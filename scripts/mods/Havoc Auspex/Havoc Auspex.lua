--[[
    Name: Havoc Auspex
    Author: Wobin
    Date: 2026-06-14
    Version: 1.0.0
--]]

local mod = get_mod("Havoc Auspex")

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

local rtc_api
local PROTO = mod
local req_counter = 0
local active = nil

local results_version = 0
local function bump_version() results_version = results_version + 1 end
function mod.results_version() return results_version end

local function status(msg) if mod:get("debug_mode") then mod:echo(msg) end end
local function dbg(msg) if mod:get("debug_mode") then mod:echo("[Havoc Auspex][dbg] " .. msg) end end

local function add_result(id, name, order)
    if not active or active.id ~= id or active.finalized then return end
    if active.order_by_name[name] == nil then
        active.names[#active.names + 1] = name
    end
    active.order_by_name[name] = order or false
    bump_version()
    dbg(("result from %s (%d collected)"):format(name, #active.names))
end

local function finalize()
    if not active or active.finalized then return end
    active.finalized = true
    bump_version()
    if not mod:get("debug_mode") then return end
    mod:echo("[Havoc Auspex] Party havoc orders:")
    if #active.names == 0 then
        mod:echo("  (no responses)")
    else
        for _, name in ipairs(active.names) do
            local order = active.order_by_name[name]
            mod:echo(("  %s: %s"):format(name, order and format_order(order) or "None"))
        end
    end
end

local function local_account_id()
    local acc
    pcall(function()
        local lp = Managers.player and Managers.player:local_player(1)
        acc = lp and lp:account_id()
    end)
    return acc
end

local function count_expected()
    local n = 1
    pcall(function()
        local pim = Managers.party_immaterium
        local members = pim and pim:all_members()
        if type(members) ~= "table" then return end
        local self_acc = local_account_id()
        for _, m in ipairs(members) do
            local acc = m.account_id and m:account_id()
            if acc and acc ~= self_acc and rtc_api and rtc_api.get_player_by_account_id then
                local p = rtc_api.get_player_by_account_id(acc)
                if p and rtc_api.player_has_mod(p, Net.PROTOCOL) then
                    n = n + 1
                end
            end
        end
    end)
    return n
end

local function start_request(simulate)
    req_counter = req_counter + 1
    local id = req_counter
    active = { id = id, order_by_name = {}, names = {}, elapsed = 0, finalized = false }
    bump_version()

    Net.build_self_order(function(order)
        add_result(id, Net.self_name() .. " (you)", order)
    end)

    if simulate then
        active.expected = nil
        local fixtures = mod:io_dofile("Havoc Auspex/scripts/mods/Havoc Auspex/test_fixtures")
        for _, f in ipairs(fixtures or {}) do
            add_result(id, f.name, f.order)
        end
        status("[Havoc Auspex] Simulating party replies…")
    else
        active.expected = count_expected()
        if rawget(_G, "RTC_TEST_ACCEPT_UNKNOWN") then
            active.expected = nil
        end
        if rtc_api then
            rtc_api.send(PROTO, Net.EVENTS.REQUEST, "all", { req_id = id, pv = Net.PV })
        end
        status("[Havoc Auspex] Requesting party havoc orders…")
    end
end

local function on_request(requester_player, data)
    if not requester_player then return end
    local req_id = type(data) == "table" and data.req_id or nil
    dbg("got request, replying")
    Net.build_self_order(function(order)
        rtc_api.send(PROTO, Net.EVENTS.REPLY, requester_player, {
            req_id = req_id, pv = Net.PV, name = Net.self_name(), order = order,
        })
    end)
end

local function on_reply(player, data)
    if type(data) ~= "table" then return end
    if not active or data.req_id ~= active.id then return end
    if data.pv ~= Net.PV then dbg("ignoring reply pv=" .. tostring(data.pv)); return end
    add_result(active.id, data.name or (player and type(player.name) == "function" and player:name()) or "?", data.order)
end

mod.update = function(dt)
    if not active or active.finalized then return end
    active.elapsed = active.elapsed + dt
    if active.expected and #active.names >= active.expected then
        finalize()
    elseif active.elapsed >= (tonumber(mod:get("window_seconds")) or 4) then
        finalize()
    end
end

mod.on_all_mods_loaded = function()
    local make = mod:io_dofile("Havoc Auspex/scripts/mods/Havoc Auspex/rtc_embedded")
    rtc_api = make(mod)
    rtc_api.activate()
    dbg("using embedded rtc transport (party-keyed)")
    rtc_api.register(PROTO, Net.EVENTS.REQUEST, on_request)
    rtc_api.register(PROTO, Net.EVENTS.REPLY, on_reply)
end

mod:command("havocauspex", "Ask your party which havoc orders they have.", function()
    start_request(mod:get("simulate_replies"))
end)

mod:command("havocauspex_test", "Local smoke test: simulate party havoc replies.", function()
    start_request(true)
end)

mod:command("havocauspex_testpeer", "Toggle accepting the headless rtc-test-peer (testing only).", function()
    local on = not rawget(_G, "RTC_TEST_ACCEPT_UNKNOWN")
    rawset(_G, "RTC_TEST_ACCEPT_UNKNOWN", on or nil)
    mod:echo("[Havoc Auspex] RTC test peer acceptance: " .. (on and "ON" or "off"))
end)

function mod.scan_party()
    start_request(mod:get("simulate_replies"))
end

local EMPTY_RESULTS = { scanning = false, finalized = false, rows = {} }
local results_cache, results_cache_ver = nil, -1
function mod.current_results()
    if not active then return EMPTY_RESULTS end
    if results_cache and results_cache_ver == results_version then return results_cache end
    local rows = {}
    for _, name in ipairs(active.names) do
        rows[#rows + 1] = { name = name, order = active.order_by_name[name] }
    end
    results_cache = { scanning = not active.finalized, finalized = active.finalized, rows = rows }
    results_cache_ver = results_version
    return results_cache
end

mod:io_dofile("Havoc Auspex/scripts/mods/Havoc Auspex/havoc_auspex_ui")
