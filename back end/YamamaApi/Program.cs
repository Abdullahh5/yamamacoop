using System.Security.Claims;
using System.Text;
using System.Text.RegularExpressions;
using System.IdentityModel.Tokens.Jwt;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using YamamaApi.Data;
using YamamaApi.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<AppDb>(o =>
    o.UseSqlServer(builder.Configuration.GetConnectionString("Default")));

builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

var jwt = builder.Configuration.GetSection("Jwt");
var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt["Key"]!));

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o => o.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true, ValidIssuer = jwt["Issuer"],
        ValidateAudience = true, ValidAudience = jwt["Audience"],
        ValidateIssuerSigningKey = true, IssuerSigningKey = key,
        ValidateLifetime = true
    });
builder.Services.AddAuthorization();

var app = builder.Build();
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();

string MakeToken(Account a)
{
    var claims = new[] { new Claim("accountId", a.AccountId.ToString()),
                         new Claim(ClaimTypes.Name, a.FullName) };
    var token = new JwtSecurityToken(jwt["Issuer"], jwt["Audience"], claims,
        expires: DateTime.UtcNow.AddDays(7),
        signingCredentials: new SigningCredentials(key, SecurityAlgorithms.HmacSha256));
    return new JwtSecurityTokenHandler().WriteToken(token);
}

int CurrentAccountId(ClaimsPrincipal u) => int.Parse(u.FindFirst("accountId")!.Value);

// ---------- إنشاء حساب ----------
app.MapPost("/api/auth/register", async (RegisterDto d, AppDb db) =>
{
    if (!Regex.IsMatch(d.Mobile, @"^05\d{8}$"))
        return Results.BadRequest(new { error = "رقم الجوال لازم يبدأ بـ 05 ويكون 10 أرقام" });
    if (!Regex.IsMatch(d.CommercialReg, @"^\d{10}$"))
        return Results.BadRequest(new { error = "السجل التجاري لازم يكون 10 أرقام" });
    if (d.Password.Length < 8)
        return Results.BadRequest(new { error = "كلمة المرور لازم تكون 8 خانات على الأقل" });
    if (string.IsNullOrWhiteSpace(d.CompanyName) || string.IsNullOrWhiteSpace(d.FullName))
        return Results.BadRequest(new { error = "الاسم واسم الشركة مطلوبين" });

    if (await db.Accounts.AnyAsync(a => a.Mobile == d.Mobile))
        return Results.Conflict(new { error = "رقم الجوال مسجل من قبل" });
    if (await db.Accounts.AnyAsync(a => a.CommercialReg == d.CommercialReg))
        return Results.Conflict(new { error = "السجل التجاري مسجل من قبل" });

    var acc = new Account
    {
        CompanyName = d.CompanyName.Trim(), FullName = d.FullName.Trim(),
        Mobile = d.Mobile, CommercialReg = d.CommercialReg,
        PasswordHash = BCrypt.Net.BCrypt.HashPassword(d.Password)
    };
    db.Accounts.Add(acc);
    await db.SaveChangesAsync();
    return Results.Ok(new { token = MakeToken(acc), account = new { acc.AccountId, acc.CompanyName, acc.FullName } });
});

// ---------- تسجيل الدخول ----------
app.MapPost("/api/auth/login", async (LoginDto d, AppDb db) =>
{
    var acc = await db.Accounts.FirstOrDefaultAsync(a => a.Mobile == d.Mobile && a.IsActive);
    if (acc is null || !BCrypt.Net.BCrypt.Verify(d.Password, acc.PasswordHash))
        return Results.Unauthorized();
    return Results.Ok(new { token = MakeToken(acc), account = new { acc.AccountId, acc.CompanyName, acc.FullName } });
});

// ---------- بيانات العميل ----------
app.MapGet("/api/me", async (ClaimsPrincipal user, AppDb db) =>
{
    var id = CurrentAccountId(user);
    var acc = await db.Accounts.FirstOrDefaultAsync(a => a.AccountId == id);
    if (acc is null) return Results.NotFound();

    var total  = await db.Bookings.CountAsync(b => b.AccountId == id);
    var active = await db.Bookings.CountAsync(b => b.AccountId == id &&
                    (b.Status == "Pending" || b.Status == "Confirmed" || b.Status == "Loading"));
    var unread = await db.Notifications.CountAsync(n => n.AccountId == id && !n.IsRead);

    return Results.Ok(new { acc.FullName, acc.CompanyName, acc.Mobile, acc.CommercialReg,
                            totalBookings = total, activeBookings = active, unreadNotifications = unread });
}).RequireAuthorization();

// ---------- حجوزاتي (filter: all | active | completed) ----------
app.MapGet("/api/bookings", async (string? filter, ClaimsPrincipal user, AppDb db) =>
{
    var id = CurrentAccountId(user);
    var q = db.Bookings.Where(b => b.AccountId == id);
    q = filter switch
    {
        "active"    => q.Where(b => b.Status == "Pending" || b.Status == "Confirmed" || b.Status == "Loading"),
        "completed" => q.Where(b => b.Status == "Completed"),
        _ => q
    };
    var list = await q.OrderByDescending(b => b.BookingDate).ThenByDescending(b => b.BookingId)
        .Select(b => new { b.BookingId, b.BookingCode, b.CementType, b.QuantityTon,
                           b.BookingDate, b.Status }).ToListAsync();
    return Results.Ok(list);
}).RequireAuthorization();

// ---------- تفاصيل حجز ----------
app.MapGet("/api/bookings/{id:int}", async (int id, ClaimsPrincipal user, AppDb db) =>
{
    var acc = CurrentAccountId(user);
    var b = await db.Bookings.FirstOrDefaultAsync(x => x.BookingId == id && x.AccountId == acc);
    return b is null ? Results.NotFound() : Results.Ok(b);
}).RequireAuthorization();

// ---------- إنشاء حجز ----------
app.MapPost("/api/bookings", async (CreateBookingDto d, ClaimsPrincipal user, AppDb db) =>
{
    if (d.QuantityTon <= 0)
        return Results.BadRequest(new { error = "الكمية لازم تكون أكبر من صفر" });
    if (d.DriverMobile is not null && !Regex.IsMatch(d.DriverMobile, @"^05\d{8}$"))
        return Results.BadRequest(new { error = "جوال السائق غير صحيح" });

    var acc = CurrentAccountId(user);
    // رقم الحجز التالي = أكبر رقم موجود + 1 (ما يتكرر حتى بعد الإلغاء)
    var maxCode = await db.Bookings.Where(b => b.BookingCode.StartsWith("YC-"))
        .Select(b => b.BookingCode).OrderByDescending(c => c).FirstOrDefaultAsync();
    var next = 1011001;
    if (maxCode is not null && int.TryParse(maxCode.Substring(3), out var n)) next = n + 1;
    var booking = new Booking
    {
        BookingCode = $"YC-{next}",
        AccountId = acc, CementType = d.CementType, QuantityTon = d.QuantityTon,
        BookingDate = d.BookingDate.Date, BookingTime = d.BookingTime,
        DriverName = d.DriverName, PlateNumber = d.PlateNumber,
        DriverMobile = d.DriverMobile, DeliveryLocation = d.DeliveryLocation,
        Latitude = d.Latitude, Longitude = d.Longitude, Status = "Pending"
    };
    db.Bookings.Add(booking);
    await db.SaveChangesAsync();
    return Results.Created($"/api/bookings/{booking.BookingId}", booking);
}).RequireAuthorization();

// ---------- إلغاء حجز (فقط بانتظار التأكيد) ----------
app.MapDelete("/api/bookings/{id:int}", async (int id, ClaimsPrincipal user, AppDb db) =>
{
    var acc = CurrentAccountId(user);
    var b = await db.Bookings.FirstOrDefaultAsync(x => x.BookingId == id && x.AccountId == acc);
    if (b is null) return Results.NotFound();
    if (b.Status != "Pending")
        return Results.BadRequest(new { error = "لا يمكن إلغاء الحجز بعد تأكيده" });

    db.Bookings.Remove(b);
    await db.SaveChangesAsync();
    return Results.NoContent();
}).RequireAuthorization();

// ---------- الإشعارات ----------
app.MapGet("/api/notifications", async (ClaimsPrincipal user, AppDb db) =>
{
    var id = CurrentAccountId(user);
    var list = await db.Notifications
        .Where(n => n.AccountId == id)
        .OrderByDescending(n => n.CreatedAt).ThenByDescending(n => n.NotificationId)
        .Take(50)
        .Select(n => new { n.NotificationId, n.BookingId, bookingCode = n.Booking!.BookingCode,
                           n.Status, n.IsRead, n.CreatedAt })
        .ToListAsync();
    return Results.Ok(list);
}).RequireAuthorization();

app.MapPost("/api/notifications/read-all", async (ClaimsPrincipal user, AppDb db) =>
{
    var id = CurrentAccountId(user);
    await db.Notifications.Where(n => n.AccountId == id && !n.IsRead)
        .ExecuteUpdateAsync(s => s.SetProperty(n => n.IsRead, true));
    return Results.NoContent();
}).RequireAuthorization();

app.Run();