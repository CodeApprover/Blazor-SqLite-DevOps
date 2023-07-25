using Blazor_SqlLite_Golf_Club.Models;
using Microsoft.EntityFrameworkCore;

namespace Blazor_SqlLite_Golf_Club.dbContext;

public class DatabaseContext : DbContext // not internal for Blazor-Tests
{
    private readonly bool _useInMemoryDatabase = false;

    public DatabaseContext(DbContextOptions options, bool useInMemoryDatabase = false) : base(options)
    {
        _useInMemoryDatabase = useInMemoryDatabase;
    }

    /// <summary>
    ///     Gets or sets database Players.
    /// </summary>
    public DbSet<Player> Players { get; set; } = null!; // not protected internal for Blazor-Tests

    /// <summary>
    ///     Gets or sets database Games.
    /// </summary>
    public DbSet<Game> Games { get; set; } = null!; // not protected internal for Blazor-Tests

    /// <summary>
    ///     Configures database context options for SQLite.
    /// </summary>
    /// <param name="optionsBuilder">The options builder used to configure the context.</param>
    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        if (!_useInMemoryDatabase)
        {
            optionsBuilder.UseSqlite(@"Data Source=Database//database.db");
        }
    }
}