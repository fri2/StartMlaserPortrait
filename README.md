# StartMlaserPortrait

StartMlaserPortrait is a Windows batch launcher for Mlaser.

The default double-click workflow is:

1. Rotate the main display to portrait.
2. Start Mlaser in the background.
3. Wait a few seconds.
4. Restore the display to landscape.

The script is designed for a Windows system with one NVIDIA-driven display, but it uses the Windows display API rather than relying on the current Command Prompt directory. It can therefore be launched from a normal local folder or from a UNC path such as `\\Friportable\Charge\Tools`.

## Files

- `StartMlaserPortrait.bat`: the launcher script.
- `README.md`: project documentation.
- `LICENSE`: license declaration.

## Configuration

Open `StartMlaserPortrait.bat` and edit this variable near the beginning of the PowerShell section if Mlaser is installed somewhere else:

```powershell
$MlaserApplicationPath = 'C:\Users\dad\Desktop\Mlaser-v0.0.1.51_Beta\MainApp'
```

The value can point to:

- the executable itself,
- the executable path without `.exe`,
- or a folder containing `MainApp.exe`.

## Usage

Double-click:

```cmd
StartMlaserPortrait.bat
```

This rotates to portrait, starts Mlaser, waits, then restores landscape.

Supported command-line modes:

```cmd
StartMlaserPortrait.bat toggle
StartMlaserPortrait.bat portrait
StartMlaserPortrait.bat landscape
StartMlaserPortrait.bat paysage
```

## Robustness Notes

The default mode uses a try/finally-style flow:

- if the display rotation succeeds but Mlaser fails to start, the script still tries to restore landscape;
- if any launch error occurs, the script exits with an error code;
- batch code and PowerShell code are separated by a marker so batch lines are not interpreted as PowerShell;
- the script does not depend on the current Command Prompt working directory.

## License

This project is licensed under `GPL-3.0-only`.
