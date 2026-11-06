-- 1. Check trước
SELECT * FROM tblKittingLine WHERE CreatedBy = 'your_user_id' AND CAST(CreatedDate AS DATE) = CAST(GETDATE() AS DATE);
SELECT * FROM tblKittingListDetail WHERE CreatedBy = 'your_user_id' AND CAST(CreatedDate AS DATE) = CAST(GETDATE() AS DATE);
SELECT * FROM tblKittingList WHERE CreatedBy = 'your_user_id' AND CAST(CreatedDate AS DATE) = CAST(GETDATE() AS DATE);

-- 2. Xóa đúng thứ tự (con trước, cha sau)
DELETE FROM tblKittingLine WHERE CreatedBy = 'your_user_id' AND CAST(CreatedDate AS DATE) = CAST(GETDATE() AS DATE);
DELETE FROM tblKittingListDetail WHERE CreatedBy = 'your_user_id' AND CAST(CreatedDate AS DATE) = CAST(GETDATE() AS DATE);
DELETE FROM tblKittingList WHERE CreatedBy = 'your_user_id' AND CAST(CreatedDate AS DATE) = CAST(GETDATE() AS DATE);
