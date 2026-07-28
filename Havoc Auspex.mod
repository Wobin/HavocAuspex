return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Havoc Auspex` encountered an error loading the Darktide Mod Framework.")

		new_mod("Havoc Auspex", {
			mod_script       = "Havoc Auspex/scripts/mods/Havoc Auspex/Havoc Auspex",
			mod_data         = "Havoc Auspex/scripts/mods/Havoc Auspex/Havoc Auspex_data",
			mod_localization = "Havoc Auspex/scripts/mods/Havoc Auspex/Havoc Auspex_localization",
		})
	end,
	load_after = {
		"Vox Manifold",
	},
	require = {
		"Vox Manifold",
	},
	packages = {},
}
