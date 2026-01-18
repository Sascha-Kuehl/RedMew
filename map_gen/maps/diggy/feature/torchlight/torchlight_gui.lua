local Gui = require 'utils.gui'

local frame_name = Gui.uid_name()
local enabled_button_name = Gui.uid_name()
local outer_flow_name = Gui.uid_name()
local inner_flow_name = Gui.uid_name()
local inventory_button_name = Gui.uid_name()
local progressbar_name = Gui.uid_name()

local BUTTON_SIZE = 38
local FRAME_X_OFFSET = 190
local FRAME_Y_OFFSET = 96

local TorchlightGui = {}

--- Checks if the player has enabled the torchlight
--- @param player LuaPlayer player to check
--- @return boolean true if the light is enabled
function TorchlightGui.is_light_enabled(player)
    return player.gui.screen[frame_name][outer_flow_name][enabled_button_name].toggled
end

--- Sets the visibility of the torchlight GUI frame
--- @param player LuaPlayer player whose GUI to modify
--- @param visible boolean whether the frame should be visible
function TorchlightGui.set_visible(player, visible)
    player.gui.screen[frame_name].visible = visible
end

--- Registers click handlers for GUI buttons
--- @param on_enabled_button_clicked function called when the enable/disable button is clicked
--- @param on_inventory_button_clicked function called when the inventory button is clicked
function TorchlightGui.register_click_handlers(on_enabled_button_clicked, on_inventory_button_clicked)
    Gui.on_click(enabled_button_name, on_enabled_button_clicked)
    Gui.on_click(inventory_button_name, on_inventory_button_clicked)
end

--- Repositions the torchlight frame based on the player's display resolution and scale
--- @param player LuaPlayer player whose frame to realign
function TorchlightGui.realign_torchlight_frame(player)
    local frame = player.gui.screen[frame_name]

    local resolution = player.display_resolution
    local scale = player.display_scale

    frame.location = { FRAME_X_OFFSET * scale, resolution.height - (FRAME_Y_OFFSET * scale) }
end

--- Updates the progressbar showing remaining fuel
--- @param player LuaPlayer player whose GUI to update
--- @param light_ticks number of ticks of fuel remaining
--- @param afterburner_ticks number of ticks in the afterburner phase
--- @param ticks_per_wood number of ticks per unit of wood fuel
function TorchlightGui.update_torchlight_progressbar(player, light_ticks, light_ticks_total)
    local progressbar = player.gui.screen[frame_name][outer_flow_name][inner_flow_name][progressbar_name]

    local remaining_ticks = math.max(0, light_ticks_total - light_ticks)

    progressbar.value = light_ticks_total ~= 0 and remaining_ticks / light_ticks_total or 0
    progressbar.tooltip = tostring(remaining_ticks / 60) .. ' sec'
end

--- Updates the inventory button to show current fuel type and count
--- @param player LuaPlayer player whose GUI to update
--- @param inventory LuaInventory the torchlight inventory
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

--- Creates the torchlight GUI frame and buttons for the player
--- @param player LuaPlayer player to create GUI for
--- @param enabled boolean initial state of the light (enabled or disabled)
function TorchlightGui.create_gui(player, enabled)
    local frame = player.gui.screen.add {
        type = 'frame',
        name = frame_name,
        direction = 'vertical'
    }
    frame.style.padding = 1

    local outer_flow = frame.add {
        type = 'flow',
        name = outer_flow_name,
        direction = 'vertical'
    }
    outer_flow.style.vertical_spacing = 2

    local enabled_button = outer_flow.add {
        type = 'sprite-button',
        name = enabled_button_name,
        tooltip = 'Toggle personal light',
        sprite = 'virtual-signal/signal-sun',
        auto_toggle = true,
        toggled = enabled,
        style = 'quick_bar_page_button'
    }
    enabled_button.style.width = BUTTON_SIZE
    enabled_button.style.height = BUTTON_SIZE

    local inner_flow = outer_flow.add {
        type = 'flow',
        name = inner_flow_name,
        direction = 'vertical'
    }
    inner_flow.style.vertical_spacing = 0

    local slot_button = inner_flow.add {
        type = 'sprite-button',
        name = inventory_button_name,
        sprite = 'virtual-signal/signal-fire',
        style = 'tool_equip_ammo_slot'
    }
    slot_button.style.width = BUTTON_SIZE
    slot_button.style.height = BUTTON_SIZE

    local progressbar = inner_flow.add {
        type = 'progressbar',
        name = progressbar_name,
        value = 0.0
    }
    progressbar.style.width = BUTTON_SIZE

    TorchlightGui.realign_torchlight_frame(player)
end

return TorchlightGui
