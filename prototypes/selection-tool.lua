local decon_planner = data.raw["deconstruction-item"]["deconstruction-planner"]

local entity_filters = { "straight-rail", "curved-rail" }

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
        flags = { "hidden", "only-in-cursor", "not-stackable", "spawnable" },
        order = "e[deconstruction-planner]-rail",
        localised_name = { "shortcut-name.rdp-give-planner" },
        draw_label_for_cursor_render = true,
        stack_size = 1,

        selection_cursor_box_type = "not-allowed",
        alt_selection_cursor_box_type = "not-allowed",

        selection_mode = { "deconstruct" },
        alt_selection_mode = { "cancel-deconstruct" },
        reverse_selection_mode = { "nothing" },     --{ "deconstruct" },
        alt_reverse_selection_mode = { "nothing" }, --{ "cancel-deconstruct" },

        selection_color = table.deepcopy(decon_planner.selection_color),
        alt_selection_color = table.deepcopy(decon_planner.alt_selection_color),
        reverse_selection_color = { r = 0, g = 0, b = 0, a = 0 },
        alt_reverse_selection_color = { r = 0, g = 0, b = 0, a = 0 },

        selection_count_button_color = table.deepcopy(decon_planner.selection_count_button_color),
        alt_selection_count_button_color = table.deepcopy(decon_planner.alt_selection_count_button_color),

        entity_type_filters = entity_filters,
        alt_entity_type_filters = entity_filters,
        --reverse_entity_type_filters = entity_filters,
        --alt_reverse_entity_type_filters = entity_filters,

        entity_filter_mode = "whitelist",
        alt_entity_filter_mode = "whitelist",
        --reverse_entity_filter_mode = "whitelist",
        --alt_reverse_entity_filter_mode = "whitelist",
    }
})
