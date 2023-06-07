using Blazor_SqlLite_Golf_Club.Models;
using Microsoft.EntityFrameworkCore;

namespace Blazor_SqlLite_Golf_Club.dbContext;

internal class DatabaseContext : DbContext
{
    /// <summary>
    ///     Gets or sets database Players.
    /// </summary>
    protected internal DbSet<Player> Players { get; set; } = null!;

    /// <summary>
    ///     Gets or sets database Games.
    /// </summary>
    protected internal DbSet<Game> Games { get; set; } = null!;

    /// <summary>
    ///     Configures database context options for SQLite.
    /// </summary>
    /// <param name="optionsBuilder">The options builder used to configure the context.</param>
    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        optionsBuilder.UseSqlite(@"Data Source=Database\database.db");
    }
}