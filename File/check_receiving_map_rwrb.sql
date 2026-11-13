-- 1. WORK có còn dòng nào mang SafetyStock không?
SELECT COUNT(*) AS Tong,
       SUM(CASE WHEN SafetyStock IS NULL THEN 1 ELSE 0 END) AS SoDong_NULL
FROM ZFMA0037_WORK WHERE DataSource = 0;

-- 2. EndValidDate hiện tại
SELECT EndValidDate, IsOverride, OverrideEndValidDate FROM NumberColumnShow WHERE DataSource = 0;
