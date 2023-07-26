// <copyright file="StyleCopLintingTests.cs" company="PlaceholderCompany">
// Copyright (c) PlaceholderCompany. All rights reserved.
// </copyright>

namespace StyleCop_CSharp_Linting
{
    using Microsoft.VisualStudio.TestTools.UnitTesting;
    using System;
    using System.Diagnostics;
    using System.IO;

    /// <summary>
    /// Test class for StyleCop linting on the main project.
    /// </summary>
    [TestClass]
    public class StyleCop_CSharp_Linting
    {
        /// <summary>
        /// Test method to check if the main project builds successfully without warnings treated as errors.
        /// </summary>
        [TestMethod]
        public void TestLintingSuccess()
        {
            // Set the root path of your main project
            var mainProjectFilePath = @"..\..\..\..\Blazor-SqlLite-DevOps\Blazor SqlLite Golf Club";
            mainProjectFilePath = Path.Combine(mainProjectFilePath, "Blazor SqlLite Golf Club.csproj");

            // Display where the cmd will navigate to
            Console.WriteLine($"Navigating to: {mainProjectFilePath}");

            // Execute build command on the main project
            var buildCommand = $"dotnet build \"{Path.GetFullPath(mainProjectFilePath)}\"";

            var processInfo = new ProcessStartInfo
            {
                FileName = "cmd.exe",
                Arguments = $"/C {buildCommand}",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true,
            };

            using (Process process = new Process())
            {
                process.StartInfo = processInfo;
                process.Start();
                var output = process.StandardOutput.ReadToEnd();
                var errorOutput = process.StandardError.ReadToEnd();
                process.WaitForExit();

                // Assert that the build succeeded and there are no StyleCop-related errors or warnings
                Assert.IsTrue(process.ExitCode == 0, $"Build failed. Build output:\n{output}\nError output:\n{errorOutput}");
            }
        }
    }
}
