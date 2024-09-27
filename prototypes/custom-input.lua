data:extend({
    {
        type = "custom-input",
        name = "rdp-give-planner",
        key_sequence = "ALT + F",
        localised_name = { "shortcut-name.rdp-give-planner" },
        include_selected_prototype = true,
        action = "lua",
        order = "a",
    } --[[@as data.CustomInputPrototype]],
    {
        type = "shortcut",
        name = "rdp-give-planner",
        order = "b[blueprints]-g[rail-deconstruction-planner]",
        action = "lua",
        associated_control_input = "rdp-give-planner",
        --technology_to_unlock = "railway",
        style = "red",
        icons = { {
            icon = "__base__/graphics/icons/rail.png",
            icon_size = 64,
            scale = 0.25,
        } },
        small_icons = { {
            icon = "__base__/graphics/icons/rail.png",
            icon_size = 64,
            scale = 0.25,
        } },
    } --[[@as data.ShortcutPrototype]]
})
