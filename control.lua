local const = require("__rail-decon-planner__/const")

---@param entities LuaEntity[]?
local function debug_draw_entities(entities)
    if not entities then return end

    for _, entity in pairs(entities) do
        rendering.draw_circle({
            color = { r = 1, g = 1, b = 0, a = 1 },
            radius = 1,
            width = 1,
            filled = true,
            target = entity,
            surface = entity.surface,
            time_to_live = 60,
        })
    end
end

local rail_types = {
    ["legacy-straight-rail"] = true,
    ["legacy-curved-rail"] = true,

    ["straight-rail"] = true,
    ["curved-rail-a"] = true,
    ["curved-rail-b"] = true,
    ["half-diagonal-rail"] = true,

    ["rail-ramp"] = true,
    ["elevated-straight-rail"] = true,
    ["elevated-curved-rail-a"] = true,
    ["elevated-curved-rail-b"] = true,
    ["elevated-half-diagonal-rail"] = true,
}

local elevated_rail_types = {
    ["elevated-straight-rail"] = true,
    ["elevated-curved-rail-a"] = true,
    ["elevated-curved-rail-b"] = true,
    ["elevated-half-diagonal-rail"] = true,
}

local signal_types = {
    ["rail-signal"] = true,
    ["rail-chain-signal"] = true,
}

local rd = defines.rail_direction

---@class SegmentConnection
---@field rail LuaEntity
---@field direction defines.rail_direction
---@field back_direction defines.rail_connection_direction

---@param a MapPosition
---@param b MapPosition
---@return boolean
local function same_position(a, b)
    local x1 = a.x or a[1]
    local y1 = a.y or a[2]
    local x2 = b.x or b[1]
    local y2 = b.y or b[2]

    return x1 == x2 and y1 == y2
end

---@param rail LuaEntity?
---@param direction defines.rail_direction
---@return SegmentConnection[]
local function get_connected_segments(rail, direction)
    ---@type SegmentConnection[]
    local res = {}

    if not rail or not rail.valid then return res end
    if not rail_types[rail.type] then return res end

    for traverse_name, traverse_dir in pairs(defines.rail_connection_direction) do
        if traverse_name == "none" then goto continue end

        local connection, dir, cdir = rail.get_connected_rail({
            rail_direction = direction,
            rail_connection_direction = traverse_dir
        })

        if connection and connection.valid then
            ---@cast dir defines.rail_direction
            ---@cast cdir defines.rail_connection_direction
            ---@type SegmentConnection
            local con = { rail = connection, direction = dir, back_direction = cdir }
            table.insert(res, con)
        end

        ::continue::
    end

    return res
end

---@param connection SegmentConnection
---@param marked_rails table<uint, LuaEntity>
---@return boolean
local function has_other_inbound_connections(connection, marked_rails)
    for traverse_name, traverse_dir in pairs(defines.rail_connection_direction) do
        if traverse_name == "none" or traverse_dir == connection.back_direction then goto continue end

        local rail, dir, cdir = connection.rail.get_connected_rail({
            rail_direction = connection.direction,
            rail_connection_direction = traverse_dir,
        })

        if rail and rail.valid and marked_rails[rail.unit_number] == nil and not rail.to_be_deconstructed() then
            return true
        end

        ::continue::
    end

    return false
end

---@param target table
---@param source table
local function append_table(target, source)
    for _, data in pairs(source) do
        table.insert(target, data)
    end
end

---@param direction defines.rail_direction
---@return defines.rail_direction flipped_direction
local function flip_direction(direction)
    if direction == rd.front then
        return rd.back
    end

    return rd.front
end

---@param connection SegmentConnection
---@return LuaEntity[] stations
local function get_stations(connection)
    local front = connection.rail.get_rail_segment_stop(rd.front)
    local back = connection.rail.get_rail_segment_stop(rd.back)

    local res = {} ---@type LuaEntity[]

    if front and front.valid then
        table.insert(res, front)
    end

    if back and back.valid then
        table.insert(res, back)
    end

    return res
end

---@param rail LuaEntity
---@return LuaEntity[] signals
local function get_signals(rail)
    local signal_in = rail.get_rail_segment_signal(rd.front, true)
    local signal_out = rail.get_rail_segment_signal(rd.front, false)

    local res = {} ---@type LuaEntity[]

    if signal_in and signal_in.valid then
        table.insert(res, signal_in)
    end

    if signal_out and signal_out.valid then
        table.insert(res, signal_out)
    end

    return res
end

---@param rail LuaEntity
---@return LuaEntity[] supports
local function get_supports_from_rail(rail)
    if not rail or not rail.valid or not elevated_rail_types[rail.type] then return {} end

    local surface = rail.surface
    local tmp = {} ---@type table<uint, LuaEntity>

    local front_location = rail.get_rail_end(rd.front).location
    local back_location = rail.get_rail_end(rd.back).location

    local front_direction = front_location.direction % 8
    local back_direction = back_location.direction % 8

    for _, support in pairs(surface.find_entities_filtered({
        type = "rail-support",
        position = front_location.position,
    })) do
        if not support.valid or front_direction ~= (support.direction % 8) then goto continue end

        tmp[support.unit_number] = support

        ::continue::
    end

    for _, support in pairs(surface.find_entities_filtered({
        type = "rail-support",
        position = back_location.position,
    })) do
        if not support.valid or back_direction ~= (support.direction % 8) then goto continue end

        tmp[support.unit_number] = support

        ::continue::
    end

    local res = {} ---@type LuaEntity[]

    for _, support in pairs(tmp) do
        table.insert(res, support)
    end

    return res
end

---@param support LuaEntity
---@return LuaEntity[] rails
local function get_rails_from_support(support)
    if not support or not support.valid or support.type ~= "rail-support" then return {} end

    local res = {} ---@type LuaEntity[]
    local surface = support.surface
    local direction = support.direction % 8
    local position = support.position

    for _, rail in pairs(surface.find_entities_filtered({
        type = {
            "elevated-straight-rail",
            "elevated-curved-rail-a",
            "elevated-curved-rail-b",
            "elevated-half-diagonal-rail",
        },
        area = {
            left_top = { x = position.x - 2.1, y = position.y - 2.1 },
            right_bottom = { x = position.x + 2.1, y = position.y + 2.1 },
        },
    })) do
        if not rail.valid then goto continue end

        local front_location = rail.get_rail_end(rd.front).location
        local back_location = rail.get_rail_end(rd.back).location

        if (same_position(front_location.position, position) and direction == (front_location.direction % 8)) or
            (same_position(back_location.position, position) and direction == (back_location.direction % 8)) then
            table.insert(res, rail)
        end

        ::continue::
    end

    return res
end

---@param start LuaEntity?
---@return LuaEntity[] rails
---@return LuaEntity[] signals
---@return LuaEntity[] stations
local function get_rail_segments(start)
    local rails = {} ---@type table<uint, LuaEntity>
    local signals = {} ---@type table<uint, LuaEntity>
    local stations = {} ---@type table<uint, LuaEntity>

    if not start or not start.valid then return rails, signals, stations end
    if not rail_types[start.type] then return rails, signals, stations end

    --------------------------------
    --- Initial selected segment ---
    --------------------------------

    local start_segment = start.get_rail_segment_rails(rd.front)
    for _, rail in pairs(start_segment) do
        -- unit number is safe, (curved-)rails inherit EntityWithOwner
        rails[rail.unit_number] = rail
    end

    for _, signal in pairs(get_signals(start)) do
        -- unit number is safe, (chain-)signals inherit EntityWithOwner
        signals[signal.unit_number] = signal
    end

    local start_stations = get_stations({
        rail = start,
        direction = rd.back,
        back_direction = defines.rail_connection_direction.none
    })

    for _, station in pairs(start_stations) do
        -- unit number is safe, stations inherit EntityWithOwner
        stations[station.unit_number] = station
    end

    -- get front and back connections
    local paths_to_check = {} ---@type SegmentConnection[]
    append_table(paths_to_check, get_connected_segments(start.get_rail_segment_end(rd.front)))
    append_table(paths_to_check, get_connected_segments(start.get_rail_segment_end(rd.back)))

    --------------------------------
    --- Connected rail traversal ---
    --------------------------------

    local idx = 1
    while idx <= #paths_to_check do
        local conn = paths_to_check[idx]

        if not has_other_inbound_connections(conn, rails) then
            local segment = conn.rail.get_rail_segment_rails(conn.direction)
            for _, rail in pairs(segment) do
                -- unit number is safe, (curved-)rails inherit EntityWithOwner
                rails[rail.unit_number] = rail
            end

            for _, signal in pairs(get_signals(conn.rail)) do
                -- unit number is safe, (chain-)signals inherit EntityWithOwner
                signals[signal.unit_number] = signal
            end

            for _, station in pairs(get_stations(conn)) do
                -- unit number is safe, stations inherit EntityWithOwner
                stations[station.unit_number] = station
            end

            local conn_segments = get_connected_segments(conn.rail.get_rail_segment_end(flip_direction(conn.direction)))
            for _, seg_conn in pairs(conn_segments) do
                if rails[seg_conn.rail.unit_number] == nil then
                    paths_to_check[#paths_to_check + 1] = seg_conn
                end
            end
        end

        idx = idx + 1
    end

    -- filter out signals attached to other rails
    for _, signal in pairs(signals) do
        for _, rail in pairs(signal.get_connected_rails()) do
            if rails[rail.unit_number] == nil and not rail.to_be_deconstructed() then
                signals[signal.unit_number] = nil
            end
        end
    end

    return rails, signals, stations
end

---@param entities LuaEntity[]
---@param player_index uint
local function mark_segments(entities, player_index)
    local force_index = game.get_player(player_index).force_index --[[@as uint8]]
    local settings = settings.get_player_settings(player_index)
    local mark_signals = settings[const.mark_signals].value
    local mark_stations = settings[const.mark_stations].value

    local supports = {} ---@type table<uint, LuaEntity>

    for _, entity in pairs(entities) do
        if not entity or not entity.valid then goto continue end
        if entity.to_be_deconstructed() then goto continue end

        local rails, signals, stations = get_rail_segments(entity)
        for _, rail in pairs(rails) do
            -- other event handlers could've deleted the rail
            if not rail.valid then goto continue end

            for _, support in pairs(get_supports_from_rail(rail)) do
                supports[support.unit_number] = support
            end

            rail.order_deconstruction(force_index, player_index)

            ::continue::
        end

        if mark_signals then
            for _, signal in pairs(signals) do
                -- other event handlers could've deleted the signal
                if not signal.valid then goto continue end

                signal.order_deconstruction(force_index, player_index)

                ::continue::
            end
        end

        if mark_stations then
            for _, station in pairs(stations) do
                -- other event handlers could've deleted the station
                if not station.valid then goto continue end

                station.order_deconstruction(force_index, player_index)

                ::continue::
            end
        end

        ::continue::
    end

    for _, support in pairs(supports) do
        if not support.valid then goto continue end

        for _, rail in pairs(get_rails_from_support(support)) do
            if not rail.valid then goto skip end

            if not rail.to_be_deconstructed() then goto continue end

            ::skip::
        end

        support.order_deconstruction(force_index, player_index)

        ::continue::
    end
end

local ev = defines.events

script.on_event(ev.on_player_selected_area, function(event)
    if event.item ~= "rdp-segment-planner" then return end

    mark_segments(event.entities, event.player_index)
end)

---@param event
---| EventData.on_lua_shortcut
---| EventData.CustomInputEvent
local function give_planner(event)
    if event.prototype_name and event.prototype_name ~= "rdp-give-planner" then return end

    -- since a player had to press the hotkey to get here we can assume they exist
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]

    local selected_proto = event.selected_prototype
    if selected_proto ~= nil and player.selected and player.selected.valid then
        local type = selected_proto.derived_type
        local did_something = false

        if rail_types[type] then
            mark_segments({ player.selected }, event.player_index)

            did_something = true
        elseif signal_types[type] then
            local signal = player.selected --[[@as LuaEntity]]

            if not signal.to_be_deconstructed() then
                signal.cancel_deconstruction(player.force_index --[[@as uint8]], event.player_index)
            end

            mark_segments(signal.get_connected_rails(), event.player_index)

            did_something = true
        elseif type == "rail-support" then
            mark_segments(get_rails_from_support(player.selected), event.player_index)

            did_something = true
        end

        if did_something then
            if not player.is_cursor_empty() and player.cursor_stack.valid_for_read and player.cursor_stack.name == "rdp-segment-planner" then
                player.clear_cursor()
            end

            return
        end
    end

    if player.clear_cursor() then
        player.cursor_stack.set_stack("rdp-segment-planner")
    end
end

script.on_event(ev.on_lua_shortcut, give_planner)
script.on_event("rdp-give-planner", give_planner)
