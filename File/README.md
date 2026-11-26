
(14786 rows affected)
Nguon                  RCID                 Barcode                                                                                                                                                                                                                                                          Status                                             Type_Check                                         Times_Check Date_Check              HanSauCheck             DeliveryDateOver        Location                                                                                             Category
---------------------- -------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- -------------------------------------------------- -------------------------------------------------- ----------- ----------------------- ----------------------- ----------------------- ---------------------------------------------------------------------------------------------------- --------------------------------------------------
GetMaterialOverOneYear 184387               184387;D4CAY5R00001;9999;9S70;VE01;VB014Y;SB                                                                                                                                                                                                                     OK                                                 NULL                                               NULL        2025-11-17 00:00:00.000 2026-11-17 00:00:00.000 2025-12-13 00:00:00.000 1.S02B.4.02                                                                                          SB

(1 row affected)

(124929 rows affected)

Nguon                         Barcode                                                                                                                                                                                                                                                          DateCheck
----------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- -----------------------
GetDM_Freelocation_By_Checked 184387;D4CAY5R00001;9999;9S70;VE01;VB014Y;SB                                                                                                                                                                                                                     2025-11-17 00:00:00.000
GetDM_Freelocation_By_Checked 110831;D4CAY5R00001;10000;5S70;VB01;VB014Y;SB                                                                                                                                                                                                                    2024-12-13 00:00:00.000
GetDM_Freelocation_By_Checked 96108;D4CAY5R00001;100;5S20;VB01;VB027;SB                                                                                                                                                                                                                        2024-11-25 00:00:00.000

(3 rows affected)


Completion time: 2026-11-26T16:47:49.1986665+07:00



Text
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE [dbo].[GetMaterialOverOneYear] --GetMaterialOverOneYear
AS
BEGIN

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    SET NOCOUNT ON;


    -- Tạo bảng tạm để lưu dữ liệu quá hạn 1 năm
    DECLARE @RCOver TABLE
    (
        DeliveryDateOver DATE,
        DeliveryDate DATE,
        Material NVARCHAR(50),
        RCID BIGINT,
        Barcode NVARCHAR(4000),
		Location NVARCHAR(500),
		Category nvarchar(50)
    );

    -- Chèn dữ liệu vào bảng tạm
    INSERT INTO @RCOver(DeliveryDateOver, DeliveryDate, Material, RCID, Barcode,Location,Category)
    SELECT 
        CAST(DATEADD(MONTH, 12, rc.ReceivingCardDate) AS DATE),
        rc.ReceivingCardDate,
        rc.Material,
        rc.ReceivingCardID,
        rc.Barcode,
		b.Name as Location
		,rc.Category
    FROM tblReceivingCard (nolock) rc 
	-- Tuấn Anh sửa
	--inner join tblBlockReceivingCard (nolock) bl on bl.ReceivingCardID = rc.ReceivingCardID AND bl.Status = 0
	inner join tblBlockReceivingCard (nolock) bl on rc.Status = 0 and bl.ReceivingCardID = rc.ReceivingCardID AND bl.Status = 0 
	-- Tuấn Anh thêm để không kiểm tra quá hạn 1 năm với hàng PMD
	and rc.Sloc not in (select Sloc from tblTypeFrequency where Category = 'PMD')
	inner join tblBlock (nolock) b on b.BlockID = bl.BlockID AND b.Status = 0
    WHERE rc.Status = 0;
   

    -- Kết hợp dữ liệu từ bảng B và C
    WITH Combined AS (
        -- Lấy dữ liệu từ bảng DM_FreeLocation
        SELECT
		A.RCID,
		A.Barcode,
           A.DeliveryDate as DeliveryDate,
		   A.DeliveryDateOver,
		   A.Material,
            (case when (B.Ketqua IS null or B.Ketqua = '') then B.Ketqua2 else  B.Ketqua end ) as Status,
			null as Type_Check,
			null as Times_Check,
			(case when (B.QCendtime IS null or B.QCendtime = '') then cast(B.QCendtime2 as DAte) else  cast(B.QCendtime as DAte) end ) as Date_Check,
			'2' as Type,
			A.Location,
			A.Category
        FROM @RCOver A
        LEFT JOIN DM_FreeLocation (nolock) B ON A.Barcode = B.Barcode

        UNION ALL

        -- Lấy dữ liệu từ bảng tblHistoryQCCheck
        SELECT
		A.RCID,
		A.Barcode,
            H.Delivery_date AS DeliveryDate, -- Lấy ngày để so sánh
			A.DeliveryDateOver,
			H.Material,
            H.Status_Check as Status, 
			H.Type_Check,
			H.Times_Check,
			cast(H.Date_Check as Date) as Date_Check,
			'1' as Type,
			A.Location,
			H.Category
        FROM @RCOver A
        LEFT JOIN tblHistoryQCCheck (nolock) H ON H.Delivery_date = A.DeliveryDate AND H.Material = A.Material
    ),
    Ranked AS (
        -- Xếp hạng để xác định dòng có ngày gần nhất
        SELECT *,
               --ROW_NUMBER() OVER (PARTITION BY RCID ORDER BY DeliveryDate DESC,Date_Check DESC,Type asc) AS rn
			   ROW_NUMBER() OVER (PARTITION BY RCID ORDER BY DeliveryDate DESC,Date_Check DESC) AS rn
        FROM Combined
    )

    -- Chọn dòng có ngày gần nhất
    SELECT RCID,Barcode,DeliveryDate,DeliveryDateOver,Material,Status,Type_Check,Times_Check,Date_Check,Type,Location,Category
    FROM Ranked
    WHERE rn = 1;
END



Text
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE [dbo].[GetDM_Freelocation_By_Checked]
		
AS
BEGIN
	select q.Barcode
	,CAST((case when q.QCendtime IS Not null then q.QCendtime else q.QCendtime2 end ) as date) as DateCheck
	
	from DM_FreeLocation q
	inner join tblReceivingCard rc on rc.Barcode =  q.Barcode
	where q.QCendtime is not null or q.QCendtime2 is not null

END



Completion time: 2026-11-26T16:48:07.9126301+07:00
