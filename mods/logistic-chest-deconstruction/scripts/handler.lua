local util = require("__core__.lualib.util")
local Car = require('scripts.car')

-- 

function Handler.tick_storage_chest(entity)
  local surfacedata = global.surfaces[entity.surface.index]
  local struct = surfacedata.storage_chests[entity.unit_number]
  if not (entity.storage_filter and entity.storage_filter.name == "deconstruction-planner") then
    if struct then Handler.delete_storage_chest_index(surfacedata, struct) end
    return
  end

  if struct then return end -- already setup

  game.print("recognized")

  local car = Car.create_for(entity)
  car.destructible = false

  rendering.draw_animation{
    animation = entity.name,
    surface = entity.surface,
    target = entity,
    render_layer = "130", -- 1 above "object"
    animation_speed = 0,
    animation_offset = global.aimation_offset_for[entity.name] - 1, -- offset ontop of 1
  }

  Handler.create_storage_chest_index(surfacedata, {
    entity = entity,
    car = car,
  })
end

--

function Handler.on_robot_post_mined(robot)
  local cargo = robot.get_inventory(defines.inventory.robot_cargo)
  if cargo.is_empty() then return end -- somehow picked up nothing

  local surfacedata = global.surfaces[robot.surface.index]
  -- remove_invalid_entities_from(surfacedata.storage_chests)

  local candidates = {}
  for unit_number, struct in pairs(surfacedata.storage_chests) do
    if struct.entity.valid then -- todo: check team
      table.insert(candidates, struct.entity)
    else
      game.print("[virtual-signal=signal-red] todo: remove invalid entity")
      -- Handler.delete_storage_chest_index(surfacedata, struct)
    end
  end

  local storage_chest = robot.surface.get_closest(robot.position, candidates)
  if storage_chest then
    robot.logistic_network = surfacedata.car_for[storage_chest.unit_number].logistic_network
    Handler.tick_construction_robot({
      robot = robot,
      attempts = 0,
    })
  end
end

function Handler.tick_construction_robot(robot_task)
  assert(type(robot_task.attempts) == "number", "robot_task.attempts isn't a number.")
  robot_task.attempts = robot_task.attempts + 1 -- ideally 3: initial travel estimate, final tile & dropoff
  -- game.print('robot attempt #' .. robot_task.attempts)

  local robot = robot_task.robot

  -- local storage_chest = robot.logistic_cell.owner
  assert(#robot.logistic_network.cells == 1, "construction robot escaped into another network.")
  local car = robot.logistic_network.cells[1].owner
  local distance = util.distance(robot.position, car.position)

  game.print(string.format("bot %d's distance is %f", robot.unit_number, distance))

  if distance > 0.1 then
    -- shoutout to calciumwizard for pointing out it was off
    local prototype = global.robot_prototype_for[robot.name]
    local speed = math.min(prototype.max_speed, prototype.speed * (1 + robot.force.worker_robots_speed_modifier))
    speed = math.min(prototype.max_speed, (robot.energy == 0 and prototype.speed_multiplier_when_out_of_energy or 1) * speed)

    local ticks = math.ceil(distance / speed) -- ticks till overhead
    local at_tick = game.tick + ticks
    assert(ticks > 0, "cannot schedule for the current tick")

    game.print(string.format("at speed %f i'll travel %f tiles in %d ticks", speed, distance, ticks))

    Handler.check_robot_at_tick(robot_task, at_tick)
  else
    local surfacedata = global.surfaces[robot.surface_index]
    local storage_chest = surfacedata.storage_chest_for[car.unit_number]

    local inventory = storage_chest.get_inventory(defines.inventory.chest)
    local cargo_stack = robot.get_inventory(defines.inventory.robot_cargo)[1]

    local inserted = inventory.insert(cargo_stack)
    cargo_stack.count = cargo_stack.count - inserted

    if cargo_stack.count == 0 then
      set_logistic_network(robot, storage_chest.logistic_network)
    else
      for _, player in ipairs(robot.force.connected_players) do
        player.add_alert(storage_chest, defines.alert_type.no_storage)
      end

      local at_tick = game.tick + (60 * robot_task.attempts) -- wait one second more for each failed offload attempt (starts at 2-3)
      Handler.check_robot_at_tick(robot_task, at_tick)
    end
  end
end

return Handler
