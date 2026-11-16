/* ============================================================================
   Mục 2c — ĐÁNH SỐ LẦN ĐỀ NGHỊ + tiến trình con                      (12/11)

   VÌ SAO:
     Luồng back cũ coi "một phiếu = một lần đề nghị". Từ 10/11 FA xin được một
     phần, nên một phiếu 500 con mà FA xin 20 thì giao xong 20 là HẾT đường:
     API chặn "phiếu đã có đề nghị", FA không đề nghị tiếp được, và tiến trình
     phiếu tick xong ở bước giao hàng trong khi 480 con vẫn nằm trong kho.

     Nay mỗi lượt đề nghị có SỐ LẦN riêng. Phiếu đi đi lại lại bốn bước
     (đề nghị → QL FA → QL SCS → giao) bao nhiêu lần cũng được, miễn còn hàng ở
     kho; tiến trình phiếu hiện mỗi lần thành MỘT TIẾN TRÌNH CON.

   BA CỘT + MỘT BẢNG:
     return_instructions.back_round   lần ĐANG mở (0 = chưa ai đề nghị)
     return_back_lines.round          dòng đề nghị thuộc lần nào
     return_back_deliveries.round     lượt giao thuộc lần nào
     wms.return_back_rounds           mốc (ai · lúc nào) của TỪNG lần

   ⚠ RÀNG BUỘC PHẢI GIỮ: các cột `back_*` trên `return_instructions` là BẢN SAO
     của lần ĐANG mở. Mọi câu đọc danh sách / lọc / mail / PDA đều đang đọc
     chúng nên không bỏ được, nhưng thêm bảng rounds là có hai chỗ ghi cùng một
     việc. Hai chỗ đó phải ghi TRONG CÙNG transaction. Mục 7 có câu soát lệch —
     chạy nó sau mỗi lần sửa luồng back.

   CHẠY SAU: return_back_merge_schema.sql, return_back_phase2_schema.sql.
   ========================================================================= */

/* ---------- 0. Điều kiện tiên quyết — BATCH RIÊNG, có GO ---------- */

IF OBJECT_ID(N'wms.return_back_lines', N'U') IS NULL
    RAISERROR(N'THIEU bang wms.return_back_lines — chay return_back_phase2_schema.sql truoc.', 16, 1);

IF OBJECT_ID(N'wms.return_back_deliveries', N'U') IS NULL
    RAISERROR(N'THIEU bang wms.return_back_deliveries — chay return_back_merge_schema.sql truoc.', 16, 1);

IF COL_LENGTH(N'wms.return_instructions', N'back_status') IS NULL
    RAISERROR(N'THIEU cot back_status — chay return_back_merge_schema.sql truoc.', 16, 1);
GO

SET NOCOUNT ON;
PRINT N'=== return_back_round_schema.sql ===';

/* ---------------------------------------------------------------------------
   1. return_instructions.back_round — lần đang mở.

      0 = chưa ai đề nghị. Lần đầu đề nghị là 1. Dùng NOT NULL DEFAULT 0 để
      không phải viết `ISNULL(back_round, 0)` ở mọi câu đọc.
--------------------------------------------------------------------------- */
PRINT N'1. back_round';

IF COL_LENGTH(N'wms.return_instructions', N'back_round') IS NULL
BEGIN
    ALTER TABLE wms.return_instructions
        ADD back_round INT NOT NULL CONSTRAINT df_ri_back_round DEFAULT (0);
    PRINT N'   + back_round';
END
ELSE
    PRINT N'   = back_round da co';
GO

/* Dữ liệu cũ: phiếu nào đã có luồng back là đang ở lần 1.
   BATCH RIÊNG vì câu này đọc cột vừa thêm ở batch trên. */
UPDATE wms.return_instructions
SET    back_round = 1
WHERE  back_status IS NOT NULL
  AND  back_round = 0;

PRINT CONCAT(N'   ~ dat back_round = 1 cho ', @@ROWCOUNT, N' phieu da co luong back');
GO

/* ---------------------------------------------------------------------------
   2. return_back_lines.round + đổi chỉ mục duy nhất.

      ux_rbl_doc_model(doc_id, model) PHẢI đổi thành (doc_id, round, model):
      để nguyên thì lần 2 xin lại đúng model đó là chèn không vào được, và
      luồng sẽ "đề nghị thành công" ở header rồi vỡ ở dòng.
--------------------------------------------------------------------------- */
PRINT N'2. return_back_lines.round';

IF COL_LENGTH(N'wms.return_back_lines', N'round') IS NULL
BEGIN
    ALTER TABLE wms.return_back_lines
        ADD round INT NOT NULL CONSTRAINT df_rbl_round DEFAULT (1);
    PRINT N'   + round';
END
ELSE
    PRINT N'   = round da co';
GO

/* Tìm chỉ mục THEO CỘT, không theo tên: tên do script trước đặt, và đoán tên
   là sai (đã trả giá ở bản gộp với fk_rbd_req). */
DECLARE @ix sysname = (
    SELECT TOP 1 i.name
    FROM   sys.indexes i
    WHERE  i.object_id = OBJECT_ID(N'wms.return_back_lines')
      AND  i.is_unique = 1
      AND  i.is_primary_key = 0
      AND  (SELECT COUNT(*) FROM sys.index_columns ic
            WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id) = 2
      AND  EXISTS (SELECT 1 FROM sys.index_columns ic
                   JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                   WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id
                     AND c.name = N'model'));

IF @ix IS NOT NULL
BEGIN
    EXEC(N'DROP INDEX ' + @ix + N' ON wms.return_back_lines;');
    PRINT CONCAT(N'   - ', @ix, N' (ban 2 cot)');
END

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = N'ux_rbl_doc_round_model'
                 AND object_id = OBJECT_ID(N'wms.return_back_lines'))
BEGIN
    EXEC(N'CREATE UNIQUE INDEX ux_rbl_doc_round_model
               ON wms.return_back_lines(doc_id, round, model);');
    PRINT N'   + ux_rbl_doc_round_model';
END
ELSE
    PRINT N'   = ux_rbl_doc_round_model da co';
GO

/* ---------------------------------------------------------------------------
   3. return_back_deliveries.round — lượt giao thuộc lần nào.

      Đây là nguồn để tính "lần này đã giao bao nhiêu". Không tính từ sổ serial
      được: serial chỉ mang trạng thái at_fa, không mang số lần.
--------------------------------------------------------------------------- */
PRINT N'3. return_back_deliveries.round';

IF COL_LENGTH(N'wms.return_back_deliveries', N'round') IS NULL
BEGIN
    ALTER TABLE wms.return_back_deliveries
        ADD round INT NOT NULL CONSTRAINT df_rbd_round DEFAULT (1);
    PRINT N'   + round';
END
ELSE
    PRINT N'   = round da co';
GO

/* ---------------------------------------------------------------------------
   3b. return_instruction_serials.back_round — con này đi FA ở LẦN nào.

       Vì sao phải có: tiến trình con cần "lần này đã giao bao nhiêu TRÊN MỖI
       MODEL" (FA xin theo model), mà nhật ký giao chỉ đếm serial theo pallet,
       không chia theo model. Sổ serial là chỗ duy nhất biết cả model lẫn lượt
       đi — nên đóng số lần vào chính dòng serial, trong cùng câu UPDATE đổi
       trạng thái sang at_fa.

       NULL = chưa đi lần nào, hoặc dữ liệu giao trước 12/11.
--------------------------------------------------------------------------- */
PRINT N'3b. return_instruction_serials.back_round';

IF COL_LENGTH(N'wms.return_instruction_serials', N'back_round') IS NULL
BEGIN
    ALTER TABLE wms.return_instruction_serials ADD back_round INT NULL;
    PRINT N'   + back_round';
END
ELSE
    PRINT N'   = back_round da co';
GO

/* Dữ liệu cũ: con nào đã rời kho (at_fa / returned / shipped / ng) thì tính là
   của lần 1 — phiếu cũ chỉ có đúng một lần. */
UPDATE wms.return_instruction_serials
SET    back_round = 1
WHERE  back_round IS NULL
  AND  status <> N'received'
  AND  is_deleted = 0;

PRINT CONCAT(N'   ~ dat back_round = 1 cho ', @@ROWCOUNT, N' serial da roi kho');
GO

/* ---------------------------------------------------------------------------
   4. wms.return_back_rounds — mốc của TỪNG lần đề nghị.

      Vì sao phải có bảng: tiến trình con cần "ai duyệt, lúc nào" của các lần
      ĐÃ XONG, mà các cột back_* chỉ giữ được lần đang mở — lần sau ghi lên là
      mất dấu lần trước.

      asked_qty là ẢNH CHỤP lúc đề nghị, NULL = xin TOÀN BỘ phần còn ở kho
      (giữ đúng nghĩa "không khai dòng nào" của luồng 10/11). Không suy lại từ
      dòng đề nghị vì "toàn bộ" là một con số thay đổi theo thời gian.
--------------------------------------------------------------------------- */
PRINT N'4. wms.return_back_rounds';

IF OBJECT_ID(N'wms.return_back_rounds', N'U') IS NULL
BEGIN
    CREATE TABLE wms.return_back_rounds
    (
        id              BIGINT IDENTITY(1,1) NOT NULL,
        doc_id          BIGINT         NOT NULL,
        round           INT            NOT NULL,

        /* NULL = xin toàn bộ phần còn ở kho lúc đề nghị. */
        asked_qty       INT            NULL,

        note            NVARCHAR(500)  NULL,
        requested_by    NVARCHAR(100)  NULL,
        requested_at    DATETIME2(0)   NULL,

        fa_approved_by  NVARCHAR(100)  NULL,
        fa_approved_at  DATETIME2(0)   NULL,
        fa_comment      NVARCHAR(500)  NULL,

        scs_approved_by NVARCHAR(100)  NULL,
        scs_approved_at DATETIME2(0)   NULL,
        scs_comment     NVARCHAR(500)  NULL,

        delivered_by    NVARCHAR(100)  NULL,
        delivered_at    DATETIME2(0)   NULL,

        cancelled_by    NVARCHAR(100)  NULL,
        cancelled_at    DATETIME2(0)   NULL,
        cancel_reason   NVARCHAR(500)  NULL,

        created_at      DATETIME2(0)   NOT NULL
            CONSTRAINT df_rbr_created DEFAULT (SYSDATETIME()),

        CONSTRAINT pk_return_back_rounds PRIMARY KEY CLUSTERED (id),
        CONSTRAINT ck_rbr_round CHECK (round > 0),

        /* Xoá phiếu là dọn luôn: mốc của một phiếu không còn thì vô nghĩa. */
        CONSTRAINT fk_rbr_doc FOREIGN KEY (doc_id)
            REFERENCES wms.return_instructions(id) ON DELETE CASCADE
    );

    /* Một phiếu chỉ có MỘT dòng cho mỗi số lần — chặn ngay ở DB để hai người
       bấm "đề nghị tiếp" cùng lúc không tạo hai lần cùng số. */
    CREATE UNIQUE INDEX ux_rbr_doc_round ON wms.return_back_rounds(doc_id, round);

    PRINT N'   + wms.return_back_rounds';
END
ELSE
    PRINT N'   = wms.return_back_rounds da co';
GO

/* ---------------------------------------------------------------------------
   5. Dữ liệu cũ: dựng dòng lần 1 từ chính các cột back_*.

      asked_qty: phiếu có dòng đề nghị thì cộng dòng; không có dòng nào thì để
      NULL (xin toàn bộ) — đúng nghĩa của dữ liệu trước 12/11.
--------------------------------------------------------------------------- */
PRINT N'5. Dung dong lan 1 cho du lieu cu';

INSERT INTO wms.return_back_rounds
    (doc_id, round, asked_qty, note,
     requested_by, requested_at,
     fa_approved_by, fa_approved_at, fa_comment,
     scs_approved_by, scs_approved_at, scs_comment,
     delivered_by, delivered_at,
     cancelled_by, cancelled_at, cancel_reason)
SELECT  d.id,
        1,
        l.asked_qty,
        d.back_note,
        d.back_requested_by,   d.back_requested_at,
        d.back_approved_by,    d.back_approved_at,    d.back_fa_comment,
        d.back_scs_approved_by, d.back_scs_approved_at, d.back_scs_comment,
        d.back_delivered_by,   d.back_delivered_at,
        d.back_cancelled_by,   d.back_cancelled_at,   d.back_cancel_reason
FROM    wms.return_instructions d
OUTER APPLY (
    SELECT SUM(x.req_qty) AS asked_qty
    FROM   wms.return_back_lines x
    WHERE  x.doc_id = d.id AND x.round = 1
) l
WHERE   d.is_deleted = 0
  AND   d.back_status IS NOT NULL
  AND   NOT EXISTS (SELECT 1 FROM wms.return_back_rounds r
                    WHERE r.doc_id = d.id AND r.round = 1);

PRINT CONCAT(N'   + ', @@ROWCOUNT, N' dong lan 1');
GO

/* ---------------------------------------------------------------------------
   5b. ĐÓNG những lần đã giao đủ mà còn treo.

       Mã trước 12/11 chỉ đóng lượt back khi KHO HẾT HÀNG của phiếu. Lần nào
       xin một phần và đã giao đủ phần đó thì vẫn nằm ở `scs_approved`:
       · tiến trình hiện "đang chờ giao" trong khi không còn gì để giao;
       · không giao thêm được (mã mới chặn giao vượt SL đã xin);
       · FA cũng không đề nghị tiếp được (phiếu chưa `delivered`).
       Tức là KẸT. Câu này gỡ đúng những phiếu đó.

       Chỉ đụng tới lần CÓ KHAI DÒNG: lần "xin toàn bộ" không có mẫu số, đóng
       nó theo SL là đoán sai ý.

       Chạy lại được bao nhiêu lần cũng được (phiếu đã `delivered` không khớp
       điều kiện nữa).
--------------------------------------------------------------------------- */
PRINT N'5b. Dong nhung lan da giao du ma con treo';

UPDATE  d
SET     d.back_status       = N'delivered',
        d.back_delivered_at = ISNULL(x.at_, SYSDATETIME()),
        d.back_delivered_by = ISNULL(x.who, N'migrate 12/11'),
        d.updated_at        = SYSDATETIME(),
        d.updated_by        = N'migrate 12/11'
FROM    wms.return_instructions d
OUTER APPLY (
    SELECT TOP 1 v.delivered_at AS at_, v.delivered_by AS who
    FROM   wms.return_back_deliveries v
    WHERE  v.doc_id = d.id AND v.round = d.back_round
    ORDER BY v.delivered_at DESC, v.id DESC
) x
WHERE   d.is_deleted = 0
  AND   d.back_status = N'scs_approved'
  AND   d.back_round > 0
  /* Lần này có khai dòng... */
  AND   EXISTS (SELECT 1 FROM wms.return_back_lines l
                WHERE l.doc_id = d.id AND l.round = d.back_round)
  /* ...và KHÔNG còn dòng nào thiếu SL Ở TRẠNG THÁI at_fa.

     ⚠ `AND s.status = N'at_fa'` là bắt buộc kể từ khi tách B4/B5 (12/11).
     Từ đó `back_round` được đóng ngay lúc SCS WH ĐƯA pallet ra khu Nhận hàng,
     trong khi serial vẫn còn `received` chờ FA đến lấy. Đếm theo back_round mà
     không xét status thì chạy lại script này sẽ đóng những lần FA CHƯA nhận —
     hàng còn nằm ngoài ô mà phiếu đã báo giao xong, và không ai mở lại được.
     Lần đề nghị chỉ xong khi FA đã nhận đủ. */
  AND   NOT EXISTS (
            SELECT 1
            FROM   wms.return_back_lines l
            OUTER APPLY (
                SELECT COUNT(*) AS qty
                FROM   wms.return_instruction_serials s
                WHERE  s.doc_id     = l.doc_id
                  AND  s.back_round = l.round
                  AND  s.model      = l.model
                  AND  s.status     = N'at_fa'
                  AND  s.is_deleted = 0
            ) g
            WHERE  l.doc_id = d.id AND l.round = d.back_round
              AND  ISNULL(g.qty, 0) < l.req_qty);

PRINT CONCAT(N'   ~ da dong ', @@ROWCOUNT, N' lan de nghi bi treo');
GO

/* ---------------------------------------------------------------------------
   5c. Đồng bộ dòng lần ĐANG MỞ từ các cột back_*.

       Cùng việc mà `SyncRoundAsync` bên API làm sau mỗi bước. Chạy ở đây để
       dọn hết lệch do dữ liệu cũ (và do mục 5b vừa đổi trạng thái). Mục 7 bên
       dưới phải in ra RỖNG sau khi chạy câu này.
--------------------------------------------------------------------------- */
PRINT N'5c. Dong bo dong lan dang mo';

UPDATE  r
SET     r.note            = d.back_note,
        r.requested_by    = d.back_requested_by,
        r.requested_at    = d.back_requested_at,
        r.fa_approved_by  = d.back_approved_by,
        r.fa_approved_at  = d.back_approved_at,
        r.fa_comment      = d.back_fa_comment,
        r.scs_approved_by = d.back_scs_approved_by,
        r.scs_approved_at = d.back_scs_approved_at,
        r.scs_comment     = d.back_scs_comment,
        r.delivered_by    = d.back_delivered_by,
        r.delivered_at    = d.back_delivered_at,
        r.cancelled_by    = d.back_cancelled_by,
        r.cancelled_at    = d.back_cancelled_at,
        r.cancel_reason   = d.back_cancel_reason
FROM    wms.return_back_rounds r
JOIN    wms.return_instructions d
        ON d.id = r.doc_id AND r.round = d.back_round
WHERE   d.is_deleted = 0;

PRINT CONCAT(N'   ~ dong bo ', @@ROWCOUNT, N' dong');
GO

/* ---------------------------------------------------------------------------
   6. Hiện trạng — đọc để biết dữ liệu đang ở đâu.
--------------------------------------------------------------------------- */
PRINT N'';
PRINT N'--- 6. Phieu co luong back, theo lan ---';

SELECT  d.doc_no              AS so_phieu,
        d.back_round          AS lan_dang_mo,
        d.back_status         AS trang_thai_lan_nay,
        r.asked_qty           AS xin_lan_nay,
        dl.da_giao            AS da_giao_lan_nay,
        con.con_o_kho         AS con_o_kho
FROM      wms.return_instructions d
LEFT JOIN wms.return_back_rounds r
       ON r.doc_id = d.id AND r.round = d.back_round
OUTER APPLY (
    SELECT SUM(x.serial_count) AS da_giao
    FROM   wms.return_back_deliveries x
    WHERE  x.doc_id = d.id AND x.round = d.back_round
) dl
OUTER APPLY (
    SELECT COUNT(*) AS con_o_kho
    FROM   wms.return_instruction_serials s
    WHERE  s.doc_id = d.id AND s.status = N'received' AND s.is_deleted = 0
) con
WHERE   d.is_deleted = 0
  AND   d.back_status IS NOT NULL
ORDER BY d.id DESC;

/* ---------------------------------------------------------------------------
   7. SOÁT LỆCH — chạy lại mỗi khi sửa luồng back.

      Không có dòng nào = tốt. Có dòng = cột back_* của phiếu và dòng lần đang
      mở đã nói hai chuyện khác nhau, tiến trình con sẽ hiện sai.
--------------------------------------------------------------------------- */
PRINT N'';
PRINT N'--- 7. Lech giua back_* va dong lan dang mo ---';

SELECT  d.doc_no                 AS so_phieu,
        d.back_round             AS lan,
        d.back_requested_at      AS phieu_requested_at,
        r.requested_at           AS lan_requested_at,
        d.back_approved_at       AS phieu_fa_at,
        r.fa_approved_at         AS lan_fa_at,
        d.back_scs_approved_at   AS phieu_scs_at,
        r.scs_approved_at        AS lan_scs_at,
        d.back_delivered_at      AS phieu_delivered_at,
        r.delivered_at           AS lan_delivered_at
FROM      wms.return_instructions d
LEFT JOIN wms.return_back_rounds r
       ON r.doc_id = d.id AND r.round = d.back_round
WHERE   d.is_deleted = 0
  AND   d.back_status IS NOT NULL
  AND   (r.id IS NULL
         OR  ISNULL(r.requested_at,    '1900-01-01') <> ISNULL(d.back_requested_at,    '1900-01-01')
         OR  ISNULL(r.fa_approved_at,  '1900-01-01') <> ISNULL(d.back_approved_at,     '1900-01-01')
         OR  ISNULL(r.scs_approved_at, '1900-01-01') <> ISNULL(d.back_scs_approved_at, '1900-01-01')
         OR  ISNULL(r.delivered_at,    '1900-01-01') <> ISNULL(d.back_delivered_at,    '1900-01-01'));

IF @@ROWCOUNT = 0 PRINT N'  (khong lech — tot)';
GO

PRINT N'';
PRINT N'=== XONG. Deploy kem ban API/Web co back_round. ===';
GO
