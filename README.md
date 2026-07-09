# StartMlaserPortrait

StartMlaserPortrait is a standalone Windows batch launcher for Mlaser.

The default double-click workflow is:

1. Rotate the screen to portrait.
2. Start Mlaser without waiting for it to close.
3. Wait a few seconds.
4. Restore the screen to landscape.

The script is designed to work when launched from a local folder or from a UNC path such as `\\Friportable\Charge\Tools`.

## Requirements

No extra NVIDIA utility or third-party dependency is required.

The script only uses components normally available on Windows:

- `cmd.exe` to run the batch file;
- `powershell.exe` to run the embedded PowerShell payload;
- `user32.dll`, through the Windows display API, to change the screen orientation;
- PowerShell `Add-Type` to compile the small embedded C# helper at runtime.

Make sure that:

- Mlaser exists at the configured path, or update `MLASER_APP`;
- PowerShell is not blocked by a very restrictive system policy;
- Windows is allowed to run the batch file from the chosen location, including a UNC path if used.

## Files

- `StartMlaserPortrait.bat`: the launcher script.
- `README.md`: project documentation.
- `LICENSE`: license declaration.

## Configuration

Edit these variables near the beginning of `StartMlaserPortrait.bat` if needed:

```bat
set "MLASER_APP=C:\Users\dad\Desktop\Mlaser-v0.0.1.51_Beta\MainApp"
set "WAIT_SECONDS=3"
```

The internal PowerShell section receives the Mlaser path as:

```powershell
$MlaserApplicationPath = $AppPath
```

The Mlaser path can point to:

- the executable itself,
- or the executable path without `.exe`.

## Usage

Double-click or run without arguments:

```cmd
StartMlaserPortrait.bat
```

For one-click access, create a desktop shortcut to `StartMlaserPortrait.bat`. You can also assign a keyboard shortcut in the shortcut properties, so Windows can launch the application directly from that hotkey.

Supported command-line modes:

```cmd
StartMlaserPortrait.bat toggle
StartMlaserPortrait.bat portrait
StartMlaserPortrait.bat landscape
StartMlaserPortrait.bat paysage
StartMlaserPortrait.bat portrait-flipped
StartMlaserPortrait.bat landscape-flipped
```

## Robustness Notes

The script keeps the same working approach as the original launcher:

- the batch file extracts its embedded PowerShell payload to a temporary `.ps1` file;
- the PowerShell payload performs the display rotation and Mlaser launch;
- the temporary PowerShell file is deleted after execution.

Two robustness fixes are included:

- the payload marker is built in two parts while extracting the script, so the extractor does not accidentally split on its own command line;
- the default `start` action always attempts to restore landscape in a `finally` block, even if Mlaser fails to launch after the screen has been rotated to portrait.

## License

This project is licensed under `GPL-3.0-only`.
