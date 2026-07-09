@echo off
setlocal EnableExtensions

rem ============================================================
rem  StartMlaserPortrait.bat
rem  Standalone file: screen rotation + Mlaser launch
rem ============================================================
rem
rem Usage:
rem   Double-click or no argument:
rem       1) rotate the screen to portrait
rem       2) start Mlaser without waiting for it to close
rem       3) wait a few seconds
rem       4) rotate the screen back to landscape
rem
rem   With argument:
rem       StartMlaserPortrait.bat toggle
rem       StartMlaserPortrait.bat portrait
rem       StartMlaserPortrait.bat landscape
rem       StartMlaserPortrait.bat paysage
rem
rem Keyboard shortcut for toggle:
rem   Create a shortcut to this file and add " toggle" at the end of the target.
rem   Example: "C:\Users\dad\Tools\StartMlaserPortrait.bat" toggle
rem ============================================================

set "ACTION=%~1"
if "%ACTION%"=="" set "ACTION=start"

set "MLASER_APP=C:\Users\dad\Desktop\Mlaser-v0.0.1.51_Beta\MainApp"
set "WAIT_SECONDS=3"

set "ROTATE_SELF=%~f0"
set "ROTATE_TMPPS=%TEMP%\StartMlaserPortrait_%RANDOM%_%RANDOM%.ps1"

rem Extract the embedded PowerShell payload to a temporary local .ps1 file.
rem This avoids depending on the current CMD directory, which matters when the
rem batch file is launched from a UNC path such as \\Friportable\Charge\Tools.
rem The marker string is assembled in two pieces so this extraction command does
rem not accidentally split on its own command line.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$marker = '# POWERSHELL_PAYLOAD' + '_BEGIN'; $src = Get-Content -Raw -LiteralPath $env:ROTATE_SELF; $parts = $src -split [regex]::Escape($marker), 2; if ($parts.Count -lt 2) { throw 'PowerShell payload marker not found.' }; Set-Content -LiteralPath $env:ROTATE_TMPPS -Value $parts[1] -Encoding UTF8"
if errorlevel 1 (
    echo Error: could not prepare the temporary PowerShell script.
    pause
    exit /b 1
)

rem Run the temporary PowerShell script, then preserve its exit code before
rem deleting the temporary file.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROTATE_TMPPS%" -Action "%ACTION%" -AppPath "%MLASER_APP%" -WaitSeconds "%WAIT_SECONDS%"
set "ERR=%ERRORLEVEL%"

del "%ROTATE_TMPPS%" >nul 2>nul

if not "%ERR%"=="0" (
    echo.
    echo Error during execution. Exit code: %ERR%
    pause
)

exit /b %ERR%

# POWERSHELL_PAYLOAD_BEGIN
param(
    [ValidateSet("start", "toggle", "portrait", "landscape", "paysage", "portrait-flipped", "landscape-flipped")]
    [string]$Action = "start",

    [string]$AppPath = "C:\Users\dad\Desktop\Mlaser-v0.0.1.51_Beta\MainApp",

    [int]$WaitSeconds = 3
)

# Change this path when installing Mlaser somewhere else.
$MlaserApplicationPath = $AppPath

# The C# block exposes the small part of the Windows display API that is needed
# to read and change the current screen orientation.
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class DisplayRotation
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DEVMODE
    {
        // DEVMODE is the Windows structure used by EnumDisplaySettings and
        // ChangeDisplaySettingsEx. The field order must match the native API.
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmDeviceName;
        public short dmSpecVersion;
        public short dmDriverVersion;
        public short dmSize;
        public short dmDriverExtra;
        public int dmFields;

        public int dmPositionX;
        public int dmPositionY;
        public int dmDisplayOrientation;
        public int dmDisplayFixedOutput;

        public short dmColor;
        public short dmDuplex;
        public short dmYResolution;
        public short dmTTOption;
        public short dmCollate;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel;
        public int dmPelsWidth;
        public int dmPelsHeight;
        public int dmDisplayFlags;
        public int dmDisplayFrequency;
        public int dmICMMethod;
        public int dmICMIntent;
        public int dmMediaType;
        public int dmDitherType;
        public int dmReserved1;
        public int dmReserved2;
        public int dmPanningWidth;
        public int dmPanningHeight;
    }

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern bool EnumDisplaySettings(
        string deviceName,
        int modeNum,
        ref DEVMODE devMode
    );

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int ChangeDisplaySettingsEx(
        string deviceName,
        ref DEVMODE devMode,
        IntPtr hwnd,
        int flags,
        IntPtr lParam
    );

    public static int GetOrientation()
    {
        const int ENUM_CURRENT_SETTINGS = -1;

        DEVMODE dm = new DEVMODE();
        dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));

        // Passing null targets the default display, which is the intended
        // single-screen setup for this launcher.
        if (!EnumDisplaySettings(null, ENUM_CURRENT_SETTINGS, ref dm))
            return -1;

        return dm.dmDisplayOrientation;
    }

    public static int SetOrientation(int target)
    {
        const int ENUM_CURRENT_SETTINGS = -1;
        const int DM_DISPLAYORIENTATION = 0x00000080;
        const int DM_PELSWIDTH = 0x00080000;
        const int DM_PELSHEIGHT = 0x00100000;
        const int CDS_UPDATEREGISTRY = 0x00000001;

        DEVMODE dm = new DEVMODE();
        dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));

        if (!EnumDisplaySettings(null, ENUM_CURRENT_SETTINGS, ref dm))
            return -1;

        int current = dm.dmDisplayOrientation;

        // Width and height must be swapped when moving between landscape-like
        // and portrait-like orientations.
        if ((current % 2) != (target % 2))
        {
            int temp = dm.dmPelsWidth;
            dm.dmPelsWidth = dm.dmPelsHeight;
            dm.dmPelsHeight = temp;
        }

        dm.dmDisplayOrientation = target;
        dm.dmFields = DM_DISPLAYORIENTATION | DM_PELSWIDTH | DM_PELSHEIGHT;

        return ChangeDisplaySettingsEx(null, ref dm, IntPtr.Zero, CDS_UPDATEREGISTRY, IntPtr.Zero);
    }
}
"@

function Set-ScreenOrientation {
    param(
        [ValidateSet("landscape", "portrait", "landscape-flipped", "portrait-flipped")]
        [string]$Mode
    )

    $orientationMap = @{
        # Windows orientation values:
        # 0 = landscape, 1 = portrait, 2 = landscape flipped, 3 = portrait flipped.
        "landscape"         = 0
        "portrait"          = 1
        "landscape-flipped" = 2
        "portrait-flipped"  = 3
    }

    $result = [DisplayRotation]::SetOrientation($orientationMap[$Mode])

    if ($result -ne 0) {
        throw "Failed to change screen orientation to '$Mode'. Exit code: $result"
    }
}

function Toggle-ScreenOrientation {
    $current = [DisplayRotation]::GetOrientation()

    if ($current -lt 0) {
        throw "Could not read the current screen orientation."
    }

    if ($current -eq 0 -or $current -eq 2) {
        # Any landscape state toggles to the normal portrait orientation.
        Set-ScreenOrientation -Mode "portrait"
    }
    else {
        # Any portrait state toggles back to the normal landscape orientation.
        Set-ScreenOrientation -Mode "landscape"
    }
}

function Start-Mlaser {
    param(
        [string]$Path
    )

    # Accept either the exact executable path or the same path without ".exe".
    $candidates = @($Path)

    if (-not $Path.EndsWith(".exe", [StringComparison]::OrdinalIgnoreCase)) {
        $candidates += "$Path.exe"
    }

    $found = $null

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            $found = $candidate
            break
        }
    }

    if ($null -eq $found) {
        throw "Application not found: $Path or $Path.exe"
    }

    Start-Process -FilePath $found | Out-Null
}

try {
    switch ($Action) {
        "toggle" {
            Toggle-ScreenOrientation
        }
        "portrait" {
            Set-ScreenOrientation -Mode "portrait"
        }
        "landscape" {
            Set-ScreenOrientation -Mode "landscape"
        }
        "paysage" {
            # French alias kept for convenience.
            Set-ScreenOrientation -Mode "landscape"
        }
        "portrait-flipped" {
            Set-ScreenOrientation -Mode "portrait-flipped"
        }
        "landscape-flipped" {
            Set-ScreenOrientation -Mode "landscape-flipped"
        }
        "start" {
            $exitCode = 0
            try {
                Set-ScreenOrientation -Mode "portrait"
                Start-Mlaser -Path $MlaserApplicationPath
                Start-Sleep -Seconds $WaitSeconds
            }
            catch {
                $exitCode = 1
                Write-Error $_.Exception.Message
            }
            finally {
                # Always try to restore landscape after the default start flow,
                # even if Mlaser fails to launch after the portrait rotation.
                try {
                    Set-ScreenOrientation -Mode "landscape"
                }
                catch {
                    $exitCode = 1
                    Write-Error $_.Exception.Message
                }
            }
            exit $exitCode
        }
    }

    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
