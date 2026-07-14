return function(host_mod, Net)
    local mod = host_mod
    local api = {}

    -- Orders travel as an Immaterium presence key-value, the same
    -- backend-relayed channel the game uses for havoc_status and the
    -- serialized character profile. No P2P, no signaling, works across
    -- hub instances and during missions.
    local KEY = "havoc_auspex_order"
    local PAYLOAD_VERSION = 1

    -- A legitimate payload tops out around ~500 bytes (8 circ ids at the
    -- game-wide max of 49 chars, plus rank/charges/map and JSON overhead);
    -- observed real orders are ~120 bytes. Anything bigger is not ours.
    local MAX_PAYLOAD_BYTES = 2048

    api.KEY = KEY
    api.PAYLOAD_VERSION = PAYLOAD_VERSION

    local cjson = cjson

    local function dbg(msg)
        if mod:get("debug_mode") then mod:echo("[Havoc Auspex][dbg] " .. msg) end
    end

    -- Payload: v = version, r = rank, c = charges, m = map id,
    -- f = circumstance ids with the "havoc-circ-" prefix stripped.
    -- "none" = mod present but no order; "" = order cleared (mod disabled).
    local function encode_order(order)
        if type(order) ~= "table" then
            return "none"
        end
        local circs = {}
        local flags = order.flags
        if type(flags) == "table" then
            for k, v in pairs(flags) do
                local s = (type(k) == "string" and k) or (type(v) == "string" and v) or nil
                local cid = s and s:match("^havoc%-circ%-(.+)$")
                if cid then circs[#circs + 1] = cid end
            end
            table.sort(circs)
        end
        local ok, encoded = pcall(cjson.encode, {
            v = PAYLOAD_VERSION,
            r = order.rank,
            c = order.charges,
            m = order.map,
            f = circs,
        })
        return (ok and encoded) or "none"
    end

    local decode_cache, decode_cache_size = {}, 0

    -- nil = not publishing (no mod / not yet received / cleared),
    -- false = publishing but no order (or unreadable payload),
    -- table = decoded order compatible with mod.describe_order.
    local function decode_order(raw)
        if type(raw) ~= "string" or raw == "" then return nil end
        if raw == "none" then return false end
        -- reject oversized payloads before touching the cache, so hostile
        -- strings are neither parsed nor retained as cache keys
        if #raw > MAX_PAYLOAD_BYTES then return false end
        local cached = decode_cache[raw]
        if cached ~= nil then return cached end
        local result = false
        local ok, d = pcall(cjson.decode, raw)
        if ok and type(d) == "table" and tonumber(d.v) then
            local flags = {}
            local f = d.f
            if type(f) == "table" then
                for i = 1, #f do
                    local cid = f[i]
                    if type(cid) == "string" then
                        flags["havoc-circ-" .. cid] = true
                    end
                end
            end
            result = {
                rank    = tonumber(d.r),
                charges = tonumber(d.c),
                map     = type(d.m) == "string" and d.m or nil,
                flags   = flags,
            }
        end
        if decode_cache_size >= 64 then
            decode_cache, decode_cache_size = {}, 0
        end
        decode_cache[raw] = result
        decode_cache_size = decode_cache_size + 1
        return result
    end

    local my_order_encoded = nil
    local my_order = nil
    local on_change_cb = nil
    local build_in_flight = false
    local build_pending = false

    function api.my_order()
        return my_order
    end

    local function push_to_presence()
        local ok, err = pcall(function()
            Managers.presence:_update_my_presence({ [KEY] = true })
        end)
        if not ok then
            dbg("presence push failed: " .. tostring(err))
        end
    end

    function api.refresh_own_order()
        local svc = Managers.data_service and Managers.data_service.havoc
        if not svc then return end
        if build_in_flight then
            build_pending = true
            return
        end
        build_in_flight = true
        Net.build_self_order(function(order)
            build_in_flight = false
            local encoded = encode_order(order)
            if encoded ~= my_order_encoded then
                my_order_encoded = encoded
                my_order = type(order) == "table" and order or false
                push_to_presence()
                dbg("published " .. KEY .. " = " .. encoded)
                if on_change_cb then on_change_cb() end
            end
            if build_pending then
                build_pending = false
                api.refresh_own_order()
            end
        end)
    end

    function api.clear_published_order()
        if my_order_encoded and my_order_encoded ~= "" then
            my_order_encoded = ""
            my_order = nil
            push_to_presence()
        end
    end

    function api.member_order(presence)
        if not presence._key_value_string then return nil end
        return decode_order(presence:_key_value_string(KEY))
    end

    function api.activate(on_change)
        on_change_cb = on_change

        -- Injects our key into the same key-value map the game publishes.
        -- With no white_list this is the full set sent on presence-stream
        -- (re)starts, so the key survives reconnects for free.
        mod:hook(CLASS.PresenceEntryMyself, "create_key_values", function(func, self, white_list)
            local key_values = func(self, white_list)
            if my_order_encoded and (not white_list or white_list[KEY]) then
                key_values[KEY] = my_order_encoded
            end
            return key_values
        end)

        api.refresh_own_order()
    end

    return api
end
