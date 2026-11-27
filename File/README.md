PlanOrderNumber Material                                           Plant      Sloc       STATUS GRQuantity             PlanOrderQuantity      CreatedDate             UpdatedDate             UpdatedBy
--------------- -------------------------------------------------- ---------- ---------- ------ ---------------------- ---------------------- ----------------------- ----------------------- ----------
2026112701      PNBC1711ZA1/AS                                     VR01       11A0       2      898                    898                    2026-11-27 06:08:54.980 2026-11-27 06:40:30.210 2000543

(1 row affected)

Text
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[GetDataBackFlush]
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT Plant, Material, ProductionVersion, FORMAT(GETDATE(), 'yyyyMMdd') AS PostingDate, GRQuantity, PlanOrderNumber
	FROM tblPlanOrder
	WHERE FORMAT(ReceivingDate, 'yyyy-MM-dd') <= FORMAT(GETDATE(), 'yyyy-MM-dd') AND Status = 2 and (IsWD <> 1 OR IsWD IS NULL)
END

Text
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE [dbo].[InsertDataPlanErrorToSAP]
	@jsonData		NVARCHAR(MAX),
	@userId			NVARCHAR(10),
	 @result INT OUTPUT
AS
BEGIN TRY
	BEGIN TRANSACTION
		

INSERT INTO tblDataPlanOrderErrorToSAP(
    Plant,
    Material,
    ProductionVersion,
    PostingDate,
    Quantity,
    Error,
    Status,
    CreatedBy,
    CreatedDate
)
SELECT 
    jsonValues.Plant,
    jsonValues.Material,
    jsonValues.Productio
nVersion,
    jsonValues.PostingDate,
    jsonValues.Quantity,
    jsonValues.Error,
    0,
    @userId,
    GETDATE()
FROM OPENJSON(@jsonData) 
WITH (
    Plant NVARCHAR(10),
    Material NVARCHAR(50),
    ProductionVersion NVARCHAR(10),
    PostingDate 
NVARCHAR(8),
    Quantity float,
    Error NVARCHAR(max)
) AS jsonValues;
	

			UPDATE d
SET d.Status = 4, ---status err
    d.CreatedBy = @userId,
    d.UpdatedBy = GETDATE()
FROM tblPlanOrder d
INNER JOIN OPENJSON(@jsonData) 
WITH (
    Plant NVARCHAR(10),
    Material NVARCHAR(50),
    ProductionVersion NVARCHAR(10),
    Postin
gDate NVARCHAR(8),
    Quantity float,
    Error NVARCHAR(max)
) j ON d.Material = j.Material AND d.Plant = j.Plant AND d.PostingDate = j.PostingDate AND d.Status = 3;

	SET @result = 1;

    SELECT @result AS Result;
	-- Commit
	COMMIT TRANSACTION;

END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0
	BEGIN
	  -- Rollback
        SET @result = 0;
        SELECT @result AS Result;

		ROLLBACK TRANSACTION;
	END

	DECLARE @ErrorMessage NVARCHAR(4000)
	DECLARE @ErrorSeverity INT
	DECLARE @ErrorState INT

	SELECT @ErrorMessage = ERROR_MESSAGE()
		   ,@ErrorSeverity = ERROR_SEVERITY()
		   ,@ErrorState = ERROR_STATE()

	RAISERROR ( @ErrorMessage
			    ,@ErrorSeverity
				,@ErrorState)
END CATCH


Completion time: 2026-11-27T13:40:04.2940291+07:00
