Text
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE [dbo].[SearchBackFlush] --'','','','','','','',1,20
    @date AS DATETIME = NULL,
    @PlanOrderNumber nvarchar(10),
    @Material nvarchar(50),
    @Plant nvarchar(50),
    @Sloc nvarchar(50),
    @ProductionVersion nvarchar(50),
    @Status tinyint,
    @PageNumber INT,
    @PageSize INT
AS
BEGIN
    SET NOCOUNT ON;
    SET @date = ISNULL(@date, getdate());

    DECLARE @StartRow INT;

    -- Tính toán chỉ số bắt đầu và kết thúc của các bản ghi cần lấy
    SET @StartRow = (@PageNumber - 1) * @PageSize + 1;

    -- Tạo bảng tạm thời
    CREATE TABLE #RCBackPlush (
        RCID bigint,
        PrintDate DATETIME,
        ReceiveDate DATETIME,
        ReceivingCardTime NVARCHAR(50),
        BackPlushId NVARCHAR(10),
		Material NVARCHAR(50),
		Plant NVARCHAR(50),
		Sloc NVARCHAR(50),
    );

    -- Chèn dữ liệu vào bảng tạm #BackPlush từ JSON trong #RCBackPlush và kết hợp với RCID
    INSERT INTO #RCBackPlush 
    (RCID, PrintDate, ReceiveDate, ReceivingCardTime, BackPlushId,Material,Plant,Sloc)
    SELECT 
        RC.ReceivingCardID,
        RC.UpdatedDate,
        RC.ReceivingCardDate,
        RC.ReceivingCardTime,
        JSONData.ID AS BackPlushId,
		RC.Material,
		RC.Plant,
		RC.Sloc
    FROM 
        tblReceivingCard RC 
        CROSS APPLY OPENJSON(RC.PlanOrderNumber)
        WITH (
            ID NVARCHAR(10) '$.ID'
        ) AS JSONData
    WHERE RC.ReceivingType = 2 AND Status <> 1 and  RC.PlanOrderNumber <>'';

    CREATE TABLE #CombinedData (
        PlanOrderNumber NVARCHAR(50),
        Material NVARCHAR(50),
        Plant NVARCHAR(50),
        Sloc NVARCHAR(50),
        ProductionVersion NVARCHAR(50),
        GRQuantity float,
        PlanOrderQuantity float,
        TodayQuantity float,
        CreatedDate Datetime,
        PrintDate Datetime,
        ReceiveDate Datetime,
        ReceivingCardTime NVARCHAR(50),
        Status TINYINT,
		ReceivingCardId BIGINT
    );

    WITH CTE1
    AS (
        SELECT
            t.PlanOrderNumber,
            t.Material,
            t.Plant,
            t.Sloc,
            t.ProductionVersion,
            t.GRQuantity,
            t.PlanOrderQuantity,
            0 as TodayQuantity,  -- Tạm thời đặt giá trị bằng 0
            t.CreatedDate,
            b.PrintDate,
            b.ReceiveDate,
            b.ReceivingCardTime,
            NULL as StoreDate,
            CASE 
			WHEN t.STATUS = 0
				AND t.GRQuantity = 0
				THEN 0
			WHEN t.STATUS = 2
				THEN 2
			WHEN t.STATUS = 0
				AND t.GRQuantity > 0
				AND t.GRQuantity < t.PlanOrderQuantity
				THEN 1
			WHEN t.STATUS = 3
				THEN 3
			WHEN t.STATUS = 4
				THEN 4
			ELSE 2
			END AS STATUS,
            ROW_NUMBER() OVER (
                PARTITION BY t.PlanOrderNumber, t.Material, t.Plant, t.Sloc ORDER BY t.CreatedDate DESC
            ) AS rn,
			b.RCID
        FROM tblPlanOrder t
        LEFT JOIN #RCBackPlush b ON b.BackPlushId = t.PlanOrderNumber
		AND b.Material = t.Material AND t.Plant = b.Plant AND t.Sloc = b.Sloc
		AND  DATEDIFF(day, b.ReceiveDate, @date) = 0  WHERE (b.BackPlushId IS NOT NULL AND DATEDIFF(day, b.ReceiveDate, @date) = 0)
   OR (b.BackPlushId IS NULL AND DATEDIFF(day, t.CreatedDate, @date) = 0)
    )
    INSERT INTO #CombinedData (
        PlanOrderNumber, 
        Material,
        Plant, 
        Sloc, 
        ProductionVersion,
        GRQuantity, 
        PlanOrderQuantity, 
        TodayQuantity, 
        CreatedDate, 
        PrintDate, 
        ReceiveDate, 
        ReceivingCardTime, 
        Status,
		ReceivingCardId
    )
    SELECT 
        PlanOrderNumber,
        Material,
        Plant,
        Sloc,
        ProductionVersion,
        GRQuantity,
        PlanOrderQuantity,
        TodayQuantity,
        CreatedDate,
        PrintDate,
        ReceiveDate,
        ReceivingCardTime,
        Status,
		RCID
    FROM CTE1
    WHERE rn = 1;

    DECLARE @TotalRecord INT;
    SET @TotalRecord = (
        SELECT COUNT(*) AS TotalRecord
        FROM #CombinedData t
        WHERE   
            (
                t.PlanOrderNumber = @PlanOrderNumber
                OR @PlanOrderNumber = ''
            )
            AND (
                t.Material LIKE '%' + TRIM(@Material) + '%'
                OR @Material = ''
            )
            AND (
                Plant LIKE '%' + TRIM(@Plant) + '%'
                OR @Plant = ''
            )
            AND (
                Sloc LIKE '%' + @sloc + '%'
                OR @sloc = ''
            )
            AND (
                ProductionVersion LIKE '%' + TRIM(@ProductionVersion) + '%'
                OR @ProductionVersion = ''
            )
            AND (
                STATUS = @status
                OR @status IS NULL
            )
    );

    SELECT 
        t.PlanOrderNumber,
        t.Material,
        t.Plant,
        t.Sloc,
        t.ProductionVersion,
        t.GRQuantity,
        t.PlanOrderQuantity,
        t.TodayQuantity,
        t.CreatedDate,
        t.PrintDate,
        t.ReceiveDate,
        t.ReceivingCardTime,
        NULL as StoreDate,
        t.Status,
		t.ReceivingCardId,
        @TotalRecord AS TotalRecord
    FROM #CombinedData t
    WHERE   
        (
            t.PlanOrderNumber = @PlanOrderNumber
            OR @PlanOrderNumber = ''
        )
        AND (
            t.Material LIKE '%' + TRIM(@Material) + '%'
            OR @Material = ''
        )
        AND (
            Plant LIKE '%' + TRIM(@Plant) + '%'
            OR @Plant = ''
        )
        AND (
            Sloc LIKE '%' + @sloc + '%'
            OR @sloc = ''
        )
        AND (
            ProductionVersion LIKE '%' + TRIM(@ProductionVersion) + '%'
            OR @ProductionVersion = ''
        )
        AND (
            STATUS = @status
            OR @status IS NULL
        )
    ORDER BY CreatedDate DESC 
    OFFSET(@StartRow - 1) ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END


Text
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- =============================================
-- Author:		hai.dinhduc
-- =============================================
CREATE PROCEDURE [dbo].[ConfirmBackFlush] @planOrderNumber NVARCHAR(10)
	,@material NVARCHAR(50)
	,@plant NVARCHAR(10)
	,@sloc NVARCHAR(10)
	,@uuid NVARCHAR(10)
AS
BEGIN TRY
	BEGIN TRANSACTION

	UPDATE tblPlanOrder
	SET STATUS = 2
		,UpdatedBy = @uuid
		,UpdatedDate = GETDATE()
	FROM tblPlanOrder
	WHERE PlanOrderNumber = @planOrderNumber
		AND Material = @material
		AND Plant = @plant
		AND Sloc = @sloc
		AND STATUS = 0
		AND GRQuantity > 0

	SELECT 1 AS Result;

	-- Commit
	COMMIT TRANSACTION;
END TRY

BEGIN CATCH
	IF @@TRANCOUNT > 0
	BEGIN
		-- Rollback		
		SELECT 0 AS Result;

		ROLLBACK TRANSACTION;
	END

	DECLARE @ErrorMessage NVARCHAR(4000)
	DECLARE @ErrorSeverity INT
	DECLARE @ErrorState INT

	SELECT @ErrorMessage = ERROR_MESSAGE()
		,@ErrorSeverity = ERROR_SEVERITY()
		,@ErrorState = ERROR_STATE()

	RAISERROR (
			@ErrorMessage
			,@ErrorSeverity
			,@ErrorState
			)
END CATCH

PlanOrderNumber                                    Material                                           Plant                                              Sloc                                               ProductionVersion                                  GRQuantity             PlanOrderQuantity      TodayQuantity          CreatedDate             PrintDate               ReceiveDate             ReceivingCardTime                                  StoreDate   Status ReceivingCardId      TotalRecord
-------------------------------------------------- -------------------------------------------------- -------------------------------------------------- -------------------------------------------------- -------------------------------------------------- ---------------------- ---------------------- ---------------------- ----------------------- ----------------------- ----------------------- -------------------------------------------------- ----------- ------ -------------------- -----------
2026112701                                         PNBC1711ZA1/AS                                     VR01                                               11A0                                               1A40                                               898                    898                    0                      2026-11-27 06:08:54.980 NULL                    NULL                    NULL                                               NULL        2      NULL                 1


Completion time: 2026-11-27T13:37:20.6740230+07:00
