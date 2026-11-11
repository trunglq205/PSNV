/* ============================================================================
   TÁCH PALLET BẰNG TAY — thay cho màn Tách pallet khi không có máy in
                                                                      (11/11)
   Làm ĐÚNG những gì LotRepository.ExecuteSplitAsync làm, không thiếu bước nào:

     1. Tạo pallet con bằng cách CLONE pallet gốc (kèm `disposition` — thiếu
        cột này thì pallet con mất badge RW/RB).
     2. Chuyển các thùng đã chọn sang pallet con.
     3. Chuyển dòng sổ serial của phiếu return theo thùng
        (wms.return_instruction_serials.pallet_id) — THIẾU BƯỚC NÀY thì sổ vẫn
        trỏ pallet gốc, và lúc giao hàng quét pallet con ra 0 serial.
     4. Đếm lại box_count cho CẢ HAI pallet.
     5. Ghi lịch sử qua wms.usp_stock_event_add: PALLET_CREATED (pallet con),
        PALLET_SPLIT_OUT (gốc), PALLET_SPLIT_IN (con), và BOX_MOVED_PALLET cho
        từng thùng.

   KHÔNG in tem. Pallet con sẽ có Pallet ID mới mà không có tem dán — nhớ ghi
   tay lên pallet, hoặc in lại sau từ màn Chi tiết pallet.

   CHẠY:
     Sửa @SourceLotNo và @BoxNos bên dưới.
     @WhatIf = 1 (mặc định) chỉ IN RA, KHÔNG ghi. Xem xong đặt @WhatIf = 0.
   ========================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;      -- lỗi giữa chừng là rollback cả cụm, không để nửa vời

------------------------------------------------------------------- THAM SỐ --

DECLARE @WhatIf      bit            = 1;                  -- <<< 0 để ghi thật
DECLARE @SourceLotNo varchar(12)    = '311261111001';     -- <<< pallet gốc
DECLARE @Actor       nvarchar(100)  = N'tach tay 11/11';

-- Thùng chuyển sang pallet con: liệt kê box_no, cách nhau bằng dấu phẩy.
-- Để RỖNG thì script dừng — tách mà không chọn thùng nào là vô nghĩa.
DECLARE @BoxNos      nvarchar(max)  = N'box1';            -- <<< vd 'box1,box2'

---------------------------------------------------------------- CHUẨN BỊ ----

DECLARE @SourceLotId bigint,
        @CategoryId  int,
        @BoxTotal    int,
        @BoxPicked   int;

SELECT  @SourceLotId = p.id,
        @CategoryId  = p.category_id
FROM    wms.pallets p
WHERE   p.pallet_id = @SourceLotNo AND p.is_deleted = 0;

IF @SourceLotId IS NULL
BEGIN
    PRINT N'Khong tim thay pallet ' + @SourceLotNo + N' (hoac da xoa mem).';
    RETURN;
END

-- Thùng được chọn, đối chiếu với thùng thật của pallet gốc.
DECLARE @Pick TABLE (box_id bigint PRIMARY KEY, box_no nvarchar(100));

INSERT INTO @Pick (box_id, box_no)
SELECT  b.id, b.box_no
FROM    wms.boxes b
JOIN    STRING_SPLIT(@BoxNos, ',') s
        ON LTRIM(RTRIM(s.value)) = b.box_no
WHERE   b.lot_id = @SourceLotId AND b.is_deleted = 0;

SELECT @BoxPicked = COUNT(*) FROM @Pick;
SELECT @BoxTotal  = COUNT(*) FROM wms.boxes
WHERE  lot_id = @SourceLotId AND is_deleted = 0;

PRINT N'--- PALLET GOC ---';
PRINT N'  ' + @SourceLotNo + N'  (id=' + CAST(@SourceLotId AS nvarchar(20))
      + N', category=' + CAST(@CategoryId AS nvarchar(10))
      + N', tong ' + CAST(@BoxTotal AS nvarchar(10)) + N' thung)';

PRINT N'';
PRINT N'--- THUNG SE CHUYEN ---';

SELECT  k.box_no                     AS thung,
        COUNT(bl.id)                 AS so_dong,
        ISNULL(SUM(bl.qty), 0)       AS so_luong,
        COUNT(DISTINCT bl.model)     AS so_model
FROM      @Pick k
LEFT JOIN wms.box_lines bl ON bl.box_id = k.box_id AND bl.is_deleted = 0
GROUP BY  k.box_no
ORDER BY  k.box_no;

IF @BoxPicked = 0
BEGIN
    PRINT N'>>> KHONG khop thung nao trong @BoxNos voi pallet goc. Dung lai.';
    PRINT N'>>> Cac box_no dang co cua pallet goc:';
    SELECT box_no FROM wms.boxes
    WHERE lot_id = @SourceLotId AND is_deleted = 0 ORDER BY box_no;
    RETURN;
END

IF @BoxPicked = @BoxTotal
BEGIN
    PRINT N'>>> Chon HET thung cua pallet goc — tach xong pallet goc se RONG.';
    PRINT N'>>> Neu khong co y do nay thi sua lai @BoxNos.';
END

-- Serial của phiếu return gắn với những thùng này (nếu có).
DECLARE @SerialMove int = 0;

IF OBJECT_ID(N'wms.return_instruction_serials') IS NOT NULL
BEGIN
    SELECT @SerialMove = COUNT(*)
    FROM   wms.return_instruction_serials s
    JOIN   @Pick k ON k.box_no = s.box_no
    WHERE  s.pallet_id = @SourceLotId AND s.is_deleted = 0;

    PRINT N'';
    PRINT N'  So dong so serial se chuyen theo: ' + CAST(@SerialMove AS nvarchar(10));

    -- Serial không gắn box_no sẽ Ở LẠI pallet gốc — giống hệt code.
    DECLARE @SerialNoBox int;
    SELECT @SerialNoBox = COUNT(*)
    FROM   wms.return_instruction_serials s
    WHERE  s.pallet_id = @SourceLotId AND s.is_deleted = 0 AND s.box_no IS NULL;

    IF @SerialNoBox > 0
        PRINT N'  (' + CAST(@SerialNoBox AS nvarchar(10))
            + N' serial khong gan thung se O LAI pallet goc — dung nhu code)';
END

------------------------------------------------------- SINH PALLET ID MOI ---

-- Khuôn: {category:D3}{yyMMdd}{seq:D3} = 12 ký tự. Seq lấy MAX+1 và ĐẾM CẢ
-- bản ghi đã xoá mềm, y như LotRepository.GetMaxSequenceAsync — số đã cấp
-- không tái sử dụng, tránh đụng unique index khi pallet cũ được khôi phục.
DECLARE @Prefix  varchar(9) =
        RIGHT('000' + CAST(@CategoryId AS varchar(3)), 3)
      + FORMAT(SYSDATETIME(), 'yyMMdd');

DECLARE @NextSeq int = (
    SELECT ISNULL(MAX(CAST(RIGHT(pallet_id, 3) AS int)), 0) + 1
    FROM   wms.pallets
    WHERE  pallet_id LIKE @Prefix + '%'
      AND  LEN(pallet_id) = 12
      AND  pallet_id NOT LIKE '%[^0-9]%');

IF @NextSeq > 999
BEGIN
    PRINT N'Het so thu tu cho prefix ' + @Prefix + N' (da dung 999).';
    RETURN;
END

DECLARE @NewLotNo varchar(12) =
        @Prefix + RIGHT('000' + CAST(@NextSeq AS varchar(3)), 3);

PRINT N'';
PRINT N'--- PALLET CON SE TAO ---';
PRINT N'  ' + @NewLotNo;
PRINT N'  (chua co tem — ghi tay len pallet, hoac in lai tu man Chi tiet pallet)';

--------------------------------------------------------------------- GHI ----

IF @WhatIf = 1
BEGIN
    PRINT N'';
    PRINT N'@WhatIf = 1 — KHONG ghi gi. Dat @WhatIf = 0 roi chay lai de tach that.';
    RETURN;
END

DECLARE @TargetLotId  bigint,
        @SourceBefore int = @BoxTotal,
        @TargetBefore int = 0,
        @Moved        int,
        @Remaining    int;

BEGIN TRAN;

    -- 1) Pallet con = CLONE pallet gốc. Cột `disposition` phải có mặt, nếu
    --    không pallet con mất badge RW/RB — đúng lúc cần nhất, vì pallet con
    --    chính là thứ sẽ đi ra khỏi kho để giao cho FA.
    DECLARE @Ins TABLE (id bigint);

    INSERT INTO wms.pallets
        (pallet_id, category_id, lot_type, stocky_code, locator_id, detail_level,
         box_count, even_lot, model, standard_packing, inspection_status,
         is_urgent, production_date, sap_status, sap_pushed_at, disposition,
         is_deleted, created_at, created_by)
    OUTPUT INSERTED.id INTO @Ins(id)
    SELECT
         @NewLotNo, s.category_id, s.lot_type, NULL, s.locator_id, s.detail_level,
         0, s.even_lot, s.model, s.standard_packing, s.inspection_status,
         s.is_urgent, s.production_date, s.sap_status, s.sap_pushed_at,
         s.disposition,
         0, SYSDATETIME(), @Actor
    FROM wms.pallets s
    WHERE s.id = @SourceLotId AND s.is_deleted = 0;

    SELECT @TargetLotId = id FROM @Ins;

    -- 2) Chuyển thùng.
    UPDATE  b
    SET     b.lot_id     = @TargetLotId,
            b.updated_at = SYSDATETIME(),
            b.updated_by = @Actor
    FROM    wms.boxes b
    JOIN    @Pick k ON k.box_id = b.id
    WHERE   b.lot_id = @SourceLotId AND b.is_deleted = 0;

    SET @Moved = @@ROWCOUNT;

    -- 3) Chuyển sổ serial theo thùng. Nối bằng box_no và CHẶN TRONG pallet
    --    nguồn: box_no chỉ chắc chắn duy nhất trong phạm vi một pallet.
    IF OBJECT_ID(N'wms.return_instruction_serials') IS NOT NULL
    BEGIN
        UPDATE  s
        SET     s.pallet_id  = @TargetLotId,
                s.updated_at = SYSDATETIME(),
                s.updated_by = @Actor
        FROM    wms.return_instruction_serials s
        JOIN    @Pick k ON k.box_no = s.box_no
        WHERE   s.pallet_id = @SourceLotId AND s.is_deleted = 0;
    END

    -- 4) Đếm lại box_count cho cả hai.
    UPDATE  l
    SET     l.box_count  = (SELECT COUNT(*) FROM wms.boxes b
                            WHERE b.lot_id = l.id AND b.is_deleted = 0),
            l.updated_at = SYSDATETIME(),
            l.updated_by = @Actor
    FROM    wms.pallets l
    WHERE   l.id IN (@SourceLotId, @TargetLotId);

    SELECT @Remaining = COUNT(*) FROM wms.boxes
    WHERE  lot_id = @SourceLotId AND is_deleted = 0;

    -- 5) Lịch sử — gọi CHÍNH stored proc mà API dùng, không insert tay vào
    --    wms.stock_events (proc còn làm việc khác ngoài INSERT).
    EXEC wms.usp_stock_event_add
         @event_code        = 'PALLET_CREATED',
         @subject_type      = 'pallet',
         @pallet_id         = @TargetLotId,
         @box_id            = NULL,
         @actor             = @Actor,
         @source            = 'WEB',
         @from_locator_id   = NULL,
         @to_locator_id     = NULL,
         @ref_type          = NULL,
         @ref_id            = NULL,
         @ref_no            = NULL,
         @related_pallet_id = @SourceLotId,
         @box_count_before  = NULL,
         @box_count_after   = @Moved,
         @note              = NULL,
         @payload           = '{"origin":"split"}',
         @event_at          = NULL;

    EXEC wms.usp_stock_event_add
         @event_code        = 'PALLET_SPLIT_OUT',
         @subject_type      = 'pallet',
         @pallet_id         = @SourceLotId,
         @box_id            = NULL,
         @actor             = @Actor,
         @source            = 'WEB',
         @from_locator_id   = NULL,
         @to_locator_id     = NULL,
         @ref_type          = NULL,
         @ref_id            = NULL,
         @ref_no            = NULL,
         @related_pallet_id = @TargetLotId,
         @box_count_before  = @SourceBefore,
         @box_count_after   = @Remaining,
         @note              = N'Tach bang SQL (khong co may in)',
         @payload           = NULL,
         @event_at          = NULL;

    EXEC wms.usp_stock_event_add
         @event_code        = 'PALLET_SPLIT_IN',
         @subject_type      = 'pallet',
         @pallet_id         = @TargetLotId,
         @box_id            = NULL,
         @actor             = @Actor,
         @source            = 'WEB',
         @from_locator_id   = NULL,
         @to_locator_id     = NULL,
         @ref_type          = NULL,
         @ref_id            = NULL,
         @ref_no            = NULL,
         @related_pallet_id = @SourceLotId,
         @box_count_before  = @TargetBefore,
         @box_count_after   = @Moved,
         @note              = N'Tach bang SQL (khong co may in)',
         @payload           = NULL,
         @event_at          = NULL;

    -- Mỗi thùng một dòng: đây là dòng DUY NHẤT cho phép dựng lại lịch sử
    -- "thùng này từng thuộc pallet nào".
    DECLARE @BoxId bigint;
    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT box_id FROM @Pick;
    OPEN cur;
    FETCH NEXT FROM cur INTO @BoxId;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC wms.usp_stock_event_add
             @event_code        = 'BOX_MOVED_PALLET',
             @subject_type      = 'box',
             @pallet_id         = @TargetLotId,
             @box_id            = @BoxId,
             @actor             = @Actor,
             @source            = 'WEB',
             @from_locator_id   = NULL,
             @to_locator_id     = NULL,
             @ref_type          = NULL,
             @ref_id            = NULL,
             @ref_no            = NULL,
             @related_pallet_id = @SourceLotId,
             @box_count_before  = NULL,
             @box_count_after   = NULL,
             @note              = NULL,
             @payload           = NULL,
             @event_at          = NULL;

        FETCH NEXT FROM cur INTO @BoxId;
    END
    CLOSE cur;
    DEALLOCATE cur;

COMMIT;

PRINT N'';
PRINT N'--- DA TACH ---';
PRINT N'  Pallet con : ' + @NewLotNo
      + N' (id=' + CAST(@TargetLotId AS nvarchar(20)) + N')';
PRINT N'  Thung chuyen: ' + CAST(@Moved AS nvarchar(10));
PRINT N'  Pallet goc con lai: ' + CAST(@Remaining AS nvarchar(10)) + N' thung';

-- Soát lại bằng mắt.
SELECT  p.pallet_id          AS pallet,
        p.box_count          AS so_thung,
        p.disposition        AS disposition,
        p.inspection_status  AS trang_thai_kiem,
        loc.locator_code     AS vi_tri,
        (SELECT COUNT(*) FROM wms.return_instruction_serials s
         WHERE s.pallet_id = p.id AND s.is_deleted = 0) AS so_serial_so
FROM      wms.pallets p
LEFT JOIN master.locators loc ON loc.id = p.locator_id AND loc.is_deleted = 0
WHERE     p.id IN (@SourceLotId, @TargetLotId);
GO
