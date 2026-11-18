/* =====================================================================
   XUẤT ẢNH SCHEMA DẠNG GỌN, SO SÁNH ĐƯỢC TỪNG DÒNG
   soạn 18/11/2026 · CHỈ ĐỌC, không sửa gì

   Mục đích: gửi lại cho tôi để tôi biết DB dev hiện có những gì, rồi
   viết script bổ sung đúng phần còn thiếu.

   ─── CÁCH CHẠY ───────────────────────────────────────────────────────
   1. SSMS, chọn ĐÚNG DB dev (dropdown trên thanh công cụ, hoặc sửa
      dòng USE ở dưới).
   2. Ctrl+T  (Results to Text)  — để copy ra dễ, không bị cắt.
   3. Chạy cả file (F5).
   4. Bấm vào ô kết quả, Ctrl+A, Ctrl+C, dán vào Notepad, lưu thành
      schema_dev.txt rồi gửi tôi.

   Nếu kết quả bị cắt: Tools > Options > Query Results > SQL Server >
   Results to Text > Maximum characters per column = 8000.

   ─── ĐỌC KẾT QUẢ ─────────────────────────────────────────────────────
   Mỗi dòng một đối tượng, cột đầu là loại:
     S  schema            S|wms
     T  bảng              T|wms.pallets
     C  cột               C|wms.pallets|id|bigint|NOT NULL|IDENTITY|<default>
     K  khoá chính        K|wms.pallets|pk_pallets|id
     U  unique            U|wms.pallets|ux_...|pallet_id|<filter>
     F  khoá ngoại        F|wms.pallets|fk_...|locator_id -> master.locators.id
     H  check             H|wms.pallets|ck_...|<definition>
     X  index thường      X|wms.pallets|ix_...|col1,col2|INCLUDE(col3)|<filter>
     V  view              V|wms.v_abc
     P  procedure         P|wms.usp_abc
     N  function          N|wms.fn_abc|TABLE|SCALAR
     G  trigger           G|wms.tr_abc|wms.pallets
   ===================================================================== */

-- USE [SWMS_FINISH_GOODS_DEV];   -- bỏ chú thích nếu muốn ép đúng DB
SET NOCOUNT ON;

PRINT N'### DB=' + DB_NAME()
      + N' | SERVER=' + CAST(SERVERPROPERTY('ServerName') AS nvarchar(200))
      + N' | LUC=' + CONVERT(varchar(19), SYSDATETIME(), 120);
PRINT N'### VERSION=' + CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(50));
PRINT N'';

/* Chỉ lấy ba schema của ứng dụng. Thêm schema khác thì sửa danh sách
   này ở CẢ các mục dưới (biến bảng dùng chung).                        */
DECLARE @sch TABLE (name sysname PRIMARY KEY);
INSERT INTO @sch (name) VALUES (N'wms'), (N'master'), (N'dbo');

/* ── S: schema có thật trong DB ─────────────────────────────────────── */
SELECT line = N'S|' + s.name
FROM   sys.schemas s
JOIN   @sch f ON f.name = s.name
ORDER BY s.name;

/* ── T + C: bảng và cột ─────────────────────────────────────────────── */
/* Sắp theo bảng rồi mới tới cột của nó (ORDER BY trên UNION chỉ nhận cột
   có trong SELECT, nên phải bọc một lớp derived table).                 */
SELECT line
FROM (
    SELECT  sort_tbl = s.name + N'.' + t.name, sort_kind = 0, sort_col = 0,
            line = N'T|' + s.name + N'.' + t.name
    FROM   sys.tables t
    JOIN   sys.schemas s ON s.schema_id = t.schema_id
    JOIN   @sch f ON f.name = s.name
    UNION ALL
    SELECT  sort_tbl = s.name + N'.' + t.name, sort_kind = 1, sort_col = c.column_id,
            line =
        N'C|' + s.name + N'.' + t.name + N'|' + c.name + N'|'
        + ty.name
        + CASE
            WHEN ty.name IN (N'nvarchar', N'nchar')
                THEN N'(' + CASE WHEN c.max_length = -1 THEN N'max'
                                 ELSE CAST(c.max_length / 2 AS nvarchar(10)) END + N')'
            WHEN ty.name IN (N'varchar', N'char', N'varbinary', N'binary')
                THEN N'(' + CASE WHEN c.max_length = -1 THEN N'max'
                                 ELSE CAST(c.max_length AS nvarchar(10)) END + N')'
            WHEN ty.name IN (N'decimal', N'numeric')
                THEN N'(' + CAST(c.precision AS nvarchar(10)) + N','
                          + CAST(c.scale AS nvarchar(10)) + N')'
            WHEN ty.name IN (N'datetime2', N'time', N'datetimeoffset')
                THEN N'(' + CAST(c.scale AS nvarchar(10)) + N')'
            ELSE N''
          END
        + N'|' + CASE WHEN c.is_nullable = 1 THEN N'NULL' ELSE N'NOT NULL' END
        + N'|' + CASE WHEN c.is_identity = 1 THEN N'IDENTITY'
                      WHEN c.is_computed = 1 THEN N'COMPUTED' ELSE N'' END
        + N'|' + ISNULL(dc.definition, N'')
        + N'|#' + CAST(c.column_id AS nvarchar(10))
    FROM   sys.tables t
    JOIN   sys.schemas s ON s.schema_id = t.schema_id
    JOIN   @sch f ON f.name = s.name
    JOIN   sys.columns c ON c.object_id = t.object_id
    JOIN   sys.types ty ON ty.user_type_id = c.user_type_id
    LEFT JOIN sys.default_constraints dc ON dc.object_id = c.default_object_id
) q
ORDER BY sort_tbl, sort_kind, sort_col;

/* ── K + U + X: khoá chính, unique, index ───────────────────────────── */
SELECT line =
    CASE WHEN i.is_primary_key = 1 THEN N'K|'
         WHEN i.is_unique_constraint = 1 OR i.is_unique = 1 THEN N'U|'
         ELSE N'X|' END
    + s.name + N'.' + t.name + N'|' + i.name + N'|'
    + STUFF((
        SELECT N',' + c2.name
               + CASE WHEN ic2.is_descending_key = 1 THEN N' DESC' ELSE N'' END
        FROM   sys.index_columns ic2
        JOIN   sys.columns c2 ON c2.object_id = ic2.object_id
                             AND c2.column_id = ic2.column_id
        WHERE  ic2.object_id = i.object_id AND ic2.index_id = i.index_id
           AND ic2.is_included_column = 0
        ORDER BY ic2.key_ordinal
        FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 1, N'')
    + N'|INCLUDE(' + ISNULL(STUFF((
        SELECT N',' + c3.name
        FROM   sys.index_columns ic3
        JOIN   sys.columns c3 ON c3.object_id = ic3.object_id
                             AND c3.column_id = ic3.column_id
        WHERE  ic3.object_id = i.object_id AND ic3.index_id = i.index_id
           AND ic3.is_included_column = 1
        ORDER BY c3.name
        FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 1, N''), N'') + N')'
    + N'|' + ISNULL(i.filter_definition, N'')
    + N'|' + CASE WHEN i.type = 1 THEN N'CLUSTERED' ELSE N'NONCLUSTERED' END
FROM   sys.indexes i
JOIN   sys.tables t ON t.object_id = i.object_id
JOIN   sys.schemas s ON s.schema_id = t.schema_id
JOIN   @sch f ON f.name = s.name
WHERE  i.type IN (1, 2) AND i.is_hypothetical = 0
ORDER BY line;

/* ── F: khoá ngoại (kèm cột, theo cặp) ──────────────────────────────── */
SELECT line =
    N'F|' + s.name + N'.' + t.name + N'|' + fk.name + N'|'
    + STUFF((
        SELECT N',' + pc.name
        FROM   sys.foreign_key_columns fkc2
        JOIN   sys.columns pc ON pc.object_id = fkc2.parent_object_id
                             AND pc.column_id = fkc2.parent_column_id
        WHERE  fkc2.constraint_object_id = fk.object_id
        ORDER BY fkc2.constraint_column_id
        FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 1, N'')
    + N' -> ' + rs.name + N'.' + rt.name + N'.'
    + STUFF((
        SELECT N',' + rc.name
        FROM   sys.foreign_key_columns fkc3
        JOIN   sys.columns rc ON rc.object_id = fkc3.referenced_object_id
                             AND rc.column_id = fkc3.referenced_column_id
        WHERE  fkc3.constraint_object_id = fk.object_id
        ORDER BY fkc3.constraint_column_id
        FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 1, N'')
    + N'|' + fk.delete_referential_action_desc
FROM   sys.foreign_keys fk
JOIN   sys.tables t ON t.object_id = fk.parent_object_id
JOIN   sys.schemas s ON s.schema_id = t.schema_id
JOIN   sys.tables rt ON rt.object_id = fk.referenced_object_id
JOIN   sys.schemas rs ON rs.schema_id = rt.schema_id
JOIN   @sch f ON f.name = s.name
ORDER BY line;

/* ── H: check constraint ────────────────────────────────────────────── */
SELECT line = N'H|' + s.name + N'.' + t.name + N'|' + cc.name + N'|'
            + REPLACE(REPLACE(cc.definition, CHAR(13), N' '), CHAR(10), N' ')
FROM   sys.check_constraints cc
JOIN   sys.tables t ON t.object_id = cc.parent_object_id
JOIN   sys.schemas s ON s.schema_id = t.schema_id
JOIN   @sch f ON f.name = s.name
ORDER BY line;

/* ── V + P + N + G: view, procedure, function, trigger ──────────────── */
SELECT line =
    CASE o.type WHEN N'V' THEN N'V|'
                WHEN N'P' THEN N'P|'
                WHEN N'TR' THEN N'G|'
                ELSE N'N|' END
    + s.name + N'.' + o.name
    + CASE WHEN o.type IN (N'FN', N'IF', N'TF')
           THEN N'|' + CASE o.type WHEN N'FN' THEN N'SCALAR' ELSE N'TABLE' END
           ELSE N'' END
    + CASE WHEN o.type = N'TR'
           THEN N'|' + OBJECT_SCHEMA_NAME(o.parent_object_id) + N'.'
                     + OBJECT_NAME(o.parent_object_id)
           ELSE N'' END
    + N'|dong=' + CAST(
        (LEN(ISNULL(m.definition, N'')) - LEN(REPLACE(ISNULL(m.definition, N''), CHAR(10), N'')) + 1)
        AS nvarchar(10))
FROM   sys.objects o
JOIN   sys.schemas s ON s.schema_id = o.schema_id
JOIN   @sch f ON f.name = s.name
LEFT JOIN sys.sql_modules m ON m.object_id = o.object_id
WHERE  o.type IN (N'V', N'P', N'FN', N'IF', N'TF', N'TR')
ORDER BY line;

/* ── Số dòng từng bảng: để biết bảng nào rỗng (mất dữ liệu) ─────────── */
SELECT line = N'R|' + s.name + N'.' + t.name + N'|'
            + CAST(ISNULL(SUM(ps.row_count), 0) AS nvarchar(20))
FROM   sys.tables t
JOIN   sys.schemas s ON s.schema_id = t.schema_id
JOIN   @sch f ON f.name = s.name
LEFT JOIN sys.dm_db_partition_stats ps ON ps.object_id = t.object_id
                                      AND ps.index_id IN (0, 1)
GROUP BY s.name, t.name
ORDER BY line;

PRINT N'';
PRINT N'### HET. Neu ban can them than cua view/function/procedure thi';
PRINT N'### chay export_schema_swms.sql (xuat nguyen van dinh nghia).';
