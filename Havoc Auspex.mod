return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Havoc Auspex` encountered an error loading the Darktide Mod Framework.")

		new_mod("Havoc Auspex", {
			mod_script       = "Havoc Auspex/scripts/mods/Havoc Auspex/Havoc Auspex",
			mod_data         = "Havoc Auspex/scripts/mods/Havoc Auspex/Havoc Auspex_data",
			mod_localization = "Havoc Auspex/scripts/mods/Havoc Auspex/Havoc Auspex_localization",
		})
	end,
	-- `rtc` only orders first if it happens to be installed; it is NOT required (embedded).
	load_after = {
		"rtc",
	},
	packages = {},
}
