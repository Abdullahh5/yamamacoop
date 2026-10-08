namespace YamamaApi.Models;

public class Account
{
    public int AccountId { get; set; }
    public string CompanyName { get; set; } = "";
    public string FullName { get; set; } = "";
    public string Mobile { get; set; } = "";
    public string CommercialReg { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public List<Booking> Bookings { get; set; } = new();
}

public class Booking
{
    public int BookingId { get; set; }
    public string BookingCode { get; set; } = "";
    public int AccountId { get; set; }
    public string CementType { get; set; } = "";
    public decimal QuantityTon { get; set; }
    public DateTime BookingDate { get; set; }
    public TimeSpan? BookingTime { get; set; }
    public string? DriverName { get; set; }
    public string? PlateNumber { get; set; }
    public string? DriverMobile { get; set; }
    public string? DeliveryLocation { get; set; }
    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }
    public string Status { get; set; } = "Pending";
    public DateTime CreatedAt { get; set; }
    public Account? Account { get; set; }
}

public class AppNotification
{
    public int NotificationId { get; set; }
    public int AccountId { get; set; }
    public int BookingId { get; set; }
    public string Status { get; set; } = "";
    public bool IsRead { get; set; }
    public DateTime CreatedAt { get; set; }
    public Booking? Booking { get; set; }
}
