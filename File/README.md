/* =====================================================================
   DUMMY ĐỦ MỌI TRẠNG THÁI — BA CHỨC NĂNG
     A. Chỉ thị back hàng   (16 phiếu)
     B. Hàng bất thường     (11 phiếu)
     C. Xe Stocky           ( 7 xe)
   soạn 18/11/2026 · chạy lại nhiều lần được

   ⚠ THAY THẾ `return_back_dummy.sql` (12/11). Bản cũ dựng theo thiết kế
     TRƯỚC khi tách B4/B5: không có `scs_approved`, không có `back_round`
     / `wms.return_back_rounds`, không có `kind` / `locator_code`, và
     không đụng NG lẫn Stocky. ĐỪNG chạy cả hai.

   CÁCH CHẠY
     1. Chạy nguyên file. Mặc định @WhatIf = 1: chỉ in cấu hình và những
        gì SẼ bị xoá, không ghi dòng nào.
     2. Đổi @WhatIf = 0 ở MỤC 0, chạy lại.
     3. Đọc MỤC 6 — ba bảng kiểm in ra đúng ma trận trạng thái đã dựng.

   ⚠ CHỐT AN TOÀN: từ chối chạy nếu DB không có đuôi _DEV.

   DẤU NHẬN DIỆN — mọi dòng script này ghi đều mang `created_by = N'dummy'`.
   MỤC 2 xoá CHỈ THEO DẤU ĐÓ, nên dữ liệu thật nằm cùng bảng không bao
   giờ bị đụng. Đừng đổi dấu này.

   PALLET DỰNG BẰNG CÁCH NHÂN BẢN một pallet có sẵn, không INSERT tay:
   wms.pallets có cột NOT NULL mà script không biết hết. Nhân bản một
   dòng thật rồi ghi đè đúng mấy cột cần thì cột khác tự hợp lệ, và thêm
   cột NOT NULL về sau script vẫn chạy.

   ⚠ Mã pallet và serial NHÚNG GIỜ CHẠY (MMddHHmmss). Lý do không phải
   cho đẹp: `UQ_pallets_pallet_id` là unique KHÔNG LỌC, nên pallet của
   lượt trước tuy đã xoá mềm vẫn giữ chỗ mã cũ — trùng mã là lượt sau
   chạy không được. Xem `dev_schema_findings.sql` Mục 1.
   ===================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* =====================================================================
   MỤC 0 — CHỐT AN TOÀN · THAM SỐ · TIỀN ĐỀ
   ---------------------------------------------------------------------
   Biến KHÔNG sống qua GO nên mọi thiết lập để trong #cfg.
   ===================================================================== */
IF RIGHT(DB_NAME(), 4) <> N'_DEV'
BEGIN
    DECLARE @dbn sysname = DB_NAME();
    RAISERROR(N'DUNG LAI: dang o DB [%s], khong phai DB co duoi _DEV.', 16, 1, @dbn);
    SET NOEXEC ON;
END
GO

IF OBJECT_ID('tempdb..#cfg') IS NOT NULL DROP TABLE #cfg;
CREATE TABLE #cfg
(
    what_if   bit,
    tpl       bigint,       -- pallet làm khuôn nhân bản
    cat       int,          -- mã category cho pallet dummy
    loc_store bigint,       -- ô thuộc bản đồ 'storing'
    loc_recv  bigint,       -- ô thuộc bản đồ 'receiving' = chỗ chờ FA lấy
    loc_park  bigint,       -- bãi đậu xe stocky
    loc_fa    bigint,       -- ô coi như bên FA
    m1 nvarchar(100), m2 nvarchar(100), m3 nvarchar(100),
    tok char(10)            -- MMddHHmmss, nhúng vào mã pallet / serial
);

INSERT INTO #cfg (what_if, tok)
VALUES (1,                                  /* <<<<< ĐỔI THÀNH 0 ĐỂ GHI THẬT */
        FORMAT(SYSDATETIME(), N'MMddHHmmss'));
GO

/* ---- tiền đề ---- */
IF NOT EXISTS (SELECT 1 FROM wms.pallets WHERE is_deleted = 0)
BEGIN
    RAISERROR(N'Khong co pallet nao de lam khuon. Tao 1 pallet bat ky roi chay lai.', 16, 1);
    SET NOEXEC ON;
END
GO
IF (SELECT COUNT(*) FROM master.models WHERE is_deleted = 0) < 3
BEGIN
    RAISERROR(N'Can it nhat 3 model trong master.models.', 16, 1);
    SET NOEXEC ON;
END
GO
IF NOT EXISTS (SELECT 1 FROM master.ng_types WHERE is_deleted = 0 AND is_active = 1)
BEGIN
    RAISERROR(N'master.ng_types rong — chay dev_rebuild_missing_tables.sql truoc.', 16, 1);
    SET NOEXEC ON;
END
GO

/* ---- chọn khuôn pallet, model, category, các ô ---- */
UPDATE #cfg SET tpl = COALESCE(
    (SELECT TOP 1 id FROM wms.pallets WHERE is_deleted = 0 AND category_id IS NOT NULL ORDER BY id DESC),
    (SELECT TOP 1 id FROM wms.pallets WHERE is_deleted = 0 ORDER BY id DESC));

/* Category lấy của chính pallet khuôn — chắc chắn là mã hợp lệ. */
UPDATE c SET c.cat = COALESCE(p.category_id,
                              (SELECT TOP 1 code FROM master.categories WHERE is_deleted = 0 ORDER BY code))
FROM #cfg c JOIN wms.pallets p ON p.id = c.tpl;

UPDATE #cfg SET
    m1 = (SELECT code FROM (SELECT code, rn = ROW_NUMBER() OVER (ORDER BY code) FROM master.models WHERE is_deleted = 0) z WHERE rn = 1),
    m2 = (SELECT code FROM (SELECT code, rn = ROW_NUMBER() OVER (ORDER BY code) FROM master.models WHERE is_deleted = 0) z WHERE rn = 2),
    m3 = (SELECT code FROM (SELECT code, rn = ROW_NUMBER() OVER (ORDER BY code) FROM master.models WHERE is_deleted = 0) z WHERE rn = 3);

/* Ô: lấy theo map_type của khu. Ô thuộc khu 'receiving' chính là thứ
   phân biệt pallet "chờ FA lấy" với pallet "đang trong kho" — xem
   ReturnPallet.State. Không có ô receiving thì trạng thái waiting_fa
   KHÔNG dựng được, nên script cảnh báo chứ không im lặng bỏ qua. */
UPDATE #cfg SET
    loc_store = (SELECT TOP 1 l.id FROM master.locators l
                 JOIN master.warehouse_areas a ON a.id = l.area_id AND a.is_deleted = 0
                 WHERE l.is_deleted = 0 AND a.map_type = N'storing'   ORDER BY l.id),
    loc_recv  = (SELECT TOP 1 l.id FROM master.locators l
                 JOIN master.warehouse_areas a ON a.id = l.area_id AND a.is_deleted = 0
                 WHERE l.is_deleted = 0 AND a.map_type = N'receiving' ORDER BY l.id);

/* Bãi đậu và ô FA: dummy chỉ cần HAI ô phân biệt được để thấy xe đổi chỗ. */
UPDATE #cfg SET
    loc_park = (SELECT TOP 1 l.id FROM master.locators l WHERE l.is_deleted = 0
                  AND l.id NOT IN (ISNULL(loc_store,-1), ISNULL(loc_recv,-1)) ORDER BY l.id),
    loc_fa   = (SELECT TOP 1 l.id FROM master.locators l WHERE l.is_deleted = 0
                  AND l.id NOT IN (ISNULL(loc_store,-1), ISNULL(loc_recv,-1)) ORDER BY l.id DESC);

SELECT ghi_that = IIF(what_if = 1, N'KHONG — dang xem truoc', N'CO'),
       khuon_pallet = tpl, category = cat, model_1 = m1, model_2 = m2, model_3 = m3,
       o_luu_tru = loc_store, o_nhan_hang = loc_recv, o_dau_xe = loc_park, o_FA = loc_fa
FROM #cfg;

IF EXISTS (SELECT 1 FROM #cfg WHERE loc_recv IS NULL)
    PRINT N'⚠ Khong co o nao thuoc khu map_type = receiving — trang thai "cho FA lay" (waiting_fa) se KHONG dung duoc.';
IF EXISTS (SELECT 1 FROM #cfg WHERE loc_store IS NULL)
    PRINT N'⚠ Khong co o nao thuoc khu map_type = storing — pallet "da luu kho" se de locator NULL.';
GO

/* =====================================================================
   MỤC 1 — XEM TRƯỚC SẼ XOÁ GÌ (chỉ đọc, luôn chạy)
   ===================================================================== */
DECLARE @ri TABLE (id bigint PRIMARY KEY);
INSERT INTO @ri SELECT id FROM wms.return_instructions WHERE created_by = N'dummy';
DECLARE @ng TABLE (id bigint PRIMARY KEY);
INSERT INTO @ng SELECT id FROM wms.ng_inspections WHERE created_by = N'dummy';

SELECT bang, so_dong FROM (VALUES
 (N'wms.return_back_deliveries',     (SELECT COUNT(*) FROM wms.return_back_deliveries     WHERE doc_id IN (SELECT id FROM @ri))),
 (N'wms.return_back_rounds',         (SELECT COUNT(*) FROM wms.return_back_rounds         WHERE doc_id IN (SELECT id FROM @ri))),
 (N'wms.return_back_lines',          (SELECT COUNT(*) FROM wms.return_back_lines          WHERE doc_id IN (SELECT id FROM @ri))),
 (N'wms.return_serial_mismatches',   (SELECT COUNT(*) FROM wms.return_serial_mismatches   WHERE doc_id IN (SELECT id FROM @ri))),
 (N'wms.return_instruction_serials', (SELECT COUNT(*) FROM wms.return_instruction_serials WHERE doc_id IN (SELECT id FROM @ri))),
 (N'wms.return_instruction_lines',   (SELECT COUNT(*) FROM wms.return_instruction_lines   WHERE doc_id IN (SELECT id FROM @ri))),
 (N'wms.return_instructions',        (SELECT COUNT(*) FROM @ri)),
 (N'wms.ng_inspection_approvals',    (SELECT COUNT(*) FROM wms.ng_inspection_approvals    WHERE ng_id IN (SELECT id FROM @ng))),
 (N'wms.ng_inspection_photos',       (SELECT COUNT(*) FROM wms.ng_inspection_photos       WHERE ng_id IN (SELECT id FROM @ng))),
 (N'wms.ng_inspection_items',        (SELECT COUNT(*) FROM wms.ng_inspection_items        WHERE ng_id IN (SELECT id FROM @ng))),
 (N'wms.ng_inspections',             (SELECT COUNT(*) FROM @ng)),
 (N'wms.stocky_carts',               (SELECT COUNT(*) FROM wms.stocky_carts WHERE created_by = N'dummy')),
 (N'wms.pallets (xoa MEM)',          (SELECT COUNT(*) FROM wms.pallets WHERE created_by = N'dummy' AND is_deleted = 0))
) v(bang, so_dong)
WHERE so_dong > 0;
GO

/* ---- Từ đây trở xuống chỉ chạy khi @WhatIf = 0 ---------------------
   SET NOEXEC bỏ qua phần THỰC THI nhưng vẫn BIÊN DỊCH, nên lỗi cú pháp
   hay sai tên cột vẫn lộ ra ngay ở lượt xem trước. ------------------- */
IF (SELECT what_if FROM #cfg) = 1
BEGIN
    PRINT N'';
    PRINT N'=== DANG XEM TRUOC. Doi @WhatIf = 0 o MUC 0 roi chay lai de ghi that. ===';
    SET NOEXEC ON;
END
GO

/* =====================================================================
   MỤC 2 — XOÁ DUMMY CŨ
   ---------------------------------------------------------------------
   Bảng con xoá HẲN; pallet chỉ XOÁ MỀM vì wms.boxes / box_lines /
   stock_events đều có khoá ngoại sang wms.pallets.
   ===================================================================== */
DELETE d FROM wms.return_back_deliveries     d JOIN wms.return_instructions i ON i.id = d.doc_id WHERE i.created_by = N'dummy';
DELETE d FROM wms.return_back_rounds         d JOIN wms.return_instructions i ON i.id = d.doc_id WHERE i.created_by = N'dummy';
DELETE d FROM wms.return_back_lines          d JOIN wms.return_instructions i ON i.id = d.doc_id WHERE i.created_by = N'dummy';
DELETE d FROM wms.return_serial_mismatches   d JOIN wms.return_instructions i ON i.id = d.doc_id WHERE i.created_by = N'dummy';
DELETE d FROM wms.return_instruction_serials d JOIN wms.return_instructions i ON i.id = d.doc_id WHERE i.created_by = N'dummy';
DELETE d FROM wms.return_instruction_lines   d JOIN wms.return_instructions i ON i.id = d.doc_id WHERE i.created_by = N'dummy';
DELETE FROM wms.return_instructions WHERE created_by = N'dummy';

DELETE a FROM wms.ng_inspection_approvals a JOIN wms.ng_inspections n ON n.id = a.ng_id WHERE n.created_by = N'dummy';
DELETE p FROM wms.ng_inspection_photos    p JOIN wms.ng_inspections n ON n.id = p.ng_id WHERE n.created_by = N'dummy';
DELETE t FROM wms.ng_inspection_items     t JOIN wms.ng_inspections n ON n.id = t.ng_id WHERE n.created_by = N'dummy';
DELETE FROM wms.ng_inspections WHERE created_by = N'dummy';

DELETE FROM wms.stocky_carts WHERE created_by = N'dummy';

/* Gỡ mã xe khỏi pallet TRƯỚC khi xoá mềm, để câu đếm "hàng trên xe" của
   màn Stocky không còn trỏ vào xe vừa biến mất. */
UPDATE wms.pallets SET stocky_code = NULL WHERE created_by = N'dummy' AND stocky_code IS NOT NULL;
UPDATE wms.pallets SET is_deleted = 1, locator_id = NULL,
                       updated_at = SYSDATETIME(), updated_by = N'dummy'
 WHERE created_by = N'dummy' AND is_deleted = 0;
PRINT N'2. Da xoa dummy cu.';
GO

/* =====================================================================
   MỤC 3 — PALLET DÙNG CHUNG CHO PHẦN A VÀ PHẦN C
   ---------------------------------------------------------------------
   Dựng trước vì cả sổ serial (phần A) lẫn "hàng trên xe" (phần C) đều
   trỏ vào đây.
   ===================================================================== */
IF OBJECT_ID('tempdb..#pal') IS NOT NULL DROP TABLE #pal;
CREATE TABLE #pal
(
    rn int IDENTITY(1,1) PRIMARY KEY,
    nhan      varchar(20),      -- khoá gọi tên: 'A07b', 'C03'...
    loc_kind  varchar(6),       -- none | store | recv | park | fa
    disp      nvarchar(20) NULL,
    insp      nvarchar(30),
    stocky    nvarchar(50) NULL,
    pallet_id char(12) NULL,
    pal_db    bigint NULL
);

/* -- pallet của phần A: một cái cho mỗi phiếu có hàng, hai cái cho các
      phiếu cần đồng thời "đã ở FA" và "còn trong kho". -- */
INSERT INTO #pal (nhan, loc_kind, disp, insp, stocky) VALUES
 ('A02','store',N'rework',   N'ng',NULL), ('A03','store',N'rework',   N'ng',NULL),
 ('A04','store',N'rework',   N'ng',NULL), ('A05','store',N'rework',   N'ng',NULL),
 ('A06','recv', N'rework',   N'ng',NULL),                       -- chờ FA lấy
 ('A07','store',N'refurbish',N'ng',NULL), ('A07b','none',N'refurbish',N'ng',NULL), -- còn kho + đã ở FA
 ('A08','store',N'refurbish',N'ng',NULL), ('A08b','none',N'refurbish',N'ng',NULL),
 ('A09','none', N'refurbish',N'ng',NULL),                       -- FA đã lấy hết
 ('A10','store',N'rework',   N'ng',NULL), ('A11','store',N'rework',   N'ng',NULL),
 ('A12','store',N'rework',   N'ng',NULL), ('A13','store',N'refurbish',N'ng',NULL),
 ('A14','none', N'refurbish',N'ng',NULL),                       -- đã ở FA, có con trả lại
 ('A15','store',N'rework',   N'ng',NULL),
 ('A16','none', N'rework',   N'ng',NULL),                       -- CHƯA lưu kho
 /* -- pallet của phần C: hàng nằm trên xe stocky -- */
 ('C03','store',NULL,N'pass',N'__C03__'),
 ('C04','recv', NULL,N'pass',N'__C04__');

UPDATE p SET p.pallet_id = LEFT(c.tok, 10) + RIGHT(N'00' + CAST(p.rn AS varchar(2)), 2),
             p.stocky    = REPLACE(REPLACE(p.stocky, N'__C03__', N'DUMMY-03'), N'__C04__', N'DUMMY-04')
FROM #pal p CROSS JOIN #cfg c;
GO

/* ---- nhân bản khuôn: dựng câu INSERT theo ĐÚNG cột đang có ---- */
DECLARE @ovr TABLE (col sysname PRIMARY KEY, val nvarchar(200), want_null bit);
INSERT INTO @ovr VALUES
 (N'pallet_id',        N'@pid',          0),
 (N'category_id',      N'@cat',          0),
 (N'model',            N'@model',        0),
 (N'box_count',        N'1',             0),
 (N'detail_level',     N'N''serial''',   0),
 (N'lot_type',         N'@lot_type',     0),
 (N'stocky_code',      N'@stocky',       0),
 /* ⚠ ck_lots_stocky_code buộc hai cột này đi CÙNG NHAU: lot_type='stocky'
    thì stocky_code PHẢI có, lot_type khác thì PHẢI rỗng. Nên lot_type là
    tham số chứ không phải hằng — pallet nằm trên xe là lot_type='stocky'. */
 (N'si_no',            NULL,             1),
 (N'locator_id',       N'@loc',          0),
 (N'inspection_status',N'@insp',         0),
 (N'disposition',      N'@disp',         0),
 (N'is_urgent',        N'0',             0),
 (N'sap_status',       NULL,             1),
 (N'sap_pushed_at',    NULL,             1),
 (N'is_deleted',       N'0',             0),
 (N'created_at',       N'SYSDATETIME()', 0),
 (N'created_by',       N'N''dummy''',    0),
 (N'updated_at',       NULL,             1),
 (N'updated_by',       NULL,             1);

DECLARE @collist nvarchar(max) = N'', @vallist nvarchar(max) = N'';
SELECT @collist = @collist + CASE WHEN @collist = N'' THEN N'' ELSE N', ' END + QUOTENAME(c.name),
       @vallist = @vallist + CASE WHEN @vallist = N'' THEN N'' ELSE N', ' END
                 + CASE WHEN o.col IS NULL        THEN N't.' + QUOTENAME(c.name)   -- không khai -> copy khuôn
                        WHEN o.want_null = 0      THEN o.val
                        WHEN c.is_nullable = 1    THEN N'NULL'
                        ELSE ISNULL(dc.definition, N't.' + QUOTENAME(c.name)) END  -- muốn rỗng mà NOT NULL -> default
FROM   sys.columns c
LEFT   JOIN @ovr o ON o.col = c.name
LEFT   JOIN sys.default_constraints dc ON dc.parent_object_id = c.object_id AND dc.parent_column_id = c.column_id
WHERE  c.object_id = OBJECT_ID(N'wms.pallets')
   AND c.is_identity = 0 AND c.is_computed = 0 AND c.generated_always_type = 0
ORDER BY c.column_id;

DECLARE @ins nvarchar(max) =
    N'INSERT INTO wms.pallets (' + @collist + N') SELECT ' + @vallist +
    N' FROM wms.pallets t WHERE t.id = @tpl; SELECT @out = CAST(SCOPE_IDENTITY() AS bigint);';

DECLARE @tpl bigint, @cat int, @m1 nvarchar(100);
SELECT @tpl = tpl, @cat = cat, @m1 = m1 FROM #cfg;

DECLARE @rn int = 1, @max int = (SELECT MAX(rn) FROM #pal);
DECLARE @pid char(12), @disp nvarchar(20), @insp nvarchar(30), @stocky nvarchar(50),
        @loc bigint, @kind varchar(6), @new bigint, @lt nvarchar(20);

WHILE @rn <= @max
BEGIN
    SELECT @pid = p.pallet_id, @disp = p.disp, @insp = p.insp,
           @stocky = p.stocky, @kind = p.loc_kind,
           @lt = IIF(p.stocky IS NULL, N'pallet', N'stocky')
    FROM #pal p WHERE p.rn = @rn;

    SELECT @loc = CASE @kind WHEN 'store' THEN loc_store WHEN 'recv' THEN loc_recv
                             WHEN 'park'  THEN loc_park  WHEN 'fa'   THEN loc_fa
                             ELSE NULL END
    FROM #cfg;

    EXEC sp_executesql @ins,
         N'@tpl bigint, @pid char(12), @cat int, @model nvarchar(100), @stocky nvarchar(50),
           @loc bigint, @insp nvarchar(30), @disp nvarchar(20), @lot_type nvarchar(20),
           @out bigint OUTPUT',
         @tpl=@tpl, @pid=@pid, @cat=@cat, @model=@m1, @stocky=@stocky,
         @loc=@loc, @insp=@insp, @disp=@disp,
         @lot_type = @lt, @out=@new OUTPUT;

    UPDATE #pal SET pal_db = @new WHERE rn = @rn;
    SET @rn += 1;
END
PRINT CONCAT(N'3. Da tao ', @max, N' pallet (nhan ban tu pallet id=', @tpl, N').');
GO

/* =====================================================================
   MỤC 4 — PHẦN A: CHỈ THỊ BACK HÀNG (16 phiếu)
   ---------------------------------------------------------------------
   Phủ: cả 6 giá trị back_status (NULL + 5), cả 3 doc_status, nhiều LẦN
   đề nghị (back_round 0/1/2), cả 4 trạng thái vị trí pallet (stored ·
   waiting_fa · at_fa · not_stored), hai loại hàng, nhận thiếu/đủ/vượt,
   cả hai `kind` của nhật ký giao, và đủ 3 lý do của sổ serial lệch.
   ===================================================================== */
IF OBJECT_ID('tempdb..#doc') IS NOT NULL DROP TABLE #doc;
CREATE TABLE #doc
(
    k int PRIMARY KEY, doc_no nvarchar(30), goods_type nvarchar(20),
    doc_status nvarchar(20), customer nvarchar(200),
    qty int, recv int,                 -- mỗi model: SL chỉ thị / SL thực nhận
    back_status nvarchar(20), back_round int,
    nhan_pal varchar(20) NULL,         -- pallet chính
    nhan_pal2 varchar(20) NULL,        -- pallet phụ (phần đã ở FA)
    n_atfa int, n_returned int,        -- mỗi model: bao nhiêu con ở FA / đã trả về
    stamp_round bit,                   -- serial còn `received` đã đóng back_round chưa (B4)
    tinh_huong nvarchar(120)
);

DECLARE @t char(6) = LEFT((SELECT tok FROM #cfg), 4) + RIGHT((SELECT tok FROM #cfg), 2);

INSERT INTO #doc (k, doc_no, goods_type, doc_status, customer, qty, recv,
                  back_status, back_round, nhan_pal, nhan_pal2, n_atfa, n_returned, stamp_round, tinh_huong) VALUES
 ( 1,N'RW-'+@t+N'-D01',N'rework',   N'open',     N'Panasonic VN',20, 0,NULL,            0,NULL,  NULL,  0,0,0,N'Chua nhan hang — FA khong de nghi duoc'),
 ( 2,N'RW-'+@t+N'-D02',N'rework',   N'open',     N'Panasonic VN',20,20,NULL,            0,'A02', NULL,  0,0,0,N'Da nhan du, CHUA de nghi'),
 ( 3,N'RW-'+@t+N'-D03',N'rework',   N'open',     N'Sony VN',     20,20,N'fa_requested', 1,'A03', NULL,  0,0,0,N'B1 — cho QUAN LY FA duyet'),
 ( 4,N'RW-'+@t+N'-D04',N'rework',   N'open',     N'Panasonic VN',20,20,N'fa_approved',  1,'A04', NULL,  0,0,0,N'B2 — cho QUAN LY SCS duyet'),
 ( 5,N'RW-'+@t+N'-D05',N'rework',   N'open',     N'Sharp VN',    20,20,N'scs_approved', 1,'A05', NULL,  0,0,0,N'B3 — WH duoc out kho, chua dua ra'),
 ( 6,N'RW-'+@t+N'-D06',N'rework',   N'open',     N'Sharp VN',    20,20,N'scs_approved', 1,'A06', NULL,  0,0,1,N'B4 — pallet CHO FA LAY o khu Nhan hang'),
 ( 7,N'RB-'+@t+N'-D01',N'refurbish',N'open',     N'Panasonic VN',20,20,N'delivered',    1,'A07','A07b', 8,0,0,N'Xong LAN 1, kho CON hang'),
 ( 8,N'RB-'+@t+N'-D02',N'refurbish',N'open',     N'Sony VN',     20,20,N'fa_requested', 2,'A08','A08b', 6,0,0,N'LAN 2 dang cho QL FA'),
 ( 9,N'RB-'+@t+N'-D03',N'refurbish',N'completed',N'Sharp VN',    20,20,N'delivered',    1,NULL, 'A09', 20,0,0,N'FA da nhan HET — kho het hang'),
 (10,N'RW-'+@t+N'-D07',N'rework',   N'open',     N'Sony VN',     20,20,N'cancelled',    1,'A10', NULL,  0,0,0,N'De nghi da HUY — de nghi lai duoc'),
 (11,N'RW-'+@t+N'-D08',N'rework',   N'cancelled',N'Panasonic VN',20,20,NULL,            0,'A11', NULL,  0,0,0,N'PHIEU da huy'),
 (12,N'RW-'+@t+N'-D09',N'rework',   N'open',     N'Sony VN',     20,12,NULL,            0,'A12', NULL,  0,0,0,N'Nhan THIEU so chi thi'),
 (13,N'RB-'+@t+N'-D04',N'refurbish',N'open',     N'Sharp VN',    20,28,NULL,            0,'A13', NULL,  0,0,0,N'Nhan VUOT chi thi'),
 (14,N'RB-'+@t+N'-D05',N'refurbish',N'completed',N'Panasonic VN',20,20,N'delivered',    1,NULL, 'A14', 20,8,0,N'FA da TRA LAI hang (muc 3)'),
 (15,N'RW-'+@t+N'-D10',N'rework',   N'open',     N'Panasonic VN',20,20,NULL,            0,'A15', NULL,  0,0,0,N'Co 3 dong so serial LECH (muc 2d)'),
 (16,N'RW-'+@t+N'-D11',N'rework',   N'open',     N'Sony VN',     20,20,NULL,            0,'A16', NULL,  0,0,0,N'Pallet CHUA LUU KHO');

/* ---------- 4a. Header ---------- */
INSERT INTO wms.return_instructions
    (doc_no, goods_type, customer, expected_date, doc_status, note,
     mail_sent_at, mail_sent_to, closed_at, closed_by,
     actual_mail_sent_at, actual_mail_sent_to,
     back_status, back_round, back_note,
     back_requested_by, back_requested_at,
     back_approved_by, back_approved_at, back_fa_comment,
     back_scs_approved_by, back_scs_approved_at, back_scs_comment,
     back_delivered_by, back_delivered_at,
     back_cancelled_by, back_cancelled_at, back_cancel_reason,
     is_deleted, created_at, created_by)
SELECT d.doc_no, d.goods_type, d.customer, DATEADD(DAY,-3,CAST(SYSDATETIME() AS date)),
       d.doc_status, N'[dummy] ' + d.tinh_huong,
       DATEADD(HOUR,-72,SYSDATETIME()), N'fa@example.local',
       IIF(d.doc_status = N'completed', DATEADD(HOUR,-36,SYSDATETIME()), NULL),
       IIF(d.doc_status = N'completed', N'Nguyen Van A (SCS WH)', NULL),
       IIF(d.recv > 0, DATEADD(HOUR,-40,SYSDATETIME()), NULL),
       IIF(d.recv > 0, N'fa@example.local', NULL),
       d.back_status, d.back_round,
       IIF(d.back_status IS NULL, NULL, N'[dummy] can gap cho lo xuat tuan sau'),
       IIF(d.back_status IS NULL, NULL, N'Pham Van C (FA)'),
       IIF(d.back_status IS NULL, NULL, DATEADD(HOUR,-24,SYSDATETIME())),
       IIF(d.back_status IN (N'fa_approved',N'scs_approved',N'delivered'), N'Le Thi D (QL FA)', NULL),
       IIF(d.back_status IN (N'fa_approved',N'scs_approved',N'delivered'), DATEADD(HOUR,-20,SYSDATETIME()), NULL),
       IIF(d.back_status IN (N'fa_approved',N'scs_approved',N'delivered'), N'Dong y, uu tien model dau', NULL),
       IIF(d.back_status IN (N'scs_approved',N'delivered'), N'Tran Van E (QL SCS)', NULL),
       IIF(d.back_status IN (N'scs_approved',N'delivered'), DATEADD(HOUR,-16,SYSDATETIME()), NULL),
       IIF(d.back_status IN (N'scs_approved',N'delivered'), N'Duyet cho giao', NULL),
       IIF(d.back_status = N'delivered', N'Pham Van C (FA)', NULL),
       IIF(d.back_status = N'delivered', DATEADD(HOUR,-6,SYSDATETIME()), NULL),
       IIF(d.back_status = N'cancelled', N'Pham Van C (FA)', NULL),
       IIF(d.back_status = N'cancelled', DATEADD(HOUR,-12,SYSDATETIME()), NULL),
       IIF(d.back_status = N'cancelled', N'FA doi y, chua can lay ve', NULL),
       0, DATEADD(HOUR,-72,SYSDATETIME()), N'dummy'
FROM #doc d ORDER BY d.k;

/* doc_no là duy nhất trong số phiếu chưa xoá -> nối lại bằng nó, không
   cần OUTPUT ... INTO. */
IF OBJECT_ID('tempdb..#dmap') IS NOT NULL DROP TABLE #dmap;
SELECT d.k, i.id AS doc_id, d.nhan_pal, d.nhan_pal2, d.recv, d.back_round,
       d.back_status, d.n_atfa, d.n_returned, d.stamp_round
INTO   #dmap
FROM   #doc d JOIN wms.return_instructions i ON i.doc_no = d.doc_no AND i.created_by = N'dummy';

/* ---------- 4b. Dòng chỉ thị: 3 model mỗi phiếu ---------- */
INSERT INTO wms.return_instruction_lines (doc_id, line_no, model, qty, is_deleted, created_at, created_by)
SELECT m.doc_id, v.line_no, v.model, d.qty, 0, DATEADD(HOUR,-72,SYSDATETIME()), N'dummy'
FROM #dmap m JOIN #doc d ON d.k = m.k
CROSS APPLY (SELECT 1, (SELECT m1 FROM #cfg) UNION ALL
             SELECT 2, (SELECT m2 FROM #cfg) UNION ALL
             SELECT 3, (SELECT m3 FROM #cfg)) v(line_no, model);

/* ---------- 4c. Sổ serial ----------
   Mọi con sinh ra ở trạng thái `received` trên pallet chính; các lượt
   UPDATE ngay dưới mới đẩy từng nhóm sang at_fa / returned. Làm hai
   bước cho dễ đọc, và để mỗi tình huống chỉ là MỘT câu UPDATE. */
IF OBJECT_ID('tempdb..#n') IS NOT NULL DROP TABLE #n;
SELECT TOP (100) i = ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) INTO #n FROM sys.all_objects;

INSERT INTO wms.return_instruction_serials
    (doc_id, model, serial_no, box_no, pallet_id, status, received_at,
     back_round, sent_fa_at, returned_at, is_deleted, created_at, created_by)
SELECT m.doc_id, v.model,
       N'DM' + (SELECT tok FROM #cfg) + RIGHT(N'0'+CAST(m.k AS varchar(2)),2)
             + CAST(v.line_no AS varchar(1)) + RIGHT(N'00'+CAST(n.i AS varchar(3)),3),
       /* Con cuối của model 3 cố ý để box_no NULL: hàng về RỜI, không còn
          thùng để quét. Đây là ca mà `ReturnSerial.BoxNo` phải là string?. */
       IIF(v.line_no = 3 AND n.i = m.recv, NULL, N'B' + CAST(v.line_no AS varchar(1))),
       p.pal_db, N'received', DATEADD(HOUR,-40,SYSDATETIME()),
       NULL, NULL, NULL, 0, DATEADD(HOUR,-40,SYSDATETIME()), N'dummy'
FROM   #dmap m
JOIN   #n n ON n.i <= m.recv
CROSS  APPLY (SELECT 1,(SELECT m1 FROM #cfg) UNION ALL
              SELECT 2,(SELECT m2 FROM #cfg) UNION ALL
              SELECT 3,(SELECT m3 FROM #cfg)) v(line_no, model)
LEFT   JOIN #pal p ON p.nhan = m.nhan_pal
WHERE  m.recv > 0 AND m.nhan_pal IS NOT NULL;

/* Phiếu chỉ có pallet phụ (9, 14): toàn bộ nằm trên pallet đó. */
INSERT INTO wms.return_instruction_serials
    (doc_id, model, serial_no, box_no, pallet_id, status, received_at,
     back_round, sent_fa_at, returned_at, is_deleted, created_at, created_by)
SELECT m.doc_id, v.model,
       N'DM' + (SELECT tok FROM #cfg) + RIGHT(N'0'+CAST(m.k AS varchar(2)),2)
             + CAST(v.line_no AS varchar(1)) + RIGHT(N'00'+CAST(n.i AS varchar(3)),3),
       N'B' + CAST(v.line_no AS varchar(1)), p.pal_db,
       N'received', DATEADD(HOUR,-40,SYSDATETIME()),
       NULL, NULL, NULL, 0, DATEADD(HOUR,-40,SYSDATETIME()), N'dummy'
FROM   #dmap m
JOIN   #n n ON n.i <= m.recv
CROSS  APPLY (SELECT 1,(SELECT m1 FROM #cfg) UNION ALL
              SELECT 2,(SELECT m2 FROM #cfg) UNION ALL
              SELECT 3,(SELECT m3 FROM #cfg)) v(line_no, model)
JOIN   #pal p ON p.nhan = m.nhan_pal2
WHERE  m.recv > 0 AND m.nhan_pal IS NULL;

/* -- B4: đóng back_round cho serial CÒN `received` (phiếu 6) --
   Đây chính là thứ phân biệt "pallet hàng back đang chờ FA lấy" với
   "pallet hàng mới nhận từ khách cũng đỗ ở khu nhận hàng". */
UPDATE s SET s.back_round = m.back_round
FROM wms.return_instruction_serials s JOIN #dmap m ON m.doc_id = s.doc_id
WHERE m.stamp_round = 1 AND s.status = N'received';

/* -- B5: chuyển n_atfa con MỖI MODEL sang at_fa, gắn vào pallet phụ -- */
WITH x AS (
    SELECT s.id, s.model, m.k, m.n_atfa, m.back_round, m.nhan_pal2,
           rn = ROW_NUMBER() OVER (PARTITION BY s.doc_id, s.model ORDER BY s.id)
    FROM   wms.return_instruction_serials s
    JOIN   #dmap m ON m.doc_id = s.doc_id
    WHERE  m.n_atfa > 0 AND s.status = N'received'
)
UPDATE s SET s.status = N'at_fa',
             s.sent_fa_at = DATEADD(HOUR,-6,SYSDATETIME()),
             s.back_round = x.back_round,
             s.pallet_id  = ISNULL(p.pal_db, s.pallet_id)
FROM wms.return_instruction_serials s
JOIN x ON x.id = s.id
LEFT JOIN #pal p ON p.nhan = x.nhan_pal2
WHERE x.rn <= x.n_atfa;

/* -- Mục 3: FA trả lại n_returned con mỗi model (phiếu 14) -- */
WITH y AS (
    SELECT s.id, rn = ROW_NUMBER() OVER (PARTITION BY s.doc_id, s.model ORDER BY s.id DESC),
           m.n_returned
    FROM   wms.return_instruction_serials s
    JOIN   #dmap m ON m.doc_id = s.doc_id
    WHERE  m.n_returned > 0 AND s.status = N'at_fa'
)
UPDATE s SET s.status = N'returned', s.returned_at = DATEADD(HOUR,-2,SYSDATETIME())
FROM wms.return_instruction_serials s JOIN y ON y.id = s.id
WHERE y.rn <= y.n_returned;

/* ---------- 4d. Mốc từng LẦN đề nghị ---------- */
INSERT INTO wms.return_back_rounds
    (doc_id, round, asked_qty, note, requested_by, requested_at,
     fa_approved_by, fa_approved_at, fa_comment,
     scs_approved_by, scs_approved_at, scs_comment,
     delivered_by, delivered_at, cancelled_by, cancelled_at, cancel_reason, created_at)
SELECT m.doc_id, r.i,
       IIF(r.i < m.back_round, m.n_atfa * 3, m.recv * 3),
       N'[dummy] lan ' + CAST(r.i AS varchar(2)),
       N'Pham Van C (FA)', DATEADD(HOUR, -24 - 8*(m.back_round - r.i), SYSDATETIME()),
       /* Lần ĐÃ ĐÓNG (round < back_round) luôn có đủ mốc; lần ĐANG MỞ thì
          chỉ có mốc của những bước đã qua. */
       IIF(r.i < m.back_round OR m.back_status IN (N'fa_approved',N'scs_approved',N'delivered'), N'Le Thi D (QL FA)', NULL),
       IIF(r.i < m.back_round OR m.back_status IN (N'fa_approved',N'scs_approved',N'delivered'), DATEADD(HOUR,-20,SYSDATETIME()), NULL),
       IIF(r.i < m.back_round OR m.back_status IN (N'fa_approved',N'scs_approved',N'delivered'), N'Dong y', NULL),
       IIF(r.i < m.back_round OR m.back_status IN (N'scs_approved',N'delivered'), N'Tran Van E (QL SCS)', NULL),
       IIF(r.i < m.back_round OR m.back_status IN (N'scs_approved',N'delivered'), DATEADD(HOUR,-16,SYSDATETIME()), NULL),
       IIF(r.i < m.back_round OR m.back_status IN (N'scs_approved',N'delivered'), N'Duyet cho giao', NULL),
       IIF(r.i < m.back_round OR m.back_status = N'delivered', N'Pham Van C (FA)', NULL),
       IIF(r.i < m.back_round OR m.back_status = N'delivered', DATEADD(HOUR,-6,SYSDATETIME()), NULL),
       IIF(r.i = m.back_round AND m.back_status = N'cancelled', N'Pham Van C (FA)', NULL),
       IIF(r.i = m.back_round AND m.back_status = N'cancelled', DATEADD(HOUR,-12,SYSDATETIME()), NULL),
       IIF(r.i = m.back_round AND m.back_status = N'cancelled', N'FA doi y', NULL),
       DATEADD(HOUR,-24,SYSDATETIME())
FROM #dmap m JOIN #n r ON r.i <= m.back_round
WHERE m.back_round > 0;

/* ---------- 4e. Dòng FA xin, theo từng lần ---------- */
INSERT INTO wms.return_back_lines (doc_id, round, model, req_qty, created_at, created_by)
SELECT b.doc_id, b.round, v.model, IIF(b.round < b.back_round, b.n_atfa, b.recv),
       DATEADD(HOUR,-24,SYSDATETIME()), N'dummy'
FROM (SELECT m.doc_id, r.i AS round, m.back_round, m.n_atfa, m.recv
      FROM #dmap m JOIN #n r ON r.i <= m.back_round
      WHERE m.back_round > 0 AND m.back_status <> N'cancelled') b
CROSS APPLY (SELECT (SELECT m1 FROM #cfg) UNION ALL
             SELECT (SELECT m2 FROM #cfg) UNION ALL
             SELECT (SELECT m3 FROM #cfg)) v(model)
WHERE IIF(b.round < b.back_round, b.n_atfa, b.recv) > 0;

/* ---------- 4f. Nhật ký giao — HAI dòng cho một lượt ----------
   `handover` = SCS WH đưa pallet ra ô khu Nhận hàng (B4, có locator_code)
   `pickup`   = FA đến lấy (B5, pallet rời vị trí)
   Từ 12/11 hai việc này ghi CHUNG một bảng, nên phải có cột `kind` —
   thiếu nó thì nhật ký hiện hai dòng giống hệt nhau. */
/* Lượt giao thuộc LẦN nào: phiếu đang mở ở lần sau (vd phiếu 8 đang xin
   lần 2) thì phần hàng đã sang FA là của lần TRƯỚC, nên round phải lùi
   một. Ghi đúng số lần ở đây mới ra đúng tiến trình con trên Web. */
IF OBJECT_ID('tempdb..#giao') IS NOT NULL DROP TABLE #giao;
SELECT m.doc_id, m.n_atfa, m.stamp_round,
       pal_db   = p.pal_db,
       lot_no   = p.pallet_id,
       lan_giao = IIF(m.back_status = N'delivered' OR m.stamp_round = 1,
                      m.back_round, m.back_round - 1)
INTO   #giao
FROM   #dmap m
JOIN   #pal p ON p.nhan = ISNULL(m.nhan_pal2, m.nhan_pal)
WHERE  m.back_round > 0 AND (m.stamp_round = 1 OR m.n_atfa > 0);

INSERT INTO wms.return_back_deliveries
    (doc_id, pallet_id, lot_no, serial_count, delivered_at, delivered_by, round, kind, locator_code)
SELECT g.doc_id, g.pal_db, g.lot_no,
       IIF(g.n_atfa > 0, g.n_atfa * 3,
           (SELECT COUNT(*) FROM wms.return_instruction_serials s
            WHERE s.doc_id = g.doc_id AND s.back_round IS NOT NULL)),
       DATEADD(HOUR,-10,SYSDATETIME()), N'Nguyen Van A (SCS WH)', g.lan_giao,
       N'handover', l.locator_code
FROM #giao g
LEFT JOIN master.locators l ON l.id = (SELECT loc_recv FROM #cfg)
WHERE g.lan_giao > 0;

INSERT INTO wms.return_back_deliveries
    (doc_id, pallet_id, lot_no, serial_count, delivered_at, delivered_by, round, kind, locator_code)
SELECT g.doc_id, g.pal_db, g.lot_no, g.n_atfa * 3,
       DATEADD(HOUR,-6,SYSDATETIME()), N'Pham Van C (FA)', g.lan_giao, N'pickup', NULL
FROM #giao g
WHERE g.n_atfa > 0 AND g.lan_giao > 0;

/* ---------- 4g. Sổ serial LỆCH — đủ ba lý do (mục 2d) ---------- */
INSERT INTO wms.return_serial_mismatches
    (doc_id, pallet_id, serial_no, model, reason, found_status, other_doc_no,
     scanned_at, scanned_by, resolved_at, resolved_by, resolve_note,
     is_deleted, created_at, created_by)
SELECT m.doc_id, p.pal_db, v.serial_no, v.model, v.reason, v.found_status, v.other_doc,
       DATEADD(HOUR,-3,SYSDATETIME()), N'Pham Van C (FA)',
       v.resolved_at, v.resolved_by, v.resolve_note,
       0, DATEADD(HOUR,-3,SYSDATETIME()), N'dummy'
FROM #dmap m
JOIN #pal p ON p.nhan = m.nhan_pal
CROSS APPLY (VALUES
   (N'LACHAN' + (SELECT tok FROM #cfg) + N'1', NULL,                 N'not_in_doc',   NULL,         NULL,
    NULL, NULL, NULL),
   (N'LACHAN' + (SELECT tok FROM #cfg) + N'2', (SELECT m2 FROM #cfg), N'wrong_status', N'received',  NULL,
    NULL, NULL, NULL),
   (N'LACHAN' + (SELECT tok FROM #cfg) + N'3', (SELECT m3 FROM #cfg), N'other_doc',    N'at_fa',     N'RW-' + @t + N'-D02',
    DATEADD(HOUR,-1,SYSDATETIME()), N'Nguyen Van A (SCS WH)', N'[dummy] da doi chieu, bo qua')
) v(serial_no, model, reason, found_status, other_doc, resolved_at, resolved_by, resolve_note)
WHERE m.k = 15;

PRINT N'4. PHAN A xong — 16 phieu chi thi back hang.';
GO

/* =====================================================================
   MỤC 5 — PHẦN B: HÀNG BẤT THƯỜNG (11 phiếu) · PHẦN C: XE STOCKY (7 xe)
   ===================================================================== */
/* ---- loại lỗi: lấy một loại CẦN OQC và một loại KHÔNG cần ---- */
DECLARE @ty_oqc nvarchar(30) = (SELECT TOP 1 code FROM master.ng_types
                                WHERE is_deleted = 0 AND is_active = 1 AND requires_oqc = 1 ORDER BY sort_order, code);
DECLARE @ty_skip nvarchar(30) = (SELECT TOP 1 code FROM master.ng_types
                                 WHERE is_deleted = 0 AND is_active = 1 AND requires_oqc = 0 ORDER BY sort_order, code);
/* Không khai loại nào bỏ OQC thì mượn tạm loại cần OQC — ca `skipped`
   vẫn dựng được vì `oqc_status` do luồng đóng, không do loại lỗi ép. */
SET @ty_skip = ISNULL(@ty_skip, @ty_oqc);

DECLARE @tok char(10) = (SELECT tok FROM #cfg);

IF OBJECT_ID('tempdb..#ngp') IS NOT NULL DROP TABLE #ngp;
CREATE TABLE #ngp
(
    k int PRIMARY KEY, doc_no nvarchar(30), ng_type nvarchar(30),
    doc_status nvarchar(30), current_step nvarchar(30),
    leader_status nvarchar(20), oqc_status nvarchar(20), fa_status nvarchar(20),
    fa_resolution nvarchar(20) NULL, resolution nvarchar(20),
    scope nvarchar(10), n_photo int, tinh_huong nvarchar(120)
);

INSERT INTO #ngp VALUES
 ( 1,N'NG-'+@tok+N'-01',@ty_oqc, N'draft',            N'created',     N'pending',  N'pending',N'pending', NULL,        N'pending', N'serial',0,N'B1 — SCS vua lap, con NHAP'),
 ( 2,N'NG-'+@tok+N'-02',@ty_oqc, N'in_review',        N'oqc_confirm', N'submitted',N'pending',N'pending', NULL,        N'pending', N'box',   2,N'B2 xong — cho OQC ket luan'),
 ( 3,N'NG-'+@tok+N'-03',@ty_skip,N'in_review',        N'fa_confirm',  N'submitted',N'skipped',N'pending', NULL,        N'pending', N'serial',1,N'Loai loi KHONG can OQC — bo qua thang sang FA'),
 ( 4,N'NG-'+@tok+N'-04',@ty_oqc, N'in_review',        N'fa_confirm',  N'submitted',N'ok',     N'pending', NULL,        N'pending', N'pallet',0,N'OQC ket luan OK — cho FA chon huong'),
 ( 5,N'NG-'+@tok+N'-05',@ty_oqc, N'in_review',        N'fa_confirm',  N'submitted',N'ng',     N'pending', NULL,        N'pending', N'pallet',3,N'OQC ket luan NG — cho FA chon huong'),
 ( 6,N'NG-'+@tok+N'-06',@ty_oqc, N'ready_to_finalize',N'scs_finalize',N'submitted',N'ng',     N'approved',N'replace',  N'pending', N'box',   1,N'B4 xong — cho SCS supervisor chot'),
 ( 7,N'NG-'+@tok+N'-07',@ty_oqc, N'finalized',        N'done',        N'submitted',N'ng',     N'approved',N'replace',  N'replace', N'serial',2,N'CHOT: doi hang'),
 ( 8,N'NG-'+@tok+N'-08',@ty_oqc, N'finalized',        N'done',        N'submitted',N'ok',     N'approved',N'accept',   N'accept',  N'serial',0,N'CHOT: chap nhan'),
 ( 9,N'NG-'+@tok+N'-09',@ty_oqc, N'finalized',        N'done',        N'submitted',N'ng',     N'approved',N'return',   N'return',  N'box',   1,N'CHOT: tra lai'),
 (10,N'NG-'+@tok+N'-10',@ty_oqc, N'finalized',        N'done',        N'submitted',N'ng',     N'approved',N'scrap',    N'scrap',   N'pallet',4,N'CHOT: huy bo'),
 (11,N'NG-'+@tok+N'-11',@ty_oqc, N'cancelled',        N'created',     N'cancelled',N'pending',N'pending', NULL,        N'pending', N'serial',0,N'DA HUY o buoc leader');

INSERT INTO wms.ng_inspections
    (doc_no, lot_id, ng_type, description, discovered_at, doc_status, current_step,
     leader_status, leader_by, leader_by_code, leader_at, leader_comment,
     fa_status, fa_resolution, fa_by, fa_at, fa_comment,
     oqc_status, oqc_by, oqc_at, oqc_comment,
     resolution, finalized_by, finalized_at, final_comment,
     cancelled_by, cancelled_at, cancel_reason,
     is_deleted, created_at, created_by, updated_at, updated_by)
SELECT p.doc_no, (SELECT pal_db FROM #pal WHERE nhan = 'A02'), p.ng_type,
       N'[dummy] ' + p.tinh_huong, DATEADD(HOUR,-30,SYSDATETIME()),
       p.doc_status, p.current_step,
       p.leader_status,
       IIF(p.leader_status = N'pending', NULL, N'Vu Thi F (Leader SCS)'),
       IIF(p.leader_status = N'pending', NULL, N'SCS001'),
       IIF(p.leader_status = N'pending', NULL, DATEADD(HOUR,-26,SYSDATETIME())),
       IIF(p.leader_status = N'pending', NULL, N'[dummy] da xem hien truong'),
       p.fa_status, p.fa_resolution,
       IIF(p.fa_status = N'approved', N'Pham Van C (FA)', NULL),
       IIF(p.fa_status = N'approved', DATEADD(HOUR,-14,SYSDATETIME()), NULL),
       IIF(p.fa_status = N'approved', N'[dummy] FA da chon huong xu ly', NULL),
       p.oqc_status,
       IIF(p.oqc_status IN (N'ok',N'ng'), N'Dang Thi G (OQC)', NULL),
       IIF(p.oqc_status IN (N'ok',N'ng'), DATEADD(HOUR,-18,SYSDATETIME()), NULL),
       IIF(p.oqc_status IN (N'ok',N'ng'), N'[dummy] ket luan ngoai quan', NULL),
       p.resolution,
       IIF(p.doc_status = N'finalized', N'Hoang Van H (SCS Supervisor)', NULL),
       IIF(p.doc_status = N'finalized', DATEADD(HOUR,-8,SYSDATETIME()), NULL),
       IIF(p.doc_status = N'finalized', N'[dummy] da chot', NULL),
       IIF(p.doc_status = N'cancelled', N'Vu Thi F (Leader SCS)', NULL),
       IIF(p.doc_status = N'cancelled', DATEADD(HOUR,-25,SYSDATETIME()), NULL),
       IIF(p.doc_status = N'cancelled', N'[dummy] lap nham phieu', NULL),
       0, DATEADD(HOUR,-30,SYSDATETIME()), N'dummy',
       DATEADD(HOUR,-8,SYSDATETIME()), N'dummy'
FROM #ngp p ORDER BY p.k;

IF OBJECT_ID('tempdb..#ngmap') IS NOT NULL DROP TABLE #ngmap;
SELECT p.k, n.id AS ng_id, p.scope, p.n_photo, p.doc_status, p.leader_status,
       p.oqc_status, p.fa_status, p.fa_resolution, p.resolution
INTO   #ngmap
FROM   #ngp p JOIN wms.ng_inspections n ON n.doc_no = p.doc_no AND n.created_by = N'dummy';

/* -- Mục phạm vi: đủ ba scope. Phiếu scope='pallet' chỉ MỘT mục để
      whole_pallet = 1 và màn hình hiện "ca pallet" thay vì "1 cai". -- */
INSERT INTO wms.ng_inspection_items
    (ng_id, scope, pallet_id, box_id, box_line_id, code, qty_affected, note,
     is_deleted, created_at, created_by)
SELECT m.ng_id, m.scope,
       (SELECT pal_db FROM #pal WHERE nhan = 'A02'), NULL, NULL,
       CASE m.scope WHEN N'pallet' THEN (SELECT pallet_id FROM #pal WHERE nhan = 'A02')
                    WHEN N'box'    THEN N'B' + CAST(n.i AS varchar(2))
                    ELSE N'DM' + @tok + N'NG' + RIGHT(N'00'+CAST(n.i AS varchar(2)),2) END,
       IIF(m.scope = N'pallet', 1, n.i * 2),
       N'[dummy] muc ' + CAST(n.i AS varchar(2)),
       0, DATEADD(HOUR,-30,SYSDATETIME()), N'dummy'
FROM #ngmap m JOIN #n n ON n.i <= IIF(m.scope = N'pallet', 1, 3);

INSERT INTO wms.ng_inspection_photos
    (ng_id, item_id, file_path, file_name, content_type, size_bytes, caption, sort_order,
     is_deleted, created_at, created_by)
SELECT m.ng_id, NULL,
       N'ng/' + CAST(m.ng_id AS varchar(12)) + N'/dummy_' + CAST(n.i AS varchar(2)) + N'.jpg',
       N'dummy_' + CAST(n.i AS varchar(2)) + N'.jpg', N'image/jpeg', 120000 + n.i * 1000,
       N'[dummy] anh ' + CAST(n.i AS varchar(2)), n.i,
       0, DATEADD(HOUR,-29,SYSDATETIME()), N'dummy'
FROM #ngmap m JOIN #n n ON n.i <= m.n_photo;

/* -- Nhật ký từng bước: KHÔNG ghi đè, mỗi lần bấm một dòng. -- */
INSERT INTO wms.ng_inspection_approvals (ng_id, step, action, resolution, [comment], acted_by, acted_at)
SELECT m.ng_id, N'leader', IIF(m.doc_status = N'cancelled', N'cancel', N'submit'), NULL,
       N'[dummy] buoc 2', N'Vu Thi F (Leader SCS)', DATEADD(HOUR,-26,SYSDATETIME())
FROM #ngmap m WHERE m.leader_status <> N'pending'
UNION ALL
SELECT m.ng_id, N'oqc', m.oqc_status, NULL, N'[dummy] buoc 3', N'Dang Thi G (OQC)', DATEADD(HOUR,-18,SYSDATETIME())
FROM #ngmap m WHERE m.oqc_status IN (N'ok', N'ng')
UNION ALL
SELECT m.ng_id, N'fa', N'approve', m.fa_resolution, N'[dummy] buoc 4', N'Pham Van C (FA)', DATEADD(HOUR,-14,SYSDATETIME())
FROM #ngmap m WHERE m.fa_status = N'approved'
UNION ALL
SELECT m.ng_id, N'finalize', N'finalize', m.resolution, N'[dummy] buoc 5', N'Hoang Van H (SCS Supervisor)', DATEADD(HOUR,-8,SYSDATETIME())
FROM #ngmap m WHERE m.doc_status = N'finalized';

PRINT N'5a. PHAN B xong — 11 phieu hang bat thuong.';

/* ---------- PHẦN C: XE STOCKY ----------
   `status` chỉ nói xe CÓ CÒN ĐƯỢC QUẢN LÝ KHÔNG, KHÔNG nói xe đứng ở
   đâu — vị trí đọc ở `locator_id`. Vì vậy ma trận dưới đây tách hai
   trục: trạng thái × vị trí × có hàng hay không. */
INSERT INTO wms.stocky_carts
    (code, name, vendor, status, locator_id, received_at, received_by,
     returned_at, returned_by, note, is_deleted, created_at, created_by, updated_at, updated_by)
SELECT v.code, v.ten, v.vendor, v.status,
       CASE v.loc WHEN 'park'  THEN c.loc_park  WHEN 'store' THEN c.loc_store
                  WHEN 'recv'  THEN c.loc_recv  WHEN 'fa'    THEN c.loc_fa
                  ELSE NULL END,
       v.received_at, IIF(v.received_at IS NULL, NULL, N'Nguyen Van A (SCS WH)'),
       v.returned_at, IIF(v.returned_at IS NULL, NULL, N'Nguyen Van A (SCS WH)'),
       N'[dummy] ' + v.tinh_huong, v.is_deleted,
       DATEADD(HOUR,-50,SYSDATETIME()), N'dummy', DATEADD(HOUR,-5,SYSDATETIME()), N'dummy'
FROM #cfg c
CROSS APPLY (VALUES
 (N'DUMMY-01',N'Xe dummy 01',N'Vendor A',N'in_warehouse','none', DATEADD(HOUR,-48,SYSDATETIME()),CAST(NULL AS datetime2(0)),0,N'Nhan vao nhung CHUA gan o nao'),
 (N'DUMMY-02',N'Xe dummy 02',N'Vendor A',N'in_warehouse','park', DATEADD(HOUR,-47,SYSDATETIME()),NULL,                      0,N'Dang o BAI DAU, xe rong'),
 (N'DUMMY-03',N'Xe dummy 03',N'Vendor B',N'in_warehouse','store',DATEADD(HOUR,-46,SYSDATETIME()),NULL,                      0,N'Dang o O KHO va CO HANG tren xe'),
 (N'DUMMY-04',N'Xe dummy 04',N'Vendor B',N'in_warehouse','recv', DATEADD(HOUR,-45,SYSDATETIME()),NULL,                      0,N'Dang o KHU NHAN HANG va co hang'),
 (N'DUMMY-05',N'Xe dummy 05',N'Vendor C',N'in_warehouse','fa',   DATEADD(HOUR,-44,SYSDATETIME()),NULL,                      0,N'Da DAY SANG FA — van duoc quan ly'),
 (N'DUMMY-06',N'Xe dummy 06',N'Vendor C',N'returned',    'park', DATEADD(HOUR,-70,SYSDATETIME()),DATEADD(HOUR,-4,SYSDATETIME()),0,N'Da TRA VENDOR — roi he thong'),
 (N'DUMMY-07',N'Xe dummy 07',N'Vendor A',N'in_warehouse','park', DATEADD(HOUR,-69,SYSDATETIME()),NULL,                      1,N'Da XOA MEM — khong hien o danh sach')
) v(code, ten, vendor, status, loc, received_at, returned_at, is_deleted, tinh_huong);

PRINT N'5b. PHAN C xong — 7 xe stocky.';
GO

/* =====================================================================
   MỤC 6 — BẢNG KIỂM
   ===================================================================== */
SELECT  N'A. CHI THI BACK HANG' AS phan,
        i.doc_no, i.goods_type, trang_thai_phieu = i.doc_status,
        back = ISNULL(i.back_status, N'(chua de nghi)'), lan = i.back_round,
        da_nhan   = (SELECT COUNT(*) FROM wms.return_instruction_serials s WHERE s.doc_id = i.id AND s.is_deleted = 0),
        o_kho     = (SELECT COUNT(*) FROM wms.return_instruction_serials s WHERE s.doc_id = i.id AND s.is_deleted = 0 AND s.status = N'received'),
        cho_FA_lay= (SELECT COUNT(*) FROM wms.return_instruction_serials s WHERE s.doc_id = i.id AND s.is_deleted = 0 AND s.status = N'received' AND s.back_round IS NOT NULL),
        o_FA      = (SELECT COUNT(*) FROM wms.return_instruction_serials s WHERE s.doc_id = i.id AND s.is_deleted = 0 AND s.status = N'at_fa'),
        da_tra_ve = (SELECT COUNT(*) FROM wms.return_instruction_serials s WHERE s.doc_id = i.id AND s.is_deleted = 0 AND s.status = N'returned'),
        nk_dua_ra = (SELECT COUNT(*) FROM wms.return_back_deliveries d WHERE d.doc_id = i.id AND d.kind = N'handover'),
        nk_FA_lay = (SELECT COUNT(*) FROM wms.return_back_deliveries d WHERE d.doc_id = i.id AND d.kind = N'pickup'),
        so_lech   = (SELECT COUNT(*) FROM wms.return_serial_mismatches x WHERE x.doc_id = i.id AND x.is_deleted = 0),
        tinh_huong = i.note
FROM    wms.return_instructions i
WHERE   i.created_by = N'dummy'
ORDER BY i.doc_no;

SELECT  N'B. HANG BAT THUONG' AS phan,
        n.doc_no, n.ng_type, n.doc_status, n.current_step,
        leader = n.leader_status, oqc = n.oqc_status, fa = n.fa_status,
        fa_huong = ISNULL(n.fa_resolution, N'—'), chot = n.resolution,
        so_muc = (SELECT COUNT(*) FROM wms.ng_inspection_items  t WHERE t.ng_id = n.id AND t.is_deleted = 0),
        ca_pallet = (SELECT MIN(CASE WHEN t.scope = N'pallet' THEN 1 ELSE 0 END)
                     FROM wms.ng_inspection_items t WHERE t.ng_id = n.id AND t.is_deleted = 0),
        so_anh = (SELECT COUNT(*) FROM wms.ng_inspection_photos f WHERE f.ng_id = n.id AND f.is_deleted = 0),
        so_buoc_da_ghi = (SELECT COUNT(*) FROM wms.ng_inspection_approvals a WHERE a.ng_id = n.id),
        tinh_huong = n.description
FROM    wms.ng_inspections n
WHERE   n.created_by = N'dummy'
ORDER BY n.doc_no;

SELECT  N'C. XE STOCKY' AS phan,
        c.code, c.name, c.vendor, c.status,
        o_cua_xe = ISNULL(l.locator_code, N'(chua gan o)'),
        khu = ISNULL(a.area_name, N'—'),
        so_pallet_tren_xe = (SELECT COUNT(*) FROM wms.pallets p
                             WHERE p.stocky_code = c.code AND p.is_deleted = 0),
        da_xoa_mem = c.is_deleted,
        ghi_chu = c.note
FROM    wms.stocky_carts c
LEFT    JOIN master.locators        l ON l.id = c.locator_id
LEFT    JOIN master.warehouse_areas a ON a.id = l.area_id
WHERE   c.created_by = N'dummy'
ORDER BY c.code;

PRINT N'';
PRINT N'===== XONG =====';
PRINT N'Doc ba bang kiem o tren. Muon xoa sach dummy: chay lai file nay';
PRINT N'voi @WhatIf = 0 roi dung lai sau MUC 2.';
GO

SET NOEXEC OFF;
GO
