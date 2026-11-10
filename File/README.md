USE [SWMS_DEV]
GO
/****** Object:  StoredProcedure [dbo].[CreateKittingCard_UpdateBarcode]    Script Date: 11/10/2026 10:18:09 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		tu.nguyenthe
-- Description:	Create New CreateKittingCard
-- =============================================
ALTER PROCEDURE [dbo].[CreateKittingCard_UpdateBarcode] @jsonData NVARCHAR(MAX)
AS
BEGIN TRY
	-- Query
	BEGIN TRANSACTION;

	DECLARE @InsertedKittingCardID TABLE (
		KittingCardID BIGINT
		,KittingListDetailId BIGINT
		,quantity FLOAT
		);

	INSERT INTO [dbo].[tblKittingCard] (
		[RCID]
		,[RCDetailID]
		,[KittingListDetailId]
		,[KittingTimeType]
		,[Plant]
		,[PartNo]
		,[Model]
		,[Quantity]
		,[DateTimeKitting]
		,[Line]
		,[Time]
		,[Sloc]
		,[Barcode]
		,[PosFA]
		,[PosMCS]
		,[PicUser]
		,[Status]
		,[CreatedDate]
		,[CreatedBy]
		,[UpdatedDate]
		,[UpdatedBy]
		,[PL]
		)
	OUTPUT INSERTED.KittingCardID
		,INSERTED.KittingListDetailId
		,inserted.Quantity
	INTO @InsertedKittingCardID
	SELECT RCID
		,RCDetailID
		,KittingListDetailId
		,KittingTimeType
		,Plant
		,PartNo
		,Model
		,Quantity
		,GETDATE() AS DateTimeKitting
		,Line
		,TIME
		,Sloc
		,'' AS Barcode
		,PosFA
		,PosMCS
		,PicUser
		,1 AS [Status]
		,GETDATE() AS CreatedDate
		,CreatedBy
		,NULL AS UpdatedDate
		,NULL AS UpdatedBy
		,PL
	FROM OPENJSON(@jsonData) WITH (
			RCID NVARCHAR(400) '$.RCID'
			,RCDetailID NVARCHAR(400) '$.RCDetailID'
			,KittingListDetailId BIGINT '$.KittingListDetailId'
			,KittingTimeType NVARCHAR(5) '$.KittingTimeType'
			,Plant NVARCHAR(10) '$.Plant'
			,PartNo NVARCHAR(50) '$.PartNo'
			,Model NVARCHAR(20) '$.Model'
			,Quantity FLOAT '$.Quantity'
			,Line NVARCHAR(10) '$.Line'
			,TIME NVARCHAR(10) '$.Time'
			,Sloc NVARCHAR(10) '$.Sloc'
			,Barcode NVARCHAR(4000) '$.Barcode'
			,PosFA NVARCHAR(50) '$.PosFA'
			,PosMCS NVARCHAR(50) '$.PosMCS'
			,PicUser NVARCHAR(10) '$.PicUser'
			,CreatedBy NVARCHAR(10) '$.CreatedBy'
			,UpdatedDate DATETIME '$.UpdatedDate'
			,UpdatedBy NVARCHAR(10) '$.UpdatedBy'
			,PL NVARCHAR(10) '$.PL'
			) AS jsonValues;

-- update Barcode for tblKittingCard
---Case new barcode
UPDATE car
SET Barcode = CASE 
	--- Hang FA
    WHEN kl.KittingType = 0 THEN CONCAT(
        car.Model, ';', car.PartNo, ';', car.Line, ';', car.Quantity, ';', d.LocationName, ';', 
        car.Sloc, ';', FORMAT(kl.Deliverydate, 'yyyy-MM-dd'), ';', car.Time, ';', 
        car.KittingTimeType, ';', car.Plant, ';', d.Category, ';', d.Category, ';', 0, ';', 'P',';',KittingCardID
    )
	--- Hang DIP
    WHEN kl.KittingType = 1 THEN CONCAT(
        car.Model, ';', car.PartNo, ';', car.Line, ';', car.Quantity, ';', d.LocationName, ';', d.ReceiptSloc, ';',
		FORMAT(kl.Deliverydate, 'yyyy-MM-dd'), ';', car.Plant, ';', car.Time, ';', car.Sloc, ';', 'UploadNo', ';', d.Category, ';', d.Category, ';', 'DIP',';',KittingCardID
    )
	--- Hang Outside
    WHEN kl.KittingType = 3 THEN CONCAT(
        d.PullID, ';', car.PartNo, ';', car.Line, ';', car.Quantity, ';', 
        car.Plant, ';', FORMAT(kl.Deliverydate, 'yyyy-MM-dd'), ';', 
        d.Sloc, ';', d.LocationName, ';', d.ReceiptSloc, ';', d.Tcode, ';', d.KittingFrom, ';', 'outside',';',KittingCardID
		)
    ELSE NULL END
	FROM tblKittingCard car 
	INNER JOIN tblKittingListDetail d ON car.KittingListDetailId = d.ID
	INNER JOIN tblKittingList kl ON kl.ID = d.KittingListID
	WHERE KittingCardID IN (
			SELECT KittingCardID
			FROM @InsertedKittingCardID) AND kl.KittingType IN (0, 1, 3)
	
	SELECT *
	FROM tblKittingCard
	WHERE KittingCardID IN (
			SELECT KittingCardID
			FROM @InsertedKittingCardID
			);

	-- Commit
	COMMIT TRANSACTION;
END TRY

BEGIN CATCH
	IF @@TRANCOUNT > 0
		ROLLBACK TRANSACTION;

	DECLARE @ErrorMessage NVARCHAR(4000);
	DECLARE @ErrorSeverity INT;
	DECLARE @ErrorState INT;

	SELECT @ErrorMessage = ERROR_MESSAGE()
		,@ErrorSeverity = ERROR_SEVERITY()
		,@ErrorState = ERROR_STATE();

	RAISERROR (
			@ErrorMessage
			,@ErrorSeverity
			,@ErrorState
			);
END CATCH;
