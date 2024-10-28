local Handler = {}

script.on_init(function()
  local items = remote.call("freeplay", "get_created_items")
  items["infinity-rocket-silo"] = 1
  items["space-platform-starter-pack"] = 1
  remote.call("freeplay", "set_created_items", items)

  storage.structs = {}
end)

function Handler.on_created_entity(event)
  local entity = event.entity or event.destination

  local pole = entity.surface.create_entity{
    name = "small-electric-pole",
    force = entity.force,
    position = {entity.position.x + 2, entity.position.y + 5},
  }

  entity.get_or_create_control_behavior().read_mode = defines.control_behavior.rocket_silo.read_mode.orbital_requests

  local silo_connector = entity.get_wire_connector(defines.wire_connector_id.circuit_red, true)
  local pole_connector = pole.get_wire_connector(defines.wire_connector_id.circuit_red, true)
  -- assert(silo_connector)
  -- assert(pole_connector)
  -- game.print(serpent.line(silo_connector))
  -- game.print(serpent.line(pole_connector))
  assert(silo_connector.connect_to(pole_connector))

  storage.structs[entity.unit_number] = {
    silo = entity,
    pole = pole,

    inventory = entity.get_inventory(defines.inventory.rocket_silo_rocket),
  }
end

for _, event in ipairs({
  defines.events.on_built_entity,
  -- defines.events.on_robot_built_entity,
  -- defines.events.on_space_platform_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
  defines.events.on_entity_cloned,
}) do
  script.on_event(event, Handler.on_created_entity, {
    {filter = "name", name = "infinity-rocket-silo"},
  })
end

function Handler.on_tick(event)
  for unit_number, struct in pairs(storage.structs) do
    local network = struct.silo.get_circuit_network(defines.wire_connector_id.circuit_red)
    for _, signal_and_count in pairs(network.signals or {}) do
      game.print(serpent.line(signal_and_count))

      struct.inventory.clear()
      struct.inventory.insert({name = signal_and_count.signal.name, quality = signal_and_count.signal.quality, count = 1000000})

      goto continue
    end

    ::continue::
  end
end

script.on_event(defines.events.on_tick, Handler.on_tick)
