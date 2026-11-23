/* =====================================================================
   ĐƯA MỘT PHIẾU HÀNG BẤT THƯỜNG TỪ "LEADER ĐÃ DUYỆT" VỀ LẠI NHÁP
   ---------------------------------------------------------------------
   Vì sao phải làm bằng SQL: luồng phiếu NG chỉ đi MỘT CHIỀU. Trong
   INgReportService không có hàm nào mở lại phiếu — chỉ có
   LeaderReviewAsync (submit / cancel), OqcConfirmAsync, FaConfirmAsync,
   FinalizeAsync. Và LeaderReviewAsync chặn ngay ở dòng đầu:
   `if (h.DocStatus != "draft") throw Ng.Err.NotWaitingLeader`. Nên phiếu
   lỡ duyệt thì trên màn hình không còn đường nào lùi.

   Script này đảo lại ĐÚNG những gì bước duyệt đã ghi — đọc từ
   NgReportRepository.ApplyStepAsync, nhánh `"leader" when action ==
   "submit"`, không đoán:

     leader_status  N'submitted'          -> N'pending'
     leader_by / _by_code / _at / _comment -> NULL
     doc_status     N'in_review'          -> N'draft'
     current_step   N'oqc_confirm' hoặc N'fa_confirm' -> N'created'
     oqc_status     N'skipped' (do bước này đặt) -> N'pending'

   Giá trị đích lấy từ DEFAULT của bảng lúc tạo phiếu (doc_status
   N'draft', current_step N'created', ba cột *_status N'pending').

   ⚠ MAIL ĐÃ GỬI THÌ KHÔNG THU HỒI ĐƯỢC. Bước 2 duyệt xong là
   NotifyLeaderApprovedAsync bắn mail cho OQC và FA. MỤC 5 cho biết có
   bao nhiêu người nhận đang khai — bằng 0 nghĩa là không ai nhận được
   gì và anh yên tâm; khác 0 thì nên báo họ một câu là phiếu làm lại.

   An toàn
     • Chỉ chạy trên DB có tên kết thúc bằng _DEV.
     • Chỉ đụng ĐÚNG MỘT phiếu. Khớp từ hai phiếu trở lên là DỪNG, bắt
       khai rõ số phiếu — không tự chọn hộ.
     • OQC hoặc FA đã có ý kiến thì DỪNG, không lùi. Lùi lúc đó là xoá
       mất kết luận của người khác.
     • Cả phần sửa nằm trong một transaction.

   Cách chạy: mở SSMS, chọn đúng DB _DEV, F5.
   Phiếu nào: để @DocNo = NULL thì script tự tìm phiếu TẠO HÔM NAY đang
   dừng ở bước Leader đã duyệt. Muốn chỉ đích danh thì điền số phiếu.
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

/* ===== THAM SỐ ===================================================== */
DECLARE @DocNo       nvarchar(50) = NULL;          -- NULL = tự tìm phiếu hôm nay
DECLARE @KeepHistory bit          = 0;             -- 1 = giữ lại dòng nhật ký duyệt
DECLARE @Actor       nvarchar(100) = N'sql-rollback';

/* =====================================================================
   MỤC 1 — TÌM PHIẾU
   ===================================================================== */
SELECT N'1. Tim phieu' AS section;

DECLARE @id bigint, @n int = 0, @multi bit = 0;

IF @DocNo IS NOT NULL
    SELECT @id = id FROM wms.ng_inspections
    WHERE doc_no = @DocNo AND is_deleted = 0;
ELSE
BEGIN
    /* Đúng cái anh mô tả: tạo hôm nay, đang đứng ở bước Leader đã duyệt
       và chưa ai đụng tiếp. */
    SELECT @id = MIN(id) FROM wms.ng_inspections
    WHERE is_deleted = 0
      AND CAST(created_at AS date) = CAST(GETDATE() AS date)
      AND doc_status    = N'in_review'
      AND leader_status = N'submitted'
      AND fa_status     = N'pending'
      AND oqc_status IN (N'pending', N'skipped');

    SET @n = (SELECT COUNT(*) FROM wms.ng_inspections
                      WHERE is_deleted = 0
                        AND CAST(created_at AS date) = CAST(GETDATE() AS date)
                        AND doc_status    = N'in_review'
                        AND leader_status = N'submitted'
                        AND fa_status     = N'pending'
                        AND oqc_status IN (N'pending', N'skipped'));

    IF @n > 1
    BEGIN
        PRINT CONCAT(N'1. DUNG LAI: hom nay co ', @n, N' phieu cung o buoc nay.');
        PRINT N'   Chon mot so phieu trong bang duoi roi dien vao @DocNo, chay lai.';
        SET @id = NULL;
        SET @multi = 1;

        SELECT  N'1b. Cac phieu dang khop' AS section,
                so_phieu = doc_no, tao_luc = created_at, tao_boi = created_by,
                loai_loi = ng_type, duyet_luc = leader_at, duyet_boi = leader_by
        FROM    wms.ng_inspections
        WHERE   is_deleted = 0
          AND   CAST(created_at AS date) = CAST(GETDATE() AS date)
          AND   doc_status    = N'in_review'
          AND   leader_status = N'submitted'
          AND   fa_status     = N'pending'
          AND   oqc_status IN (N'pending', N'skipped')
        ORDER   BY created_at;
    END
END

IF @id IS NULL AND @DocNo IS NOT NULL
    PRINT N'1. DUNG LAI: khong tim thay phieu mang so do (hoac da bi xoa mem).';
ELSE IF @id IS NULL AND @DocNo IS NULL AND @multi = 0
    PRINT N'1. Khong co phieu nao tao hom nay dang dung o buoc Leader da duyet.';

/* Hiện trạng trước khi sửa */
IF @id IS NOT NULL
    SELECT  N'1c. Truoc khi sua' AS section,
            so_phieu = doc_no, trang_thai = doc_status, buoc = current_step,
            leader = leader_status, leader_boi = leader_by, leader_luc = leader_at,
            leader_ghi_chu = leader_comment,
            oqc = oqc_status, fa = fa_status,
            tao_luc = created_at, tao_boi = created_by
    FROM    wms.ng_inspections WHERE id = @id;

/* =====================================================================
   MỤC 2 — KIỂM TRA ĐIỀU KIỆN
   ===================================================================== */
SELECT N'2. Kiem tra dieu kien' AS section;

DECLARE @stop nvarchar(400) = NULL;

IF @id IS NOT NULL
BEGIN
    SELECT @stop =
        CASE
          WHEN doc_status = N'draft'
               THEN N'Phieu DA o trang thai nhap roi — khong co gi de lui.'
          WHEN doc_status IN (N'cancelled', N'finalized')
               THEN N'Phieu da ' + doc_status + N' — khong lui bang script nay.'
          WHEN leader_status <> N'submitted'
               THEN N'leader_status = ' + leader_status + N', khong phai submitted.'
          WHEN oqc_status NOT IN (N'pending', N'skipped')
               THEN N'OQC DA ket luan (' + oqc_status + N'). Lui bay gio la xoa mat ket luan cua OQC.'
          WHEN fa_status <> N'pending'
               THEN N'FA DA chon huong xu ly (' + fa_status + N'). Lui bay gio la xoa mat quyet dinh cua FA.'
          ELSE NULL
        END
    FROM wms.ng_inspections WHERE id = @id;

    IF @stop IS NOT NULL
    BEGIN
        PRINT CONCAT(N'2. DUNG LAI: ', @stop);
        SET @id = NULL;
    END
    ELSE PRINT N'2. Dieu kien dat — chi co buoc Leader can lui.';
END
ELSE PRINT N'2. Bo qua: MUC 1 chua chot duoc phieu nao.';

/* =====================================================================
   MỤC 3 — LÙI VỀ NHÁP
   ===================================================================== */
SELECT N'3. Lui ve nhap' AS section;

IF @id IS NOT NULL
BEGIN
    /* Ghi lại dòng nhật ký sắp xoá, để kết quả chạy còn dấu vết. */
    SELECT  N'3a. Dong nhat ky buoc leader' AS section,
            buoc = step, hanh_dong = action, ghi_chu = comment,
            boi = acted_by, luc = acted_at
    FROM    wms.ng_inspection_approvals
    WHERE   ng_id = @id AND step = N'leader';

    BEGIN TRAN;

    UPDATE  wms.ng_inspections
    SET     doc_status     = N'draft',
            current_step   = N'created',
            leader_status  = N'pending',
            leader_by      = NULL,
            leader_by_code = NULL,
            leader_at      = NULL,
            leader_comment = NULL,
            /* Chỉ trả 'skipped' về 'pending' — đó là giá trị do chính bước
               duyệt đặt khi model không cần OQC. Giá trị khác là của OQC,
               mà MỤC 2 đã chặn trường hợp đó rồi. */
            oqc_status     = CASE WHEN oqc_status = N'skipped' THEN N'pending' ELSE oqc_status END,
            updated_at     = SYSDATETIME(),
            updated_by     = @Actor
    WHERE   id = @id;

    PRINT CONCAT(N'3. Da dua ', @@ROWCOUNT, N' phieu ve nhap.');

    IF @KeepHistory = 0
    BEGIN
        /* Xoá dòng duyệt, nếu không bảng lịch sử trên màn chi tiết hiện
           "Leader duyet luc X" trong khi phieu dang la nhap — va duyet lai
           se co hai dong leader. */
        DELETE FROM wms.ng_inspection_approvals
        WHERE  ng_id = @id AND step = N'leader';

        PRINT CONCAT(N'3. Da xoa ', @@ROWCOUNT, N' dong nhat ky buoc leader.');
    END
    ELSE PRINT N'3. Giu lai nhat ky buoc leader theo @KeepHistory = 1.';

    COMMIT;
END

/* =====================================================================
   MỤC 4 — SAU KHI SỬA
   ===================================================================== */
IF @id IS NOT NULL
    SELECT  N'4. Sau khi sua' AS section,
            so_phieu = doc_no, trang_thai = doc_status, buoc = current_step,
            leader = leader_status, leader_boi = leader_by, leader_luc = leader_at,
            oqc = oqc_status, fa = fa_status,
            sua_luc = updated_at, sua_boi = updated_by,
            dung_chua = IIF(doc_status = N'draft' AND current_step = N'created'
                            AND leader_status = N'pending' AND leader_at IS NULL,
                            N'dung — sua lai va duyet lai duoc', N'*** CHUA DUNG ***'),
            so_dong_nhat_ky = (SELECT COUNT(*) FROM wms.ng_inspection_approvals
                               WHERE ng_id = @id)
    FROM    wms.ng_inspections WHERE id = @id;

/* =====================================================================
   MỤC 5 — MAIL ĐÃ GỬI CHƯA
   ===================================================================== */
SELECT  N'5. Mail buoc 2' AS section,
        so_nguoi_nhan_dang_khai =
            (SELECT COUNT(*) FROM master.email_config
             WHERE event_code = N'RECEIVING_ABNORMAL' AND is_active = 1 AND is_deleted = 0),
        co_mau_thu =
            IIF(EXISTS (SELECT 1 FROM master.email_events
                        WHERE code = N'RECEIVING_ABNORMAL'
                          AND NULLIF(LTRIM(RTRIM(subject_template)), N'') IS NOT NULL
                          AND NULLIF(LTRIM(RTRIM(body_template)),    N'') IS NOT NULL),
                N'co', N'chua'),
        ghi_chu = N'Khong co nguoi nhan HOAC chua co mau thu = khong mail nao duoc gui.';
GO

PRINT N'';
PRINT N'=== XONG ===';
PRINT N'Phieu ve nhap thi man chi tiet lai hien nut Sua va nut Leader duyet.';
PRINT N'Mail da gui thi khong thu hoi duoc — xem MUC 5.';
PRINT N'';
GO

SET NOEXEC OFF;
GO
