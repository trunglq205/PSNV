/* =====================================================================
   DUMMY KIỂM KÊ BUỔI SÁNG — HAI Ô, ĐÚNG CA ANH MÔ TẢ
   soạn 20/11/2026 · chạy lại nhiều lần được

   DỰNG RA CÁI GÌ

     Ô A  — 4 pallet, 4 model khác nhau
            · 3 pallet đã nằm đó TỪ TRƯỚC, không có sự kiện kho hôm qua
            · 1 pallet CHUYỂN VÀO hôm qua
            => phiếu sáng ra 4 dòng, CHỈ 1 dòng phải đếm
            => Web hiện 4 (3 dòng mang nhãn "không cần kiểm")
               PDA hiện 1

     Ô B  — rỗng, vì chính pallet kia hôm qua đã rời khỏi đây
            => phiếu sáng ra 1 dòng Ô TRỐNG, và dòng đó PHẢI đếm
               (người đi kiểm xác nhận ô rỗng thật)

   Chỉ cần MỘT sự kiện kho: pallet thứ 4 đi từ ô B sang ô A hôm qua. Sự
   kiện đó vừa đưa ô A vào phiếu (to_locator_id = A) vừa đưa ô B vào phiếu
   (from_locator_id = B) — đúng khuôn ChangedLocatorsSql đang dùng.

   Mỗi pallet có 2 thùng × 5 cái = 10 cái THẬT. Nhờ vậy kiểm luôn được
   bản sửa qty_system: màn kiểm kê phải hiện 10, không phải 2 (số thùng)
   và cũng không phải 2 × quy cách khai trong danh mục.

   CÁCH CHẠY
     1. Để @WhatIf = 1, chạy một lượt — xem nó chọn ô nào, xoá gì.
     2. Đổi @WhatIf = 0 ở MỤC 0, chạy lại.
     3. Đọc MỤC 5: nó in ra ĐÚNG những gì phiếu sáng sẽ sinh.
     4. Vào Web bấm tạo phiếu kiểm kê BUỔI SÁNG, rồi đối chiếu với MỤC 5.

   ⚠ Chạy `stocktake_is_required.sql` TRƯỚC file này, và deploy API bản
     mới — thiếu cột is_required thì không có gì để kiểm.

   ⚠ CHỐT AN TOÀN: từ chối chạy nếu DB không có đuôi _DEV.

   Dấu nhận diện: created_by = N'dummy-stk' (khác N'dummy' của
   dummy_three_features.sql, nên hai bộ không đụng nhau).
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
    PRINT N'⚠ Chua co cot is_required — chay stocktake_is_required.sql truoc, khong thi khong kiem duoc gi.';
GO

/* =====================================================================
   MỤC 0 — THAM SỐ · CHỌN Ô VÀ KHUÔN
   ===================================================================== */
IF OBJECT_ID('tempdb..#c') IS NOT NULL DROP TABLE #c;
CREATE TABLE #c
(
    what_if bit,
    tpl     bigint,        -- pallet làm khuôn nhân bản
    cat     int,
    locA    bigint, codeA nvarchar(50),
    locB    bigint, codeB nvarchar(50),
    m1 nvarchar(100), m2 nvarchar(100), m3 nvarchar(100), m4 nvarchar(100),
    tok char(10)
);
INSERT INTO #c (what_if, tok)
VALUES (1,                              /* <<<<< ĐỔI THÀNH 0 ĐỂ GHI THẬT */
        FORMAT(SYSDATETIME(), N'MMddHHmmss'));
GO

/* Khuôn pallet + category: lấy của một pallet thật để mọi cột NOT NULL
   mà script không biết đều tự hợp lệ. */
UPDATE #c SET tpl = COALESCE(
    (SELECT TOP 1 id FROM wms.pallets WHERE is_deleted = 0 AND category_id IS NOT NULL ORDER BY id DESC),
    (SELECT TOP 1 id FROM wms.pallets WHERE is_deleted = 0 ORDER BY id DESC));
UPDATE c SET c.cat = COALESCE(p.category_id,
                              (SELECT TOP 1 code FROM master.categories WHERE is_deleted = 0 ORDER BY code))
FROM #c c JOIN wms.pallets p ON p.id = c.tpl;

/* 4 model khác nhau — để trên màn hình nhìn ra 4 dòng khác nhau thật. */
UPDATE #c SET
    m1 = (SELECT code FROM (SELECT code, rn = ROW_NUMBER() OVER (ORDER BY code) FROM master.models WHERE is_deleted = 0) z WHERE rn = 1),
    m2 = (SELECT code FROM (SELECT code, rn = ROW_NUMBER() OVER (ORDER BY code) FROM master.models WHERE is_deleted = 0) z WHERE rn = 2),
    m3 = (SELECT code FROM (SELECT code, rn = ROW_NUMBER() OVER (ORDER BY code) FROM master.models WHERE is_deleted = 0) z WHERE rn = 3),
    m4 = (SELECT code FROM (SELECT code, rn = ROW_NUMBER() OVER (ORDER BY code) FROM master.models WHERE is_deleted = 0) z WHERE rn = 4);
UPDATE #c SET m4 = ISNULL(m4, m1), m3 = ISNULL(m3, m1), m2 = ISNULL(m2, m1);

/* Hai ô thuộc bản đồ 'storing' và ĐANG KHÔNG CÓ pallet nào — phải rỗng
   sẵn, nếu không thì ô A có thêm pallet thật và không còn đếm được là
   "4 dòng, 1 phải đếm" nữa. */
IF OBJECT_ID('tempdb..#free') IS NOT NULL DROP TABLE #free;
SELECT TOP (2) l.id, l.locator_code, rn = ROW_NUMBER() OVER (ORDER BY l.locator_code)
INTO   #free
FROM   master.locators l
JOIN   master.warehouse_areas a ON a.id = l.area_id AND a.is_deleted = 0 AND a.map_type = N'storing'
WHERE  l.is_deleted = 0
  AND  NOT EXISTS (SELECT 1 FROM wms.pallets p WHERE p.locator_id = l.id AND p.is_deleted = 0)
ORDER BY l.locator_code;

UPDATE c SET c.locA = a.id, c.codeA = a.locator_code FROM #c c JOIN #free a ON a.rn = 1;
UPDATE c SET c.locB = b.id, c.codeB = b.locator_code FROM #c c JOIN #free b ON b.rn = 2;

SELECT ghi_that = IIF(what_if = 1, N'KHONG — dang xem truoc', N'CO'),
       khuon_pallet = tpl, category = cat,
       o_A = codeA, o_B = codeB,
       model_1 = m1, model_2 = m2, model_3 = m3, model_4 = m4
FROM #c;

IF EXISTS (SELECT 1 FROM #c WHERE locA IS NULL OR locB IS NULL)
BEGIN
    RAISERROR(N'Khong tim duoc 2 o trong thuoc khu storing. Don bot pallet o mot vai o roi chay lai.', 16, 1);
    SET NOEXEC ON;
END
GO

/* Từ đây chỉ chạy khi @WhatIf = 0. NOEXEC vẫn BIÊN DỊCH nên sai cú pháp
   hay sai tên cột vẫn lộ ra ngay ở lượt xem trước. */
IF (SELECT what_if FROM #c) = 1
BEGIN
    PRINT N'';
    PRINT N'=== DANG XEM TRUOC. Doi @WhatIf = 0 o MUC 0 roi chay lai. ===';
    SET NOEXEC ON;
END
GO

/* =====================================================================
   MỤC 1 — XOÁ DUMMY CŨ CỦA CHÍNH FILE NÀY
   ---------------------------------------------------------------------
   Sự kiện kho và dòng thùng xoá HẲN; pallet xoá MỀM (wms.boxes và
   stock_events đều có khoá ngoại sang wms.pallets).
   ===================================================================== */
DELETE bl FROM wms.box_lines bl
  JOIN wms.boxes b ON b.id = bl.box_id
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
   MỤC 2 — BỐN PALLET Ở Ô A
   ===================================================================== */
IF OBJECT_ID('tempdb..#p') IS NOT NULL DROP TABLE #p;
CREATE TABLE #p
(
    rn int IDENTITY(1,1) PRIMARY KEY,
    nhan      varchar(10),
    model     nvarchar(100),
    moved     bit,               -- 1 = pallet chuyển vào hôm qua
    pallet_id char(12) NULL,
    pal_db    bigint NULL
);
INSERT INTO #p (nhan, model, moved)
SELECT v.nhan, v.model, v.moved
FROM #c c
CROSS APPLY (VALUES
 ('A-cu-1', c.m1, CAST(0 AS bit)),
 ('A-cu-2', c.m2, 0),
 ('A-cu-3', c.m3, 0),
 ('A-moi',  c.m4, 1)      -- pallet thứ 4: hôm qua từ ô B sang ô A
) v(nhan, model, moved);

UPDATE p SET p.pallet_id = LEFT(c.tok, 10) + RIGHT(N'0' + CAST(p.rn AS varchar(2)), 2)
FROM #p p CROSS JOIN #c c;
GO

/* ---- nhân bản khuôn: dựng câu INSERT theo ĐÚNG cột đang có ---- */
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
                 + CASE WHEN o.col IS NULL     THEN N't.' + QUOTENAME(c.name)   -- không khai -> copy khuôn
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
         N'@tpl bigint, @pid char(12), @cat int, @model nvarchar(100),
           @loc bigint, @out bigint OUTPUT',
         @tpl = @tpl, @pid = @pid, @cat = @cat, @model = @model,
         @loc = @locA, @out = @new OUTPUT;
    UPDATE #p SET pal_db = @new WHERE rn = @rn;
    SET @rn += 1;
END
PRINT CONCAT(N'2. Da tao ', @max, N' pallet o o A.');
GO

/* ---- 2b. Mỗi pallet 2 thùng × 5 cái = 10 cái THẬT ----
   Đây là thứ kiểm bản sửa qty_system: màn kiểm kê phải hiện 10. */
INSERT INTO wms.boxes (lot_id, box_no, is_deleted, created_at)
SELECT p.pal_db, p.pallet_id + N'-B' + CAST(n.i AS varchar(2)), 0, SYSDATETIME()
FROM   #p p
CROSS  JOIN (VALUES (1),(2)) n(i);

INSERT INTO wms.box_lines (box_id, model, qty, is_deleted, created_at)
SELECT b.id, p.model, 5, 0, SYSDATETIME()
FROM   wms.boxes b
JOIN   #p p ON p.pal_db = b.lot_id
WHERE  b.is_deleted = 0;
PRINT N'2b. Da tao 2 thung x 5 cai cho moi pallet (10 cai/pallet).';
GO

/* =====================================================================
   MỤC 3 — MỘT SỰ KIỆN KHO HÔM QUA: Ô B  ->  Ô A
   ---------------------------------------------------------------------
   event_at đặt GIỮA ngày hôm qua (12:00) cho chắc nằm trong cửa sổ
   [hôm qua 00:00, hôm nay 00:00) mà phiếu sáng dùng — đặt đúng mốc
   nửa đêm là dễ lọt ra ngoài vì so sánh một đầu đóng một đầu mở.

   Sự kiện này làm hai việc một lúc:
     from_locator_id = ô B  ->  ô B vào phiếu (và giờ đã rỗng)
     to_locator_id   = ô A  ->  ô A vào phiếu
   ===================================================================== */
INSERT INTO wms.stock_events
    (subject_type, pallet_id, pallet_code, event_code, event_at, actor, source,
     from_locator_id, from_locator_code, from_map_type,
     to_locator_id,   to_locator_code,   to_map_type,
     note)
SELECT N'pallet', p.pal_db, p.pallet_id, 'STORAGE_MOVED',
       DATEADD(HOUR, 12, CAST(DATEADD(DAY, -1, CAST(SYSDATETIME() AS date)) AS datetime2(0))),
       N'dummy-stk', 'WEB',
       c.locB, c.codeB, 'storing',
       c.locA, c.codeA, 'storing',
       N'[dummy-stk] chuyen tu ' + c.codeB + N' sang ' + c.codeA + N' hom qua'
FROM #p p CROSS JOIN #c c
WHERE p.moved = 1;
PRINT N'3. Da ghi 1 su kien STORAGE_MOVED (hom qua 12:00).';
GO

/* =====================================================================
   MỤC 4 — DỌN SỰ KIỆN HÔM QUA CỦA PALLET THẬT Ở HAI Ô NÀY
   ---------------------------------------------------------------------
   Không có gì để dọn: MỤC 0 đã chọn hai ô ĐANG RỖNG. Để lại chú thích
   này để lần sau không ai đi tìm xem thiếu bước nào.
   ===================================================================== */

/* =====================================================================
   MỤC 5 — PHIẾU SÁNG SẼ SINH RA ĐÚNG NHỮNG DÒNG NÀY
   ---------------------------------------------------------------------
   Mô phỏng lại MorningSql + MorningRequiredCol của API, CHỈ ĐỌC. Bấm
   "tạo phiếu kiểm kê buổi sáng" trên Web rồi so với bảng này.
   ===================================================================== */
DECLARE @t0 datetime2(0) = CAST(CAST(SYSDATETIME() AS date) AS datetime2(0));
DECLARE @y0 datetime2(0) = DATEADD(DAY, -1, @t0);

PRINT N'--- 5a. Nhung dong phieu sang se sinh cho HAI o nay ---';
SELECT  o          = l.locator_code,
        pallet_id  = p.pallet_id,
        model      = p.model,
        so_thung   = p.box_count,
        /* Giống hệt QtyColumns sau khi sửa: SỐ THẬT trước, công thức là
           đường lùi. Cột cuối in ra con số mà code CŨ sẽ hiện, để thấy
           bản sửa có tác dụng. */
        qty_se_hien = CASE WHEN ISNULL(bx.qty, 0) > 0 THEN bx.qty
                           WHEN ISNULL(mdl.standard_packing, 0) > 0
                                THEN ISNULL(p.box_count, 0) * mdl.standard_packing
                           ELSE 0 END,
        qty_code_cu = CASE WHEN ISNULL(mdl.standard_packing, 0) > 0
                                THEN ISNULL(p.box_count, 0) * mdl.standard_packing
                           ELSE ISNULL(bx.qty, 0) END,
        quy_cach_danh_muc = mdl.standard_packing,
        phai_dem   = CASE WHEN p.id IS NULL THEN N'CO (o trong)'
                          WHEN EXISTS (SELECT 1 FROM wms.stock_events e
                                       WHERE e.event_at >= @y0 AND e.event_at < @t0
                                         AND p.id IN (e.pallet_id, e.related_pallet_id))
                               THEN N'CO'
                          ELSE N'khong' END
FROM    master.locators l
JOIN    master.warehouse_areas a ON a.id = l.area_id AND a.is_deleted = 0 AND a.map_type = N'storing'
LEFT    JOIN wms.pallets p ON p.locator_id = l.id AND p.is_deleted = 0
-- ORDER BY m.id: chép ĐÚNG PackingApply của API. Thiếu nó thì mã model
-- trùng nhau sẽ cho bảng mong đợi khác bảng thật, và lúc đối chiếu không
-- biết là code sai hay dummy sai.
OUTER   APPLY (SELECT TOP 1 m.standard_packing FROM master.models m
               WHERE m.code = p.model AND m.is_deleted = 0
               ORDER BY m.id) mdl
OUTER   APPLY (SELECT SUM(bl.qty) AS qty
               FROM wms.boxes b
               JOIN wms.box_lines bl ON bl.box_id = b.id AND bl.is_deleted = 0
               WHERE b.lot_id = p.id AND b.is_deleted = 0) bx
WHERE   l.is_deleted = 0
  AND   l.id IN (SELECT locA FROM #c UNION SELECT locB FROM #c)
ORDER BY l.locator_code, p.pallet_id;

PRINT N'';
PRINT N'--- 5b. Tong hop mong doi ---';
SELECT  o = l.locator_code,
        so_dong    = COUNT(*),
        so_phai_dem = SUM(CASE WHEN p.id IS NULL THEN 1
                               WHEN EXISTS (SELECT 1 FROM wms.stock_events e
                                            WHERE e.event_at >= @y0 AND e.event_at < @t0
                                              AND p.id IN (e.pallet_id, e.related_pallet_id))
                                    THEN 1 ELSE 0 END)
FROM    master.locators l
LEFT    JOIN wms.pallets p ON p.locator_id = l.id AND p.is_deleted = 0
WHERE   l.id IN (SELECT locA FROM #c UNION SELECT locB FROM #c)
GROUP BY l.locator_code
ORDER BY l.locator_code;

PRINT N'';
PRINT N'--- 5c. Tat ca cac o se vao phieu sang (ke ca o cua du lieu that) ---';
SELECT  tong_so_o_vao_phieu = COUNT(DISTINCT x.locator_id)
FROM (
    SELECT e.from_locator_id AS locator_id FROM wms.stock_events e
     WHERE e.event_at >= @y0 AND e.event_at < @t0 AND e.from_locator_id IS NOT NULL
    UNION
    SELECT e.to_locator_id FROM wms.stock_events e
     WHERE e.event_at >= @y0 AND e.event_at < @t0 AND e.to_locator_id IS NOT NULL
    UNION
    SELECT p2.locator_id FROM wms.stock_events e
      JOIN wms.pallets p2 ON p2.id IN (e.pallet_id, e.related_pallet_id)
     WHERE e.event_at >= @y0 AND e.event_at < @t0
       AND e.from_locator_id IS NULL AND e.to_locator_id IS NULL
       AND p2.is_deleted = 0 AND p2.locator_id IS NOT NULL
) x;

PRINT N'';
PRINT N'===== XONG =====';
PRINT N'Mong doi: o A = 4 dong / 1 phai dem · o B = 1 dong / 1 phai dem.';
PRINT N'Cot qty_se_hien phai la 10 (so that), KHONG phai 2 (so thung)';
PRINT N'va cung khong phai qty_code_cu neu hai so do khac nhau.';
PRINT N'Gio vao Web bam tao phieu kiem ke BUOI SANG roi doi chieu.';
GO

SET NOEXEC OFF;
GO
