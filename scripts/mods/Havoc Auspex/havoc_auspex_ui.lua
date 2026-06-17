local mod = get_mod("Havoc Auspex")

local UIWidget = require("scripts/managers/ui/ui_widget")
local Text     = require("scripts/utilities/ui/text")

local WHITE = { 255, 255, 255, 255 }

local BUTTON_PACKAGE = "packages/ui/views/options_view/options_view"

local PANEL_W, PANEL_H = 653, 300
local ROW_H, ROW_TOP   = 52, 54
local LABEL_X, LABEL_W = 20, 405
local ICON, ICON_GAP   = 30, 34
local ICON_X           = 433
local MAX_ROWS, MAX_ICONS = 4, 6
local TIP_W, TIP_H     = 220, 26
local DEFAULT_ICON = "content/ui/materials/icons/circumstances/special_waves_01"
local REFRESH_ICON = "content/ui/materials/hud/interactions/icons/pocketable_syringe_ability"

local function ensure_package()
    local pm = Managers.package
    if not pm then return false end
    if pm:has_loaded(BUTTON_PACKAGE) then return true end
    if not mod._pkg_id and not pm:is_loading(BUTTON_PACKAGE) then
        mod._pkg_id = pm:load(BUTTON_PACKAGE, "Havoc Auspex")
    end
    return false
end

local function row_passes()
    local p = {
        {
            pass_type = "text", style_id = "label", value_id = "label", value = "",
            style = {
                font_type = "proxima_nova_bold", font_size = 18, drop_shadow = true,
                text_color = { 255, 235, 235, 235 }, offset = { LABEL_X, 0, 2 },
                size = { LABEL_W, ROW_H }, text_vertical_alignment = "center",
                text_horizontal_alignment = "left",
            },
        },
        {
            pass_type = "hotspot", content_id = "loc_hs", style_id = "loc_hs",
            style = { size = { 0, ROW_H }, offset = { LABEL_X, 0, 5 } },
        },
    }
    for i = 1, MAX_ICONS do
        local ix, iy = ICON_X + (i - 1) * ICON_GAP, (ROW_H - ICON) / 2
        p[#p + 1] = {
            pass_type = "texture", style_id = "icon_" .. i, value_id = "icon_" .. i,
            value = DEFAULT_ICON,
            style = {
                size = { ICON, ICON },
                offset = { ix, iy, 3 },
                color = { 255, 255, 255, 255 },
            },
            visibility_function = function(content) return content["show_" .. i] == true end,
        }
        p[#p + 1] = {
            pass_type = "hotspot", content_id = "hs_" .. i,
            style = { size = { ICON, ICON }, offset = { ix, iy, 4 } },
        }
    end
    return p
end

local panel_passes = {
    { pass_type = "texture", value = "content/ui/materials/backgrounds/terminal_basic",
      style = { color = { 242, 12, 14, 18 } } },
    { pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px",
      style = { color = { 255, 110, 140, 170 } } },
    { pass_type = "texture", style_id = "background_gradient",
      value = "content/ui/materials/masks/gradient_horizontal_sides_02",
      style = {
          horizontal_alignment = "center", vertical_alignment = "top",
          size = { PANEL_W - 8, 54 }, offset = { 0, 6, 2 },
          color = Color.terminal_background_gradient(nil, true),
      } },
    { pass_type = "text", value = "Havoc Auspex",
      style = { font_type = "proxima_nova_bold", font_size = 28, drop_shadow = true,
                text_color = { 255, 255, 220, 170 }, offset = { 0, 14, 3 }, size = { PANEL_W, 34 },
                text_horizontal_alignment = "center", text_vertical_alignment = "top" } },
    { pass_type = "text", value_id = "status", value = "",
      style = { font_type = "proxima_nova_medium", font_size = 18, text_color = { 255, 180, 180, 180 },
                offset = { 0, PANEL_H - 30, 3 }, size = { PANEL_W, 26 },
                text_horizontal_alignment = "center", text_vertical_alignment = "top" } },
}

local tip_passes = {
    { pass_type = "rect", style_id = "tip_bg",
      style = { color = { 240, 8, 9, 12 }, size = { TIP_W, TIP_H }, offset = { 0, 0, 2 } },
      visibility_function = function(content) return content.tip_visible == true end },
    { pass_type = "rect", style_id = "tip_frame",
      style = { color = { 255, 110, 140, 170 }, size = { TIP_W, 1 }, offset = { 0, TIP_H - 1, 3 } },
      visibility_function = function(content) return content.tip_visible == true end },
    { pass_type = "text", value_id = "tip", value = "", style_id = "tip",
      style = { font_type = "proxima_nova_bold", font_size = 16, drop_shadow = true,
                text_color = { 255, 245, 245, 245 }, size = { TIP_W, TIP_H }, offset = { 0, 0, 4 },
                text_horizontal_alignment = "center", text_vertical_alignment = "center" },
      visibility_function = function(content) return content.tip_visible == true end },
}

local refresh_passes = {
    { pass_type = "hotspot", content_id = "hotspot" },
    { pass_type = "rect",
      style = { color = { 200, 28, 32, 40 } },
      change_function = function(content, style)
          style.color[1] = (content.hotspot and content.hotspot.is_hover) and 245 or 200
      end },
    { pass_type = "texture", value = REFRESH_ICON,
      style = { size = { 30, 30 }, offset = { 0, 0, 2 },
                horizontal_alignment = "center", vertical_alignment = "center",
                color = { 255, 220, 220, 220 } },
      change_function = function(content, style)
          local v = (content.hotspot and content.hotspot.is_hover) and 255 or 215
          style.color[2], style.color[3], style.color[4] = v, v, v
      end },
}

local function apply_definitions(defs)
    if not defs.scenegraph_definition or not defs.widget_definitions then return end
    if defs._ha_applied then return end
    defs._ha_applied = true
    local sg, wd = defs.scenegraph_definition, defs.widget_definitions

    sg.ha_panel = { horizontal_alignment = "center", vertical_alignment = "center",
        parent = "canvas", size = { PANEL_W, PANEL_H }, position = { 0, -300, 200 } }
    wd.ha_panel = UIWidget.create_definition(panel_passes, "ha_panel")

    sg.ha_refresh = { horizontal_alignment = "right", vertical_alignment = "top",
        parent = "ha_panel", size = { 44, 44 }, position = { -12, 10, 212 } }
    wd.ha_refresh = UIWidget.create_definition(refresh_passes, "ha_refresh", { hotspot = {} })

    for i = 1, MAX_ROWS do
        sg["ha_row_" .. i] = { horizontal_alignment = "left", vertical_alignment = "top",
            parent = "ha_panel", size = { PANEL_W, ROW_H }, position = { 0, ROW_TOP + (i - 1) * ROW_H, 210 } }
        wd["ha_row_" .. i] = UIWidget.create_definition(row_passes(), "ha_row_" .. i)
    end

    sg.ha_tip = { horizontal_alignment = "left", vertical_alignment = "top",
        parent = "ha_panel", size = { PANEL_W, PANEL_H }, position = { 0, 0, 260 } }
    wd.ha_tip = UIWidget.create_definition(tip_passes, "ha_tip")
end

mod:hook_require("scripts/ui/views/havoc_play_view/havoc_play_view_definitions", function(defs)
    apply_definitions(defs)
end)

mod:hook_require("scripts/ui/views/havoc_play_view/havoc_play_view", function(instance)
    instance._ha_create_widgets = function(self)
        if self._ha_widgets then return true end
        if not ensure_package() then return false end
        local Defs = require("scripts/ui/views/havoc_play_view/havoc_play_view_definitions")
        apply_definitions(Defs)
        local function mk(name)
            local w = self:_create_widget(name, Defs.widget_definitions[name])
            self._widgets_by_name[name] = w
            self._widgets[#self._widgets + 1] = w
            return w
        end
        local ok = pcall(function()
            self._ha_panel   = mk("ha_panel")
            self._ha_refresh = mk("ha_refresh")
            self._ha_rows    = {}
            for i = 1, MAX_ROWS do self._ha_rows[i] = mk("ha_row_" .. i) end
            self._ha_tip     = mk("ha_tip")
        end)
        if not ok then return false end
        self._ha_widgets = true
        mod._ha_waiting = false
        return true
    end
end)

local function measure(self, text, style)
    local ok, w = pcall(Text.text_width, self._ui_renderer, text, style, { 4000, ROW_H })
    if ok and type(w) == "number" and w > 0 then return w end
    return nil
end

local function place_loc_hotspot(self, st, label, location, has_sub)
    local ls = st.loc_hs
    if not ls then return end
    if not (has_sub and location and location ~= "") then
        ls.size[1] = 0
        return
    end
    local full_w = measure(self, label, st.label)
    local loc_w = measure(self, location, st.label)
    if full_w and loc_w then
        local x = math.max(LABEL_X, LABEL_X + (full_w - loc_w) - 2)
        local right = LABEL_X + LABEL_W
        ls.offset[1] = x
        ls.size[1] = math.max(0, math.min(loc_w + 4, right - x))
    else
        ls.offset[1] = LABEL_X
        ls.size[1] = LABEL_W
    end
end

local function rebuild_rows(self, rows)
    self._ha_desc = self._ha_desc or {}
    for i = 1, MAX_ROWS do
        local rw = self._ha_rows[i]
        if rw then
            local row = rows[i]
            if row then
                rw.visible = true
                local c, st = rw.content, rw.style
                local d = row.order and mod.describe_order(row.order) or nil
                self._ha_desc[i] = d
                if d then
                    c.label = ("%s    R%s%s    %s"):format(
                        row.name, tostring(d.rank or "?"),
                        d.charges and (" (" .. tostring(d.charges) .. "c)") or "",
                        d.location or "")
                    place_loc_hotspot(self, st, c.label, d.location, d.location_sub ~= nil)
                    for k = 1, MAX_ICONS do
                        local circ = d.circs[k]
                        local show = (circ ~= nil) and (type(circ.icon) == "string")
                        c["show_" .. k] = show
                        c["icon_" .. k] = (circ and circ.icon) or DEFAULT_ICON
                        local istyle = st["icon_" .. k]
                        if istyle then istyle.color = (circ and circ.color) or WHITE end
                    end
                else
                    c.label = row.name .. "    None"
                    if st.loc_hs then st.loc_hs.size[1] = 0 end
                    for k = 1, MAX_ICONS do c["show_" .. k] = false end
                end
            else
                rw.visible = false
                self._ha_desc[i] = nil
            end
        end
    end
end

local function render_rows(self)
    local res = mod.current_results()
    local rows = res.rows or {}

    local ver = mod.results_version()
    if ver ~= self._ha_ver then
        rebuild_rows(self, rows)
        self._ha_ver = ver
    end

    local hover_name, tip_cx, tip_y
    local desc = self._ha_desc
    if desc then
        for i = 1, MAX_ROWS do
            local rw = self._ha_rows[i]
            local d = desc[i]
            if rw and rw.visible and d then
                local c = rw.content
                for k = 1, MAX_ICONS do
                    local hs = c["hs_" .. k]
                    if c["show_" .. k] and hs and hs.is_hover then
                        local circ = d.circs[k]
                        if circ then
                            hover_name = circ.name
                            tip_cx = ICON_X + (k - 1) * ICON_GAP + ICON / 2
                            tip_y = ROW_TOP + (i - 1) * ROW_H + (ROW_H - ICON) / 2 + ICON + 4
                        end
                    end
                end
                local lhs = c.loc_hs
                if lhs and lhs.is_hover and d.location_sub and d.location_sub ~= "" then
                    local ls = rw.style.loc_hs
                    hover_name = d.location_sub
                    tip_cx = ls.offset[1] + ls.size[1] / 2
                    tip_y = ROW_TOP + (i - 1) * ROW_H + ROW_H - 4
                end
            end
        end
    end

    if self._ha_panel then
        local overflow = #rows - MAX_ROWS
        self._ha_panel.content.status = (not hover_name)
            and (res.scanning and "Scanning party…"
                 or (overflow > 0 and ("+ " .. overflow .. " more not shown"))
                 or ((#rows == 0) and "No responses.")
                 or "")
            or ""
    end

    local tip = self._ha_tip
    if tip then
        if hover_name then
            local ts = tip.style
            local tw, th
            if self._ha_tip_name == hover_name then
                tw, th = self._ha_tip_w, self._ha_tip_h
            else
                tw, th = TIP_W, TIP_H
                local ok, w, h = pcall(Text.text_size, self._ui_renderer, hover_name, ts.tip, { 4000, 400 })
                if ok and type(w) == "number" and w > 0 then tw = w + 24 end
                if ok and type(h) == "number" and h > 0 then th = math.max(TIP_H, h + 8) end
                tw = math.max(60, math.min(tw, PANEL_W - 8))
                self._ha_tip_name, self._ha_tip_w, self._ha_tip_h = hover_name, tw, th
            end
            ts.tip_bg.size[1], ts.tip_bg.size[2] = tw, th
            ts.tip.size[1], ts.tip.size[2]       = tw, th
            ts.tip_frame.size[1]                 = tw

            local tip_x = math.max(4, math.min(tip_cx - tw / 2, PANEL_W - tw - 4))
            local tip_yy = math.max(2, math.min(tip_y, PANEL_H - th - 2))
            tip.content.tip = hover_name
            tip.content.tip_visible = true
            ts.tip_bg.offset[1], ts.tip_bg.offset[2]       = tip_x, tip_yy
            ts.tip_frame.offset[1], ts.tip_frame.offset[2] = tip_x, tip_yy + th - 1
            ts.tip.offset[1], ts.tip.offset[2]             = tip_x, tip_yy
        else
            tip.content.tip_visible = false
        end
    end
end

mod:hook_safe(CLASS.HavocPlayView, "on_enter", function(self)
    ensure_package()
    if not self:_ha_create_widgets() then mod._ha_waiting = true end
    mod.scan_party()
end)

mod:hook_safe(CLASS.HavocPlayView, "update", function(self, dt, t)
    if mod._ha_waiting then self:_ha_create_widgets() end
    if not self._ha_widgets then return end

    local rb = self._ha_refresh
    if rb and rb.content and rb.content.hotspot and rb.content.hotspot.on_pressed then
        mod.scan_party()
    end

    render_rows(self)
end)

mod:hook_safe(CLASS.HavocPlayView, "on_exit", function(self)
    mod._ha_waiting = false
end)
