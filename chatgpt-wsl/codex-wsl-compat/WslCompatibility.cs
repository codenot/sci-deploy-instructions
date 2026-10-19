// Compatibility launcher for Codex Desktop 26.1013.3656 and WSL 3.0.3.
// Only removes the unsupported literal argument pair: --cd .
// All other arguments and process standard handles pass through unchanged.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
internal static class WslCompatibility {
    private static string Quote(string value) {
        if (value.Length > 0 && value.IndexOfAny(new char[] { ' ', '\t', '\n', '\v', '"' }) < 0) return value;
        var result = new StringBuilder("\"");
        int slashes = 0;
        foreach (char ch in value) {
            if (ch == '\\') { slashes++; continue; }
            if (ch == '"') { result.Append('\\', slashes * 2 + 1); result.Append('"'); slashes = 0; continue; }
            result.Append('\\', slashes); slashes = 0; result.Append(ch);
        }
        result.Append('\\', slashes * 2); result.Append('"');
        return result.ToString();
    }
    private static int Main(string[] args) {
        var forwarded = new List<string>();
        bool optionsEnded = false;
        for (int i = 0; i < args.Length; i++) {
            if (!optionsEnded && args[i] == "--cd" && i + 1 < args.Length && args[i + 1] == ".") { i++; continue; }
            forwarded.Add(Quote(args[i]));
            if (args[i] == "--" || args[i] == "--exec" || args[i] == "-e") optionsEnded = true;
        }
        string systemDirectory = Environment.GetFolderPath(Environment.SpecialFolder.System);
        var start = new ProcessStartInfo(Path.Combine(systemDirectory, "wsl.exe"), String.Join(" ", forwarded.ToArray()));
        start.UseShellExecute = false;
        start.CreateNoWindow = false;
        start.WorkingDirectory = Environment.CurrentDirectory;
        try {
            using (Process process = Process.Start(start)) { process.WaitForExit(); return process.ExitCode; }
        } catch (Exception error) { Console.Error.WriteLine("Codex WSL compatibility launcher: " + error.Message); return 1; }
    }
}
