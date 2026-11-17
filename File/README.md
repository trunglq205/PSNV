/* =====================================================================
   CLONE  SWMS_FINISH_GOODS  ->  SWMS_FINISH_GOODS_DEV
   Cùng một SQL Server instance · soạn 17/11/2026

   Cách làm: BACKUP COPY_ONLY của DB thật, rồi RESTORE WITH REPLACE +
   MOVE sang file riêng của DB DEV. Chép đầy đủ và nhất quán tại một
   thời điểm: dữ liệu, index, identity, FK, trigger, view, function,
   stored procedure, user trong DB.

   ⚠ KHÔNG dùng `DBCC CLONEDATABASE` — nó chỉ chép schema + statistics,
     KHÔNG chép một dòng dữ liệu nào.

   ─── CÁCH CHẠY ───────────────────────────────────────────────────────
   Mở SSMS, kết nối instance, chạy trong context [master].
   Chạy Mục 0 → 1, ĐỌC kết quả Mục 1 (dung lượng), rồi chạy tiếp 2 → 6.
   Mục 5 mặc định @WhatIf = 1 (chỉ in). Đọc xong đổi thành 0, chạy lại
   RIÊNG Mục 5.

   Quyền cần: sysadmin (hoặc dbcreator + quyền ghi thư mục backup).
   Thời gian: DB vài chục GB thì backup + restore khoảng 5–20 phút.
   ===================================================================== */

USE [master];
SET NOCOUNT ON;
GO

/* =====================================================================
   MỤC 0 — THAM SỐ (đã điền sẵn, không cần sửa)
   ===================================================================== */
DECLARE @ProdDb sysname = N'SWMS_FINISH_GOODS';
DECLARE @DevDb  sysname = N'SWMS_FINISH_GOODS_DEV';

/* Thư mục backup và thư mục data: tự đọc cấu hình của instance, nên
   không phải gõ đường dẫn. Muốn chỉ định tay thì gán thẳng vào hai biến
   dưới, vd N'D:\SqlBackup\' (NHỚ dấu \ ở cuối).                        */
DECLARE @BackupDir nvarchar(400) = NULL;
DECLARE @DataDir   nvarchar(400) = NULL;

IF @BackupDir IS NULL
BEGIN
    EXEC master.dbo.xp_instance_regread
         N'HKEY_LOCAL_MACHINE',
         N'Software\Microsoft\MSSQLServer\MSSQLServer',
         N'BackupDirectory', @BackupDir OUTPUT;
END

IF @DataDir IS NULL
    SET @DataDir = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS nvarchar(400));

/* Chuẩn hoá: thiếu dấu \ cuối là đường dẫn dính liền tên file. */
IF RIGHT(ISNULL(@BackupDir, N''), 1) <> N'\' SET @BackupDir = @BackupDir + N'\';
IF RIGHT(ISNULL(@DataDir,   N''), 1) <> N'\' SET @DataDir   = @DataDir   + N'\';

/* ── Ba chốt an toàn ──────────────────────────────────────────────────
   Câu RESTORE ... WITH REPLACE ghi đè KHÔNG HỎI LẠI. Một lần gõ nhầm
   tên vào ô đích là mất DB thật, nên chặn bằng code chứ không bằng
   cẩn thận.                                                            */
IF @DevDb = @ProdDb
BEGIN
    RAISERROR(N'DỪNG: DB nguồn và DB đích trùng tên.', 16, 1); RETURN;
END

IF LOWER(@DevDb) NOT LIKE N'%dev%' AND LOWER(@DevDb) NOT LIKE N'%test%'
BEGIN
    RAISERROR(N'DỪNG: tên DB đích "%s" không chứa "dev" hay "test".', 16, 1, @DevDb);
    RETURN;
END

IF DB_ID(@ProdDb) IS NULL
BEGIN
    RAISERROR(N'DỪNG: không thấy DB nguồn "%s" trên instance này.', 16, 1, @ProdDb);
    RETURN;
END

IF @BackupDir IS NULL OR @DataDir IS NULL
BEGIN
    RAISERROR(N'DỪNG: không đọc được thư mục backup/data của instance. Gán tay ở Mục 0.', 16, 1);
    RETURN;
END

/* Tham số sang bảng tạm: biến DECLARE chỉ sống trong MỘT batch, mà các
   mục sau đều nằm sau GO.                                              */
IF OBJECT_ID('tempdb..#p') IS NOT NULL DROP TABLE #p;
CREATE TABLE #p (ProdDb sysname, DevDb sysname,
                 BackupDir nvarchar(400), DataDir nvarchar(400),
                 BakFile nvarchar(600) NULL);
INSERT INTO #p (ProdDb, DevDb, BackupDir, DataDir)
VALUES (@ProdDb, @DevDb, @BackupDir, @DataDir);

PRINT N'Nguồn      : ' + @ProdDb;
PRINT N'Đích       : ' + @DevDb
      + CASE WHEN DB_ID(@DevDb) IS NULL
             THEN N'   (chưa có -> RESTORE sẽ tạo mới)'
             ELSE N'   (ĐÃ CÓ -> sẽ bị GHI ĐÈ HOÀN TOÀN)' END;
PRINT N'Backup vào : ' + @BackupDir;
PRINT N'File DB DEV: ' + @DataDir;
GO

/* =====================================================================
   MỤC 1 — DUNG LƯỢNG CẦN CHỖ (chỉ đọc)
   ===================================================================== */
DECLARE @ProdDb sysname = (SELECT ProdDb FROM #p);

SELECT  logical_name = mf.name,
        loai         = mf.type_desc,
        co_file_mb   = CAST(mf.size * 8.0 / 1024 AS decimal(18,1)),
        duong_dan    = mf.physical_name
FROM    sys.master_files mf
WHERE   mf.database_id = DB_ID(@ProdDb)
ORDER BY mf.type, mf.file_id;

SELECT  tong_co_file_mb = CAST(SUM(mf.size) * 8.0 / 1024 AS decimal(18,1)),
        ghi_chu = N'Cần chỗ trống >= con số này cho DB DEV, CỘNG thêm chỗ cho file .bak'
FROM    sys.master_files mf
WHERE   mf.database_id = DB_ID(@ProdDb);
GO

/* =====================================================================
   MỤC 2 — BACKUP DB THẬT (COPY_ONLY)
   ===================================================================== */
DECLARE @ProdDb    sysname       = (SELECT ProdDb    FROM #p);
DECLARE @BackupDir nvarchar(400) = (SELECT BackupDir FROM #p);
DECLARE @Bak nvarchar(600) =
        @BackupDir + @ProdDb + N'_to_DEV_'
        + CONVERT(char(8), GETDATE(), 112) + N'_'
        + REPLACE(CONVERT(char(8), GETDATE(), 108), ':', N'') + N'.bak';

/* COPY_ONLY: KHÔNG cắt chuỗi backup của DB thật.
   Thiếu nó thì bản full này thành mắt mới của chuỗi, và mọi bản
   differential / log sau đó phụ thuộc vào ĐÚNG FILE NÀY — mất file là
   không restore DB thật được nữa.

   CHECKSUM + RESTORE VERIFYONLY: bắt lỗi I/O ngay bây giờ, chứ không để
   phát hiện lúc restore. */
BACKUP DATABASE @ProdDb TO DISK = @Bak
WITH COPY_ONLY, INIT, COMPRESSION, CHECKSUM, STATS = 10,
     NAME = N'SWMS clone -> DEV';

RESTORE VERIFYONLY FROM DISK = @Bak WITH CHECKSUM;

UPDATE #p SET BakFile = @Bak;
PRINT N'Đã backup xong: ' + @Bak;
GO

/* =====================================================================
   MỤC 3 — RESTORE SANG SWMS_FINISH_GOODS_DEV
   ===================================================================== */
DECLARE @ProdDb  sysname       = (SELECT ProdDb  FROM #p);
DECLARE @DevDb   sysname       = (SELECT DevDb   FROM #p);
DECLARE @Bak     nvarchar(600) = (SELECT BakFile FROM #p);
DECLARE @DataDir nvarchar(400) = (SELECT DataDir FROM #p);
DECLARE @sql     nvarchar(max);

IF @Bak IS NULL
BEGIN
    RAISERROR(N'DỪNG: chưa chạy Mục 2, không có file backup.', 16, 1); RETURN;
END

/* Dựng mệnh đề MOVE từ sys.master_files của DB nguồn.

   Vì sao không dùng `RESTORE FILELISTONLY`: số cột nó trả về khác nhau
   giữa các bản SQL Server, nên bảng tạm để hứng sẽ vỡ trên bản khác.
   Nguồn và đích cùng một instance nên đọc sys.master_files là đủ và
   luôn đúng.

   Thiếu MOVE là RESTORE đòi ghi vào ĐÚNG FILE của DB thật. */
/* Chốt: script chỉ đặt tên .mdf/.ldf, nên gặp file loại khác
   (FILESTREAM / FULLTEXT — type 2, 4) là DỪNG thay vì dựng câu RESTORE
   sai rồi để SQL Server báo lỗi nửa đường. */
IF EXISTS (SELECT 1 FROM sys.master_files
           WHERE database_id = DB_ID(@ProdDb) AND type NOT IN (0, 1))
BEGIN
    SELECT loai_file_khong_ho_tro = type_desc, logical_name = name, physical_name
    FROM   sys.master_files
    WHERE  database_id = DB_ID(@ProdDb) AND type NOT IN (0, 1);
    RAISERROR(N'DỪNG: DB nguồn có file không phải ROWS/LOG. Phải viết mệnh đề MOVE tay cho các file đó.', 16, 1);
    RETURN;
END

DECLARE @move nvarchar(max) = N'';
SELECT  @move = @move + N'    MOVE ' + QUOTENAME(mf.name, '''') + N' TO '
              + QUOTENAME(@DataDir + @DevDb + N'_' + CAST(mf.file_id AS nvarchar(10))
                          + CASE mf.type WHEN 1 THEN N'.ldf' ELSE N'.mdf' END, '''')
              + N',' + CHAR(13) + CHAR(10)
FROM    sys.master_files mf
WHERE   mf.database_id = DB_ID(@ProdDb)
ORDER BY mf.file_id;

/* DB DEV đang có thì phải chiếm độc quyền: một kết nối đang mở (kể cả
   một tab SSMS của chính mình đang chọn DB đó) là RESTORE chờ vô hạn.  */
IF DB_ID(@DevDb) IS NOT NULL
BEGIN
    SET @sql = N'ALTER DATABASE ' + QUOTENAME(@DevDb)
             + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE;';
    PRINT @sql;
    EXEC(@sql);
END

SET @sql = N'RESTORE DATABASE ' + QUOTENAME(@DevDb) + N' FROM DISK = '
         + QUOTENAME(@Bak, '''') + N' WITH' + CHAR(13) + CHAR(10)
         + @move
         + N'    REPLACE, RECOVERY, STATS = 10;';
PRINT @sql;
EXEC(@sql);

SET @sql = N'ALTER DATABASE ' + QUOTENAME(@DevDb) + N' SET MULTI_USER;';
EXEC(@sql);

PRINT N'Đã restore sang ' + @DevDb;
GO

/* =====================================================================
   MỤC 4 — DỌN SAU RESTORE
   ===================================================================== */
DECLARE @DevDb sysname = (SELECT DevDb FROM #p);
DECLARE @sql nvarchar(max);

/* 4.1 RECOVERY SIMPLE — DB dev không có ai backup log, để FULL là file
       log phình mãi không ai cắt. */
SET @sql = N'ALTER DATABASE ' + QUOTENAME(@DevDb) + N' SET RECOVERY SIMPLE;';
EXEC(@sql);
PRINT N'4.1 recovery = SIMPLE';

/* 4.2 OWNER — DB vừa restore thuộc về người chạy câu RESTORE. Đặt về sa
       để không phụ thuộc một tài khoản người thật (người đó nghỉ việc là
       DB mất owner). */
BEGIN TRY
    SET @sql = N'ALTER AUTHORIZATION ON DATABASE::' + QUOTENAME(@DevDb) + N' TO [sa];';
    EXEC(@sql);
    PRINT N'4.2 owner = sa';
END TRY
BEGIN CATCH
    PRINT N'4.2 (bỏ qua) không đổi được owner: ' + ERROR_MESSAGE();
END CATCH

/* 4.3 USER MỒ CÔI — user trong DB giữ SID của login. Cùng instance thì
       thường khớp, nhưng nếu app dùng SQL login riêng cho dev thì đây
       đúng là chỗ làm app dev không đăng nhập được vào DB. */
SET @sql = N'
SELECT  user_mo_coi = dp.name, loai = dp.type_desc,
        cach_sua = N''ALTER USER '' + QUOTENAME(dp.name) + N'' WITH LOGIN = [<login>];''
FROM    ' + QUOTENAME(@DevDb) + N'.sys.database_principals dp
LEFT JOIN sys.server_principals sp ON sp.sid = dp.sid
WHERE   dp.type IN (''S'',''U'',''G'')
  AND   dp.sid IS NOT NULL
  AND   dp.authentication_type <> 0
  AND   dp.name NOT IN (''dbo'',''guest'',''INFORMATION_SCHEMA'',''sys'')
  AND   sp.sid IS NULL;';
EXEC(@sql);
PRINT N'4.3 không có dòng nào ở trên = không có user mồ côi';
GO

/* =====================================================================
   MỤC 5 — DỌN DỮ LIỆU NHẠY CẢM TRÊN DB DEV     ⚠ MỤC QUAN TRỌNG NHẤT
   ---------------------------------------------------------------------
   Dữ liệu vừa chép là DỮ LIỆU THẬT. Chưa dọn mà bật app dev lên thì:
     • MAIL BAY TỚI NGƯỜI THẬT — app gửi thư ở ba sự kiện (tạo chỉ thị
       return, chốt thực nhận, quản lý FA duyệt). Bấm thử một lượt trên
       dev là FA / SCS Office nhận thư, không ai biết đó là thử.
     • API KEY THẬT vẫn hiệu lực trên dev.
     • JOB ĐỒNG BỘ HD soft chạy tiếp từ MỐC của hệ thật.

   ⚠ Lưu ý đọc code: `master.` ở đây là SCHEMA master TRONG DB DEV
   (master.email_config, master.configs…), KHÔNG phải system database
   [master]. Hai thứ trùng tên nhưng khác nhau.

   Đổi @WhatIf = 0 rồi chạy lại RIÊNG mục này để ghi thật.
   ===================================================================== */
DECLARE @WhatIf bit = 1;          -- << ĐỔI THÀNH 0 ĐỂ CHẠY THẬT
DECLARE @DevDb sysname = (SELECT DevDb FROM #p);
DECLARE @sql nvarchar(max);

IF @WhatIf = 1
    PRINT N'===== @WhatIf = 1 : CHỈ IN RA, KHÔNG GHI GÌ =====';

SET @sql = N'
USE ' + QUOTENAME(@DevDb) + N';
DECLARE @WhatIf bit = ' + CAST(@WhatIf AS nvarchar(1)) + N';

/* 5.1 TẮT TOÀN BỘ NGƯỜI NHẬN MAIL */
IF COL_LENGTH(''master.email_config'', ''is_active'') IS NOT NULL
BEGIN
    IF @WhatIf = 1
        SELECT buoc = ''5.1 tat mail'', so_dong_dang_bat = COUNT(*)
        FROM master.email_config WHERE is_active = 1;
    ELSE
    BEGIN
        UPDATE master.email_config SET is_active = 0 WHERE is_active = 1;
        PRINT ''5.1 da tat '' + CAST(@@ROWCOUNT AS varchar(10)) + '' dong email_config'';
    END
END
ELSE
    PRINT ''5.1 BO QUA: khong thay cot master.email_config.is_active - kiem tay'';

/* 5.2 VÔ HIỆU API KEY — tắt CẢ HAI cờ: ApiKeyRepository xác thực bằng
       is_deleted = 0 AND is_active = 1, tắt một cờ là vẫn lọt. */
IF OBJECT_ID(''master.api_keys'') IS NOT NULL
BEGIN
    IF @WhatIf = 1
        SELECT buoc = ''5.2 vo hieu api key'', so_dong_con_hieu_luc = COUNT(*)
        FROM master.api_keys WHERE is_deleted = 0;
    ELSE
    BEGIN
        UPDATE master.api_keys SET is_active = 0, is_deleted = 1 WHERE is_deleted = 0;
        PRINT ''5.2 da vo hieu '' + CAST(@@ROWCOUNT AS varchar(10)) + '' api key'';
    END
END

/* 5.3 XOÁ MỐC ĐỒNG BỘ HD soft (master.configs, dạng config_key/value).
       Xoá MỀM: SyncStateRepository đọc WHERE is_deleted = 0, nên xoá mềm
       là job coi như chưa có mốc. */
IF OBJECT_ID(''master.configs'') IS NOT NULL
BEGIN
    IF @WhatIf = 1
        SELECT buoc = ''5.3 moc dong bo'', config_key, config_value
        FROM master.configs
        WHERE is_deleted = 0
          AND (config_key LIKE ''%sync%'' OR config_key LIKE ''%hdsoft%''
               OR config_key LIKE ''%watermark%'');
    ELSE
    BEGIN
        UPDATE master.configs SET is_deleted = 1
        WHERE is_deleted = 0
          AND (config_key LIKE ''%sync%'' OR config_key LIKE ''%hdsoft%''
               OR config_key LIKE ''%watermark%'');
        PRINT ''5.3 da xoa mem '' + CAST(@@ROWCOUNT AS varchar(10)) + '' moc dong bo'';
    END
END

/* 5.4 PHIÊN BẢN PDA — bảng này quyết định máy PDA tự cập nhật lên APK
       nào. Giữ bản của hệ thật thì máy đang test bị kéo về APK prod.
       CHỈ IN, tự quyết vì tuỳ cách anh phát hành APK. */
IF OBJECT_ID(''master.pda_app_versions'') IS NOT NULL
    SELECT buoc = ''5.4 TU KIEM'', * FROM master.pda_app_versions;
';
EXEC sp_executesql @sql;
GO

/* =====================================================================
   MỤC 6 — ĐỐI CHIẾU HAI DB (chỉ đọc)
   ---------------------------------------------------------------------
   So số dòng từng bảng. Cột `lech` khác 0 nghĩa là restore chưa xong,
   hoặc DB DEV không phải vừa restore từ bản backup này.
   ===================================================================== */
DECLARE @ProdDb sysname = (SELECT ProdDb FROM #p);
DECLARE @DevDb  sysname = (SELECT DevDb  FROM #p);
DECLARE @sql nvarchar(max) = N'
SELECT  bang      = p.sch + ''.'' + p.tbl,
        dong_prod = p.row_count,
        dong_dev  = ISNULL(d.row_count, -1),
        lech      = p.row_count - ISNULL(d.row_count, -1)
FROM (
    SELECT s.name AS sch, t.name AS tbl, SUM(ps.row_count) AS row_count
    FROM ' + QUOTENAME(@ProdDb) + N'.sys.tables t
    JOIN ' + QUOTENAME(@ProdDb) + N'.sys.schemas s ON s.schema_id = t.schema_id
    JOIN ' + QUOTENAME(@ProdDb) + N'.sys.dm_db_partition_stats ps
         ON ps.object_id = t.object_id AND ps.index_id IN (0,1)
    GROUP BY s.name, t.name
) p
LEFT JOIN (
    SELECT s.name AS sch, t.name AS tbl, SUM(ps.row_count) AS row_count
    FROM ' + QUOTENAME(@DevDb) + N'.sys.tables t
    JOIN ' + QUOTENAME(@DevDb) + N'.sys.schemas s ON s.schema_id = t.schema_id
    JOIN ' + QUOTENAME(@DevDb) + N'.sys.dm_db_partition_stats ps
         ON ps.object_id = t.object_id AND ps.index_id IN (0,1)
    GROUP BY s.name, t.name
) d ON d.sch = p.sch AND d.tbl = p.tbl
WHERE p.row_count > 0
ORDER BY ABS(p.row_count - ISNULL(d.row_count, -1)) DESC, p.row_count DESC;';
EXEC sp_executesql @sql;

PRINT N'';
PRINT N'===== CÒN LẠI, LÀM NGOÀI SQL =====';
PRINT N'1. appsettings.json của API dev: ConnectionString -> SWMS_FINISH_GOODS_DEV.';
PRINT N'2. Cấu hình HD soft / Foss của API dev PHẢI trỏ hệ dev.';
PRINT N'   Trỏ hệ thật thì job đồng bộ GHI vị trí pallet vào hệ thật —';
PRINT N'   rủi ro này lớn hơn cả chuyện mail.';
PRINT N'3. SMTP của API dev: trỏ hộp thư nháp, đừng trỏ SMTP công ty.';
PRINT N'4. Xoá file .bak sau khi xong — nó là bản sao đầy đủ dữ liệu thật.';
PRINT N'5. Lần clone sau chỉ cần chạy lại file này; Mục 3 tự ghi đè DB dev.';
GO
