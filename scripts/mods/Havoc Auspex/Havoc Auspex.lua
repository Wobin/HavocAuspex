--[[
    Name: Havoc Auspex
    Author: Wobin
    Date: 2026-07-12
    Version: 1.9.0
--]]

local mod = get_mod("Havoc Auspex")
mod.version = "1.9.0"

local Net = mod:io_dofile("Havoc Auspex/scripts/mods/Havoc Auspex/havoc_net")

local _mission_templates, _circ_templates, _zones
local function load_templates()
    if _mission_templates ~= nil then return end
    local function tryreq(path) local ok, t = pcall(require, path); return (ok and t) or false end
    _mission_templates = tryreq("scripts/settings/mission/mission_templates")
    _circ_templates    = tryreq("scripts/settings/circumstance/circumstance_templates")
    _zones             = tryreq("scripts/settings/zones/zones")
end

local function try_localize(key)
    if type(key) ~= "string" then return nil end
    local ok, s = pcall(function() return Managers.localization:localize(key) end)
    if ok and s and s ~= key and not s:match("^<") then return s end
    return nil
end

local function prettify(s)
    return (tostring(s):gsub("_", " "):gsub("(%a)([%w_]*)", function(a, b) return a:upper() .. b end))
end

local function map_name(map_id)
    if type(map_id) ~= "string" then return "Unknown" end
    load_templates()
    local t = _mission_templates and _mission_templates[map_id]
    if t and t.mission_name then
        local s = try_localize(t.mission_name)
        if s then return s end
    end
    return prettify(map_id)
end

local function map_subtitle(map_id)
    if type(map_id) ~= "string" then return nil end
    load_templates()
    local t = _mission_templates and _mission_templates[map_id]
    if not t then return nil end
    local zone = t.zone_id and _zones and _zones[t.zone_id] and try_localize(_zones[t.zone_id].name)
    if zone then return zone end
    return t.coordinates and try_localize(t.coordinates) or nil
end

local CIRC_COLOR_NAMES = {
    loc_havoc_increased_difficulty_name           = "white",
    loc_havoc_highest_difficulty_name             = "white",
    loc_havoc_bolstering_enemies_name             = "item_rarity_5",
    loc_havoc_encroaching_garden_name             = "blue_violet",
    loc_havoc_mutator_enraged_name                = "ui_red_light",
    loc_havoc_chaos_ritual_name                   = "lime",
    loc_havoc_armored_infected_name               = "steel_blue",
    loc_havoc_enemies_corrupted_name              = "olive",
    loc_havoc_enemies_parasite_headshot_name      = "light_salmon",
    loc_havoc_tougher_skin_name                   = "citadel_ogryn_camo",
    loc_havoc_rotten_armor_name                   = "citadel_nurgling_green",
    loc_havoc_stimmed_minions_name                = "citadel_dorn_yellow",
    loc_circumstance_ember_title                  = "sienna",
    loc_circumstance_toxic_gas_title              = "yellow_green",
    loc_circumstance_toxic_gas_cultist_grenadier_title = "yellow_green",
    loc_circumstance_ventilation_purge_title      = "gray",
    loc_circumstance_ventilation_purge_with_snipers_title = "gray",
    loc_circumstance_darkness_title               = "citadel_nuln_oil",
    loc_circumstance_darkness_hunting_grounds_title = "citadel_nuln_oil",
}

local _color_cache = {}
local function color_by_name(name)
    local cached = _color_cache[name]
    if cached ~= nil then return cached or nil end
    local result = false
    pcall(function()
        if Color and Color[name] then
            local c = Color[name](255, true)
            result = { 255, c[2], c[3], c[4] }
        end
    end)
    _color_cache[name] = result
    return result or nil
end

local function circ_info(id)
    load_templates()
    local display, icon, color
    local t = _circ_templates and _circ_templates[id] and _circ_templates[id].ui
    if t then
        icon = t.icon
        display = try_localize(t.display_name)
        local cname = type(t.display_name) == "string" and CIRC_COLOR_NAMES[t.display_name]
        if cname then color = color_by_name(cname) end
    end
    display = display or prettify(id)
    local is_fading = type(icon) == "string" and icon:find("fading_light", 1, true) ~= nil
    return display, is_fading, icon, color
end

local function parse_circumstances(flags)
    local circs = {}
    if type(flags) ~= "table" then return circs end
    local strs = {}
    for k, v in pairs(flags) do
        local s = (type(k) == "string" and k) or (type(v) == "string" and v) or nil
        if s then strs[#strs + 1] = s end
    end
    table.sort(strs)
    for _, s in ipairs(strs) do
        local cid = s:match("^havoc%-circ%-(.+)$")
        if cid then
            local disp, is_fading, icon, color = circ_info(cid)
            circs[#circs + 1] = { name = disp, fading = is_fading, icon = icon, color = color }
        end
    end
    return circs
end

local function format_order(order)
    if type(order) ~= "table" then return "None" end
    local parts = {}
    local rank_part = "Rank " .. tostring(order.rank or "?")
    if order.charges ~= nil then
        rank_part = rank_part .. (" (%sc)"):format(tostring(order.charges))
    end
    parts[#parts + 1] = rank_part
    parts[#parts + 1] = map_name(order.map)

    local hide_fl = mod:get("hide_fading_light")
    local extras = {}
    for _, c in ipairs(parse_circumstances(order.flags)) do
        if not (hide_fl and c.fading) then extras[#extras + 1] = c.name end
    end
    parts[#parts + 1] = #extras > 0 and table.concat(extras, ", ") or "-"
    return table.concat(parts, " | ")
end

function mod.describe_order(order)
    if type(order) ~= "table" then return nil end
    local hide_fl = mod:get("hide_fading_light")
    local circs = {}
    for _, c in ipairs(parse_circumstances(order.flags)) do
        if not (hide_fl and c.fading) then
            circs[#circs + 1] = { name = c.name, icon = c.icon, fading = c.fading, color = c.color }
        end
    end
    return {
        rank         = order.rank,
        charges      = order.charges,
        location     = map_name(order.map),
        location_sub = map_subtitle(order.map),
        circs        = circs,
    }
end

local Presence = mod:io_dofile("Havoc Auspex/scripts/mods/Havoc Auspex/presence_order")(mod, Net)

local results_version = 0
local function bump_version() results_version = results_version + 1 end
function mod.results_version() return results_version end

local function status(msg) if mod:get("debug_mode") then mod:echo(msg) end end

local sim_rows = nil

local function build_rows()
    local rows = {}
    local party_size = 0
    pcall(function()
        local pim = Managers.party_immaterium
        local members = pim and pim:all_members()
        if type(members) ~= "table" then return end
        local self_name = Net.self_name()
        for i = 1, #members do
            local member = members[i]
            local presence = type(member.presence) == "function" and member:presence()
            if presence then
                party_size = party_size + 1
                if presence:is_myself() then
                    rows[#rows + 1] = { name = self_name .. " (you)", order = Presence.my_order() or false }
                else
                    local order = Presence.member_order(presence)
                    if order ~= nil then
                        local name = member:name()
                        if name == nil or name == "" then name = presence:account_name() end
                        if name == nil or name == "" then name = "?" end
                        rows[#rows + 1] = { name = name, order = order }
                    end
                end
            end
        end
    end)
    if #rows == 0 then
        rows[1] = { name = Net.self_name() .. " (you)", order = Presence.my_order() or false }
        party_size = math.max(party_size, 1)
    end
    return rows, party_size
end

local results_cache, results_cache_ver = nil, -1
function mod.current_results()
    if results_cache and results_cache_ver == results_version then return results_cache end
    local rows, party_size
    if sim_rows then
        rows = sim_rows
    else
        rows, party_size = build_rows()
    end
    results_cache = { scanning = false, finalized = true, rows = rows, party_size = party_size }
    results_cache_ver = results_version
    return results_cache
end

local function load_sim_rows()
    local fixtures = mod:io_dofile("Havoc Auspex/scripts/mods/Havoc Auspex/test_fixtures")
    local rows = { { name = Net.self_name() .. " (you)", order = Presence.my_order() or false } }
    for _, f in ipairs(fixtures or {}) do
        rows[#rows + 1] = { name = f.name, order = f.order }
    end
    sim_rows = rows
    Presence.refresh_own_order()
    bump_version()
    status("[Havoc Auspex] Simulating party replies…")
end

function mod.scan_party()
    if mod:get("simulate_replies") then
        load_sim_rows()
    else
        sim_rows = nil
        Presence.refresh_own_order()
        bump_version()
    end
end

local function on_own_order_changed()
    if sim_rows then
        sim_rows[1].order = Presence.my_order() or false
    end
    bump_version()
end

local MANAGER_EVENTS = {
    event_new_immaterium_entry = "ha_event_new_immaterium_entry",
    party_immaterium_other_members_updated = "ha_event_party_members_updated",
    event_havoc_status_refreshed = "ha_event_havoc_status_refreshed",
}

mod.ha_event_new_immaterium_entry = function() bump_version() end
mod.ha_event_party_members_updated = function() bump_version() end
mod.ha_event_havoc_status_refreshed = function() Presence.refresh_own_order() end

local events_registered = false
local function register_events()
    if events_registered or not Managers.event then return end
    for event_name, method in pairs(MANAGER_EVENTS) do
        Managers.event:register(mod, event_name, method)
    end
    events_registered = true
end

local function unregister_events()
    if not events_registered then return end
    if Managers.event then
        for event_name in pairs(MANAGER_EVENTS) do
            Managers.event:unregister(mod, event_name)
        end
    end
    events_registered = false
end

mod.on_all_mods_loaded = function()
    Presence.activate(on_own_order_changed)
    register_events()
    mod:info(("Havoc Auspex v%s loaded (immaterium presence transport, payload v%d)"):format(
        tostring(mod.version), Presence.PAYLOAD_VERSION))
end

mod.on_enabled = function()
    register_events()
    Presence.refresh_own_order()
end

mod.on_disabled = function()
    unregister_events()
    Presence.clear_published_order()
end

mod.on_unloaded = function()
    unregister_events()
end

mod.on_game_state_changed = function(status_name, state_name)
    if status_name == "enter" and state_name == "StateGameplay" then
        Presence.refresh_own_order()
    end
end

local function echo_report()
    local res = mod.current_results()
    mod:echo("[Havoc Auspex] Party havoc orders:")
    local rows = res.rows
    if #rows == 0 then
        mod:echo("  (no data)")
    else
        for _, row in ipairs(rows) do
            mod:echo(("  %s: %s"):format(row.name, row.order and format_order(row.order) or "None"))
        end
    end
end

mod:command("havocauspex", "Ask your party which havoc orders they have.", function()
    mod.scan_party()
    if mod:get("debug_mode") then echo_report() end
end)

mod:command("havocauspex_test", "Local smoke test: simulate party havoc replies.", function()
    load_sim_rows()
end)

mod:io_dofile("Havoc Auspex/scripts/mods/Havoc Auspex/havoc_auspex_ui") 
