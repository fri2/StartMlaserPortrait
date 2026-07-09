@echo off
setlocal

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$BatchPath = $env:START_MLASER_BATCH_PATH; if ([string]::IsNullOrWhiteSpace($BatchPath)) { $BatchPath = '%~f0' }; $Marker = '# POWERSHELL' + '_BEGIN'; $Content = Get-Content -LiteralPath $BatchPath -Raw; $Parts = $Content -split [regex]::Escape($Marker), 2; if ($Parts.Count -lt 2) { Write-Error 'PowerShell payload marker not found.'; exit 1 }; & ([scriptblock]::Create($Parts[1])) @args" %*
exit /b %ERRORLEVEL%

# POWERSHELL_BEGIN
$ErrorActionPreference = 'Stop'

# Change this path when installing Mlaser somewhere else.
$MlaserApplicationPath = 'C:\Users\dad\Desktop\Mlaser-v0.0.1.51_Beta\MainApp'

$LaunchDelaySeconds = 5
$Mode = if ($args.Count -gt 0) { $args[0].ToLowerInvariant() } else { '' }

$DisplayApiSource = @'
using System;
using System.Runtime.InteropServices;

public static class DisplaySettings
{
    public const int ENUM_CURRENT_SETTINGS = -1;
    public const int CDS_UPDATEREGISTRY = 0x00000001;
    public const int DISP_CHANGE_SUCCESSFUL = 0;
    public const int DM_DISPLAYORIENTATION = 0x00000080;
    public const int DM_PELSWIDTH = 0x00080000;
    public const int DM_PELSHEIGHT = 0x00100000;
    public const int DMDO_DEFAULT = 0;
    public const int DMDO_90 = 1;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public struct DEVMODE
    {
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

    [DllImport("user32.dll")]
    public static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

    [DllImport("user32.dll")]
    public static extern int ChangeDisplaySettingsEx(string deviceName, ref DEVMODE devMode, IntPtr hwnd, int flags, IntPtr lParam);
}
'@

if (-not ('DisplaySettings' -as [type])) {
    Add-Type -TypeDefinition $DisplayApiSource
}

function Get-CurrentDisplayMode {
    $devMode = New-Object DisplaySettings+DEVMODE
    $devMode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($devMode)

    if (-not [DisplaySettings]::EnumDisplaySettings($null, [DisplaySettings]::ENUM_CURRENT_SETTINGS, [ref]$devMode)) {
        throw 'Could not read the current display settings.'
    }

    return $devMode
}

function Set-DisplayOrientation {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Landscape', 'Portrait')]
        [string] $Orientation
    )

    $devMode = Get-CurrentDisplayMode
    $targetOrientation = if ($Orientation -eq 'Portrait') {
        [DisplaySettings]::DMDO_90
    } else {
        [DisplaySettings]::DMDO_DEFAULT
    }

    $isCurrentlyLandscape = $devMode.dmDisplayOrientation -eq [DisplaySettings]::DMDO_DEFAULT
    $willBeLandscape = $targetOrientation -eq [DisplaySettings]::DMDO_DEFAULT

    if ($isCurrentlyLandscape -ne $willBeLandscape) {
        $oldWidth = $devMode.dmPelsWidth
        $devMode.dmPelsWidth = $devMode.dmPelsHeight
        $devMode.dmPelsHeight = $oldWidth
    }

    $devMode.dmDisplayOrientation = $targetOrientation
    $devMode.dmFields = [DisplaySettings]::DM_DISPLAYORIENTATION -bor [DisplaySettings]::DM_PELSWIDTH -bor [DisplaySettings]::DM_PELSHEIGHT

    $result = [DisplaySettings]::ChangeDisplaySettingsEx($null, [ref]$devMode, [IntPtr]::Zero, [DisplaySettings]::CDS_UPDATEREGISTRY, [IntPtr]::Zero)
    if ($result -ne [DisplaySettings]::DISP_CHANGE_SUCCESSFUL) {
        throw "Display rotation failed with code $result."
    }
}

function Get-MlaserLaunchTarget {
    param(
        [Parameter(Mandatory)]
        [string] $ApplicationPath
    )

    if (Test-Path -LiteralPath $ApplicationPath -PathType Leaf) {
        return (Get-Item -LiteralPath $ApplicationPath).FullName
    }

    if (Test-Path -LiteralPath "$ApplicationPath.exe" -PathType Leaf) {
        return (Get-Item -LiteralPath "$ApplicationPath.exe").FullName
    }

    if (Test-Path -LiteralPath $ApplicationPath -PathType Container) {
        $directExe = Join-Path -Path $ApplicationPath -ChildPath 'MainApp.exe'
        if (Test-Path -LiteralPath $directExe -PathType Leaf) {
            return (Get-Item -LiteralPath $directExe).FullName
        }

        $candidate = Get-ChildItem -LiteralPath $ApplicationPath -Filter '*.exe' -File | Select-Object -First 1
        if ($null -ne $candidate) {
            return $candidate.FullName
        }
    }

    throw "Mlaser executable not found from path: $ApplicationPath"
}

function Start-Mlaser {
    $launchTarget = Get-MlaserLaunchTarget -ApplicationPath $MlaserApplicationPath
    $workingDirectory = Split-Path -Path $launchTarget -Parent
    Start-Process -FilePath $launchTarget -WorkingDirectory $workingDirectory
}

switch ($Mode) {
    '' {
        $exitCode = 0
        try {
            Set-DisplayOrientation -Orientation Portrait
            Start-Mlaser
            Start-Sleep -Seconds $LaunchDelaySeconds
        } catch {
            $exitCode = 1
            Write-Error $_
        } finally {
            try {
                Set-DisplayOrientation -Orientation Landscape
            } catch {
                $exitCode = 1
                Write-Error $_
            }
        }
        exit $exitCode
    }
    'toggle' {
        $currentMode = Get-CurrentDisplayMode
        if ($currentMode.dmDisplayOrientation -eq [DisplaySettings]::DMDO_DEFAULT) {
            Set-DisplayOrientation -Orientation Portrait
        } else {
            Set-DisplayOrientation -Orientation Landscape
        }
        exit 0
    }
    'portrait' {
        Set-DisplayOrientation -Orientation Portrait
        exit 0
    }
    { $_ -in @('landscape', 'paysage') } {
        Set-DisplayOrientation -Orientation Landscape
        exit 0
    }
    default {
        Write-Host 'Usage: StartMlaserPortrait.bat [toggle|portrait|landscape|paysage]'
        exit 2
    }
}
