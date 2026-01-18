local LIGHT_SCALE = 2.0
local LIGHT_SCALE_EFFECT = 1.15
local MAIN_LIGHT_COLOR = { 250, 200, 120 }
local EFFECT_LIGHT_1_COLOR = { 170, 40, 0 }
local EFFECT_LIGHT_2_COLOR = { 200, 100, 0 }
local EFFECT_LIGHT_INTENSITY = 0.25
local EFFECT_LIGHT_1_BLINK = 11
local EFFECT_LIGHT_2_BLINK = 13

local TorchlightLights = {}

--- Creates the main bright light for the torchlight
--- @param target LuaEntity to attach light to
--- @param surface LuaSurface to render on
--- @return LuaRenderObject the created light rendering object
function TorchlightLights.create_main_light(target, surface)
    return rendering.draw_light {
        sprite = 'utility/light_medium',
        color = MAIN_LIGHT_COLOR,
        surface = surface,
        target = target,
    }
end

--- Creates the first effect light (reddish glow with blinking)
--- @param target LuaEntity to attach light to
--- @param surface LuaSurface to render on
--- @return LuaRenderObject the created light rendering object
function TorchlightLights.create_effect_light_1(target, surface)
    return rendering.draw_light {
        sprite = 'utility/light_medium',
        color = EFFECT_LIGHT_1_COLOR,
        surface = surface,
        target = target,
        intensity = EFFECT_LIGHT_INTENSITY,
        blink_interval = EFFECT_LIGHT_1_BLINK
    }
end

--- Creates the second effect light (orange glow with different blinking)
--- @param target LuaEntity to attach light to
--- @param surface LuaSurface to render on
--- @return LuaRenderObject the created light rendering object
function TorchlightLights.create_effect_light_2(target, surface)
    return rendering.draw_light {
        sprite = 'utility/light_medium',
        color = EFFECT_LIGHT_2_COLOR,
        surface = surface,
        target = target,
        intensity = EFFECT_LIGHT_INTENSITY,
        blink_interval = EFFECT_LIGHT_2_BLINK
    }
end

function TorchlightLights.update_light(light_data, enabled)
    local main_light = rendering.get_object_by_id(light_data.light_ids[1])
    local effect_light_1 = rendering.get_object_by_id(light_data.light_ids[2])
    local effect_light_2 = rendering.get_object_by_id(light_data.light_ids[3])

    if light_data.intensity < 0.001 or ((not enabled or light_data.light_ticks >= light_data.light_ticks_total) and light_data.intensity_per_tick == 0) then
        main_light.visible = false
        effect_light_1.visible = false
        effect_light_2.visible = false
        return
    end

    main_light.visible = true
    effect_light_1.visible = true
    effect_light_2.visible = true

    main_light.scale = LIGHT_SCALE * light_data.intensity
    effect_light_1.scale = LIGHT_SCALE * LIGHT_SCALE_EFFECT * light_data.intensity
    effect_light_2.scale = LIGHT_SCALE * LIGHT_SCALE_EFFECT * light_data.intensity
end

function TorchlightLights.destroy_lights(light_ids)
    for _, id in pairs(light_ids) do
        local light_rendering = rendering.get_object_by_id(id)
        if light_rendering then
            light_rendering.destroy()
        end
    end
end

--- Creates light rendering IDs for a target entity
--- @param target LuaEntity to attach lights to
--- @param surface LuaSurface to render on
--- @return table array of light IDs {main_light_id, effect_light_1_id, effect_light_2_id}
function TorchlightLights.create_light_ids(target, surface)
    return {
        TorchlightLights.create_main_light(target, surface).id,
        TorchlightLights.create_effect_light_1(target, surface).id,
        TorchlightLights.create_effect_light_2(target, surface).id
    }
end

return TorchlightLights
