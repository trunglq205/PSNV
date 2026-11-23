/* =====================================================================
   DỰNG LẠI DỮ LIỆU NỀN ĐÃ MẤT — MẪU THƯ "HÀNG BẤT THƯỜNG" + VAI TRÒ
   ---------------------------------------------------------------------
   Vì sao có script này
     DB DEV bị dựng lại, phần SCHEMA đã có nhưng phần DỮ LIỆU NỀN thì
     không: mẫu thư của màn Hàng bất thường và toàn bộ vai trò biến mất.
     Thiếu mẫu thư thì bước 2 duyệt xong KHÔNG gửi mail (service tự bỏ
     qua và ghi log). Thiếu vai trò thì không ai gán quyền được cho ai.

   Nguồn: ĐỌC TỪ CODE, không tham chiếu DB PROD.
     • Mã sự kiện, module, name_key   → NgReportService.cs
     • Danh sách biến trong mẫu thư   → NgReportService.Fill()
     • Cột của bảng                   → EmailConfigRepository.cs,
                                        RoleRepository.cs, UserRepository.cs
     • 144 mã quyền                   → Features/Roles/Catalog/Perms.cs
       (quy ước PascalCase → snake_case của PermissionCatalog.Snake)

   ⚠ BỘ VAI TRÒ DƯỚI ĐÂY LÀ TÔI DỰNG LẠI THEO LUỒNG NGHIỆP VỤ TRONG CODE,
     KHÔNG PHẢI BỘ VAI TRÒ CŨ CỦA ANH. Không nơi nào trong source ghi mã
     vai trò cũ (trừ 'admin' xuất hiện ở mẫu CSV nhập user), nên không có
     cách nào đọc lại. Xem MỤC 4, sửa tên/mã trước khi chạy nếu anh còn
     nhớ bộ cũ. Chạy rồi vẫn sửa được trên màn /roles.

   An toàn
     • CHỈ CHẠY TRÊN DB CÓ TÊN KẾT THÚC BẰNG _DEV — sai thì dừng ngay.
     • Không DELETE, không DROP, không TRUNCATE dòng nào.
     • Chỉ THÊM cái còn thiếu. Mẫu thư đã có người sửa tay
       (updated_at IS NOT NULL) thì KHÔNG đè.
     • Chạy lại nhiều lần đều an toàn.

   Cách chạy: mở SSMS, chọn đúng DB _DEV, F5. Đọc MỤC 7 và MỤC 8 ở cuối.
   ===================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ---------------------------------------------------------------------
   CHỐT CHẶN — chạy nhầm DB thật là hỏng dữ liệu thật.
   SET NOEXEC ON giữ nguyên qua mọi batch sau, nên các MỤC phía dưới sẽ
   được biên dịch nhưng KHÔNG chạy.
   --------------------------------------------------------------------- */
IF RIGHT(DB_NAME(), 4) <> N'_DEV'
BEGIN
    PRINT N'==========================================================';
    PRINT CONCAT(N'DUNG LAI: dang o DB [', DB_NAME(), N'], khong phai DB _DEV.');
    PRINT N'Script nay chi duoc chay tren DB DEV. Doi DB roi chay lai.';
    PRINT N'==========================================================';
    SET NOEXEC ON;
END
GO

/* =====================================================================
   MỤC 0a — BẢNG BẮT BUỘC PHẢI CÓ
   ---------------------------------------------------------------------
   Đọc bảng này TRƯỚC. Thiếu một bảng thì các mục sau báo "Invalid object
   name" ngay lúc biên dịch — khối này nói rõ thiếu cái nào, thay vì để
   anh đoán từ một câu lỗi trần.
   ===================================================================== */
SELECT  N'0a. Bang bat buoc' AS section,
        bang = v.t,
        tinh_trang = IIF(OBJECT_ID(v.t, N'U') IS NULL, N'*** THIEU ***', N'co'),
        dung_cho = v.m
FROM   (VALUES (N'master.email_events',        N'muc 1 — mau thu'),
               (N'master.email_event_subtypes',N'muc 2 — phan tang nguoi nhan'),
               (N'master.email_config',        N'bao cao nguoi nhan'),
               (N'master.roles',               N'muc 4'),
               (N'master.permissions',         N'muc 5 — API tu seed'),
               (N'master.role_permissions',    N'muc 5'),
               (N'master.user_roles',          N'muc 6'),
               (N'master.users',               N'muc 6'),
               (N'master.ng_types',            N'muc 2 — co the bo qua')) v(t, m)
ORDER  BY IIF(OBJECT_ID(v.t, N'U') IS NULL, 0, 1), v.t;
GO

/* =====================================================================
   MỤC 0 — HIỆN TRẠNG TRƯỚC KHI GHI
   ===================================================================== */
SELECT N'0. Hien trang truoc khi ghi' AS section;

SELECT  bang            = N'master.email_events',
        so_dong         = (SELECT COUNT(*) FROM master.email_events),
        ghi_chu         = N'su kien mail'
UNION ALL SELECT N'master.email_events (co mau)',
        (SELECT COUNT(*) FROM master.email_events
         WHERE NULLIF(LTRIM(RTRIM(subject_template)), N'') IS NOT NULL
           AND NULLIF(LTRIM(RTRIM(body_template)), N'') IS NOT NULL),
        N'da soan noi dung'
UNION ALL SELECT N'master.email_event_subtypes',
        (SELECT COUNT(*) FROM master.email_event_subtypes), N'phan tang nguoi nhan'
UNION ALL SELECT N'master.email_config',
        (SELECT COUNT(*) FROM master.email_config WHERE is_deleted = 0), N'nguoi nhan mail'
UNION ALL SELECT N'master.roles',
        (SELECT COUNT(*) FROM master.roles WHERE is_deleted = 0), N'vai tro'
UNION ALL SELECT N'master.permissions',
        (SELECT COUNT(*) FROM master.permissions WHERE is_deleted = 0), N'API tu seed luc khoi dong'
UNION ALL SELECT N'master.role_permissions',
        (SELECT COUNT(*) FROM master.role_permissions), N'gan quyen'
UNION ALL SELECT N'master.user_roles',
        (SELECT COUNT(*) FROM master.user_roles), N'gan vai tro cho user';
GO

/* =====================================================================
   MỤC 1 — MẪU THƯ "HÀNG BẤT THƯỜNG" (RECEIVING_ABNORMAL)
   ---------------------------------------------------------------------
   Khi nào gửi: Leader SCS duyệt xong bước 2 → mail cho OQC và FA CÙNG
   LÚC (NgReportService.LeaderApproveAsync).

   Mẫu viết bằng MARKDOWN — MarkdownMail.Render dựng khung HTML màu cam.
   Thẻ HTML gõ thẳng vào mẫu sẽ hiện thành CHỮ, không thành thẻ.

   CHÍN biến được thay, đúng bằng danh sách trong NgReportService.Fill():
     {DocNo} {PalletCode} {Model} {NgType} {Description}
     {LeaderBy} {DiscoveredAt} {Now} {Link}
   Gõ sai tên biến thì nó nằm nguyên trong mail dưới dạng {TenSai}.
   {Link} chỉ dựng được khi appsettings có "Web": { "BaseUrl": "..." }.
   ===================================================================== */
SELECT N'1. Mau thu RECEIVING_ABNORMAL' AS section;

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

/* Chưa có dòng nào ⇒ thêm mới, xếp cuối nhóm RECEIVING. */
IF NOT EXISTS (SELECT 1 FROM master.email_events WHERE code = N'RECEIVING_ABNORMAL')
BEGIN
    DECLARE @sort int =
        (SELECT ISNULL(MAX(sort_order), 0) + 1 FROM master.email_events WHERE module = N'RECEIVING');

    INSERT INTO master.email_events
        (code, module, name_key, description, subject_template, body_template,
         is_active, sort_order)
    VALUES
        (N'RECEIVING_ABNORMAL', N'RECEIVING', N'email.RECEIVING_ABNORMAL', @ng_desc,
         @ng_subject, @ng_body, 1, @sort);

    PRINT N'1. Da them su kien RECEIVING_ABNORMAL kem mau thu.';
END
ELSE
BEGIN
    /* Đã có dòng. Chỉ điền khi mẫu đang RỖNG, hoặc khi chưa ai sửa tay.
       Người ta đã ngồi soạn lại rồi mà script đè mất là tệ hơn cả thiếu. */
    UPDATE  master.email_events
    SET     subject_template = @ng_subject,
            body_template    = @ng_body,
            description      = ISNULL(NULLIF(LTRIM(RTRIM(description)), N''), @ng_desc),
            is_active        = 1
    WHERE   code = N'RECEIVING_ABNORMAL'
      AND   (updated_at IS NULL
             OR NULLIF(LTRIM(RTRIM(subject_template)), N'') IS NULL
             OR NULLIF(LTRIM(RTRIM(body_template)),    N'') IS NULL);

    IF @@ROWCOUNT > 0 PRINT N'1. Da dien lai mau thu cho RECEIVING_ABNORMAL.';
    ELSE PRINT N'1. RECEIVING_ABNORMAL da co mau va da co nguoi sua tay — GIU NGUYEN.';
END
GO

/* =====================================================================
   MỤC 2 — PHÂN TẦNG NGƯỜI NHẬN THEO LOẠI LỖI (email_event_subtypes)
   ---------------------------------------------------------------------
   sub_code của sự kiện này CHÍNH LÀ mã loại lỗi trong master.ng_types.
   Có nó thì màn Cấu hình email mới khai được "lỗi bao bì gửi cho ai,
   lỗi ngoại quan gửi cho ai". Bảng này KHÔNG có cột mẫu thư — một mã
   sự kiện chỉ một mẫu, sub_code chỉ dùng để chọn người nhận.

   Lấy thẳng từ master.ng_types nên mã luôn khớp danh mục thật, kể cả
   khi anh đã sửa danh mục. Dùng EXEC vì master.ng_types có thể chưa
   được tạo — nhắc tên bảng chưa tồn tại trong batch thường là cả batch
   không biên dịch được.
   ===================================================================== */
SELECT N'2. Phan tang nguoi nhan theo loai loi' AS section;

IF OBJECT_ID(N'master.ng_types', N'U') IS NULL
    PRINT N'2. BO QUA: chua co master.ng_types. Chay dev_rebuild_missing_tables.sql truoc.';
ELSE
BEGIN
    EXEC(N'
        INSERT INTO master.email_event_subtypes
            (event_code, sub_code, name_key, severity, sort_order, is_active)
        SELECT  N''RECEIVING_ABNORMAL'', t.code, N''ngtype.'' + t.code, N''info'',
                t.sort_order, 1
        FROM    master.ng_types t
        WHERE   t.is_deleted = 0 AND t.is_active = 1
          AND   NOT EXISTS (SELECT 1 FROM master.email_event_subtypes s
                            WHERE s.event_code = N''RECEIVING_ABNORMAL''
                              AND s.sub_code   = t.code);
        PRINT CONCAT(N''2. Da them '', @@ROWCOUNT, N'' loai loi vao email_event_subtypes.'');
    ');
END
GO

/* =====================================================================
   MỤC 3 — CÁC SỰ KIỆN MAIL KHÁC CODE ĐANG DÙNG
   ---------------------------------------------------------------------
   Chỉ BÁO CÁO, không tự điền. Mỗi sự kiện có bộ biến riêng trong hàm
   Fill() của service tương ứng; điền nhầm biến thì mail gửi ra mang
   nguyên chuỗi {TenBien}. Script dựng lại từng cái nằm ở cột cuối.
   ===================================================================== */
SELECT N'3. Cac su kien mail khac' AS section;

DECLARE @ev TABLE (code nvarchar(100) PRIMARY KEY, mo_ta nvarchar(200), script nvarchar(100));
INSERT INTO @ev (code, mo_ta, script) VALUES
    (N'RECEIVING_ABNORMAL',       N'Hang bat thuong — buoc 2 duyet xong',      N'(muc 1 cua script nay)'),
    (N'RETURN_INSTRUCTION_CREATED', N'Chi thi back hang — buoc 1 tao phieu',   N'return_instruction_schema.sql'),
    (N'RETURN_ACTUAL_CONFIRMED',  N'Chi thi back hang — buoc 2b chot thuc nhan', N'return_actual_schema.sql'),
    (N'RETURN_BACK_FA_APPROVED',  N'Muc 2c — quan ly FA duyet de nghi',        N'return_back_mail_schema.sql'),
    (N'RETURN_BACK_DELIVERED',    N'Muc 2c — WH giao hang cho FA',             N'return_back_mail_schema.sql'),
    (N'OQC_NG',                   N'OQC ket luan NG',                          N'(chua co script)'),
    (N'SHORTAGE_REQUEST',         N'Hang thieu — yeu cau',                      N'(chua co script)'),
    (N'SHORTAGE_DAILY',           N'Hang thieu — bao cao ngay',                 N'(chua co script)'),
    (N'SHORTAGE_ESCALATE',        N'Hang thieu — leo thang',                    N'(chua co script)'),
    (N'SHORTAGE_ETA_DUE',         N'Hang thieu — den han ETA',                  N'(chua co script)'),
    (N'STOCKTAKE_DIFF',           N'Kiem ke — lech ton',                        N'(chua co script)');

SELECT  ma          = v.code,
        y_nghia     = v.mo_ta,
        trong_db    = IIF(e.code IS NULL, N'CHUA CO', N'da co'),
        co_mau_thu  = CASE
                        WHEN e.code IS NULL THEN N'—'
                        WHEN NULLIF(LTRIM(RTRIM(e.subject_template)), N'') IS NULL
                          OR NULLIF(LTRIM(RTRIM(e.body_template)),    N'') IS NULL
                             THEN N'CHUA — se KHONG gui mail'
                        ELSE N'co' END,
        nguoi_nhan  = ISNULL((SELECT COUNT(*) FROM master.email_config c
                              WHERE c.event_code = v.code
                                AND c.is_active = 1 AND c.is_deleted = 0), 0),
        dung_script = v.script
FROM    @ev v
LEFT    JOIN master.email_events e ON e.code = v.code
ORDER   BY IIF(e.code IS NULL, 0, 1), v.code;
GO

/* =====================================================================
   MỤC 4 — VAI TRÒ
   ---------------------------------------------------------------------
   ⚠ ĐÂY LÀ BỘ TÔI DỰNG LẠI THEO LUỒNG TRONG CODE, KHÔNG PHẢI BỘ CŨ.

   Vì sao tách nhiều vai trò thế này: luồng hàng bất thường có 5 bước và
   Perms.cs cố tình cho MỖI BƯỚC MỘT LÁ QUYỀN RIÊNG, để một người không
   gánh được hai bước liền nhau. Gộp hết vào một vai trò "quản lý" là
   xoá mất ý đồ đó.

     B1 SCS tạo phiếu        → scs_wh      (abnormal_report.create)
     B2 Leader SCS duyệt     → scs_leader  (abnormal_report.leader_review)
     B3 OQC kết luận         → oqc         (abnormal_report.oqc_confirm)
     B4 FA chọn hướng xử lý  → fa          (abnormal_report.fa_confirm)
     B5 SCS Supervisor chốt  → scs_manager (abnormal_report.finalize)

   Luồng back hàng cũng vậy: fa → fa_manager → scs_manager.

   'admin' có is_system = 1. Cờ đó KHÔNG phải nhãn trang trí: user mang
   vai trò hệ thống được RoleService trả TOÀN BỘ catalog quyền, không
   qua role_permissions. Và màn /roles không tạo được vai trò hệ thống
   (INSERT của nó luôn ghi is_system = 0) — nên mất rồi thì chỉ dựng lại
   bằng SQL như dưới đây.
   ===================================================================== */
SELECT N'4. Vai tro' AS section;

DECLARE @roles TABLE (code nvarchar(50) PRIMARY KEY, name nvarchar(200),
                      descr nvarchar(400), dot nvarchar(20), is_system bit);
INSERT INTO @roles (code, name, descr, dot, is_system) VALUES
    (N'admin',       N'Quản trị hệ thống', N'Toàn quyền. Vai trò hệ thống — quyền lấy thẳng từ catalog, không qua bảng gán quyền.', N'danger',  1),
    (N'scs_office',  N'SCS Office',        N'Nhập chỉ thị, issue SI, đối chiếu cuối tháng. Không quét kho.', N'info',    0),
    (N'scs_wh',      N'SCS Kho',           N'Quét nhận hàng, lưu kho, kiểm kê, vanning, xuất. Tạo phiếu hàng bất thường (B1).', N'info',    0),
    (N'scs_leader',  N'Leader SCS',        N'Duyệt phiếu hàng bất thường (B2).', N'warning', 0),
    (N'scs_manager', N'Quản lý SCS',       N'Chốt phiếu hàng bất thường (B5), duyệt cho back hàng, duyệt kiểm kê và cân bằng tồn.', N'warning', 0),
    (N'oqc',         N'OQC',               N'Kết luận OK/NG cho phiếu hàng bất thường (B3), lấy và trả mẫu.', N'success', 0),
    (N'fa',          N'FA',                N'Đề nghị nhận lại hàng, chọn hướng xử lý (B4), đóng lại Pallet ID sau rework.', N'info',    0),
    (N'fa_manager',  N'Quản lý FA',        N'Duyệt đề nghị nhận lại hàng của FA.', N'warning', 0);

/* Cắt mô tả cho vừa cột. Không chỗ nào trong code nói độ dài cột
   description, mà mô tả dài hơn cột là cả INSERT đổ lỗi 8152 — nên đo
   cột rồi cắt. COL_LENGTH trả BYTE, nvarchar là 2 byte/ký tự; -1 nghĩa
   là (max), lúc đó không phải cắt. */
DECLARE @dlen int =
    ISNULL(NULLIF(COL_LENGTH('master.roles', 'description'), -1), 8000) / 2;

INSERT INTO master.roles (code, name, description, dot, is_system, created_by)
SELECT  r.code, r.name, LEFT(r.descr, @dlen), r.dot, r.is_system, N'seed-script'
FROM    @roles r
WHERE   NOT EXISTS (SELECT 1 FROM master.roles x
                    WHERE x.code = r.code AND x.is_deleted = 0);

PRINT CONCAT(N'4. Da them ', @@ROWCOUNT, N' vai tro moi (vai tro da co giu nguyen).');
GO

/* =====================================================================
   MỤC 5 — GÁN QUYỀN CHO VAI TRÒ
   ---------------------------------------------------------------------
   Gán theo MÃ QUYỀN, không theo id: master.permissions do API tự seed
   lại mỗi lần khởi động (PermissionCatalogSeeder), id không ổn định
   giữa hai lần dựng DB nhưng mã thì ổn định.

   135 dòng dưới đây sinh từ Perms.cs và đã đối chiếu từng mã với cây
   quyền — mã nào không có trong catalog sẽ hiện ở MỤC 7, không âm thầm
   bỏ qua.

   'admin' KHÔNG nằm trong bảng này: nó lấy trọn 144 mã ở khối riêng bên
   dưới, để màn /roles tick đủ cho người đọc. Quyền thật của nó đến từ
   cờ is_system.
   ===================================================================== */
SELECT N'5. Gan quyen' AS section;

IF (SELECT COUNT(*) FROM master.permissions WHERE is_deleted = 0) = 0
BEGIN
    PRINT N'5. DUNG: master.permissions dang RONG.';
    PRINT N'   Khoi dong API mot lan de PermissionCatalogSeeder seed 144 ma quyen, roi chay lai script nay.';
END
ELSE
BEGIN
    DECLARE @grant TABLE (role_code nvarchar(50), perm_code nvarchar(100));
    INSERT INTO @grant (role_code, perm_code) VALUES
/* Sinh tu Perms.cs — moi ma da doi chieu voi catalog. */
        (N'scs_office', N'part_card.view')
       ,(N'scs_office', N'part_card.print')
       ,(N'scs_office', N'recv_pallet.view')
       ,(N'scs_office', N'abnormal_report.view')
       ,(N'scs_office', N'abnormal_report.print')
       ,(N'scs_office', N'rework_refurbish.view')
       ,(N'scs_office', N'rework_refurbish.create')
       ,(N'scs_office', N'si.view')
       ,(N'scs_office', N'si.create')
       ,(N'scs_office', N'si.update')
       ,(N'scs_office', N'si.completed')
       ,(N'scs_office', N'si.cancel')
       ,(N'scs_office', N'si.cut')
       ,(N'scs_office', N'si.allocate')
       ,(N'scs_office', N'si.print')
       ,(N'scs_office', N'trip.view')
       ,(N'scs_office', N'inventory.view')
       ,(N'scs_office', N'inventory.export')
       ,(N'scs_office', N'stocktake.view')
       ,(N'scs_office', N'reports.view')
       ,(N'scs_office', N'reports.export')
       ,(N'scs_office', N'models.view')
       ,(N'scs_office', N'master.view')
       ,(N'scs_office', N'email_config.view')
       ,(N'scs_wh', N'pda_receiving.receive')
       ,(N'scs_wh', N'pda_receiving.abnormal_report')
       ,(N'scs_wh', N'pda_receiving.temp_location')
       ,(N'scs_wh', N'pda_storage.putaway')
       ,(N'scs_wh', N'pda_storage.move')
       ,(N'scs_wh', N'pda_storage.stocktake_morning')
       ,(N'scs_wh', N'pda_storage.stocktake_shipment')
       ,(N'scs_wh', N'pda_storage.stocktake_monthly')
       ,(N'scs_wh', N'pda_outbound.shipping_instructions')
       ,(N'scs_wh', N'pda_outbound.pick')
       ,(N'scs_wh', N'pda_outbound.tally')
       ,(N'scs_wh', N'pda_outbound.emap_kitting')
       ,(N'scs_wh', N'pda_shipping.vanning')
       ,(N'scs_wh', N'pda_shipping.container')
       ,(N'scs_wh', N'pda_shipping.stowage')
       ,(N'scs_wh', N'part_card.view')
       ,(N'scs_wh', N'part_card.print')
       ,(N'scs_wh', N'recv_pallet.view')
       ,(N'scs_wh', N'recv_pallet.scan')
       ,(N'scs_wh', N'recv_pallet.undo')
       ,(N'scs_wh', N'temploc.view')
       ,(N'scs_wh', N'temploc.assign')
       ,(N'scs_wh', N'temploc.release')
       ,(N'scs_wh', N'stocky.view')
       ,(N'scs_wh', N'stocky.create')
       ,(N'scs_wh', N'stocky.update')
       ,(N'scs_wh', N'stocky.transfer')
       ,(N'scs_wh', N'abnormal_report.view')
       ,(N'scs_wh', N'abnormal_report.create')
       ,(N'scs_wh', N'abnormal_report.print')
       ,(N'scs_wh', N'rework_refurbish.view')
       ,(N'scs_wh', N'rework_refurbish.process')
       ,(N'scs_wh', N'putaway.view')
       ,(N'scs_wh', N'putaway.execute')
       ,(N'scs_wh', N'map.view')
       ,(N'scs_wh', N'map.detail')
       ,(N'scs_wh', N'inventory.view')
       ,(N'scs_wh', N'stocktake.view')
       ,(N'scs_wh', N'stocktake.count')
       ,(N'scs_wh', N'stocktake.recount')
       ,(N'scs_wh', N'si.view')
       ,(N'scs_wh', N'si.pick')
       ,(N'scs_wh', N'picking.view')
       ,(N'scs_wh', N'picking.execute')
       ,(N'scs_wh', N'picking.confirm')
       ,(N'scs_wh', N'serial.view')
       ,(N'scs_wh', N'serial.scan')
       ,(N'scs_wh', N'shortage.view')
       ,(N'scs_wh', N'shortage.request')
       ,(N'scs_wh', N'vanning.view')
       ,(N'scs_wh', N'vanning.execute')
       ,(N'scs_wh', N'container.view')
       ,(N'scs_wh', N'container.inspect')
       ,(N'scs_wh', N'container.seal')
       ,(N'scs_wh', N'stowage.view')
       ,(N'scs_wh', N'stowage.create')
       ,(N'scs_wh', N'trip.view')
       ,(N'scs_wh', N'trip.stow')
       ,(N'scs_wh', N'trip.photo_upload')
       ,(N'scs_leader', N'abnormal_report.view')
       ,(N'scs_leader', N'abnormal_report.leader_review')
       ,(N'scs_leader', N'abnormal_report.print')
       ,(N'scs_leader', N'rework_refurbish.view')
       ,(N'scs_leader', N'recv_pallet.view')
       ,(N'scs_leader', N'part_card.view')
       ,(N'scs_leader', N'inventory.view')
       ,(N'scs_leader', N'reports.view')
       ,(N'scs_manager', N'abnormal_report.view')
       ,(N'scs_manager', N'abnormal_report.finalize')
       ,(N'scs_manager', N'abnormal_report.manage_types')
       ,(N'scs_manager', N'abnormal_report.print')
       ,(N'scs_manager', N'rework_refurbish.view')
       ,(N'scs_manager', N'rework_refurbish.approve_scs')
       ,(N'scs_manager', N'temploc.view')
       ,(N'scs_manager', N'temploc.assign')
       ,(N'scs_manager', N'temploc.release')
       ,(N'scs_manager', N'stocktake.view')
       ,(N'scs_manager', N'stocktake.create')
       ,(N'scs_manager', N'stocktake.assign')
       ,(N'scs_manager', N'stocktake.approve')
       ,(N'scs_manager', N'stocktake.cancel')
       ,(N'scs_manager', N'balance.view')
       ,(N'scs_manager', N'balance.create')
       ,(N'scs_manager', N'balance.approve')
       ,(N'scs_manager', N'stowage.view')
       ,(N'scs_manager', N'stowage.approve')
       ,(N'scs_manager', N'inventory.view')
       ,(N'scs_manager', N'inventory.value')
       ,(N'scs_manager', N'inventory.export')
       ,(N'scs_manager', N'si.view')
       ,(N'scs_manager', N'trip.view')
       ,(N'scs_manager', N'reports.view')
       ,(N'scs_manager', N'reports.export')
       ,(N'scs_manager', N'audit.view')
       ,(N'scs_manager', N'email_config.view')
       ,(N'scs_manager', N'email_config.update')
       ,(N'oqc', N'abnormal_report.view')
       ,(N'oqc', N'abnormal_report.oqc_confirm')
       ,(N'oqc', N'o_q_c.sample')
       ,(N'oqc', N'o_q_c.return')
       ,(N'oqc', N'recv_pallet.view')
       ,(N'oqc', N'part_card.view')
       ,(N'oqc', N'inventory.view')
       ,(N'fa', N'rework_refurbish.view')
       ,(N'fa', N'rework_refurbish.request_back')
       ,(N'fa', N'rework_refurbish.process_fa')
       ,(N'fa', N'abnormal_report.view')
       ,(N'fa', N'abnormal_report.fa_confirm')
       ,(N'fa_manager', N'rework_refurbish.view')
       ,(N'fa_manager', N'rework_refurbish.approve_fa')
       ,(N'fa_manager', N'abnormal_report.view')
    ;

    /* Vai trò nghiệp vụ */
    INSERT INTO master.role_permissions (role_id, permission_id, created_by)
    SELECT  r.id, p.id, N'seed-script'
    FROM    @grant g
    JOIN    master.roles r       ON r.code = g.role_code  AND r.is_deleted = 0
    JOIN    master.permissions p ON p.code = g.perm_code  AND p.is_deleted = 0
    WHERE   NOT EXISTS (SELECT 1 FROM master.role_permissions rp
                        WHERE rp.role_id = r.id AND rp.permission_id = p.id);

    PRINT CONCAT(N'5. Da gan ', @@ROWCOUNT, N' quyen cho cac vai tro nghiep vu.');

    /* admin — trọn catalog */
    INSERT INTO master.role_permissions (role_id, permission_id, created_by)
    SELECT  r.id, p.id, N'seed-script'
    FROM    master.roles r
    CROSS   JOIN master.permissions p
    WHERE   r.code = N'admin' AND r.is_deleted = 0 AND p.is_deleted = 0
      AND   NOT EXISTS (SELECT 1 FROM master.role_permissions rp
                        WHERE rp.role_id = r.id AND rp.permission_id = p.id);

    PRINT CONCAT(N'5. Da gan them ', @@ROWCOUNT, N' quyen cho admin.');
END
GO

/* =====================================================================
   MỤC 6 — GÁN VAI TRÒ admin CHO MỘT TÀI KHOẢN
   ---------------------------------------------------------------------
   Không khai thì bỏ qua. Khai mã nhân viên vào @AdminEmployeeCode rồi
   chạy lại script là xong — cần ít nhất một tài khoản vào được màn
   /roles, nếu không thì có vai trò mà không ai gán được cho ai.
   ===================================================================== */
SELECT N'6. Gan vai tro admin' AS section;

DECLARE @AdminEmployeeCode nvarchar(50) = NULL;   -- vd: N'008421'

IF @AdminEmployeeCode IS NULL
BEGIN
    PRINT N'6. BO QUA: chua khai @AdminEmployeeCode.';
    SELECT TOP (20) ma_nhan_vien = u.employee_code, ho_ten = u.full_name, email = u.email,
           vai_tro_dang_co = ISNULL(STUFF((SELECT N', ' + r2.code
                                           FROM master.user_roles ur2
                                           JOIN master.roles r2 ON r2.id = ur2.role_id AND r2.is_deleted = 0
                                           WHERE ur2.user_id = u.id
                                           FOR XML PATH(''), TYPE).value(N'.', N'nvarchar(max)'), 1, 2, N''), N'(chua co)')
    FROM   master.users u
    WHERE  u.is_deleted = 0
    ORDER  BY u.employee_code;
END
ELSE IF NOT EXISTS (SELECT 1 FROM master.users WHERE employee_code = @AdminEmployeeCode AND is_deleted = 0)
    PRINT N'6. DUNG: khong co tai khoan nao mang ma nhan vien do.';
ELSE
BEGIN
    INSERT INTO master.user_roles (user_id, role_id)
    SELECT  u.id, r.id
    FROM    master.users u
    CROSS   JOIN master.roles r
    WHERE   u.employee_code = @AdminEmployeeCode AND u.is_deleted = 0
      AND   r.code = N'admin' AND r.is_deleted = 0
      AND   NOT EXISTS (SELECT 1 FROM master.user_roles ur
                        WHERE ur.user_id = u.id AND ur.role_id = r.id);

    PRINT CONCAT(N'6. Da gan vai tro admin cho ', @AdminEmployeeCode, N' (', @@ROWCOUNT, N' dong).');
    PRINT N'   Tai khoan do phai DANG XUAT DANG NHAP LAI; quyen con dem 5 phut trong API.';
END
GO

/* =====================================================================
   MỤC 7 — TỰ ĐỐI CHIẾU
   ===================================================================== */
SELECT N'7. Tu doi chieu' AS section;

/* 7.1 Mã quyền trong script mà catalog không có (gõ sai, hoặc catalog đổi) */
DECLARE @chk TABLE (role_code nvarchar(50), perm_code nvarchar(100));
INSERT INTO @chk (role_code, perm_code) VALUES
/* Sinh tu Perms.cs — moi ma da doi chieu voi catalog. */
        (N'scs_office', N'part_card.view')
       ,(N'scs_office', N'part_card.print')
       ,(N'scs_office', N'recv_pallet.view')
       ,(N'scs_office', N'abnormal_report.view')
       ,(N'scs_office', N'abnormal_report.print')
       ,(N'scs_office', N'rework_refurbish.view')
       ,(N'scs_office', N'rework_refurbish.create')
       ,(N'scs_office', N'si.view')
       ,(N'scs_office', N'si.create')
       ,(N'scs_office', N'si.update')
       ,(N'scs_office', N'si.completed')
       ,(N'scs_office', N'si.cancel')
       ,(N'scs_office', N'si.cut')
       ,(N'scs_office', N'si.allocate')
       ,(N'scs_office', N'si.print')
       ,(N'scs_office', N'trip.view')
       ,(N'scs_office', N'inventory.view')
       ,(N'scs_office', N'inventory.export')
       ,(N'scs_office', N'stocktake.view')
       ,(N'scs_office', N'reports.view')
       ,(N'scs_office', N'reports.export')
       ,(N'scs_office', N'models.view')
       ,(N'scs_office', N'master.view')
       ,(N'scs_office', N'email_config.view')
       ,(N'scs_wh', N'pda_receiving.receive')
       ,(N'scs_wh', N'pda_receiving.abnormal_report')
       ,(N'scs_wh', N'pda_receiving.temp_location')
       ,(N'scs_wh', N'pda_storage.putaway')
       ,(N'scs_wh', N'pda_storage.move')
       ,(N'scs_wh', N'pda_storage.stocktake_morning')
       ,(N'scs_wh', N'pda_storage.stocktake_shipment')
       ,(N'scs_wh', N'pda_storage.stocktake_monthly')
       ,(N'scs_wh', N'pda_outbound.shipping_instructions')
       ,(N'scs_wh', N'pda_outbound.pick')
       ,(N'scs_wh', N'pda_outbound.tally')
       ,(N'scs_wh', N'pda_outbound.emap_kitting')
       ,(N'scs_wh', N'pda_shipping.vanning')
       ,(N'scs_wh', N'pda_shipping.container')
       ,(N'scs_wh', N'pda_shipping.stowage')
       ,(N'scs_wh', N'part_card.view')
       ,(N'scs_wh', N'part_card.print')
       ,(N'scs_wh', N'recv_pallet.view')
       ,(N'scs_wh', N'recv_pallet.scan')
       ,(N'scs_wh', N'recv_pallet.undo')
       ,(N'scs_wh', N'temploc.view')
       ,(N'scs_wh', N'temploc.assign')
       ,(N'scs_wh', N'temploc.release')
       ,(N'scs_wh', N'stocky.view')
       ,(N'scs_wh', N'stocky.create')
       ,(N'scs_wh', N'stocky.update')
       ,(N'scs_wh', N'stocky.transfer')
       ,(N'scs_wh', N'abnormal_report.view')
       ,(N'scs_wh', N'abnormal_report.create')
       ,(N'scs_wh', N'abnormal_report.print')
       ,(N'scs_wh', N'rework_refurbish.view')
       ,(N'scs_wh', N'rework_refurbish.process')
       ,(N'scs_wh', N'putaway.view')
       ,(N'scs_wh', N'putaway.execute')
       ,(N'scs_wh', N'map.view')
       ,(N'scs_wh', N'map.detail')
       ,(N'scs_wh', N'inventory.view')
       ,(N'scs_wh', N'stocktake.view')
       ,(N'scs_wh', N'stocktake.count')
       ,(N'scs_wh', N'stocktake.recount')
       ,(N'scs_wh', N'si.view')
       ,(N'scs_wh', N'si.pick')
       ,(N'scs_wh', N'picking.view')
       ,(N'scs_wh', N'picking.execute')
       ,(N'scs_wh', N'picking.confirm')
       ,(N'scs_wh', N'serial.view')
       ,(N'scs_wh', N'serial.scan')
       ,(N'scs_wh', N'shortage.view')
       ,(N'scs_wh', N'shortage.request')
       ,(N'scs_wh', N'vanning.view')
       ,(N'scs_wh', N'vanning.execute')
       ,(N'scs_wh', N'container.view')
       ,(N'scs_wh', N'container.inspect')
       ,(N'scs_wh', N'container.seal')
       ,(N'scs_wh', N'stowage.view')
       ,(N'scs_wh', N'stowage.create')
       ,(N'scs_wh', N'trip.view')
       ,(N'scs_wh', N'trip.stow')
       ,(N'scs_wh', N'trip.photo_upload')
       ,(N'scs_leader', N'abnormal_report.view')
       ,(N'scs_leader', N'abnormal_report.leader_review')
       ,(N'scs_leader', N'abnormal_report.print')
       ,(N'scs_leader', N'rework_refurbish.view')
       ,(N'scs_leader', N'recv_pallet.view')
       ,(N'scs_leader', N'part_card.view')
       ,(N'scs_leader', N'inventory.view')
       ,(N'scs_leader', N'reports.view')
       ,(N'scs_manager', N'abnormal_report.view')
       ,(N'scs_manager', N'abnormal_report.finalize')
       ,(N'scs_manager', N'abnormal_report.manage_types')
       ,(N'scs_manager', N'abnormal_report.print')
       ,(N'scs_manager', N'rework_refurbish.view')
       ,(N'scs_manager', N'rework_refurbish.approve_scs')
       ,(N'scs_manager', N'temploc.view')
       ,(N'scs_manager', N'temploc.assign')
       ,(N'scs_manager', N'temploc.release')
       ,(N'scs_manager', N'stocktake.view')
       ,(N'scs_manager', N'stocktake.create')
       ,(N'scs_manager', N'stocktake.assign')
       ,(N'scs_manager', N'stocktake.approve')
       ,(N'scs_manager', N'stocktake.cancel')
       ,(N'scs_manager', N'balance.view')
       ,(N'scs_manager', N'balance.create')
       ,(N'scs_manager', N'balance.approve')
       ,(N'scs_manager', N'stowage.view')
       ,(N'scs_manager', N'stowage.approve')
       ,(N'scs_manager', N'inventory.view')
       ,(N'scs_manager', N'inventory.value')
       ,(N'scs_manager', N'inventory.export')
       ,(N'scs_manager', N'si.view')
       ,(N'scs_manager', N'trip.view')
       ,(N'scs_manager', N'reports.view')
       ,(N'scs_manager', N'reports.export')
       ,(N'scs_manager', N'audit.view')
       ,(N'scs_manager', N'email_config.view')
       ,(N'scs_manager', N'email_config.update')
       ,(N'oqc', N'abnormal_report.view')
       ,(N'oqc', N'abnormal_report.oqc_confirm')
       ,(N'oqc', N'o_q_c.sample')
       ,(N'oqc', N'o_q_c.return')
       ,(N'oqc', N'recv_pallet.view')
       ,(N'oqc', N'part_card.view')
       ,(N'oqc', N'inventory.view')
       ,(N'fa', N'rework_refurbish.view')
       ,(N'fa', N'rework_refurbish.request_back')
       ,(N'fa', N'rework_refurbish.process_fa')
       ,(N'fa', N'abnormal_report.view')
       ,(N'fa', N'abnormal_report.fa_confirm')
       ,(N'fa_manager', N'rework_refurbish.view')
       ,(N'fa_manager', N'rework_refurbish.approve_fa')
       ,(N'fa_manager', N'abnormal_report.view')
    ;

SELECT  loi = N'7.1 Ma quyen khong co trong master.permissions',
        vai_tro = c.role_code, ma_quyen = c.perm_code
FROM    @chk c
WHERE   NOT EXISTS (SELECT 1 FROM master.permissions p
                    WHERE p.code = c.perm_code AND p.is_deleted = 0);

/* 7.2 Vai trò và số quyền đang có */
SELECT  N'7.2 Vai tro' AS muc,
        ma        = r.code,
        ten       = r.name,
        he_thong  = IIF(r.is_system = 1, N'CO — toan quyen', N''),
        so_quyen  = (SELECT COUNT(*) FROM master.role_permissions rp
                     JOIN master.permissions p ON p.id = rp.permission_id AND p.is_deleted = 0
                     WHERE rp.role_id = r.id),
        so_user   = (SELECT COUNT(*) FROM master.user_roles ur WHERE ur.role_id = r.id)
FROM    master.roles r
WHERE   r.is_deleted = 0
ORDER   BY r.is_system DESC, r.code;

/* 7.3 Năm bước của luồng hàng bất thường — bước nào chưa ai cầm */
SELECT  N'7.3 Luong hang bat thuong' AS muc,
        buoc = v.buoc, ma_quyen = v.perm,
        vai_tro_dang_co = ISNULL(STUFF((SELECT N', ' + r.code
                                        FROM master.role_permissions rp
                                        JOIN master.roles r ON r.id = rp.role_id AND r.is_deleted = 0
                                        JOIN master.permissions p ON p.id = rp.permission_id AND p.is_deleted = 0
                                        WHERE p.code = v.perm
                                        ORDER BY r.code
                                        FOR XML PATH(''), TYPE).value(N'.', N'nvarchar(max)'), 1, 2, N''),
                               N'*** CHUA AI CO — buoc nay dung ***')
FROM   (VALUES (N'B1 SCS tao phieu',       N'abnormal_report.create'),
               (N'B2 Leader SCS duyet',    N'abnormal_report.leader_review'),
               (N'B3 OQC ket luan',        N'abnormal_report.oqc_confirm'),
               (N'B4 FA chon huong xu ly', N'abnormal_report.fa_confirm'),
               (N'B5 SCS Supervisor chot', N'abnormal_report.finalize'),
               (N'Quan tri danh muc loi',  N'abnormal_report.manage_types')) v(buoc, perm);

/* 7.4 Mail hàng bất thường đã gửi được chưa */
SELECT  N'7.4 Mail hang bat thuong' AS muc,
        co_su_kien   = IIF(EXISTS (SELECT 1 FROM master.email_events WHERE code = N'RECEIVING_ABNORMAL'),
                           N'co', N'*** CHUA ***'),
        co_mau_thu   = IIF(EXISTS (SELECT 1 FROM master.email_events
                                   WHERE code = N'RECEIVING_ABNORMAL'
                                     AND NULLIF(LTRIM(RTRIM(subject_template)), N'') IS NOT NULL
                                     AND NULLIF(LTRIM(RTRIM(body_template)),    N'') IS NOT NULL),
                           N'co', N'*** CHUA — se khong gui ***'),
        so_loai_loi  = (SELECT COUNT(*) FROM master.email_event_subtypes
                        WHERE event_code = N'RECEIVING_ABNORMAL' AND is_active = 1),
        so_nguoi_nhan= (SELECT COUNT(*) FROM master.email_config
                        WHERE event_code = N'RECEIVING_ABNORMAL'
                          AND is_active = 1 AND is_deleted = 0),
        ghi_chu      = N'Khong co nguoi nhan thi mail van KHONG gui. Khai o man Cau hinh email.';
GO

/* =====================================================================
   MỤC 8 — CÒN PHẢI LÀM BẰNG TAY
   ===================================================================== */
PRINT N'';
PRINT N'=== CON PHAI LAM BANG TAY ===';
PRINT N'1. NGUOI NHAN MAIL: script khong tu dien duoc vi can dia chi that.';
PRINT N'   Vao Web > Hang bat thuong > banh rang > tab Cau hinh email, them';
PRINT N'   nguoi nhan TO/CC. Muon tach theo loai loi thi chon sub_code (MUC 2).';
PRINT N'2. GAN VAI TRO CHO USER: man /roles, hoac khai @AdminEmployeeCode o MUC 6.';
PRINT N'3. QUYEN CO DEM 5 PHUT trong API va KHONG xoa duoc bang dang xuat.';
PRINT N'   Doi quyen xong ma van an 403 thi doi het 5 phut hoac restart API.';
PRINT N'4. DOI TEN/MA VAI TRO neu bo cu cua anh khac — sua tren man /roles.';
PRINT N'';
GO

SET NOEXEC OFF;
GO
