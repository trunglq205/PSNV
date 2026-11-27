-- 1. Hai điều kiện còn lại của job
SELECT PlanOrderNumber, Material, Status, ReceivingDate, IsWD, PostingDate
FROM tblPlanOrder
WHERE PlanOrderNumber = '2026112701' AND Material = 'PNBC1711ZA1/AS';

-- 2. Job có lấy dòng này không
EXEC GetDataBackFlush;          -- tìm PlanOrderNumber = '2026112701'

-- 3. Job hôm nay có chạy không: plan order khác đã lên 3/4 chưa
SELECT Status, COUNT(*) AS SoDong, MAX(UpdatedDate) AS CapNhatCuoi
FROM tblPlanOrder
WHERE CAST(CreatedDate AS date) = '2026-11-27'
GROUP BY Status;

-- 4. Nếu job có lấy mà không lên 3: SP cập nhật khớp theo điều kiện nào
EXEC sp_helptext 'UpdateStatusDataBackFlushToSAP';
