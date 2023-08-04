// <copyright file="PlayerService.cs" company="CodeApprover">
// Copyright (c) CodeApprover. All rights reserved.
// </copyright>

namespace Blazor_SqlLite_Golf_Club.Services
{
    using System.Text.RegularExpressions;
    using Blazor_SqlLite_Golf_Club.DbContext;
    using Blazor_SqlLite_Golf_Club.Models;
    using Microsoft.EntityFrameworkCore;

    /// <summary>
    ///     Provides operations related to player data in the Golf Club application.
    /// </summary>
    public class PlayerService
    {
        // private Fields
        private readonly DatabaseContext databaseContext;
        private bool boolAscending;

        /// <summary>
        /// Initializes a new instance of the <see cref="PlayerService"/> class.
        ///     Initialises database connection.
        /// </summary>
        /// <param name="databaseContext">The database connection.</param>
        public PlayerService(DatabaseContext databaseContext) => this.databaseContext = databaseContext;

        /// <summary>
        ///     Creates a new player and adds them to the database.
        /// </summary>
        /// <param name="player">The new player to be added to the database.</param>
        /// <returns>A message indicating whether the player was successfully added or not.</returns>
        internal async Task<string> Create(Player player)
        {
            await this.databaseContext.Players.ToListAsync();

            if (!IsValidString(player.Firstname) || !IsValidString(player.Surname))
            {
                return "Incorrect firstname or surname - max length 10 each.";
            }

            if (!IsValidEmail(player.Email))
            {
                return "Invalid email address - max length 30.";
            }

            if (await this.databaseContext.Players.AnyAsync(p => p.Email == player.Email))
            {
                return "A player with this email already exists.";
            }

            if (string.IsNullOrEmpty(player.Gender))
            {
                return "Select gender.";
            }

            if (player.Handicap == 0.0)
            {
                return "Select handicap";
            }

            if (await this.databaseContext.Players.AnyAsync())
            {
                player.PlayerId = await this.databaseContext.Players.MaxAsync(p => p.PlayerId) + 1;
            }
            else
            {
                player.PlayerId = 1;
            }

            await this.databaseContext.Players.AddAsync(player);
            await this.databaseContext.SaveChangesAsync();

            return $"{player.Firstname} {player.Surname} added.";
        }

        /// <summary>
        ///     Updates an existing player in the database.
        /// </summary>
        /// <param name="player">The player to be updated.</param>
        /// <param name="gameService">Service object for manipluating games.</param>
        /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
        internal async Task Edit(Player player, GameService gameService)
        {
            var allGames = await this.databaseContext.Games.ToListAsync();
            var allPlayers = await this.databaseContext.Players.ToListAsync();

            var playersGames = (from game in allGames
                                where player.PlayerId == game.Captain
                                      || player.PlayerId == game.Player2
                                      || player.PlayerId == game.Player3
                                      || player.PlayerId == game.Player4
                                select game).ToList();

            this.databaseContext.Players.Update(player);

            for (var i = 0; i < allPlayers.Count; i++)
            {
                if (allPlayers[i].PlayerId != player.PlayerId)
                {
                    continue;
                }

                allPlayers[i] = player;
                break;
            }

            foreach (var game in playersGames)
            {
                game.GameCard = await gameService.GameCard(game);
                this.databaseContext.Games.Update(game);
            }

            await this.databaseContext.SaveChangesAsync();
        }

        /// <summary>
        ///     Deletes an existing player from the database.
        /// </summary>
        /// <param name="player">The player to be deleted.</param>
        /// <returns>A <see cref="Task"/> representing the asynchronous operation.</returns>
        internal async Task Delete(Player player)
        {
            var allGames = await this.databaseContext.Games.ToListAsync();

            var playersGames = (from game in allGames
                                where player.PlayerId == game.Captain
                                      || player.PlayerId == game.Player2
                                      || player.PlayerId == game.Player3
                                      || player.PlayerId == game.Player4
                                select game).ToList();

            foreach (var game in playersGames)
            {
                this.databaseContext.Games.Remove(game);
            }

            this.databaseContext.Players.Remove(player);

            await this.databaseContext.SaveChangesAsync();
        }

        /// <summary>
        ///     Retrieves all players from the database.
        /// </summary>
        /// <returns>A list of all players in the database, or null if the operation fails.</returns>
        internal Task<List<Player>> GetAll() => this.databaseContext.Players.ToListAsync();

        /// <summary>
        ///     Sorts the list of players in the database by the specified column.
        /// </summary>
        /// <param name="column">The column to sort by.</param>
        /// <returns>
        ///     A list of players sorted by the specified column, or the unsorted list if the column is invalid or the
        ///     operation fails.
        /// </returns>
        internal async Task<List<Player>?> SortTables(string column)
        {
            var allPlayers = await this.databaseContext.Players.ToListAsync();
            this.boolAscending = !this.boolAscending;

            return column switch
            {
                "Id" => this.boolAscending
                    ? new List<Player>(allPlayers.OrderBy(p => p.PlayerId))
                    : new List<Player>(allPlayers.OrderByDescending(p => p.PlayerId)),
                "Firstname" => this.boolAscending
                    ? new List<Player>(allPlayers.OrderBy(p => p.Firstname))
                    : new List<Player>(allPlayers.OrderByDescending(p => p.Firstname)),
                "Surname" => this.boolAscending
                    ? new List<Player>(allPlayers.OrderBy(p => p.Surname))
                    : new List<Player>(allPlayers.OrderByDescending(p => p.Surname)),
                "Email" => this.boolAscending
                    ? new List<Player>(allPlayers.OrderBy(p => p.Email))
                    : new List<Player>(allPlayers.OrderByDescending(p => p.Email)),
                "Gender" => this.boolAscending
                    ? new List<Player>(allPlayers.OrderBy(p => p.Gender))
                    : new List<Player>(allPlayers.OrderByDescending(p => p.Gender)),
                "Handicap" => this.boolAscending
                    ? new List<Player>(allPlayers.OrderBy(p => p.Handicap))
                    : new List<Player>(allPlayers.OrderByDescending(p => p.Handicap)),
                _ => allPlayers
            };
        }

        /// <summary>
        ///     Determines if the specified string is a valid name.
        /// </summary>
        /// <param name="name">The name to validate.</param>
        /// <returns>True if the first name or surname is valid, false otherwise.</returns>
        private static bool IsValidString(string name)
        {
            if (string.IsNullOrEmpty(name) || name.Length is > 10 or < 1)
            {
                return false;
            }

            var nameRegex = new Regex("^[a-zA-Z\\s\\-]*$");
            return nameRegex.IsMatch(name);
        }

        /// <summary>
        ///     Determines if the specified email address is valid.
        /// </summary>
        /// <param name="email">The email address to validate.</param>
        /// <returns>True if the email address is valid, false otherwise.</returns>
        private static bool IsValidEmail(string email)
        {
            if (string.IsNullOrEmpty(email) || email.Length is > 31 or < 5)
            {
                return false;
            }

            var emailRegex = new Regex(@"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
            return emailRegex.IsMatch(email);
        }
    }
}
