TargetBot.Creature.attack = function(params, targets, isLooting) -- params {config, creature, danger, priority}
  if player:isWalking() then
    lastWalk = now
  end

  local config = params.config
  local creature = params.creature
  
  if g_game.getAttackingCreature() ~= creature then
    g_game.attack(creature)
  end

  if not isLooting then -- walk only when not looting
    TargetBot.Creature.walk(creature, config, targets)
  end

  -- attacks
  local mana = player:getMana()
  if config.useGroupAttack and config.groupAttackSpell:len() > 1 and mana > config.minManaGroup then
    local creatures = g_map.getSpectatorsInRange(player:getPosition(), false, config.groupAttackRadius, config.groupAttackRadius)
    local playersAround = false
    local monsters = 0
    for _, creature in ipairs(creatures) do
      if not creature:isLocalPlayer() and creature:isPlayer() and (not config.groupAttackIgnoreParty or creature:getShield() <= 2) then
        playersAround = true
      elseif creature:isMonster() then
        monsters = monsters + 1
      end
    end
    if monsters >= config.groupAttackTargets and (not playersAround or config.groupAttackIgnorePlayers) then
      if TargetBot.sayAttackSpell(config.groupAttackSpell, config.groupAttackDelay) then
        return
      end
    end
  end

  if config.useGroupAttackRune and config.groupAttackRune > 100 then
    local creatures = g_map.getSpectatorsInRange(creature:getPosition(), false, config.groupRuneAttackRadius, config.groupRuneAttackRadius)
    local playersAround = false
    local monsters = 0
    for _, creature in ipairs(creatures) do
      if not creature:isLocalPlayer() and creature:isPlayer() and (not config.groupAttackIgnoreParty or creature:getShield() <= 2) then
        playersAround = true
      elseif creature:isMonster() then
        monsters = monsters + 1
      end
    end
    if monsters >= config.groupRuneAttackTargets and (not playersAround or config.groupAttackIgnorePlayers) then
      if TargetBot.useAttackItem(config.groupAttackRune, 0, creature, config.groupRuneAttackDelay) then
        return
      end
    end
  end
  if config.useSpellAttack and config.attackSpell:len() > 1 and mana > config.minMana then
    if TargetBot.sayAttackSpell(config.attackSpell, config.attackSpellDelay) then
      return
    end
  end
  if config.useRuneAttack and config.attackRune > 100 then
    if TargetBot.useAttackItem(config.attackRune, 0, creature, config.attackRuneDelay) then
      return
    end
  end
end

if not storage.targetBotTargets then
  storage.targetBotTargets = 0
end
TargetBot.Creature.walk = function(creature, config, targets)
  local cpos = creature:getPosition()
  local pos = player:getPosition()
  
  local isTrapped = true
  local pos = player:getPosition()
  local dirs = {{-1,1}, {0,1}, {1,1}, {-1, 0}, {1, 0}, {-1, -1}, {0, -1}, {1, -1}}
  for i=1,#dirs do
    local tile = g_map.getTile({x=pos.x-dirs[i][1],y=pos.y-dirs[i][2],z=pos.z})
    if tile and tile:isWalkable(false) then
      isTrapped = false
    end
  end

  -- data for external dynamic lure
  if config.lureMin and config.lureMax then
    if config.lureMin >= targets then
      storage.TargetBotLure = true
    elseif targets >= config.lureMax then
      storage.TargetBotLure = false
    end
  end
  storage.targetBotTargets = targets
  storage.targetBotDynamicLureDelayValue = config.lureDelay

  if not storage.targetBotLureMax then
    storage.targetBotLureMax = 0
  end
  if config.lureMax then
    storage.targetBotLureMax = config.lureMax
  end

  -- luring
  if TargetBot.canLure() and (config.lure or config.lureCavebot or config.dynamicLure) and not (config.chase and creature:getHealthPercent() < 5) and not isTrapped then
    local monsters = 0
    if storage.TargetBotLure then
      return TargetBot.allowCaveBot(150)
    else
      if targets < config.lureCount then
        if config.lureCavebot then
          return TargetBot.allowCaveBot(150)
        else
          local path = findPath(pos, cpos, 5, {ignoreNonPathable=true, precision=2})
          if path then
            return TargetBot.walkTo(cpos, 10, {marginMin=5, marginMax=6, ignoreNonPathable=true})
          end
        end
      end
    end
  end

  local currentDistance = findPath(pos, cpos, 10, {ignoreCreatures=true, ignoreNonPathable=true, ignoreCost=true})
  if config.chase and (creature:getHealthPercent() < 30 or not config.keepDistance) then
    if #currentDistance > 1 then
      return TargetBot.walkTo(cpos, 10, {ignoreNonPathable=true, precision=1})
    end
  elseif config.keepDistance then
    if #currentDistance ~= config.keepDistanceRange and #currentDistance ~= config.keepDistanceRange + 1 then
      return TargetBot.walkTo(cpos, 10, {ignoreNonPathable=true, marginMin=config.keepDistanceRange, marginMax=config.keepDistanceRange + 1})
    end
  end

  if config.avoidAttacks then
    local diffx = cpos.x - pos.x
    local diffy = cpos.y - pos.y
    local candidates = {}
    if math.abs(diffx) == 1 and diffy == 0 then
      candidates = {{x=pos.x, y=pos.y-1, z=pos.z}, {x=pos.x, y=pos.y+1, z=pos.z}}
    elseif diffx == 0 and math.abs(diffy) == 1 then
      candidates = {{x=pos.x-1, y=pos.y, z=pos.z}, {x=pos.x+1, y=pos.y, z=pos.z}}
    end
    for _, candidate in ipairs(candidates) do
      local tile = g_map.getTile(candidate)
      if tile and tile:isWalkable() then
        return TargetBot.walkTo(candidate, 2, {ignoreNonPathable=true})
      end
    end
  elseif config.faceMonster then
    local diffx = cpos.x - pos.x
    local diffy = cpos.y - pos.y
    local candidates = {}
    if diffx == 1 and diffy == 1 then
      candidates = {{x=pos.x+1, y=pos.y, z=pos.z}, {x=pos.x, y=pos.y-1, z=pos.z}}
    elseif diffx == -1 and diffy == 1 then
      candidates = {{x=pos.x-1, y=pos.y, z=pos.z}, {x=pos.x, y=pos.y-1, z=pos.z}}
    elseif diffx == -1 and diffy == -1 then
      candidates = {{x=pos.x, y=pos.y-1, z=pos.z}, {x=pos.x-1, y=pos.y, z=pos.z}} 
    elseif diffx == 1 and diffy == -1 then
      candidates = {{x=pos.x, y=pos.y-1, z=pos.z}, {x=pos.x+1, y=pos.y, z=pos.z}}       
    else
      local dir = player:getDirection()
      if diffx == 1 and dir ~= 1 then turn(1)
      elseif diffx == -1 and dir ~= 3 then turn(3)
      elseif diffy == 1 and dir ~= 2 then turn(2)
      elseif diffy == -1 and dir ~= 0 then turn(0)
      end
    end
    for _, candidate in ipairs(candidates) do
      local tile = g_map.getTile(candidate)
      if tile and tile:isWalkable() then
        return TargetBot.walkTo(candidate, 2, {ignoreNonPathable=true})
      end
    end
  end
end

onPlayerPositionChange(function(newPos, oldPos)
  if CaveBot.isOff() then return end
  if TargetBot.isOff() then return end
  if not storage.targetBotLureMax then return end
  if storage.targetBotTargets < storage.targetBotLureMax/2 or not target() then return end

  CaveBot.delay(storage.targetBotDynamicLureDelayValue)
end)