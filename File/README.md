https://github.com/trunglq205/PSNV/tree/main/db


USE [TimeSheet.22]
GO
/****** Object:  StoredProcedure [dbo].[ESD_MASTER]    Script Date: 11/05/2026 5:02:15 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[ESD_MASTER]  --  [ESD_MASTER]

AS
BEGIN
          SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
          SET NOCOUNT ON;
			--delete [192.168.128.33].[CELL_MANAGEMENT].[dbo].[ESD_RESULT] where WorkDate = convert(date,getdate()) update 20260714
			delete [192.168.128.33].[CELL_MANAGEMENT].[dbo].[ESD_MASTER]

			-- Trung start
			DELETE [192.168.128.33].[CELL_MANAGEMENT].[dbo].[ESD_ATTENDANCE]
			WHERE WorkDate >= CONVERT(DATE, GETDATE())

			INSERT INTO [192.168.128.33].[CELL_MANAGEMENT].[dbo].[ESD_ATTENDANCE]
			(CodeEmp, WorkDate, InTime1)
			SELECT CodeEmp, CAST(WorkDate as date), InTime1
			FROM [10.92.152.40].[PVG].[dbo].[View_ThongTinChamCong_PSNV]
			WHERE CAST(WorkDate as date) >= CONVERT(DATE, GETDATE())
			AND InTime1 IS NOT NULL
			-- Trung end

			INSERT INTO [192.168.128.33].[CELL_MANAGEMENT].[dbo].[ESD_MASTER]
			(
				 [CodeEmp],[Profilename],[Line],[ESD],[Position],[Division],[Department],[Team],[Section],[IDCard],[Shift]
			)			 
			 (	
			 SELECT *
			 --,(select top(1) InTime from  [10.92.152.40].[PVG].[dbo].View_ThongTinGanCaMaster_PSNV where ShiftName = h.Shift) as InTime
			  FROM (
				SELECT 
					[CodeEmp]
					,[ProfileName]
					,LEFT(LINE, CHARINDEX('|', LINE) - 1) as Line
					,SUBSTRING(Line , LEN(Line) -  CHARINDEX('|',REVERSE(Line)) + 2  , LEN(Line))  as ESD
					,[PositionName]
					,[E_DIVISION]
					,[E_DEPARTMENT]
					,[E_TEAM]
					,[E_SECTION]     
					,[CodeAttendance]
					, (select 1) as Shift
				FROM [10.92.152.40].[PVG].[dbo].[View_ThongTinNV_PSNV] ttnv where StatusVN = N'Đang Làm Việc' and 
					SUBSTRING(Line , LEN(Line) -  CHARINDEX('|',REVERSE(Line)) + 2  , LEN(Line)) = 'Y'
					)  h
		  )
	--###########################################################################################################################
		  -- UPDATE SHIFT
--Khai báo biến @id, @title để lưu nội dung đọc
			DECLARE @CodeEmp nvarchar(20)

			DECLARE cursorProduct CURSOR FOR  -- khai báo con trỏ cursorProduct 
		
			select  CodeEmp from [192.168.128.33].[CELL_MANAGEMENT].[dbo].[ESD_MASTER]
			OPEN cursorProduct                -- Mở con trỏ
			FETCH NEXT FROM cursorProduct     -- Đọc dòng đầu tiên
			INTO @CodeEmp
			WHILE @@FETCH_STATUS = 0          --vòng lặp WHILE khi đọc Cursor thành công
			BEGIN
												--In kết quả hoặc thực hiện bất kỳ truy vấn
												--nào dựa trên kết quả đọc được
			 declare @shift_val nvarchar(100)
				if (SELECT DATENAME(dw,GETDATE())) = 'Monday' 
				set @shift_val = (select top(1) isnull(Thu2,1) from  [10.92.152.40].[PVG].[dbo].View_ThongTinGanCaData_PSNV  ganca where ganca.codeemp = @CodeEmp and CAST(DateStart as date) <= CAST(getdate() as date) and CAST(DateEnd as date)  >= CAST(getdate() as date) order by datestart desc)
				else if (SELECT DATENAME(dw,GETDATE())) = 'Tuesday' 
				set @shift_val =(select top(1) isnull(Thu3,1) from  [10.92.152.40].[PVG].[dbo].View_ThongTinGanCaData_PSNV  ganca where ganca.codeemp = @CodeEmp and CAST(DateStart as date) <= CAST(getdate() as date) and CAST(DateEnd as date)  >= CAST(getdate() as date) order by datestart desc)
				else if (SELECT DATENAME(dw,GETDATE())) = 'Wednesday' 
					begin
					set @shift_val =(select top(1) isnull(Thu4,1) from  [10.92.152.40].[PVG].[dbo].View_ThongTinGanCaData_PSNV  ganca where ganca.codeemp = @CodeEmp and CAST(DateStart as date) <= CAST(getdate() as date) and CAST(DateEnd as date)  >= CAST(getdate() as date) order by datestart desc)
					--print 'select top(1) isnull(Thu4,0) from 
					--[10.92.152.40].[PVG].[dbo].View_ThongTinGanCaData_PSNV  ganca where ganca.codeemp = '+@CodeEmp+' order by datestart desc'
					end
				else if (SELECT DATENAME(dw,GETDATE())) = 'Thursday' 
				begin
				set @shift_val =(select top(1) isnull(Thu5,1) from  [10.92.152.40].[PVG].[dbo].View_ThongTinGanCaData_PSNV  ganca where ganca.codeemp = @CodeEmp and CAST(DateStart as date) <= CAST(getdate() as date) and CAST(DateEnd as date)  >= CAST(getdate() as date) order by datestart desc)
					print 'select top(1) isnull(Thu5,0) from 
					[10.92.152.40].[PVG].[dbo].View_ThongTinGanCaData_PSNV  ganca where ganca.codeemp = '+@CodeEmp+' order by datestart desc'
				end
				else if (SELECT DATENAME(dw,GETDATE())) = 'Friday' 
				set @shift_val =(select top(1) isnull(Thu6,1) from  [10.92.152.40].[PVG].[dbo].View_ThongTinGanCaData_PSNV  ganca where ganca.codeemp = @CodeEmp and CAST(DateStart as date) <= CAST(getdate() as date) and CAST(DateEnd as date)  >= CAST(getdate() as date) order by datestart desc)
				else if (SELECT DATENAME(dw,GETDATE())) = 'Saturday' 
				set @shift_val =(select top(1) isnull(Thu7,1) from  [10.92.152.40].[PVG].[dbo].View_ThongTinGanCaData_PSNV  ganca where ganca.codeemp = @CodeEmp and CAST(DateStart as date) <= CAST(getdate() as date) and CAST(DateEnd as date)  >= CAST(getdate() as date) order by datestart desc)
				else if (SELECT DATENAME(dw,GETDATE())) = 'Sunday' 
				set @shift_val =(select top(1) isnull(ChuNhat,1) from  [10.92.152.40].[PVG].[dbo].View_ThongTinGanCaData_PSNV  ganca where ganca.codeemp = @CodeEmp and CAST(DateStart as date) <= CAST(getdate() as date) and CAST(DateEnd as date)  >= CAST(getdate() as date) order by datestart desc)
				else
				set @shift_val = (select 0)
				--print @shift_val


				--phong add
			declare @starttime nvarchar(40),@mealtime nvarchar(40)

				SET @starttime = (SELECT TRY_CAST(
					CONVERT(Varchar(10), (select convert(varchar, GETDATE(), 23)), 112) + ' ' +   
					CONVERT(Varchar(8), (SELECT DATEADD(HH, 0, (SELECT [StartTime] 
					FROM [192.168.128.33].[CELL_MANAGEMENT].[dbo].[ESD_MEALTIME] 
					where [Shift]= @shift_val AND Department IS NULL)))) 
				AS DateTime)) --update 20260715 fix phan ca null
				
				SET @mealtime = (SELECT TRY_CAST(
					CONVERT(Varchar(10), (select convert(varchar, (SELECT DATEADD(DAY, 
					(SELECT [PlusDayForMealTime] FROM [192.168.128.33].[CELL_MANAGEMENT].[dbo].[ESD_MEALTIME] 
					where [Shift]=@shift_val AND Department IS NULL), GETDATE())), 23)), 112) + ' ' +   
					CONVERT(Varchar(8), (SELECT DATEADD(HH, 0, (SELECT [MealTime] 
					FROM [192.168.128.33].[CELL_MANAGEMENT].[dbo].[ESD_MEALTIME] 
					where [Shift]= @shift_val AND Department IS NULL)))) 
				AS DateTime)) --update 20260715 fix phan ca null
				--end
			update [192.168.128.33].[CELL_MANAGEMENT].[dbo].[ESD_MASTER]
			set [Shift] = @shift_val,[StartTime]=@starttime,[MealTime]=@mealtime
			where CodeEmp = @CodeEmp

			--print('
			--update [10.92.184.30].[CELL_MANAGEMENT].[dbo].[ESD_MASTER]
			--set [Shift] = '+@shift_val+'
			--where CodeEmp = '+@CodeEmp+'
			--')


			FETCH NEXT FROM cursorProduct -- Đọc dòng tiếp
					  INTO @CodeEmp
			END
			CLOSE cursorProduct              -- Đóng Cursor
			DEALLOCATE cursorProduct         -- Giải phóng tài nguyên

			delete [192.168.128.33].[CELL_MANAGEMENT].[dbo].[ESD_MASTER] where [Shift] = '1'
			delete [192.168.128.33].[CELL_MANAGEMENT].[dbo].[ESD_MASTER] where [Shift] = 'ML'

			-- insert master history
			IF NOT EXISTS(SELECT TOP(1) 1 FROM [192.168.128.33].[CELL_MANAGEMENT].[dbo].ESD_MASTER_HISTORY WHERE WORK_DATE = CONVERT(DATE,GETDATE()))
			BEGIN
				INSERT INTO [192.168.128.33].[CELL_MANAGEMENT].[dbo].ESD_MASTER_HISTORY(
					[CodeEmp],[Profilename],[Position],[Line],[ESD],[Division],[Department],[Team],[Section],[IDCard],[Shift],[InTime],[Insert_DT],[Final_Judge],[StartTime],[MealTime]
				)
				SELECT 
					[CodeEmp],[Profilename],[Position],[Line],[ESD],[Division],[Department],[Team],[Section],[IDCard],[Shift],[InTime],[Insert_DT],[Final_Judge],[StartTime],[MealTime]
				FROM [192.168.128.33].[CELL_MANAGEMENT].[dbo].ESD_MASTER
				PRINT('INSERT OK')
			END
			ELSE
			PRINT('DA CO BAN GHI')

			-- Gọi ESD_JOB_JUDGE ngay sau khi reset xong
			-- EXEC [192.168.128.33].[CELL_MANAGEMENT].[dbo].[ESD_JOB_JUDGE]
END

USE [CELL_MANAGEMENT]
GO
/****** Object:  StoredProcedure [dbo].[ESD_JOB_JUDGE]    Script Date: 11/05/2026 5:05:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ============================================================================
   3. ESD_JOB_JUDGE

   SUA:
   (a) Bo  AND AM IS NULL  o nhanh NG lan 1.
       Dieu kien nay lam gio quet hien thi bi dong bang o lan judge DAU TIEN:
       mot khi AM da co gia tri thi khong bao gio duoc cap nhat lai, nen gio
       quet cuoi cung trong ngay khong bao gio len man hinh.
   (b) Bo  AND [PM] IS NULL  o nhanh NG lan 2, cung ly do.
   (c) Nhanh OK ca hai lan: them UPDATE ESD_MASTER SET FINAL_JUDGE='OK'.
       Ban cu khong co, nen nguoi da OK van bi cursor quet lai moi lan chay -
       cursor khong bao gio nho di. ESD_JOB_JUDGE_BYDAY von da lam dung cho nay.
   (d) Them khoi khoi phuc confirm o cuoi (lop bao ve thu hai, phong truong hop
       ESD_MASTER_HISTORY bi dung lai hoac thieu ban ghi cho ngay do).
============================================================================ */

ALTER PROCEDURE [dbo].[ESD_JOB_JUDGE]
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
        FROM ESD_MASTER(NOLOCK)
        WHERE FINAL_JUDGE = 'NG'
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

    SET @DATE_SCAN = CONVERT(DATE, GETDATE())
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
          AND (MT.Department = (SELECT TOP 1 Department FROM ESD_MASTER WHERE CodeEmp = @CodeEmp)
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

        -- Lan 1: StartTime +/- 1h (PASS only)
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

        -- TIME_CHECK lan 1 fallback: gio cuoi cung truoc MealTimeStart trong ngay StartTime
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

        -- Lan 2: MealTime_Start -> MealTime_End (PASS only)
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

        -- TIME_CHECK_MEALTIME lan 2 fallback
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
                UPDATE ESD_MASTER SET FINAL_JUDGE = 'NG' WHERE CodeEmp = @CodeEmp
            END
            ELSE
            BEGIN
                IF @RETURN_DT_SCAN_MEALTIME IS NOT NULL
                BEGIN
                    UPDATE [CELL_MANAGEMENT].[dbo].[ESD_RESULT]
                    SET [AM] = @RETURN_DT_SCAN, [ResultAM] = 'OK',
                        [PM] = @RETURN_DT_SCAN_MEALTIME, [ResultPM] = 'OK', [FinalResult] = 'OK'
                    WHERE EmpCode = @CodeEmp AND WorkDate = convert(date, @StartTime)

                    -- (c) THEM MOI: danh dau da xong de cursor khong quet lai moi lan chay.
                    --     ESD_JOB_JUDGE_BYDAY von da co cau tuong duong.
                    UPDATE ESD_MASTER SET FINAL_JUDGE = 'OK' WHERE CodeEmp = @CodeEmp
                END
                ELSE
                BEGIN
                    UPDATE [CELL_MANAGEMENT].[dbo].[ESD_RESULT]
                    SET [AM] = @RETURN_DT_SCAN, [ResultAM] = 'OK',
                        [PM] = @TIME_CHECK_MEALTIME, [ResultPM] = 'NG', [FinalResult] = 'NG'
                    WHERE EmpCode = @CodeEmp AND IDCard = @IDCard
                    AND WorkDate = convert(date, @StartTime)
                    -- (b) DA BO:  AND [PM] IS NULL
                    UPDATE ESD_MASTER SET FINAL_JUDGE = 'NG' WHERE CodeEmp = @CodeEmp
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
                -- (a) DA BO:  AND AM IS NULL
            END
        END

        FETCH NEXT FROM cursorProduct
            INTO @CodeEmp, @IDCard, @Shift, @InTime, @StartTime, @MealTime
    END

    CLOSE cursorProduct
    DEALLOCATE cursorProduct

    /* (d) KHOI PHUC CONFIRM - lop bao ve thu hai.
       Lop thu nhat la Final_Judge='OK' lam cursor bo qua. Cau nay danh cho
       truong hop ban ghi ESD_MASTER / ESD_MASTER_HISTORY bi dung lai hoac
       khong co dong cho ngay do. Gioi han 2 ngay gan day cho nhe. */
    UPDATE R
    SET R.ResultAM = 'OK', R.ResultPM = 'OK', R.FinalResult = 'OK'
    FROM [CELL_MANAGEMENT].[dbo].[ESD_RESULT] R
    WHERE CAST(R.WorkDate AS date) >= CAST(DATEADD(DAY, -2, GETDATE()) AS date)
      AND EXISTS (
            SELECT 1 FROM [CELL_MANAGEMENT].[dbo].[ESD_HISTORYCONFIRM] C
            WHERE C.UserID = R.EmpCode
              AND C.WorkDate = CAST(R.WorkDate AS date)
      )

    DECLARE @currentHour INT = DATEPART(HOUR, GETDATE());
    DECLARE @DATE_SCAN_MINUS_A_DAY NVARCHAR(12)
    SET @DATE_SCAN_MINUS_A_DAY = CONVERT(DATE, DATEADD(DAY, -1, GETDATE()));
    IF @currentHour BETWEEN 8 AND 12
    BEGIN
        EXEC ESD_JOB_JUDGE_BYDAY @DATE_SCAN_MINUS_A_DAY;
    END
END

