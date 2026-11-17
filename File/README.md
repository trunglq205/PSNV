SELECT ID, mahang, vitri,
       '[' + Barcode + ']'      AS Barcode,
       LEN(Barcode)             AS LenBarcode,      -- chuỗi đúng dài 42
       DATALENGTH(Barcode)      AS DataLen,
       ISNULL(TTcheck2, '<NULL>') AS TTcheck2
FROM DM_FreeLocation WITH (NOLOCK)
WHERE Barcode LIKE '%566560;H1001-3L10-P%'
   OR vitri = 'PL148';
