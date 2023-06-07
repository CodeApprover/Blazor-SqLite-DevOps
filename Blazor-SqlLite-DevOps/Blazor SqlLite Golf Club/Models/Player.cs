using System.ComponentModel.DataAnnotations;

namespace Blazor_SqlLite_Golf_Club.Models;

/// <summary>
///     Represents a player in the golf club.
/// </summary>
public class Player
{
    /// <summary>
    ///     Gets or sets the player's unique identifier.
    /// </summary>
    [Key]
    public int PlayerId { get; set; }

    /// <summary>
    ///     Gets or sets the player's first name.
    /// </summary>
    [Required(ErrorMessage = "First name is required.")]
    [StringLength(10, MinimumLength = 1, ErrorMessage = "First name must be 1 to 10 characters.")]
    public string Firstname { get; set; } = string.Empty;

    /// <summary>
    ///     Gets or sets the player's surname.
    /// </summary>
    [Required(ErrorMessage = "Surname is required.")]
    [StringLength(10, MinimumLength = 1, ErrorMessage = "Surname must be 1 to 10 characters.")]
    public string Surname { get; set; } = string.Empty;

    /// <summary>
    ///     Gets or sets the player's email address.
    /// </summary>
    [Required(ErrorMessage = "Email is required.")]
    [EmailAddress(ErrorMessage = "Invalid email address.")]
    [StringLength(30, MinimumLength = 5, ErrorMessage = "Email must be 5 to 30 characters.")]
    public string Email { get; set; } = string.Empty;

    /// <summary>
    ///     Gets or sets the player's gender.
    /// </summary>
    [Required(ErrorMessage = "Gender is required.")]
    [StringLength(1, MinimumLength = 1, ErrorMessage = "Gender must be either M, F or O")]
    public string Gender { get; set; } = string.Empty;

    /// <summary>
    ///     Gets or sets the player's handicap.
    /// </summary>
    [Required(ErrorMessage = "Handicap is required.")]
    [Range(1, 50, ErrorMessage = "Handicap must be between 1 and 50.")]
    public double Handicap { get; set; }
}