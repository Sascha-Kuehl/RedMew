local Event = require 'utils.event'
local Global = require 'utils.global'
local Gui = require 'utils.gui'
local Table = require 'utils.table'

local TICK_INTERVAL = 60
local TICKS_PER_WOOD = 60 * 60 * 1
local AFTERBURNER_TICKS = 60 * 17
local LIGHT_SCALE = 2.0
local INITIAL_WOOD_COUNT = 10

local torchlight_frame_name = Gui.uid_name()
local torchlight_enabled_button_name = Gui.uid_name()
local torchlight_flow_name = Gui.uid_name()
local torchlight_slot_button_name = Gui.uid_name()
local torchlight_progressbar_name = Gui.uid_name()

-- "map" from player index to {enabled, remaining_ticks, light_ids}
local player_light_data = {}

-- "map" from position to {remaining_ticks, light_ids}
local corpse_light_data = {}

-- "map" from player index to torchlight inventory
local torchlight_inventory = {}

Global.register(
        {
            player_light_data = player_light_data,
            corpse_light_data = corpse_light_data,
            torchlight_inventory = torchlight_inventory
        },
        function(tbl)
            player_light_data = tbl.player_light_data
            corpse_light_data = tbl.corpse_light_data
            torchlight_inventory = tbl.torchlight_inventory
        end
)

local Torchlight = {}

function realign_torchlight_frame(player)
    local frame = player.gui.screen[torchlight_frame_name]

    local resolution = player.display_resolution
    local scale = player.display_scale

    frame.location = { 190 * scale, resolution.height - (96 * scale) }
end

function update_torchlight_progressbar(player)
    local progressbar = player.gui.screen[torchlight_frame_name][torchlight_flow_name][torchlight_progressbar_name]
    local remaining_ticks = player_light_data[player.index].remaining_ticks

    local remaining_percent = (remaining_ticks - AFTERBURNER_TICKS) / TICKS_PER_WOOD
    if (remaining_percent < 0) then
        remaining_percent = 0
    end

    progressbar.value = remaining_percent
    progressbar.tooltip = tostring(remaining_percent * TICKS_PER_WOOD / 60) .. ' sec'
end

function create_gui_button(player)
    local frame = player.gui.screen.add {
        type = 'frame',
        name = torchlight_frame_name,
        direction = 'vertical'
    }
    frame.style.padding = 0

    local enabled_button = frame.add {
        type = 'sprite-button',
        name = torchlight_enabled_button_name,
        tooltip = 'Switch light on/off',
        sprite = 'virtual-signal/signal-sun',
        auto_toggle = true, toggled = player_light_data[player.index].enabled,
        style = 'quick_bar_page_button'
    }
    enabled_button.style.width = 38
    enabled_button.style.height = 38

    local flow = frame.add {
        type = 'flow',
        name = torchlight_flow_name,
        direction = 'vertical'
    }
    flow.style.vertical_spacing = 0

    local slot_button = flow.add {
        type = 'sprite-button',
        name = torchlight_slot_button_name,
        sprite = 'virtual-signal/signal-fire',
        style = 'tool_equip_ammo_slot'
    }
    slot_button.style.width = 38
    slot_button.style.height = 38

    local progressbar = flow.add {
        type = 'progressbar',
        name = torchlight_progressbar_name,
        value = 0.0
    }
    progressbar.style.width = 38

    realign_torchlight_frame(player)
    update_torchlight_progressbar(player)
end

function create_main_light(target, surface)
    return rendering.draw_light {
        sprite = 'utility/light_medium',
        color = { 250, 200, 120 },
        surface = surface,
        target = target,
    }
end

function create_effect_light_1(target, surface)
    return rendering.draw_light {
        sprite = 'utility/light_medium',
        color = { 170, 40, 0 },
        surface = surface,
        target = target,
        intensity = 0.25,
        blink_interval = 11
    }
end

function create_effect_light_2(target, surface)
    return rendering.draw_light {
        sprite = 'utility/light_medium',
        color = { 200, 100, 0 },
        surface = surface,
        target = target,
        intensity = 0.25,
        blink_interval = 13
    }
end

function create_or_restore_player_light(player)
    local light_data = player_light_data[player.index]

    if (light_data == nil) then
        local main_light = create_main_light(player.character, player.surface)
        local effect_light_1 = create_effect_light_1(player.character, player.surface)
        local effect_light_2 = create_effect_light_2(player.character, player.surface)
        light_data = {
            enabled = true,
            remaining_ticks = 0,
            light_ids = { main_light.id, effect_light_1.id, effect_light_2.id }
        }
        player_light_data[player.index] = light_data
        return
    end

    local main_light = rendering.get_object_by_id(light_data.light_ids[1])
    if (main_light == nil) then
        main_light = create_main_light(player.character, player.surface)
        light_data.light_ids[1] = main_light.id
    end

    local effect_light_1 = rendering.get_object_by_id(light_data.light_ids[2])
    if (effect_light_1 == nil) then
        effect_light_1 = create_effect_light_1(player.character, player.surface)
        light_data.light_ids[2] = effect_light_1.id
    end

    local effect_light_2 = rendering.get_object_by_id(light_data.light_ids[3])
    if (effect_light_2 == nil) then
        effect_light_2 = create_effect_light_2(player.character, player.surface)
        light_data.light_ids[3] = effect_light_2.id
    end

    return
end

function create_player_torchlight_inventory(player)
    local inventory = game.create_inventory(1)
    inventory.insert({ name = 'wood', count = INITIAL_WOOD_COUNT })
    torchlight_inventory[player.index] = inventory
end

function get_intensity(remaining_ticks)
    if (remaining_ticks <= 0) then
        return 0.0
    end
    if (remaining_ticks <= AFTERBURNER_TICKS) then
        return remaining_ticks / AFTERBURNER_TICKS
    end
    return 1.0
end

function update_light(light_data)
    local intensity = get_intensity(light_data.remaining_ticks)

    local main_light = rendering.get_object_by_id(light_data.light_ids[1])
    local effect_light_1 = rendering.get_object_by_id(light_data.light_ids[2])
    local effect_light_2 = rendering.get_object_by_id(light_data.light_ids[3])

    if (intensity == 0) then
        main_light.visible = false
        effect_light_1.visible = false
        effect_light_2.visible = false
        return
    end

    main_light.visible = true
    effect_light_1.visible = true
    effect_light_2.visible = true

    main_light.scale = LIGHT_SCALE * intensity
    effect_light_1.scale = LIGHT_SCALE * 1.15 * intensity
    effect_light_2.scale = LIGHT_SCALE * 1.15 * intensity
end

function update_player_light(player)
    if (player.ticks_to_respawn ~= nil) then
        return
    end

    local light_data = player_light_data[player.index]

    -- the light is burning and has enough "fuel"
    -- or player has deactivated the light, so we will not burn more wood
    if (light_data.remaining_ticks > AFTERBURNER_TICKS or not light_data.enabled) then
        update_light(light_data)
        return
    end

    local inventory = torchlight_inventory[player.index]
    local woodCount = inventory.get_item_count('wood')

    -- player has wood, so we can burn it
    if (woodCount ~= 0) then
        inventory.remove({ name = 'wood', count = 1 })
        light_data.remaining_ticks = TICKS_PER_WOOD + AFTERBURNER_TICKS
    end

    update_light(light_data)
    update_inventory_button(player)
end

function update_player_lights_on_tick()
    for _, player in pairs(game.connected_players) do
        local light_data = player_light_data[player.index]
        light_data.remaining_ticks = light_data.remaining_ticks - TICK_INTERVAL
        if (light_data.remaining_ticks <= 0) then
            light_data.remaining_ticks = 0
        end
        update_player_light(player)
        update_torchlight_progressbar(player)

        -- player runs out of wood so we show a message
        if (light_data.enabled
                and light_data.remaining_ticks > 0
                and light_data.remaining_ticks < AFTERBURNER_TICKS
                and light_data.remaining_ticks % 180 == 0) then
            player.create_local_flying_text {
                text = 'no more wood',
                surface = player.surface,
                position = player.position,
                color = { 250, 0, 0 }
            }
        end
    end
end

function update_corpse_light(position)
    local light_data = corpse_light_data[position]

    if (light_data.remaining_ticks > 0) then
        update_light(light_data)
        return
    end

    -- light burned out
    for _, id in pairs(light_data.light_ids) do
        local light_rendering = rendering.get_object_by_id(id)
        light_rendering.destroy()
    end
    corpse_light_data[position] = nil
end

function update_corpse_lights_on_tick()
    for position, light_data in pairs(corpse_light_data) do
        light_data.remaining_ticks = light_data.remaining_ticks - TICK_INTERVAL
        update_corpse_light(position)
    end
end

function on_player_created(event)
    local player = game.get_player(event.player_index)
    player.disable_flashlight()

    create_or_restore_player_light(player)
    create_player_torchlight_inventory(player)
    create_gui_button(player)
    update_player_light(player)
end

function on_player_respawned(event)
    local player = game.get_player(event.player_index)
    player.disable_flashlight()

    create_or_restore_player_light(player)
    update_player_light(player)
end

function on_player_joined_game(event)
    local player = game.get_player(event.player_index)

    create_or_restore_player_light(player)
    update_player_light(player)
end

function on_pre_player_died(event)
    local player = game.get_player(event.player_index)
    player.character_inventory_slots_bonus = player.character_inventory_slots_bonus + 1
    local torchlight_stack = torchlight_inventory[player.index][1]
    player.character.get_main_inventory().find_empty_stack().transfer_stack(torchlight_stack)
end

function on_player_died(event)
    local player = game.get_player(event.player_index)

    player.character_inventory_slots_bonus = player.character_inventory_slots_bonus - 1

    local light_data = player_light_data[player.index]
    local position = player.position

    corpse_light_data[position] = {
        remaining_ticks = light_data.remaining_ticks,
        light_ids = {
            create_main_light(position, player.surface).id,
            create_effect_light_1(position, player.surface).id,
            create_effect_light_2(position, player.surface).id
        }
    }
    player_light_data[player.index].remaining_ticks = 0
    update_player_light(player)
    update_corpse_light(position)
end

function on_player_main_inventory_changed(event)
    local player = game.get_player(event.player_index)
    update_player_light(player)
end

function on_tick()
    if (game.tick % TICK_INTERVAL ~= 0) then
        return
    end
    update_player_lights_on_tick()
    update_corpse_lights_on_tick()
end

function on_torchlight_button_pressed(event)
    local player = event.player
    local button = player.gui.screen[torchlight_frame_name][torchlight_enabled_button_name]
    player_light_data[player.index].enabled = button.toggled
    update_player_light(player)
end

function configure_wood_in_market()
    local redmew_config = storage.config
    for _, entry in pairs(redmew_config.experience.unlockables) do
        if (entry.name == 'wood') then
            entry.level = 1
            entry.price = 4
            return
        end
    end
    table.insert(redmew_config.experience.unlockables, {
        level = 1,
        price = 4,
        name = 'wood'
    })
end

function on_player_display_resolution_changed(event)
    local player = game.get_player(event.player_index)
    realign_torchlight_frame(player)
end

function on_player_display_scale_changed(event)
    local player = game.get_player(event.player_index)
    realign_torchlight_frame(player)
end

function update_inventory_button(player)
    local inventory = torchlight_inventory[player.index]
    local slot_button = player.gui.screen[torchlight_frame_name][torchlight_flow_name][torchlight_slot_button_name]

    local stack = inventory[1];

    if (stack.count == 0) then
        slot_button.sprite = 'virtual-signal/signal-fire'
        slot_button.number = nil
    else
        slot_button.sprite = 'item/' .. stack.name
        slot_button.number = stack.count
    end
end

function handle_inventory_slot_click(item_stack, click_event, allowed_items)
    local player = game.get_player(click_event.player_index)
    local main_inventory = player.character.get_main_inventory()
    local cursor_stack = player.cursor_stack
    if (cursor_stack == nil) then
        return
    end

    if (player.is_cursor_empty()) then
        if (not item_stack.valid_for_read) then
            return
        end

        local pick_count
        if (click_event.button == defines.mouse_button_type.left) then
            pick_count = item_stack.count
        elseif (click_event.button == defines.mouse_button_type.right) then
            pick_count = item_stack.count / 2
        else
            return
        end

        -- when holding Ctrl or Shift, then the chosen amount will be directly transferred to the main inventory
        if (click_event.control or click_event.shift) then
            local insert_count = main_inventory.get_insertable_count(item_stack)
            if (insert_count < pick_count) then
                pick_count = insert_count
            end
            -- don't know how to transfer a specific amount to main inventory, so the cursor_stack is used as "buffer"
            cursor_stack.transfer_stack(item_stack, pick_count)
            main_inventory.insert(cursor_stack)
            cursor_stack.clear()
        else
            cursor_stack.transfer_stack(item_stack, pick_count)
        end
    else
        if (not Table.contains(allowed_items, cursor_stack.name)) then
            return
        end

        if (click_event.button == defines.mouse_button_type.left and (not item_stack.valid_for_read or cursor_stack.name ~= item_stack.name or cursor_stack.quality ~= item_stack.quality)) then
            item_stack.swap_stack(cursor_stack)
            return
        end

        local push_count
        if (click_event.button == defines.mouse_button_type.left) then
            push_count = cursor_stack.count
        elseif (click_event.button == defines.mouse_button_type.right) then
            push_count = 1
        else
            return
        end

        item_stack.transfer_stack(cursor_stack, push_count)
    end
end

function on_torchlight_fuel_pressed(event)
    local player = game.get_player(event.player_index)
    local inventory = torchlight_inventory[player.index]
    handle_inventory_slot_click(inventory[1], event, { 'wood' })
    update_inventory_button(player)
end

function Torchlight.register()
    Event.add(defines.events.on_player_created, on_player_created)
    Event.add(defines.events.on_player_respawned, on_player_respawned)
    Event.add(defines.events.on_player_joined_game, on_player_joined_game)
    Event.add(defines.events.on_pre_player_died, on_pre_player_died)
    Event.add(defines.events.on_player_died, on_player_died)
    Event.add(defines.events.on_player_main_inventory_changed, on_player_main_inventory_changed)
    Event.add(defines.events.on_tick, on_tick)
    Event.add(defines.events.on_player_display_resolution_changed, on_player_display_resolution_changed)
    Event.add(defines.events.on_player_display_scale_changed, on_player_display_scale_changed)

    Gui.on_click(torchlight_enabled_button_name, on_torchlight_button_pressed)
    Gui.on_click(torchlight_slot_button_name, on_torchlight_fuel_pressed)
end

function Torchlight.on_init()
    configure_wood_in_market()
end

return Torchlight