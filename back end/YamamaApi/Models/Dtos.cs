namespace YamamaApi.Models;

public record RegisterDto(string CompanyName, string FullName, string Mobile,
                          string CommercialReg, string Password);

public record LoginDto(string Mobile, string Password);

public record CreateBookingDto(string CementType, decimal QuantityTon,
    DateTime BookingDate, TimeSpan? BookingTime, string? DriverName,
    string? PlateNumber, string? DriverMobile, string? DeliveryLocation,
    decimal? Latitude, decimal? Longitude);