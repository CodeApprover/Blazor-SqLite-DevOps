// <copyright file="Game.cs" company="CodeApprover">
// Copyright (c) CodeApprover. All rights reserved.
// </copyright>

namespace Blazor_SqLite_Golf_Club.Models
{
    using System.ComponentModel.DataAnnotations;

    /// <summary>
    ///     Represents a golf game played by members of the golf club.
    /// </summary>
    public class Game
    {
        /// <summary>
        ///     Gets or sets the unique identifier of the game.
        /// </summary>
        [Key]
        public int GameId { get; set; }

        /// <summary>
        ///     Gets or sets the captain's player ID for the game.
        /// </summary>
        [Required(ErrorMessage = "Captain Id is required.")]
        public int Captain { get; set; }

        /// <summary>
        ///     Gets or sets the second player's player ID for the game.
        /// </summary>
        [Required(ErrorMessage = "Second player Id is required.")]
        public int Player2 { get; set; }

        /// <summary>
        ///     Gets or sets the third player's player ID for the game.
        /// </summary>
        [Required(ErrorMessage = "Third player Id is required.")]
        public int Player3 { get; set; }

        /// <summary>
        ///     Gets or sets the fourth player's player ID for the game.
        /// </summary>
        [Required(ErrorMessage = "Fourth player Id is required.")]
        public int Player4 { get; set; }

        /// <summary>
        ///     Gets or sets the date and time of the game.
        /// </summary>
        [Required(ErrorMessage = "Game time is required.")]
        public DateTime GameTime { get; set; }

        /// <summary>
        ///     Gets or sets the game card for the game.
        /// </summary>
        [StringLength(250, MinimumLength = 0)]
        public string GameCard { get; set; } = string.Empty;
    }
}