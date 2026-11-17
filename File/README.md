-- 1. Các SP/trigger có ghi TTcheck2 = 'nothing'
SELECT OBJECT_NAME(object_id) AS ObjName
FROM sys.sql_modules
WHERE definition LIKE '%TTcheck2%nothing%';

-- 2. Có bao nhiêu RC khác cũng bị lệch như vậy
SELECT rc.ReceivingCardID, rc.Barcode, rc.TemporaryAreaCode
FROM tblReceivingCard rc
WHERE rc.TemporaryAreaCode NOT IN ('notyet', 'outOK')
  AND NOT EXISTS (SELECT 1 FROM DM_FreeLocation f WITH (NOLOCK)
                  WHERE f.Barcode = rc.Barcode AND f.TTcheck2 <> 'nothing');
