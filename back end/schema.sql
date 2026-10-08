/* ============================================================
   YamamaData - سكربت إنشاء قاعدة البيانات كامل
   يمكن تشغيله أكثر من مرة بدون أخطاء
   ============================================================ */

IF DB_ID('YamamaData') IS NULL
    CREATE DATABASE YamamaData;
GO

USE YamamaData;
GO

/* ---------- 1) الحسابات ---------- */
IF OBJECT_ID('dbo.Accounts', 'U') IS NULL
CREATE TABLE Accounts (
    AccountId       INT IDENTITY(1,1) PRIMARY KEY,
    CompanyName     NVARCHAR(150) NOT NULL,
    FullName        NVARCHAR(100) NOT NULL,
    Mobile          VARCHAR(10)   NOT NULL UNIQUE,
    CommercialReg   VARCHAR(10)   NOT NULL UNIQUE,
    PasswordHash    NVARCHAR(255) NOT NULL,
    IsActive        BIT           NOT NULL DEFAULT 1,
    CreatedAt       DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Accounts_Mobile CHECK (Mobile LIKE '05[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
    CONSTRAINT CK_Accounts_CR     CHECK (CommercialReg LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')
);
GO

/* ---------- 2) الحجوزات ---------- */
IF OBJECT_ID('dbo.Bookings', 'U') IS NULL
CREATE TABLE Bookings (
    BookingId        INT IDENTITY(1,1) PRIMARY KEY,
    BookingCode      VARCHAR(20)    NOT NULL UNIQUE,
    AccountId        INT            NOT NULL,
    CementType       NVARCHAR(30)   NOT NULL,
    QuantityTon      DECIMAL(10,2)  NOT NULL,
    BookingDate      DATE           NOT NULL,
    BookingTime      TIME(0)        NULL,
    DriverName       NVARCHAR(100)  NULL,
    PlateNumber      NVARCHAR(20)   NULL,
    DriverMobile     VARCHAR(10)    NULL,
    DeliveryLocation NVARCHAR(200)  NULL,
    Latitude         DECIMAL(9,6)   NULL,
    Longitude        DECIMAL(9,6)   NULL,
    Status           VARCHAR(20)    NOT NULL DEFAULT 'Pending',
    CreatedAt        DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Bookings_Accounts FOREIGN KEY (AccountId) REFERENCES Accounts(AccountId),
    CONSTRAINT CK_Bookings_Qty      CHECK (QuantityTon > 0),
    CONSTRAINT CK_Bookings_Status   CHECK (Status IN ('Pending','Confirmed','Loading','Completed')),
    CONSTRAINT CK_Bookings_DriverMobile
        CHECK (DriverMobile IS NULL OR DriverMobile LIKE '05[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')
);
GO

/* ---------- 3) الإشعارات ---------- */
IF OBJECT_ID('dbo.Notifications', 'U') IS NULL
CREATE TABLE Notifications (
    NotificationId INT IDENTITY(1,1) PRIMARY KEY,
    AccountId      INT         NOT NULL,
    BookingId      INT         NOT NULL,
    Status         VARCHAR(20) NOT NULL,
    IsRead         BIT         NOT NULL DEFAULT 0,
    CreatedAt      DATETIME2   NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Notif_Accounts FOREIGN KEY (AccountId) REFERENCES Accounts(AccountId),
    CONSTRAINT FK_Notif_Bookings FOREIGN KEY (BookingId) REFERENCES Bookings(BookingId) ON DELETE CASCADE
);
GO

/* ---------- 4) تريقر: إشعار تلقائي عند حجز جديد أو تغيّر الحالة ---------- */
CREATE OR ALTER TRIGGER trg_Bookings_Notify ON Bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Notifications (AccountId, BookingId, Status)
    SELECT i.AccountId, i.BookingId, i.Status
    FROM inserted i
    LEFT JOIN deleted d ON d.BookingId = i.BookingId
    WHERE d.BookingId IS NULL OR d.Status <> i.Status;
END
GO
