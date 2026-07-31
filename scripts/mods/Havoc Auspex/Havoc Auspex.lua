--[[
    Name: Havoc Auspex
    Author: Wobin
    Date: 2026-07-31
    Version: 2.1.0
--]]

local mod = get_mod("Havoc Auspex")
mod.version = "2.1.0"

local Net = mod:io_dofile("Havoc Auspex/scripts/mods/Havoc Auspex/havoc_net")
local id_codec = mod:io_dofile("Havoc Auspex/scripts/mods/Havoc Auspex/id_codec")

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

local function map_texture(map_id)
    if type(map_id) ~= "string" then return nil end
    load_templates()
    local t = _mission_templates and _mission_templates[map_id]
    if not t then return nil end
    return (type(t.texture_big) == "string" and t.texture_big)
        or (type(t.texture_medium) == "string" and t.texture_medium)
        or (type(t.texture_small) == "string" and t.texture_small)
        or nil
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
        texture      = map_texture(order.map),
        circs        = circs,
    }
end

local MANIFOLD_ID = "wobin.havoc"
local PAYLOAD_VERSION = 2

local results_version = 0
local function bump_results() results_version = results_version + 1 end
function mod.results_version() return results_version end
mod.bump_results = bump_results

local function debug_on()
    return mod:get("debug_mode") == true
end

local function dbg(fmt, ...)
    if not debug_on() then return end
    mod:info("[Havoc Auspex][dbg] " .. (select("#", ...) > 0 and (fmt):format(...) or fmt))
end

local function member_name(member)
    local name = "?"
    pcall(function() name = (member and member.name and member:name()) or "?" end)
    return name
end

local function build_codec(templates, label)
    local ids = {}
    if type(templates) == "table" then
        for name in pairs(templates) do
            if type(name) == "string" then ids[#ids + 1] = name end
        end
    end
    local c = id_codec.build(ids)
    if #c.collisions > 0 then
        mod:warning(("[Havoc Auspex] %d %s ids still collide at %d-char codes and will ride raw: %s"):format(
            #c.collisions, label, c.width, table.concat(c.collisions, ", ")))
    end
    dbg("%s codec: %d ids, %d-char codes", label, #ids, c.width)
    return c
end

local _circ_codec, _mission_codec
local function get_circ_codec()
    if not _circ_codec then load_templates(); _circ_codec = build_codec(_circ_templates, "circumstance") end
    return _circ_codec
end
local function get_mission_codec()
    if not _mission_codec then load_templates(); _mission_codec = build_codec(_mission_templates, "mission") end
    return _mission_codec
end

local function build_payload()
    local order = mod.my_order
    if type(order) ~= "table" then return nil end
    local cc = get_circ_codec()
    local circs = {}
    if type(order.flags) == "table" then
        for k, v in pairs(order.flags) do
            local s = (type(k) == "string" and k) or (type(v) == "string" and v) or nil
            local cid = s and s:match("^havoc%-circ%-(.+)$")
            if cid then circs[#circs + 1] = cc.encode(cid) end
        end
        table.sort(circs)
    end
    local map = order.map
    if type(map) == "string" then map = get_mission_codec().encode(map) end
    return { pv = PAYLOAD_VERSION, r = order.rank, c = order.charges, m = map, f = circs }
end

local function decode_payload(payload)
    if type(payload) ~= "table" then return nil end
    local pv = tonumber(payload.pv) or 1
    local cc = pv >= 2 and get_circ_codec() or nil
    local flags = {}
    if type(payload.f) == "table" then
        for i = 1, #payload.f do
            local token = payload.f[i]
            if type(token) == "string" then
                local cid = cc and (cc.decode(token) or token) or token
                flags["havoc-circ-" .. cid] = true
            end
        end
    end
    local map = type(payload.m) == "string" and payload.m or nil
    if map and pv >= 2 then
        map = get_mission_codec().decode(map) or map
    end
    return {
        rank    = tonumber(payload.r),
        charges = tonumber(payload.c),
        map     = map,
        flags   = flags,
    }
end

function mod.refresh_own_order()
    Net.build_self_order(function(order)
        mod.my_order = (type(order) == "table") and order or nil
        if mod.manifold then mod.manifold.mark_dirty(MANIFOLD_ID) end
        bump_results()
        dbg("own order refreshed: %s", mod.my_order and format_order(mod.my_order) or "None (no havoc order)")
    end)
end

mod.ha_event_havoc_status_refreshed = function()
    mod.refresh_own_order()
end

function mod.scan_party()
    bump_results()
    mod.refresh_own_order()
end

function mod.build_rows()
    local Manifold = mod.manifold
    if not Manifold then
        dbg("build_rows: Vox Manifold not available")
        return {}
    end
    local rows = {}
    local members = Manifold.members()
    for i = 1, #members do
        local member = members[i]
        if Manifold.is_myself(member) then
            rows[#rows + 1] = { name = Net.self_name() .. " (you)", order = mod.my_order or false }
        elseif Manifold.has_mod(member, MANIFOLD_ID) then
            local payload = Manifold.get(member, MANIFOLD_ID)
            local order = (type(payload) == "table") and decode_payload(payload) or false
            rows[#rows + 1] = { name = member_name(member), order = order }
            dbg("member %s: has mod v%s, order %s", member_name(member),
                tostring(Manifold.has_mod(member, MANIFOLD_ID)), order and format_order(order) or "not yet published")
        else
            dbg("member %s: NOT running Havoc Auspex (absent from capability record)", member_name(member))
        end
    end
    dbg("built %d rows from %d party members", #rows, #members)
    return rows
end

local EMPTY_RESULTS = { rows = {} }
local results_cache, results_cache_ver = nil, -1
function mod.current_results()
    if not mod.manifold then return EMPTY_RESULTS end
    if results_cache and results_cache_ver == results_version then return results_cache end
    results_cache = { rows = mod.build_rows() }
    results_cache_ver = results_version
    return results_cache
end

mod.on_all_mods_loaded = function()
    local vox = get_mod("Vox Manifold")

    local major = vox and tonumber(tostring(vox.version):match("^(%d+)"))
    local supported = vox and vox.api and major and major >= 2

    if not supported then
        mod:error("[Havoc Auspex] requires Vox Manifold 2.0.0 or later. Install it to share party havoc orders.")
        return
    end

    local Manifold = vox.api
    mod.manifold = Manifold

    Manifold.register(MANIFOLD_ID, mod, build_payload)
    mod.manifold_unsub = Manifold.on_update(function() bump_results() end)

    Managers.event:register(mod, "event_havoc_status_refreshed", "ha_event_havoc_status_refreshed")
    mod.refresh_own_order()

    mod:info(("Havoc Auspex v%s loaded (Vox Manifold transport, payload v%d)"):format(
        tostring(mod.version), PAYLOAD_VERSION))
    dbg("registered %s with Vox Manifold; debug logging ON", MANIFOLD_ID)
end

mod:command("havocauspex", "Echo the party's havoc orders to chat.", function()
    local rows = mod.build_rows()
    mod:echo("[Havoc Auspex] Party havoc orders:")
    if #rows == 0 then
        mod:echo("  (none)")
        return
    end
    for i = 1, #rows do
        local r = rows[i]
        mod:echo(("  %s: %s"):format(r.name, r.order and format_order(r.order) or "None"))
    end
end)

mod.on_enabled = function()
    if not mod.manifold then return end
    mod.manifold.register(MANIFOLD_ID, mod, build_payload)
    if not mod.manifold_unsub then
        mod.manifold_unsub = mod.manifold.on_update(function() bump_results() end)
    end
    mod.refresh_own_order()
end

mod.on_disabled = function()
    if mod.manifold then mod.manifold.unregister(MANIFOLD_ID) end
    if mod.manifold_unsub then
        mod.manifold_unsub()
        mod.manifold_unsub = nil
    end
end

mod.on_unload = mod.on_disabled

mod:io_dofile("Havoc Auspex/scripts/mods/Havoc Auspex/havoc_auspex_ui") 
