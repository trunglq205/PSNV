/* ============================================================================
   Mục 2c — TÁCH "đưa ra khu Nhận hàng" khỏi "FA đã nhận"            (12/11)

   VÌ SAO:
     Trước đây đặt pallet vào vị trí khu Nhận hàng là serial sang luôn `at_fa`.
     Nhưng lúc đó hàng MỚI CHỈ nằm ở khu nhận hàng của kho SCS — FA chưa đến
     lấy. Sổ nói "đang ở FA" trong khi hàng vẫn trong nhà máy, và không ai biết
     còn bao nhiêu con đang nằm chờ FA đến.

   NAY HAI BƯỚC:
     B4  SCS WH đưa pallet ra một vị trí thuộc khu Nhận hàng
         -> serial GIỮ NGUYÊN `received`, chỉ đóng số lần đề nghị (back_round)
         -> ghi nhật ký kind = 'handover', KÈM MÃ VỊ TRÍ đặt hàng
     B5  FA đến lấy, quét pallet bằng chức năng "FA nhận hàng RW/RB" trên PDA
         -> serial sang `at_fa` + `sent_fa_at`
         -> pallet RỜI vị trí (locator_id = NULL)
         -> ghi nhật ký kind = 'pickup'

   KHÔNG thêm trạng thái serial mới (chốt 12/11): "đang chờ FA lấy" đọc ra từ
   VỊ TRÍ của pallet (đang đứng ở ô thuộc khu Nhận hàng) + `back_round` đã đóng,
   chứ không phải từ một giá trị status thứ sáu. Đổi lại, mọi câu đếm "còn ở
   kho" phải hiểu `received` gồm cả hàng đang chờ FA — xem mục 4.

   CHẠY SAU: return_back_round_schema.sql.
   ========================================================================= */

/* ---------- 0. Điều kiện tiên quyết — BATCH RIÊNG, có GO ---------- */

IF OBJECT_ID(N'wms.return_back_deliveries', N'U') IS NULL
    RAISERROR(N'THIEU bang wms.return_back_deliveries — chay return_back_merge_schema.sql truoc.', 16, 1);

IF COL_LENGTH(N'wms.return_back_deliveries', N'round') IS NULL
    RAISERROR(N'THIEU cot round — chay return_back_round_schema.sql truoc.', 16, 1);

IF COL_LENGTH(N'wms.return_instruction_serials', N'back_round') IS NULL
    RAISERROR(N'THIEU cot serials.back_round — chay return_back_round_schema.sql truoc.', 16, 1);
GO

SET NOCOUNT ON;
PRINT N'=== return_fa_pickup_schema.sql ===';

/* ---------------------------------------------------------------------------
   1. kind: dòng nhật ký này là ĐƯA RA VỊ TRÍ hay FA ĐÃ NHẬN.
--------------------------------------------------------------------------- */
PRINT N'1. return_back_deliveries.kind';

IF COL_LENGTH(N'wms.return_back_deliveries', N'kind') IS NULL
BEGIN
    /* DEFAULT 'handover' cho dòng MỚI; dòng cũ xử lý riêng ở mục 3. */
    ALTER TABLE wms.return_back_deliveries
        ADD kind NVARCHAR(10) NOT NULL CONSTRAINT df_rbd_kind DEFAULT (N'handover');
    PRINT N'   + kind';
END
ELSE
    PRINT N'   = kind da co';
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE name = N'ck_rbd_kind'
                 AND parent_object_id = OBJECT_ID(N'wms.return_back_deliveries'))
BEGIN
    ALTER TABLE wms.return_back_deliveries
        ADD CONSTRAINT ck_rbd_kind CHECK (kind IN (N'handover', N'pickup'));
    PRINT N'   + ck_rbd_kind';
END
GO

/* ---------------------------------------------------------------------------
   2. locator_code: ĐẶT Ở ĐÂU.

      Lưu MÃ chứ không lưu id vị trí: đây là nhật ký, phải đọc được cả khi vị
      trí bị xoá hoặc đổi tên sau này. Cùng lý do với lot_no nằm sẵn ở bảng này
      dù đã có pallet_id.
--------------------------------------------------------------------------- */
PRINT N'2. return_back_deliveries.locator_code';

IF COL_LENGTH(N'wms.return_back_deliveries', N'locator_code') IS NULL
BEGIN
    ALTER TABLE wms.return_back_deliveries ADD locator_code NVARCHAR(50) NULL;
    PRINT N'   + locator_code';
END
ELSE
    PRINT N'   = locator_code da co';
GO

/* ---------------------------------------------------------------------------
   3. Dòng nhật ký CŨ là 'pickup'.

      Luồng cũ gộp hai việc làm một: pallet ra khu nhận hàng VÀ serial sang
      at_fa trong cùng một lượt. Serial của những lượt đó đang ở `at_fa` thật,
      nên dòng nhật ký tương ứng phải là 'pickup' — nếu để 'handover' thì màn
      hình sẽ báo "đang chờ FA đến lấy" cho hàng đã ở FA từ lâu.

      Hệ quả chấp nhận: các lần đề nghị cũ không có dòng 'handover', nên bước
      "đưa ra vị trí" của chúng không có mốc riêng. Mã C# lùi về mốc của dòng
      'pickup' để bước đó vẫn hiện đã xong.
--------------------------------------------------------------------------- */
PRINT N'3. Danh dau nhat ky cu la pickup';

UPDATE  d
SET     d.kind = N'pickup'
FROM    wms.return_back_deliveries d
WHERE   d.kind = N'handover'
  AND   d.delivered_at < CAST(N'2026-11-13' AS datetime2(0))
  /* Chỉ những dòng mà serial của pallet đó THỰC SỰ đã sang at_fa. */
  AND   EXISTS (SELECT 1 FROM wms.return_instruction_serials s
                WHERE s.pallet_id = d.pallet_id
                  AND s.doc_id    = d.doc_id
                  AND s.status    = N'at_fa'
                  AND s.is_deleted = 0);

PRINT CONCAT(N'   ~ ', @@ROWCOUNT, N' dong nhat ky cu -> pickup');
GO

/* ---------------------------------------------------------------------------
   4. Hiện trạng: hàng đang CHỜ FA ĐẾN LẤY.

      Định nghĩa: serial còn `received`, đã được đóng số lần đề nghị
      (back_round > 0), và pallet đang đứng ở một ô thuộc khu Nhận hàng.

      Đây đúng là tập hợp mà chức năng "FA nhận hàng RW/RB" trên PDA sẽ xử lý.
--------------------------------------------------------------------------- */
PRINT N'';
PRINT N'--- 4. Dang cho FA den lay ---';

SELECT      d.doc_no              AS so_phieu,
            d.back_round          AS lan,
            RTRIM(p.pallet_id)    AS pallet_id,
            loc.locator_code      AS vi_tri,
            a.area_name           AS khu,
            COUNT(*)              AS so_serial_cho_lay
FROM        wms.return_instruction_serials s
JOIN        wms.return_instructions d ON d.id = s.doc_id AND d.is_deleted = 0
JOIN        wms.pallets p             ON p.id = s.pallet_id AND p.is_deleted = 0
JOIN        master.locators loc       ON loc.id = p.locator_id AND loc.is_deleted = 0
JOIN        master.warehouse_areas a  ON a.id = loc.area_id AND a.is_deleted = 0
                                     AND a.map_type = N'receiving'
WHERE       s.is_deleted = 0
  AND       s.status     = N'received'
  AND       s.back_round IS NOT NULL
GROUP BY    d.doc_no, d.back_round, p.pallet_id, loc.locator_code, a.area_name
ORDER BY    d.doc_no, p.pallet_id;

IF @@ROWCOUNT = 0 PRINT N'  (khong co pallet nao dang cho FA den lay)';
GO

PRINT N'';
PRINT N'=== XONG. Deploy kem ban API/Web/PDA co buoc "FA nhan hang". ===';
GO
