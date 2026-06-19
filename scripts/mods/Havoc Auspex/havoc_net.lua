local Net = {
    PROTOCOL = "Havoc Auspex",
    PV = 1,
    EVENTS = {
        REQUEST = "havoc_request",
        REPLY   = "havoc_reply",
    },
}

function Net.build_self_order(on_done)
    local svc
    pcall(function() svc = Managers.data_service and Managers.data_service.havoc end)
    if not svc or type(svc.current_order) ~= "function" then
        on_done(nil)
        return
    end

    local ok, promise = pcall(svc.current_order, svc)
    if not (ok and type(promise) == "table" and type(promise.next) == "function") then
        on_done(nil)
        return
    end

    promise:next(function(order)
        if type(order) ~= "table" or type(order.blueprint) ~= "table" then
            on_done(nil)
            return
        end
        local bp = order.blueprint
        local payload = {
            rank       = order.rank or (type(order.data) == "table" and order.data.rank) or nil,
            map        = bp.map,
            challenge  = bp.challenge,
            resistance = bp.resistance,
            flags      = type(bp.flags) == "table" and bp.flags or {},
            charges    = nil,
        }

        local oid = order.id
        if oid ~= nil and type(svc.order_by_id) == "function" then
            local ok2, p2 = pcall(svc.order_by_id, svc, oid)
            if ok2 and type(p2) == "table" and type(p2.next) == "function" then
                p2:next(function(full)
                    if type(full) == "table" then payload.charges = tonumber(full.charges) end
                    on_done(payload)
                end):catch(function()
                    on_done(payload)
                end)
                return
            end
        end
        on_done(payload)
    end):catch(function()
        on_done(nil)
    end)
end

function Net.self_name()
    local name
    pcall(function()
        local lp = Managers.player and Managers.player:local_player(1)
        name = lp and lp:name()
    end)
    return name or "?"
end

return Net
