-- 1. Nguồn gây lỗi khi kitting
CREATE TABLE #over (RCID bigint, Barcode nvarchar(500), DeliveryDate datetime, DeliveryDateOver datetime,
                    Material nvarchar(100), Status nvarchar(50), Type_Check nvarchar(50), Times_Check int,
                    Date_Check datetime, Type nvarchar(50), Location nvarchar(100), Category nvarchar(50));
INSERT INTO #over EXEC GetMaterialOverOneYear;

SELECT 'GetMaterialOverOneYear' AS Nguon, RCID, Barcode, Status, Type_Check, Times_Check,
       Date_Check, DATEADD(YEAR, 1, Date_Check) AS HanSauCheck, DeliveryDateOver, Location, Category
FROM #over
WHERE RCID = 84387 OR Material = 'D4CAY5R00001';

-- 2. Nguồn lần check lại theo barcode
CREATE TABLE #dm (Barcode nvarchar(500), DateCheck datetime);
INSERT INTO #dm EXEC GetDM_Freelocation_By_Checked;

SELECT 'GetDM_Freelocation_By_Checked' AS Nguon, Barcode, DateCheck
FROM #dm
WHERE Barcode LIKE '84387;%' OR Barcode LIKE '%;D4CAY5R00001;%'
ORDER BY DateCheck DESC;

DROP TABLE #over, #dm;
