Text
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- tu.nguyenthe
CREATE PROCEDURE [dbo].[CreatePlanOrder] @jsonData NVARCHAR(MAX)
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
			,jsonValues.Sloc
			,jsonValues.ProductionVersion
			,jsonValues.PlanOrderQuantity
			,jsonValues.GRQuantity
			,jsonValues.PostingDate
			,jsonValues.IsWD
		FROM OPENJSON(@jsonData) WITH (
				PlanOrderNumber NVARCHAR(10) '$.PlanOrderNumber'
				,Plant NVARCHAR(10) '$.Plant'
				,Material NVARCHAR(50) '$.Material'
				,Sloc NVARCHAR(10) '$.Sloc'
				,ProductionVersion NVARCHAR(10) '$.ProductionVersion'
				,PlanOrderQuantity FLOAT '$.PlanOrderQuantity'
				,GRQuantity FLOAT '$.GRQuantity'
				,PostingDate NVARCHAR(8) '$.PostingDate'
				,IsWD BIT '$.IsWD'
				) AS jsonValues
		) AS source
		ON target.PlanOrderNumber = source.PlanOrderNumber
		AND target.Plant = source.Plant
		AND target.Material = source.Material
		AND target.Sloc = source.Sloc
			
	WHEN NOT MATCHED
		THEN
			INSERT (
				PlanOrderNumber
				,Plant
				,Material
				,Sloc
				,ProductionVersion
				,PlanOrderQuantity
				,GRQuantity
				,PostingDate
				,STATUS
				,CreatedDate
				,CreatedBy
				,UpdatedDate
				,UpdatedBy
				,IsWD
				)
			VALUES (
				source.PlanOrderNumber
				,source.Plant
				,source.Material
				,source.Sloc
				,source.ProductionVersion
				,source.PlanOrderQuantity
				,source.GRQuantity
				,source.PostingDate
				,0
				,GETDATE()
				,@UserId -- Thêm giá trị mong muốn cho CreatedBy
				,NULL
				,NULL
				,source.IsWD
				);

	COMMIT TRANSACTION;

	SET @result = 1;

	SELECT @result AS Result;
		-- Commit
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

PlanOrderNumber SoDong      MinRecv    MaxRecv    MinCreated              MaxCreated
--------------- ----------- ---------- ---------- ----------------------- -----------------------
2026112701      36          2026-11-27 2026-12-01 2026-11-27 06:08:54.980 2026-11-27 06:08:54.980
2026112702      1           2026-11-27 2026-11-27 2026-11-27 06:11:01.177 2026-11-27 06:11:01.177
2026112703      2           2026-11-27 2026-11-27 2026-11-27 06:53:56.790 2026-11-27 06:53:56.790
2026112704      5           2026-11-27 2026-11-27 2026-11-27 13:10:12.327 2026-11-27 13:10:12.327

(4 rows affected)


Completion time: 2026-11-27T13:43:39.8366315+07:00
