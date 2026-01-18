local Gui = require 'utils.gui'

local frame_name = Gui.uid_name()
local enabled_button_name = Gui.uid_name()
local outer_flow_name = Gui.uid_name()
local inner_flow_name = Gui.uid_name()
local inventory_button_name = Gui.uid_name()
local progressbar_name = Gui.uid_name()

local BUTTON_SIZE = 38
local FRAME_X_OFFSET = 1872
local FRAME_Y_OFFSET = 96

local TorchlightGui = {}

-- Returns true if the torchlight is enabled
function TorchlightGui.is_light_enabled(player)
    return player.gui.screen[frame_name][outer_flow_name][enabled_button_name].toggled
end

-- Sets the visibility of the torchlight GUI frame
function TorchlightGui.set_visible(player, visible)
    player.gui.screen[frame_name].visible = visible
end

-- Registers click handlers for GUI buttons
function TorchlightGui.register_click_handlers(on_enabled_button_clicked, on_inventory_button_clicked)
    Gui.on_click(enabled_button_name, on_enabled_button_clicked)
    Gui.on_click(inventory_button_name, on_inventory_button_clicked)
end

-- Repositions the frame based on display resolution and scale
function TorchlightGui.realign_torchlight_frame(player)
    local frame = player.gui.screen[frame_name]
    local scale = player.display_scale
    frame.location = { FRAME_X_OFFSET * scale, player.display_resolution.height - (FRAME_Y_OFFSET * scale) }
end

-- Updates the progressbar showing remaining fuel
function TorchlightGui.update_torchlight_progressbar(player, light_ticks, light_ticks_total)
    local progressbar = player.gui.screen[frame_name][outer_flow_name][inner_flow_name][progressbar_name]
    local remaining_ticks = math.max(0, light_ticks_total - light_ticks)
    progressbar.value = light_ticks_total > 0 and remaining_ticks / light_ticks_total or 0
    progressbar.tooltip = string.format('%d sec', remaining_ticks / 60)
end

-- Updates the inventory button to show current fuel type and count
function TorchlightGui.update_inventory_button(player, inventory)
    local inventory_button = player.gui.screen[frame_name][outer_flow_name][inner_flow_name][inventory_button_name]
    local stack = inventory[1]
    if stack.count == 0 then
        inventory_button.sprite = 'virtual-signal/signal-fire'
        inventory_button.number = nil
    else
        inventory_button.sprite = 'item/' .. stack.name
        inventory_button.number = stack.count
    end
end

function TorchlightGui.build_tooltip(allowed_items)
    local localized_tooltip = {'', {'description.accepted-fuel'}}
    for index, item in pairs(allowed_items) do
        localized_tooltip[2*index+1] = '\n - '
        localized_tooltip[2*index+2] = {'item-name.'..item}
    end
    return localized_tooltip;
end

-- Creates the torchlight GUI frame and buttons for the player
function TorchlightGui.create_gui(player, enabled, allowed_items)
    local frame = player.gui.screen.add { type = 'frame', name = frame_name, direction = 'vertical' }
    frame.style.padding = 1

    local outer_flow = frame.add { type = 'flow', name = outer_flow_name, direction = 'vertical' }
    outer_flow.style.vertical_spacing = 2

    local enabled_button = outer_flow.add {
        type = 'sprite-button', name = enabled_button_name, tooltip = 'Toggle personal light',
        sprite = 'virtual-signal/signal-sun', auto_toggle = true, toggled = enabled, style = 'quick_bar_page_button'
    }
    enabled_button.style.width = BUTTON_SIZE
    enabled_button.style.height = BUTTON_SIZE

    local inner_flow = outer_flow.add { type = 'flow', name = inner_flow_name, direction = 'vertical' }
    inner_flow.style.vertical_spacing = 0

    local slot_button = inner_flow.add {
        type = 'sprite-button', name = inventory_button_name, sprite = 'virtual-signal/signal-fire', style = 'tool_equip_ammo_slot', tooltip = TorchlightGui.build_tooltip(allowed_items)
    }
    slot_button.style.width = BUTTON_SIZE
    slot_button.style.height = BUTTON_SIZE

    inner_flow.add { type = 'progressbar', name = progressbar_name, value = 0.0 }.style.width = BUTTON_SIZE

    TorchlightGui.realign_torchlight_frame(player)
end

return TorchlightGui
