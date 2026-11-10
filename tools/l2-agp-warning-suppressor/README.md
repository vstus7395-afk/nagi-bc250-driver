# Lineage II AGP warning suppressor (x86)

A game-local dinput8.dll proxy for the 32-bit Lineage II client.

- Suppresses only a Unicode MessageBoxW whose text contains "AGP is deactivated" (case-insensitive), returning IDOK.
- Forwards all six DirectInput 8 exports to the genuine Windows System32 dinput8.dll.
- Does not change GPU/AGP capabilities, registry values, the NAGI display driver, or gamma-ramp behavior.
- Other message boxes are passed through unchanged.

## Install

Copy the built dinput8.dll beside L2.exe in the game's system directory. Keep the original Windows System32 dinput8.dll untouched.

To undo, remove or rename the game-local proxy DLL.

This is separate from the BC-250 display-driver package. It is not installed into DriverStore and does not replace BUILD27.
