return function()
    local gate = {}

    local pending      = false
    local since_disc   = 0
    local since_resync = math.huge

    function gate.request()
        pending = true
        since_disc = 0
    end

    function gate.tick(dt, in_hub, settle, min_interval)
        since_disc   = since_disc + dt
        since_resync = since_resync + dt
        if not pending then return false end
        if not in_hub then return false end
        if since_disc < settle then return false end
        if since_resync < min_interval then return false end
        pending = false
        since_resync = 0
        return true
    end

    return gate
end
