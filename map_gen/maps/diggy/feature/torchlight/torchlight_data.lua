local Global = require 'utils.global'

local player_light_data = {}
local corpse_light_data = {}
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

local TorchlightData = {}

function TorchlightData.get_player_light_data()
    return player_light_data
end

function TorchlightData.get_corpse_light_data()
    return corpse_light_data
end

function TorchlightData.set_player_light_data(player_index, data)
    player_light_data[player_index] = data
end

function TorchlightData.set_corpse_light_data(corpse_id, data)
    corpse_light_data[corpse_id] = data
end

function TorchlightData.set_torchlight_inventory(player_index, inventory)
    torchlight_inventory[player_index] = inventory
end

function TorchlightData.get_player_light_info(player_index)
    return player_light_data[player_index]
end

function TorchlightData.get_corpse_light_info(corpse_id)
    return corpse_light_data[corpse_id]
end

function TorchlightData.get_player_inventory(player_index)
    return torchlight_inventory[player_index]
end

function TorchlightData.remove_corpse_light_data(corpse_id)
    corpse_light_data[corpse_id] = nil
end

function TorchlightData.remove_player_light_data(player_index)
    player_light_data[player_index] = nil
end

return TorchlightData
