-- Forever prototype modifications, 2026-09-20. See FOREVER.md.
if not WeakAuras.IsLibsOK() then return end
local Private = select(2, ...)
local L = WeakAuras.L
local F = {observations = {}}
Private.Forever = F

function F.Readable(value)
  return not issecretvalue(value) and canaccessvalue(value)
end

-- Unknown inputs stay nil, including when the user selects an inverse trigger.
-- Opaque fields never enter WA's conditions, text formatters or state tables.
function F.Read(callback, kind, ...)
  if type(callback) ~= "function" then return nil end
  local value = callback(...)
  if F.Readable(value) and type(value) == kind then return value end
end

function F.Field(object, field, kind)
  if not F.Readable(object) or type(object) ~= "table"
    or canaccesstable and not canaccesstable(object) then return nil end
  local value = object[field]
  if F.Readable(value) and type(value) == kind then return value end
end

function F.PositiveID(value)
  local id = tonumber(value)
  if id and id > 0 and id < math.huge and id == math.floor(id) then return id end
end
function F.SpellID(trigger) return F.PositiveID(trigger.spellID) end

F.categories = {
  spell = L["Spell"], aura = L["Aura"], item = L["Item"],
  unit = L["Unit"], player = L["Player & World"], timer = L["Timer"]
}
F.categoryOrder = {"spell", "aura", "item", "unit", "player", "timer"}
F.sources = {
  cooldown = {name = L["Spell cooldown (native)"], category = "spell", kind = "native", spell = true,
    events = "SPELL_UPDATE_COOLDOWN SPELL_UPDATE_CHARGES SPELLS_CHANGED"},
  cooldown_state = {name = L["Cooldown state"], category = "spell", kind = "bool", spell = true,
    events = "SPELL_UPDATE_COOLDOWN SPELL_UPDATE_CHARGES SPELLS_CHANGED"},
  spell_known = {name = L["Spell learned"], category = "spell", kind = "bool", spell = true,
    events = "SPELLS_CHANGED"},
  spell_usable = {name = L["Spell usable"], category = "spell", kind = "bool", spell = true,
    events = "SPELL_UPDATE_USABLE SPELL_UPDATE_COOLDOWN UNIT_POWER_UPDATE SPELLS_CHANGED"},
  spell_range = {name = L["Spell in range"], category = "spell", kind = "bool", spell = true, poll = true,
    events = "PLAYER_TARGET_CHANGED PLAYER_FOCUS_CHANGED SPELLS_CHANGED"},
  proc = {name = L["Blizzard proc highlight"], category = "spell", kind = "bool", spell = true,
    events = "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW SPELL_ACTIVATION_OVERLAY_GLOW_HIDE SPELLS_CHANGED"},
  buff = {name = L["Buff / debuff display (native)"], category = "aura", kind = "native", spell = true,
    events = "PLAYER_TARGET_CHANGED"},
  aura_presence = {name = L["Buff / debuff present or missing"], category = "aura", kind = "bool", poll = true,
    events = "UNIT_AURA PLAYER_TARGET_CHANGED SPELLS_CHANGED"},
  ammo = {name = L["Equipped ammunition"], category = "item", kind = "number", label = L["Ammo count"],
    events = "BAG_UPDATE_DELAYED PLAYER_EQUIPMENT_CHANGED"},
  item_count = {name = L["Item count"], category = "item", kind = "number", item = true, label = L["Item count"],
    events = "BAG_UPDATE_DELAYED PLAYER_EQUIPMENT_CHANGED GET_ITEM_INFO_RECEIVED"},
  equipped = {name = L["Item equipped"], category = "item", kind = "bool", item = true,
    events = "PLAYER_EQUIPMENT_CHANGED GET_ITEM_INFO_RECEIVED"},
  unit_state = {name = L["Unit state"], category = "unit", kind = "bool", poll = true,
    events = "PLAYER_TARGET_CHANGED PLAYER_FOCUS_CHANGED UNIT_PET UNIT_FLAGS UNIT_FACTION UNIT_CONNECTION"},
  player_state = {name = L["Player state"], category = "player", kind = "bool", poll = true,
    events = "PLAYER_MOUNT_DISPLAY_CHANGED PLAYER_UPDATE_RESTING PLAYER_ALIVE PLAYER_DEAD PLAYER_UNGHOST GROUP_ROSTER_UPDATE UNIT_PET"},
  class = {name = L["Player class"], category = "player", kind = "bool", events = ""},
  level = {name = L["Player level"], category = "player", kind = "number", label = L["Level"],
    events = "PLAYER_LEVEL_UP UNIT_LEVEL"},
  experience = {name = L["Experience"], category = "player", kind = "number", label = L["Experience"],
    events = "PLAYER_XP_UPDATE PLAYER_LEVEL_UP UPDATE_EXHAUSTION"},
  money = {name = L["Money (gold)"], category = "player", kind = "number", label = L["Gold"], events = "PLAYER_MONEY"},
  form = {name = L["Form / stance number"], category = "player", kind = "number", label = L["Form / stance number"],
    events = "UPDATE_SHAPESHIFT_FORM UPDATE_SHAPESHIFT_FORMS"},
  group_size = {name = L["Group size"], category = "player", kind = "number", label = L["Group members"],
    events = "GROUP_ROSTER_UPDATE"},
  zone = {name = L["Zone"], category = "player", kind = "bool",
    events = "ZONE_CHANGED ZONE_CHANGED_INDOORS ZONE_CHANGED_NEW_AREA"},
  instance = {name = L["Instance type"], category = "player", kind = "bool", events = "ZONE_CHANGED_NEW_AREA"},
  swing = {name = L["Swing timer"], category = "timer", kind = "timed", poll = true, events = "PLAYER_SWING"},
  timer = {name = L["Event / manual timer"], category = "timer", kind = "timed", poll = true,
    events = "UNIT_SPELLCAST_SUCCEEDED"}
}
F.sourceNames = {}
for source, definition in pairs(F.sources) do
  F.sourceNames[source] = definition.name
  local events = {}
  for event in definition.events:gmatch("%S+") do events[event] = true end
  definition.events = events
end
F.defaults = {spell = "cooldown", aura = "buff", item = "item_count", unit = "unit_state",
              player = "player_state", timer = "swing"}
F.playerStates = {combat = L["In combat"], mounted = L["Mounted"], dead = L["Dead or ghost"],
  resting = L["Resting"], swimming = L["Swimming"], pet = L["Has a pet"],
  group = L["In a group"], raid = L["In a raid"]}
F.unitStates = {exists = L["Exists"], dead = L["Dead or ghost"], attackable = L["Can attack"],
  friendly = L["Friendly"], connected = L["Connected"]}
F.units = {player = L["Player"], target = L["Target"], focus = L["Focus"], pet = L["Pet"]}
F.cooldownStates = {active = L["Cooldown active (includes GCD)"], inactive = L["Cooldown inactive"],
  held = L["Cooldown on hold"], recharging = L["Charges recharging"]}
F.instanceTypes = {none = L["Open world"], party = L["Dungeon"], raid = L["Raid"],
  pvp = L["Battleground"], arena = L["Arena"], scenario = L["Scenario"]}

function F.Source(trigger) return F.sources[trigger.source or "ammo"] end
function F.IsNative(trigger)
  local definition = F.Source(trigger)
  return definition and definition.kind == "native"
end

function F.ClassToken()
  if not UnitClass then return nil end
  local _, token = UnitClass("player")
  if F.Readable(token) and type(token) == "string" then return token end
end

function F.ReadAmmo()
  local itemID = GetInventoryItemID("player", 0)
  if not F.Readable(itemID) then return nil end
  if itemID == nil then return 0 end
  if type(itemID) ~= "number" then return nil end
  return F.Read(C_Item.GetItemCount, "number", itemID, false, false, false), itemID
end

function F.NameAndIcon(trigger)
  local source = trigger.source or "ammo"
  local definition = F.Source(trigger)
  if not definition then return L["Forever"], 134400 end
  local id = F.SpellID(trigger)
  if source == "aura_presence" then
    local ids = F.ParseSpellIDs(trigger.spellIDs or trigger.spellID)
    id = ids and ids[1]
  end
  if id and (definition.spell or source == "aura_presence" or source == "timer" and trigger.timerStart == "cast") then
    return F.Read(C_Spell.GetSpellName, "string", id) or definition.name,
           F.Read(C_Spell.GetSpellTexture, "number", id) or 134400
  elseif definition.item then
    local item = F.PositiveID(trigger.itemID)
    return definition.name, item and F.Read(C_Item.GetItemIconByID, "number", item) or 134400
  elseif source == "ammo" then
    local _, item = F.ReadAmmo()
    return definition.name, item and F.Read(C_Item.GetItemIconByID, "number", item) or 132382
  end
  return definition.name, 134400
end

function F.ParseSpellIDs(text)
  local ids, seen = {}, {}
  for word in tostring(text or ""):gmatch("[^,%s]+") do
    local id = F.PositiveID(word)
    if not id then return nil end
    if not seen[id] then ids[#ids + 1], seen[id] = id, true end
    if #ids > 32 then return nil end
  end
  return #ids > 0 and ids or nil
end

-- An empty RequiresNonSecretAura lookup proves absence only when the spell
-- policy is public and the queried unit is visible. Never inspect native frames.
function F.AuraPresent(unit, id)
  if unit ~= "player" and unit ~= "target" then return nil end
  if unit ~= "player" and (F.Read(UnitExists, "boolean", unit) ~= true
    or F.Read(UnitIsVisible, "boolean", unit) ~= true) then return nil end
  local policy = C_Secrets and C_Secrets.ShouldSpellAuraBeSecret
  if F.Read(policy, "boolean", id) ~= false then return nil end
  local query = C_UnitAuras and (unit == "player" and C_UnitAuras.GetPlayerAuraBySpellID or C_UnitAuras.GetUnitAuraBySpellID)
  if type(query) ~= "function" then return nil end
  local aura
  if unit == "player" then aura = query(id) else aura = query(unit, id) end
  if not F.Readable(aura) or F.Read(policy, "boolean", id) ~= false then return nil end
  if aura == nil then return false end
  if F.Field(aura, "spellId", "number") == id then return true end
end

function F.AuraSet(trigger, context)
  if context.invalidate then return nil end
  local ids = context.spellIDs or F.ParseSpellIDs(trigger.spellIDs or trigger.spellID)
  if not ids then return nil end
  local mode, unknown = trigger.auraMatch or "any", false
  for _, id in ipairs(ids) do
    local present = F.AuraPresent(trigger.unit or "player", id)
    if present == nil then unknown = true
    elseif mode == "all" and not present then return false
    elseif mode == "any" and present then return true end
  end
  if unknown then return nil end
  return mode == "all"
end

local function cooldownFlags(trigger, state)
  local id = F.SpellID(trigger)
  if not id then return end
  local info = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(id)
  state.cooldownActive = F.Field(info, "isActive", "boolean")
  state.cooldownEnabled = F.Field(info, "isEnabled", "boolean")
  local charges = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(id)
  state.recharging = F.Field(charges, "isActive", "boolean")
  -- currentCharges and numeric times may be secret. Duration objects are bound
  -- separately; only documented public flags are copied into logical state.
end

local function playerState(key)
  if key == "combat" then return F.Read(InCombatLockdown, "boolean")
  elseif key == "mounted" then return F.Read(IsMounted, "boolean")
  elseif key == "dead" then return F.Read(UnitIsDeadOrGhost, "boolean", "player")
  elseif key == "resting" then return F.Read(IsResting, "boolean")
  elseif key == "swimming" then return F.Read(IsSwimming, "boolean")
  elseif key == "pet" then return F.Read(UnitExists, "boolean", "pet")
  elseif key == "group" then return F.Read(IsInGroup, "boolean")
  elseif key == "raid" then return F.Read(IsInRaid, "boolean") end
end

local function unitState(trigger)
  local unit, key = trigger.unit or "target", trigger.unitState or "exists"
  if not F.units[unit] then return nil end
  local exists = F.Read(UnitExists, "boolean", unit)
  if key == "exists" then return exists end
  if exists ~= true then return nil end
  if key == "dead" then return F.Read(UnitIsDeadOrGhost, "boolean", unit)
  elseif key == "connected" then return F.Read(UnitIsConnected, "boolean", unit)
  elseif key == "friendly" then return F.Read(UnitIsFriend, "boolean", "player", unit)
  elseif key == "attackable" then return F.Read(UnitCanAttack, "boolean", "player", unit) end
end

function F.Compare(value, operator, threshold)
  if value == nil then return nil end
  if operator == "always" then return true end
  if threshold == nil then return nil end
  if operator == "<" then return value < threshold
  elseif operator == "<=" then return value <= threshold
  elseif operator == ">" then return value > threshold
  elseif operator == ">=" then return value >= threshold
  elseif operator == "==" then return value == threshold
  elseif operator == "~=" then return value ~= threshold end
end

-- Context belongs to a loaded trigger, never SavedVariables. Timers start from
-- public events only; reloading does not fabricate an elapsed game cooldown.
function F.Event(trigger, context, event, arg1, arg2, arg3)
  local source = trigger.source
  if event == "PLAYER_ENTERING_WORLD" then context.expirationTime = nil end
  if source == "swing" and event == "PLAYER_SWING" then
    if F.Readable(arg1) and F.Readable(arg2) and type(arg1) == "number"
      and arg1 > 0 and arg2 == (trigger.swingType or 2) then
      context.duration, context.expirationTime = arg1, GetTime() + arg1
    end
  elseif source == "timer" then
    local start = trigger.timerStart or "manual"
    local matched = start == "combat" and event == "PLAYER_REGEN_DISABLED"
      or start == "manual" and event == "FOREVER_TIMER" and arg1 == (trigger.timerKey or "timer")
    if start == "cast" and event == "UNIT_SPELLCAST_SUCCEEDED"
      and F.Readable(arg1) and F.Readable(arg3) then
      local id = F.SpellID(trigger)
      matched = id ~= nil and arg1 == "player" and arg3 == id
    end
    if start == "manual" and event == "FOREVER_TIMER_STOP" and arg1 == (trigger.timerKey or "timer") then
      context.expirationTime = nil
    elseif matched then
      context.duration = math.min(3600, math.max(0.1, tonumber(trigger.timerDuration) or 10))
      context.expirationTime = GetTime() + context.duration
    end
  end
end

function F.MakeState(trigger, preview, context)
  context = context or {}
  local definition = F.Source(trigger)
  local name, icon = context.name, context.icon
  if not name then name, icon = F.NameAndIcon(trigger) end
  local state = {changed = true, show = false, name = name, icon = icon,
                 progressType = "static", value = 0, total = 1, available = false}
  if not definition then return state end
  local source, value = trigger.source or "ammo"
  if definition.kind == "native" then
    state.available = F.SpellID(trigger) ~= nil
    state.show = state.available
    if source == "cooldown" then cooldownFlags(trigger, state) end
  elseif definition.kind == "timed" then
    local duration = preview and 3 or context.duration
    local expiration = preview and GetTime() + 3 or context.expirationTime
    state.available = true
    state.matches = expiration ~= nil and expiration > GetTime()
    state.show = state.matches
    if state.matches then
      state.progressType, state.duration, state.expirationTime = "timed", duration, expiration
      state.autoHide = true
    end
  elseif definition.kind == "number" then
    local total = math.max(1, tonumber(trigger.maximum) or 200)
    if source == "ammo" then value = F.ReadAmmo()
    elseif source == "item_count" then
      local id = F.PositiveID(trigger.itemID)
      if id then value = F.Read(C_Item.GetItemCount, "number", id, false, false, false) end
    elseif source == "level" then value = F.Read(UnitLevel, "number", "player")
    elseif source == "form" then value = F.Read(GetShapeshiftForm, "number")
    elseif source == "group_size" then
      value = F.Read(GetNumGroupMembers, "number")
      if value ~= nil then value = math.max(1, value) end
    elseif source == "money" then
      value = F.Read(GetMoney, "number")
      if value ~= nil then value = value / 10000 end
    elseif source == "experience" then
      value = F.Read(UnitXP, "number", "player")
      total = F.Read(UnitXPMax, "number", "player")
      if not total or total <= 0 then value, total = nil, 1 end
    end
    if preview then value = source == "ammo" and 68 or 25 end
    state.available = value ~= nil
    state.count, state.stacks, state.value, state.total = value, value, value or 0, total
    state.percent = value and (100 * value / total) or nil
    local operator = trigger.compare or (source == "ammo" and trigger.lowOnly and "<=") or "always"
    state.matches = F.Compare(trigger.usePercent and state.percent or value, operator, tonumber(trigger.threshold) or 100)
    state.show = state.available and state.matches == true
  else
    -- Match WA's ordinary status-trigger representation: an untimed icon must
    -- not acquire a synthetic one-second cooldown from static value/total.
    state.progressType, state.duration, state.expirationTime = "timed", 0, math.huge
    state.value, state.total = nil, nil
    local id = F.SpellID(trigger)
    if source == "spell_known" and id then
      value = F.Read(C_SpellBook and C_SpellBook.IsSpellKnown, "boolean", id)
    elseif source == "spell_usable" and id then
      if C_Spell.IsSpellUsable then
        local usable, insufficient = C_Spell.IsSpellUsable(id)
        if F.Readable(usable) and type(usable) == "boolean" then value = usable end
        if F.Readable(insufficient) and type(insufficient) == "boolean" then state.insufficientPower = insufficient end
      end
    elseif source == "spell_range" and id then
      local unit = trigger.unit or "target"
      if F.units[unit] then value = F.Read(C_Spell.IsSpellInRange, "boolean", id, unit) end
    elseif source == "proc" and id then
      value = F.Read(C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed, "boolean", id)
    elseif source == "cooldown_state" then
      cooldownFlags(trigger, state)
      local mode = trigger.cooldownState or "active"
      if mode == "active" then value = state.cooldownActive
      elseif mode == "inactive" and state.cooldownEnabled ~= nil and state.cooldownActive ~= nil then
        value = state.cooldownEnabled and not state.cooldownActive
      elseif mode == "held" and state.cooldownEnabled ~= nil then value = not state.cooldownEnabled
      elseif mode == "recharging" then value = state.recharging end
    elseif source == "equipped" then
      local item = F.PositiveID(trigger.itemID)
      if item then value = F.Read(C_Item.IsEquippedItem, "boolean", item) end
    elseif source == "class" then
      local class = F.ClassToken()
      if class then value = class == (trigger.classToken or class) end
    elseif source == "player_state" then value = playerState(trigger.playerState or "combat")
    elseif source == "unit_state" then value = unitState(trigger)
    elseif source == "aura_presence" then value = F.AuraSet(trigger, context)
    elseif source == "zone" then
      local zone = F.Read(GetRealZoneText, "string")
      local match = trigger.zoneName
      if zone and type(match) == "string" and match ~= "" then value = zone:lower() == match:lower() end
    elseif source == "instance" then
      local _, instanceType = GetInstanceInfo()
      if F.Readable(instanceType) and type(instanceType) == "string" then
        value = instanceType == (trigger.instanceType or "party")
      end
    end
    if preview then value = trigger.showWhen ~= "false" end
    state.available = value ~= nil
    state.result = value
    if value ~= nil then
      local when = trigger.showWhen or "true"
      state.matches = when == "always" or value == (when ~= "false")
    end
    state.show = state.available and state.matches == true
  end
  if preview then state.show = true end
  return state
end
