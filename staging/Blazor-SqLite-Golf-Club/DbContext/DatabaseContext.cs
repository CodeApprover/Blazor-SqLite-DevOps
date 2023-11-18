// <copyright file="DatabaseContext.cs" company="CodeApprover">
// Copyright (c) CodeApprover. All rights reserved.
// </copyright>

namespace Blazor_SqLite_Golf_Club.DbContext
{
    using Blazor_SqLite_Golf_Club.Models;
    using Microsoft.EntityFrameworkCore;

    /// <summary>
    /// Represents the database context for the Golf Club application.
    /// </summary>
    public class DatabaseContext : DbContext // not internal for Blazor-Tests
    {
        readonly bool useInMemoryDatabase;

        /// <summary>
        /// Initializes a new instance of the <see cref="DatabaseContext"/> class.
        /// </summary>
        /// <param name="options">The options used to configure the database context.</param>
        /// <param name="useInMemoryDatabase">Indicates whether to use an in-memory database (optional).</param>
        public DatabaseContext(DbContextOptions options, bool useInMemoryDatabase = false)
            : base(options)
        {
            this.useInMemoryDatabase = useInMemoryDatabase;
        }

        /// <summary>
        /// Gets or sets the database Players.
        /// </summary>
        public DbSet<Player> Players { get; set; } = null!; // not protected internal for Blazor-Tests

        /// <summary>
        /// Gets or sets the database Games.
        /// </summary>
        public DbSet<Game> Games { get; set; } = null!; // not protected internal for Blazor-Tests

        /// <summary>
        /// Configures database context options for SQLite.
        /// </summary>
        /// <param name="optionsBuilder">The options builder used to configure the context.</param>
        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        {
            if (!useInMemoryDatabase)
            {
                optionsBuilder.UseSqlite(@"Data Source=Database//staging-database.db");
            }
        }
    }
}
