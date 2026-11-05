USE CELL_MANAGEMENT;

-- 0. Kiểm tra trước
SELECT WORK_DATE, Final_Judge, COUNT(*) AS so_nguoi
FROM ESD_MASTER_HISTORY
WHERE WORK_DATE IN ('2026-11-01','2026-11-02')
GROUP BY WORK_DATE, Final_Judge;
-- Nếu Final_Judge là NULL (không phải 'NG') thì DỪNG, báo lại tôi.

SELECT WorkDate, FinalResult, COUNT(*) AS so_dong
FROM ESD_RESULT
WHERE WorkDate IN ('2026-11-01','2026-11-02')
GROUP BY WorkDate, FinalResult;

-- 1. Sao lưu
SELECT * INTO ESD_RESULT_BAK_20261105
FROM ESD_RESULT WHERE WorkDate IN ('2026-11-01','2026-11-02');
SELECT * INTO ESD_MASTER_HISTORY_BAK_20261105
FROM ESD_MASTER_HISTORY WHERE WORK_DATE IN ('2026-11-01','2026-11-02');

-- 2. Chạy lại (mỗi ngày 2 lần, xem điểm 2 ở trên)
BEGIN TRAN;
    EXEC dbo.ESD_JOB_JUDGE_BYDAY '2026-11-01';
    EXEC dbo.ESD_JOB_JUDGE_BYDAY '2026-11-01';
    EXEC dbo.ESD_JOB_JUDGE_BYDAY '2026-11-02';
    EXEC dbo.ESD_JOB_JUDGE_BYDAY '2026-11-02';

    -- 3. Xem kết quả trước khi chốt
    SELECT WorkDate, FinalResult, COUNT(*) AS so_dong
    FROM ESD_RESULT
    WHERE WorkDate IN ('2026-11-01','2026-11-02')
    GROUP BY WorkDate, FinalResult;
-- Ổn thì: COMMIT;   Không ổn thì: ROLLBACK;
