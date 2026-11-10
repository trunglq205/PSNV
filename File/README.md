-- Bước 1: tìm KittingListDetailId của mã này ngày 6/11
SELECT kld.Id, kld.Material, kl.Deliverydate
FROM tblKittingList kl
JOIN tblKittingListDetail kld ON kld.KittingListId = kl.Id
WHERE kld.Material = 'ZM2NS221W276-H'
  AND CAST(kl.Deliverydate AS DATE) = '2026-11-06';

  -- Bước 2: đo thời gian SP (thay <id> bằng id lấy ở trên)
SET STATISTICS TIME ON;
EXEC GetKittingListDetailByIdCustom @id = <id>;
SET STATISTICS TIME OFF;
