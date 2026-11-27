EXEC sp_helptext 'CreatePlanOrder';

-- So sánh với các plan order khác import hôm nay
SELECT PlanOrderNumber, COUNT(*) AS SoDong, MIN(ReceivingDate) AS MinRecv, MAX(ReceivingDate) AS MaxRecv,
       MIN(CreatedDate) AS MinCreated, MAX(CreatedDate) AS MaxCreated
FROM tblPlanOrder
WHERE CAST(CreatedDate AS date) = '2026-11-27'
GROUP BY PlanOrderNumber
ORDER BY MinCreated;
