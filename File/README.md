/* =====================================================================
   HÀNG BẤT THƯỜNG — LUỒNG MỚI: BỎ BƯỚC SUPERVISOR, THÊM VÒNG OQC ⇄ FA
   ---------------------------------------------------------------------
   Chạy script này TRƯỚC khi deploy API/Web bản mới.

   Luồng mới (đã chốt 23/11)

     SCS tạo phiếu
       → Leader SCS duyệt          ⇒ pallet đóng dấu inspection_status = 'ng'
       → OQC đánh giá (ok | ng)    ⇒ bỏ qua nếu loại lỗi không cần OQC
       → FA đánh giá (ok | ng)
            · FA = NG  ⇒ bắt chọn hướng xử lý, phiếu sang bước "FA xử lý";
                         xử lý xong FA XÁC NHẬN LẠI rồi OQC đánh giá lại
            · FA = OK mà OQC = NG ⇒ quay lại OQC đánh giá lại
            · FA = OK và OQC = OK (hoặc không cần OQC)
                       ⇒ ĐÓNG PHIẾU, pallet chuyển 'pass'
     Không còn bước SCS Supervisor chốt.

   Vì sao KHÔNG thêm cột trạng thái mới cho pallet

     wms.pallets.inspection_status ĐÃ CÓ SẴN và đang được dùng thật, với
     bộ mã chuẩn trong Features/Pallets/Business/Entities/InspectionStatus.cs:
       not_inspected · under_inspection · pending_result ·
       pass · ng · inspection_exempt
     'ng' và 'pass' là đúng hai giá trị cần. Đẻ thêm cột là tạo nguồn sự
     thật thứ hai cho cùng một câu hỏi.

   ⚠ HỆ QUẢ PHẢI BIẾT TRƯỚC KHI CHẠY

     Cột đó KHÔNG chỉ để hiện màu. Nó đang gác việc xuất hàng:
     ShipmentInstructionRepository lọc
         AND p.inspection_status IN (N'pass', N'inspection_exempt')
     Nghĩa là Leader SCS duyệt phiếu bất thường là pallet đó LẬP TỨC
     KHÔNG XUẤT ĐƯỢC, cho tới khi OQC và FA cùng OK. Nó cũng đổi màu
     pallet trên bản đồ kho (TempLocMapService).

     Đây gần như chắc chắn là điều anh muốn — nhưng nó chặn thật, nên nói
     trước còn hơn để kho phát hiện lúc soạn hàng.

   An toàn
     • Chỉ chạy trên DB có tên kết thúc bằng _DEV.
     • Chỉ THÊM cột và NỚI ràng buộc. Không xoá cột, không xoá dòng.
     • Chạy lại nhiều lần đều an toàn.
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
   MỤC 0 — HIỆN TRẠNG
   ===================================================================== */
SELECT N'0. Hien trang' AS section;

SELECT  bang_cot = N'wms.pallets.inspection_status',
        tinh_trang = IIF(COL_LENGTH(N'wms.pallets', N'inspection_status') IS NULL,
                         N'*** THIEU — dung lai, bao lai cho toi ***', N'co san')
UNION ALL SELECT N'wms.ng_inspections.fa_result',
        IIF(COL_LENGTH(N'wms.ng_inspections', N'fa_result') IS NULL, N'se them', N'da co')
UNION ALL SELECT N'wms.ng_inspections.review_round',
        IIF(COL_LENGTH(N'wms.ng_inspections', N'review_round') IS NULL, N'se them', N'da co')
UNION ALL SELECT N'wms.ng_inspections.pallet_status_before',
        IIF(COL_LENGTH(N'wms.ng_inspections', N'pallet_status_before') IS NULL, N'se them', N'da co');

SELECT  N'0b. Phieu theo trang thai' AS section,
        trang_thai = doc_status, buoc = current_step, so_phieu = COUNT(*)
FROM    wms.ng_inspections
WHERE   is_deleted = 0
GROUP   BY doc_status, current_step
ORDER   BY doc_status, current_step;
GO

/* =====================================================================
   MỤC 1 — fa_result: KẾT LUẬN OK/NG CỦA FA
   ---------------------------------------------------------------------
   Tách khỏi fa_status và fa_resolution, vì ba thứ trả lời ba câu khác nhau:
     fa_status      — FA đã chốt vòng này chưa (pending / approved)
     fa_result      — FA kết luận hàng OK hay NG   ← CỘT MỚI
     fa_resolution  — NG thì xử lý thế nào (đổi / chấp nhận / trả / huỷ)
   Trước đây FA chỉ chọn hướng xử lý, nên không có gì để so với OQC. Suy
   "chấp nhận = OK" là sai: trả lại hàng cũng có thể là hàng OK mà khách
   không lấy nữa.
   ===================================================================== */
SELECT N'1. fa_result' AS section;

IF COL_LENGTH(N'wms.ng_inspections', N'fa_result') IS NULL
BEGIN
    ALTER TABLE wms.ng_inspections ADD fa_result nvarchar(20) NULL;
    PRINT N'1. Da them cot fa_result.';
END
ELSE PRINT N'1. fa_result da co — bo qua.';
GO

IF OBJECT_ID(N'ck_ngi_fa_result', N'C') IS NULL
BEGIN
    ALTER TABLE wms.ng_inspections WITH CHECK
        ADD CONSTRAINT ck_ngi_fa_result
        CHECK (fa_result IS NULL OR fa_result IN (N'ok', N'ng'));
    PRINT N'1. Da them rang buoc ck_ngi_fa_result.';
END
ELSE PRINT N'1. ck_ngi_fa_result da co — bo qua.';
GO

/* =====================================================================
   MỤC 2 — review_round: VÒNG ĐÁNH GIÁ THỨ MẤY
   ---------------------------------------------------------------------
   OQC và FA đẩy qua đẩy lại được nhiều vòng. Không đánh số vòng thì sơ đồ
   tiến trình chỉ hiện được LẦN CUỐI của mỗi bên, và người đọc không biết
   phiếu đã quay mấy lượt — đúng thứ cần nhìn thấy khi một phiếu mắc kẹt.
   Nhật ký từng lượt vẫn nằm đủ ở wms.ng_inspection_approvals.
   ===================================================================== */
SELECT N'2. review_round' AS section;

IF COL_LENGTH(N'wms.ng_inspections', N'review_round') IS NULL
BEGIN
    ALTER TABLE wms.ng_inspections
        ADD review_round int NOT NULL CONSTRAINT df_ngi_round DEFAULT 1;
    PRINT N'2. Da them cot review_round (mac dinh 1).';
END
ELSE PRINT N'2. review_round da co — bo qua.';
GO

/* =====================================================================
   MỤC 3 — pallet_status_before: TRẠNG THÁI PALLET TRƯỚC KHI ĐÓNG DẤU NG
   ---------------------------------------------------------------------
   Để HOÀN NGUYÊN được. Huỷ phiếu, hoặc lùi phiếu về nháp, mà cứ đặt bừa
   'pass' thì một pallet vốn mang 'inspection_exempt' (miễn kiểm) hay
   'not_inspected' sẽ bị script âm thầm đổi nghĩa. Nhớ giá trị cũ thì trả
   lại đúng cái đang có.
   ===================================================================== */
SELECT N'3. pallet_status_before' AS section;

IF COL_LENGTH(N'wms.ng_inspections', N'pallet_status_before') IS NULL
BEGIN
    ALTER TABLE wms.ng_inspections ADD pallet_status_before nvarchar(30) NULL;
    PRINT N'3. Da them cot pallet_status_before.';
END
ELSE PRINT N'3. pallet_status_before da co — bo qua.';
GO

/* =====================================================================
   MỤC 4 — NỚI ck_ngi_step CHO BƯỚC "FA XỬ LÝ"
   ---------------------------------------------------------------------
   Thêm 'fa_fix'. GIỮ NGUYÊN 'scs_finalize' trong danh sách dù bước đó đã
   bỏ: phiếu cũ còn mang giá trị đó, bỏ ra khỏi CHECK là ALTER đổ ngay.
   ===================================================================== */
SELECT N'4. ck_ngi_step' AS section;

IF OBJECT_ID(N'ck_ngi_step', N'C') IS NOT NULL
BEGIN
    ALTER TABLE wms.ng_inspections DROP CONSTRAINT ck_ngi_step;
    PRINT N'4. Da go ck_ngi_step cu.';
END

ALTER TABLE wms.ng_inspections WITH CHECK
    ADD CONSTRAINT ck_ngi_step CHECK (current_step IN
        (N'created', N'oqc_confirm', N'fa_confirm', N'fa_fix',
         N'scs_finalize', N'done'));
PRINT N'4. Da dat lai ck_ngi_step co them fa_fix.';
GO

/* =====================================================================
   MỤC 5 — VÁ DỮ LIỆU CŨ CHO KHỚP LUỒNG MỚI
   ---------------------------------------------------------------------
   5a. Phiếu ĐÃ CHỐT trước đây: FA từng duyệt mà chưa có fa_result. Luồng
       cũ không có khái niệm OK/NG của FA, nên suy ngược là bịa. Chỉ điền
       cho phiếu đã finalized — ở đó kết quả cuối cùng là đã xong, ghi
       'ok' để sơ đồ mới không hiện một ô trống khó hiểu.
   5b. Phiếu đang chờ Supervisor chốt (ready_to_finalize): luồng mới không
       còn ai bấm nút đó, nên chúng sẽ KẸT. Script chỉ BÁO; đổi
       @CloseReadyDocs = 1 nếu muốn đóng luôn chúng theo luật mới.
   ===================================================================== */
SELECT N'5. Va du lieu cu' AS section;

DECLARE @CloseReadyDocs bit = 0;

UPDATE  wms.ng_inspections
SET     fa_result = N'ok'
WHERE   is_deleted = 0
  AND   fa_result IS NULL
  AND   fa_status = N'approved'
  AND   doc_status = N'finalized';
PRINT CONCAT(N'5a. Da dien fa_result = ok cho ', @@ROWCOUNT, N' phieu da chot truoc day.');

DECLARE @ready int = (SELECT COUNT(*) FROM wms.ng_inspections
                      WHERE is_deleted = 0 AND doc_status = N'ready_to_finalize');

IF @ready = 0
    PRINT N'5b. Khong co phieu nao dang cho Supervisor chot.';
ELSE IF @CloseReadyDocs = 0
BEGIN
    PRINT CONCAT(N'5b. CO ', @ready, N' phieu dang cho Supervisor chot.');
    PRINT N'    Luong moi khong con nut do -> chung se KET.';
    PRINT N'    Doi @CloseReadyDocs = 1 roi chay lai de dong chung theo luat moi.';

    SELECT  N'5b. Phieu se ket' AS section,
            so_phieu = doc_no, oqc = oqc_status, fa = fa_status,
            huong_xu_ly = fa_resolution, tao_luc = created_at
    FROM    wms.ng_inspections
    WHERE   is_deleted = 0 AND doc_status = N'ready_to_finalize'
    ORDER   BY created_at;
END
ELSE
BEGIN
    /* Đóng theo đúng luật mới: chỉ đóng khi OQC không NG. OQC đã kết luận
       NG mà đóng là bỏ qua chính cái vòng vừa dựng ra. */
    UPDATE  wms.ng_inspections
    SET     doc_status   = N'finalized',
            current_step = N'done',
            fa_result    = ISNULL(fa_result, N'ok'),
            resolution   = COALESCE(NULLIF(resolution, N'pending'), fa_resolution, resolution),
            updated_at   = SYSDATETIME(),
            updated_by   = N'ng-flow-v2'
    WHERE   is_deleted = 0
      AND   doc_status = N'ready_to_finalize'
      AND   oqc_status <> N'ng';
    PRINT CONCAT(N'5b. Da dong ', @@ROWCOUNT, N' phieu theo luat moi.');

    UPDATE  wms.ng_inspections
    SET     current_step = N'oqc_confirm',
            doc_status   = N'in_review',
            oqc_status   = N'pending',
            fa_status    = N'pending',
            updated_at   = SYSDATETIME(),
            updated_by   = N'ng-flow-v2'
    WHERE   is_deleted = 0
      AND   doc_status = N'ready_to_finalize'
      AND   oqc_status = N'ng';
    PRINT CONCAT(N'5b. Da tra ', @@ROWCOUNT, N' phieu (OQC da danh NG) ve buoc OQC danh gia lai.');
END
GO

/* =====================================================================
   MỤC 6 — ĐÓNG DẤU NG CHO PALLET CỦA PHIẾU ĐANG MỞ
   ---------------------------------------------------------------------
   Phiếu đã qua Leader duyệt và chưa đóng thì theo luật mới pallet phải
   đang mang 'ng'. Phiếu cũ duyệt trước khi có luật này nên chưa có dấu.

   ⚠ ĐÂY LÀ CHỖ CHẶN XUẤT HÀNG. Mặc định CHỈ XEM TRƯỚC. Đọc danh sách
   xong, đổi @StampExisting = 1 rồi chạy lại nếu đồng ý.
   ===================================================================== */
SELECT N'6. Dong dau NG cho pallet phieu dang mo' AS section;

DECLARE @StampExisting bit = 0;

SELECT  N'6a. Pallet se bi doi trang thai' AS section,
        so_phieu = n.doc_no,
        pallet   = RTRIM(p.pallet_id),
        trang_thai_hien_tai = ISNULL(p.inspection_status, N'(trong)'),
        se_thanh = N'ng',
        xuat_duoc_khong = IIF(p.inspection_status IN (N'pass', N'inspection_exempt'),
                              N'dang xuat duoc -> SE BI CHAN', N'von da khong xuat duoc')
FROM    wms.ng_inspections n
JOIN    wms.pallets p ON p.id = n.lot_id AND p.is_deleted = 0
WHERE   n.is_deleted = 0
  AND   n.leader_status = N'submitted'
  AND   n.doc_status NOT IN (N'finalized', N'cancelled')
  AND   ISNULL(p.inspection_status, N'') <> N'ng'
ORDER   BY n.doc_no;

IF @StampExisting = 0
    PRINT N'6. CHI XEM TRUOC. Doi @StampExisting = 1 roi chay lai de dong dau that.';
ELSE
BEGIN
    /* Nhớ giá trị cũ TRƯỚC, rồi mới ghi đè — làm ngược lại là mất nó. */
    UPDATE  n
    SET     n.pallet_status_before = ISNULL(n.pallet_status_before, ISNULL(p.inspection_status, N''))
    FROM    wms.ng_inspections n
    JOIN    wms.pallets p ON p.id = n.lot_id AND p.is_deleted = 0
    WHERE   n.is_deleted = 0
      AND   n.leader_status = N'submitted'
      AND   n.doc_status NOT IN (N'finalized', N'cancelled')
      AND   ISNULL(p.inspection_status, N'') <> N'ng';
    PRINT CONCAT(N'6. Da nho trang thai cu cua ', @@ROWCOUNT, N' phieu.');

    UPDATE  p
    SET     p.inspection_status = N'ng',
            p.updated_at = SYSDATETIME(),
            p.updated_by = N'ng-flow-v2'
    FROM    wms.pallets p
    JOIN    wms.ng_inspections n ON n.lot_id = p.id
    WHERE   p.is_deleted = 0 AND n.is_deleted = 0
      AND   n.leader_status = N'submitted'
      AND   n.doc_status NOT IN (N'finalized', N'cancelled')
      AND   ISNULL(p.inspection_status, N'') <> N'ng';
    PRINT CONCAT(N'6. Da dong dau ng cho ', @@ROWCOUNT, N' pallet.');
END
GO

/* =====================================================================
   MỤC 7 — ĐỐI CHIẾU
   ===================================================================== */
SELECT N'7. Doi chieu' AS section;

SELECT  hang_muc = v.ten,
        tinh_trang = v.gt
FROM   (VALUES
   (N'cot fa_result',            IIF(COL_LENGTH(N'wms.ng_inspections', N'fa_result') IS NULL, N'*** THIEU ***', N'co')),
   (N'cot review_round',         IIF(COL_LENGTH(N'wms.ng_inspections', N'review_round') IS NULL, N'*** THIEU ***', N'co')),
   (N'cot pallet_status_before', IIF(COL_LENGTH(N'wms.ng_inspections', N'pallet_status_before') IS NULL, N'*** THIEU ***', N'co')),
   (N'ck_ngi_fa_result',         IIF(OBJECT_ID(N'ck_ngi_fa_result', N'C') IS NULL, N'*** THIEU ***', N'co')),
   (N'ck_ngi_step co fa_fix',    IIF(OBJECT_ID(N'ck_ngi_step', N'C') IS NULL, N'*** THIEU ***', N'co'))
       ) v(ten, gt);

/* Thử nhận bước fa_fix — ràng buộc nới đúng chưa thì câu này nói thật. */
BEGIN TRY
    BEGIN TRAN;
    UPDATE TOP (1) wms.ng_inspections SET current_step = N'fa_fix'
    WHERE id = (SELECT MIN(id) FROM wms.ng_inspections);

    DECLARE @tried int = @@ROWCOUNT;
    ROLLBACK;

    IF @tried = 0
        PRINT N'7. Bang chua co phieu nao nen khong thu duoc fa_fix — chua ket luan.';
    ELSE
        PRINT N'7. ck_ngi_step nhan duoc gia tri fa_fix — dung.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CONCAT(N'7. *** ck_ngi_step CHUA nhan fa_fix: ', ERROR_MESSAGE(), N' ***');
END CATCH
GO

PRINT N'';
PRINT N'=== XONG — VIEC TIEP THEO ===';
PRINT N'1. Deploy API + Web ban moi. Chay script nay TRUOC khi deploy.';
PRINT N'2. Quyen abnormal_report.finalize KHONG con gac gi. Khong xoa la quyen';
PRINT N'   (xoa roi khai lai se lam song lai quyen cua moi role tung duoc gan).';
PRINT N'3. Pallet mang inspection_status = ng thi KHONG LEN DUOC PHIEU XUAT.';
PRINT N'';
GO

SET NOEXEC OFF;
GO
