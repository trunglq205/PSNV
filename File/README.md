-- 1. Chạy đúng SP backend đang gọi
EXEC GetFreelocationByBarcode @barcode = N'566560;H1001-3L10-P;24;61S0;VG01;VE014P;MW';

-- 2. Barcode và trạng thái khu tạm hiện tại của RC
SELECT ReceivingCardID, Barcode, TemporaryAreaCode, CurrentQuantity
FROM tblReceivingCard
WHERE ReceivingCardID = 566560;

-- 3. Nội dung SP, để biết nó đọc bảng nào và lọc theo điều kiện gì
EXEC sp_helptext 'GetFreelocationByBarcode';
