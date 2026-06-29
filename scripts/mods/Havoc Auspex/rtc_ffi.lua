return function(host_mod)
    local mod = host_mod
    local ffi = Mods.lua.ffi

    if not pcall(ffi.typeof, "RTC_FFI_CDEF") then
        ffi.cdef([[
            typedef struct { int unused; } RTC_FFI_CDEF;

            int RTC_Connect(const char* room, char* err, int errlen);
            int RTC_Send(const char* room, const char* recipient, const char* msg, int msglen);
            int RTC_Disconnect(const char* room);
            int RTC_PollEvent(int* type_out, char* room, int room_cap, char* peer, int peer_cap, char* msg, int msg_cap, int* msg_len_out);
            void RTC_Shutdown(void);
        ]])
    end

    local ok, lib = pcall(ffi.load, "../mods/Havoc Auspex/bin/darktide_rtc_ffi.dll")
    if not ok then
        mod:error("[rtc_ffi] failed to load darktide_rtc_ffi.dll: " .. tostring(lib))
        return nil
    end

    local RTC = {}

    -- channel -> { on_connect, on_message, on_disconnect }
    local handlers = {}

    -- Reusable FFI scratch buffers (allocated once; never resized).
    local ROOM_CAP, PEER_CAP, MSG_CAP, ERR_CAP = 256, 64, 65536, 1024
    local type_out    = ffi.new("int[1]")
    local msg_len_out = ffi.new("int[1]")
    local room_buf    = ffi.new("char[?]", ROOM_CAP)
    local peer_buf    = ffi.new("char[?]", PEER_CAP)
    local msg_buf     = ffi.new("char[?]", MSG_CAP)
    local err_buf     = ffi.new("char[?]", ERR_CAP)

    local EVENT_PEER_CONNECTED    = 1
    local EVENT_MESSAGE           = 2
    local EVENT_PEER_DISCONNECTED = 3
    local MAX_EVENTS_PER_POLL     = 256

    -- Diagnostic trace into the console log, gated by the mod's debug_mode
    -- setting so normal play stays silent. mod:info keeps it out of in-game chat.
    local function dbg(msg)
        if mod:get("debug_mode") then mod:info("[rtc_ffi] " .. msg) end
    end

    function RTC.connect(channel, on_peer_connect, on_message, on_peer_disconnect)
        handlers[channel] = {
            on_connect    = on_peer_connect,
            on_message    = on_message,
            on_disconnect = on_peer_disconnect,
        }
        local ok = lib.RTC_Connect(channel, err_buf, ERR_CAP)
        if ok == 0 then
            mod:error("[rtc_ffi] RTC_Connect failed: " .. ffi.string(err_buf))
            return false
        end
        dbg("connect ok: " .. channel)
        return true
    end

    function RTC.send(channel, recipient, message)
        message = message or ""
        local ok = lib.RTC_Send(channel, recipient, message, #message) ~= 0
        dbg(("send -> %s (%d bytes) ok=%s"):format(tostring(recipient), #message, tostring(ok)))
        return ok
    end

    function RTC.disconnect(channel)
        handlers[channel] = nil
        return lib.RTC_Disconnect(channel) ~= 0
    end

    function RTC.poll()
        for _ = 1, MAX_EVENTS_PER_POLL do
            local r = lib.RTC_PollEvent(
                type_out,
                room_buf, ROOM_CAP,
                peer_buf, PEER_CAP,
                msg_buf, MSG_CAP,
                msg_len_out
            )
            if r ~= 1 then
                break
            end

            local channel = ffi.string(room_buf)
            local peer = ffi.string(peer_buf)
            local h = handlers[channel]
            if not h then
                dbg(("event type %d for unhandled channel %s"):format(type_out[0], channel))
            else
                local t = type_out[0]
                if t == EVENT_PEER_CONNECTED then
                    dbg("peer connected: " .. peer)
                    if h.on_connect then h.on_connect(peer) end
                elseif t == EVENT_MESSAGE then
                    local n = msg_len_out[0]
                    if n > MSG_CAP then n = MSG_CAP end
                    local message = ffi.string(msg_buf, n)
                    dbg(("message from %s (%d bytes)"):format(peer, n))
                    if h.on_message then h.on_message(message, peer) end
                elseif t == EVENT_PEER_DISCONNECTED then
                    dbg("peer disconnected: " .. peer)
                    if h.on_disconnect then h.on_disconnect(peer) end
                end
            end
        end
    end

    return RTC
end
