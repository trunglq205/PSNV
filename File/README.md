/* =====================================================================
   VÁ: BẢNG NHẬT KÝ DUYỆT CHƯA NHẬN BƯỚC 'fa_fix'
   ---------------------------------------------------------------------
   Triệu chứng: FA bấm "Đã xử lý xong" thì báo
       "Dữ liệu tham chiếu không hợp lệ hoặc vi phạm ràng buộc"

   Nguyên nhân: ng_flow_v2_schema.sql nới ck_ngi_step — ràng buộc cột
   current_step của BẢNG PHIẾU wms.ng_inspections. Nhưng mỗi lần bấm,
   ApplyStepAsync còn chèn một dòng vào BẢNG NHẬT KÝ
   wms.ng_inspection_approvals, và bảng đó có ràng buộc RIÊNG:

       ck_ngap_step CHECK (step IN (N'leader', N'fa', N'oqc', N'finalize'))

   Hai ràng buộc cùng tên khái niệm "bước" nhưng là hai object khác nhau.
   Nới một cái rồi tưởng xong — đó là chỗ tôi sót. Các bước khác không
   lộ ra vì 'fa', 'oqc', 'leader' đều đã nằm trong danh sách; chỉ bước
   mới 'fa_fix' là vi phạm.

   Cột action KHÔNG có ràng buộc nào, nên 'done' / 'ok' / 'ng' đi qua
   bình thường — đó là lý do FA đánh đạt / không đạt vẫn chạy được.

   GIỮ NGUYÊN 'finalize' trong danh sách dù bước đó đã bỏ: nhật ký cũ
   còn dòng mang giá trị đó, bỏ ra khỏi CHECK là ALTER đổ ngay.

   An toàn: chỉ chạy trên DB tên kết thúc bằng _DEV; chỉ nới ràng buộc,
   không xoá dòng nào; chạy lại nhiều lần đều được.
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
   MỤC 0 — MỌI RÀNG BUỘC CHECK CỦA HAI BẢNG NÀY
   ---------------------------------------------------------------------
   In hết ra để lần này không sót cái nào nữa.
   ===================================================================== */
SELECT  N'0. Rang buoc CHECK dang co' AS section,
        bang = SCHEMA_NAME(t.schema_id) + N'.' + t.name,
        ten  = c.name,
        dinh_nghia = c.definition
FROM    sys.check_constraints c
JOIN    sys.tables t ON t.object_id = c.parent_object_id
WHERE   t.name IN (N'ng_inspections', N'ng_inspection_approvals')
ORDER   BY t.name, c.name;
GO

/* =====================================================================
   MỤC 1 — NỚI ck_ngap_step
   ---------------------------------------------------------------------
   ⚠ Ghi rõ schema: ràng buộc nằm cùng schema với BẢNG (wms), còn
   OBJECT_ID không có tiền tố thì tra trong schema mặc định của người
   chạy (thường dbo) và trả NULL — lệnh gỡ bị bỏ qua, lệnh thêm đâm vào
   lỗi 2714. Đúng lỗi đã gặp hôm 23/11.
   ===================================================================== */
SELECT N'1. Noi ck_ngap_step' AS section;

IF OBJECT_ID(N'wms.ck_ngap_step', N'C') IS NOT NULL
BEGIN
    ALTER TABLE wms.ng_inspection_approvals DROP CONSTRAINT ck_ngap_step;
    PRINT N'1. Da go ck_ngap_step cu.';
END
ELSE PRINT N'1. ck_ngap_step khong co san — se tao moi.';

ALTER TABLE wms.ng_inspection_approvals WITH CHECK
    ADD CONSTRAINT ck_ngap_step CHECK (step IN
        (N'leader', N'fa', N'fa_fix', N'oqc', N'finalize'));
PRINT N'1. Da dat lai ck_ngap_step co them fa_fix.';
GO

/* =====================================================================
   MỤC 2 — ĐỐI CHIẾU
   ===================================================================== */
SELECT  N'2. Doi chieu' AS section,
        ten = c.name,
        dinh_nghia = c.definition,
        co_fa_fix = IIF(c.definition LIKE N'%fa_fix%', N'co — dung', N'*** THIEU ***')
FROM    sys.check_constraints c
WHERE   c.name IN (N'ck_ngap_step', N'ck_ngi_step');

/* Chèn thử một dòng nhật ký bước fa_fix rồi huỷ — nới đúng chưa thì câu
   này nói thật, chứ đọc định nghĩa bằng mắt vẫn có thể nhìn nhầm. */
BEGIN TRY
    BEGIN TRAN;

    DECLARE @ng bigint = (SELECT MIN(id) FROM wms.ng_inspections);

    IF @ng IS NULL
        PRINT N'2. Bang phieu dang rong nen khong thu duoc — chua ket luan.';
    ELSE
    BEGIN
        INSERT INTO wms.ng_inspection_approvals (ng_id, step, action, comment, acted_by)
        VALUES (@ng, N'fa_fix', N'done', N'thu rang buoc, se huy', N'sql-test');
        PRINT N'2. Nhat ky nhan duoc buoc fa_fix — dung.';
    END

    ROLLBACK;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CONCAT(N'2. *** VAN CHUA NHAN: ', ERROR_MESSAGE(), N' ***');
END CATCH
GO

PRINT N'';
PRINT N'=== XONG ===';
PRINT N'Khong can deploy lai code. Bam lai nut "Da xu ly xong" la chay.';
PRINT N'';
GO

SET NOEXEC OFF;
GO
