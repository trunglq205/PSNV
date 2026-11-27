-- 1. Trạng thái thật trong DB
SELECT PlanOrderNumber, Material, Plant, Sloc, STATUS, GRQuantity, PlanOrderQuantity,
       CreatedDate, UpdatedDate, UpdatedBy
FROM tblPlanOrder
WHERE PlanOrderNumber = '2026112701' AND Material = 'PNBC1711ZA1/AS';

-- 2. Job SAP lấy plan order theo điều kiện nào
EXEC sp_helptext 'GetDataBackFlush';

-- 3. Có lỗi gửi SAP nào cho plan order này không
EXEC sp_helptext 'InsertDataPlanErrorToSAP';
