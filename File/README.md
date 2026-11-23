/* =====================================================================
   THAY LẠI MẪU THƯ "HÀNG BẤT THƯỜNG" (RECEIVING_ABNORMAL)
   ---------------------------------------------------------------------
   Dùng khi dòng RECEIVING_ABNORMAL trong master.email_events đang mang
   nội dung TEST và cần thay bằng mẫu chuẩn.

   Vì sao cần script riêng: dev_seed_mail_roles.sql cố ý KHÔNG đè mẫu đã
   có người sửa tay (updated_at IS NOT NULL) — soạn lại mà bị script đè
   mất thì tệ hơn cả thiếu. Nội dung test cũng tính là "đã sửa tay", nên
   chạy lại script kia sẽ bỏ qua. Script này đè có chủ đích.

   HAI CHẾ ĐỘ — xem MỤC 2:
     @HardDelete = 0  (MẶC ĐỊNH, nên dùng)
         Ghi đè nội dung tại chỗ rồi xoá dấu sửa tay (updated_at = NULL).
         Kết quả giống hệt xoá-rồi-thêm-lại, nhưng GIỮ NGUYÊN danh sách
         người nhận và phân tầng loại lỗi đang gắn vào mã sự kiện này.
     @HardDelete = 1
         Xoá hẳn dòng rồi thêm lại. Chỉ làm được khi không có khoá ngoại
         nào chặn; script tự kiểm và dừng nếu bị chặn. KHÔNG xoá người
         nhận trong master.email_config — chúng dính theo mã sự kiện nên
         dòng mới vẫn nhận lại đúng bộ cũ.

   Nội dung mẫu: CHÉP NGUYÊN từ dev_seed_mail_roles.sql, không soạn lại,
   để hai script không bao giờ lệch nhau. Chín biến đúng theo
   NgReportService.Fill(): {DocNo} {PalletCode} {Model} {NgType}
   {Description} {LeaderBy} {DiscoveredAt} {Now} {Link}.

   An toàn: chỉ chạy trên DB có tên kết thúc bằng _DEV.
   ===================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF RIGHT(DB_NAME(), 4) <> N'_DEV'
BEGIN
    PRINT N'==========================================================';
    PRINT CONCAT(N'DUNG LAI: dang o DB [', DB_NAME(), N'], khong phai DB _DEV.');
    PRINT N'==========================================================';
    SET NOEXEC ON;
END
GO

/* =====================================================================
   MỤC 1 — ĐANG CÓ GÌ (đọc trước khi ghi đè)
   ===================================================================== */
SELECT N'1. Hien trang truoc khi ghi de' AS section;

SELECT  ma            = e.code,
        dang_bat      = e.is_active,
        da_sua_tay    = IIF(e.updated_at IS NULL, N'khong', N'CO'),
        sua_luc       = e.updated_at,
        sua_boi       = e.updated_by,
        dai_tieu_de   = LEN(ISNULL(e.subject_template, N'')),
        dai_than_thu  = LEN(ISNULL(e.body_template, N'')),
        so_loai_loi   = (SELECT COUNT(*) FROM master.email_event_subtypes s
                         WHERE s.event_code = e.code),
        so_nguoi_nhan = (SELECT COUNT(*) FROM master.email_config c
                         WHERE c.event_code = e.code AND c.is_deleted = 0)
FROM    master.email_events e
WHERE   e.code = N'RECEIVING_ABNORMAL';

/* Xem nội dung đang có — để đối chiếu sau khi ghi đè. */
SELECT  N'1b. Noi dung dang co' AS section,
        tieu_de = e.subject_template,
        than_thu_400_ky_tu_dau = LEFT(ISNULL(e.body_template, N'(rong)'), 400)
FROM    master.email_events e
WHERE   e.code = N'RECEIVING_ABNORMAL';

IF NOT EXISTS (SELECT 1 FROM master.email_events WHERE code = N'RECEIVING_ABNORMAL')
    PRINT N'1. Chua co dong RECEIVING_ABNORMAL — script se THEM MOI.';
GO

/* =====================================================================
   MỤC 2 — CHỌN CHẾ ĐỘ, RỒI GHI
   ===================================================================== */
SELECT N'2. Ghi lai mau thu' AS section;

DECLARE @HardDelete bit = 0;   -- đổi 1 nếu muốn xoá hẳn dòng rồi thêm lại

DECLARE @ng_subject nvarchar(500) =
    N'[SWMS] Hàng bất thường {DocNo} — {NgType} · {Model}';

DECLARE @ng_body nvarchar(max) = N'Kính gửi OQC và FA,

Leader SCS đã duyệt phiếu hàng bất thường **{DocNo}**. Nhờ hai bộ phận vào SWMS
kết luận và chọn hướng xử lý.

| Thông tin | Nội dung |
|---|---|
| Số phiếu | **{DocNo}** |
| Loại bất thường | {NgType} |
| Model | {Model} |
| Pallet ID | {PalletCode} |
| Thời điểm phát hiện | {DiscoveredAt} |
| Leader SCS duyệt | {LeaderBy} |

**Mô tả hiện trạng**

{Description}

**Thứ tự xử lý**

1. OQC kết luận trước: OK hoặc NG.
2. FA chọn hướng xử lý: đổi hàng / chấp nhận / trả lại / huỷ.
3. SCS Supervisor chốt phiếu ở bước cuối.

FA chỉ chọn được hướng xử lý sau khi OQC đã kết luận.

[Mở phiếu trong SWMS]({Link})

---

Thư do SWMS Finish Goods gửi tự động lúc {Now}. Vui lòng không trả lời thư này.';

DECLARE @ng_desc nvarchar(500) =
    N'Hàng bất thường — Leader SCS duyệt xong bước 2, gửi OQC và FA cùng lúc.';

/* ---- Giữ lại thứ tự hiển thị cũ, đừng để nó nhảy xuống cuối danh sách ---- */
DECLARE @sort int = (SELECT sort_order FROM master.email_events
                     WHERE code = N'RECEIVING_ABNORMAL');
IF @sort IS NULL
    SET @sort = (SELECT ISNULL(MAX(sort_order), 0) + 1
                 FROM master.email_events WHERE module = N'RECEIVING');

/* ---- Khoá ngoại nào đang trỏ vào bảng này ---- */
DECLARE @fk int = (SELECT COUNT(*) FROM sys.foreign_keys
                   WHERE referenced_object_id = OBJECT_ID(N'master.email_events'));
DECLARE @con int =
    (SELECT COUNT(*) FROM master.email_event_subtypes WHERE event_code = N'RECEIVING_ABNORMAL')
  + (SELECT COUNT(*) FROM master.email_config        WHERE event_code = N'RECEIVING_ABNORMAL');

IF @HardDelete = 1 AND @fk > 0 AND @con > 0
BEGIN
    PRINT N'2. DUNG LAI: @HardDelete = 1 nhung co khoa ngoai tro vao master.email_events';
    PRINT CONCAT(N'   va dang con ', @con, N' dong con (loai loi + nguoi nhan).');
    PRINT N'   Xoa dong su kien se hoac bi chan, hoac keo theo ca cau hinh nguoi nhan.';
    PRINT N'   Dung @HardDelete = 0 — ket qua giong het, ma khong dong vao nguoi nhan.';
END
ELSE
BEGIN
    BEGIN TRAN;

    IF @HardDelete = 1
    BEGIN
        DELETE FROM master.email_events WHERE code = N'RECEIVING_ABNORMAL';
        PRINT CONCAT(N'2. Da xoa ', @@ROWCOUNT, N' dong cu.');
    END

    IF EXISTS (SELECT 1 FROM master.email_events WHERE code = N'RECEIVING_ABNORMAL')
    BEGIN
        /* Ghi đè tại chỗ. updated_at/by về NULL = "mau do script dat, chua
           ai sua tay" — để lần sau dev_seed_mail_roles.sql lại tự cập nhật
           được, không phải chạy script này nữa. */
        UPDATE  master.email_events
        SET     module           = N'RECEIVING',
                name_key         = N'email.RECEIVING_ABNORMAL',
                description      = @ng_desc,
                subject_template = @ng_subject,
                body_template    = @ng_body,
                is_active        = 1,
                updated_at       = NULL,
                updated_by       = NULL
        WHERE   code = N'RECEIVING_ABNORMAL';

        PRINT CONCAT(N'2. Da ghi de noi dung cho ', @@ROWCOUNT, N' dong.');
    END
    ELSE
    BEGIN
        INSERT INTO master.email_events
            (code, module, name_key, description, subject_template, body_template,
             is_active, sort_order)
        VALUES
            (N'RECEIVING_ABNORMAL', N'RECEIVING', N'email.RECEIVING_ABNORMAL', @ng_desc,
             @ng_subject, @ng_body, 1, @sort);

        PRINT N'2. Da them moi dong RECEIVING_ABNORMAL.';
    END

    COMMIT;
END
GO

/* =====================================================================
   MỤC 3 — ĐỐI CHIẾU SAU KHI GHI
   ===================================================================== */
SELECT N'3. Sau khi ghi' AS section;

SELECT  ma            = e.code,
        dang_bat      = e.is_active,
        da_sua_tay    = IIF(e.updated_at IS NULL, N'khong (dung)', N'CO'),
        thu_tu        = e.sort_order,
        dai_tieu_de   = LEN(ISNULL(e.subject_template, N'')),
        dai_than_thu  = LEN(ISNULL(e.body_template, N'')),
        gui_duoc_chua = CASE
                          WHEN NULLIF(LTRIM(RTRIM(e.subject_template)), N'') IS NULL
                            OR NULLIF(LTRIM(RTRIM(e.body_template)),    N'') IS NULL
                               THEN N'*** CHUA — mau rong ***'
                          WHEN (SELECT COUNT(*) FROM master.email_config c
                                WHERE c.event_code = e.code
                                  AND c.is_active = 1 AND c.is_deleted = 0) = 0
                               THEN N'*** CHUA — chua khai nguoi nhan ***'
                          ELSE N'duoc' END,
        so_loai_loi   = (SELECT COUNT(*) FROM master.email_event_subtypes s
                         WHERE s.event_code = e.code AND s.is_active = 1),
        so_nguoi_nhan = (SELECT COUNT(*) FROM master.email_config c
                         WHERE c.event_code = e.code
                           AND c.is_active = 1 AND c.is_deleted = 0)
FROM    master.email_events e
WHERE   e.code = N'RECEIVING_ABNORMAL';

/* Đủ chín biến chưa — thiếu biến nào thì chỗ đó trong thư sẽ trống. */
SELECT  N'3b. Bien trong mau' AS section,
        bien = v.b,
        co_trong_than_thu = IIF(e.body_template LIKE N'%' + v.b + N'%', N'co', N'khong'),
        co_trong_tieu_de  = IIF(e.subject_template LIKE N'%' + v.b + N'%', N'co', N'khong')
FROM    master.email_events e
CROSS   JOIN (VALUES (N'{DocNo}'), (N'{PalletCode}'), (N'{Model}'), (N'{NgType}'),
                     (N'{Description}'), (N'{LeaderBy}'), (N'{DiscoveredAt}'),
                     (N'{Now}'), (N'{Link}')) v(b)
WHERE   e.code = N'RECEIVING_ABNORMAL';

SELECT  N'3c. Noi dung moi' AS section,
        tieu_de  = e.subject_template,
        than_thu = e.body_template
FROM    master.email_events e
WHERE   e.code = N'RECEIVING_ABNORMAL';
GO

PRINT N'';
PRINT N'=== XONG ===';
PRINT N'Mau thu da thay. Mail van chi gui khi DA KHAI NGUOI NHAN:';
PRINT N'Web > Hang bat thuong > banh rang > Cau hinh email.';
PRINT N'Thu thu bang nut Xem truoc mail trong man phieu.';
PRINT N'';
GO

SET NOEXEC OFF;
GO
