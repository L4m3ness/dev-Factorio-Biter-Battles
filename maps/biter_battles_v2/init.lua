local Terrain = require('maps.biter_battles_v2.terrain')
local Score = require('comfy_panel.score')
local Tables = require('maps.biter_battles_v2.tables')
local Blueprint = require('maps.biter_battles_v2.blueprints')
local Queue = require('utils.queue')
local q_size = Queue.size
local q_push = Queue.push
local q_pop = Queue.pop

local Public = {}

local function createTrollSong(forceName, offset)
    local bp_string = Blueprint.get_blueprint('jail_song')
    local jailSurface = game.surfaces['gulag']
    local bp_entity = jailSurface.create_entity({ name = 'item-on-ground', position = offset, stack = 'blueprint' })
    bp_entity.stack.import_stack(bp_string)
    local bp_entities = bp_entity.stack.get_blueprint_entities()
    local bpInfo = { surface = jailSurface, force = forceName, position = offset, force_build = 'true' }
    local bpResult = bp_entity.stack.build_blueprint(bpInfo)
    bp_entity.destroy()
    for k, v in pairs(bpResult) do
        if k == 27 then
            v.get_control_behavior().enabled = false
        end
        if k == 28 then
            v.get_control_behavior().enabled = true
        end
        v.revive()
    end
    local songBuildings = jailSurface.find_entities_filtered({
        area = { { -11 + offset.x, -23 + offset.y }, { 12 + offset.x, 25 + offset.y } },
        name = {
            'constant-combinator',
            'decider-combinator',
            'substation',
            'programmable-speaker',
            'arithmetic-combinator',
            'electric-energy-interface',
        },
    })
    for k, v in pairs(songBuildings) do
        v.minable_flag = false
        v.destructible = false
        v.operable = false
    end
end

function Public.initial_setup()
    game.map_settings.enemy_evolution.time_factor = 0
    game.map_settings.enemy_evolution.destroy_factor = 0
    game.map_settings.enemy_evolution.pollution_factor = 0
    game.map_settings.pollution.enabled = false
    game.map_settings.enemy_expansion.enabled = false

    game.map_settings.path_finder.fwd2bwd_ratio = 2 -- default 5
    game.map_settings.path_finder.goal_pressure_ratio = 3 -- default 2
    game.map_settings.path_finder.general_entity_collision_penalty = 5 -- default 10
    game.map_settings.path_finder.general_entity_subsequent_collision_penalty = 1 -- default 3
    game.map_settings.path_finder.short_cache_size = 30 -- default 5
    game.map_settings.path_finder.long_cache_size = 50 -- default 25
    game.map_settings.path_finder.short_cache_min_cacheable_distance = 10 -- default 10
    game.map_settings.path_finder.long_cache_min_cacheable_distance = 60 -- default 30
    game.map_settings.path_finder.short_cache_min_algo_steps_to_cache = 50 -- default 50
    game.map_settings.path_finder.max_clients_to_accept_any_new_request = 4 -- default 10
    game.map_settings.path_finder.max_clients_to_accept_short_new_request = 150 -- default 100
    game.map_settings.path_finder.start_to_goal_cost_multiplier_to_terminate_path_find = 10000 -- default 2000

    game.create_force('north')
    game.create_force('south')
    game.create_force('north_biters')
    game.create_force('south_biters')
    game.create_force('north_biters_boss')
    game.create_force('south_biters_boss')
    game.create_force('spectator')

    game.forces.spectator.set_surface_hidden('gulag', true)
    game.forces.north.set_surface_hidden('gulag', true)
    game.forces.south.set_surface_hidden('gulag', true)
    game.forces.spectator.set_surface_hidden('nauvis', true)
    game.forces.north.set_surface_hidden('nauvis', true)
    game.forces.south.set_surface_hidden('nauvis', true)
    game.forces.spectator.research_all_technologies()
    local defs = {
        defines.input_action.import_blueprint_string,
        defines.input_action.open_blueprint_library_gui,
    }
    local p = game.permissions.get_group('Default')
    for k, v in pairs(defs) do
        p.set_allows_action(v, false)
    end

    p = game.permissions.create_group('spectator')
    for action_name, _ in pairs(defines.input_action) do
        p.set_allows_action(defines.input_action[action_name], false)
    end

    defs = {
        defines.input_action.admin_action,
        defines.input_action.change_active_item_group_for_filters,
        defines.input_action.change_active_quick_bar,
        defines.input_action.change_multiplayer_config,
        defines.input_action.clear_cursor,
        defines.input_action.edit_permission_group,
        defines.input_action.gui_checked_state_changed,
        defines.input_action.gui_click,
        defines.input_action.gui_confirmed,
        defines.input_action.gui_elem_changed,
        defines.input_action.gui_location_changed,
        defines.input_action.gui_selected_tab_changed,
        defines.input_action.gui_selection_state_changed,
        defines.input_action.gui_switch_state_changed,
        defines.input_action.gui_text_changed,
        defines.input_action.gui_value_changed,
        defines.input_action.map_editor_action,
        defines.input_action.open_character_gui,
        defines.input_action.quick_bar_set_selected_page,
        defines.input_action.quick_bar_set_slot,
        defines.input_action.remote_view_surface,
        defines.input_action.set_filter,
        defines.input_action.set_player_color,
        defines.input_action.spawn_item,
        defines.input_action.start_walking,
        defines.input_action.toggle_map_editor,
        defines.input_action.toggle_show_entity_info,
        defines.input_action.write_to_console,
    }
    for _, d in pairs(defs) do
        p.set_allows_action(d, true)
    end

    storage.suspend_time_limit = 3600
    storage.automatic_captain_time_left = 0
    storage.reroll_time_limit = 45 * 60 -- 45 seconds
    storage.automatic_captain_time_limit = 45 * 60 -- 45 seconds
    storage.automatic_captain_time_to_start_it = 5 * 60 * 60 -- 5 minutes
    storage.automatic_captain_time_remaining_for_start = 5 * 60 * 60 -- 5 minutes
    storage.automatic_captain_prepa_time_to_start_it = 10 * 60 * 60 -- 10 minutes
    storage.automatic_captain_prepa_time_remaining_for_start = 10 * 60 * 60 -- 10 minutes
    storage.automatic_captain_min_connected_players_for_vote = 25

    storage.chart_queue = Queue.new()
    storage.gui_refresh_delay = 0
    storage.bb_debug = false
    storage.bb_draw_revive_count_text = false
    storage.bb_show_research_info = 'always' -- "always", "spec", nil
    storage.ignore_lists = {}
    storage.reply_target = {}
    storage.bb_settings = {
        --TEAM SETTINGS--
        ['team_balancing'] = true, --Should players only be able to join a team that has less or equal members than the opposing team?
        ['only_admins_vote'] = false, --Are only admins able to vote on the global difficulty?
        --MAP SETTINGS--
        ['new_year_island'] = false,
        ['bb_map_reveal_toggle'] = true,
        ['automatic_captain'] = true,
        ['map_reroll'] = true,
        ['burners_balance'] = true,
    }
    storage.gui_theme = {}
    storage.want_pings = {}
    storage.want_pings_default_value = true
    storage.default_clear_corpses_radius = 160
    storage.total_time_online_players = {}
    storage.already_logged_current_session_time_online_players = {}
    ---Holds information about announcement
    ---@class AnnouncementData
    ---@field entity LuaEntity? Reference to speech-bubble entity
    ---@field text string? Text for speech-bubble
    storage.announcement = {}
    ---@type table<string, TeamstatsPreferences>
    storage.teamstats_preferences = {}
    storage.allow_teamstats = 'always'
    storage.use_old_pick_ui = false
    --Disable Nauvis
    local surface = game.surfaces[1]
    local map_gen_settings = surface.map_gen_settings
    map_gen_settings.height = 3
    map_gen_settings.width = 3
    surface.map_gen_settings = map_gen_settings
    for chunk in surface.get_chunks() do
        surface.delete_chunk({ chunk.x, chunk.y })
    end
    createTrollSong(game.forces.south.name, { x = 6, y = 0 })
    createTrollSong(game.forces.north.name, { x = -40, y = 0 })
    createTrollSong(game.forces.spectator.name, { x = -80, y = 0 })
end

--Terrain Playground Surface
function Public.playground_surface()
    local map_gen_settings = {}
    map_gen_settings.seed = storage.next_map_seed
    -- reset next_map_seed for next round
    storage.next_map_seed = 1
    Terrain.adjust_map_gen_settings(map_gen_settings)
    local surface = game.create_surface(storage.bb_surface_name, map_gen_settings)
    surface.brightness_visual_weights = { -1.17, -0.975, -0.52 }
end

function Public.draw_structures()
    Terrain.generate_initial_structures(game.surfaces[storage.bb_surface_name])
end

function Public.queue_reveal_map()
    local chart_queue = storage.chart_queue
    -- important to flush the queue upon resetting a map or chunk requests from previous maps could overlap
    Queue.clear(chart_queue)

    local width = 2000 -- for one side
    local height = 500 -- for one side

    for x = 16, width, 32 do
        for y = 16, height, 32 do
            q_push(chart_queue, { { -x, -y }, { -x, -y } })
            q_push(chart_queue, { { x, -y }, { x, -y } })
            q_push(chart_queue, { { -x, y }, { -x, y } })
            q_push(chart_queue, { { x, y }, { x, y } })

            if x == 496 and y == 496 then
                -- request whole starting area at the end again to clear any charting hiccup
                q_push(chart_queue, { { -height, -height }, { height, height } })
            end
        end
        -- spectator island (guarantees sounds to be played during map reveal)
        q_push(chart_queue, { { -16, -16 }, { 16, 16 } })
    end
end

---@param max_requests number
function Public.pop_chunk_request(max_requests)
    if not storage.bb_settings.bb_map_reveal_toggle then
        return
    end
    max_requests = max_requests or 1
    local chart_queue = storage.chart_queue
    local surface = game.surfaces[storage.bb_surface_name]
    local spectator = game.forces.spectator

    while max_requests > 0 and q_size(chart_queue) > 0 do
        spectator.chart(surface, q_pop(chart_queue))
        max_requests = max_requests - 1
    end
end

function Public.tables()
    local get_score = Score.get_table()
    get_score.score_table = {}
    storage.research_info = { completed = {}, current_progress = { north = {}, south = {} } }
    storage.science_logs_text = nil
    storage.science_logs_total_north = nil
    storage.science_logs_total_south = nil
    ---@type TeamStats
    storage.team_stats = {
        forces = {
            north = { items = {}, food = {}, damage_types = {} },
            south = { items = {}, food = {}, damage_types = {} },
        },
    }
    storage.last_teamstats_print_at = 0
    -- Name of main BB surface within game.surfaces
    -- We hot-swap here between 2 surfaces.
    if storage.bb_surface_name == 'bb0' then
        storage.bb_surface_name = 'bb1'
    else
        storage.bb_surface_name = 'bb0'
    end

    storage.suspended_time = 36000
    storage.pings_to_remove = {}

    ---@class SuspendTargetInfo
    ---@field suspendee_player_name string
    ---@field suspendee_force_name string
    ---@field suspender_player_name string
    ---@field suspend_votes_by_player table<string, int>

    ---@type SuspendTargetInfo|nil
    storage.suspend_target_info = nil
    ---Name and tick suspended at
    ---@type table<string, int>
    storage.suspended_players = {}
    if storage.next_map_seed == nil or storage.next_map_seed < 341 then
        -- Seeds 1-341 inclusive are the same
        -- https://lua-api.factorio.com/latest/classes/LuaRandomGenerator.html#re_seed
        storage.next_map_seed = math.random(341, 4294967294)
    end
    storage.reroll_map_voting = {}
    storage.automatic_captain_voting = {}
    storage.bb_evolution = {}
    storage.benchmark_mode = false
    storage.bb_game_won_by_team = nil
    storage.bb_game_start_tick = nil
    storage.bb_threat = {}
    storage.bb_threat_income = {}
    storage.chosen_team = {}
    storage.got_burners = {}
    storage.combat_balance = {}
    storage.difficulty_player_votes = {}
    storage.evo_raise_counter = 1
    storage.force_area = {}
    storage.main_attack_wave_amount = 0
    storage.map_pregen_message_counter = {}
    storage.rocket_silo = {}
    storage.spectator_rejoin_delay = {}
    storage.spy_fish_timeout = {}
    storage.tm_custom_name = {}
    storage.total_passive_feed_redpotion = 0
    storage.unit_spawners = {}
    ---@type table<integer, HighHealthUnit>
    storage.high_health_units = {}
    storage.unit_spawners.north_biters = {}
    storage.unit_spawners.south_biters = {}
    storage.ai_targets = {}
    storage.player_data_afk = {}
    storage.max_group_size_initial = 300 --Maximum unit group size for all biters at start, just used as a reference, doesnt change initial group size.
    storage.max_group_size = {}
    storage.max_group_size['north_biters'] = 300 --Maximum unit group size for north biters.
    storage.max_group_size['south_biters'] = 300 --Maximum unit group size for south biters.
    storage.biter_spawn_unseen = {
        ['north'] = {
            ['medium-spitter'] = true,
            ['medium-biter'] = true,
            ['big-spitter'] = true,
            ['big-biter'] = true,
            ['behemoth-spitter'] = true,
            ['behemoth-biter'] = true,
        },
        ['south'] = {
            ['medium-spitter'] = true,
            ['medium-biter'] = true,
            ['big-spitter'] = true,
            ['big-biter'] = true,
            ['behemoth-spitter'] = true,
            ['behemoth-biter'] = true,
        },
        ['north_biters_boss'] = {
            ['medium-spitter'] = true,
            ['medium-biter'] = true,
            ['big-spitter'] = true,
            ['big-biter'] = true,
            ['behemoth-spitter'] = true,
            ['behemoth-biter'] = true,
        },
        ['south_biters_boss'] = {
            ['medium-spitter'] = true,
            ['medium-biter'] = true,
            ['big-spitter'] = true,
            ['big-biter'] = true,
            ['behemoth-spitter'] = true,
            ['behemoth-biter'] = true,
        },
    }
    storage.difficulty_vote_value = 0.75
    storage.difficulty_vote_index = 4

    storage.difficulty_votes_timeout = 36000
    storage.threat_multiplier = nil

    -- Maximum evolution threshold after which biters have 100% chance
    -- to reanimate. The reanimation starts after evolution factor reaches
    -- 100, so this value starts having an effect only at that point.
    -- To reach 100% reanimation chance at 200% evolution, set it to 100.
    -- To reach 100% reanimation chance at 350% evolution, set it to 250.
    -- This is used to calculate biter_health_factor.
    storage.max_reanim_thresh = 250

    -- Container for storing health factor, accessed by key with force's index.
    ---@type table<integer, number>
    storage.biter_health_factor = {}

    local rng = game.create_random_generator(storage.next_map_seed)
    storage.next_attack = 'north'
    if rng(1, 2) == 1 then
        storage.next_attack = 'south'
    end

    -- Clear all ping UIs.  Otherwise, if a map reset happens when a ping is
    -- visible, it will be permanently visible.
    for _, player in pairs(game.connected_players) do
        local ping_messages = player.gui.screen.ping_messages
        if ping_messages then
            ping_messages.destroy()
        end
        local ping_header = player.gui.screen.ping_header
        if ping_header then
            ping_header.destroy()
        end
    end
end

function Public.forces()
    for _, force in pairs(game.forces) do
        if force.name ~= 'spectator' then
            force.reset()
            force.reset_evolution()
        end
    end

    local surface = game.surfaces[storage.bb_surface_name]

    local f = game.forces['north']
    f.set_spawn_position({ 0, -44 }, surface)
    f.set_cease_fire('player', true)
    f.set_friend('spectator', true)
    f.set_friend('south_biters', true)
    f.set_friend('south_biters_boss', true)
    f.share_chart = true

    local f = game.forces['south']
    f.set_spawn_position({ 0, 44 }, surface)
    f.set_cease_fire('player', true)
    f.set_friend('spectator', true)
    f.set_friend('north_biters', true)
    f.set_friend('north_biters_boss', true)
    f.share_chart = true

    local f = game.forces['north_biters']
    f.set_friend('south_biters', true)
    f.set_friend('south_biters_boss', true)
    f.set_friend('north_biters_boss', true)
    f.set_friend('south', true)
    f.set_friend('player', true)
    f.set_friend('spectator', true)
    f.share_chart = false

    local f = game.forces['south_biters']
    f.set_friend('north_biters', true)
    f.set_friend('north_biters_boss', true)
    f.set_friend('south_biters_boss', true)
    f.set_friend('north', true)
    f.set_friend('player', true)
    f.set_friend('spectator', true)
    f.share_chart = false

    local f = game.forces['north_biters_boss']
    f.set_friend('south_biters', true)
    f.set_friend('north_biters', true)
    f.set_friend('south_biters_boss', true)
    f.set_friend('south', true)
    f.set_friend('player', true)
    f.set_friend('spectator', true)
    f.share_chart = false

    local f = game.forces['south_biters_boss']
    f.set_friend('north_biters', true)
    f.set_friend('south_biters', true)
    f.set_friend('north_biters_boss', true)
    f.set_friend('north', true)
    f.set_friend('player', true)
    f.set_friend('spectator', true)
    f.share_chart = false

    local f = game.forces['spectator']
    f.set_spawn_position({ 0, 0 }, surface)
    f.technologies['toolbelt'].researched = true
    f.set_cease_fire('north_biters', true)
    f.set_cease_fire('south_biters', true)
    f.set_friend('north', true)
    f.set_friend('south', true)
    f.set_cease_fire('player', true)
    f.share_chart = true

    local f = game.forces['player']
    f.set_spawn_position({ 0, 0 }, surface)
    f.set_cease_fire('spectator', true)
    f.set_cease_fire('north_biters', true)
    f.set_cease_fire('south_biters', true)
    f.set_cease_fire('north', true)
    f.set_cease_fire('south', true)
    f.share_chart = false

    for _, force in pairs(game.forces) do
        game.forces[force.name].technologies['artillery'].enabled = false
        game.forces[force.name].technologies['artillery-shell-range-1'].enabled = false
        game.forces[force.name].technologies['artillery-shell-speed-1'].enabled = false
        game.forces[force.name].technologies['atomic-bomb'].enabled = false
        game.forces[force.name].technologies['cliff-explosives'].enabled = false
        game.forces[force.name].technologies['land-mine'].enabled = false
        storage.ai_targets[force.name] = { available = {}, available_list = {} }
        storage.ai_target_destroyed_map = {}
        storage.spy_fish_timeout[force.name] = 0
        storage.bb_evolution[force.name] = 0
        storage.biter_health_factor[force.index] = 1.0
        storage.bb_threat_income[force.name] = 0
        storage.bb_threat[force.name] = 0
    end
    for _, force in pairs(Tables.ammo_modified_forces_list) do
        for ammo_category, value in pairs(Tables.base_ammo_modifiers) do
            game.forces[force].set_ammo_damage_modifier(ammo_category, value)
        end
    end

    for _, force in pairs(Tables.ammo_modified_forces_list) do
        for turret_category, value in pairs(Tables.base_turret_attack_modifiers) do
            game.forces[force].set_turret_attack_modifier(turret_category, value)
        end
    end
end

return Public
