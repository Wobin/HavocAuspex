local mod = get_mod("Havoc Auspex")

return {
    name         = "Havoc Auspex",
    description  = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id    = "hide_fading_light",
                type          = "checkbox",
                default_value = true,
                tooltip       = "hide_fading_light_tooltip",
            },
            {
                setting_id    = "window_seconds",
                type          = "numeric",
                default_value = 4,
                range         = { 2, 15 },
                tooltip       = "window_seconds_tooltip",
            },
            {
                setting_id    = "simulate_replies",
                type          = "checkbox",
                default_value = false,
                tooltip       = "simulate_replies_tooltip",
            },
            {
                setting_id    = "debug_mode",
                type          = "checkbox",
                default_value = false,
                tooltip       = "debug_mode_tooltip",
            },
        },
    },
}
