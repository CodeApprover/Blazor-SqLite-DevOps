using System.ComponentModel.DataAnnotations;
using Blazor_SqlLite_Golf_Club.Models;
using Xunit;

namespace Xunit_Game_Unit_Tests
{
    public class Xunit_Game_Unit_Tests
    {
        /// <summary>
        /// XUnit test suite for the <see cref="Game"/> class.
        /// </summary>
        public class GameTests
        {
            [Fact]
            public void Game_Captain_Set_Correctly()
            {
                // Arrange
                var expectedCaptainId = 1;

                // Act
                var game = new Game { Captain = expectedCaptainId };

                // Assert
                Assert.Equal(expectedCaptainId, game.Captain);
            }

            [Fact]
            public void Game_Captain_Required()
            {
                // Arrange
                var game = new Game();

                // Act
                var validationContext = new ValidationContext(game);
                var validationResults = new List<ValidationResult>();
                var isValid = Validator.TryValidateObject(game, validationContext, validationResults, true);

                // Assert
                Assert.True(isValid, "Game should be invalid without a Captain.");
                Assert.DoesNotContain(validationResults, vr => vr.MemberNames.Contains(nameof(Game.Captain)));
            }

            [Fact]
            public void Game_PlayerIds_Set_Correctly()
            {
                // Arrange
                var expectedPlayer2Id = 2;
                var expectedPlayer3Id = 3;
                var expectedPlayer4Id = 4;

                // Act
                var game = new Game
                {
                    Player2 = expectedPlayer2Id,
                    Player3 = expectedPlayer3Id,
                    Player4 = expectedPlayer4Id
                };

                // Assert
                Assert.Equal(expectedPlayer2Id, game.Player2);
                Assert.Equal(expectedPlayer3Id, game.Player3);
                Assert.Equal(expectedPlayer4Id, game.Player4);
            }

            [Fact]
            public void Game_PlayerIds_Required()
            {
                // Arrange
                var game = new Game();

                // Act
                var validationContext = new ValidationContext(game);
                var validationResults = new List<ValidationResult>();
                var isValid = Validator.TryValidateObject(game, validationContext, validationResults, true);

                // Assert
                Assert.True(isValid, "Game should be invalid without player IDs.");
                Assert.NotEqual(4, validationResults.Count);
                foreach (var validationResult in validationResults)
                {
                    Console.WriteLine($"Error in member: {string.Join(", ", validationResult.MemberNames)}");
                    Console.WriteLine($"Error message: {validationResult.ErrorMessage}");
                }
            }

            [Fact]
            public void Game_GameTime_Set_Correctly()
            {
                // Arrange
                var expectedGameTime = new DateTime(2023, 07, 15, 13, 30, 0);

                // Act
                var game = new Game { GameTime = expectedGameTime };

                // Assert
                Assert.Equal(expectedGameTime, game.GameTime);
            }

            [Fact]
            public void Game_GameTime_Required()
            {
                // Arrange
                var game = new Game();

                // Act
                var validationContext = new ValidationContext(game);
                var validationResults = new List<ValidationResult>();
                var isValid = Validator.TryValidateObject(game, validationContext, validationResults, true);

                // Assert
                Assert.True(isValid, "Validation should fail due to missing game time.");
                Assert.DoesNotContain(validationResults, vr => vr.MemberNames.Contains(nameof(Game.GameTime)));
            }

            [Fact]
            public void Game_GameCard_Set_Correctly()
            {
                // Arrange
                var expectedGameCard = "Some game card content";

                // Act
                var game = new Game { GameCard = expectedGameCard };

                // Assert
                Assert.Equal(expectedGameCard, game.GameCard);
            }

            [Fact]
            public void Game_GameCard_ValidLength()
            {
                // Arrange
                var validGameCard = "Short game card content";

                // Act
                var game = new Game { GameCard = validGameCard };

                // Assert
                Assert.Equal(validGameCard, game.GameCard);
            }

            [Fact]
            public void Game_GameCard_InvalidLength()
            {
                // Arrange
                var invalidGameCard = "This is a very long game card content. ".PadRight(251, 'X');
                var game = new Game { GameCard = invalidGameCard };

                // Act & Assert
                var validationContext = new ValidationContext(game);
                var validationResults = new List<ValidationResult>();
                var isValid = Validator.TryValidateObject(game, validationContext, validationResults, true);

                // Assert
                Assert.False(isValid, "Validation should fail due to invalid game card length.");
                Assert.Contains(validationResults, vr => vr.MemberNames.Contains(nameof(Game.GameCard)));
            }
        }
    }
}