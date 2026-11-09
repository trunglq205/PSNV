/* =====================================================================
   return_back_dummy.sql
   XOÁ sạch dữ liệu màn Tái gia công rồi DỰNG LẠI bộ dummy đủ 11 tình
   huống, để kiểm từng bước theo từng bộ phận.

   CHẠY SAU return_back_merge_schema.sql.
   Chạy lại nhiều lần được: mỗi lần là xoá hết rồi dựng lại từ đầu.

   ⚠ SCRIPT NÀY XOÁ DỮ LIỆU. Chỉ chạy trên DB test.
     Để @WhatIf = 1 (mặc định) để XEM TRƯỚC sẽ xoá gì, chưa ghi gì cả.
     Xem xong, đổi thành 0 rồi chạy lại.

   ---------------------------------------------------------------------
   PHẠM VI XOÁ — đúng bốn bảng của luồng return, KHÔNG đụng gì khác:

     wms.return_back_deliveries        xoá hẳn
     wms.return_instruction_serials    xoá hẳn
     wms.return_instruction_lines      xoá hẳn
     wms.return_instructions           xoá hẳn

   Pallet thì XOÁ MỀM (is_deleted = 1), không xoá hẳn, và CHỈ những pallet
   đang được sổ serial của các phiếu này trỏ tới: wms.boxes, wms.box_lines,
   wms.stock_events đều có khoá ngoại sang wms.pallets, xoá hẳn là gãy —
   mà kể cả không gãy thì cũng mất luôn lịch sử đi lại của pallet.

   KHÔNG đụng: master.models · master.categories · master.locators ·
   master.email_events · master.email_config · role / quyền · mọi pallet
   không thuộc luồng return.
   ---------------------------------------------------------------------
   PALLET DỰNG BẰNG CÁCH NHÂN BẢN MỘT PALLET CÓ SẴN, không INSERT tay:
   wms.pallets có những cột NOT NULL mà script này không biết hết (DDL
   không nằm trong bộ script). Nhân bản một dòng thật rồi ghi đè đúng mấy
   cột cần thì mọi cột khác tự có giá trị hợp lệ — và nếu sau này ai thêm
   cột NOT NULL vào bảng thì script vẫn chạy.
   ===================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* 1 = chỉ xem, chưa ghi gì. ĐỔI THÀNH 0 ĐỂ CHẠY THẬT. */
DECLARE @WhatIf bit = 1;

/* ---------- 0. Tiền đề ---------- */
IF COL_LENGTH(N'wms.return_instructions', N'back_status') IS NULL
BEGIN
    RAISERROR(N'Chua co cot back_status — chay return_back_merge_schema.sql truoc.', 16, 1);
    RETURN;
END

IF NOT EXISTS (SELECT 1 FROM wms.pallets WHERE is_deleted = 0)
BEGIN
    RAISERROR(N'Khong co pallet nao trong wms.pallets de lam khuon. Tao 1 pallet bat ky roi chay lai.', 16, 1);
    RETURN;
END

DECLARE @nModel int = (SELECT COUNT(*) FROM master.models WHERE is_deleted = 0);
IF @nModel < 3
BEGIN
    RAISERROR(N'Can it nhat 3 model trong master.models.', 16, 1);
    RETURN;
END

SELECT N'0. Se xoa nhung gi' AS section;
SELECT  bang = v.n, so_dong = v.c
FROM (VALUES
    (N'wms.return_back_deliveries',     (SELECT COUNT(*) FROM wms.return_back_deliveries)),
    (N'wms.return_instruction_serials', (SELECT COUNT(*) FROM wms.return_instruction_serials)),
    (N'wms.return_instruction_lines',   (SELECT COUNT(*) FROM wms.return_instruction_lines)),
    (N'wms.return_instructions',        (SELECT COUNT(*) FROM wms.return_instructions))
) v(n, c);

SELECT N'0b. Bang KHAC dang tro vao — se bi xoa sach luon' AS section;
SELECT  bang = QUOTENAME(SCHEMA_NAME(t.schema_id)) + N'.' + QUOTENAME(t.name),
        qua_khoa_ngoai = fk.name
FROM    sys.foreign_keys fk
JOIN    sys.tables t ON t.object_id = fk.parent_object_id
WHERE   fk.referenced_object_id IN (
            OBJECT_ID(N'wms.return_instructions'),
            OBJECT_ID(N'wms.return_instruction_serials'))
        AND t.object_id NOT IN (
            OBJECT_ID(N'wms.return_back_deliveries'),
            OBJECT_ID(N'wms.return_instruction_serials'),
            OBJECT_ID(N'wms.return_instruction_lines'),
            OBJECT_ID(N'wms.return_instructions'));

SELECT N'0c. Pallet se bi XOA MEM (is_deleted = 1)' AS section;
SELECT  pallet_id = RTRIM(p.pallet_id), p.disposition, p.box_count,
        so_serial = (SELECT COUNT(*) FROM wms.return_instruction_serials s
                     WHERE s.pallet_id = p.id)
FROM    wms.pallets p
WHERE   p.is_deleted = 0
        AND EXISTS (SELECT 1 FROM wms.return_instruction_serials s WHERE s.pallet_id = p.id)
ORDER BY p.id;

IF @WhatIf = 1
BEGIN
    SELECT N'WhatIf = 1 — CHUA GHI GI. Doi @WhatIf = 0 roi chay lai.' AS ket_qua;
    RETURN;
END

BEGIN TRAN;

/* =====================================================================
   1. Xoá
   ===================================================================== */

/* Gom id pallet TRƯỚC khi xoá sổ serial — xoá rồi thì không còn đường nào
   tìm ra pallet nào thuộc luồng return. */
DECLARE @old_pallets TABLE (id bigint PRIMARY KEY);
INSERT INTO @old_pallets (id)
SELECT DISTINCT s.pallet_id
FROM   wms.return_instruction_serials s
WHERE  s.pallet_id IS NOT NULL;

/* Bảng NÀO KHÁC đang trỏ vào hai bảng sắp xoá — TRA SYS.FOREIGN_KEYS, không
   liệt kê tên bằng tay. Mục 2d có wms.return_serial_mismatches trỏ vào
   wms.return_instructions, và liệt kê tay thì hôm nay đủ, mai ai thêm một
   bảng nữa là DELETE gãy với lỗi 547 giữa transaction.

   Bỏ ra bốn bảng đã xử lý tường minh ở dưới. */
DECLARE @dep TABLE (id int IDENTITY(1,1) PRIMARY KEY, tbl nvarchar(300));

INSERT INTO @dep (tbl)
SELECT DISTINCT QUOTENAME(SCHEMA_NAME(t.schema_id)) + N'.' + QUOTENAME(t.name)
FROM   sys.foreign_keys fk
JOIN   sys.tables t ON t.object_id = fk.parent_object_id
WHERE  fk.referenced_object_id IN (
           OBJECT_ID(N'wms.return_instructions'),
           OBJECT_ID(N'wms.return_instruction_serials'))
       AND t.object_id NOT IN (
           OBJECT_ID(N'wms.return_back_deliveries'),
           OBJECT_ID(N'wms.return_instruction_serials'),
           OBJECT_ID(N'wms.return_instruction_lines'),
           OBJECT_ID(N'wms.return_instructions'));

DECLARE @i int = 1, @n int = (SELECT ISNULL(MAX(id), 0) FROM @dep);
DECLARE @tbl nvarchar(300), @del nvarchar(max);

WHILE @i <= @n
BEGIN
    SELECT @tbl = tbl FROM @dep WHERE id = @i;
    SET @del = N'DELETE FROM ' + @tbl + N';';
    EXEC sp_executesql @del;
    PRINT CONCAT(N'1. Da xoa ', @@ROWCOUNT, N' dong tu ', @tbl, N' (bang phu thuoc)');
    SET @i += 1;
END

DELETE FROM wms.return_back_deliveries;
PRINT CONCAT(N'   Da xoa ', @@ROWCOUNT, N' dong nhat ky giao hang');

DELETE FROM wms.return_instruction_serials;
PRINT CONCAT(N'   Da xoa ', @@ROWCOUNT, N' dong so serial');

DELETE FROM wms.return_instruction_lines;
PRINT CONCAT(N'   Da xoa ', @@ROWCOUNT, N' dong model');

DELETE FROM wms.return_instructions;
PRINT CONCAT(N'   Da xoa ', @@ROWCOUNT, N' phieu chi thi');

UPDATE  p
SET     p.is_deleted = 1,
        p.updated_at = SYSDATETIME(),
        p.updated_by = N'dummy-reset'
FROM    wms.pallets p
JOIN    @old_pallets o ON o.id = p.id
WHERE   p.is_deleted = 0;
PRINT CONCAT(N'   Da XOA MEM ', @@ROWCOUNT, N' pallet cua luong return');

/* =====================================================================
   2. Chọn model + category + khuôn pallet từ dữ liệu THẬT
   ===================================================================== */
/* Ba model đầu theo thứ tự mã. OFFSET/FETCH chứ không MAX(CASE…): cách kia
   làm SQL Server in cảnh báo "Null value is eliminated by an aggregate" vào
   giữa output, đọc tưởng có lỗi. */
DECLARE @m1 nvarchar(100), @m2 nvarchar(100), @m3 nvarchar(100);

SELECT @m1 = (SELECT code FROM master.models WHERE is_deleted = 0
              ORDER BY code OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY),
       @m2 = (SELECT code FROM master.models WHERE is_deleted = 0
              ORDER BY code OFFSET 1 ROWS FETCH NEXT 1 ROWS ONLY),
       @m3 = (SELECT code FROM master.models WHERE is_deleted = 0
              ORDER BY code OFFSET 2 ROWS FETCH NEXT 1 ROWS ONLY);

/* Khuôn pallet: ưu tiên một pallet mức serial cho giống hàng return thật. */
DECLARE @tpl bigint = (
    SELECT TOP 1 id FROM wms.pallets
    WHERE is_deleted = 0 AND detail_level = N'serial' ORDER BY id DESC);
IF @tpl IS NULL
    SET @tpl = (SELECT TOP 1 id FROM wms.pallets WHERE is_deleted = 0 ORDER BY id DESC);

DECLARE @cat int = (SELECT category_id FROM wms.pallets WHERE id = @tpl);

/* Tiền tố Pallet ID = {category:D3}{yyMMdd}. Số thứ tự tiếp TỪ SỐ LỚN NHẤT
   đã cấp cho tiền tố này, kể cả pallet đã xoá: số đã cấp không dùng lại,
   nếu không sẽ đụng unique index trên pallet_id. */
DECLARE @prefix nchar(9) =
    RIGHT(N'000' + CONVERT(nvarchar(10), @cat), 3) + FORMAT(SYSDATETIME(), N'yyMMdd');

DECLARE @seq int = (
    SELECT ISNULL(MAX(CONVERT(int, RIGHT(pallet_id, 3))), 0)
    FROM   wms.pallets
    WHERE  pallet_id LIKE @prefix + N'%'
           AND LEN(pallet_id) = 12
           AND pallet_id NOT LIKE N'%[^0-9]%');

/* {seq:D3} chỉ ba chữ số. Vượt 999 thì RIGHT(...,3) cắt mất chữ số đầu và
   sinh ra Pallet ID trùng — dừng lại còn hơn ghi dữ liệu rác. */
IF @seq + 40 > 999
BEGIN
    RAISERROR(N'So thu tu pallet cho tien to hom nay da gan 999 — doi ngay khac hoac don pallet cu.', 16, 1);
    ROLLBACK;
    RETURN;
END

PRINT CONCAT(N'2. Model: ', @m1, N' / ', @m2, N' / ', @m3,
             N' · category ', @cat, N' · tien to Pallet ID ', @prefix,
             N' · so tiep theo ', @seq + 1);

/* =====================================================================
   3. Mười một phiếu — ma trận tình huống

   Mỗi dòng là một tình huống. CỐ Ý phủ đủ: cả 5 trạng thái back, cả hai
   loại hàng, phiếu open / completed / cancelled, nhận thiếu / đủ / vượt,
   giao dở dang, và FA đã trả lại hàng.
   ===================================================================== */
DECLARE @d TABLE
(
    k            int PRIMARY KEY,   /* số thứ tự, dùng sinh serial duy nhất */
    doc_no       nvarchar(30),
    goods_type   nvarchar(20),
    doc_status   nvarchar(20),
    customer     nvarchar(200),
    qty1         int,               /* SL chỉ thị của 3 model */
    qty2         int,
    qty3         int,
    recv1        int,               /* SL thực nhận của 3 model */
    recv2        int,
    recv3        int,
    back_status  nvarchar(20),
    closed       bit,               /* đã chốt thực nhận chưa */
    tinh_huong   nvarchar(200)
);

DECLARE @t nchar(6) = FORMAT(SYSDATETIME(), N'yyMMdd');

INSERT INTO @d VALUES
 (1, N'RW-' + @t + N'-001', N'rework',    N'open',      N'Panasonic VN',  100,100,100,   0,  0,  0, NULL,
     0, N'Chua nhan hang — FA KHONG de nghi duoc (con 0 con)'),
 (2, N'RW-' + @t + N'-002', N'rework',    N'open',      N'Panasonic VN',  120,100, 80, 120,100, 80, NULL,
     0, N'Da nhan du, CHUA de nghi — FA thay nut "De nghi nhan lai"'),
 (3, N'RW-' + @t + N'-003', N'rework',    N'open',      N'Sony VN',       100, 80, 60, 100, 80, 60, N'fa_requested',
     0, N'Cho QUAN LY FA xac nhan — FA con sua ghi chu / huy'),
 (4, N'RW-' + @t + N'-004', N'rework',    N'open',      N'Panasonic VN',  150,120, 90, 150,120, 90, N'fa_approved',
     0, N'Cho SCS WH GIAO HANG, chua giao con nao — van huy duoc'),
 (5, N'RW-' + @t + N'-005', N'rework',    N'open',      N'Sharp VN',      120,100, 80, 120,100, 80, N'fa_approved',
     0, N'DANG GIAO DO (1/3 pallet) — KHONG con huy duoc'),
 (6, N'RB-' + @t + N'-001', N'refurbish', N'completed', N'Panasonic VN',   80, 60, 40,  80, 60, 40, N'delivered',
     1, N'Giao XONG het — hang dang o FA'),
 (7, N'RB-' + @t + N'-002', N'refurbish', N'open',      N'Sony VN',       100, 60, 40, 100, 60, 40, N'cancelled',
     0, N'Da HUY de nghi — FA de nghi LAI duoc'),
 (8, N'RB-' + @t + N'-003', N'refurbish', N'completed', N'Sharp VN',       70, 50, 30,  70, 50, 30, N'delivered',
     1, N'Giao xong, FA DA TRA LAI 50 con (muc 3)'),
 (9, N'RW-' + @t + N'-006', N'rework',    N'cancelled', N'Panasonic VN',   60, 40, 20,  60, 40, 20, NULL,
     0, N'Phieu DA HUY — khong de nghi duoc'),
 (10,N'RW-' + @t + N'-007', N'rework',    N'open',      N'Sony VN',       100, 80, 60,  60, 20, 10, N'delivered',
     0, N'Nhan THIEU so chi thi + da giao het'),
 (11,N'RB-' + @t + N'-004', N'refurbish', N'open',      N'Sharp VN',      100, 80, 60, 150,120, 90, N'fa_requested',
     0, N'Nhan VUOT chi thi — cho quan ly FA xac nhan');

/* ---------- 3a. Header ---------- */
INSERT INTO wms.return_instructions
    (doc_no, goods_type, customer, expected_date, doc_status, note,
     mail_sent_at, mail_sent_to,
     closed_at, closed_by, actual_mail_sent_at, actual_mail_sent_to,
     back_status, back_note,
     back_requested_by, back_requested_at,
     back_approved_by,  back_approved_at,  back_fa_comment,
     back_delivered_by, back_delivered_at, back_scs_comment,
     back_cancelled_by, back_cancelled_at, back_cancel_reason,
     is_deleted, created_at, created_by)
SELECT
    d.doc_no, d.goods_type, d.customer,
    DATEADD(DAY, -(d.k), CONVERT(date, SYSDATETIME())),
    d.doc_status,
    N'[DUMMY] ' + d.tinh_huong,
    DATEADD(DAY, -(d.k), SYSDATETIME()), N'fa@psnv.local',
    /* Chốt thực nhận: chỉ phiếu nào cột closed = 1 */
    IIF(d.closed = 1, DATEADD(HOUR, -20, SYSDATETIME()), NULL),
    IIF(d.closed = 1, N'Nguyen Van A (SCS WH)', NULL),
    IIF(d.closed = 1, DATEADD(HOUR, -20, SYSDATETIME()), NULL),
    IIF(d.closed = 1, N'fa@psnv.local', NULL),

    d.back_status,
    /* Ghi chú của FA chỉ có khi đã đề nghị */
    IIF(d.back_status IS NULL, NULL, N'[DUMMY] Can gap cho lo xuat tuan sau'),

    /* B1 — mọi phiếu đã bước vào luồng back đều có người đề nghị */
    IIF(d.back_status IS NULL, NULL, N'Pham Van C (FA)'),
    IIF(d.back_status IS NULL, NULL, DATEADD(HOUR, -12, SYSDATETIME())),

    /* B2 — chỉ từ fa_approved trở đi */
    IIF(d.back_status IN (N'fa_approved', N'delivered'), N'Le Thi D (QL FA)', NULL),
    IIF(d.back_status IN (N'fa_approved', N'delivered'), DATEADD(HOUR, -10, SYSDATETIME()), NULL),
    IIF(d.back_status IN (N'fa_approved', N'delivered'), N'Dong y, uu tien model dau', NULL),

    /* B3 — chỉ phiếu đã giao XONG */
    IIF(d.back_status = N'delivered', N'Nguyen Van A (SCS WH)', NULL),
    IIF(d.back_status = N'delivered', DATEADD(HOUR, -4, SYSDATETIME()), NULL),
    IIF(d.back_status = N'delivered', N'Giao du, FA ky nhan tai cua 2', NULL),

    /* Huỷ */
    IIF(d.back_status = N'cancelled', N'Pham Van C (FA)', NULL),
    IIF(d.back_status = N'cancelled', DATEADD(HOUR, -8, SYSDATETIME()), NULL),
    IIF(d.back_status = N'cancelled', N'FA doi y, chua can lay ve', NULL),

    0, DATEADD(DAY, -(d.k), SYSDATETIME()), N'Tran Thi B (SCS Office)'
FROM @d d
ORDER BY d.k;

PRINT CONCAT(N'3. Da tao ', @@ROWCOUNT, N' phieu chi thi');

/* ---------- 3b. Dòng model ---------- */
DECLARE @map TABLE (k int PRIMARY KEY, doc_id bigint, goods_type nvarchar(20),
                    back_status nvarchar(20));
INSERT INTO @map (k, doc_id, goods_type, back_status)
SELECT d.k, i.id, d.goods_type, d.back_status
FROM   @d d JOIN wms.return_instructions i ON i.doc_no = d.doc_no;

INSERT INTO wms.return_instruction_lines
    (doc_id, line_no, model, qty, note, is_deleted, created_at, created_by)
SELECT m.doc_id, v.line_no, v.model, v.qty, NULL, 0, SYSDATETIME(), N'Tran Thi B (SCS Office)'
FROM   @d d
JOIN   @map m ON m.k = d.k
CROSS APPLY (VALUES (1, @m1, d.qty1), (2, @m2, d.qty2), (3, @m3, d.qty3)) v(line_no, model, qty)
WHERE  v.qty > 0;

PRINT CONCAT(N'   Da tao ', @@ROWCOUNT, N' dong model');

/* =====================================================================
   4. Pallet + sổ serial

   MỖI MODEL MỘT PALLET, nên phiếu nào cũng có 3 pallet để SCS WH quét —
   và phiếu số 5 cố ý mới giao 1 trong 3 pallet, đó là tình huống "đang
   giao dở" mà cả màn Web lẫn PDA phải chặn nút Huỷ.
   ===================================================================== */
DECLARE @plan TABLE
(
    rn          int IDENTITY(1,1) PRIMARY KEY,
    k           int,
    doc_id      bigint,
    model       nvarchar(100),
    line_no     int,
    cnt         int,            /* số serial trên pallet này */
    status      nvarchar(20),   /* trạng thái serial sau khi dựng */
    sent        bit,            /* đã từng giao FA chưa (sent_fa_at) */
    pallet_id   nchar(12) NULL,
    pallet_db   bigint NULL
);

INSERT INTO @plan (k, doc_id, model, line_no, cnt, status, sent)
SELECT  d.k, m.doc_id, v.model, v.line_no, v.cnt,
        /* Trạng thái serial suy ra TỪ tình huống của phiếu:
             delivered          -> at_fa   (phieu 8: mot phan returned)
             fa_approved + do do -> pallet dau at_fa, hai pallet sau received
             con lai             -> received */
        CASE
            WHEN d.back_status = N'delivered' AND d.k = 8 AND v.line_no = 2 THEN N'returned'
            WHEN d.back_status = N'delivered' THEN N'at_fa'
            WHEN d.k = 5 AND v.line_no = 1 THEN N'at_fa'
            ELSE N'received'
        END,
        CASE
            WHEN d.back_status = N'delivered' THEN 1
            WHEN d.k = 5 AND v.line_no = 1 THEN 1
            ELSE 0
        END
FROM    @d d
JOIN    @map m ON m.k = d.k
CROSS APPLY (VALUES (1, @m1, d.recv1), (2, @m2, d.recv2), (3, @m3, d.recv3)) v(line_no, model, cnt)
WHERE   v.cnt > 0;

/* Cấp Pallet ID theo đúng khuôn {category:D3}{yyMMdd}{seq:D3}. */
UPDATE  @plan
SET     pallet_id = @prefix + RIGHT(N'000' + CONVERT(nvarchar(10), @seq + rn), 3);

/* ---------- 4a. Nhân bản pallet ----------
   Dựng câu INSERT từ sys.columns: mọi cột KHÔNG nằm trong danh sách ghi đè
   thì copy từ pallet khuôn. Nhờ vậy cột NOT NULL nào script không biết cũng
   tự có giá trị hợp lệ. */
/* want_null = 1 nghĩa là "muốn cột này rỗng". KHÔNG ép NULL thẳng: cột có
   thể là NOT NULL — wms.pallets.sap_status chính là ca đó, và lần đầu tôi
   viết cứng NULL nên gãy lỗi 515. Thứ tự ưu tiên khi cột NOT NULL:
     1) giá trị DEFAULT của chính cột (pallet mới dựng giống pallet thật nhất)
     2) không có default thì copy từ pallet khuôn
   Tra is_nullable + default ở sys.*, không đoán. */
DECLARE @ovr TABLE (col sysname PRIMARY KEY, val nvarchar(200), want_null bit);
INSERT INTO @ovr (col, val, want_null) VALUES
    (N'pallet_id',         N'@pid',                       0),
    (N'model',             NULL,                          1),  /* mức serial: model ở box */
    (N'box_count',         N'@cnt',                       0),
    (N'detail_level',      N'N''serial''',                0),
    (N'lot_type',          N'N''pallet''',                0),
    (N'stocky_code',       NULL,                          1),
    (N'si_no',             NULL,                          1),
    (N'locator_id',        NULL,                          1),  /* chưa xếp vị trí */
    (N'inspection_status', N'N''inspection_exempt''',     0),
    (N'disposition',       N'@disp',                      0),
    (N'is_urgent',         N'0',                          0),
    (N'sap_status',        NULL,                          1),
    (N'sap_pushed_at',     NULL,                          1),
    (N'is_deleted',        N'0',                          0),
    (N'created_at',        N'SYSDATETIME()',              0),
    (N'created_by',        N'N''Nguyen Van A (SCS WH)''', 0),
    (N'updated_at',        NULL,                          1),
    (N'updated_by',        NULL,                          1);

DECLARE @collist nvarchar(max) = N'', @vallist nvarchar(max) = N'';

SELECT @collist = @collist + CASE WHEN @collist = N'' THEN N'' ELSE N', ' END
                           + QUOTENAME(c.name),
       @vallist = @vallist + CASE WHEN @vallist = N'' THEN N'' ELSE N', ' END
                           + CASE
                               /* không khai ghi đè -> copy khuôn */
                               WHEN o.col IS NULL THEN N't.' + QUOTENAME(c.name)
                               /* ghi đè một giá trị cụ thể */
                               WHEN o.want_null = 0 THEN o.val
                               /* muốn rỗng, và cột cho phép rỗng */
                               WHEN c.is_nullable = 1 THEN N'NULL'
                               /* muốn rỗng mà cột NOT NULL -> default, rồi khuôn */
                               ELSE ISNULL(dc.definition, N't.' + QUOTENAME(c.name))
                             END
FROM   sys.columns c
LEFT   JOIN @ovr o ON o.col = c.name
LEFT   JOIN sys.default_constraints dc
            ON dc.parent_object_id = c.object_id
           AND dc.parent_column_id = c.column_id
WHERE  c.object_id = OBJECT_ID(N'wms.pallets')
       AND c.is_identity = 0
       AND c.is_computed = 0
       AND c.generated_always_type = 0
ORDER BY c.column_id;

/* In ra để nếu còn gãy thì thấy ngay cột nào nhận giá trị gì. */
PRINT N'   Gia tri tung cot pallet:';
PRINT N'   ' + @vallist;

DECLARE @ins nvarchar(max) =
    N'INSERT INTO wms.pallets (' + @collist + N') ' +
    N'SELECT ' + @vallist + N' FROM wms.pallets t WHERE t.id = @tpl; ' +
    N'SELECT @out = CAST(SCOPE_IDENTITY() AS bigint);';

DECLARE @rn int = 1, @max int = (SELECT MAX(rn) FROM @plan);
DECLARE @pid nchar(12), @disp nvarchar(20), @cnt int, @newid bigint;

WHILE @rn <= @max
BEGIN
    SELECT @pid = p.pallet_id, @cnt = p.cnt, @disp = m.goods_type
    FROM   @plan p JOIN @map m ON m.k = p.k
    WHERE  p.rn = @rn;

    EXEC sp_executesql @ins,
         N'@tpl bigint, @pid nchar(12), @disp nvarchar(20), @cnt int, @out bigint OUTPUT',
         @tpl = @tpl, @pid = @pid, @disp = @disp, @cnt = @cnt, @out = @newid OUTPUT;

    UPDATE @plan SET pallet_db = @newid WHERE rn = @rn;
    SET @rn += 1;
END

PRINT CONCAT(N'4. Da tao ', @max, N' pallet (nhan ban tu pallet id=',
             @tpl, N')');

/* ---------- 4b. Sổ serial ----------
   Sinh N dòng bằng bảng đếm từ sys.all_objects, không dùng vòng lặp: một
   phiếu vài trăm con, lặp từng con là vài nghìn lượt round-trip. */
;WITH n AS (
    SELECT TOP (10000) i = ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
    FROM   sys.all_objects a CROSS JOIN sys.all_columns b
)
INSERT INTO wms.return_instruction_serials
    (doc_id, model, serial_no, box_no, pallet_id, status,
     received_at, is_deleted, created_at, created_by, updated_at, updated_by)
SELECT  p.doc_id,
        p.model,
        /* Duy nhất toàn hệ thống: DMY + thứ tự pallet + thứ tự con.
           ux_ris_serial_open chặn một serial nằm trong hai phiếu đang chạy,
           nên không được trùng giữa các phiếu dummy. */
        N'DMY' + RIGHT(N'000' + CONVERT(nvarchar(10), p.rn), 3)
               + RIGHT(N'00000' + CONVERT(nvarchar(10), n.i), 5),
        N'BOX' + RIGHT(N'000' + CONVERT(nvarchar(10), p.rn), 3),
        p.pallet_db,
        p.status,
        DATEADD(HOUR, -30, SYSDATETIME()),
        0, DATEADD(HOUR, -30, SYSDATETIME()), N'Nguyen Van A (SCS WH)',
        IIF(p.sent = 1, DATEADD(HOUR, -4, SYSDATETIME()), NULL),
        IIF(p.sent = 1, N'Nguyen Van A (SCS WH)', NULL)
FROM    @plan p
JOIN    n ON n.i <= p.cnt;

PRINT CONCAT(N'   Da tao ', @@ROWCOUNT, N' dong so serial');

/* sent_fa_at — mốc "đã TỪNG giao", thứ quyết định còn huỷ được hay không.
   Cột này không nằm trong INSERT trên vì nó chỉ áp cho pallet đã giao. */
UPDATE  s
SET     s.sent_fa_at = DATEADD(HOUR, -4, SYSDATETIME())
FROM    wms.return_instruction_serials s
JOIN    @plan p ON p.pallet_db = s.pallet_id
WHERE   p.sent = 1;

PRINT CONCAT(N'   Da dong moc sent_fa_at cho ', @@ROWCOUNT, N' con');

/* returned_at cho phiếu 8 — FA đã trả lại một phần (mục 3). */
UPDATE  s
SET     s.returned_at = DATEADD(HOUR, -1, SYSDATETIME())
FROM    wms.return_instruction_serials s
WHERE   s.status = N'returned';

/* =====================================================================
   5. Nhật ký giao hàng — chỉ cho pallet đã thực giao
   ===================================================================== */
INSERT INTO wms.return_back_deliveries
    (doc_id, pallet_id, lot_no, serial_count, delivered_at, delivered_by)
SELECT  p.doc_id, p.pallet_db, RTRIM(p.pallet_id), p.cnt,
        DATEADD(HOUR, -4, SYSDATETIME()), N'Nguyen Van A (SCS WH)'
FROM    @plan p
WHERE   p.sent = 1;

PRINT CONCAT(N'5. Da tao ', @@ROWCOUNT, N' dong nhat ky giao hang');

COMMIT;

/* =====================================================================
   6. Bảng kiểm — in ra để đối chiếu trên màn hình
   ===================================================================== */
SELECT N'6. Ma tran tinh huong — doi chieu voi man Tai gia cong' AS section;
SELECT  stt          = d.k,
        so_phieu     = i.doc_no,
        loai         = i.goods_type,
        tt_phieu     = i.doc_status,
        chi_thi      = (SELECT SUM(qty) FROM wms.return_instruction_lines l
                        WHERE l.doc_id = i.id AND l.is_deleted = 0),
        thuc_nhan    = (SELECT COUNT(*) FROM wms.return_instruction_serials s
                        WHERE s.doc_id = i.id AND s.is_deleted = 0),
        back_status  = ISNULL(i.back_status, N'(chua de nghi)'),
        con_o_kho    = (SELECT COUNT(*) FROM wms.return_instruction_serials s
                        WHERE s.doc_id = i.id AND s.status = N'received' AND s.is_deleted = 0),
        da_giao      = (SELECT COUNT(*) FROM wms.return_instruction_serials s
                        WHERE s.doc_id = i.id AND s.sent_fa_at IS NOT NULL AND s.is_deleted = 0),
        dang_o_fa    = (SELECT COUNT(*) FROM wms.return_instruction_serials s
                        WHERE s.doc_id = i.id AND s.status = N'at_fa' AND s.is_deleted = 0),
        fa_tra_ve    = (SELECT COUNT(*) FROM wms.return_instruction_serials s
                        WHERE s.doc_id = i.id AND s.status = N'returned' AND s.is_deleted = 0),
        tinh_huong   = d.tinh_huong
FROM    @d d
JOIN    wms.return_instructions i ON i.doc_no = d.doc_no
ORDER BY d.k;

SELECT N'7. Nut nao hien cho ai' AS section;
SELECT ghi_chu = v.s FROM (VALUES
 (N'FA (request_back)      : phieu 2, 7  -> "De nghi nhan lai"   | phieu 3, 11 -> "Sua ghi chu"'),
 (N'Quan ly FA (approve_fa): phieu 3, 11 -> "Quan ly FA xac nhan"'),
 (N'SCS WH (process)       : phieu 4, 5  -> "Giao hang"'),
 (N'Nut "Huy" (ca 3 ben)   : phieu 3, 4, 11. Phieu 5 KHONG — da giao do dang'),
 (N'Khong nut nao          : phieu 1 (chua nhan hang) · 6, 8, 10 (da giao xong) · 9 (phieu da huy)')
) v(s);

/* Số đếm của bộ lọc hàng đợi — TÍNH TỪ DỮ LIỆU, không viết cứng. Viết cứng
   thì sửa ma trận ở mục 3 là con số ở đây sai ngay, mà không ai biết. */
SELECT N'7b. So dem tren bo loc hang doi' AS section;
SELECT  muc = v.m, so_phieu = v.c
FROM (VALUES
    (N'Nhan lai hang: tat ca',    (SELECT COUNT(*) FROM wms.return_instructions WHERE is_deleted = 0)),
    (N'Chua de nghi nhan lai',    (SELECT COUNT(*) FROM wms.return_instructions
                                   WHERE is_deleted = 0
                                     AND (back_status IS NULL OR back_status = N'cancelled'))),
    (N'Cho quan ly FA xac nhan',  (SELECT COUNT(*) FROM wms.return_instructions
                                   WHERE is_deleted = 0 AND back_status = N'fa_requested')),
    (N'Cho SCS giao hang',        (SELECT COUNT(*) FROM wms.return_instructions
                                   WHERE is_deleted = 0 AND back_status = N'fa_approved')),
    (N'Da giao xong cho FA',      (SELECT COUNT(*) FROM wms.return_instructions
                                   WHERE is_deleted = 0 AND back_status = N'delivered'))
) v(m, c);

SELECT N'8. Pallet ID de QUET tren PDA (phieu 4 va 5)' AS section;
SELECT  so_phieu  = i.doc_no,
        pallet_id = RTRIM(p.pallet_id),
        model     = s.model,
        so_luong  = COUNT(*),
        trang_thai = s.status,
        ghi_chu   = IIF(s.status = N'received', N'QUET DUOC', N'da giao roi')
FROM    wms.return_instruction_serials s
JOIN    wms.pallets p ON p.id = s.pallet_id
JOIN    wms.return_instructions i ON i.id = s.doc_id
WHERE   i.doc_no IN (SELECT doc_no FROM @d WHERE k IN (4, 5))
        AND s.is_deleted = 0
GROUP BY i.doc_no, p.pallet_id, s.model, s.status
ORDER BY i.doc_no, p.pallet_id;

SELECT N'9. Viec con phai lam tay' AS section;
SELECT ghi_chu = v.s FROM (VALUES
 (N'Gan quyen o /roles -> receiving -> rework_refurbish:'),
 (N'  FA = view + request_back · QL FA = view + approve_fa'),
 (N'  SCS WH = view + process  · SCS Office = view + create'),
 (N'  approve_scs: DUNG gan cho ai.'),
 (N'Quyen cache 5 phut phia API — tick roi van 403 thi cho.'),
 (N'Khai nguoi nhan mail o banh rang man Tai gia cong (4 tab) neu muon test mail.'),
 (N'Pallet dummy chua xep vi tri (locator_id NULL) nen khong hien tren ban do kho.')
) v(s);
