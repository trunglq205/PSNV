USE [CrtiticalListDB]
GO
/****** Object:  StoredProcedure [dbo].[sp_InsertZFMA0037_Work]    Script Date: 11/27/2026 9:26:04 AM ******/
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

    INSERT INTO ZFMA0037_WORK (Material, Plant, ETA_PSNV, Elm, InboundQty, SafetyStock, Vendor, DataSource)
    SELECT 
        o.Material, 
        o.Plant, 
        o.ETA_PSNV, 
        o.Elm, 
        -- Quy đổi g -> kg cho Material bắt đầu bằng ZM
        CASE WHEN o.Material LIKE 'ZM%' THEN o.InboundQty  / 1000.0 ELSE o.InboundQty  END AS InboundQty,
        CASE WHEN o.Material LIKE 'ZM%' THEN o.SafetyStock / 1000.0 ELSE o.SafetyStock END AS SafetyStock, 
		o.fix
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
