local Color = require('utils.color_presets')
local Public = {}

---@param cmd CustomCommandData
function Public.current_map_seed(cmd)
    local player = cmd.player_index and game.get_player(cmd.player_index)
    if player then
        player.print(
            'Current seed: ' .. game.surfaces[storage.bb_surface_name].map_gen_settings.seed,
            { color = Color.warning }
        )
    end
end

commands.add_command('current-map-seed', 'Get the current map seed for BB surface.', Public.current_map_seed)
return Public
