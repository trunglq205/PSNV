/* =====================================================================
   ShippingSCS (Auto Shipment) - 001 M1 Hệ thống chung
   SQL Server, schema dbo. Tên bảng/cột PascalCase trùng property C#
   để Dapper tự map, không cần alias.
   Chạy lại được (kiểm tra tồn tại trước khi tạo).

   Tài khoản admin đầu tiên KHÔNG tạo ở đây: app tự tạo lúc khởi động
   nếu bảng Users trống (xem SeedAdmin trong appsettings.json).
   ===================================================================== */

SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ---------------------------------------------------------------------
   Users
   Role: Admin (quản lý user, master, lịch) | PIC (import, chạy lịch, sửa lô)
         | Viewer (chỉ xem báo cáo)
   PicCode: tên PIC như trong file Excel (N.LINH, X.DUNG...). Master vessel
   nối về đây. PicKey là PicCode đã bỏ khoảng trắng và dấu chấm, viết hoa,
   nên "X DUNG", "X.DUNG", "x.dung" là cùng một người.
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Users (
        Id           int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
        UserName     nvarchar(50)  NOT NULL,
        FullName     nvarchar(100) NOT NULL,
        Email        nvarchar(200) NULL,
        PicCode      nvarchar(30)  NULL,
        PicKey       AS UPPER(REPLACE(REPLACE(PicCode, N' ', N''), N'.', N'')) PERSISTED,
        Role         varchar(20)   NOT NULL CONSTRAINT CK_Users_Role CHECK (Role IN ('Admin', 'PIC', 'Viewer')),
        PasswordHash nvarchar(500) NOT NULL,
        IsActive     bit           NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT (1),
        CreatedAt    datetime2(0)  NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (SYSDATETIME()),
        UpdatedAt    datetime2(0)  NULL
    );

    CREATE UNIQUE INDEX UX_Users_UserName ON dbo.Users (UserName);
    CREATE UNIQUE INDEX UX_Users_PicKey   ON dbo.Users (PicKey) WHERE PicCode IS NOT NULL;
END
GO

/* ---------------------------------------------------------------------
   ChangeLogs - nhật ký thay đổi
   Note: câu cho người đọc. Payload: JSON cho máy đọc, ví dụ
   {"field":"EtdPort","old":"2026-07-25","new":"2026-07-18","reason":"VesselAllocation"}
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.ChangeLogs', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ChangeLogs (
        Id         bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_ChangeLogs PRIMARY KEY,
        EntityType varchar(30)   NOT NULL,   -- User, Calendar, Shipment, ImportBatch, MasterModel...
        EntityKey  nvarchar(100) NULL,       -- số SI, model, ngày... để tra nhanh
        Action     varchar(30)   NOT NULL,   -- Create, Update, Delete, Import, RunSchedule...
        Note       nvarchar(500) NULL,
        Payload    nvarchar(max) NULL CONSTRAINT CK_ChangeLogs_Payload CHECK (Payload IS NULL OR ISJSON(Payload) = 1),
        UserId     int           NULL CONSTRAINT FK_ChangeLogs_User REFERENCES dbo.Users(Id),
        CreatedAt  datetime2(0)  NOT NULL CONSTRAINT DF_ChangeLogs_CreatedAt DEFAULT (SYSDATETIME())
    );

    CREATE INDEX IX_ChangeLogs_Entity    ON dbo.ChangeLogs (EntityType, EntityKey, CreatedAt DESC);
    CREATE INDEX IX_ChangeLogs_CreatedAt ON dbo.ChangeLogs (CreatedAt DESC);
END
GO

/* ---------------------------------------------------------------------
   Lịch làm việc
   VP = văn phòng (mặc định), KHO_<vanning place> = lịch từng kho.
   Văn phòng và kho có ngày nghỉ khác nhau.
   Rule Long FC ("ngày làm việc thứ 5") và Ex-factory AIR ("ETD - 1 ngày
   làm việc") đọc bảng này. Ngày chưa có dòng = chưa cấu hình -> app báo lỗi.
   DayType: Workday | Weekend | Holiday | ExtraWorkday (ngày nghỉ nhưng đi làm bù)
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.WorkingCalendars', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.WorkingCalendars (
        Code      varchar(20)   NOT NULL CONSTRAINT PK_WorkingCalendars PRIMARY KEY,
        Name      nvarchar(100) NOT NULL,
        IsDefault bit           NOT NULL CONSTRAINT DF_WorkingCalendars_IsDefault DEFAULT (0)
    );

    CREATE UNIQUE INDEX UX_WorkingCalendars_Default ON dbo.WorkingCalendars (IsDefault) WHERE IsDefault = 1;
END
GO

IF OBJECT_ID(N'dbo.WorkingDays', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.WorkingDays (
        CalendarCode varchar(20)   NOT NULL CONSTRAINT FK_WorkingDays_Calendar REFERENCES dbo.WorkingCalendars(Code),
        [Date]       date          NOT NULL,
        IsWorking    bit           NOT NULL,
        DayType      varchar(20)   NOT NULL,
        Note         nvarchar(200) NULL,
        CONSTRAINT PK_WorkingDays PRIMARY KEY (CalendarCode, [Date]),
        CONSTRAINT CK_WorkingDays_DayType CHECK (
            (IsWorking = 1 AND DayType IN ('Workday', 'ExtraWorkday'))
         OR (IsWorking = 0 AND DayType IN ('Weekend', 'Holiday'))
        )
    );
END
GO

-- Lịch mẫu theo bộ phận: VP (văn phòng, mặc định) + lịch từng kho (chọn theo vanning place).
-- Sinh ngày cho từng năm ở màn hình Lịch làm việc (Sinh lịch năm / Import Excel).
-- VP chỉ là mặc định khi DB chưa có lịch mặc định nào (chạy lại trên DB cũ không lỗi).
-- DB cũ còn PSNV/JUPITER: chạy 002 để chuyển sang VP/KHO.
IF NOT EXISTS (SELECT 1 FROM dbo.WorkingCalendars WHERE Code = 'VP')
    INSERT INTO dbo.WorkingCalendars (Code, Name, IsDefault)
    VALUES ('VP', N'Văn phòng',
            CASE WHEN EXISTS (SELECT 1 FROM dbo.WorkingCalendars WHERE IsDefault = 1) THEN 0 ELSE 1 END);
IF NOT EXISTS (SELECT 1 FROM dbo.WorkingCalendars WHERE Code = 'KHO_PSNV')
    INSERT INTO dbo.WorkingCalendars (Code, Name, IsDefault) VALUES ('KHO_PSNV', N'Kho PSNV', 0);
IF NOT EXISTS (SELECT 1 FROM dbo.WorkingCalendars WHERE Code = 'KHO_JUPITER')
    INSERT INTO dbo.WorkingCalendars (Code, Name, IsDefault) VALUES ('KHO_JUPITER', N'Kho JUPITER', 0);
GO
