/* =====================================================================
   KIỂM KÊ — THÊM CỘT is_required CHO DÒNG PHIẾU
   soạn 19/11/2026 · chạy lại nhiều lần được

   VÌ SAO CẦN
   Phiếu kiểm kê SÁNG chọn phạm vi theo Ô, không theo pallet: ô nào có biến
   động hôm qua thì MỌI pallet đang đứng ở ô đó đều thành một dòng. Một ô
   sẵn 3 model từ hôm trước, hôm nay thêm 1 model, thì phiếu ra 4 dòng
   nhưng người đi kiểm chỉ cần đếm 1.

   Cột này tách "có trong phiếu" khỏi "phải đếm":
     · Web  hiện ĐỦ 4 dòng — người đọc thấy bối cảnh của ô.
     · PDA  chỉ hiện dòng phải đếm.
     · Tiến độ và nút đóng phiếu chỉ tính dòng phải đếm.

   ⚠ VÌ SAO LƯU THÀNH CỘT, KHÔNG TÍNH LÚC ĐỌC
   Bản đầu tôi tính lúc đọc từ wms.stock_events theo cửa sổ suy ra từ
   count_date. Sai: mỗi lần có sự kiện kho mới rơi vào khoảng đó, một phiếu
   ĐÃ ĐÓNG sẽ đổi nghĩa — hôm nay 1 dòng cần kiểm, mai thành 2, mà không ai
   sửa gì. Phạm vi của một phiếu phải ĐÓNG BĂNG tại thời điểm tạo phiếu.

   ⚠ CHẠY TRƯỚC KHI DEPLOY API. API bản mới đọc và ghi cột này; thiếu cột
   là mọi màn kiểm kê ăn lỗi SQL.

   Dữ liệu cũ: mọi dòng đang có đều đặt 1 (phải đếm) — giữ nguyên hành vi
   hiện tại cho phiếu cũ, không làm phiếu nào đang dở tự nhiên đóng được.
   ===================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF RIGHT(DB_NAME(), 4) <> N'_DEV' AND DB_NAME() <> N'SWMS_FINISH_GOODS'
BEGIN
    DECLARE @db sysname = DB_NAME();
    RAISERROR(N'DUNG LAI: dang o DB [%s]. Script nay chi chay tren SWMS_FINISH_GOODS hoac DB duoi _DEV.',
              16, 1, @db);
    SET NOEXEC ON;
END
GO

PRINT N'### DB: ' + DB_NAME();

IF OBJECT_ID(N'wms.inventory_count_lines', N'U') IS NULL
BEGIN
    RAISERROR(N'Khong tim thay wms.inventory_count_lines.', 16, 1);
    SET NOEXEC ON;
END
GO

/* ---------------------------------------------------------------------
   MỤC 1 — THÊM CỘT
   ---------------------------------------------------------------------
   NOT NULL kèm DEFAULT 1 nên dòng cũ tự điền 1, không phải UPDATE riêng.
   Đặt DEFAULT thay vì để NULL: "không biết có phải đếm không" là một trạng
   thái vô nghĩa, và mọi câu đếm sẽ phải nhớ ISNULL — sớm muộn quên một chỗ.
   --------------------------------------------------------------------- */
IF COL_LENGTH(N'wms.inventory_count_lines', N'is_required') IS NULL
BEGIN
    ALTER TABLE wms.inventory_count_lines
        ADD is_required bit NOT NULL
            CONSTRAINT df_icl_is_required DEFAULT (1);
    PRINT N'1. Da them cot is_required (dong cu = 1).';
END
ELSE PRINT N'1. Cot is_required da co — bo qua.';
GO

/* ---------------------------------------------------------------------
   MỤC 2 — INDEX CHO CÂU ĐẾM TIẾN ĐỘ
   ---------------------------------------------------------------------
   Màn danh sách phiếu đếm "bao nhiêu dòng phải đếm / đã đếm" cho TỪNG
   phiếu trong danh sách, nên câu này chạy theo lô mỗi lần mở màn.
   --------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = N'ix_icl_count_required'
                 AND object_id = OBJECT_ID(N'wms.inventory_count_lines'))
BEGIN
    CREATE INDEX ix_icl_count_required
        ON wms.inventory_count_lines (count_id, is_required)
        INCLUDE (qty_count, qty_system)
        WHERE is_deleted = 0;
    PRINT N'2. Da tao ix_icl_count_required.';
END
ELSE PRINT N'2. ix_icl_count_required da co — bo qua.';
GO

/* ---------------------------------------------------------------------
   MỤC 3 — INDEX CHO CÂU DỰNG PHIẾU SÁNG
   ---------------------------------------------------------------------
   Phiếu sáng hỏi "pallet này có sự kiện kho nào trong cửa sổ hôm qua
   không" cho TỪNG pallet đang đứng ở các ô có biến động. Không có index
   theo thời gian thì mỗi lần tạo phiếu là một lượt quét cả bảng sự kiện.

   Hai cột pallet nằm ở INCLUDE chứ không ở khoá: điều kiện lọc là khoảng
   THỜI GIAN, còn pallet_id chỉ để so sau khi đã thu hẹp.
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'wms.stock_events', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE name = N'ix_stock_events_at_pallet'
                     AND object_id = OBJECT_ID(N'wms.stock_events'))
BEGIN
    CREATE INDEX ix_stock_events_at_pallet
        ON wms.stock_events (event_at)
        INCLUDE (pallet_id, related_pallet_id);
    PRINT N'3. Da tao ix_stock_events_at_pallet.';
END
ELSE PRINT N'3. Bo qua index tren wms.stock_events (da co, hoac khong co bang).';
GO

/* ---------------------------------------------------------------------
   MỤC 4 — BẢNG KIỂM
   --------------------------------------------------------------------- */
SELECT  cot_is_required = CASE WHEN COL_LENGTH(N'wms.inventory_count_lines', N'is_required') IS NULL
                               THEN N'>>> CHUA CO <<<' ELSE N'co' END,
        so_dong_tong    = (SELECT COUNT(*) FROM wms.inventory_count_lines WHERE is_deleted = 0),
        so_dong_phai_dem= (SELECT COUNT(*) FROM wms.inventory_count_lines WHERE is_deleted = 0 AND is_required = 1);

SELECT  ten = i.name,
        bang = OBJECT_SCHEMA_NAME(i.object_id) COLLATE DATABASE_DEFAULT + N'.' +
               OBJECT_NAME(i.object_id)        COLLATE DATABASE_DEFAULT
FROM    sys.indexes i
WHERE   i.name IN (N'ix_icl_count_required', N'ix_stock_events_at_pallet');

PRINT N'';
PRINT N'===== XONG =====';
PRINT N'Deploy API + Web ban moi SAU khi chay file nay.';
PRINT N'Phieu sang TAO MOI tu day moi co cot nay dung nghia; phieu cu giu';
PRINT N'nguyen hanh vi (moi dong deu phai dem).';
GO

SET NOEXEC OFF;
GO
