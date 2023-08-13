// <copyright file="ErrorModel.cshtml.cs" company="CodeApprover">
// Copyright (c) CodeApprover. All rights reserved.
// </copyright>

namespace Blazor_SqLite_Golf_Club.Pages
{
    using System.Diagnostics;
    using Microsoft.AspNetCore.Mvc;
    using Microsoft.AspNetCore.Mvc.RazorPages;
    using Microsoft.Extensions.Logging;

    /// <summary>
    /// Represents the model for the error page.
    /// </summary>
    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    [IgnoreAntiforgeryToken]
    public class ErrorModel : PageModel
    {
        private readonly ILogger<ErrorModel> logger;

        /// <summary>
        /// Initializes a new instance of the <see cref="ErrorModel"/> class.
        /// </summary>
        /// <param name="logger">The logger used for logging.</param>
        public ErrorModel(ILogger<ErrorModel> logger) => this.logger = logger;

        /// <summary>
        /// Gets or sets the request ID for the error.
        /// </summary>
        public string? RequestId { get; set; }

        /// <summary>
        /// Gets a value indicating whether to show the request ID.
        /// </summary>
        public bool ShowRequestId => !string.IsNullOrEmpty(this.RequestId);

        /// <summary>
        /// Called when the error page is requested.
        /// </summary>
        public void OnGet() => this.RequestId = Activity.Current?.Id ?? this.HttpContext.TraceIdentifier;
    }
}
