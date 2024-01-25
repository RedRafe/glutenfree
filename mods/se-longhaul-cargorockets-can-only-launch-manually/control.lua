local Launchpad = {name_rocket_launch_pad = 'se-rocket-launch-pad'}
local LaunchpadGUI = {name_rocket_launch_pad_gui_root = 'se-rocket-launch-pad-gui'}

--

local print_gui = require('scripts.print_gui')

local function reset_launch_trigger_to_manual(entity, player)
  local position = entity.surface.find_non_colliding_position(entity.name, entity.position, 0, 1, true)
  local ghost = entity.surface.create_entity{
    name = 'entity-ghost',
    force = entity.force,
    position = position,
    inner_name = entity.name,
    create_build_effect_smoke = false,
  }

  local _, revived, _ = ghost.revive()

  script.raise_script_revive({entity = revived, tags = {
    name = "Nauvis",
    launch_trigger = "none",
    zone_name = "Nauvis Orbit",
    landing_pad_name = "Nauvis Orbit Landing Pad",
  }})

  entity.copy_settings(revived, player)
  revived.destroy()
end

commands.add_command('reset-launch-trigger-to-manual', nil, function(command)
  local player = game.get_player(command.player_index)
  local selected = player.selected

  if selected and selected.name == Launchpad.name_rocket_launch_pad then

    local root = player.gui.relative[LaunchpadGUI.name_rocket_launch_pad_gui_root]
    if not (root and root.tags and root.tags.unit_number) then return end

    local trigger_dropdown = root.children[2].children[2]['trigger']
    local trigger_selected = trigger_dropdown.items[trigger_dropdown.selected_index][1]

    game.print(trigger_selected)
    if trigger_selected ~= "space-exploration.trigger-none" then
      reset_launch_trigger_to_manual(selected, player)
    end

    -- log(serpent.block( trigger_dropdown.items[trigger_dropdown.selected_index] ))
    -- log(print_gui.serpent(root.children[2].children[2]['trigger']))
    -- reset_launch_trigger_to_manual(selected, player)
  end
end)
