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




(14412 rows affected)
RCID                 Barcode                                                                                                                                                                                                                                                          DeliveryDate            DeliveryDateOver        Material                                                                                             Status                                             Type_Check                                         Times_Check Date_Check              Type                                               Location                                                                                             Category
-------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ----------------------- ----------------------- ---------------------------------------------------------------------------------------------------- -------------------------------------------------- -------------------------------------------------- ----------- ----------------------- -------------------------------------------------- ---------------------------------------------------------------------------------------------------- --------------------------------------------------
440583               440583;F301Q-3503A;3;6197;VG01;VB013;NG                                                                                                                                                                                                                          2026-04-21 00:00:00.000 2027-04-21 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
443401               443401;F301Q-3503A;1;6197;VG01;VB013;NG                                                                                                                                                                                                                          2026-04-24 00:00:00.000 2027-04-24 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
449293               449293;F301Q-3503A;1;6197;VG01;VB013;NG                                                                                                                                                                                                                          2026-05-06 00:00:00.000 2027-05-06 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
452583               452583;F301Q-3503A;1;6197;VG01;VB013;NG                                                                                                                                                                                                                          2026-05-11 00:00:00.000 2027-05-11 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
456476               456476;F301Q-3503A;1;6197;VG01;VB013;NG                                                                                                                                                                                                                          2026-05-15 00:00:00.000 2027-05-15 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
459144               459144;F301Q-3503A;1;6197;VG01;VB013;NG                                                                                                                                                                                                                          2026-05-19 00:00:00.000 2027-05-19 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
459781               459781;F301Q-3503A;2;6197;VG01;VB013;NG                                                                                                                                                                                                                          2026-05-20 00:00:00.000 2027-05-20 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
465349               465349;F301Q-3503A;1;6197;VG01;VB013;NG                                                                                                                                                                                                                          2026-05-28 00:00:00.000 2027-05-28 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
356402               356402;F301Q-3503A;2;6197;VG01;VB013;NG                                                                                                                                                                                                                          2025-11-25 00:00:00.000 2026-11-25 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
356403               356403;F301Q-3503A;6;6197;VG01;VB013;NG                                                                                                                                                                                                                          2025-11-25 00:00:00.000 2026-11-25 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
356404               356404;F301Q-3503A;1;6197;VG01;VB013;NG                                                                                                                                                                                                                          2025-11-24 00:00:00.000 2026-11-24 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
356405               356405;F301Q-3503A;1;6197;VG01;VB013;NG                                                                                                                                                                                                                          2025-11-19 00:00:00.000 2026-11-19 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
356406               356406;F301Q-3503A;1;6197;VG01;VB013;NG                                                                                                                                                                                                                          2025-11-17 00:00:00.000 2026-11-17 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
356407               356407;F301Q-3503A;1;6197;VG01;VB013;NG                                                                                                                                                                                                                          2025-11-06 00:00:00.000 2026-11-06 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
356408               356408;F301Q-3503A;1;6197;VG01;VB013;NG                                                                                                                                                                                                                          2025-11-04 00:00:00.000 2026-11-04 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
356428               356428;F301Q-3503A;13;6197;VG01;VB013;NG                                                                                                                                                                                                                         2025-11-04 00:00:00.000 2026-11-04 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
406712               406712;F301Q-3503A;11;6197;VG01;VB013;NG                                                                                                                                                                                                                         2026-03-04 00:00:00.000 2027-03-04 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
414486               414486;F301Q-3503A;4;6197;VG01;VB013;NG                                                                                                                                                                                                                          2026-03-16 00:00:00.000 2027-03-16 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
415190               415190;F301Q-3503A;3;6197;VG01;VB013;NG                                                                                                                                                                                                                          2026-03-17 00:00:00.000 2027-03-17 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
416874               416874;F301Q-3503A;1;6197;VG01;VB013;NG                                                                                                                                                                                                                          2026-03-19 00:00:00.000 2027-03-19 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
420036               420036;F301Q-3503A;6;6197;VG01;VB013;NG                                                                                                                                                                                                                          2026-03-24 00:00:00.000 2027-03-24 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
420802               420802;F301Q-3503A;6;6197;VG01;VB013;NG                                                                                                                                                                                                                          2026-03-25 00:00:00.000 2027-03-25 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
422144               422144;F301Q-3503A;7;6197;VG01;VB013;NG                                                                                                                                                                                                                          2026-03-27 00:00:00.000 2027-03-27 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG
423270               423270;F301Q-3503A;2;6197;VG01;VB013;NG                                                                                                                                                                                                                          2026-03-30 00:00:00.000 2027-03-30 00:00:00.000 F301Q-3503A                                                                                          NULL                                               NULL                                               NULL        NULL                    2                                                  1.SN006.1.02                                                                                         NG

(24 rows affected)


Completion time: 2026-11-27T08:43:07.5417487+07:00
