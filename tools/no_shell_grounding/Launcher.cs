// Direct Windows launcher for the unchanged frozen Thursday diagnostics.
// Build-time tools may use PowerShell; this executable never invokes a shell.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Management;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

internal sealed class Launcher : Form
{
    private readonly TextBox status = new TextBox { Multiline = true, ReadOnly = true, Dock = DockStyle.Fill, ScrollBars = ScrollBars.Vertical };
    private readonly Button close = new Button { Text = "Cancel and close", Dock = DockStyle.Bottom, Height = 36 };
    private readonly JavaScriptSerializer json = new JavaScriptSerializer { MaxJsonLength = Int32.MaxValue };
    private readonly string root = AppDomain.CurrentDomain.BaseDirectory;
    private volatile bool cancelled;
    private volatile bool finished;
    private string output;
    private int result;
    private readonly bool verifyOnly;
    private readonly bool exitWhenDone;
#if LAB
    private static readonly bool IsLab = true;
#else
    private static readonly bool IsLab = false;
#endif

    [STAThread]
    private static int Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        using (var window = new Launcher(args)) { Application.Run(window); return window.result; }
    }

    private Launcher(string[] args)
    {
        verifyOnly = args.Contains("--verify-only");
        exitWhenDone = args.Contains("--exit-when-done") || verifyOnly;
        Text = IsLab ? "Visual Grounding Lab" : "Work Laptop Matrix";
        ClientSize = new Size(700, 240);
        StartPosition = FormStartPosition.Manual;
        var screen = Screen.AllScreens.FirstOrDefault(s => !s.Primary) ?? Screen.PrimaryScreen;
        Location = new Point(screen.WorkingArea.X + 40, screen.WorkingArea.Y + 40);
        Controls.Add(status);
        Controls.Add(close);
        close.Click += delegate { Close(); };
        FormClosing += delegate(object sender, FormClosingEventArgs e) {
            if (!finished) { cancelled = true; e.Cancel = true; Log("Cancelling; partial results will be retained."); }
        };
        Shown += delegate { new Thread(Run) { IsBackground = true }.Start(); };
    }

    private void Log(string text)
    {
        if (!IsDisposed && IsHandleCreated) BeginInvoke((Action)delegate { status.AppendText(text + Environment.NewLine); });
    }

    private void Save(string path, object value)
    {
        File.WriteAllText(path, json.Serialize(value), new UTF8Encoding(false));
    }

    private static string Hash(string path)
    {
        using (var sha = SHA256.Create())
        using (var stream = File.OpenRead(path))
            return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", "");
    }

    // Windows CreateProcess quoting, including paths ending in a backslash.
    internal static string Quote(string value)
    {
        var text = new StringBuilder("\"");
        int slashes = 0;
        foreach (char character in value) {
            if (character == '\\') { slashes++; continue; }
            if (character == '"') text.Append('\\', slashes * 2 + 1);
            else text.Append('\\', slashes);
            text.Append(character);
            slashes = 0;
        }
        text.Append('\\', slashes * 2);
        return text.Append('"').ToString();
    }

    private string PrepareRuntime()
    {
        var manifest = json.Deserialize<Dictionary<string, object>>(File.ReadAllText(Path.Combine(root, "payload-manifest.json")));
        var files = ((System.Collections.IEnumerable)manifest["files"]).Cast<Dictionary<string, object>>().ToArray();
        string runtime = Path.Combine(root, "Results", "Runtime");
        int copied = 0;
        foreach (Dictionary<string, object> entry in files) {
            if (cancelled) throw new OperationCanceledException();
            string relative = (string)entry["path"];
            string source = Path.GetFullPath(Path.Combine(root, "Frozen Payload", relative));
            string prefix = Path.GetFullPath(Path.Combine(root, "Frozen Payload")) + Path.DirectorySeparatorChar;
            if (!source.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("Unsafe manifest path.");
            string expected = (string)entry["sha256"];
            if (!File.Exists(source) || Hash(source) != expected) throw new InvalidDataException("Frozen payload mismatch: " + relative);
            string target = Path.Combine(runtime, relative);
            Directory.CreateDirectory(Path.GetDirectoryName(target));
            if (!File.Exists(target) || Hash(target) != expected) {
                File.Copy(source, target, true);
                File.SetLastWriteTimeUtc(target, File.GetLastWriteTimeUtc(source));
                if (Hash(target) != expected) throw new IOException("Runtime copy mismatch: " + relative);
                copied++;
            }
        }
        Save(Path.Combine(output, "payload-verification.json"), new { original_zip_sha256 = manifest["original_zip_sha256"], files = files.Length, copied = copied, all_match = true, runtime = runtime });
        Log("Verified " + files.Length + " frozen files. All runtime writes stay under Results.");
        return runtime;
    }

    private sealed class Job
    {
        public string name, runtime, quality, renderer;
        public bool detailed;
        public Job(string n, string r, string q, string rendererName, bool d = false) { name = n; runtime = r; quality = q; renderer = rendererName; detailed = d; }
    }

    private static Job[] Jobs()
    {
        return new[] {
            new Job("01-prototype-production", "prototype", "production", "forward_plus"),
            new Job("02-endless-production", "endless", "production", "forward_plus", true),
            new Job("03-endless-shadow-light", "endless", "shadow-light", "forward_plus"),
            new Job("04-endless-balanced", "endless", "balanced", "forward_plus"),
            new Job("05-endless-balanced-no-retro", "endless", "balanced-no-retro", "forward_plus"),
            new Job("06-endless-reduced-retro", "endless", "reduced-retro", "forward_plus"),
            new Job("07-endless-mobile-vulkan", "endless", "production", "mobile"),
            new Job("08-endless-compatibility-angle", "endless", "production", "gl_compatibility")
        };
    }

    private List<string> Arguments(Job job, string project, string destination, bool interactive)
    {
        var args = new List<string> { "--path", project, "--rendering-method", job.renderer, "--rendering-driver",
            job.renderer == "gl_compatibility" ? "opengl3_angle" : "vulkan" };
        var screen = Screen.AllScreens.FirstOrDefault(s => !s.Primary);
        if (screen != null) {
            // Godot measures from the virtual desktop's top-left; WinForms
            // uses primary-relative coordinates, which can be negative.
            Rectangle desktop = SystemInformation.VirtualScreen;
            args.AddRange(new[] { "--position", (screen.Bounds.X - desktop.X + 20) + "," + (screen.Bounds.Y - desktop.Y + 30) });
        }
        args.AddRange(new[] { "--script", "res://tests/grounding_lab.gd", "--", "--seed=18", "--retro=production", "--profile-stages", "--grounding-lab",
            "--grounding-task=" + (interactive ? "interactive" : "matrix"), "--grounding-runtime=" + job.runtime,
            "--theme=rooftop_run", "--grounding-quality=" + job.quality, "--grounding-seconds=" + (interactive ? "3" : "2.5"), "--output=" + destination });
        if (job.quality == "balanced-no-retro") args.Add("--grounding-retro=off");
        if (job.quality == "reduced-retro") args.Add("--grounding-retro=n64");
        if (job.detailed) args.Add("--grounding-detailed");
        return args;
    }

    private static object[] Query(string type, params string[] fields)
    {
        var rows = new List<object>();
        using (var query = new ManagementObjectSearcher("SELECT " + String.Join(",", fields) + " FROM " + type))
        using (var collection = query.Get())
            foreach (ManagementObject item in collection) {
                var row = new Dictionary<string, object>();
                foreach (string field in fields) row[field] = item[field];
                rows.Add(row);
                item.Dispose();
            }
        return rows.ToArray();
    }

    private void Machine()
    {
        var machine = new Dictionary<string, object> { { "captured_at", DateTimeOffset.Now.ToString("o") }, { "computer", Environment.MachineName }, { "logical_processors", Environment.ProcessorCount } };
        try {
            machine["gpu"] = Query("Win32_VideoController", "Name", "DriverVersion", "AdapterRAM", "VideoModeDescription");
            machine["cpu"] = Query("Win32_Processor", "Name", "NumberOfCores", "NumberOfLogicalProcessors");
            machine["windows"] = Query("Win32_OperatingSystem", "Caption", "Version", "BuildNumber", "TotalVisibleMemorySize");
        } catch (Exception error) { machine["hardware_query_error"] = error.Message; }
        Save(Path.Combine(output, "machine.json"), machine);
    }

    private void Probe(Job job, string project, string destination, int timeout, bool interactive)
    {
        Directory.CreateDirectory(destination);
        var other = new List<object>();
        foreach (Process candidate in Process.GetProcesses()) using (candidate) {
            try { if (Regex.IsMatch(candidate.ProcessName, "^(Godot|Sonic Spinball Runners)", RegexOptions.IgnoreCase)) other.Add(new { Id = candidate.Id, ProcessName = candidate.ProcessName }); }
            catch (InvalidOperationException) { }
        }
        if (other.Count > 0) {
            Save(Path.Combine(destination, "concurrent-processes.json"), other);
            throw new InvalidOperationException("Another Godot/editor/lab process is running. Close it before starting this matrix.");
        }
        var args = Arguments(job, project, destination, interactive);
        var hashes = new Dictionary<string, string>();
        foreach (string relative in new[] { "tests/grounding_lab.gd", "scripts/diagnostics/render_audit.gd", "scripts/diagnostics/render_sampler.gd", "scripts/diagnostics/grounding_control.gd", "scripts/diagnostics/scenery_shadow_trial.gd" }) hashes[relative] = Hash(Path.Combine(project, relative));
        string profile = Path.Combine(root, "Results", "diagnostic-user");
        var start = new ProcessStartInfo(Path.Combine(project, "Sonic Spinball Runners.exe"), String.Join(" ", args.Select(Quote))) {
            WorkingDirectory = project, UseShellExecute = false, CreateNoWindow = true,
            WindowStyle = interactive ? ProcessWindowStyle.Normal : ProcessWindowStyle.Hidden,
            RedirectStandardOutput = true, RedirectStandardError = true
        };
        foreach (var setting in new[] { new[] { "APPDATA", "Roaming" }, new[] { "LOCALAPPDATA", "Local" } }) {
            string directory = Path.Combine(profile, setting[1]);
            Directory.CreateDirectory(directory);
            start.EnvironmentVariables[setting[0]] = directory;
        }
        var errors = new StringBuilder();
        var guard = new object();
        bool timedOut = false, scriptError = false;
        var clock = Stopwatch.StartNew();
        using (var stdout = new StreamWriter(Path.Combine(destination, "console.log"), false, new UTF8Encoding(false)) { AutoFlush = true })
        using (var stderr = new StreamWriter(Path.Combine(destination, "errors.log"), false, new UTF8Encoding(false)) { AutoFlush = true })
        using (var process = new Process { StartInfo = start }) {
            process.OutputDataReceived += delegate(object sender, DataReceivedEventArgs e) { if (e.Data != null) lock (guard) stdout.WriteLine(e.Data); };
            process.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e) { if (e.Data != null) lock (guard) { stderr.WriteLine(e.Data); errors.AppendLine(e.Data); } };
            process.Start();
            var handle = process.Handle;
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();
            while (!process.WaitForExit(500)) {
                lock (guard) scriptError = errors.ToString().Contains("SCRIPT ERROR:");
                timedOut = !interactive && clock.Elapsed.TotalSeconds > timeout;
                if (cancelled || scriptError || timedOut) {
                    if (cancelled) { process.CloseMainWindow(); if (process.WaitForExit(3000)) break; }
                    process.Kill();
                    break;
                }
            }
            process.WaitForExit(); // Also drain redirected asynchronous output.
            string allErrors;
            lock (guard) allErrors = errors.ToString();
            scriptError = allErrors.Contains("SCRIPT ERROR:");
            Save(Path.Combine(destination, "process.json"), new {
                renderer_requested = job.renderer, driver_requested = job.renderer == "gl_compatibility" ? "opengl3_angle" : "vulkan",
                arguments = args, elapsed_seconds = clock.Elapsed.TotalSeconds, process_cpu_seconds = process.TotalProcessorTime.TotalSeconds,
                exit_code = process.ExitCode, timed_out = timedOut, script_error = scriptError, cancelled = cancelled,
                instrumentation_sha256 = hashes, cache_directory = profile, child_pid = process.Id,
                source = "Frozen engine launched directly with UseShellExecute=false. CPU time includes startup, all phases and cleanup. Engine/driver caches may be warm; graphics preferences have a fresh explicit path."
            });
            if (cancelled) throw new OperationCanceledException("Cancelled; partial results retained.");
            if (timedOut) throw new TimeoutException("Diagnostic exceeded " + timeout + " seconds; partial results retained.");
            if (process.ExitCode != 0) throw new InvalidOperationException("Diagnostic failed with exit code " + process.ExitCode);
            if (Regex.IsMatch(allErrors, "SCRIPT ERROR:|^ERROR:", RegexOptions.Multiline)) throw new InvalidOperationException("Diagnostic logged errors; see errors.log.");
        }
    }

    private void Run()
    {
        try {
            output = Path.Combine(root, "Results", (IsLab ? "Visual-Lab-" : "Work-Laptop-") + DateTime.Now.ToString("yyyyMMdd-HHmmss-fff", CultureInfo.InvariantCulture));
            Directory.CreateDirectory(output);
            Log("Verifying the frozen package. No shell, installation or administrator access is used.");
            string project = PrepareRuntime();
            Machine();
            var jobs = IsLab ? new[] { new Job("rooftop_run", "prototype", "production", "forward_plus") } : Jobs();
            Save(Path.Combine(output, "command-plan.json"), jobs.Select(j => new { name = j.name, arguments = Arguments(j, project, Path.Combine(output, j.name), IsLab), timeout_seconds = IsLab ? 0 : (j.renderer == "gl_compatibility" ? 420 : 240), detailed = j.detailed }).ToArray());
            if (!verifyOnly) {
                var statuses = new List<object>();
                var clock = Stopwatch.StartNew();
                foreach (Job job in jobs) {
                    int remaining = (int)Math.Round(20 * 60 - clock.Elapsed.TotalSeconds, MidpointRounding.ToEven);
                    if (cancelled) { statuses.Add(new { name = job.name, status = "cancelled" }); result = 1; break; }
                    if (!IsLab && remaining < 20) { statuses.Add(new { name = job.name, status = "skipped_total_time_limit" }); result = 1; continue; }
                    Log("Running " + job.name + " (" + (statuses.Count + 1) + "/" + jobs.Length + ")");
                    try {
                        Probe(job, project, Path.Combine(output, job.name), Math.Min(job.renderer == "gl_compatibility" ? 420 : 240, remaining), IsLab);
                        statuses.Add(new { name = job.name, status = "complete" });
                    } catch (Exception error) { result = 1; statuses.Add(new { name = job.name, status = "failed", error = error.Message }); Log(error.Message); }
                    Save(Path.Combine(output, "matrix-status.json"), statuses);
                }
                Save(Path.Combine(output, "matrix-status.json"), statuses);
                File.WriteAllText(Path.Combine(output, "RETURN THIS FOLDER.txt"), "Return this entire folder, including failed or partial runs.\r\n" + output + "\r\nThe actual renderer and GPU are in report.json and console.log. The matrix retains the frozen eight cases and 20-minute budget.\r\n");
            }
            Log((result == 0 ? "Finished." : "Finished with failures or partial results.") + Environment.NewLine + output);
        } catch (Exception error) {
            result = 1;
            if (output != null && Directory.Exists(output)) File.WriteAllText(Path.Combine(output, "launcher-error.txt"), error.ToString());
            Log("Cannot run: " + error.Message);
        } finally {
            finished = true;
            if (!IsDisposed) BeginInvoke((Action)delegate { close.Text = "Close"; if (exitWhenDone || cancelled) Close(); });
        }
    }
}
