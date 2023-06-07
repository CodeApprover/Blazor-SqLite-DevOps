using System.Globalization;
using Blazor_SqlLite_Golf_Club.dbContext;
using Blazor_SqlLite_Golf_Club.Models;
using Microsoft.EntityFrameworkCore;

namespace Blazor_SqlLite_Golf_Club.Services;

/// <summary>
///     Provides functionality to manage games in the database.
/// </summary>
internal class GameService
{
    // private Fields
    private static DatabaseContext? _databaseContext;
    private bool _boolAscending;

    /// <summary>
    ///     Initialises database connection.
    /// </summary>
    /// <param name="databaseContext"></param>
    public GameService(DatabaseContext? databaseContext)
    {
        _databaseContext = databaseContext;
    }

    /// <summary>
    ///     Creates a new game in the database.
    /// </summary>
    /// <param name="game">The game to create.</param>
    /// <returns>A string representing the game card for the new game.</returns>
    internal async Task<string> Create(Game game)
    {
        var playerIds = new List<int> { game.Captain, game.Player2, game.Player3, game.Player4 };

        if (playerIds.Distinct().Count() < 4) return "Players must be unique.";

        if (game.GameTime.TimeOfDay == TimeSpan.Zero) return "Select a valid time.";

        var gameExists = await _databaseContext!.Games.AnyAsync(g => g.GameTime == game.GameTime);

        if (gameExists)
            return $"Game time of {game.GameTime:h.mm tt} " +
                   $"on {game.GameTime.Date.ToShortDateString()} is unavailable.";

        var captainsGames = await _databaseContext.Games
            .Where(g => g.Captain == game.Captain && g.GameTime.Date == game.GameTime.Date)
            .ToListAsync();

        if (captainsGames.Any())
            return $"Captain has existing booking on {game.GameTime.Date.ToShortDateString()}." +
                   $"(Game Id: {captainsGames.First().GameId})";

        if (await _databaseContext.Games.CountAsync() > 0)
            game.GameId = await _databaseContext.Games.MaxAsync(g => g.GameId) + 1;
        else
            game.GameId = 1;

        game.GameCard = await GameCard(game);
        await _databaseContext.Games.AddAsync(game);
        await _databaseContext.SaveChangesAsync();
        return game.GameCard;
    }

    /// <summary>
    ///     Edits an existing game in the database.
    /// </summary>
    /// <param name="game">The game to edit.</param>
    internal async Task Edit(Game game)
    {
        await _databaseContext!.Players.ToListAsync();
        var allGames = await _databaseContext.Games.ToListAsync();
        var playersGames = (from g in allGames
            where game.Captain == g.Captain
                  || game.Player2 == g.Player2
                  || game.Player3 == g.Player3
                  || game.Player4 == g.Player4
            select g).ToList();
        foreach (var pGame in playersGames)
        {
            pGame.GameCard = await GameCard(pGame);
            _databaseContext.Games.Update(pGame);
        }

        await _databaseContext.SaveChangesAsync();
    }

    /// <summary>
    ///     Deletes a game from the database.
    /// </summary>
    /// <param name="game">The game to be deleted.</param>
    internal async Task Delete(Game game)
    {
        _databaseContext!.Games.Remove(game);
        await _databaseContext.SaveChangesAsync();
    }

    /// <summary>
    ///     Returns a list of all games from the database.
    /// </summary>
    /// <returns>A Task List of Game objects.</returns>
    internal async Task<List<Game>> GetAll()
    {
        return await _databaseContext!.Games.ToListAsync();
    }

    /// <summary>
    ///     Generates a game card with details of the specified game.
    /// </summary>
    /// <param name="game">The game for which to generate a card.</param>
    /// <returns>A Task string containing the game card.</returns>
    internal static async Task<string> GameCard(Game game)
    {
        var allPlayers = await _databaseContext!.Players.ToListAsync();
        var gameCard = $"{"Game Id ",-10}{game.GameId}\n"
                       + $"{"Game Time ",-10}{game.GameTime:dddd dd/MM/yyyy 'at' HH:mm}"
                       + $" at {game.GameTime:h.mm tt}\n\n";

        var captain = allPlayers.FirstOrDefault(p => p.PlayerId == game.Captain);
        var player2 = allPlayers.FirstOrDefault(p => p.PlayerId == game.Player2);
        var player3 = allPlayers.FirstOrDefault(p => p.PlayerId == game.Player3);
        var player4 = allPlayers.FirstOrDefault(p => p.PlayerId == game.Player4);

        gameCard +=
            $"{"Captain Id",-10} {captain?.PlayerId.ToString(),-10} {captain?.Firstname} {captain?.Surname,-10} {captain?.Gender}/{captain?.Handicap.ToString(CultureInfo.InvariantCulture)}\n"
            + $"{"Player2 Id",-10} {player2?.PlayerId.ToString(),-10} {player2?.Firstname} {player2?.Surname,-10} {player2?.Gender}/{player2?.Handicap.ToString(CultureInfo.InvariantCulture)}\n"
            + $"{"Player3 Id",-10} {player3?.PlayerId.ToString(),-10} {player3?.Firstname} {player3?.Surname,-10} {player3?.Gender}/{player3?.Handicap.ToString(CultureInfo.InvariantCulture)}\n"
            + $"{"Player4 Id",-10}{player4?.PlayerId.ToString(),-10} {player4?.Firstname} {player4?.Surname,-10} {player4?.Gender}/{player4?.Handicap.ToString(CultureInfo.InvariantCulture)}";

        return gameCard;
    }

    /// <summary>
    ///     Sorts the list of games in ascending or descending order based on the specified column.
    /// </summary>
    /// <param name="column">The column to sort by.</param>
    /// <returns>
    ///     A Task List of Game objects sorted by column.
    /// </returns>
    internal async Task<List<Game>> SortTables(string column)
    {
        var allGames = await _databaseContext!.Games.ToListAsync();
        _boolAscending = !_boolAscending;

        return column switch
        {
            "Id" => _boolAscending
                ? new List<Game>(allGames.OrderBy(g => g.GameId))
                : new List<Game>(allGames.OrderByDescending(p => p.GameId)),
            "Game Time" => _boolAscending
                ? new List<Game>(allGames.OrderBy(p => p.GameTime))
                : new List<Game>(allGames.OrderByDescending(p => p.GameTime)),
            "Captain" => _boolAscending
                ? new List<Game>(allGames.OrderBy(p => p.Captain))
                : new List<Game>(allGames.OrderByDescending(p => p.Captain)),
            "Player2" => _boolAscending
                ? new List<Game>(allGames.OrderBy(p => p.Player2))
                : new List<Game>(allGames.OrderByDescending(p => p.Player2)),
            "Player3" => _boolAscending
                ? new List<Game>(allGames.OrderBy(p => p.Player3))
                : new List<Game>(allGames.OrderByDescending(p => p.Player3)),
            "Player4" => _boolAscending
                ? new List<Game>(allGames.OrderBy(p => p.Player4))
                : new List<Game>(allGames.OrderByDescending(p => p.Player4)),
            _ => allGames
        };
    }
}