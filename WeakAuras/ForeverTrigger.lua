-- Forever prototype modifications, 2026-09-20. See FOREVER.md.
if not WeakAuras.IsLibsOK() then return end
local Private = select(2, ...)
local L = WeakAuras.L
local F = Private.Forever
local definitions, loaded = {}, {}
local frame = CreateFrame("Frame")
Private.frames["Forever sources"] = frame

local commonEvents = {
  PLAYER_ENTERING_WORLD = true, PLAYER_REGEN_ENABLED = true,
  PLAYER_REGEN_DISABLED = true, ADDON_RESTRICTION_STATE_CHANGED = true
}

local function different(old, state)
  if not old then return true end
  for key, value in pairs(state) do
    if key ~= "changed" and old[key] ~= value then return true end
  end
  for key in pairs(old) do
    if key ~= "changed" and key ~= "id" and key ~= "trigger" and key ~= "triggernum"
      and state[key] == nil then return true end
  end
  return false
end

local function update(id, preview, event, ...)
  local changed = false
  F.observations[id] = F.observations[id] or {}
  for index, entry in pairs(definitions[id] or {}) do
    local trigger, context = entry.trigger, entry.context
    local definition = F.Source(trigger)
    local relevant = not event or commonEvents[event]
      or definition and (definition.events[event] or event == "FOREVER_POLL" and definition.poll
        or definition.kind == "timed" and (event == "FOREVER_TIMER" or event == "FOREVER_TIMER_STOP"))
    if relevant then
      F.Event(trigger, context, event, ...)
      context.invalidate = event == "ADDON_RESTRICTION_STATE_CHANGED" or event == "PLAYER_REGEN_DISABLED"
      if not context.name or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"
        or event == "GET_ITEM_INFO_RECEIVED" then
        context.name, context.icon = F.NameAndIcon(trigger)
      end
      local state = F.MakeState(trigger, preview, context)
      local old = F.observations[id][index]
      if not event or different(old, state) or definition and definition.kind == "native" then
        F.observations[id][index] = state
        WeakAuras.GetTriggerStateForTrigger(id, index)[""] = state
        changed = true
      end
    end
  end
  if changed then Private.UpdatedTriggerState(id) end
end

local function refresh(_, event, ...)
  if not WeakAuras.IsLoginFinished() or WeakAuras.IsPaused() then return end
  for id in pairs(loaded) do update(id, false, event, ...) end
end

local elapsed = 0
local function poll(_, delta)
  elapsed = elapsed + delta
  if elapsed < 0.2 then return end
  elapsed = 0
  refresh(nil, "FOREVER_POLL")
end
local function updatePolling()
  for id in pairs(loaded) do
    for _, entry in pairs(definitions[id] or {}) do
      local definition = F.Source(entry.trigger)
      if definition and definition.poll then frame:SetScript("OnUpdate", poll) return end
    end
  end
  frame:SetScript("OnUpdate", nil)
end

local system = {}
function system.Add(data)
  local triggers = {}
  for index, entry in ipairs(data.triggers) do
    if entry.trigger.type == "forever" then
      triggers[index] = {trigger = entry.trigger, context = {
        spellIDs = F.ParseSpellIDs(entry.trigger.spellIDs or entry.trigger.spellID)
      }}
    end
  end
  definitions[data.id] = next(triggers) and triggers or nil
  F.observations[data.id] = nil
  local nativeCount = 0
  local message
  for _, entry in pairs(triggers) do
    local required = F.NativeRegion(entry.trigger)
    if required then
      nativeCount = nativeCount + 1
      if data.regionType ~= required then
        message = required == "aurabar" and L["Native mana requires a Progress Bar display."]
          or L["Native cooldown and buff sources require an Icon in this prototype."]
      end
    end
  end
  if nativeCount > 1 then
    message = L["Use one native display source per aura in this prototype."]
  end
  Private.AuraWarnings.UpdateWarning(data.uid, "forever-source", "warning", message)
  updatePolling()
end
function system.Delete(id)
  definitions[id], loaded[id], F.observations[id] = nil, nil, nil
  updatePolling()
end
function system.Rename(oldID, newID)
  definitions[newID], definitions[oldID] = definitions[oldID], nil
  loaded[newID], loaded[oldID] = loaded[oldID], nil
  F.observations[newID], F.observations[oldID] = F.observations[oldID], nil
end
function system.LoadDisplays(toLoad, event, ...)
  for id in pairs(toLoad) do
    if definitions[id] then
      loaded[id] = true
      for _, entry in pairs(definitions[id]) do F.Event(entry.trigger, entry.context, event, ...) end
    end
  end
  updatePolling()
end
function system.UnloadDisplays(toUnload)
  for id in pairs(toUnload) do
    loaded[id], F.observations[id] = nil, nil
    for _, entry in pairs(definitions[id] or {}) do
      entry.context.duration, entry.context.expirationTime = nil, nil
    end
  end
  updatePolling()
end
function system.UnloadAll()
  system.UnloadDisplays(loaded)
end
function system.FinishLoadUnload()
  for id in pairs(loaded) do update(id, false) end
end
function system.GetName() return L["Forever"] .. WeakAuras.newFeatureString end
function system.GetNameAndIcon(data, index) return F.NameAndIcon(data.triggers[index].trigger) end
function system.GetOverlayInfo() return {} end
function system.CanHaveTooltip() return false end
function system.GetAdditionalProperties(data, index)
  local definition = F.Source(data.triggers[index].trigger)
  if definition and definition.kind == "number" then
    return {count = {display = definition.label}, percent = {display = L["Percent"]}}
  end
  return {}
end
function system.GetTriggerDescription(data, index, names)
  table.insert(names, {L["Trigger:"], F.sourceNames[data.triggers[index].trigger.source or "ammo"]})
end
function system.GetTriggerConditions(data, index)
  local trigger = data.triggers[index].trigger
  local definition = F.Source(trigger)
  if not definition then return {} end
  local result = {}
  if definition.kind ~= "native" then
    result.available = {display = L["Data available"], type = "bool", test = function(_, needle)
      local state = F.observations[data.id] and F.observations[data.id][index]
      return state ~= nil and state.available == (needle == 1)
    end}
  end
  if definition.kind == "number" then
    result.count = {display = definition.label, type = "number", total = "total"}
    result.percent = {display = L["Percent"], type = "number"}
  elseif definition.kind == "bool" then
    result.result = {display = L["Source is true"], type = "bool", test = function(_, needle)
      local state = F.observations[data.id] and F.observations[data.id][index]
      return state ~= nil and state.available and state.result == (needle == 1)
    end}
  elseif definition.kind == "timed" then
    result.expirationTime = {display = L["Remaining Duration"], type = "timer", total = "duration"}
  end
  if trigger.source == "cooldown" or trigger.source == "cooldown_state" then
    result.cooldownActive = {display = L["Cooldown active (includes GCD)"], type = "bool"}
    result.cooldownEnabled = {display = L["Cooldown enabled (not on hold)"], type = "bool"}
    result.recharging = {display = L["Charges recharging"], type = "bool"}
  elseif trigger.source == "spell_usable" then
    result.insufficientPower = {display = L["Insufficient resource"], type = "bool"}
  end
  return result
end
function F.ActiveCondition(data, index)
  return function(_, needle)
    local state = F.observations[data.id] and F.observations[data.id][index]
    return state ~= nil and state.available and state.show == (needle == 1)
  end
end
function system.GetProgressSources(data, index, values)
  local definition = F.Source(data.triggers[index].trigger)
  if definition and definition.kind == "number" then
    table.insert(values, {trigger = index, property = "count", type = "number",
                         display = definition.label, total = "total"})
  elseif definition and definition.kind == "timed" then
    table.insert(values, {trigger = index, property = "expirationTime", type = "timer",
                         display = L["Remaining Duration"], total = "duration"})
  end
end
function system.CreateFallbackState(data, index, state)
  -- An inactive source supplying dynamic information must not fabricate sample
  -- values during live Any-trigger combinations. Samples belong to editor only.
  local sample = F.MakeState(data.triggers[index].trigger, WeakAuras.IsOptionsOpen())
  for key, value in pairs(sample) do state[key] = value end
  state.show = true
end
function system.CreateFakeStates(id, index)
  local states = WeakAuras.GetTriggerStateForTrigger(id, index)
  states[""] = F.MakeState(definitions[id][index].trigger, true)
end
WeakAuras.RegisterTriggerSystem({"forever"}, system)

-- The native display is a rendering source, independent of public trigger
-- combinations. Exactly one native source per icon is supported in this spike.
local function nativeTrigger(data)
  for _, entry in ipairs(data.triggers) do
    local t = entry.trigger
    if t.type == "forever" and (t.source == "cooldown" or t.source == "buff") then return t end
  end
end

function F.BindIcon(region, data)
  local trigger = nativeTrigger(data)
  if not data.cooldown then region.PreShow = nil end
  if region.foreverContainer then region.foreverContainer:Hide() end
  region.icon:SetAlpha(1)
  if not trigger then return end
  local id = F.SpellID(trigger)
  if not id then return end
  if trigger.source == "cooldown" then
    -- Replace only the numeric progress writer; retain WA icon styling,
    -- conditions, anchoring, subregions and editor interaction.
    local function render()
      if data.cooldown then
        local duration
        if trigger.nativeTimer == "charges" then
          duration = C_Spell.GetSpellChargeDuration(id)
        else
          duration = C_Spell.GetSpellCooldownDuration(id, true)
        end
        if duration then
          region.cooldown:Show()
          region.cooldown:SetCooldownFromDurationObject(duration, true)
        else
          region.cooldown:Clear()
        end
      end
    end
    region.UpdateValue, region.UpdateTime = render, render
    region.PreShow = render
    render()
  else
    local container = region.foreverContainer
    if not container then
      container = CreateFrame("AuraContainer", nil, region, "CustomAuraContainerTemplate")
      container:SetAllPoints(region)
      container:SetUnit(trigger.unit == "target" and "target" or "player")
      container:AddAuraSlot("buff", trigger.auraFilter == "HARMFUL" and "HARMFUL" or "HELPFUL", {
        candidateFilters = {includeSpellIDs = {[id] = true}},
        initializeFrame = function(button)
          button:SetAllPoints(container)
          local texture = button:CreateTexture(nil, "ARTWORK")
          texture:SetAllPoints()
          local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
          cooldown:SetAllPoints()
          button:SetIcon(texture)
          button:SetDurationCooldown(cooldown)
          container.texture, container.cooldown = texture, cooldown
        end
      })
      container:GetAuraSlotFrame("buff"):SetAllPoints(container)
      region.foreverContainer = container
    end
    container:SetUnit(trigger.unit == "target" and "target" or "player")
    container:SetAuraSlotFilterString("buff", trigger.auraFilter == "HARMFUL" and "HARMFUL" or "HELPFUL")
    container:SetAuraSlotCandidateFilters("buff", {includeSpellIDs = {[id] = true}})
    container.texture:SetTexCoord(0.5 * data.zoom, 1 - 0.5 * data.zoom, 0.5 * data.zoom, 1 - 0.5 * data.zoom)
    container.texture:SetVertexColor(unpack(data.color))
    container.texture:SetDesaturated(data.desaturate)
    container.cooldown:SetDrawSwipe(data.cooldown and data.cooldownSwipe)
    container.cooldown:SetDrawEdge(data.cooldownEdge)
    container.cooldown:SetHideCountdownNumbers(data.cooldownTextDisabled)
    region.icon:SetAlpha(0)
    region.cooldown:Hide()
    local function render()
      container:SetEditModePreviewEnabled(WeakAuras.IsOptionsOpen())
    end
    region.UpdateValue, region.UpdateTime, region.PreShow = render, render, render
    container:Show()
    render()
  end
end

local events = {}
for event in pairs(commonEvents) do events[event] = true end
for _, definition in pairs(F.sources) do
  for event in pairs(definition.events) do events[event] = true end
end
for event in pairs(events) do frame:RegisterEvent(event) end
frame:SetScript("OnEvent", refresh)

Private.callbacks:RegisterCallback("Add", function(_, _, id)
  if loaded[id] and not WeakAuras.IsPaused() then update(id, false) end
end)

local function testAura(id, regionType, source, x, y)
  if WeakAuras.GetData(id) then return end
  local data = {
    id = id, uid = WeakAuras.GenerateUniqueID(), internalVersion = WeakAuras.InternalVersion(),
    regionType = regionType, xOffset = x, yOffset = y, width = 48, height = 48,
    triggers = {{trigger = {type = "forever", source = source, spellID = 2973, maximum = 200}, untrigger = {}}},
    load = {}, subRegions = {}, conditions = {}
  }
  if source == "buff" then data.triggers[1].trigger.spellID = 13163 end
  if source == "ammo" then
    data.width, data.height = 240, 24
    data.barColor = {0.2, 0.7, 1, 1}
    data.subRegions = {{type = "subtext", text_text = "%1.count", anchor_point = "CENTER"}}
    data.conditions = {{check = {trigger = 1, variable = "count", op = "<=", value = 100},
      changes = {{property = "barColor", value = {1, 0.15, 0.1, 1}}}}}
  end
  WeakAuras.Add(data)
end

local function moreExamples()
  local function add(id, region, triggers, y, text)
    if WeakAuras.GetData(id) then return end
    local data = {
      id = id, uid = WeakAuras.GenerateUniqueID(), internalVersion = WeakAuras.InternalVersion(),
      regionType = region, xOffset = 0, yOffset = y,
      width = region == "icon" and 48 or 240, height = region == "icon" and 48 or 24,
      triggers = triggers, load = {}, conditions = {},
      subRegions = {{type = "subtext", text_text = text, anchor_point = "CENTER"}}
    }
    for _, entry in ipairs(triggers) do entry.untrigger = {} end
    data.triggers.disjunctive = "all"
    data.triggers.activeTriggerMode = 1
    WeakAuras.Add(data)
  end
  add(L["Forever example - Low ammo in combat"], "icon", {
    {trigger = {type = "forever", source = "ammo", compare = "<=", threshold = 100}},
    {trigger = {type = "forever", source = "player_state", playerState = "combat"}}
  }, -270, "%1.count")
  add(L["Forever example - Ranged swing"], "aurabar", {
    {trigger = {type = "forever", source = "swing", swingType = 2}}
  }, -310, "%p")
  add(L["Forever example - Manual timer"], "aurabar", {
    {trigger = {type = "forever", source = "timer", timerKey = "demo", timerDuration = 10}}
  }, -345, "%p")
  add(L["Forever example - Missing hunter aspect"], "icon", {
    {trigger = {type = "forever", source = "aura_presence", unit = "player",
                spellIDs = "13163, 13165", auraMatch = "any", showWhen = "false"}}
  }, -390, L["Aspect"])
end

-- Registered on the existing slash dispatcher table; no new global table.
SLASH_WEAKAURASFOREVER1 = "/waf"
SLASH_WEAKAURASFOREVER2 = "/weakaurasforever"
SLASH_WEAKAURASFOREVER3 = "/waforever"
SlashCmdList.WEAKAURASFOREVER = function(input)
  local command, key = input:match("^(%S+)%s*(.-)$")
  if not command then
    WeakAuras.OpenOptions()
  elseif command == "timer" or command == "stop" then
    refresh(nil, command == "timer" and "FOREVER_TIMER" or "FOREVER_TIMER_STOP", key ~= "" and key or "timer")
  elseif command == "hunter" then
    F.HunterCommand(key)
  elseif input == "test" or input == "examples" then
    if InCombatLockdown() or not WeakAuras.IsLoginFinished() then
      WeakAuras.prettyPrint(L["Wait until login completes and leave combat before creating test auras."])
      return
    end
    if input == "examples" then moreExamples() end
    testAura(L["Forever test - Raptor Strike"], "icon", "cooldown", -64, -160)
    testAura(L["Forever test - Aspect of the Monkey"], "icon", "buff", 0, -160)
    testAura(L["Forever test - Ammunition"], "aurabar", "ammo", 0, -210)
    Private.ScanForLoads()
    WeakAuras.prettyPrint(L["Test auras created. Open /waf to edit them. Existing test auras were kept."])
    WeakAuras.OpenOptions()
  elseif command == "help" then
    WeakAuras.prettyPrint(L["/waf opens the editor. /waf hunter creates your Hunter group; /waf hunter validate checks it. /waf examples adds examples. /waf timer KEY starts manual timers; /waf stop KEY stops them."])
    Private.PrintHelp()
  else
    SlashCmdList.WEAKAURAS(input)
  end
end
