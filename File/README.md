/* =====================================================================
   HƯỚNG XỬ LÝ CỦA FA: TỪ 4 MÃ CHỌN SẴN → CHỮ FA TỰ NHẬP
   ---------------------------------------------------------------------
   Chạy SAU ng_flow_v2_schema.sql, TRƯỚC khi deploy bản API/Web mới nhất.

   Vì sao: bốn mã cũ (replace / accept / return / scrap) không phủ hết
   việc thật, nên phần quan trọng nhất — LÀM GÌ với lô hàng này — bị đẩy
   xuống ô ghi chú tuỳ chọn. Giờ FA gõ thẳng vào ô hướng xử lý.

   Hai việc:
     1. Gỡ ràng buộc ck_ngi_fa_res (chỉ cho 4 mã).
     2. Nới wms.ng_inspections.fa_resolution lên nvarchar(500).

   KHÔNG đụng tới cột wms.ng_inspections.resolution và ràng buộc
   ck_ngi_res của nó: luồng mới KHÔNG còn ghi vào cột đó nữa (xem
   NgReportRepository — ba chỗ gán resolution đã gỡ), nên nó giữ nguyên
   giá trị của phiếu cũ, không có gì vi phạm.

   Phiếu CŨ vẫn mang mã cũ trong fa_resolution. Chỗ hiển thị tự quay về
   in nguyên giá trị khi không tra được nhãn, nên phiếu cũ vẫn đọc ra
   "Đổi hàng" / "Chấp nhận" như trước.

   An toàn: chỉ chạy trên DB tên kết thúc bằng _DEV; chỉ nới, không xoá
   dữ liệu; chạy lại nhiều lần đều được.
   ===================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF RIGHT(DB_NAME(), 4) <> N'_DEV'
BEGIN
    PRINT CONCAT(N'DUNG LAI: dang o DB [', DB_NAME(), N'], khong phai DB _DEV.');
    SET NOEXEC ON;
END
GO

/* =====================================================================
   MỤC 0 — HIỆN TRẠNG
   ===================================================================== */
SELECT  N'0. Hien trang' AS section,
        do_dai_fa_resolution = COL_LENGTH(N'wms.ng_inspections', N'fa_resolution') / 2,
        con_rang_buoc_4_ma   = IIF(OBJECT_ID(N'wms.ck_ngi_fa_res', N'C') IS NULL,
                                   N'da go', N'con');

SELECT  N'0b. Gia tri dang co' AS section,
        huong_xu_ly = ISNULL(fa_resolution, N'(trong)'),
        so_phieu = COUNT(*)
FROM    wms.ng_inspections
WHERE   is_deleted = 0
GROUP   BY fa_resolution
ORDER   BY COUNT(*) DESC;
GO

/* =====================================================================
   MỤC 1 — GỠ RÀNG BUỘC 4 MÃ
   ---------------------------------------------------------------------
   ⚠ Phải ghi rõ schema: OBJECT_ID(N'ck_ngi_fa_res') tra trong schema mặc
   định của người chạy (thường dbo), mà ràng buộc nằm cùng schema với
   BẢNG — tức wms. Thiếu tiền tố thì hàm trả NULL và lệnh gỡ bị bỏ qua.
   ===================================================================== */
SELECT N'1. Go ck_ngi_fa_res' AS section;

IF OBJECT_ID(N'wms.ck_ngi_fa_res', N'C') IS NOT NULL
BEGIN
    ALTER TABLE wms.ng_inspections DROP CONSTRAINT ck_ngi_fa_res;
    PRINT N'1. Da go ck_ngi_fa_res.';
END
ELSE PRINT N'1. ck_ngi_fa_res khong con — bo qua.';
GO

/* =====================================================================
   MỤC 2 — NỚI CỘT LÊN nvarchar(500)
   ---------------------------------------------------------------------
   Nới trước khi API mới chạy. Deploy trước mà cột còn hẹp thì FA nhập
   một câu bình thường là đổ lỗi 2628 "String or binary data would be
   truncated" — lỗi đó ném ở tầng DB nên người dùng chỉ thấy "Đã có lỗi".
   ===================================================================== */
SELECT N'2. Noi fa_resolution' AS section;

IF COL_LENGTH(N'wms.ng_inspections', N'fa_resolution') / 2 < 500
BEGIN
    ALTER TABLE wms.ng_inspections ALTER COLUMN fa_resolution nvarchar(500) NULL;
    PRINT N'2. Da noi fa_resolution len nvarchar(500).';
END
ELSE PRINT N'2. fa_resolution da du rong — bo qua.';
GO

/* =====================================================================
   MỤC 3 — ĐỐI CHIẾU
   ===================================================================== */
SELECT  N'3. Doi chieu' AS section,
        do_dai_fa_resolution = COL_LENGTH(N'wms.ng_inspections', N'fa_resolution') / 2,
        con_rang_buoc_4_ma   = IIF(OBJECT_ID(N'wms.ck_ngi_fa_res', N'C') IS NULL,
                                   N'da go — dung', N'*** VAN CON ***'),
        ghi_chu = N'Cot resolution va ck_ngi_res giu nguyen — luong moi khong ghi vao do nua.';

/* Thử nhận một câu chữ thật — nới đúng chưa thì câu này nói thật. */
BEGIN TRY
    BEGIN TRAN;
    UPDATE TOP (1) wms.ng_inspections
    SET    fa_resolution = N'Tach rieng 12 thung loi, doi hang tu lo ke tiep roi tra lai kho truoc 25/11.'
    WHERE  id = (SELECT MIN(id) FROM wms.ng_inspections);

    DECLARE @tried int = @@ROWCOUNT;
    ROLLBACK;

    IF @tried = 0 PRINT N'3. Bang chua co phieu nao nen khong thu duoc — chua ket luan.';
    ELSE PRINT N'3. fa_resolution nhan duoc chu tu do — dung.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CONCAT(N'3. *** VAN CHUA NHAN: ', ERROR_MESSAGE(), N' ***');
END CATCH
GO

PRINT N'';
PRINT N'=== XONG ===';
PRINT N'Deploy ban Web/API moi nhat sau khi chay script nay.';
PRINT N'';
GO

SET NOEXEC OFF;
GO
