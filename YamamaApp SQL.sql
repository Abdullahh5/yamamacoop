USE YamamaData;
GO
ALTER TABLE Bookings DROP CONSTRAINT CK_Bookings_Status;
GO
ALTER TABLE Bookings ADD CONSTRAINT CK_Bookings_Status
    CHECK (Status IN ('Pending','Confirmed','Loading','Completed'));

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


CREATE TRIGGER trg_Bookings_Notify ON Bookings
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

INSERT INTO Notifications (AccountId, BookingId, Status, IsRead, CreatedAt)
SELECT AccountId, BookingId, Status, 1, CreatedAt FROM Bookings;
GO

SELECT * FROM Notifications;
GO
