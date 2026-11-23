/* =====================================================================
   CHÈN CA KIỂM KÊ SÁNG VÀO MỘT PHIẾU ĐÃ CÓ SẴN
   soạn 20/11/2026 · chạy lại nhiều lần được

   KHÁC `dummy_stocktake_morning.sql` CHỖ NÀO
   File kia dựng ĐIỀU KIỆN (pallet + sự kiện kho) rồi để anh tự bấm tạo
   phiếu, nên phụ thuộc vào việc tạo phiếu đúng ngày. File này ghi THẲNG
   các dòng vào một phiếu đang có, nên:
     · không phụ thuộc ngày tạo phiếu, không phụ thuộc cửa sổ sự kiện;
     · nhưng KHÔNG kiểm được phần sinh phiếu (MorningSql) — chỉ kiểm phần
       HIỂN THỊ: Web hiện 4 dòng, PDA hiện 1, tiến độ tính theo dòng phải
       đếm, và số lượng ra số thật.
   Muốn kiểm cả khâu sinh phiếu thì dùng file kia.

   CHÈN GÌ

     Ô A  — 4 pallet, 4 model khác nhau, mỗi pallet 2 thùng × 5 = 10 cái
            · 3 dòng is_required = 0  (nằm sẵn ở ô từ trước)
            · 1 dòng is_required = 1  (coi như hôm qua mới chuyển vào)

     Ô B  — 1 dòng Ô TRỐNG (lot_id NULL), is_required = 1
            (ô đã chuyển đi hết, người kiểm ra xác nhận rỗng thật)

   MONG ĐỢI SAU KHI CHẠY
     Web  : ô A hiện 4 dòng, 3 dòng mang nhãn "không cần kiểm";
            bấm nút lọc thì còn 1. Ô B hiện 1 dòng.
     PDA  : ô A hiện 1 dòng, ô B hiện 1 dòng. Cột số là 10, không phải 2.
     Tiến độ phiếu tăng thêm 2 vào mẫu số (không phải 5).

   ⚠ Chạy `stocktake_is_required.sql` TRƯỚC và deploy API bản mới.

   ⚠ CHỐT AN TOÀN: từ chối chạy nếu DB không có đuôi _DEV.

   Dấu nhận diện: dòng kiểm kê có note bắt đầu bằng "[dummy-stk]",
   pallet có created_by = N'dummy-stk'. (Bảng dòng kiểm kê dùng
   created_by kiểu bigint = id người dùng, không nhét được chữ, nên dấu
   phải nằm ở note.)
   ===================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF RIGHT(DB_NAME(), 4) <> N'_DEV'
BEGIN
    DECLARE @dbn sysname = DB_NAME();
    RAISERROR(N'DUNG LAI: dang o DB [%s], khong phai DB co duoi _DEV.', 16, 1, @dbn);
    SET NOEXEC ON;
END
GO

IF COL_LENGTH(N'wms.inventory_count_lines', N'is_required') IS NULL
BEGIN
    RAISERROR(N'Chua co cot is_required. Chay stocktake_is_required.sql truoc.', 16, 1);
    SET NOEXEC ON;
END
GO

/* =====================================================================
   MỤC 0 — THAM SỐ · CHỌN PHIẾU · CHỌN Ô
   ===================================================================== */
IF OBJECT_ID('tempdb..#c') IS NOT NULL DROP TABLE #c;
CREATE TABLE #c
(
    what_if  bit,
    doc_no   nvarchar(50),   -- phiếu chỉ định; NULL = tự chọn
    doc_id   bigint,
    doc_type nvarchar(20),
    doc_stat nvarchar(20),
    tpl      bigint,
    cat      int,
    locA bigint, codeA nvarchar(50),
    locB bigint, codeB nvarchar(50),
    m1 nvarchar(100), m2 nvarchar(100), m3 nvarchar(100), m4 nvarchar(100),
    tok char(10)
);

INSERT INTO #c (what_if, doc_no, tok)
VALUES (1,                      /* <<<<< ĐỔI THÀNH 0 ĐỂ GHI THẬT */

        /* SỐ PHIẾU muốn chèn vào, vd N'KK-20261120-001'.
           Để NULL thì tự lấy phiếu SÁNG mới nhất chưa đóng. */
        NULL,

        FORMAT(SYSDATETIME(), N'MMddHHmmss'));
GO

/* ---- chọn phiếu ---- */
UPDATE c SET c.doc_id = d.id, c.doc_no = d.doc_no, c.doc_type = d.count_type, c.doc_stat = d.doc_status
FROM #c c
CROSS APPLY (
    SELECT TOP 1 x.id, x.doc_no, x.count_type, x.doc_status
    FROM   wms.inventory_counts x
    WHERE  x.is_deleted = 0
      AND  (c.doc_no IS NULL OR x.doc_no = c.doc_no)
      /* Tự chọn thì chỉ nhận phiếu SÁNG chưa đóng — chèn vào phiếu đã
         đóng là sửa sổ đã chốt, còn phiếu cuối tháng thì is_required = 0
         không có nghĩa (phiếu đó kiểm hết). */
      AND  (c.doc_no IS NOT NULL
            OR (x.count_type = N'morning' AND x.doc_status <> N'closed'))
    ORDER BY x.count_date DESC, x.id DESC
) d;

IF EXISTS (SELECT 1 FROM #c WHERE doc_id IS NULL)
BEGIN
    PRINT N'KHONG tim duoc phieu phu hop. Danh sach phieu dang co:';
    SELECT TOP (20) doc_no, count_type, count_date, doc_status,
           so_dong = (SELECT COUNT(*) FROM wms.inventory_count_lines l
                      WHERE l.count_id = c.id AND l.is_deleted = 0)
    FROM   wms.inventory_counts c
    WHERE  c.is_deleted = 0
    ORDER BY c.count_date DESC, c.id DESC;
    RAISERROR(N'Chon mot doc_no o tren roi khai vao MUC 0.', 16, 1);
    SET NOEXEC ON;
END
GO

/* ---- khuôn pallet, category, 4 model ---- */
UPDATE #c SET tpl = COALESCE(
    (SELECT TOP 1 id FROM wms.pallets WHERE is_deleted = 0 AND category_id IS NOT NULL ORDER BY id DESC),
    (SELECT TOP 1 id FROM wms.pallets WHERE is_deleted = 0 ORDER BY id DESC));
UPDATE c SET c.cat = COALESCE(p.category_id,
                              (SELECT TOP 1 code FROM master.categories WHERE is_deleted = 0 ORDER BY code))
FROM #c c JOIN wms.pallets p ON p.id = c.tpl;

UPDATE #c SET
    m1 = (SELECT code FROM (SELECT code, rn = ROW_NUMBER() OVER (ORDER BY code) FROM master.models WHERE is_deleted = 0) z WHERE rn = 1),
    m2 = (SELECT code FROM (SELECT code, rn = ROW_NUMBER() OVER (ORDER BY code) FROM master.models WHERE is_deleted = 0) z WHERE rn = 2),
    m3 = (SELECT code FROM (SELECT code, rn = ROW_NUMBER() OVER (ORDER BY code) FROM master.models WHERE is_deleted = 0) z WHERE rn = 3),
    m4 = (SELECT code FROM (SELECT code, rn = ROW_NUMBER() OVER (ORDER BY code) FROM master.models WHERE is_deleted = 0) z WHERE rn = 4);
UPDATE #c SET m4 = ISNULL(m4, m1), m3 = ISNULL(m3, m1), m2 = ISNULL(m2, m1);

/* ---- hai ô: thuộc khu storing, ĐANG RỖNG, và CHƯA có trong phiếu ----
   Chưa có trong phiếu là điều kiện quan trọng: trùng ô thì phiếu ra hai
   nhóm dòng cho cùng một ô và không còn đọc được là "4 dòng / 1 phải đếm". */
IF OBJECT_ID('tempdb..#free') IS NOT NULL DROP TABLE #free;
SELECT TOP (2) l.id, l.locator_code, rn = ROW_NUMBER() OVER (ORDER BY l.locator_code)
INTO   #free
FROM   master.locators l
JOIN   master.warehouse_areas a ON a.id = l.area_id AND a.is_deleted = 0 AND a.map_type = N'storing'
WHERE  l.is_deleted = 0
  AND  NOT EXISTS (SELECT 1 FROM wms.pallets p WHERE p.locator_id = l.id AND p.is_deleted = 0)
  AND  NOT EXISTS (SELECT 1 FROM wms.inventory_count_lines cl
                   JOIN #c c ON c.doc_id = cl.count_id
                   WHERE cl.locator_id = l.id AND cl.is_deleted = 0)
ORDER BY l.locator_code;

UPDATE c SET c.locA = a.id, c.codeA = a.locator_code FROM #c c JOIN #free a ON a.rn = 1;
UPDATE c SET c.locB = b.id, c.codeB = b.locator_code FROM #c c JOIN #free b ON b.rn = 2;

SELECT ghi_that = IIF(what_if = 1, N'KHONG — dang xem truoc', N'CO'),
       phieu = doc_no, loai = doc_type, trang_thai = doc_stat,
       o_A = codeA, o_B = codeB,
       model_1 = m1, model_2 = m2, model_3 = m3, model_4 = m4,
       so_dong_phieu_hien_tai = (SELECT COUNT(*) FROM wms.inventory_count_lines l
                                 JOIN #c c2 ON c2.doc_id = l.count_id
                                 WHERE l.is_deleted = 0)
FROM #c;

IF EXISTS (SELECT 1 FROM #c WHERE locA IS NULL OR locB IS NULL)
BEGIN
    RAISERROR(N'Khong tim duoc 2 o trong thuoc khu storing va chua co trong phieu.', 16, 1);
    SET NOEXEC ON;
END
IF EXISTS (SELECT 1 FROM #c WHERE doc_stat = N'closed')
    PRINT N'⚠ Phieu nay DA DONG — chen vao se sua so da chot. Can nhac chon phieu khac.';
IF EXISTS (SELECT 1 FROM #c WHERE doc_type <> N'morning')
    PRINT N'⚠ Phieu nay KHONG phai loai morning. Dong is_required = 0 chi co nghia o phieu sang; PDA se an chung ma Web khong gan nhan.';
GO

IF (SELECT what_if FROM #c) = 1
BEGIN
    PRINT N'';
    PRINT N'=== DANG XEM TRUOC. Doi @WhatIf = 0 o MUC 0 roi chay lai. ===';
    SET NOEXEC ON;
END
GO

/* =====================================================================
   MỤC 1 — DỌN DUMMY CŨ CỦA FILE NÀY
   ===================================================================== */
DELETE cl
  FROM wms.inventory_count_lines cl
 WHERE cl.note LIKE N'%dummy-stk%';

DELETE bl FROM wms.box_lines bl
  JOIN wms.boxes b   ON b.id = bl.box_id
  JOIN wms.pallets p ON p.id = b.lot_id
 WHERE p.created_by = N'dummy-stk';
DELETE b FROM wms.boxes b
  JOIN wms.pallets p ON p.id = b.lot_id
 WHERE p.created_by = N'dummy-stk';
DELETE e FROM wms.stock_events e
  JOIN wms.pallets p ON p.id = e.pallet_id
 WHERE p.created_by = N'dummy-stk';
UPDATE wms.pallets
   SET is_deleted = 1, locator_id = NULL, updated_at = SYSDATETIME(), updated_by = N'dummy-stk'
 WHERE created_by = N'dummy-stk' AND is_deleted = 0;
PRINT N'1. Da don dummy cu.';
GO

/* =====================================================================
   MỤC 2 — BỐN PALLET Ở Ô A + THÙNG
   ===================================================================== */
IF OBJECT_ID('tempdb..#p') IS NOT NULL DROP TABLE #p;
CREATE TABLE #p
(
    rn int IDENTITY(1,1) PRIMARY KEY,
    nhan varchar(10), model nvarchar(100), req bit,
    pallet_id char(12) NULL, pal_db bigint NULL
);
INSERT INTO #p (nhan, model, req)
SELECT v.nhan, v.model, v.req
FROM #c c
CROSS APPLY (VALUES
 ('A-cu-1', c.m1, CAST(0 AS bit)),
 ('A-cu-2', c.m2, 0),
 ('A-cu-3', c.m3, 0),
 ('A-moi',  c.m4, 1)
) v(nhan, model, req);

UPDATE p SET p.pallet_id = LEFT(c.tok, 10) + RIGHT(N'0' + CAST(p.rn AS varchar(2)), 2)
FROM #p p CROSS JOIN #c c;
GO

DECLARE @ovr TABLE (col sysname PRIMARY KEY, val nvarchar(200), want_null bit);
INSERT INTO @ovr VALUES
 (N'pallet_id',        N'@pid',          0),
 (N'category_id',      N'@cat',          0),
 (N'model',            N'@model',        0),
 (N'box_count',        N'2',             0),
 (N'detail_level',     N'N''serial''',   0),
 (N'lot_type',         N'N''pallet''',   0),
 (N'stocky_code',      NULL,             1),
 (N'si_no',            NULL,             1),
 (N'locator_id',       N'@loc',          0),
 (N'inspection_status',N'N''pass''',     0),
 (N'disposition',      NULL,             1),
 (N'is_urgent',        N'0',             0),
 (N'sap_status',       NULL,             1),
 (N'sap_pushed_at',    NULL,             1),
 (N'is_deleted',       N'0',             0),
 (N'created_at',       N'SYSDATETIME()', 0),
 (N'created_by',       N'N''dummy-stk''',0),
 (N'updated_at',       NULL,             1),
 (N'updated_by',       NULL,             1);

DECLARE @collist nvarchar(max) = N'', @vallist nvarchar(max) = N'';
SELECT @collist = @collist + CASE WHEN @collist = N'' THEN N'' ELSE N', ' END + QUOTENAME(c.name),
       @vallist = @vallist + CASE WHEN @vallist = N'' THEN N'' ELSE N', ' END
                 + CASE WHEN o.col IS NULL     THEN N't.' + QUOTENAME(c.name)
                        WHEN o.want_null = 0   THEN o.val
                        WHEN c.is_nullable = 1 THEN N'NULL'
                        ELSE ISNULL(dc.definition, N't.' + QUOTENAME(c.name)) END
FROM   sys.columns c
LEFT   JOIN @ovr o ON o.col = c.name
LEFT   JOIN sys.default_constraints dc ON dc.parent_object_id = c.object_id AND dc.parent_column_id = c.column_id
WHERE  c.object_id = OBJECT_ID(N'wms.pallets')
   AND c.is_identity = 0 AND c.is_computed = 0 AND c.generated_always_type = 0
ORDER BY c.column_id;

DECLARE @ins nvarchar(max) =
    N'INSERT INTO wms.pallets (' + @collist + N') SELECT ' + @vallist +
    N' FROM wms.pallets t WHERE t.id = @tpl; SELECT @out = CAST(SCOPE_IDENTITY() AS bigint);';

DECLARE @tpl bigint, @cat int, @locA bigint;
SELECT @tpl = tpl, @cat = cat, @locA = locA FROM #c;
DECLARE @rn int = 1, @max int = (SELECT MAX(rn) FROM #p);
DECLARE @pid char(12), @model nvarchar(100), @new bigint;

WHILE @rn <= @max
BEGIN
    SELECT @pid = pallet_id, @model = model FROM #p WHERE rn = @rn;
    EXEC sp_executesql @ins,
         N'@tpl bigint, @pid char(12), @cat int, @model nvarchar(100), @loc bigint, @out bigint OUTPUT',
         @tpl = @tpl, @pid = @pid, @cat = @cat, @model = @model, @loc = @locA, @out = @new OUTPUT;
    UPDATE #p SET pal_db = @new WHERE rn = @rn;
    SET @rn += 1;
END
PRINT CONCAT(N'2. Da tao ', @max, N' pallet o o A.');
GO

/* Mỗi pallet 2 thùng × 5 cái = 10 cái THẬT — đây là thứ kiểm bản sửa
   qty_system: màn kiểm kê phải hiện 10, không phải 2 (số thùng). */
INSERT INTO wms.boxes (lot_id, box_no, is_deleted, created_at)
SELECT p.pal_db, p.pallet_id + N'-B' + CAST(n.i AS varchar(2)), 0, SYSDATETIME()
FROM   #p p CROSS JOIN (VALUES (1),(2)) n(i);

INSERT INTO wms.box_lines (box_id, model, qty, is_deleted, created_at)
SELECT b.id, p.model, 5, 0, SYSDATETIME()
FROM   wms.boxes b JOIN #p p ON p.pal_db = b.lot_id
WHERE  b.is_deleted = 0;
PRINT N'2b. Da tao 2 thung x 5 cai moi pallet.';
GO

/* =====================================================================
   MỤC 3 — SỰ KIỆN KHO CHO PALLET "MỚI VÀO"
   ---------------------------------------------------------------------
   Không bắt buộc cho việc hiển thị (is_required đã là cột lưu sẵn), nhưng
   ghi vào thì dữ liệu mới nhất quán: nếu sau này ai dựng lại phiếu sáng
   cho đúng ngày đó, họ sẽ ra cùng kết quả. event_at đặt 12:00 ngày trước
   count_date của phiếu, tức đúng cửa sổ phiếu đó đại diện.
   ===================================================================== */
INSERT INTO wms.stock_events
    (subject_type, pallet_id, pallet_code, event_code, event_at, actor, source,
     from_locator_id, from_locator_code, from_map_type,
     to_locator_id,   to_locator_code,   to_map_type, note)
SELECT N'pallet', p.pal_db, p.pallet_id, 'STORAGE_MOVED',
       DATEADD(HOUR, 12, CAST(DATEADD(DAY, -1, d.count_date) AS datetime2(0))),
       N'dummy-stk', 'WEB',
       c.locB, c.codeB, 'storing',
       c.locA, c.codeA, 'storing',
       N'[dummy-stk] ' + c.codeB + N' -> ' + c.codeA
FROM #p p
CROSS JOIN #c c
JOIN wms.inventory_counts d ON d.id = c.doc_id
WHERE p.req = 1;
PRINT N'3. Da ghi 1 su kien STORAGE_MOVED.';
GO

/* =====================================================================
   MỤC 4 — CHÈN 5 DÒNG VÀO PHIẾU
   ---------------------------------------------------------------------
   qty_system / standard_packing tính y hệt QtyColumns của API sau khi
   sửa: SỐ THẬT trước, box × quy cách chỉ là đường lùi.
   ===================================================================== */
IF OBJECT_ID('tempdb..#ln') IS NOT NULL DROP TABLE #ln;

/* 4 dòng của ô A */
SELECT  locator_id = c.locA,
        lot_id     = p.pal_db,
        product_id = CAST(c.cat AS bigint),
        qty_system = CASE WHEN ISNULL(bx.qty, 0) > 0 THEN bx.qty
                          WHEN ISNULL(mdl.standard_packing, 0) > 0
                               THEN 2 * mdl.standard_packing
                          ELSE 0 END,
        box_count_system = 2,
        standard_packing = CASE WHEN ISNULL(bx.qty, 0) > 0 AND bx.qty % 2 = 0 THEN bx.qty / 2
                                WHEN ISNULL(mdl.standard_packing, 0) > 0 THEN mdl.standard_packing
                                ELSE NULL END,
        is_required = p.req,
        note = N'[dummy-stk] ' + p.nhan
          + IIF(p.req = 1, N' · hom qua moi chuyen vao', N' · nam san tu truoc'),
        ord = p.rn
INTO    #ln
FROM    #p p
CROSS   JOIN #c c
OUTER   APPLY (SELECT TOP 1 m.standard_packing FROM master.models m
               WHERE m.code = p.model AND m.is_deleted = 0 ORDER BY m.id) mdl
OUTER   APPLY (SELECT SUM(bl.qty) AS qty
               FROM wms.boxes b
               JOIN wms.box_lines bl ON bl.box_id = b.id AND bl.is_deleted = 0
               WHERE b.lot_id = p.pal_db AND b.is_deleted = 0) bx;

/* 1 dòng ô trống của ô B */
INSERT INTO #ln (locator_id, lot_id, product_id, qty_system, box_count_system,
                 standard_packing, is_required, note, ord)
SELECT c.locB, NULL, NULL, 0, NULL, NULL, 1,
       N'[dummy-stk] o B · da chuyen di het, xac nhan o trong', 99
FROM #c c;

INSERT INTO wms.inventory_count_lines
    (count_id, line_no, product_id, locator_id, lot_id,
     qty_system, qty_count, is_adjusted,
     box_count_system, box_count_counted, standard_packing,
     is_required, note,
     created_at, updated_at, is_deleted)
SELECT  c.doc_id,
        base.mx + ROW_NUMBER() OVER (ORDER BY n.ord),
        n.product_id, n.locator_id, n.lot_id,
        n.qty_system, NULL, 0,
        n.box_count_system, NULL, n.standard_packing,
        n.is_required, n.note,
        SYSDATETIME(), SYSDATETIME(), 0
FROM    #ln n
CROSS   JOIN #c c
CROSS   APPLY (SELECT mx = ISNULL(MAX(l.line_no), 0)
               FROM wms.inventory_count_lines l
               WHERE l.count_id = c.doc_id) base;
PRINT N'4. Da chen 5 dong vao phieu.';
GO

/* =====================================================================
   MỤC 5 — BẢNG KIỂM
   ===================================================================== */
PRINT N'--- 5a. Nam dong vua chen ---';
SELECT  phieu = d.doc_no,
        o     = l.locator_code,
        pallet_id = p.pallet_id,
        model     = p.model,
        so_thung  = cl.box_count_system,
        qty_he_thong = cl.qty_system,
        quy_cach  = cl.standard_packing,
        phai_dem  = IIF(cl.is_required = 1, N'CO', N'khong'),
        cl.note
FROM    wms.inventory_count_lines cl
JOIN    wms.inventory_counts d ON d.id = cl.count_id
JOIN    master.locators l ON l.id = cl.locator_id
LEFT    JOIN wms.pallets p ON p.id = cl.lot_id
WHERE   cl.note LIKE N'%dummy-stk%' AND cl.is_deleted = 0
ORDER BY l.locator_code, cl.line_no;

PRINT N'';
PRINT N'--- 5b. Tien do phieu sau khi chen ---';
SELECT  phieu = d.doc_no, loai = d.count_type, trang_thai = d.doc_status,
        tong_so_dong = a.total,
        dong_phai_dem = a.req,
        da_dem_trong_so_phai_dem = a.req_counted,
        phan_tram_PDA_va_Web_se_hien =
            IIF(a.req = 0, 0, CAST(ROUND(100.0 * a.req_counted / a.req, 0) AS int))
FROM    wms.inventory_counts d
JOIN    #c c ON c.doc_id = d.id
CROSS   APPLY (
    SELECT  total = COUNT(*),
            req   = SUM(CASE WHEN cl.is_required = 1 THEN 1 ELSE 0 END),
            req_counted = SUM(CASE WHEN cl.is_required = 1 AND cl.qty_count IS NOT NULL THEN 1 ELSE 0 END)
    FROM    wms.inventory_count_lines cl
    WHERE   cl.count_id = d.id AND cl.is_deleted = 0
) a;

PRINT N'';
PRINT N'===== XONG =====';
PRINT N'Mong doi tren 5a: o A ra 4 dong (3 "khong", 1 "CO"), o B ra 1 dong "CO".';
PRINT N'Cot qty_he_thong phai la 10 o ca 4 dong cua o A — khong phai 2.';
PRINT N'Web: o A hien 4 dong, 3 dong co nhan "khong can kiem".';
PRINT N'PDA: o A hien 1 dong, o B hien 1 dong.';
GO

SET NOEXEC OFF;
GO
