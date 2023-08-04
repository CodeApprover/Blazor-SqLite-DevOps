// <copyright file="WeatherForecast.cs" company="CodeApprover">
// Copyright (c) CodeApprover. All rights reserved.
// </copyright>

#nullable enable

namespace Blazor_SqlLite_Golf_Club.Data
{
    /// <summary>
    /// Represents a weather forecast with date, temperature, and summary.
    /// </summary>
    public class WeatherForecast
    {
        /// <summary>
        /// Gets or sets the date of the weather forecast.
        /// </summary>
        public DateOnly Date { get; set; }

        /// <summary>
        /// Gets or sets the temperature in Celsius for the weather forecast.
        /// </summary>
        public int TemperatureC { get; set; }

        /// <summary>
        /// Gets the temperature in Fahrenheit for the weather forecast.
        /// </summary>
        public int TemperatureF => 32 + (int)(this.TemperatureC / 0.5556);

        /// <summary>
        /// Gets or sets the summary of the weather forecast.
        /// </summary>
        public string? Summary { get; set; }
    }
}
