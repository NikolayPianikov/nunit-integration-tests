namespace nunit.integration.tests.Dsl
{
    using System;
    using System.Diagnostics;
    using System.IO;
    using System.Linq;
    using System.Text;

    internal class NUnitRunner
    {
        public TestSession Run(TestContext ctx, CommandLineSetup setup)
        {
            var processesBefore = Process.GetProcesses().Select(i => i.Id).ToList();

            var cmd = Path.Combine(ctx.SandboxPath, "run.cmd");
            File.WriteAllText(
                cmd,
                $"@pushd \"{ctx.CurrentDirectory}\""
                + Environment.NewLine + $"\"{setup.ToolName}\" {setup.Arguments}"
                + Environment.NewLine + "@set exitCode=%errorlevel%"
                + Environment.NewLine + "@popd"
                + Environment.NewLine + "@exit /b %exitCode%");

            var process = new Process();
            process.StartInfo.FileName = cmd;
            process.StartInfo.UseShellExecute = false;
            process.StartInfo.WindowStyle = ProcessWindowStyle.Hidden;
            process.StartInfo.CreateNoWindow = true;
            process.StartInfo.RedirectStandardOutput = true;
            foreach (var envVariable in setup.EnvVariables)
            {
                process.StartInfo.EnvironmentVariables[envVariable.Key] = envVariable.Value;
            }

            foreach (var artifact in setup.Artifacts)
            {
                File.WriteAllText(artifact.FileName, artifact.Content);
            }

            process.Start();
            var finish = false;
            var output = new StringBuilder();
            while (!finish && !process.WaitForExit(1))
            {
                do
                {
                    var readLineTask = process.StandardOutput.ReadLineAsync();
                    if (!readLineTask.Wait(100))
                    {
                        finish = true;
                        break;
                    }

                    var line = readLineTask.Result;
                    if (line != null)
                    {
                        output.AppendLine(line);
                    }
                    else
                    {
                        break;
                    }
                }
                while (true);                
            }
            
            process.WaitForExit();

            var processesAfter = (
                from processItem in Process.GetProcesses()
                where !processesBefore.Contains(processItem.Id)
                select processItem).ToList();

            return new TestSession(ctx, process.ExitCode, output.ToString(), processesAfter);
        }        
    }
}
