PlanOrderNumber Material                                           Status ReceivingDate IsWD  PostingDate
--------------- -------------------------------------------------- ------ ------------- ----- -----------
2026112701      PNBC1711ZA1/AS                                     2      2026-12-01    0     NULL

(1 row affected)

Plant      Material                                           ProductionVersion PostingDate                                                                                                                                                                                                                                                      GRQuantity             PlanOrderNumber
---------- -------------------------------------------------- ----------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ---------------------- ---------------

Status SoDong      CapNhatCuoi
------ ----------- -----------------------
2      9           2026-11-27 13:19:06.543
3      35          2026-11-27 07:12:58.360

(2 rows affected)

Text
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- tu.nguyenthe
CREATE PROCEDURE [dbo].[UpdateStatusDataBackFlushToSAP] 
	@jsonData NVARCHAR(MAX)
	,@userid NVARCHAR(20)
	,@result INT OUTPUT
AS
BEGIN TRY
	-- Query
	BEGIN TRANSACTION;

	MERGE INTO [dbo].[tblPlanOrder] AS target
	USING (
		SELECT jsonValues.PlanOrderNumber
			,jsonValues.Plant
			,jsonValues.Material
			,jsonValues.ProductionVersion
			,jsonValues.GRQuantity
			,jsonValues.PostingDate
		FROM OPENJSON(@jsonData) WITH (
				PlanOrderNumber NVARCHAR(10) '$.PlanOrderNumber'
				,Plant NVARCHAR(10) '$.Plant'
				,Material NVARCHAR(50) '$.Material'
				,ProductionVersion NVARCHAR(10) '$.ProductionVersion'
				,GRQuantity FLOAT '$.GRQuantity'
				,PostingDate NVARCHAR(8) '$.PostingDate'
				) AS jsonValues
		) AS source
		ON target.PlanOrderNumber = source.PlanOrderNumber
		AND target.Plant = source.Plant
		AND target.Material = source.Material
		AND target.ProductionVersion = source.ProductionVersion
		--AND target.PlanOrderQuantity = source.GRQuantity	
	WHEN MATCHED
		THEN
			UPDATE 
			SET target.PostingDate = source.PostingDate
				,target.Status = 3
				,target.UpdatedDate = GETDATE()
				,target.UpdatedBy = @UserId;
	SET @result = 1;

	SELECT @result AS Result;
		-- Commit
	COMMIT TRANSACTION;

END TRY

BEGIN CATCH
	IF @@TRANCOUNT > 0
		-- Rollback
		SET @result = 0;

	SELECT @result AS Result;

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


Completion time: 2026-11-27T13:40:53.5359182+07:00
