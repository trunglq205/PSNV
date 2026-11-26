-- 1. Kiểm tra khi kitting đang thấy gì (nguồn gây lỗi)
EXEC GetMaterialOverOneYear;            -- tìm dòng RCID = 84387

-- 2. Nguồn lần check lại theo barcode (màn hàng quá hạn có đọc, kitting thì không)
EXEC GetDM_Freelocation_By_Checked;     -- tìm Barcode = '84387;D4CAY5R00001;9999;9S70;VE01;VB014Y;SB'

-- 3. Hai SP này đọc bảng nào
EXEC sp_helptext 'GetMaterialOverOneYear';
EXEC sp_helptext 'GetDM_Freelocation_By_Checked';
