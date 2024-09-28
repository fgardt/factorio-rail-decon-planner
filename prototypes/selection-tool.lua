local decon_planner = data.raw["deconstruction-item"]["deconstruction-planner"]

local entity_filters = {
    "legacy-straight-rail",
    "legacy-curved-rail",

    "straight-rail",
    "curved-rail-a",
    "curved-rail-b",
    "half-diagonal-rail",

    "rail-ramp",
    "elevated-straight-rail",
    "elevated-curved-rail-a",
    "elevated-curved-rail-b",
    "elevated-half-diagonal-rail",
}

local disabled_selection = {
    cursor_box_type = "not-allowed",
    mode = "nothing",

    border_color = { r = 0, g = 0, b = 0, a = 0 },
    count_button_color = { r = 0, g = 0, b = 0, a = 0 },
}

data:extend({
    {
        type = "selection-tool",
        name = "rdp-segment-planner",
        icons = {
            {
                icon = "__base__/graphics/icons/deconstruction-planner.png",
                icon_size = 64,
                icon_mipmaps = 4,
            },
            {
                icon = "__base__/graphics/icons/rail.png",
                icon_size = 64,
                icon_mipmaps = 4,
                scale = 0.375,
            }
        },
        hidden = true,
        flags = { "only-in-cursor", "not-stackable", "spawnable" },
        order = "e[deconstruction-planner]-rail",
        localised_name = { "shortcut-name.rdp-give-planner" },
        draw_label_for_cursor_render = true,
        stack_size = 1,

        select = {
            cursor_box_type = "not-allowed",
            mode = "deconstruct",

            border_color = table.deepcopy(decon_planner.select.border_color),
            count_button_color = table.deepcopy(decon_planner.select.count_button_color),

            entity_type_filters = entity_filters,
            entity_filter_mode = "whitelist",
        },

        alt_select = disabled_selection,
        reverse_select = disabled_selection,
        alt_reverse_select = disabled_selection,
        super_forced_select = disabled_selection,
    }
})
