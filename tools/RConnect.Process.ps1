# A process-local foreground-performance policy for the games we start.
# Does not set priority/affinity, change power plans, or find other game PIDs.
if (-not ('RConnectLauncher.NativePower' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
namespace RConnectLauncher {
    public static class NativePower {
        [StructLayout(LayoutKind.Sequential)]
        public struct PowerState { public uint Version, ControlMask, StateMask; }
        [DllImport("kernel32.dll", SetLastError=true)]
        private static extern bool GetProcessInformation(IntPtr process, int kind, ref PowerState state, uint size);
        [DllImport("kernel32.dll", SetLastError=true)]
        private static extern bool SetProcessInformation(IntPtr process, int kind, ref PowerState state, uint size);
        public static PowerState Read(Process process) {
            var state = new PowerState { Version=1 };
            if (!GetProcessInformation(process.Handle, 4, ref state, 12))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            return state;
        }
        public static PowerState KeepResponsive(Process process) {
            var state = Read(process);
            // Explicit HighQoS: opt out of EXECUTION_SPEED throttling only.
            state.ControlMask |= 1;
            state.StateMask &= ~1u;
            if (!SetProcessInformation(process.Handle, 4, ref state, 12))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            state = Read(process);
            if ((state.ControlMask & 1)==0 || (state.StateMask & 1)!=0)
                throw new InvalidOperationException("The process performance policy was not applied.");
            return state;
        }
    }
}
'@
}

function Start-RConnectWindow {
    param([Parameter(Mandatory=$true)][string]$GameRoot,
          [Parameter(Mandatory=$true)][string]$Descriptor,
          [string]$AdlPath)
    $rcRoot = (Resolve-Path -LiteralPath $GameRoot).Path.TrimEnd('\')
    $rcDescriptor = (Resolve-Path -LiteralPath $Descriptor).Path
    if (-not $AdlPath) { $AdlPath = Join-Path $rcRoot 'adl64.exe' }
    $rcAdl = (Resolve-Path -LiteralPath $AdlPath).Path
    $rcRuntime = (Resolve-Path -LiteralPath (Join-Path (Split-Path -Parent $rcAdl) 'runtimes/air/win64')).Path
    # Start-Process joins its argument array, so explicitly quote every path.
    $rcArguments = @('-runtime', ('"' + $rcRuntime + '"'), ('"' + $rcDescriptor + '"'), ('"' + $rcRoot + '"'))
    $rcProcess = Start-Process -FilePath $rcAdl -ArgumentList $rcArguments -WorkingDirectory $rcRoot -WindowStyle Hidden -PassThru
    if ($rcProcess.WaitForExit(750)) {
        if ($rcProcess.ExitCode -eq 1) { throw 'This game profile is already running. Close that window before using this launcher.' }
        throw ('AIR could not start (exit ' + $rcProcess.ExitCode + ').')
    }
    try { [void][RConnectLauncher.NativePower]::KeepResponsive($rcProcess) }
    catch {
        # Leave the newly opened game usable; do not claim the policy succeeded.
        Write-Warning ('The game started, but background performance could not be enabled: ' + $_.Exception.Message)
    }
    return $rcProcess
}
