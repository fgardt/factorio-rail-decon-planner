data:extend({
    {
        type = "custom-input",
        name = "rdp-give-planner",
        key_sequence = "ALT + F",
        localised_name = { "shortcut-name.rdp-give-planner" },
        include_selected_prototype = true,
        action = "lua",
        order = "a",
    },
    {
        type = "shortcut",
        name = "rdp-give-planner",
        order = "b[blueprints]-g[rail-deconstruction-planner]",
        action = "lua",
        associated_control_input = "rdp-give-planner",
        --technology_to_unlock = "railway",
        style = "red",
        icon = {
            filename = "__base__/graphics/icons/rail.png",
            priority = "extra-high-no-scale",
            size = 64,
            scale = 0.25,
            mipmap_count = 1,
            flags = { "gui-icon" },
        }
    }
})
