param(
    [string]$Builder = '',
    [switch]$Background,
    [switch]$Wait
)

$ErrorActionPreference = 'Stop'

$source = @'
using System;
using System.Runtime.InteropServices;

[Flags]
public enum ActivateOptions : uint
{
    None = 0x00000000,
    DesignMode = 0x00000001,
    NoErrorUI = 0x00000002,
    NoSplashScreen = 0x00000004
}

[ComImport]
[Guid("2e941141-7f97-4756-ba1d-9decde894a3d")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IApplicationActivationManager
{
    int ActivateApplication(
        [MarshalAs(UnmanagedType.LPWStr)] string appUserModelId,
        [MarshalAs(UnmanagedType.LPWStr)] string arguments,
        ActivateOptions options,
        out uint processId);

    int ActivateForFile(
        [MarshalAs(UnmanagedType.LPWStr)] string appUserModelId,
        IntPtr itemArray,
        [MarshalAs(UnmanagedType.LPWStr)] string verb,
        out uint processId);

    int ActivateForProtocol(
        [MarshalAs(UnmanagedType.LPWStr)] string appUserModelId,
        IntPtr itemArray,
        out uint processId);
}

[ComImport]
[Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C")]
class ApplicationActivationManager
{
}

public static class AppActivator
{
    public static uint Launch(string appUserModelId, string arguments)
    {
        var manager = (IApplicationActivationManager)new ApplicationActivationManager();
        uint processId;
        int result = manager.ActivateApplication(appUserModelId, arguments, ActivateOptions.NoErrorUI, out processId);
        if (result != 0)
        {
            Marshal.ThrowExceptionForHR(result);
        }
        return processId;
    }
}
'@

Add-Type -TypeDefinition $source -Language CSharp

$appId = 'BlenderFoundation.Blender4.5LTS_ppwjx1n5r4v9t!BLENDER'
if ([string]::IsNullOrWhiteSpace($Builder)) {
    $Builder = Join-Path $PSScriptRoot 'build_blind_one_analog_v1.py'
}

$backgroundArgument = if ($Background) { '--background ' } else { '' }
$arguments = $backgroundArgument + '--python "' + $Builder + '"'

$blenderProcessId = [AppActivator]::Launch($appId, $arguments)
Write-Output "Activated Blender build process $blenderProcessId (background=$Background)"

if ($Wait) {
    Wait-Process -Id $blenderProcessId
    Write-Output "Blender build process $blenderProcessId finished"
}
