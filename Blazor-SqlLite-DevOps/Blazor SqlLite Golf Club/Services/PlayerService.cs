using Blazor_SqlLite_Golf_Club.dbContext;
using Blazor_SqlLite_Golf_Club.Models;
using Microsoft.EntityFrameworkCore;
using System.Text.RegularExpressions;

namespace Blazor_SqlLite_Golf_Club.Services;

internal class PlayerService
{
    // private Fields
    readonly DatabaseContext _databaseContext;
    bool _boolAscending;

    /// <summary>
    ///     Initialises database connection.
    /// </summary>
    /// <param name="databaseContext"></param>
    public PlayerService(DatabaseContext databaseContext) => _databaseContext = databaseContext;

    /// <summary>
    ///     Creates a new player and adds them to the database.
    /// </summary>
    /// <param name="player">The new player to be added to the database.</param>
    /// <returns>A message indicating whether the player was successfully added or not.</returns>
    internal async Task<string> Create(Player player)
    {
        await _databaseContext.Players.ToListAsync();

        if (!IsValidString(player.Firstname) || !IsValidString(player.Surname))
            return "Incorrect firstname or surname - max length 10 each.";

        if (!IsValidEmail(player.Email)) return "Invalid email address - max length 30.";

        if (await _databaseContext.Players.AnyAsync(p => p.Email == player.Email))
            return "A player with this email already exists.";

        if (string.IsNullOrEmpty(player.Gender)) return "Select gender.";

        if (player.Handicap == 0.0)
            return "Select handicap";

        if (await _databaseContext.Players.CountAsync() > 0)
            player.PlayerId = await _databaseContext.Players.MaxAsync(p => p.PlayerId) + 1;
        else
            player.PlayerId = 1;

        await _databaseContext.Players.AddAsync(player);
        await _databaseContext.SaveChangesAsync();

        return $"{player.Firstname} {player.Surname} added.";
    }

    /// <summary>
    ///     Updates an existing player in the database.
    /// </summary>
    /// <param name="player">The player to be updated.</param>
    internal async Task Edit(Player player)
    {
        var allGames = await _databaseContext.Games.ToListAsync();
        var allPlayers = await _databaseContext.Players.ToListAsync();

        var playersGames = (from game in allGames
                            where player.PlayerId == game.Captain
                                  || player.PlayerId == game.Player2
                                  || player.PlayerId == game.Player3
                                  || player.PlayerId == game.Player4
                            select game).ToList();

        _databaseContext.Players.Update(player);

        for (var i = 0; i < allPlayers.Count; i++)
        {
            if (allPlayers[i].PlayerId != player.PlayerId) continue;
            allPlayers[i] = player;
            break;
        }

        foreach (var game in playersGames)
        {
            game.GameCard = await GameService.GameCard(game);
            _databaseContext.Games.Update(game);
        }

        await _databaseContext.SaveChangesAsync();
    }

    /// <summary>
    ///     Deletes an existing player from the database.
    /// </summary>
    /// <param name="player">The player to be deleted.</param>
    internal async Task Delete(Player player)
    {
        var allGames = await _databaseContext.Games.ToListAsync();

        var playersGames = (from game in allGames
                            where player.PlayerId == game.Captain
                                  || player.PlayerId == game.Player2
                                  || player.PlayerId == game.Player3
                                  || player.PlayerId == game.Player4
                            select game).ToList();

        foreach (var game in playersGames) _databaseContext.Games.Remove(game);
        _databaseContext.Players.Remove(player);

        await _databaseContext.SaveChangesAsync();
    }

    /// <summary>
    ///     Retrieves all players from the database.
    /// </summary>
    /// <returns>A list of all players in the database, or null if the operation fails.</returns>
    internal Task<List<Player>?> GetAll() => _databaseContext.Players.ToListAsync();

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
        var allPlayers = await _databaseContext.Players.ToListAsync();
        _boolAscending = !_boolAscending;

        return column switch
        {
            "Id" => _boolAscending
                ? new List<Player>(allPlayers.OrderBy(p => p.PlayerId))
                : new List<Player>(allPlayers.OrderByDescending(p => p.PlayerId)),
            "Firstname" => _boolAscending
                ? new List<Player>(allPlayers.OrderBy(p => p.Firstname))
                : new List<Player>(allPlayers.OrderByDescending(p => p.Firstname)),
            "Surname" => _boolAscending
                ? new List<Player>(allPlayers.OrderBy(p => p.Surname))
                : new List<Player>(allPlayers.OrderByDescending(p => p.Surname)),
            "Email" => _boolAscending
                ? new List<Player>(allPlayers.OrderBy(p => p.Email))
                : new List<Player>(allPlayers.OrderByDescending(p => p.Email)),
            "Gender" => _boolAscending
                ? new List<Player>(allPlayers.OrderBy(p => p.Gender))
                : new List<Player>(allPlayers.OrderByDescending(p => p.Gender)),
            "Handicap" => _boolAscending
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
    static bool IsValidString(string name)
    {
        if (string.IsNullOrEmpty(name) || name.Length is > 10 or < 1) return false;
        var nameRegex = new Regex("^[a-zA-Z\\s\\-]*$");
        return nameRegex.IsMatch(name);
    }

    /// <summary>
    ///     Determines if the specified email address is valid.
    /// </summary>
    /// <param name="email">The email address to validate.</param>
    /// <returns>True if the email address is valid, false otherwise.</returns>
    static bool IsValidEmail(string email)
    {
        if (string.IsNullOrEmpty(email) || email.Length is > 31 or < 5) return false;
        var emailRegex = new Regex(@"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
        return emailRegex.IsMatch(email);
    }
}