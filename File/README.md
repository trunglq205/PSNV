-- SP trên server hiện tại có loại NG không (tìm 'NG' trong nội dung)
EXEC sp_helptext 'GetMaterialOverOneYear';

-- RC của box này: category, sloc, dữ liệu quá hạn
CREATE TABLE #over (RCID bigint, Barcode nvarchar(500), DeliveryDate datetime, DeliveryDateOver datetime,
                    Material nvarchar(100), Status nvarchar(50), Type_Check nvarchar(50), Times_Check int,
                    Date_Check datetime, Type nvarchar(50), Location nvarchar(100), Category nvarchar(50));
INSERT INTO #over EXEC GetMaterialOverOneYear;
SELECT * FROM #over WHERE Material = 'F301Q-3503A' AND Location = '1.SN006.1.02';
DROP TABLE #over;
