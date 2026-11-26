-- Kết quả check trong tblHistoryQCCheck của mã này
SELECT Material, Delivery_date, Category, Status_Check, Type_Check, Times_Check, Date_Check
FROM tblHistoryQCCheck WITH (NOLOCK)
WHERE Material = 'D4CAY5R00001'
ORDER BY Date_Check DESC;

-- Kết quả check trong DM_FreeLocation của mã này
SELECT ID, Barcode, vitri, Ketqua, Ketqua2, QCendtime, QCendtime2, TTcheck2
FROM DM_FreeLocation WITH (NOLOCK)
WHERE Barcode LIKE '%;D4CAY5R00001;%'
ORDER BY ISNULL(QCendtime, QCendtime2) DESC;
