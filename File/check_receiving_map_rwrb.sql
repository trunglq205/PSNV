USE [CrtiticalListDB]
GO
/****** Object:  StoredProcedure [dbo].[sp_InsertTableWork_V2]    Script Date: 11/13/2026 2:11:55 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ============================================================================
   BẢN CUỐI - VIỆC 2 & VIỆC 3

   VIỆC 2 - Valid date:
     - PIC set trên web -> bấm Apply -> ăn ngay (sp_ResertMR nạp lại ZFMA0037_WORK)
     - Cờ IsOverride / OverrideEndValidDate KHÔNG bị xoá lúc Apply
       -> web vẫn hiển thị đúng giá trị PIC đang dùng
     - Job auto hôm sau (sp_InsertTableWork_V2) xoá cờ -> quay về rule 3 tháng

   VIỆC 3 - ValidGWAir / ValidGWAirOtherPlant:
     - Chỉ Admin set, ăn ngay khi Apply
     - KHÔNG bị reset bởi job auto (đã bỏ khỏi khối UPDATE)
     - Giá trị 100/50 chỉ dùng khi khởi tạo row mới

   MR:
     - Apply -> ăn ngay, cờ IsMR giữ nguyên để web hiển thị đúng
     - Job auto LUÔN chạy với IsMR = 0 (không nạp dòng MR), đồng thời xoá cờ

   PHỤ THUỘC: cần đã tạo sp_InsertZFMA0037_Work (PHẦN 1 của file trước).
   ============================================================================ */


/* ============================================================================
   STORE 1: sp_InsertTableWork_V2   - job auto import

   Thay đổi so với bản gốc:
   [1] INSERT khởi tạo row mới: thêm ValidGWAir = 100, ValidGWAirOtherPlant = 50
   [2] Bỏ đọc override -> job auto LUÔN dùng rule mặc định (2-3 tháng)
   [3] Khối UPDATE: BỎ ValidGWAir = 100 và ValidGWAirOtherPlant = 50   -> VIỆC 3
                    GIỮ IsOverride = 0, OverrideEndValidDate = NULL, IsMR = 0
   [4] Bỏ ZFMA0037_WORK khỏi DISABLE / DELETE / REBUILD (SP con tự lo)
   [5] Thay khối nạp ZFMA0037_WORK bằng EXEC sp_InsertZFMA0037_Work với @IsMR = 0
   ============================================================================ */
ALTER   PROCEDURE [dbo].[sp_InsertTableWork_V2]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DataSource TINYINT = 0; -- SAP

    BEGIN TRY
        -- ========== DISABLE INDEXES (bỏ ZFMA0037_WORK) ==========
        ALTER INDEX ALL ON ZFMA0033_WORK DISABLE;
        ALTER INDEX ALL ON ZFMA0035_WORK DISABLE;
        ALTER INDEX ALL ON tblZMV132 DISABLE;
        ALTER INDEX ALL ON ZMV132_Judgement DISABLE;

        -- ========== CONFIG ==========
        -- [1] Giá trị mặc định GW chỉ set khi tạo row mới
        IF NOT EXISTS (SELECT 1 FROM dbo.NumberColumnShow WHERE DataSource = @DataSource)
            INSERT INTO dbo.NumberColumnShow (DataSource, ValidGWAir, ValidGWAirOtherPlant)
            VALUES (@DataSource, 100, 50);

        DECLARE @Today DATE = CAST(GETDATE() AS DATE);
        DECLARE @WeekOfMonth INT = ((DAY(@Today) - 1) / 7) + 1;
        DECLARE @EndValidDate DATE;
        DECLARE @MonthDiff INT;

        -- [2] Job auto luôn dùng rule mặc định, không đọc override
        SET @EndValidDate = EOMONTH(DATEADD(MONTH, IIF(@WeekOfMonth >= 4, 3, 2), @Today));
        SET @MonthDiff = DATEDIFF(MONTH, @Today, @EndValidDate) + 1;

        -- [3] Xoá cờ override + IsMR, KHÔNG đụng ValidGWAir / ValidGWAirOtherPlant
        UPDATE dbo.NumberColumnShow
        SET ColumnAirSummary = @MonthDiff,
            EndValidDate = dbo.fn_FormatDate(@EndValidDate),
            IsOverride = 0,
            OverrideEndValidDate = NULL,
            IsMR = 0
        WHERE DataSource = @DataSource;

        -- ========== DELETE (bỏ ZFMA0037_WORK) ==========
        DELETE FROM ZFMA0033_WORK WHERE DataSource = @DataSource;
        DELETE FROM ZFMA0035_WORK WHERE DataSource = @DataSource;
        DELETE FROM tblZMV132 WHERE DataSource = @DataSource;
        DELETE FROM ZMV132_Judgement WHERE DataSource = @DataSource;
        INSERT INTO ZMV132_Judgement SELECT *, 0 FROM ZMV132_STG;

        CHECKPOINT;

        -- ========== ZFMA0033_WORK ==========
        INSERT INTO ZFMA0033_WORK (Plant, Material, [Type], MaterialDescription, PurGr, RoundingVal, ProfitCtr, MRPC, DataSource)
        SELECT Plant, Material, [Type], MaterialDescription, PurGr, RoundingVal, ProfitCtr, MRPC, @DataSource
        FROM ZFMA0033_STG
        WHERE [Type] = 'ROH' OR ([Type] = 'HALB' AND RIGHT(Material, 2) = '-P');

        -- ========== ZFMA0035_WORK - Gộp VendorCode ==========

        -- Bước 1: Lấy VendorFix từ ZFMA0035_STG
        SELECT Plant, Material, VendorCode AS VendorFix, LeadTime
        INTO #VendorFix
        FROM (
            SELECT Plant, Material, VendorCode, LeadTime,
                   ROW_NUMBER() OVER (PARTITION BY Plant, Material ORDER BY VendorCode) AS rn
            FROM ZFMA0035_STG
            WHERE VendorFix = 'X'
        ) x
        WHERE rn = 1;

        CREATE INDEX IX_VF ON #VendorFix(Plant, Material);

        -- Bước 2: Lấy tất cả Vendor từ ZFMA0037_STG (cột FixVendor)
        SELECT DISTINCT Plant, Material, FixVendor AS VendorCode
        INTO #VendorFromZFMA0037
        FROM ZFMA0037_STG
        WHERE FixVendor IS NOT NULL AND FixVendor <> '';

        CREATE INDEX IX_V37 ON #VendorFromZFMA0037(Plant, Material);

        -- Bước 3: Gộp VendorCode (VendorFix đứng đầu, sau đó là các Vendor khác từ ZFMA0037)
        INSERT INTO ZFMA0035_WORK (Plant, Material, VendorCode, VendorFix, LeadTime, DataSource)
        SELECT
            vf.Plant,
            vf.Material,
            vf.VendorFix + ISNULL(
                '/' + (
                    SELECT STRING_AGG(v37.VendorCode, '/') WITHIN GROUP (ORDER BY v37.VendorCode)
                    FROM #VendorFromZFMA0037 v37
                    WHERE v37.Plant = vf.Plant
                      AND v37.Material = vf.Material
                      AND v37.VendorCode <> vf.VendorFix
                ), ''
            ) AS VendorCode,
            vf.VendorFix,
            vf.LeadTime,
            @DataSource
        FROM #VendorFix vf;

        DROP TABLE #VendorFix;
        DROP TABLE #VendorFromZFMA0037;

        -- ========== tblZMV132 ==========
        INSERT INTO tblZMV132 (Plant, Material, QtyPending, VendorLastConfirm, ETAPSNV, ShippingMode, ShortLT, DataSource, VendorStatus, Vendor)
        SELECT Plant, Material, QtyPending,
               TRY_CONVERT(DATE, VendorLastCF, 113),
               TRY_CONVERT(DATE, ETAPSNV_VendorLastCF, 113),
               ShippingMode,
               TRY_CAST(ShortLT AS INT),
               @DataSource,
               VendorStatus,
               Vendor
        FROM ZMV132_STG;

        CHECKPOINT;

        -- ========== STOCK NG CACHE ==========
        DELETE FROM tblStockNGCache WHERE DataSource = @DataSource;

        INSERT INTO tblStockNGCache (Plant, Material, NGQty, DataSource)
        SELECT
            Plant,
            Material,
            SUM(InboundQty) AS NGQty,
            @DataSource
        FROM ZFMA0037_STG
        WHERE Elm = 'LB'
          AND RIGHT(SLoc, 2) IN ('97', '85', '93')
        GROUP BY Plant, Material
        HAVING SUM(InboundQty) <> 0;

        -- ========== REBUILD INDEXES cho ZFMA0033_WORK, ZFMA0035_WORK trước khi JOIN ==========
        ALTER INDEX ALL ON ZFMA0033_WORK REBUILD;
        ALTER INDEX ALL ON ZFMA0035_WORK REBUILD;

        -- [5] ========== ZFMA0037_WORK - job auto luôn chạy với IsMR = 0 ==========
        EXEC dbo.sp_InsertZFMA0037_Work
             @EndValidDate = @EndValidDate,
             @IsMR         = 0,
             @DataSource   = @DataSource;

        CHECKPOINT;

        -- ========== REBUILD REMAINING INDEXES (bỏ ZFMA0037_WORK) ==========
        ALTER INDEX ALL ON tblZMV132 REBUILD;
        ALTER INDEX ALL ON ZMV132_Judgement REBUILD;

    END TRY
    BEGIN CATCH
        -- Rebuild index nếu lỗi (tránh để index ở trạng thái disabled)
        BEGIN TRY
            ALTER INDEX ALL ON ZFMA0033_WORK REBUILD;
            ALTER INDEX ALL ON ZFMA0035_WORK REBUILD;
            ALTER INDEX ALL ON tblZMV132 REBUILD;
            ALTER INDEX ALL ON ZMV132_Judgement REBUILD;
            ALTER INDEX ALL ON ZFMA0037_WORK REBUILD;
        END TRY
        BEGIN CATCH
            -- Ignore rebuild errors in catch block
        END CATCH

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('sp_InsertTableWork failed: %s', 16, 1, @ErrMsg);
    END CATCH
END


USE [CrtiticalListDB]
GO
/****** Object:  StoredProcedure [dbo].[sp_InsertZFMA0037_Work]    Script Date: 11/13/2026 2:12:14 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE [dbo].[sp_InsertZFMA0037_Work]
    @EndValidDate DATE,
    @IsMR         BIT,
    @DataSource   TINYINT = 0
AS
BEGIN
    SET NOCOUNT ON;

    ALTER INDEX ALL ON ZFMA0037_WORK DISABLE;

    DELETE FROM ZFMA0037_WORK WHERE DataSource = @DataSource;

    SELECT 
        s.Material,
        s.Plant,
        TRY_CONVERT(DATE, REPLACE(s.ETA_PSNV, '/', '-')) AS ETA_PSNV,
        s.Elm,
        s.InboundQty,
        s.SafetyStock,
        s.[Type],
        ROW_NUMBER() OVER (PARTITION BY s.Material, s.Plant ORDER BY s.RowId) AS rn
    INTO #OrderedData
    FROM ZFMA0037_STG s;

    CREATE NONCLUSTERED INDEX IX_Ordered_Material ON #OrderedData(Material, Plant, Elm);

    SELECT Material, Plant, MIN(rn) AS LB_rn
    INTO #LB_Pos
    FROM #OrderedData
    WHERE Elm = 'LB'
    GROUP BY Material, Plant;

    CREATE NONCLUSTERED INDEX IX_LB_Material ON #LB_Pos(Material, Plant);

    DECLARE @PrefixList TABLE (Prefix NVARCHAR(10));
    INSERT INTO @PrefixList VALUES ('SS'),('SACE'),('SCCD'),('SGCC'),('SNSA'),('SPCM'),('SUS'),('SGCD'),('SI'),('ZM');

    INSERT INTO ZFMA0037_WORK (Material, Plant, ETA_PSNV, Elm, InboundQty, SafetyStock, DataSource)
    SELECT 
        o.Material, 
        o.Plant, 
        o.ETA_PSNV, 
        o.Elm, 
        -- Quy đổi g -> kg cho Material bắt đầu bằng ZM
        CASE WHEN o.Material LIKE 'ZM%' THEN o.InboundQty  / 1000.0 ELSE o.InboundQty  END AS InboundQty,
        CASE WHEN o.Material LIKE 'ZM%' THEN o.SafetyStock / 1000.0 ELSE o.SafetyStock END AS SafetyStock, 
        @DataSource
    FROM #OrderedData o
    LEFT JOIN ZFMA0035_WORK v ON o.Material = v.Material AND o.Plant = v.Plant AND v.DataSource = @DataSource
    LEFT JOIN ZFMA0033_WORK m ON o.Material = m.Material AND o.Plant = m.Plant AND m.DataSource = @DataSource
    LEFT JOIN #LB_Pos lb      ON o.Material = lb.Material AND o.Plant = lb.Plant
    WHERE (m.MaterialDescription IS NULL OR m.MaterialDescription NOT IN ('Recycle', 'Recycle resin', 'Resin recycle'))
      AND o.InboundQty <> 0
      AND (
            o.Elm = 'WB'
            OR (
                o.Elm IN ('LA','BB','SB')
                AND (o.[Type] = 'ROH' OR (o.[Type] = 'HALB' AND RIGHT(o.Material, 2) = '-P'))
                AND o.ETA_PSNV <= @EndValidDate
                AND (
                    NOT EXISTS (SELECT 1 FROM @PrefixList p WHERE o.Material LIKE p.Prefix + '%')
                    OR
                    (EXISTS (SELECT 1 FROM @PrefixList p WHERE o.Material LIKE p.Prefix + '%') 
                     AND lb.LB_rn IS NOT NULL AND o.rn < lb.LB_rn)
                )
            )
            OR (
                o.Elm = 'MR'
                AND @IsMR = 1
                AND (o.[Type] = 'ROH' OR (o.[Type] = 'HALB' AND RIGHT(o.Material, 2) = '-P'))
                AND o.ETA_PSNV <= @EndValidDate
                AND (
                    NOT EXISTS (SELECT 1 FROM @PrefixList p WHERE o.Material LIKE p.Prefix + '%')
                    OR
                    (EXISTS (SELECT 1 FROM @PrefixList p WHERE o.Material LIKE p.Prefix + '%') 
                     AND lb.LB_rn IS NOT NULL AND o.rn < lb.LB_rn)
                )
            )
        );

    DROP TABLE #OrderedData;
    DROP TABLE #LB_Pos;

    ALTER INDEX ALL ON ZFMA0037_WORK REBUILD;
END


select * from ZFMA0037_STG where Material = 'F1K1V106A010' and Elm = 'LA' order by ETA_PSNV desc
=>> data:
RowId	Material	Plant	MRPC	ETA_PSNV	FixVendor	Sloc	Elm	InboundQty	SafetyStock	Type
1476639	F1K1V106A010	VE01	E14	2026/12/01	VF163	9210	LA	10000.000	2497.000	ROH
1476640	F1K1V106A010	VE01	E14	2026/12/01	VF163	9210	LA	6000.000	2497.000	ROH
1476641	F1K1V106A010	VE01	E14	2026/12/01	VF163	9210	LA	2000.000	2497.000	ROH
1476642	F1K1V106A010	VE01	E14	2026/12/01	VF163	9210	LA	10000.000	2497.000	ROH
1476643	F1K1V106A010	VE01	E14	2026/12/01	VF163	9210	LA	10000.000	2497.000	ROH
2483770	F1K1V106A010	VR01	R14	2026/11/19	VB032	1210	LA	272000.000	5000.000	ROH
2483806	F1K1V106A010	VR01	R14	2026/12/01	VF163	1210	LA	20000.000	5000.000	ROH
2483807	F1K1V106A010	VR01	R14	2026/12/01	VF163	1210	LA	22000.000	5000.000	ROH
2483808	F1K1V106A010	VR01	R14	2026/12/01	VF163	1210	LA	18000.000	5000.000	ROH
2483809	F1K1V106A010	VR01	R14	2026/12/01	VF163	1210	LA	8000.000	5000.000	ROH
2483810	F1K1V106A010	VR01	R14	2026/12/01	VF163	1210	LA	18000.000	5000.000	ROH
2483811	F1K1V106A010	VR01	R14	2026/12/01	VF163	1210	LA	22000.000	5000.000	ROH
2483812	F1K1V106A010	VR01	R14	2026/12/01	VF163	1210	LA	22000.000	5000.000	ROH