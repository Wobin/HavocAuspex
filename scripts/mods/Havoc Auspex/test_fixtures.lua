--[[
    Simulation fixtures for Havoc Auspex's local smoke test (/havocauspex_test).
    Each entry mirrors the WIRE payload shape: { name, order } where order is the raw
    current-order table (or nil for "no active order"). Real `flags` keys + real mission
    ids are used so the full client's parse + template resolution runs against actual game
    data, not just the renderer.

    These three fill out the rest of a 4-person party (you + 3) with assorted havoc
    combos that exercise the coloured circumstance icons + tooltips: between them they
    cover every colour in the scheme, one un-coloured circ (renders white), and a
    fading-light circ (to test the hide toggle). Charges + varied rank/location too.
--]]

return {
    {
        name  = "Sgt. Morrow",
        order = {
            rank = 16, map = "lm_scavenge", challenge = 4, resistance = 4, charges = 3,
            flags = {
                ["havoc-circ-bolstering_minions_01"]            = true,
                ["havoc-circ-mutator_havoc_armored_infected"]   = true,
                ["havoc-circ-mutator_havoc_enraged"]            = true,
                ["havoc-circ-mutator_havoc_duplicating_enemies"] = true,
                ["havoc-mods-buff_elites-2"]                    = true,
            },
        },
    },
    {
        name  = "Adept Zola",
        order = {
            rank = 33, map = "dm_propaganda", challenge = 5, resistance = 5, charges = 1,
            flags = {
                ["havoc-circ-mutator_havoc_chaos_rituals"]   = true,
                ["havoc-circ-mutator_havoc_enemies_corrupted"] = true,
                ["havoc-circ-mutator_havoc_tougher_skin"]    = true,
                ["havoc-circ-mutator_stimmed_minions"]       = true,
                ["havoc-mods-horde_spawn_rate_increase-3"]   = true,
                ["havoc-faction-nurgle"]                     = true,
            },
        },
    },
    {
        name  = "Rannick",
        order = {
            rank = 24, map = "hm_strain", challenge = 4, resistance = 5, charges = 5,
            flags = {
                ["havoc-circ-mutator_encroaching_garden"]              = true,
                ["havoc-circ-mutator_havoc_enemies_parasite_headshot"] = true,
                ["havoc-circ-mutator_havoc_rotten_armor"]              = true,
                ["havoc-circ-mutator_increased_difficulty"]            = true,
            },
        },
    },
}
