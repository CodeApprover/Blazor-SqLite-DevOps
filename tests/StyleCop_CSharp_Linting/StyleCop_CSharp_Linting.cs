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

            // Display where the cmd will navigate to
            var mainProjectFilePath = "..\\..\\..\\..\\..\\" +
                "development\\Blazor-SqLite-Golf-Club\\Blazor-SqLite-Golf-Club.csproj";
            Console.WriteLine($"Navigating to: {mainProjectFilePath}");

            // Execute build command on the main project
            var buildCommand = $"dotnet build \"{Path.GetFullPath(mainProjectFilePath)}\" "
                + "/p:StyleCopEnabled=true"
                + "/p:StyleCopTreatErrorsAsWarnings=false"
                + "/p:StyleCopForceFullAnalysis=false";

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
