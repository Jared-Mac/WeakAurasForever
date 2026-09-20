-- Forever prototype modifications, 2026-09-20. See FOREVER.md.
if not WeakAuras.IsLibsOK() then return end
local Private = select(2, ...)
local L = WeakAuras.L
local F = Private.Forever
local definitions, loaded = {}, {}
local frame = CreateFrame("Frame")
Private.frames["Forever sources"] = frame

local function update(id, preview)
  for index, trigger in pairs(definitions[id] or {}) do
    local states = WeakAuras.GetTriggerStateForTrigger(id, index)
    states[""] = F.MakeState(trigger, preview)
  end
  Private.UpdatedTriggerState(id)
end

local function refresh()
  if not WeakAuras.IsLoginFinished() or WeakAuras.IsPaused() then return end
  for id in pairs(loaded) do update(id, false) end
end

local system = {}
function system.Add(data)
  local triggers = {}
  for index, entry in ipairs(data.triggers) do
    if entry.trigger.type == "forever" then triggers[index] = entry.trigger end
  end
  definitions[data.id] = next(triggers) and triggers or nil
  local nativeCount = 0
  for _, trigger in pairs(triggers) do
    if trigger.source == "buff" or trigger.source == "cooldown" then nativeCount = nativeCount + 1 end
  end
  local message
  if nativeCount > 0 and data.regionType ~= "icon" then
    message = L["Native cooldown and buff sources require an Icon in this prototype."]
  elseif nativeCount > 1 then
    message = L["Use one native cooldown or buff source per icon in this prototype."]
  end
  Private.AuraWarnings.UpdateWarning(data.uid, "forever-source", "warning", message)
end
function system.Delete(id)
  definitions[id], loaded[id] = nil, nil
end
function system.Rename(oldID, newID)
  definitions[newID], definitions[oldID] = definitions[oldID], nil
  loaded[newID], loaded[oldID] = loaded[oldID], nil
end
function system.LoadDisplays(toLoad)
  for id in pairs(toLoad) do
    if definitions[id] then loaded[id] = true end
  end
end
function system.UnloadDisplays(toUnload)
  for id in pairs(toUnload) do loaded[id] = nil end
end
function system.UnloadAll() wipe(loaded) end
function system.FinishLoadUnload()
  for id in pairs(loaded) do update(id, false) end
end
function system.GetName() return L["Forever"] .. WeakAuras.newFeatureString end
function system.GetNameAndIcon(data, index) return F.NameAndIcon(data.triggers[index].trigger) end
function system.GetOverlayInfo() return {} end
function system.CanHaveTooltip() return false end
function system.GetAdditionalProperties(data, index)
  if (data.triggers[index].trigger.source or "ammo") == "ammo" then
    return {count = {display = L["Ammo count"]}}
  end
  return {}
end
function system.GetTriggerDescription(data, index, names)
  table.insert(names, {L["Trigger:"], F.sourceNames[data.triggers[index].trigger.source or "ammo"]})
end
function system.GetTriggerConditions(data, index)
  if (data.triggers[index].trigger.source or "ammo") == "ammo" then
    return {
      count = {display = L["Ammo count"], type = "number", total = "total"},
      available = {display = L["Count available"], type = "bool"}
    }
  end
  return {}
end
function system.GetProgressSources(data, index, values)
  if (data.triggers[index].trigger.source or "ammo") == "ammo" then
    table.insert(values, {trigger = index, property = "count", type = "number",
                         display = L["Ammo count"], total = "total"})
  end
end
function system.CreateFallbackState(data, index, state)
  for key, value in pairs(F.MakeState(data.triggers[index].trigger, true)) do state[key] = value end
end
function system.CreateFakeStates(id, index)
  local states = WeakAuras.GetTriggerStateForTrigger(id, index)
  states[""] = F.MakeState(definitions[id][index], true)
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
        local duration = C_Spell.GetSpellCooldownDuration(id, true)
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
      container:SetUnit("player")
      container:AddAuraSlot("buff", "HELPFUL", {
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

for _, event in ipairs({"PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED",
                        "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "SPELLS_CHANGED",
                        "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED"}) do
  frame:RegisterEvent(event)
end
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

-- Registered on the existing slash dispatcher table; no new global table.
SLASH_WEAKAURASFOREVER1 = "/waf"
SlashCmdList.WEAKAURASFOREVER = function(input)
  if input == "test" then
    if InCombatLockdown() or not WeakAuras.IsLoginFinished() then
      WeakAuras.prettyPrint(L["Wait until login completes and leave combat before creating test auras."])
      return
    end
    testAura(L["Forever test - Raptor Strike"], "icon", "cooldown", -64, -160)
    testAura(L["Forever test - Aspect of the Monkey"], "icon", "buff", 0, -160)
    testAura(L["Forever test - Ammunition"], "aurabar", "ammo", 0, -210)
    Private.ScanForLoads()
    WeakAuras.prettyPrint(L["Test auras created. Open /wa to edit them. Existing test auras were kept."])
    WeakAuras.OpenOptions()
  else
    WeakAuras.prettyPrint(L["Forever prototype: /waf test creates cooldown, buff and ammunition examples. /wa opens the editor."])
  end
end
