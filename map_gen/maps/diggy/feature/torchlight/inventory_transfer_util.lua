local Table = require 'utils.table'

--- Utility module for managing inventory transfers in Factorio
local InventoryUtil = {}

--- Checks if a click event is a left mouse button click
--- @param click_event table The click event to check
--- @return boolean True if left click, false otherwise
local function is_left_click(click_event)
    return click_event.button == defines.mouse_button_type.left
end

--- Checks if a click event is a right mouse button click
--- @param click_event table The click event to check
--- @return boolean True if right click, false otherwise
local function is_right_click(click_event)
    return click_event.button == defines.mouse_button_type.right
end

--- Determines the pickup count based on total items and click type
--- Left click: transfer all, Right click: transfer half (or 1 if only 1 item)
--- @param total number Total number of items available
--- @param click_event table The click event to evaluate
--- @return number The number of items to pick up
local function get_pickup_count(total, click_event)
    if is_left_click(click_event) then
        return total
    elseif is_right_click(click_event) then
        return total == 1 and 1 or math.floor(total / 2)
    else
        return 0
    end
end

--- Creates a new stack with specified count while preserving item properties
--- @param stack LuaItemStack The source stack to copy from
--- @param count number The new count for the stack
--- @return table A new stack table with updated count
local function copy_stack_with_new_count(stack, count)
    return {
        name = stack.name,
        quality = stack.quality,
        health = stack.health,
        durability = stack.is_tool and stack.durability or nil,
        ammo = stack.is_ammo and stack.ammo or nil,
        spoil_percent = stack.spoil_percent,
        count = count
    }
end

--- Transfers items from source inventory to player's main inventory
--- @param player table The player object
--- @param source_inventory table The source inventory to transfer from
--- @param source_stack table The stack being transferred
--- @param click_event table The click event (determines transfer amount)
--- @param count number The maximum items available to transfer
local function transfer_items_to_main(player, source_inventory, source_stack, click_event, count)
    if not player or not player.character then
        return
    end

    local main_inventory = player.character.get_main_inventory()
    if not main_inventory then
        return
    end

    local pick_count = get_pickup_count(count, click_event)
    local insertable_count = main_inventory.get_insertable_count(source_stack)
    
    if insertable_count < pick_count then
        pick_count = insertable_count
    end

    local transfer_stack = copy_stack_with_new_count(source_stack, pick_count)
    main_inventory.insert(transfer_stack)
    source_inventory.remove(transfer_stack)

    if transfer_stack.name then
        player.play_sound({path = 'item-move/' .. transfer_stack.name})
    end
end

--- Transfers all stacks of a specific item type to player's main inventory
--- @param player table The player object
--- @param source_inventory table The source inventory to transfer from
--- @param source_stack table The stack type being transferred
--- @param click_event table The click event (determines transfer amount)
local function transfer_all_stacks_to_main(player, source_inventory, source_stack, click_event)
    local item_count = source_inventory.get_item_count(source_stack)
    transfer_items_to_main(player, source_inventory, source_stack, click_event, item_count)
end

--- Transfers one stack to player's main inventory
--- @param player table The player object
--- @param source_inventory table The source inventory to transfer from
--- @param source_stack table The stack being transferred
--- @param click_event table The click event (determines transfer amount)
local function transfer_stack_to_main(player, source_inventory, source_stack, click_event)
    transfer_items_to_main(player, source_inventory, source_stack, click_event, source_stack.count)
end

--- Picks up a stack from inventory to player's cursor
--- @param player table The player object
--- @param source_stack table The stack to pick up
--- @param cursor_stack table The player's cursor stack
--- @param click_event table The click event (determines pickup amount)
local function pickup_stack_to_cursor(player, source_stack, cursor_stack, click_event)
    local pick_count = get_pickup_count(source_stack.count, click_event)
    cursor_stack.transfer_stack(source_stack, pick_count)

    if cursor_stack.name then
        player.play_sound({path = 'item-pick/' .. cursor_stack.name})
    end
end

--- Pushes items from player's cursor to inventory slot
--- @param player table The player object
--- @param source_stack table The destination stack in inventory
--- @param cursor_stack table The player's cursor stack
--- @param click_event table The click event (determines push amount/behavior)
local function push_stack_from_cursor(player, source_stack, cursor_stack, click_event)
    -- Swap stacks if destination is empty or items don't match
    if is_left_click(click_event) and (source_stack.count == 0 or cursor_stack.name ~= source_stack.name or cursor_stack.quality ~= source_stack.quality) then
        source_stack.swap_stack(cursor_stack)
        if source_stack.name then
            player.play_sound({path = 'item-drop/' .. source_stack.name})
        end
        return
    end

    local push_count
    if is_left_click(click_event) then
        push_count = cursor_stack.count
    elseif is_right_click(click_event) then
        push_count = 1
    else
        return
    end

    source_stack.transfer_stack(cursor_stack, push_count)
    if source_stack.name then
        player.play_sound({path = 'item-drop/' .. source_stack.name})
    end
end

--- Handles inventory slot click events with keyboard modifiers and mouse buttons
--- Control + Click: transfer all stacks to main inventory
--- Shift + Click: transfer one stack to main inventory
--- Left Click: pickup to cursor or push from cursor
--- Right Click: pickup half stack or push 1 item
--- @param source_inventory table The inventory being clicked
--- @param source_stack table The stack at the clicked slot
--- @param click_event table The click event containing button and modifier info
--- @param accepted_items table Array of item names that can be pushed to this inventory
function InventoryUtil.handle_inventory_slot_click(source_inventory, source_stack, click_event, accepted_items)
    if not click_event or not click_event.player_index then
        return
    end

    local player = game.get_player(click_event.player_index)
    if not player or not player.cursor_stack then
        return
    end

    local cursor_stack = player.cursor_stack
    if cursor_stack == nil then
        return
    end

    if click_event.control then
        if source_stack.count == 0 then
            transfer_whole_inventory_to_main(player, source_inventory, click_event)
        else
            transfer_all_stacks_to_main(player, source_inventory, source_stack, click_event)
        end
    elseif click_event.shift then
        transfer_stack_to_main(player, source_inventory, source_stack, click_event)
    else
        if cursor_stack.count == 0 then
            if source_stack.count == 0 then
                return
            end
            pickup_stack_to_cursor(player, source_stack, cursor_stack, click_event)
        else
            if not (accepted_items and Table.contains(accepted_items, cursor_stack.name)) then
                return
            end
            push_stack_from_cursor(player, source_stack, cursor_stack, click_event)
        end
    end
end

--- Placeholder for future functionality: transfer entire inventory to main
--- Currently not implemented
--- @param player table The player object
--- @param source_inventory table The source inventory to transfer from
--- @param click_event table The click event
local function transfer_whole_inventory_to_main(player, source_inventory, click_event)
    -- TODO: Implement bulk transfer of entire inventory contents
end

return InventoryUtil