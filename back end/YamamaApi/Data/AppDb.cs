using Microsoft.EntityFrameworkCore;
using YamamaApi.Models;

namespace YamamaApi.Data;

public class AppDb : DbContext
{
    public AppDb(DbContextOptions<AppDb> options) : base(options) { }

    public DbSet<Account> Accounts => Set<Account>();
    public DbSet<Booking> Bookings => Set<Booking>();
    public DbSet<AppNotification> Notifications => Set<AppNotification>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<Account>().ToTable("Accounts").HasKey(x => x.AccountId);
        b.Entity<Account>().Property(x => x.CreatedAt).ValueGeneratedOnAdd();
        b.Entity<Account>().Property(x => x.IsActive).HasDefaultValue(true);

        // الجدول فيه تريقر، لازم نخبر EF عنه
        b.Entity<Booking>().ToTable("Bookings", t => t.HasTrigger("trg_Bookings_Notify"))
            .HasKey(x => x.BookingId);
        b.Entity<Booking>().Property(x => x.CreatedAt).ValueGeneratedOnAdd();
        b.Entity<Booking>().Property(x => x.Latitude).HasPrecision(9, 6);
        b.Entity<Booking>().Property(x => x.Longitude).HasPrecision(9, 6);
        b.Entity<Booking>().Property(x => x.QuantityTon).HasPrecision(10, 2);
        b.Entity<Booking>().HasOne(x => x.Account)
            .WithMany(a => a.Bookings).HasForeignKey(x => x.AccountId);

        b.Entity<AppNotification>().ToTable("Notifications").HasKey(x => x.NotificationId);
        b.Entity<AppNotification>().Property(x => x.CreatedAt).ValueGeneratedOnAdd();
        b.Entity<AppNotification>().HasOne(x => x.Booking)
            .WithMany().HasForeignKey(x => x.BookingId);
    }
}