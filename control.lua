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

local rd = defines.rail_direction

---@class SegmentConnection
---@field rail LuaEntity
---@field direction defines.rail_direction
---@field back_direction defines.rail_connection_direction

---@param rail LuaEntity?
---@param direction defines.rail_direction
---@return SegmentConnection[]
local function get_connected_segments(rail, direction)
    ---@type SegmentConnection[]
    local res = {}

    if not rail or not rail.valid then return res end
    if not (rail.type == "straight-rail" or rail.type == "curved-rail") then return res end

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
    local direction = flip_direction(connection.direction)
    local entrance = connection.rail.get_rail_segment_entity(direction, true)
    local exit = connection.rail.get_rail_segment_entity(direction, false)

    local res = {} ---@type LuaEntity[]

    if entrance and entrance.valid and entrance.type == "train-stop" then
        table.insert(res, entrance)
    end

    if exit and exit.valid and exit.type == "train-stop" then
        table.insert(res, exit)
    end

    return res
end

---@param rail LuaEntity
---@return LuaEntity[] signals
local function get_signals(rail)
    local res = rail.get_inbound_signals()
    append_table(res, rail.get_outbound_signals())

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
    if not (start.type == "straight-rail" or start.type == "curved-rail") then return rails, signals, stations end

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

---@param rail LuaEntity
---@return LuaEntity[]
local function find_deconstructed_rail_signals(rail)
    local radius = 2.5

    if rail.type == "curved-rail" then
        radius = 4.5
    end

    local signals = rail.surface.find_entities_filtered({
        type = { "rail-signal", "rail-chain-signal" },
        to_be_deconstructed = true,
        position = rail.position,
        radius = radius,
    })

    return signals
end

---@param entities LuaEntity[]
---@param player_index uint
local function mark_segments(entities, player_index)
    local force_index = game.get_player(player_index).force_index --[[@as uint8]]
    for _, entity in pairs(entities) do
        if not entity or not entity.valid then goto continue end
        if entity.to_be_deconstructed() then goto continue end

        local rails, signals, stations = get_rail_segments(entity)
        for _, rail in pairs(rails) do
            -- other event handlers could've deleted the rail
            if not rail.valid then goto continue end

            rail.order_deconstruction(force_index, player_index)

            ::continue::
        end

        for _, signal in pairs(signals) do
            -- other event handlers could've deleted the signal
            if not signal.valid then goto continue end

            signal.order_deconstruction(force_index, player_index)

            ::continue::
        end

        for _, station in pairs(stations) do
            -- other event handlers could've deleted the station
            if not station.valid then goto continue end

            station.order_deconstruction(force_index, player_index)

            ::continue::
        end

        ::continue::
    end
end

---@param entities LuaEntity[]
---@param player_index uint
local function unmark_segments(entities, player_index)
    local force_index = game.get_player(player_index).force_index --[[@as uint8]]
    for _, entity in pairs(entities) do
        if not entity or not entity.valid then goto continue end
        if not entity.to_be_deconstructed() then goto continue end

        -- signals marked for decon can not be found this way
        local rails, _signals, stations = get_rail_segments(entity)
        for _, rail in pairs(rails) do
            -- other event handlers could've deleted the rail
            if not rail.valid then goto continue end

            rail.cancel_deconstruction(force_index, player_index)

            -- other event handlers could've deleted the rail
            if not rail.valid then goto continue end

            local signals = find_deconstructed_rail_signals(rail)
            for _, signal in pairs(signals) do
                -- other event handlers could've deleted the signal
                if not signal.valid then goto continue end

                signal.cancel_deconstruction(force_index, player_index)

                -- other event handlers could've deleted the signal
                if not signal.valid then goto continue end

                -- check if signal is actually connected to this rail
                for _, signal_rail in pairs(signal.get_connected_rails()) do
                    if rails[signal_rail.unit_number] ~= nil then goto continue end
                end

                signal.order_deconstruction(force_index, player_index)

                ::continue::
            end
        end

        for _, station in pairs(stations) do
            -- other event handlers could've deleted the station
            if not station.valid then goto continue end

            station.cancel_deconstruction(force_index, player_index)

            ::continue::
        end

        ::continue::
    end
end

--[[

---@param event EventData.on_player_alt_selected_area
local function mark_blocks(event)
    local force_index = game.get_player(event.player_index).force_index --@as uint8
    for _, entity in pairs(event.entities) do
        if entity.to_be_deconstructed() then goto continue end

        local segment = entity.get_rail_segment_rails(defines.rail_direction.front)
        for _, rail in pairs(segment) do
            rail.order_deconstruction(force_index, event.player_index)
        end

        ::continue::
    end
end

---@param event EventData.on_player_alt_reverse_selected_area
local function unmark_blocks(event)
    local force_index = game.get_player(event.player_index).force_index --@as uint8
    for _, entity in pairs(event.entities) do
        if not entity.to_be_deconstructed() then goto continue end

        local segment = entity.get_rail_segment_rails(defines.rail_direction.front)
        for _, rail in pairs(segment) do
            rail.cancel_deconstruction(force_index, event.player_index)
        end

        ::continue::
    end
end

]]

local ev = defines.events
script.on_event(ev.on_player_selected_area, function(event)
    if event.item ~= "rdp-segment-planner" then return end

    mark_segments(event.entities, event.player_index)
end)
script.on_event(ev.on_player_alt_selected_area, function(event)
    if event.item ~= "rdp-segment-planner" then return end

    unmark_segments(event.entities, event.player_index)
end)
--script.on_event(ev.on_player_reverse_selected_area, mark_blocks)
--script.on_event(ev.on_player_alt_reverse_selected_area, unmark_blocks)

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

        if type == "straight-rail" or type == "curved-rail" then
            if player.selected.to_be_deconstructed() then
                unmark_segments({ player.selected }, event.player_index)
            else
                mark_segments({ player.selected }, event.player_index)
            end

            did_something = true
        end

        if type == "rail-signal" or type == "rail-chain-signal" then
            local signal = player.selected --[[@as LuaEntity]]

            if not signal.to_be_deconstructed() then
                mark_segments(signal.get_connected_rails(), event.player_index)
            else
                signal.cancel_deconstruction(player.force_index --[[@as uint8]], event.player_index)
                local rails = signal.get_connected_rails()
                signal.order_deconstruction(player.force_index --[[@as uint8]], event.player_index)

                unmark_segments(rails, event.player_index)
            end

            did_something = true
        end

        if did_something then
            if not player.is_cursor_empty() and player.cursor_stack.name == "rdp-segment-planner" then
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
