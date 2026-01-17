local Event = require 'utils.event'
local TorchlightData = require 'map_gen.maps.diggy.feature.torchlight.torchlight_data'
local TorchlightLights = require 'map_gen.maps.diggy.feature.torchlight.torchlight_lights'
local TorchlightGui = require 'map_gen.maps.diggy.feature.torchlight.torchlight_gui'
local InventoryTransferUtil = require 'map_gen.maps.diggy.feature.torchlight.inventory_transfer_util'

local TICK_INTERVAL = 60
local FADE_TICK_INTERVAL = 5
local FADE_OUT_TICKS = 60 * 2
local FADE_IN_TICKS = 60 * 1
local TICKS_PER_WOOD = 60 * 60 * 1
local INITIAL_WOOD_COUNT = 10

local Torchlight = {}

function Torchlight.on_player_created(event)
    local player = game.get_player(event.player_index)
    player.disable_flashlight()

    Torchlight.create_or_restore_player_light(player)
    Torchlight.create_player_torchlight_inventory(player)
    TorchlightGui.create_gui(player, true)
    Torchlight.update_player_light(player)
end

function Torchlight.on_player_respawned(event)
    local player = game.get_player(event.player_index)
    player.disable_flashlight()

    Torchlight.create_or_restore_player_light(player)
    Torchlight.update_player_light(player)
    TorchlightGui.set_visible(player, true)
end

function Torchlight.on_player_joined_game(event)
    local player = game.get_player(event.player_index)

    Torchlight.create_or_restore_player_light(player)
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
    for _, a_corpse in pairs(corpses) do
        if a_corpse.character_corpse_player_index == player.index and a_corpse.character_corpse_tick_of_death == tick then
            return a_corpse
        end
    end
    return nil;
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

    local corpse_light_data = {
        light_ticks = 0,
        light_ticks_total = light_data.light_ticks_total - light_data.light_ticks,
        intensity = light_data.intensity,
        intensity_per_tick = light_data.intensity_per_tick,
        light_ids = TorchlightLights.create_light_ids(corpse, player.surface)
    }
    TorchlightData.set_corpse_light_data(corpse_id, corpse_light_data)

    light_data.light_ticks = 0
    light_data.light_ticks_total = 0
    light_data.intensity = 0
    light_data.intensity_per_tick = 0

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
        if light_data.intensity_per_tick ~= 0 then
            light_data.intensity = light_data.intensity + (light_data.intensity_per_tick * FADE_TICK_INTERVAL)

            if light_data.intensity >= 1 then
                light_data.intensity = 1
                light_data.intensity_per_tick = 0
            end

            if light_data.intensity <= 0 then
                light_data.intensity = 0
                light_data.intensity_per_tick = 0
            end

            local enabled = TorchlightGui.is_light_enabled(player)
            TorchlightLights.update_light(light_data, enabled)
        end
    end
end

function Torchlight.update_corpse_light_fades()
    for corpse_id, light_data in pairs(TorchlightData.get_corpse_light_data()) do
        if light_data.intensity_per_tick ~= 0 then
            light_data.intensity = light_data.intensity + (light_data.intensity_per_tick * FADE_TICK_INTERVAL)

            if light_data.intensity <= 0 then
                TorchlightLights.destroy_lights(light_data.light_ids)
                TorchlightData.remove_corpse_light_data(corpse_id)
            end
            TorchlightLights.update_light(light_data, true)
        end
    end
end

function Torchlight.on_torchlight_button_pressed(event)
    local player = event.player
    local enabled = TorchlightGui.is_light_enabled(player)
    local light_data = TorchlightData.get_player_light_info(player.index)
    if enabled then
        light_data.intensity_per_tick = 1 / FADE_IN_TICKS
    else
        light_data.intensity_per_tick = -1 / FADE_OUT_TICKS
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

function Torchlight.on_torchlight_fuel_pressed(event)
    local player = game.get_player(event.player_index)
    local inventory = TorchlightData.get_player_inventory(player.index)
    InventoryTransferUtil.handle_inventory_slot_click(inventory, inventory[1], event, { 'wood' })
    TorchlightGui.update_inventory_button(player, inventory)
    Torchlight.update_player_light(player)
end

function Torchlight.create_or_restore_player_light(player)
    local light_data = TorchlightData.get_player_light_info(player.index)

    if not light_data then
        local light_ids = TorchlightLights.create_light_ids(player.character, player.surface)
        light_data = {
            light_ids = light_ids,

            light_ticks = 0,
            light_ticks_total = 0,

            intensity = 1,
            intensity_per_tick = 0, -- positive number -> fade in, negative number -> fade out, 0 for idle
        }
        TorchlightData.set_player_light_data(player.index, light_data)
        return
    end

    Torchlight.restore_missing_lights(light_data, player.character, player.surface)
end

function Torchlight.create_player_torchlight_inventory(player)
    local inventory = game.create_inventory(1)
    inventory.insert({ name = 'wood', count = INITIAL_WOOD_COUNT })
    TorchlightData.set_torchlight_inventory(player.index, inventory)
end

function Torchlight.update_player_light(player)
    if player.ticks_to_respawn then
        return
    end

    local light_data = TorchlightData.get_player_light_info(player.index)
    local inventory = TorchlightData.get_player_inventory(player.index)
    local isEnabled = TorchlightGui.is_light_enabled(player)

    if not isEnabled then
        return
    end

    if light_data.light_ticks >= light_data.light_ticks_total then
        local item_stack = inventory[1]
        if item_stack.count > 0 then
            item_stack.count = item_stack.count - 1
            light_data.light_ticks = 0
            light_data.light_ticks_total = TICKS_PER_WOOD
            light_data.intensity_per_tick = 1 / FADE_IN_TICKS

            TorchlightGui.update_inventory_button(player, inventory)
        else
            light_data.light_ticks = 0
            light_data.light_ticks_total = 0
            light_data.intensity_per_tick = -1 / FADE_OUT_TICKS
        end
    end

    TorchlightLights.update_light(light_data, isEnabled)
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

    -- light burned out -> start fade out
    light_data.intensity_per_tick = -1 / FADE_OUT_TICKS
end

function Torchlight.update_corpse_lights_on_tick()
    local corpse_light_data = TorchlightData.get_corpse_light_data()
    for corpse_id, light_data in pairs(corpse_light_data) do
        light_data.light_ticks = light_data.light_ticks + TICK_INTERVAL
        Torchlight.update_corpse_light(corpse_id)
    end
end

function Torchlight.move_wood_to_torchlight_inventory(player, corpse)
    local corpse_inventory = corpse.get_inventory(defines.inventory.character_corpse)
    local torchlight_inventory = TorchlightData.get_player_inventory(player.index)
    local wood_stack = corpse_inventory.find_item_stack('wood')
    if wood_stack and wood_stack.valid_for_read then
        torchlight_inventory[1].transfer_stack(wood_stack)
        TorchlightGui.update_inventory_button(player, torchlight_inventory)
    end
end

function Torchlight.takeover_remaining_torchlight_time(player, corpse)
    local corpse_id = Torchlight.build_corpse_id(corpse)
    local corpse_light_data = TorchlightData.get_corpse_light_info(corpse_id)
    local player_light_data = TorchlightData.get_player_light_info(player.index)
    if not corpse_light_data or not player_light_data then
        return
    end

    player_light_data.light_ticks_total = corpse_light_data.light_ticks_total - corpse_light_data.light_ticks
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
        Torchlight.move_wood_to_torchlight_inventory(player, event.entity)
    end
end

function Torchlight.register()
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

    TorchlightGui.register_click_handlers(Torchlight.on_torchlight_button_pressed, Torchlight.on_torchlight_fuel_pressed)
end

--- Ensures wood is available in the market at the configured level and price
function Torchlight.configure_wood_in_market()
    local redmew_config = storage.config
    for _, entry in pairs(redmew_config.experience.unlockables) do
        if entry.name == 'wood' then
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

function Torchlight.on_init()
    Torchlight.configure_wood_in_market()
end

--- Restores missing light rendering objects from stored IDs
--- @param light_data table containing light_ids array
--- @param target LuaEntity to attach lights to
--- @param surface LuaSurface to render on
function Torchlight.restore_missing_lights(light_data, target, surface)
    local main_light = rendering.get_object_by_id(light_data.light_ids[1])
    if not main_light then
        main_light = TorchlightLights.create_main_light(target, surface)
        light_data.light_ids[1] = main_light.id
    end

    local effect_light_1 = rendering.get_object_by_id(light_data.light_ids[2])
    if not effect_light_1 then
        effect_light_1 = TorchlightLights.create_effect_light_1(target, surface)
        light_data.light_ids[2] = effect_light_1.id
    end

    local effect_light_2 = rendering.get_object_by_id(light_data.light_ids[3])
    if not effect_light_2 then
        effect_light_2 = TorchlightLights.create_effect_light_2(target, surface)
        light_data.light_ids[3] = effect_light_2.id
    end
end

return Torchlight