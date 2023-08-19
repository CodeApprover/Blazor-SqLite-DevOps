namespace Nunit_Player_Unit_Tests
{
    using Blazor_SqLite_Golf_Club.Models;
    using System.ComponentModel.DataAnnotations;

    public class Nunit_Player_Unit_Tests
    {
        /// <summary>
        /// NUnit test suite for the <see cref="Player"/> class.
        /// </summary>
        [TestFixture]
        public class PlayerTests
        {
            /// <summary>
            /// Test to verify that the Firstname property is set correctly.
            /// </summary>
            [Test]
            public void Player_Firstname_Set_Correctly()
            {
                // Arrange
                var expectedFirstname = "Andy";

                // Act
                var player = new Player { Firstname = expectedFirstname };

                // Assert
                Assert.That(player.Firstname, Is.EqualTo(expectedFirstname));
            }

            /// <summary>
            /// Test to verify that the Firstname property fails MinimumLength validation with an empty string.
            /// </summary>
            [Test]
            public void Player_Firstname_MinimumLength_Fail()
            {
                // Arrange
                var invalidFirstname = "";

                // Act
                var player = new Player { Firstname = invalidFirstname };

                // Assert
                Assert.IsEmpty(player.Firstname, "Player Firstname MinimumLength validation failed: Firstname should not be empty.");
            }

            /// <summary>
            /// Test to verify that the Surname property is set correctly.
            /// </summary>
            [Test]
            public void Player_Surname_Set_Correctly()
            {
                // Arrange
                var expectedSurname = "Smith";

                // Act
                var player = new Player { Surname = expectedSurname };

                // Assert
                Assert.That(player.Surname, Is.EqualTo(expectedSurname));
            }

            /// <summary>
            /// Test to verify that the Surname property fails MinimumLength validation with an empty string.
            /// </summary>
            [Test]
            public void Player_Surname_MinimumLength_Fail()
            {
                // Arrange
                var invalidSurname = "";

                // Act
                var player = new Player { Surname = invalidSurname };

                // Assert
                Assert.That(player.Surname, Is.Empty, "Player Surname MinimumLength validation failed: Surname should not be empty.");
            }

            /// <summary>
            /// Test to verify that the Email property is set correctly.
            /// </summary>
            [Test]
            public void Player_Email_Set_Correctly()
            {
                // Arrange
                var expectedEmail = "andy@example.com";

                // Act
                var player = new Player { Email = expectedEmail };

                // Assert
                Assert.That(player.Email, Is.EqualTo(expectedEmail), "Player email format validation failed.");
            }

            /// <summary>
            /// Test to verify that the Email property fails format validation with an invalid email address.
            /// </summary>
            [Test]
            public void Player_Email_Format_Validation_Fail()
            {
                // Arrange
                var invalidEmail = "invalid_email_format";
                var player = new Player { Email = invalidEmail };
                var emailPropertyName = nameof(Player.Email);
                var emailProperty = typeof(Player).GetProperty(emailPropertyName) ?? throw new InvalidOperationException($"Property '{emailPropertyName}' not found on type '{nameof(Player)}'.");
                var validationContext = new ValidationContext(player) { MemberName = emailProperty.Name };
                var validationResults = new List<ValidationResult>();

                // Act
                var isValid = Validator.TryValidateProperty(player.Email, validationContext, validationResults);

                // Assert
                Assert.Multiple(() =>
                {
                    Assert.That(isValid, Is.False, "Player Email format validation should fail.");
                    Assert.That(validationResults, Has.Count.EqualTo(1), "Email format failure, expected one validation error.");
                    Assert.That(validationResults[0].ErrorMessage, Does.Contain("Invalid email address."), "Unexpected error message for email format validation.");
                });
            }

            /// <summary>
            /// Test to verify that the Gender property is set correctly.
            /// </summary>
            [Test]
            public void Player_Gender_Set_Correctly()
            {
                // Arrange
                var expectedGender = "M";

                // Act
                var player = new Player { Gender = expectedGender };

                // Assert
                Assert.That(player.Gender, Is.EqualTo(expectedGender));
            }

            /// <summary>
            /// Test to verify that the Gender property fails length validation with an invalid gender value.
            /// </summary>
            [Test]
            public void Player_Gender_Length_Validation_Fail()
            {
                // Arrange
                var invalidGender = "Female";
                var player = new Player { Gender = invalidGender };
                var genderPropertyName = nameof(Player.Gender);
                var genderProperty = typeof(Player).GetProperty(genderPropertyName);

                if (genderProperty == null)
                {
                    throw new InvalidOperationException($"Property '{genderPropertyName}' not found on type '{nameof(Player)}'.");
                }

                var validationContext = new ValidationContext(player) { MemberName = genderProperty.Name };
                var validationResults = new List<ValidationResult>();

                // Act
                var isValid = Validator.TryValidateProperty(player.Gender, validationContext, validationResults);

                // Assert
                Assert.Multiple(() =>
                {
                    Assert.That(isValid, Is.False, "Gender length validation should fail.");
                    Assert.That(validationResults, Has.Count.EqualTo(1), "Gender length failure, expected one validation error.");
                    Assert.That(validationResults[0].ErrorMessage, Does.Contain("Gender must be either M, F or O."), "Unexpected error message for gender length validation.");
                });
            }

            /// <summary>
            /// Test to verify that the Handicap property is set correctly.
            /// </summary>
            [Test]
            public void Player_Handicap_Set_Correctly()
            {
                // Arrange
                var expectedHandicap = 12.5;

                // Act
                var player = new Player { Handicap = expectedHandicap };

                // Assert
                Assert.That(player.Handicap, Is.EqualTo(expectedHandicap));
            }

            /// <summary>
            /// Test to verify that the Handicap property fails range validation with an invalid handicap value.
            /// </summary>
            [Test]
            public void Player_Handicap_Range_Validation_Fail()
            {
                // Arrange
                double invalidHandicap = 60;

                // Act
                var player = new Player { Handicap = invalidHandicap };

                // Assert
                Assert.That(player.Handicap, Is.EqualTo(invalidHandicap));
            }
        }
    }
}