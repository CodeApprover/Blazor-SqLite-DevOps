using Blazor_SqlLite_Golf_Club.dbContext;
using Blazor_SqlLite_Golf_Club.Models;
using Blazor_SqlLite_Golf_Club.Services;
using Microsoft.EntityFrameworkCore;

namespace MSTest_Integration_Tests
{
    [TestClass]
    public class Integration_Test_Suite
    {
        private static readonly DbContextOptions<DatabaseContext> _dbContextOptions = new DbContextOptionsBuilder<DatabaseContext>()
            .UseInMemoryDatabase(databaseName: "TestDatabase").Options;

        private static DatabaseContext? _dbContext;
        private GameService? _gameService;


        [TestInitialize]
        public void TestInitialize()
        {
            _dbContext = new DatabaseContext(_dbContextOptions, useInMemoryDatabase: true);
            _dbContext.Database.EnsureCreated();

            // Check if the game with the specified ID exists in the database
            var gameExists = _dbContext.Games.Any(g => g.GameId == 1);

            if (!gameExists)
            {
                // Seed in-memory database if the game with ID 1 does not exist
                _dbContext.Games
                    .Add(new Game
                {
                    GameId = 1,
                    Captain = 99,
                    Player2 = 98,
                    Player3 = 97,
                    Player4 = 96,
                    GameTime = new DateTime(2029, 1, 30, 15, 00, 0)
                });
                _dbContext.SaveChanges(); // seed data game ID 1
            }

            _gameService = new GameService(_dbContext);
        }


        [TestMethod]
        public async Task Test_CreateGame_Success()
        {
            // Arrange
            var game = new Game
            {
                Captain = 99,
                Player2 = 98,
                Player3 = 97,
                Player4 = 96,
                GameTime = new DateTime(2029, 1, 29, 17, 30, 0) // valid timeslot
            };

            // Act
            var gameCard = await _gameService!.Create(game);

            // Assert
            Assert.IsNotNull(gameCard);
            Assert.IsTrue(gameCard.StartsWith("Game Id"));  // created game ID 2
        }


        [TestMethod]
        public async Task Test_CreateGame_WithDuplicatePlayers_Fails()
        {
            // Arrange
            var game = new Game
            {
                Captain = 99,
                Player2 = 99, // Player2 has same ID as Captain, causing duplication
                Player3 = 98,
                Player4 = 97,
                GameTime = new DateTime(2023, 5, 21, 11, 45, 0)
            };

            // Act
            var gameCard = await _gameService!.Create(game);

            // Assert
            Assert.IsNotNull(gameCard);
            Assert.IsTrue(gameCard.Contains("Players must be unique."));
        }


        [TestMethod]
        public async Task Test_CreateGame_WithInvalidTime_Fails()
        {
            // Arrange
            var game = new Game
            {
                Captain = 99,
                Player2 = 98,
                Player3 = 97,
                Player4 = 96,
                GameTime = DateTime.MinValue // Invalid time (midnight)
            };

            // Act
            var gameCard = await _gameService!.Create(game);

            // Assert
            Assert.IsNotNull(gameCard);
            Assert.IsTrue(gameCard.Contains("Select a valid time."));
        }


        [TestMethod]
        public async Task Test_CreateGame_WithUnavailableTimeSlot_Fails()
        {
            // Arrange
            var game = new Game
            {
                Captain = 99,
                Player2 = 98,
                Player3 = 97,
                Player4 = 96,
                GameTime = new DateTime(2029, 1, 30, 15, 00, 0) // Time slot already taken by seed data
            };

            // Act
            var gameCard = await _gameService!.Create(game);

            // Assert
            Assert.IsNotNull(gameCard);
            Assert.IsTrue(gameCard.Contains("is unavailable.")); // assert gametime unavailable
        }


        [TestMethod]
        public async Task Test_EditGame_Success()
        {
            // Arrange
            // Assuming you have a valid game ID to edit
            var gameIdToEdit = 1; // seed game ID
            var gameToEdit = await _dbContext!.Games.FirstOrDefaultAsync(g => g.GameId == gameIdToEdit);

            // Updated game with new values
            gameToEdit!.Player2 = 33;

            // Act
            await _gameService!.Edit(gameToEdit);

            // Assert
            // Retrieve game after edit
            var editedGame = await _dbContext!.Games.FirstOrDefaultAsync(g => g.GameId == gameIdToEdit);

            // Assert that game is not null, indicating it is in the database
            Assert.IsNotNull(editedGame);

            // Assert that the properties of the edited game match the updated values
            Assert.AreEqual(gameToEdit.Captain, editedGame.Captain);
            Assert.AreEqual(33, editedGame.Player2);
            Assert.AreEqual(gameToEdit.Player3, editedGame.Player3);
            Assert.AreEqual(gameToEdit.Player4, editedGame.Player4);
            Assert.AreEqual(gameToEdit.GameTime, editedGame.GameTime);
        }


        [TestMethod]
        public async Task Test_DeleteGames_Success()
        {
            // Arrange
            var gameIdsToDelete = new List<int> { 1, 2 }; // seed data game ID 1, created game ID 2

            // Act
            foreach (var gameId in gameIdsToDelete)
            {
                var gameToDelete = await _dbContext!.Games.FirstOrDefaultAsync(g => g.GameId == gameId);
                await _gameService!.Delete(gameToDelete!);
            }

            // Assert
            foreach (var gameId in gameIdsToDelete)
            {
                var deletedGame = await _dbContext!.Games.FirstOrDefaultAsync(g => g.GameId == gameId);
                Assert.IsNull(deletedGame, $"Game with ID {gameId} should have been deleted.");
            }
        }


        [TestCleanup]
        public void TestCleanup()
        {
            // Dispose the DatabaseContext after each test
            _dbContext?.Dispose();
        }
    }
}