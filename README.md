# Havoc Auspex

A shipboard cogitator-link for your strike team: each member runs Havoc Auspex (or the thin companion Havoc Auspex Transmitter) and it collates everyone's current Havoc order; rank, charges remaining, location, and circumstances into a single readout on the Havoc page before you launch.

## Installation

Pure Lua, no native plugin or binary required. Installing through Vortex deploys the mod automatically (`mods/Havoc Auspex/`, added to `mod_load_order.txt` by Vortex).

For a manual install, copy the `mods/Havoc Auspex` folder into your Darktide `mods/` directory and add `Havoc Auspex` to `mod_load_order.txt`.

Orders are shared through the game's own presence service, so party members' orders appear automatically — even while they are loading, in a mission, or in a different hub instance. If you are upgrading from a version before 1.9.0, the old `darktide_rtc_ffi.dll` / `darktide_plugin_rtc.dll` binaries are no longer used and can be deleted.
