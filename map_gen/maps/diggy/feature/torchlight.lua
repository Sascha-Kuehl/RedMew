local Event = require 'utils.event'
local TorchlightData = require 'map_gen.maps.diggy.feature.torchlight.torchlight_data'
local TorchlightLights = require 'map_gen.maps.diggy.feature.torchlight.torchlight_lights'
local TorchlightGui = require 'map_gen.maps.diggy.feature.torchlight.torchlight_gui'
local InventoryTransferUtil = require 'map_gen.maps.diggy.feature.torchlight.inventory_transfer_util'

local TICK_INTERVAL = 60
local FADE_TICK_INTERVAL = 5
local FADE_IN_STEPS = 1 / 30
local FADE_OUT_STEPS = -1 * FADE_IN_STEPS

local initial_items
local burn_items

local Torchlight = {}

function Torchlight.on_player_created(event)
    local player = game.get_player(event.player_index)
    player.disable_flashlight()

    Torchlight.create_player_light_data(player)
    Torchlight.create_player_torchlight_inventory(player)
    TorchlightGui.create_gui(player, true, Torchlight.get_allowed_item_names())
    Torchlight.update_player_light(player)
end

function Torchlight.on_player_respawned(event)
    local player = game.get_player(event.player_index)
    player.disable_flashlight()

    Torchlight.recreate_lights(player)
    Torchlight.update_player_light(player)
    TorchlightGui.set_visible(player, true)
end

function Torchlight.on_player_joined_game(event)
    local player = game.get_player(event.player_index)

    Torchlight.recreate_lights(player)
    Torchlight.update_player_light(player)
end

function Torchlight.on_pre_player_died(event)
    local player = game.get_player(event.player_index)
    player.character_inventory_slots_bonus = player.character_inventory_slots_bonus + 1
    local inventory = TorchlightData.get_player_inventory(player.index)
    local torchlight_stack = inventory[1]
    player.character.get_main_inventory().find_empty_stack().transfer_stack(torchlight_stack)
    TorchlightGui.update_inventory_button(player, inventory)
end

function Torchlight.build_corpse_id(corpse)
    return tostring(corpse.character_corpse_player_index) .. '-' .. tostring(corpse.character_corpse_tick_of_death)
end

function Torchlight.find_corpse(player, tick)
    local corpses = player.surface.find_entities_filtered({name = 'character-corpse', position = player.position})
    for _, corpse in pairs(corpses) do
        if corpse.character_corpse_player_index == player.index and corpse.character_corpse_tick_of_death == tick then
            return corpse
        end
    end
end

function Torchlight.on_player_died(event)
    local player = game.get_player(event.player_index)
    player.character_inventory_slots_bonus = player.character_inventory_slots_bonus - 1

    local corpse = Torchlight.find_corpse(player, event.tick)
    if not corpse then
        return
    end

    local corpse_id = Torchlight.build_corpse_id(corpse)
    local light_data = TorchlightData.get_player_light_info(player.index)

    -- Transfer remaining light to corpse
    TorchlightData.set_corpse_light_data(corpse_id, {
        light_ticks = 0,
        light_ticks_total = light_data.light_ticks_total - light_data.light_ticks,
        current_scale = light_data.current_scale,
        target_scale = light_data.target_scale,
        full_scale = light_data.full_scale,
        scale_per_tick = light_data.scale_per_tick,
        light_ids = TorchlightLights.create_light_ids(corpse, player.surface)
    })

    -- Reset player light data
    light_data.light_ticks = 0
    light_data.light_ticks_total = 0
    light_data.current_scale = 0
    light_data.target_scale = 0
    light_data.full_scale = 0
    light_data.scale_per_tick = 0

    Torchlight.update_corpse_light(corpse_id)
    TorchlightGui.set_visible(player, false)
    TorchlightGui.update_torchlight_progressbar(player, 0, 0)
end

function Torchlight.on_tick()
    -- Normal consumption logic
    if game.tick % TICK_INTERVAL == 0 then
        Torchlight.update_player_lights_on_tick()
        Torchlight.update_corpse_lights_on_tick()
    end
    -- Fade animations (faster interval)
    if game.tick % FADE_TICK_INTERVAL == 0 then
        Torchlight.update_player_light_fades()
        Torchlight.update_corpse_light_fades()
    end
end

function Torchlight.update_player_light_fades()
    for _, player in pairs(game.connected_players) do
        local light_data = TorchlightData.get_player_light_info(player.index)
        if light_data.scale_per_tick ~= 0 then
            light_data.current_scale = light_data.current_scale + (light_data.scale_per_tick * FADE_TICK_INTERVAL)

            if light_data.scale_per_tick < 0 and light_data.current_scale < light_data.target_scale
            or light_data.scale_per_tick > 0 and light_data.current_scale > light_data.target_scale then
                light_data.current_scale = light_data.target_scale
                light_data.scale_per_tick = 0
            end

            local enabled = TorchlightGui.is_light_enabled(player)
            TorchlightLights.update_light(light_data, enabled)
        end
    end
end

function Torchlight.update_corpse_light_fades()
    for corpse_id, light_data in pairs(TorchlightData.get_corpse_light_data()) do
        if light_data.scale_per_tick ~= 0 then
            light_data.current_scale = light_data.current_scale + (light_data.scale_per_tick * FADE_TICK_INTERVAL)

            if light_data.current_scale <= 0 then
                TorchlightLights.destroy_lights(light_data.light_ids)
                TorchlightData.remove_corpse_light_data(corpse_id)
            end
            TorchlightLights.update_light(light_data, true)
        end
    end
end

function Torchlight.on_torchlight_button_pressed(event)
    local player = event.player
    local light_data = TorchlightData.get_player_light_info(player.index)
    if TorchlightGui.is_light_enabled(player) then
        light_data.scale_per_tick = FADE_IN_STEPS
        light_data.target_scale = light_data.full_scale
    else
        light_data.scale_per_tick = FADE_OUT_STEPS
        light_data.target_scale = 0
    end
    Torchlight.update_player_light(player)
end

function Torchlight.on_player_display_resolution_changed(event)
    local player = game.get_player(event.player_index)
    TorchlightGui.realign_torchlight_frame(player)
end

function Torchlight.on_player_display_scale_changed(event)
    local player = game.get_player(event.player_index)
    TorchlightGui.realign_torchlight_frame(player)
end

function Torchlight.get_allowed_item_names()
    local allowed_item_names = {}
    for index, burn_item in pairs(burn_items)do
        allowed_item_names[index] = burn_item.item
    end
    return allowed_item_names
end

function Torchlight.on_torchlight_fuel_pressed(event)
    local player = game.get_player(event.player_index)
    local inventory = TorchlightData.get_player_inventory(player.index)
    local allowed_items = Torchlight.get_allowed_item_names()
    InventoryTransferUtil.handle_inventory_slot_click(inventory, inventory[1], event, allowed_items)
    TorchlightGui.update_inventory_button(player, inventory)
    Torchlight.update_player_light(player)
end

function Torchlight.create_player_light_data(player)
    TorchlightData.set_player_light_data(player.index, {
        light_ids = TorchlightLights.create_light_ids(player.character, player.surface),
        light_ticks = 0,
        light_ticks_total = 0,
        current_scale = 0,
        target_scale = 0,
        full_scale = 0,
        scale_per_tick = 0  -- positive = fade in, negative = fade out, 0 = idle
    })
end

function Torchlight.create_player_torchlight_inventory(player)
    local inventory = game.create_inventory(1)
    inventory.insert(initial_items)
    TorchlightData.set_torchlight_inventory(player.index, inventory)
end

function Torchlight.get_burn_config(item_name)
    for _, burn_item in pairs(burn_items) do
        if burn_item.item == item_name then
            return burn_item
        end
    end
end

function Torchlight.update_player_light(player)
    if player.ticks_to_respawn then
        return
    end

    local light_data = TorchlightData.get_player_light_info(player.index)
    local is_enabled = TorchlightGui.is_light_enabled(player)
    if not is_enabled then
        TorchlightLights.update_light(light_data, is_enabled)
        return
    end

    if light_data.light_ticks >= light_data.light_ticks_total then
        local inventory = TorchlightData.get_player_inventory(player.index)
        local item_stack = inventory[1]
        if item_stack.count > 0 then
            local burn_config = Torchlight.get_burn_config(item_stack.name)
            if (burn_config) then
                item_stack.count = item_stack.count - 1
                TorchlightGui.update_inventory_button(player, inventory)

                light_data.light_ticks = 0
                light_data.light_ticks_total = burn_config.duration
                light_data.target_scale = burn_config.scale
                light_data.full_scale = burn_config.scale
                if (light_data.current_scale ~= light_data.target_scale) then
                    light_data.scale_per_tick = light_data.current_scale < light_data.target_scale and FADE_IN_STEPS or FADE_OUT_STEPS
                end
                TorchlightLights.update_light(light_data, is_enabled)
                return
            end
        end

        light_data.light_ticks = 0
        light_data.light_ticks_total = 0
        light_data.scale_per_tick = FADE_OUT_STEPS
        light_data.target_scale = 0
    end

    TorchlightLights.update_light(light_data, is_enabled)
end

function Torchlight.update_player_lights_on_tick()
    for _, player in pairs(game.connected_players) do
        local light_data = TorchlightData.get_player_light_info(player.index)
        local enabled = TorchlightGui.is_light_enabled(player)
        if enabled and light_data.light_ticks < light_data.light_ticks_total then
            light_data.light_ticks = light_data.light_ticks + TICK_INTERVAL
            Torchlight.update_player_light(player)
            TorchlightGui.update_torchlight_progressbar(player, light_data.light_ticks, light_data.light_ticks_total)
        end
    end
end

function Torchlight.update_corpse_light(corpse_id)
    local light_data = TorchlightData.get_corpse_light_info(corpse_id)
    if not light_data then
        return
    end

    if light_data.light_ticks < light_data.light_ticks_total then
        TorchlightLights.update_light(light_data, true)
        return
    end

    -- Light burned out, start fade out
    light_data.scale_per_tick = FADE_OUT_STEPS
end

function Torchlight.update_corpse_lights_on_tick()
    local corpse_light_data = TorchlightData.get_corpse_light_data()
    for corpse_id, light_data in pairs(corpse_light_data) do
        light_data.light_ticks = light_data.light_ticks + TICK_INTERVAL
        Torchlight.update_corpse_light(corpse_id)
    end
end

function Torchlight.move_burn_item_to_torchlight_inventory(player, corpse)
    local corpse_inventory = corpse.get_inventory(defines.inventory.character_corpse)
    local torchlight_inventory = TorchlightData.get_player_inventory(player.index)

    for i = #burn_items, 1, -1 do
        local burn_item_stack = corpse_inventory.find_item_stack(burn_items[i].item)
        if burn_item_stack and burn_item_stack.valid_for_read then
            torchlight_inventory[1].transfer_stack(burn_item_stack)
            TorchlightGui.update_inventory_button(player, torchlight_inventory)
        end
    end
end

function Torchlight.takeover_remaining_torchlight_time(player, corpse)
    local corpse_id = Torchlight.build_corpse_id(corpse)
    local corpse_light_data = TorchlightData.get_corpse_light_info(corpse_id)
    local player_light_data = TorchlightData.get_player_light_info(player.index)
    if not (corpse_light_data and player_light_data) then
        return
    end

    player_light_data.light_ticks = corpse_light_data.light_ticks
    player_light_data.light_ticks_total = corpse_light_data.light_ticks_total
    player_light_data.current_scale = corpse_light_data.current_scale
    player_light_data.target_scale = corpse_light_data.target_scale
    player_light_data.full_scale = corpse_light_data.full_scale
    player_light_data.scale_per_tick = corpse_light_data.scale_per_tick

    TorchlightData.remove_corpse_light_data(corpse_id)
    TorchlightGui.update_torchlight_progressbar(player, player_light_data.light_ticks, player_light_data.light_ticks_total)
end

function Torchlight.on_player_mined_entity(event)
    if event.entity and event.entity.type == 'character-corpse' then
        local player = game.get_player(event.player_index)
        Torchlight.takeover_remaining_torchlight_time(player, event.entity)
        Torchlight.update_player_light(player)
    end
end

function Torchlight.on_pre_player_mined_item(event)
    if event.entity and event.entity.type == 'character-corpse' then
        local player = game.get_player(event.player_index)
        Torchlight.move_burn_item_to_torchlight_inventory(player, event.entity)
    end
end

function Torchlight.on_player_controller_changed(event)
    local player = game.get_player(event.player_index)
    local is_in_character_view = player.controller_type == defines.controllers.character
    TorchlightGui.set_visible(player, is_in_character_view)
end

function Torchlight.register(config)
    initial_items = config.initial_items
    burn_items = config.burn_items

    Event.add(defines.events.on_player_created, Torchlight.on_player_created)
    Event.add(defines.events.on_player_respawned, Torchlight.on_player_respawned)
    Event.add(defines.events.on_player_joined_game, Torchlight.on_player_joined_game)
    Event.add(defines.events.on_pre_player_died, Torchlight.on_pre_player_died)
    Event.add(defines.events.on_player_died, Torchlight.on_player_died)
    Event.add(defines.events.on_tick, Torchlight.on_tick)
    Event.add(defines.events.on_player_display_resolution_changed, Torchlight.on_player_display_resolution_changed)
    Event.add(defines.events.on_player_display_scale_changed, Torchlight.on_player_display_scale_changed)
    Event.add(defines.events.on_player_mined_entity, Torchlight.on_player_mined_entity)
    Event.add(defines.events.on_pre_player_mined_item, Torchlight.on_pre_player_mined_item)
    Event.add(defines.events.on_player_controller_changed, Torchlight.on_player_controller_changed)

    TorchlightGui.register_click_handlers(Torchlight.on_torchlight_button_pressed, Torchlight.on_torchlight_fuel_pressed)
end

-- Ensure wood is available in the market at configured level and price
function Torchlight.configure_wood_in_market()
    local unlockables = storage.config.experience.unlockables
    for _, entry in pairs(unlockables) do
        if entry.name == 'wood' then
            entry.level = 1
            entry.price = 4
            return
        end
    end
    table.insert(unlockables, { level = 1, price = 4, name = 'wood' })
end

function Torchlight.on_init()
    if (Torchlight.get_burn_config('wood')) then
        Torchlight.configure_wood_in_market()
    end
end

-- Recreate light rendering objects
function Torchlight.recreate_lights(player)
    local light_data = TorchlightData.get_player_light_info(player.index)
    light_data.light_ids = TorchlightLights.create_light_ids(player.character, player.surface)
end

return Torchlight