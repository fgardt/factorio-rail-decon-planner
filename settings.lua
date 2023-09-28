local const = require("__rail-decon-planner__/const")

data:extend({
    {
        type = "bool-setting",
        name = const.mark_signals,
        setting_type = "runtime-per-user",
        default_value = true,
    },
    {
        type = "bool-setting",
        name = const.mark_stations,
        setting_type = "runtime-per-user",
        default_value = true,
    },
})
