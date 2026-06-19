return function(host_mod)
    local mod = host_mod
    local api = {}

    local mod_event_handlers   = mod:persistent_table("rtc_embedded_mod_event_handlers")
    local internal_data        = mod:persistent_table("rtc_embedded_internal_data")
    local data_for_peer        = mod:persistent_table("rtc_embedded_data_for_peer")
    local account_id_to_peer_id = mod:persistent_table("rtc_embedded_account_id_to_peer_id")

    local function current_channel()
        return internal_data.channel
    end

    local URL_SAFE = {}
    do
        local function mark_range(from, to)
            for b = string.byte(from), string.byte(to) do URL_SAFE[b] = true end
        end
        mark_range("A", "Z")
        mark_range("a", "z")
        mark_range("0", "9")
        for _, c in ipairs({ "-", "_", ".", "~" }) do URL_SAFE[string.byte(c)] = true end
    end

    local function url_encode(s)
        return (tostring(s):gsub(".", function(c)
            local b = string.byte(c)
            if URL_SAFE[b] then return c end
            return string.format("%%%02X", b)
        end))
    end

    local MAX_TAG_NAME_BYTES = 24
    local function local_name_tag()
        local name
        pcall(function()
            local lp = Managers.player and Managers.player:local_player(1)
            name = lp and lp:name()
        end)
        name = name or "?"
        if #name > MAX_TAG_NAME_BYTES then
            name = name:sub(1, MAX_TAG_NAME_BYTES)
        end
        local tag = url_encode(name)
        if tag == "" then
            tag = url_encode("?")
        end
        return tag
    end

    function api.register(registering_mod, event_name, callback)
        local mod_name = registering_mod:get_name()
        mod_event_handlers[mod_name] = mod_event_handlers[mod_name] or {}
        mod_event_handlers[mod_name][event_name] = callback
    end

    function api.send(sending_mod, event_name, player_or_all, data)
        local mod_name = sending_mod:get_name()
        if not RTC then
            mod:echo(string.format("[%s] RTC plugin not installed - peer networking unavailable.", mod_name))
            return
        end
        local channel = current_channel()
        if not channel then
            mod:echo(string.format("[%s] Not connected to a channel, cannot send message.", mod_name))
            return
        end

        local payload = {
            mod_name   = mod_name,
            event_name = event_name,
            data       = data,
        }
        local recipient = player_or_all == "all" and "all" or account_id_to_peer_id[player_or_all:account_id()]
        RTC.send(channel, recipient, cjson.encode(payload))
    end

    local function party_member_by_account_id(account_id)
        local ok, member = pcall(function()
            local pim = Managers.party_immaterium
            local members = pim and pim:all_members()
            if type(members) ~= "table" then return nil end
            for _, m in ipairs(members) do
                if type(m.account_id) == "function" and m:account_id() == account_id then
                    return m
                end
            end
            return nil
        end)
        return ok and member or nil
    end

    function api.get_player_by_account_id(account_id)
        for _, player in pairs(Managers.player:players()) do
            if player:account_id() == account_id then
                return player
            end
        end

        local member = party_member_by_account_id(account_id)
        if member then
            return member
        end

        if rawget(_G, "RTC_TEST_ACCEPT_UNKNOWN") then
            return {
                account_id = function() return account_id end,
                name = function() return "RTC Test Peer" end,
                is_rtc_test_peer = true,
            }
        end

        return nil
    end

    function api.player_has_mod(player, wanted_mod_name)
        local peer_id = account_id_to_peer_id[player:account_id()]
        if not peer_id then
            return false
        end

        local peer_data = data_for_peer[peer_id]
        if not peer_data then
            return false
        end

        for _, mod_name in ipairs(peer_data.mods) do
            if mod_name == wanted_mod_name then
                return true
            end
        end

        return false
    end

    local function on_share_meta(peer_id, data)
        data_for_peer[peer_id] = data
        account_id_to_peer_id[data.account_id] = peer_id

        local player = api.get_player_by_account_id(data.account_id)
        if not player or not #data.mods then
            return
        end

        for _, mod_name in ipairs(data.mods) do
            local callback = mod_event_handlers[mod_name]
            if callback and callback.player_joined then
                callback.player_joined(player)
            end
        end
    end

    local function on_peer_connect(peer_id)
        local player = Managers.player:local_player(1)
        local account_id = player:account_id()
        local player_mods = {}
        for mod_name, _ in pairs(mod_event_handlers) do
            table.insert(player_mods, mod_name)
        end

        if #player_mods == 0 then
            return
        end

        local channel = current_channel()
        if not channel then
            mod:echo("[rtc_embedded] Not connected to a channel, cannot send message.")
            return
        end

        local data = {
            account_id = account_id,
            mods       = player_mods,
        }
        local payload = {
            mod_name   = "rtc",
            event_name = "rtc_share_meta",
            data       = data,
        }
        RTC.send(channel, peer_id, cjson.encode(payload))
    end

    local function on_message(message, peer_id)
        local decoded_message = cjson.decode(message)
        if not decoded_message then
            return
        end

        local mod_name = decoded_message.mod_name
        local event_name = decoded_message.event_name
        local data = decoded_message.data

        if mod_name == "rtc" and event_name == "rtc_share_meta" then
            on_share_meta(peer_id, data)
            return
        end

        if not mod_event_handlers[mod_name] or not mod_event_handlers[mod_name][event_name] then
            return
        end

        local callback = mod_event_handlers[mod_name][event_name]
        if callback then
            local peer_data = data_for_peer[peer_id]
            if peer_data and peer_data.account_id then
                local player = api.get_player_by_account_id(peer_data.account_id)
                if player then
                    callback(player, data)
                end
            end
        end
    end

    local function on_peer_disconnect(peer_id)
        local peer_data = data_for_peer[peer_id]
        if peer_data then
            local player = api.get_player_by_account_id(peer_data.account_id)
            if player then
                for _, mod_name in ipairs(peer_data.mods) do
                    local callbacks = mod_event_handlers[mod_name]
                    if callbacks and callbacks.player_left then
                        callbacks.player_left(player)
                    end
                end
            end
            account_id_to_peer_id[peer_data.account_id] = nil
            data_for_peer[peer_id] = nil
        end
    end

    local function current_party_id()
        local ok, party_id = pcall(function()
            return Managers.party_immaterium and Managers.party_immaterium:party_id()
        end)
        return (ok and party_id) or ""
    end

    local function sync_channel()
        if not RTC then return end
        local new_id = current_party_id()
        local old_id = internal_data.party_id
        if new_id == (old_id or "") then return end

        if internal_data.channel then
            RTC.disconnect(internal_data.channel)
            internal_data.channel = nil
            internal_data.party_id = nil
        end
        if new_id ~= "" then
            local channel = "rtc_" .. new_id .. "?n=" .. local_name_tag()
            internal_data.party_id = new_id
            internal_data.channel = channel
            RTC.connect(channel, on_peer_connect, on_message, on_peer_disconnect)
        end
    end

    function api.activate()
        mod:hook_safe("PartyImmateriumManager", "_handle_party_update_event", function(_self)
            sync_channel()
        end)

        sync_channel()

        mod:hook("MultiplayerSession", "other_client_left", function(func, self, game_peer_id)
            for _, player in pairs(Managers.player:players_at_peer(game_peer_id) or {}) do
                local account_id = player:account_id()
                local peer_id = account_id_to_peer_id[account_id]
                local peer_data = data_for_peer[peer_id]
                if peer_data then
                    for _, mod_name in ipairs(peer_data.mods) do
                        local callbacks = mod_event_handlers[mod_name]
                        if callbacks and callbacks.player_left then
                            callbacks.player_left(player)
                        end
                    end

                    data_for_peer[peer_id] = nil
                    account_id_to_peer_id[account_id] = nil
                end
            end

            return func(self, game_peer_id)
        end)
    end

    return api
end
