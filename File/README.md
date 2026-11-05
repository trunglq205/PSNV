USE [CELL_MANAGEMENT]
GO
/****** Object:  StoredProcedure [dbo].[ESD_JOB_JUDGE_BYDAY]    Script Date: 11/05/2026 5:11:28 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ============================================================================
   4. ESD_JOB_JUDGE_BYDAY

   SUA: giong hệt muc 3 - bo AND AM IS NULL, bo AND [PM] IS NULL,
        them khoi khoi phuc confirm o cuoi (gioi han dung @day).
        Nhanh OK o day von da co UPDATE FINAL_JUDGE='OK' nen giu nguyen.
============================================================================ */

ALTER PROCEDURE [dbo].[ESD_JOB_JUDGE_BYDAY]
@day nvarchar(20)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CodeEmp nvarchar(20)
    DECLARE @IDCard nvarchar(20)
    DECLARE @Shift nvarchar(20)
    DECLARE @InTime nvarchar(20)
    DECLARE @StartTime nvarchar(20)
    DECLARE @MealTime nvarchar(20)
    DECLARE cursorProduct CURSOR FOR
        SELECT CodeEmp, IDCard, [Shift], InTime
        , CAST(StartTime as datetime) as StartTime
        , CAST(MealTime as datetime) as MealTime
        FROM [CELL_MANAGEMENT].[dbo].[ESD_MASTER_HISTORY](nolock)
        WHERE Work_Date = @day
        AND FINAL_JUDGE = 'NG'
        AND Shift <> '1'
        AND Shift <> 'ML'
        AND StartTime IS NOT NULL

    DECLARE @DATE_SCAN NVARCHAR(12)
    DECLARE @RETURN_DT_SCAN NVARCHAR(20)
    DECLARE @RETURN_DT_SCAN_MEALTIME NVARCHAR(20)
    DECLARE @TIME_CHECK NVARCHAR(20)
    DECLARE @TIME_CHECK_MEALTIME NVARCHAR(20)
    DECLARE @COUNT_ INT
    DECLARE @MealTimeStart DATETIME
    DECLARE @MealTimeEnd DATETIME
    DECLARE @MealTimeStartStr NVARCHAR(8)
    DECLARE @MealTimeEndStr NVARCHAR(8)

    SET @DATE_SCAN = @day
    SET @COUNT_ = 1

    OPEN cursorProduct
    FETCH NEXT FROM cursorProduct
        INTO @CodeEmp, @IDCard, @Shift, @InTime, @StartTime, @MealTime

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @COUNT_ = @COUNT_ + 1

        SET @MealTimeStartStr = NULL
        SET @MealTimeEndStr = NULL

        SELECT TOP 1
            @MealTimeStartStr = CONVERT(VARCHAR(8), MT.MealTime_Start, 108),
            @MealTimeEndStr   = CONVERT(VARCHAR(8), MT.MealTime_End,   108)
        FROM [CELL_MANAGEMENT].[dbo].[ESD_MEALTIME] MT
        WHERE MT.Shift = @Shift
          AND (MT.Department = (SELECT TOP 1 Department FROM ESD_MASTER_HISTORY
                                WHERE CodeEmp = @CodeEmp AND Work_Date = @day)
               OR MT.Department IS NULL)
        ORDER BY CASE WHEN MT.Department IS NOT NULL THEN 0 ELSE 1 END

        IF @MealTimeStartStr IS NULL OR @MealTimeEndStr IS NULL
        BEGIN
            FETCH NEXT FROM cursorProduct
                INTO @CodeEmp, @IDCard, @Shift, @InTime, @StartTime, @MealTime
            CONTINUE
        END

        SET @MealTimeStart = CAST(
            CONVERT(VARCHAR(10), CONVERT(DATE, @StartTime), 23) + ' ' + @MealTimeStartStr
        AS DATETIME)

        SET @MealTimeEnd = CAST(
            CONVERT(VARCHAR(10), CONVERT(DATE, @StartTime), 23) + ' ' + @MealTimeEndStr
        AS DATETIME)

        IF @MealTimeEnd < @MealTimeStart
            SET @MealTimeEnd = DATEADD(DAY, 1, @MealTimeEnd)

        IF @MealTimeStart < CAST(@StartTime AS DATETIME)
            SET @MealTimeStart = DATEADD(DAY, 1, @MealTimeStart)

        SET @RETURN_DT_SCAN = (
            SELECT TOP 1 datastarttime
            FROM (
                SELECT replace(convert(date,left(Time_input,10)),'.','-') + ' ' +
                       replace(right(Time_input,8),'.',':') as datastarttime
                FROM tbl_mater_endcheck(NOLOCK)
                WHERE Card_code = @IDCard
                AND Resutl = 'PASS'
                AND LEN(LTRIM(RTRIM(Time_input))) >= 18
                AND replace(convert(date,left(Time_input,10)),'.','-') = convert(date, @StartTime)
            ) ab
            WHERE TRY_CAST(datastarttime AS DATETIME) >= DATEADD(HOUR, -1, CAST(@StartTime AS DATETIME))
            AND   TRY_CAST(datastarttime AS DATETIME) <= DATEADD(HOUR,  1, CAST(@StartTime AS DATETIME))
            ORDER BY datastarttime DESC
        )

        SET @TIME_CHECK = (
            SELECT TOP 1 timeScan
            FROM (
                SELECT replace(convert(date,left(Time_input,10)),'.','-') + ' ' +
                       replace(right(Time_input,8),'.',':') as timeScan
                FROM tbl_mater_endcheck(NOLOCK)
                WHERE Card_code = @IDCard
                AND LEN(LTRIM(RTRIM(Time_input))) >= 18
                AND replace(convert(date,left(Time_input,10)),'.','-')
                    = CONVERT(VARCHAR(10), CONVERT(DATE, @StartTime), 23)
            ) a
            WHERE TRY_CAST(timeScan AS DATETIME) < @MealTimeStart
            ORDER BY timeScan DESC
        )

        SET @RETURN_DT_SCAN_MEALTIME = (
            SELECT TOP 1 datatime
            FROM (
                SELECT replace(convert(date,left(Time_input,10)),'.','-') + ' ' +
                       replace(right(Time_input,8),'.',':') as datatime
                FROM tbl_mater_endcheck(NOLOCK)
                WHERE Card_code = @IDCard
                AND Resutl = 'PASS'
                AND LEN(LTRIM(RTRIM(Time_input))) >= 18
            ) ab
            WHERE TRY_CAST(datatime AS DATETIME) >= @MealTimeStart
            AND   TRY_CAST(datatime AS DATETIME) <= @MealTimeEnd
            ORDER BY datatime DESC
        )

        SET @TIME_CHECK_MEALTIME = (
            SELECT TOP 1 timeScan
            FROM (
                SELECT replace(convert(date,left(Time_input,10)),'.','-') + ' ' +
                       replace(right(Time_input,8),'.',':') as timeScan
                FROM tbl_mater_endcheck(NOLOCK)
                WHERE Card_code = @IDCard
                AND LEN(LTRIM(RTRIM(Time_input))) >= 18
                AND replace(convert(date,left(Time_input,10)),'.','-')
                    IN (
                        CONVERT(VARCHAR(10), CONVERT(DATE, @StartTime), 23),
                        CONVERT(VARCHAR(10), DATEADD(DAY,1,CONVERT(DATE,@StartTime)), 23)
                    )
            ) a
            WHERE TRY_CAST(timeScan AS DATETIME) > DATEADD(HOUR, 1, CAST(@StartTime AS DATETIME))
            AND   TRY_CAST(timeScan AS DATETIME) <= DATEADD(HOUR, 1, @MealTimeEnd)
            ORDER BY timeScan DESC
        )

        IF @RETURN_DT_SCAN IS NOT NULL
        BEGIN
            IF NOT EXISTS(SELECT 1 FROM [CELL_MANAGEMENT].[dbo].[ESD_RESULT](nolock)
                          WHERE EmpCode = @CodeEmp AND IDCard = @IDCard
                          AND WorkDate = convert(date, @StartTime))
            BEGIN
                INSERT INTO [CELL_MANAGEMENT].[dbo].[ESD_RESULT]
                ([EmpCode],[IDCard],[WorkDate],[AM],[ResultAM],[FinalResult],[Shift])
                VALUES(@CodeEmp, @IDCard, convert(date, @StartTime), @RETURN_DT_SCAN, 'OK', 'NG', @Shift)
                UPDATE ESD_MASTER_HISTORY SET FINAL_JUDGE = 'NG'
                WHERE CodeEmp = @CodeEmp AND Work_Date = @day
            END
            ELSE
            BEGIN
                IF @RETURN_DT_SCAN_MEALTIME IS NOT NULL
                BEGIN
                    UPDATE [CELL_MANAGEMENT].[dbo].[ESD_RESULT]
                    SET [AM] = @RETURN_DT_SCAN, [ResultAM] = 'OK',
                        [PM] = @RETURN_DT_SCAN_MEALTIME, [ResultPM] = 'OK', [FinalResult] = 'OK'
                    WHERE EmpCode = @CodeEmp AND IDCard = @IDCard
                    AND WorkDate = convert(date, @StartTime)
                    UPDATE ESD_MASTER_HISTORY SET FINAL_JUDGE = 'OK'
                    WHERE CodeEmp = @CodeEmp AND Work_Date = @day
                END
                ELSE
                BEGIN
                    UPDATE [CELL_MANAGEMENT].[dbo].[ESD_RESULT]
                    SET [AM] = @RETURN_DT_SCAN, [ResultAM] = 'OK',
                        [PM] = @TIME_CHECK_MEALTIME, [ResultPM] = 'NG', [FinalResult] = 'NG'
                    WHERE EmpCode = @CodeEmp AND IDCard = @IDCard
                    AND WorkDate = convert(date, @StartTime)
                    -- DA BO:  AND [PM] IS NULL
                    UPDATE ESD_MASTER_HISTORY SET FINAL_JUDGE = 'NG'
                    WHERE CodeEmp = @CodeEmp AND Work_Date = @day
                END
            END
        END
        ELSE
        BEGIN
            IF NOT EXISTS(SELECT 1 FROM [CELL_MANAGEMENT].[dbo].[ESD_RESULT](nolock)
                          WHERE EmpCode = @CodeEmp AND IDCard = @IDCard
                          AND WorkDate = convert(date, @StartTime))
            BEGIN
                INSERT INTO [CELL_MANAGEMENT].[dbo].[ESD_RESULT]
                ([EmpCode],[IDCard],[WorkDate],[AM],[ResultAM],[FinalResult],[Shift])
                VALUES(@CodeEmp, @IDCard, convert(date, @StartTime), @TIME_CHECK, 'NG', 'NG', @Shift)
            END
            ELSE
            BEGIN
                UPDATE [CELL_MANAGEMENT].[dbo].[ESD_RESULT]
                SET [AM] = @TIME_CHECK, [ResultAM] = 'NG', [FinalResult] = 'NG', [Shift] = @Shift
                WHERE EmpCode = @CodeEmp AND IDCard = @IDCard
                AND WorkDate = convert(date, @StartTime)
                -- DA BO:  AND AM IS NULL
            END
        END

        FETCH NEXT FROM cursorProduct
            INTO @CodeEmp, @IDCard, @Shift, @InTime, @StartTime, @MealTime
    END

    CLOSE cursorProduct
    DEALLOCATE cursorProduct

    /* KHOI PHUC CONFIRM cho dung ngay vua cham lai */
    UPDATE R
    SET R.ResultAM = 'OK', R.ResultPM = 'OK', R.FinalResult = 'OK'
    FROM [CELL_MANAGEMENT].[dbo].[ESD_RESULT] R
    WHERE CAST(R.WorkDate AS date) = CAST(@day AS date)
      AND EXISTS (
            SELECT 1 FROM [CELL_MANAGEMENT].[dbo].[ESD_HISTORYCONFIRM] C
            WHERE C.UserID = R.EmpCode
              AND C.WorkDate = CAST(@day AS date)
      )
END
