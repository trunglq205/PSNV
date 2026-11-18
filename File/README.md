/* =====================================================================
   CHÉP SCHEMA CÁC BẢNG CÒN THIẾU TỪ DB THẬT SANG DB DEV
   SWMS_FINISH_GOODS  ->  SWMS_FINISH_GOODS_DEV   (cùng instance)
   soạn 18/11/2026

   Dùng cho 6 đối tượng mà tôi KHÔNG có DDL gốc:

     master.ng_types               wms.ng_inspection_items
     wms.ng_inspections            wms.ng_inspection_photos
     wms.stocky_carts              wms.ng_inspection_approvals

   VÌ SAO CHÉP TỪ DB THẬT thay vì tôi viết tay: DB thật nằm NGAY TRÊN
   CÙNG INSTANCE và đang chạy hai tính năng đó, nên nó là nguồn DDL
   đúng nhất. Tôi suy từ code chỉ ra được TÊN CỘT; kiểu dữ liệu, độ
   dài, default, index, FK đều sẽ là phỏng đoán.

   CÁCH LÀM: tạo khung bảng bằng `SELECT TOP 0 * INTO` (giữ đúng tên
   cột, kiểu, NULL/NOT NULL, IDENTITY và collation), rồi sinh tiếp
   DEFAULT / PK / UNIQUE / INDEX / CHECK / FK từ catalog DB thật.

   ⚠ KHÔNG chép dữ liệu, trừ bảng danh mục `master.ng_types`
   (@CopyRefData) — rỗng bảng đó thì màn Hàng bất thường không có loại
   NG nào để chọn.

   ─── CÁCH CHẠY ───────────────────────────────────────────────────────
   Chạy TRONG DB DEV. @WhatIf = 1 chỉ IN câu lệnh ra tab Messages.
   Đọc xong đổi @WhatIf = 0 rồi chạy lại. Chạy lại nhiều lần vô hại:
   bảng/khoá nào đã có thì bỏ qua.
   ===================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ProdDb      sysname = N'SWMS_FINISH_GOODS';   -- << sửa nếu khác
DECLARE @WhatIf      bit     = 1;                      -- << 0 = ghi thật
DECLARE @CopyRefData bit     = 1;                      -- chép dữ liệu ng_types

/* ── Chốt an toàn ──────────────────────────────────────────────────── */
IF DB_NAME() = @ProdDb
BEGIN
    RAISERROR(N'DỪNG: đang ở DB thật (%s). Chọn DB dev rồi chạy lại.', 16, 1, @ProdDb);
    RETURN;
END
IF DB_NAME() NOT LIKE N'%DEV%' AND DB_NAME() NOT LIKE N'%TEST%'
BEGIN
    DECLARE @cur sysname = DB_NAME();
    RAISERROR(N'DỪNG: DB hiện tại "%s" không có chữ DEV/TEST trong tên.', 16, 1, @cur);
    RETURN;
END
IF DB_ID(@ProdDb) IS NULL
BEGIN
    RAISERROR(N'DỪNG: không thấy DB "%s" trên instance này.', 16, 1, @ProdDb);
    RETURN;
END

PRINT N'### DB dev  = ' + DB_NAME();
PRINT N'### DB thật = ' + @ProdDb;
PRINT N'### @WhatIf = ' + CAST(@WhatIf AS varchar(1))
      + CASE WHEN @WhatIf = 1 THEN N'   (CHỈ IN, KHÔNG GHI)' ELSE N'   (GHI THẬT)' END;
PRINT N'';

/* Dùng #temp (không dùng bảng biến) để câu dynamic SQL bên dưới đọc được.
   Thứ tự: bảng cha trước bảng con. */
IF OBJECT_ID('tempdb..#list') IS NOT NULL DROP TABLE #list;
CREATE TABLE #list (ord int PRIMARY KEY, sch sysname, tbl sysname);
INSERT INTO #list (ord, sch, tbl) VALUES
    (1, N'master', N'ng_types'),
    (2, N'wms',    N'stocky_carts'),
    (3, N'wms',    N'ng_inspections'),
    (4, N'wms',    N'ng_inspection_items'),
    (5, N'wms',    N'ng_inspection_photos'),
    (6, N'wms',    N'ng_inspection_approvals');

/* Mọi câu lệnh sinh ra gom vào đây rồi mới in / chạy, theo thứ tự.    */
IF OBJECT_ID('tempdb..#cmd') IS NOT NULL DROP TABLE #cmd;
CREATE TABLE #cmd (id int IDENTITY(1,1) PRIMARY KEY, buoc nvarchar(40),
                   doi_tuong nvarchar(300), stmt nvarchar(max));

DECLARE @sql nvarchar(max);
DECLARE @P nvarchar(300) = QUOTENAME(@ProdDb);

/* =====================================================================
   MỤC 1 — SOÁT: bảng nào có ở DB thật, bảng nào dev đã có
   ===================================================================== */
SET @sql = N'
SELECT  bang          = l.sch + N''.'' + l.tbl,
        o_db_that     = CASE WHEN pt.object_id IS NULL THEN N''>>> KHONG CO <<<''
                             ELSE N''co'' END,
        o_db_dev      = CASE WHEN OBJECT_ID(QUOTENAME(l.sch) + N''.'' + QUOTENAME(l.tbl), ''U'') IS NULL
                             THEN N''thieu'' ELSE N''da co -> bo qua'' END,
        so_cot        = (SELECT COUNT(*) FROM ' + @P + N'.sys.columns pc
                         WHERE pc.object_id = pt.object_id),
        cot_tinh_toan = (SELECT COUNT(*) FROM ' + @P + N'.sys.columns pc
                         WHERE pc.object_id = pt.object_id AND pc.is_computed = 1),
        so_dong_that  = (SELECT ISNULL(SUM(ps.row_count), 0)
                         FROM ' + @P + N'.sys.dm_db_partition_stats ps
                         WHERE ps.object_id = pt.object_id AND ps.index_id IN (0,1))
FROM    #list l
LEFT JOIN ' + @P + N'.sys.tables pt
       ON pt.name COLLATE DATABASE_DEFAULT = l.tbl COLLATE DATABASE_DEFAULT
      AND SCHEMA_NAME(pt.schema_id) COLLATE DATABASE_DEFAULT = l.sch COLLATE DATABASE_DEFAULT
ORDER BY l.ord;';
EXEC sp_executesql @sql;

PRINT N'MỤC 1: cot_tinh_toan > 0 nghĩa là bảng có COMPUTED COLUMN —';
PRINT N'        `SELECT INTO` sẽ biến nó thành cột thường, phải sửa tay.';
PRINT N'';

/* =====================================================================
   MỤC 2 — KHUNG BẢNG: SELECT TOP 0 * INTO
   ---------------------------------------------------------------------
   Giữ đúng tên cột, kiểu, độ dài, NULL/NOT NULL, IDENTITY, collation.
   KHÔNG giữ: default, PK, index, check, FK — sinh ở các mục sau.
   ===================================================================== */
SET @sql = N'
INSERT INTO #cmd (buoc, doi_tuong, stmt)
SELECT  N''2-khung-bang'', l.sch + N''.'' + l.tbl,
        N''SELECT TOP 0 * INTO '' + QUOTENAME(l.sch) + N''.'' + QUOTENAME(l.tbl)
        + N'' FROM '' + ' + QUOTENAME(@ProdDb, '''') + N' + N''.'' + QUOTENAME(l.sch)
        + N''.'' + QUOTENAME(l.tbl) + N'';''
FROM    #list l
JOIN    ' + @P + N'.sys.tables pt
       ON pt.name COLLATE DATABASE_DEFAULT = l.tbl COLLATE DATABASE_DEFAULT
      AND SCHEMA_NAME(pt.schema_id) COLLATE DATABASE_DEFAULT = l.sch COLLATE DATABASE_DEFAULT
WHERE   OBJECT_ID(QUOTENAME(l.sch) + N''.'' + QUOTENAME(l.tbl), ''U'') IS NULL
ORDER BY l.ord;';
EXEC sp_executesql @sql;

/* =====================================================================
   MỤC 3 — DEFAULT
   ===================================================================== */
SET @sql = N'
INSERT INTO #cmd (buoc, doi_tuong, stmt)
SELECT  N''3-default'', l.sch + N''.'' + l.tbl + N''.'' + pc.name COLLATE DATABASE_DEFAULT,
        N''ALTER TABLE '' + QUOTENAME(l.sch) + N''.'' + QUOTENAME(l.tbl)
        + N'' ADD CONSTRAINT '' + QUOTENAME(pdc.name COLLATE DATABASE_DEFAULT)
        + N'' DEFAULT '' + pdc.definition COLLATE DATABASE_DEFAULT
        + N'' FOR '' + QUOTENAME(pc.name COLLATE DATABASE_DEFAULT) + N'';''
FROM    #list l
JOIN    ' + @P + N'.sys.tables pt
       ON pt.name COLLATE DATABASE_DEFAULT = l.tbl COLLATE DATABASE_DEFAULT
      AND SCHEMA_NAME(pt.schema_id) COLLATE DATABASE_DEFAULT = l.sch COLLATE DATABASE_DEFAULT
JOIN    ' + @P + N'.sys.columns pc ON pc.object_id = pt.object_id
JOIN    ' + @P + N'.sys.default_constraints pdc ON pdc.object_id = pc.default_object_id
ORDER BY l.ord, pc.column_id;';
EXEC sp_executesql @sql;

/* =====================================================================
   MỤC 4 — PK / UNIQUE / INDEX
   ---------------------------------------------------------------------
   PK và UNIQUE CONSTRAINT sinh bằng ALTER TABLE ADD CONSTRAINT; unique
   INDEX và index thường sinh bằng CREATE INDEX (giữ cả INCLUDE và
   WHERE filter — bỏ filter là đổi hẳn nghĩa của unique).
   ===================================================================== */
SET @sql = N'
INSERT INTO #cmd (buoc, doi_tuong, stmt)
SELECT  N''4-'' + CASE WHEN pi.is_primary_key = 1 THEN N''pk''
                      WHEN pi.is_unique_constraint = 1 THEN N''uq''
                      WHEN pi.is_unique = 1 THEN N''uix'' ELSE N''ix'' END,
        l.sch + N''.'' + l.tbl + N''.'' + pi.name COLLATE DATABASE_DEFAULT,
        CASE
          WHEN pi.is_primary_key = 1 OR pi.is_unique_constraint = 1 THEN
            N''ALTER TABLE '' + QUOTENAME(l.sch) + N''.'' + QUOTENAME(l.tbl)
            + N'' ADD CONSTRAINT '' + QUOTENAME(pi.name COLLATE DATABASE_DEFAULT)
            + CASE WHEN pi.is_primary_key = 1 THEN N'' PRIMARY KEY '' ELSE N'' UNIQUE '' END
            + CASE WHEN pi.type = 1 THEN N''CLUSTERED '' ELSE N''NONCLUSTERED '' END
            + N''('' + k.cols + N'');''
          ELSE
            N''CREATE '' + CASE WHEN pi.is_unique = 1 THEN N''UNIQUE '' ELSE N'''' END
            + CASE WHEN pi.type = 1 THEN N''CLUSTERED '' ELSE N''NONCLUSTERED '' END
            + N''INDEX '' + QUOTENAME(pi.name COLLATE DATABASE_DEFAULT)
            + N'' ON '' + QUOTENAME(l.sch) + N''.'' + QUOTENAME(l.tbl)
            + N'' ('' + k.cols + N'')''
            + ISNULL(N'' INCLUDE ('' + inc.cols + N'')'', N'''')
            + ISNULL(N'' WHERE '' + pi.filter_definition COLLATE DATABASE_DEFAULT, N'''')
            + N'';''
        END
FROM    #list l
JOIN    ' + @P + N'.sys.tables pt
       ON pt.name COLLATE DATABASE_DEFAULT = l.tbl COLLATE DATABASE_DEFAULT
      AND SCHEMA_NAME(pt.schema_id) COLLATE DATABASE_DEFAULT = l.sch COLLATE DATABASE_DEFAULT
JOIN    ' + @P + N'.sys.indexes pi ON pi.object_id = pt.object_id
                                  AND pi.type IN (1, 2) AND pi.is_hypothetical = 0
CROSS APPLY (
    SELECT cols = STUFF((
        SELECT N'', '' + QUOTENAME(pc2.name COLLATE DATABASE_DEFAULT)
               + CASE WHEN pic2.is_descending_key = 1 THEN N'' DESC'' ELSE N'''' END
        FROM   ' + @P + N'.sys.index_columns pic2
        JOIN   ' + @P + N'.sys.columns pc2 ON pc2.object_id = pic2.object_id
                                          AND pc2.column_id = pic2.column_id
        WHERE  pic2.object_id = pi.object_id AND pic2.index_id = pi.index_id
          AND  pic2.is_included_column = 0
        ORDER BY pic2.key_ordinal
        FOR XML PATH(''''), TYPE).value(''.'', ''nvarchar(max)'') COLLATE DATABASE_DEFAULT, 1, 2, N'''')
) k
OUTER APPLY (
    SELECT cols = STUFF((
        SELECT N'', '' + QUOTENAME(pc3.name COLLATE DATABASE_DEFAULT)
        FROM   ' + @P + N'.sys.index_columns pic3
        JOIN   ' + @P + N'.sys.columns pc3 ON pc3.object_id = pic3.object_id
                                          AND pc3.column_id = pic3.column_id
        WHERE  pic3.object_id = pi.object_id AND pic3.index_id = pi.index_id
          AND  pic3.is_included_column = 1
        ORDER BY pc3.name
        FOR XML PATH(''''), TYPE).value(''.'', ''nvarchar(max)'') COLLATE DATABASE_DEFAULT, 1, 2, N'''')
) inc
WHERE   k.cols IS NOT NULL
ORDER BY l.ord, pi.is_primary_key DESC, pi.name;';
EXEC sp_executesql @sql;

/* =====================================================================
   MỤC 5 — CHECK CONSTRAINT
   ===================================================================== */
SET @sql = N'
INSERT INTO #cmd (buoc, doi_tuong, stmt)
SELECT  N''5-check'', l.sch + N''.'' + l.tbl + N''.'' + pcc.name COLLATE DATABASE_DEFAULT,
        N''ALTER TABLE '' + QUOTENAME(l.sch) + N''.'' + QUOTENAME(l.tbl)
        + N'' ADD CONSTRAINT '' + QUOTENAME(pcc.name COLLATE DATABASE_DEFAULT)
        + N'' CHECK '' + pcc.definition COLLATE DATABASE_DEFAULT + N'';''
FROM    #list l
JOIN    ' + @P + N'.sys.tables pt
       ON pt.name COLLATE DATABASE_DEFAULT = l.tbl COLLATE DATABASE_DEFAULT
      AND SCHEMA_NAME(pt.schema_id) COLLATE DATABASE_DEFAULT = l.sch COLLATE DATABASE_DEFAULT
JOIN    ' + @P + N'.sys.check_constraints pcc ON pcc.parent_object_id = pt.object_id
ORDER BY l.ord, pcc.name;';
EXEC sp_executesql @sql;

/* =====================================================================
   MỤC 6 — FOREIGN KEY (sau cùng, khi mọi bảng đã có)
   ---------------------------------------------------------------------
   Chỉ sinh FK mà bảng ĐƯỢC TRỎ TỚI đã tồn tại ở dev (hoặc nằm trong
   danh sách đang tạo). FK trỏ tới bảng chưa có thì bỏ qua và báo ở
   Mục 8 — thêm sau, đừng để câu lệnh lỗi giữa mạch.
   ===================================================================== */
SET @sql = N'
INSERT INTO #cmd (buoc, doi_tuong, stmt)
SELECT  N''6-fk'', l.sch + N''.'' + l.tbl + N''.'' + pfk.name COLLATE DATABASE_DEFAULT,
        N''ALTER TABLE '' + QUOTENAME(l.sch) + N''.'' + QUOTENAME(l.tbl)
        + N'' ADD CONSTRAINT '' + QUOTENAME(pfk.name COLLATE DATABASE_DEFAULT)
        + N'' FOREIGN KEY ('' + pcols.cols + N'') REFERENCES ''
        + QUOTENAME(rsch.name COLLATE DATABASE_DEFAULT) + N''.''
        + QUOTENAME(rt.name COLLATE DATABASE_DEFAULT)
        + N'' ('' + rcols.cols + N'')''
        + CASE pfk.delete_referential_action WHEN 1 THEN N'' ON DELETE CASCADE''
                                             WHEN 2 THEN N'' ON DELETE SET NULL''
                                             ELSE N'''' END + N'';''
FROM    #list l
JOIN    ' + @P + N'.sys.tables pt
       ON pt.name COLLATE DATABASE_DEFAULT = l.tbl COLLATE DATABASE_DEFAULT
      AND SCHEMA_NAME(pt.schema_id) COLLATE DATABASE_DEFAULT = l.sch COLLATE DATABASE_DEFAULT
JOIN    ' + @P + N'.sys.foreign_keys pfk ON pfk.parent_object_id = pt.object_id
JOIN    ' + @P + N'.sys.tables rt ON rt.object_id = pfk.referenced_object_id
JOIN    ' + @P + N'.sys.schemas rsch ON rsch.schema_id = rt.schema_id
CROSS APPLY (
    SELECT cols = STUFF((
        SELECT N'', '' + QUOTENAME(ppc.name COLLATE DATABASE_DEFAULT)
        FROM   ' + @P + N'.sys.foreign_key_columns pfkc
        JOIN   ' + @P + N'.sys.columns ppc ON ppc.object_id = pfkc.parent_object_id
                                          AND ppc.column_id = pfkc.parent_column_id
        WHERE  pfkc.constraint_object_id = pfk.object_id
        ORDER BY pfkc.constraint_column_id
        FOR XML PATH(''''), TYPE).value(''.'', ''nvarchar(max)'') COLLATE DATABASE_DEFAULT, 1, 2, N'''')
) pcols
CROSS APPLY (
    SELECT cols = STUFF((
        SELECT N'', '' + QUOTENAME(prc.name COLLATE DATABASE_DEFAULT)
        FROM   ' + @P + N'.sys.foreign_key_columns pfkc
        JOIN   ' + @P + N'.sys.columns prc ON prc.object_id = pfkc.referenced_object_id
                                          AND prc.column_id = pfkc.referenced_column_id
        WHERE  pfkc.constraint_object_id = pfk.object_id
        ORDER BY pfkc.constraint_column_id
        FOR XML PATH(''''), TYPE).value(''.'', ''nvarchar(max)'') COLLATE DATABASE_DEFAULT, 1, 2, N'''')
) rcols
WHERE   OBJECT_ID(QUOTENAME(rsch.name COLLATE DATABASE_DEFAULT) + N''.''
                + QUOTENAME(rt.name COLLATE DATABASE_DEFAULT), ''U'') IS NOT NULL
   OR   EXISTS (SELECT 1 FROM #list l2
                WHERE l2.sch COLLATE DATABASE_DEFAULT = rsch.name COLLATE DATABASE_DEFAULT
                  AND l2.tbl COLLATE DATABASE_DEFAULT = rt.name COLLATE DATABASE_DEFAULT)
ORDER BY l.ord, pfk.name;';
EXEC sp_executesql @sql;

/* =====================================================================
   MỤC 7 — IN RA / CHẠY
   ===================================================================== */
SELECT buoc, doi_tuong, stmt FROM #cmd ORDER BY id;

/* PRINT chỉ nhận BIỂU THỨC VÔ HƯỚNG, không nhận truy vấn con — viết
   CAST((SELECT COUNT(*) ...)) thẳng vào PRINT là lỗi 1046
   "Subqueries are not allowed in this context". Phải lấy ra biến trước. */
DECLARE @soCau int;
SET @soCau = (SELECT COUNT(*) FROM #cmd);

IF @WhatIf = 1
BEGIN
    PRINT N'';
    PRINT N'===== @WhatIf = 1 : đã IN ' + CAST(@soCau AS varchar(10))
          + N' câu lệnh ở bảng kết quả, CHƯA chạy câu nào =====';
    PRINT N'Đọc xong, đổi @WhatIf = 0 rồi chạy lại cả file.';
END
ELSE
BEGIN
    DECLARE @id int, @stmt nvarchar(max), @obj nvarchar(300), @b nvarchar(40);
    DECLARE @ok int = 0, @err int = 0;

    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT id, buoc, doi_tuong, stmt FROM #cmd ORDER BY id;
    OPEN c;
    FETCH NEXT FROM c INTO @id, @b, @obj, @stmt;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            EXEC sp_executesql @stmt;
            SET @ok += 1;
            PRINT N'OK   [' + @b + N'] ' + @obj;
        END TRY
        BEGIN CATCH
            /* Không dừng cả mạch vì một câu lỗi: phần lớn lỗi ở đây là
               "đã tồn tại", và những câu sau vẫn cần chạy. */
            SET @err += 1;
            PRINT N'LỖI  [' + @b + N'] ' + @obj + N' -> ' + ERROR_MESSAGE();
        END CATCH
        FETCH NEXT FROM c INTO @id, @b, @obj, @stmt;
    END
    CLOSE c; DEALLOCATE c;

    PRINT N'';
    PRINT N'===== XONG: ' + CAST(@ok AS varchar(10)) + N' câu OK, '
          + CAST(@err AS varchar(10)) + N' câu lỗi =====';
END

/* =====================================================================
   MỤC 8 — CHÉP DỮ LIỆU DANH MỤC (chỉ master.ng_types)
   ===================================================================== */
IF @CopyRefData = 1 AND @WhatIf = 0
BEGIN
    /* Cả mục này đi qua dynamic SQL. Lý do: trong CÙNG một batch, câu
       tĩnh tham chiếu master.ng_types sẽ được biên dịch dù bảng chưa tồn
       tại, và điều kiện IF ... AND NOT EXISTS(...) KHÔNG đảm bảo thứ tự
       xét — gặp bảng chưa có là ném "Invalid object name" ngay. */
    IF OBJECT_ID('master.ng_types', 'U') IS NULL
        PRINT N'MỤC 8 bỏ qua: master.ng_types vẫn chưa tạo được.';
    ELSE
    BEGIN
        SET @sql = N'
DECLARE @n int;
SELECT @n = COUNT(*) FROM master.ng_types;
IF @n > 0
BEGIN
    PRINT N''MỤC 8 bỏ qua: master.ng_types đã có '' + CAST(@n AS varchar(10)) + N'' dòng.'';
    RETURN;
END

DECLARE @hasIdent bit = CASE WHEN EXISTS (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(''master.ng_types'') AND is_identity = 1)
    THEN 1 ELSE 0 END;

DECLARE @cols nvarchar(max) = STUFF((
    SELECT N'', '' + QUOTENAME(c.name)
    FROM   sys.columns c
    WHERE  c.object_id = OBJECT_ID(''master.ng_types'') AND c.is_computed = 0
    ORDER BY c.column_id
    FOR XML PATH(''''), TYPE).value(''.'', ''nvarchar(max)''), 1, 2, N'''');

DECLARE @ins nvarchar(max) =
      CASE WHEN @hasIdent = 1 THEN N''SET IDENTITY_INSERT master.ng_types ON; '' ELSE N'''' END
    + N''INSERT INTO master.ng_types ('' + @cols + N'') SELECT '' + @cols
    + N'' FROM ' + @P + N'.master.ng_types;''
    + CASE WHEN @hasIdent = 1 THEN N'' SET IDENTITY_INSERT master.ng_types OFF;'' ELSE N'''' END;

EXEC sp_executesql @ins;
PRINT N''MỤC 8: đã chép dữ liệu master.ng_types.'';';

        BEGIN TRY
            EXEC sp_executesql @sql;
        END TRY
        BEGIN CATCH
            PRINT N'MỤC 8 lỗi: ' + ERROR_MESSAGE();
        END CATCH
    END
END

/* =====================================================================
   MỤC 9 — ĐỐI CHIẾU LẠI
   ===================================================================== */
SET @sql = N'
SELECT  bang     = l.sch + N''.'' + l.tbl,
        cot_that = (SELECT COUNT(*) FROM ' + @P + N'.sys.columns pc
                    JOIN ' + @P + N'.sys.tables pt2 ON pt2.object_id = pc.object_id
                    JOIN ' + @P + N'.sys.schemas ps ON ps.schema_id = pt2.schema_id
                    WHERE pt2.name COLLATE DATABASE_DEFAULT = l.tbl COLLATE DATABASE_DEFAULT
                      AND ps.name COLLATE DATABASE_DEFAULT = l.sch COLLATE DATABASE_DEFAULT),
        cot_dev  = ISNULL((SELECT COUNT(*) FROM sys.columns c
                           WHERE c.object_id = OBJECT_ID(QUOTENAME(l.sch) + N''.'' + QUOTENAME(l.tbl), ''U'')), 0),
        trang_thai = CASE WHEN OBJECT_ID(QUOTENAME(l.sch) + N''.'' + QUOTENAME(l.tbl), ''U'') IS NULL
                          THEN N''>>> VAN THIEU <<<'' ELSE N''da co'' END
FROM    #list l
ORDER BY l.ord;';
EXEC sp_executesql @sql;

PRINT N'';
PRINT N'### Cột lệch nhau thì chạy lại export_schema_compact.sql trên CẢ HAI DB';
PRINT N'### rồi so, chứ đừng thêm cột bằng tay.';
