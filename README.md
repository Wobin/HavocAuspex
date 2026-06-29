# Havoc Auspex

A shipboard cogitator-link for your strike team: each member runs Havoc Auspex (or the thin companion Havoc Auspex Transmitter) and it collates everyone's current Havoc order; rank, charges remaining, location, and circumstances into a single readout on the Havoc page before you launch.

## Installation

This package bundles the peer-networking plugin (`darktide_plugin_rtc.dll`). Installing through Vortex deploys both halves automatically:

- `mods/Havoc Auspex/` - the mod itself (added to `mod_load_order.txt` by Vortex).
- `binaries/plugins/darktide_plugin_rtc.dll` - the native transport, auto-loaded by the engine on launch.

For a manual install, copy the `mods/Havoc Auspex` folder into your Darktide `mods/` directory and copy `darktide_plugin_rtc.dll` into `binaries/plugins/`. Some antivirus software may flag the unsigned plugin; allow it if so.
