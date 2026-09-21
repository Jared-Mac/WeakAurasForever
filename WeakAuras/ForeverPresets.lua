-- Explicit, non-destructive character presets for the Forever experiment.
if not WeakAuras.IsLibsOK() then return end
local Private = select(2, ...)
local F, L = Private.Forever, WeakAuras.L
local groupID = "Forever Hunter"

-- These IDs/names were confirmed in this character's Forever spellbook cache.
-- Rank selection uses the current spellbook, not general spell-database probes.
local hunterSpells = {
  {name = L["Arcane Shot"], ids = {3044, 14281}},
  {name = L["Concussive Shot"], ids = {5116}},
  {name = L["Distracting Shot"], ids = {20736}},
  {name = L["Raptor Strike"], ids = {2973, 14260}},
  {name = L["Elune's Light"], ids = {1259799}, racial = true},
  {name = L["Shadowmeld"], ids = {20580}, racial = true}
}

function F.HunterSpellbook()
  local book = {}
  local bank = Enum.SpellBookSpellBank.Player
  for index = 1, C_SpellBook.GetNumSpellBookSkillLines() do
    local line = C_SpellBook.GetSpellBookSkillLineInfo(index)
    if line then
      for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
        local info = C_SpellBook.GetSpellBookItemInfo(slot, bank)
        if info and info.itemType == Enum.SpellBookItemType.Spell and info.spellID
          and not info.isPassive and not info.isOffSpec then
          book[#book + 1] = info
        end
      end
    end
  end
  return book
end

function F.HunterSelection(book)
  local selected, skipped = {}, {}
  for _, wanted in ipairs(hunterSpells) do
    local best, bestRank
    for _, info in ipairs(book) do
      local matches = info.name == wanted.name
      for _, id in ipairs(wanted.ids) do
        if info.spellID == id or info.actionID == id then matches = true end
      end
      if matches then
        local rank = tonumber((info.subName or ""):match("(%d+)")) or 0
        if not best or rank >= bestRank then best, bestRank = info, rank end
      end
    end
    if best then
      selected[#selected + 1] = {name = best.name, spellID = best.spellID, icon = best.iconID, racial = wanted.racial}
    else
      skipped[#skipped + 1] = wanted.name
    end
  end
  return selected, skipped
end

local function uniqueID(base)
  local id, suffix = base, 2
  while WeakAuras.GetData(id) do
    id, suffix = base .. " " .. suffix, suffix + 1
  end
  return id
end

function F.BuildHunterPreset(book)
  local selected, skipped = F.HunterSelection(book)
  local displays = {}
  local group = {
    id = groupID, uid = WeakAuras.GenerateUniqueID(), internalVersion = WeakAuras.InternalVersion(),
    regionType = "group", controlledChildren = {}, load = {}, triggers = {},
    anchorFrameType = "SCREEN", anchorPoint = "CENTER", xOffset = 0, yOffset = -160,
    scale = 1, information = {groupOffset = false}
  }
  displays[1] = group
  local size, gap, sectionGap = 44, 6, 12
  local hasClass, hasRacial = false, false
  for _, spell in ipairs(selected) do
    if spell.racial then hasRacial = true else hasClass = true end
  end
  local width = math.max(240, #selected * size + math.max(0, #selected - 1) * gap
    + (hasClass and hasRacial and sectionGap or 0))
  local function child(label, regionType, source, y)
    local data = {
      id = uniqueID(groupID .. " - " .. label), uid = WeakAuras.GenerateUniqueID(),
      internalVersion = WeakAuras.InternalVersion(), parent = groupID, regionType = regionType,
      anchorFrameType = "SCREEN", anchorPoint = "CENTER", selfPoint = "CENTER",
      xOffset = 0, yOffset = y, width = width, height = 20,
      triggers = {
        {trigger = {type = "forever", source = source}, untrigger = {}},
        {trigger = {type = "forever", source = "class", classToken = "HUNTER"}, untrigger = {}},
        disjunctive = "all", activeTriggerMode = 1
      },
      load = {}, subRegions = {}, conditions = {}
    }
    group.controlledChildren[#group.controlledChildren + 1] = data.id
    displays[#displays + 1] = data
    return data
  end
  local mana = child(L["Mana"], "aurabar", "mana", 46)
  mana.barColor, mana.backgroundColor = {0.15, 0.45, 1, 1}, {0.02, 0.025, 0.04, 0.9}
  mana.texture, mana.orientation, mana.icon = "Blizzard", "HORIZONTAL", false
  mana.triggers[1].trigger.manaText = true
  local swing = child(L["Ranged swing"], "aurabar", "swing", 30)
  swing.height, swing.texture, swing.orientation, swing.icon = 8, "Blizzard", "HORIZONTAL", false
  swing.barColor, swing.backgroundColor = {1, 0.72, 0.18, 1}, {0.02, 0.025, 0.04, 0.9}
  swing.triggers[1].trigger.swingType = 2
  local x, lastRacial = -width / 2 + size / 2, false
  for _, spell in ipairs(selected) do
    if spell.racial and not lastRacial and hasClass then x = x + sectionGap end
    local icon = child(spell.name, "icon", "cooldown", 0)
    icon.xOffset, icon.width, icon.height = x, size, size
    icon.cooldown, icon.cooldownSwipe, icon.cooldownEdge, icon.cooldownTextDisabled = true, true, false, false
    icon.zoom, icon.color, icon.displayIcon = 0.12, {1, 1, 1, 1}, spell.icon
    icon.triggers[1].trigger.spellID = spell.spellID
    icon.triggers[3] = {trigger = {type = "forever", source = "spell_known", spellID = spell.spellID}, untrigger = {}}
    x, lastRacial = x + size + gap, spell.racial
  end
  return displays, skipped
end

function F.ValidateHunterPreset(displays, book)
  local errors, byID, known, seen = {}, {}, {}, {}
  for _, info in ipairs(book) do known[info.spellID] = true end
  for _, data in ipairs(displays) do
    if byID[data.id] then errors[#errors + 1] = L["Duplicate aura name."] end
    byID[data.id] = data
  end
  local group = byID[groupID]
  if not group or group.regionType ~= "group" then return {L["Hunter group is missing."]} end
  for _, id in ipairs(group.controlledChildren) do
    local data = byID[id]
    if seen[id] or not data or data.parent ~= groupID then
      errors[#errors + 1] = L["Invalid group membership: "] .. id
    else
      seen[id] = true
      for _, entry in ipairs(data.triggers) do
        local trigger = entry.trigger
        if trigger.type ~= "forever" or not F.Source(trigger) then
          errors[#errors + 1] = L["Unsupported trigger: "] .. id
        elseif F.NativeRegion(trigger) and F.NativeRegion(trigger) ~= data.regionType then
          errors[#errors + 1] = L["Wrong native display type: "] .. id
        elseif trigger.source == "cooldown" and not known[trigger.spellID] then
          errors[#errors + 1] = L["Spell is not in the current spellbook: "] .. id
        end
      end
    end
  end
  for _, data in ipairs(displays) do
    if data ~= group and not seen[data.id] then errors[#errors + 1] = L["Ungrouped aura: "] .. data.id end
  end
  return errors
end

function F.HunterCommand(command)
  if InCombatLockdown() or not WeakAuras.IsLoginFinished() then
    WeakAuras.prettyPrint(L["Wait until login completes and leave combat before creating or validating the Hunter group."])
    return
  end
  if command ~= "" and command ~= "validate" then
    WeakAuras.prettyPrint(L["Use /waf hunter to create the group, or /waf hunter validate to check it."])
    return
  end
  if F.ClassToken() ~= "HUNTER" then
    WeakAuras.prettyPrint(L["This preset is for your Hunter character."])
    return
  end
  local book = F.HunterSpellbook()
  local group = WeakAuras.GetData(groupID)
  if command ~= "validate" and group then
    WeakAuras.prettyPrint(L["Forever Hunter already exists. Your edits and deletions were kept. Open /wa to edit or export it."])
    WeakAuras.OpenOptions()
    return
  end
  local displays, skipped
  if command == "validate" then
    if not group then WeakAuras.prettyPrint(L["Create the group first with /waf hunter."]) return end
    displays = {group}
    for _, id in ipairs(group.controlledChildren or {}) do
      local data = WeakAuras.GetData(id)
      if data then displays[#displays + 1] = data end
    end
  else
    displays, skipped = F.BuildHunterPreset(book)
    if #displays == 3 then
      WeakAuras.prettyPrint(L["No matching Hunter spells are available yet. Try again after the spellbook loads."])
      return
    end
  end
  local errors = F.ValidateHunterPreset(displays, book)
  if #errors > 0 then
    for _, message in ipairs(errors) do WeakAuras.prettyPrint(message) end
    return
  end
  if command ~= "validate" then
    -- Match WA's grouping order: create the parent, add each child, then rebuild
    -- the parent's bounds. No file writes, login seeding or recurring backfill.
    group = displays[1]
    local children = group.controlledChildren
    group.controlledChildren = {}
    WeakAuras.Add(group)
    for i = 2, #displays do
      group.controlledChildren[#group.controlledChildren + 1] = children[i - 1]
      WeakAuras.Add(displays[i])
    end
    WeakAuras.Add(group)
    Private.ScanForLoads()
    if #skipped > 0 then WeakAuras.prettyPrint(L["Not learned; skipped: "] .. table.concat(skipped, ", ")) end
    WeakAuras.OpenOptions()
  end
  WeakAuras.prettyPrint(L["Forever Hunter: %d auras validated against your current spellbook. Mana uses native rendering; ranged swing starts on your next shot."]:format(#displays - 1))
  for i = 2, #displays do
    local t = displays[i].triggers[1].trigger
    if t.source == "cooldown" then WeakAuras.prettyPrint(displays[i].id .. " (" .. t.spellID .. ")") end
  end
end
