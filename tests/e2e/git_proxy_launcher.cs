// Только транспорт argv Windows: cmd.exe раскрывает %CD% в Git --format.
using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;

public static class ForgeGitProxy
{
    static string Quote(string value)
    {
        var text = new StringBuilder("\"");
        int slashes = 0;
        foreach (char ch in value)
        {
            if (ch == '\\') { slashes++; continue; }
            text.Append('\\', ch == '"' ? slashes * 2 + 1 : slashes);
            text.Append(ch);
            slashes = 0;
        }
        text.Append('\\', slashes * 2);
        return text.Append('"').ToString();
    }

    public static int Main(string[] args)
    {
        var path = Path.ChangeExtension(Assembly.GetExecutingAssembly().Location, ".args");
        var prefix = File.ReadAllLines(path);
        var start = new ProcessStartInfo(prefix[0], String.Join(" ", prefix.Skip(1).Concat(args).Select(Quote)));
        // Только для gate удаления: ожидающий proxy не удерживает linked cwd.
        var stable = Environment.GetEnvironmentVariable("FORGE_GIT_PROXY_STABLE_CWD");
        if (!String.IsNullOrEmpty(stable))
        {
            start.EnvironmentVariables["FORGE_GIT_PROXY_ORIGINAL_CWD"] = Environment.CurrentDirectory;
            Environment.CurrentDirectory = stable;
            start.WorkingDirectory = stable;
        }
        start.UseShellExecute = false;
        start.CreateNoWindow = true;
        // При CreateNoWindow дочернему процессу нужны явные pipe handles.
        // Копируем байты, без декодирования Git records/ANSI в текст.
        start.RedirectStandardOutput = true;
        start.RedirectStandardError = true;
        using (var child = Process.Start(start))
        {
            var output = child.StandardOutput.BaseStream.CopyToAsync(Console.OpenStandardOutput());
            var errors = child.StandardError.BaseStream.CopyToAsync(Console.OpenStandardError());
            child.WaitForExit();
            Task.WaitAll(output, errors);
            return child.ExitCode;
        }
    }
}
