-- Spellbook metadata and persistence-boundary fixtures, not a WoW frame runtime.
-- The ranks below were read from this character's saved Forever spellbook cache.
local testsDir = arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path = testsDir .. "/?.lua;" .. package.path
local T = require("helpers")
local private, saved, messages = {}, {}, {}
local serial, writes, opens, scans = 0, 0, 0, 0
local combat, loggedIn = false, true
WeakAuras = {
  IsLibsOK = function() return true end,
  IsLoginFinished = function() return loggedIn end,
  L = setmetatable({}, {__index = function(_, key) return key end}),
  GenerateUniqueID = function() serial = serial + 1 return "hunter-" .. serial end,
  InternalVersion = function() return 90 end,
  GetData = function(id) return saved[id] end,
  Add = function(data)
    if data.parent then assert(saved[data.parent], "parent must exist before adding its child") end
    saved[data.id] = data
    writes = writes + 1
  end,
  prettyPrint = function(text) messages[#messages + 1] = text end,
  OpenOptions = function() opens = opens + 1 end
}
private.ScanForLoads = function() scans = scans + 1 end
InCombatLockdown = function() return combat end
issecretvalue = function() return false end
canaccessvalue = function() return true end
UnitClass = function() return "Hunter", "HUNTER" end
Enum = {SpellBookSpellBank = {Player = 0}, SpellBookItemType = {Spell = 1}}
local function spell(id, name, rank, icon)
  return {spellID = id, actionID = id, name = name, subName = "Rank " .. rank,
    itemType = 1, isPassive = false, isOffSpec = false, iconID = icon}
end
local slots = {
  spell(14281, "Arcane Shot", 2, 132218), spell(3044, "Arcane Shot", 1, 132218),
  spell(5116, "Concussive Shot", 1, 135860), spell(20736, "Distracting Shot", 1, 135736),
  spell(2973, "Raptor Strike", 1, 132223), spell(14260, "Raptor Strike", 2, 132223),
  spell(1259799, "Elune's Light", 1, 136057), spell(20580, "Shadowmeld", 1, 132089),
  {spellID = 20582, name = "Quickness", itemType = 1, isPassive = true},
  {spellID = 999, name = "Arcane Shot", subName = "Rank 99", itemType = 1, isOffSpec = true},
  {spellID = 888, name = "Arcane Shot", subName = "Rank 98", itemType = 2}
}
local queries = {}
C_SpellBook = {
  GetNumSpellBookSkillLines = function() return 1 end,
  GetSpellBookSkillLineInfo = function() return {itemIndexOffset = 6, numSpellBookItems = #slots} end,
  GetSpellBookItemInfo = function(slot, bank)
    assert(slot >= 7 and slot <= #slots + 6 and bank == 0)
    queries[#queries + 1] = slot
    return slots[slot - 6]
  end
}
C_Spell = setmetatable({}, {__index = function() error("Preset probed the general spell database") end})
T.loadAddonFile("WeakAuras/ForeverState.lua", "WeakAuras", private)
T.loadAddonFile("WeakAuras/ForeverPresets.lua", "WeakAuras", private)
T.loadAddonFile("WeakAuras/ForeverMana.lua", "WeakAuras", private)
local F = private.Forever
T.section("Character-specific selection uses only the reported spellbook")
local book = F.HunterSpellbook()
local selected, skipped = F.HunterSelection(book)
T.expect(#queries == #slots and #book == 8, "reads bounded slots and skips passives, off-spec and future spells")
T.expect(#selected == 6 and #skipped == 0, "selects four learned Hunter cooldowns and two racials")
T.expect(selected[1].spellID == 14281 and selected[4].spellID == 14260,
  "selects highest learned ranks even when the higher rank appears first")
T.expect(selected[5].spellID == 1259799 and selected[6].spellID == 20580, "uses confirmed Forever racial IDs")
local lowLevel, missing = F.HunterSelection({slots[2], slots[5]})
T.expect(#lowLevel == 2 and #missing == 4 and lowLevel[1].spellID == 3044, "lower-level characters get only learned spells")

T.section("Group definitions and non-destructive creation")
local displays = F.BuildHunterPreset(book)
T.expect(#displays == 9 and #F.ValidateHunterPreset(displays, book) == 0, "validates one parent and eight auras")
T.expect(displays[2].triggers[1].trigger.source == "mana" and displays[3].triggers[1].trigger.swingType == 2,
  "uses native mana and the documented ranged swing enum")
T.expect(displays[2].width == 306 and displays[3].width == 306, "bars align with the full cooldown row")
T.expect(displays[8].xOffset - displays[7].xOffset == 62, "separates racials from Hunter cooldowns")
T.expect(displays[2].yOffset - displays[2].height / 2 > displays[3].yOffset + displays[3].height / 2
  and displays[3].yOffset - displays[3].height / 2 > displays[4].height / 2, "bars and icon row do not overlap")
for i = 4, #displays do
  local d = displays[i]
  T.expect(d.cooldown and d.cooldownSwipe and not d.cooldownTextDisabled and #d.subRegions == 0,
    d.id .. " uses native cooldown numbers without labels or WA numeric timer text")
  T.expect(d.triggers.disjunctive == "all" and d.triggers.activeTriggerMode == 1
    and d.triggers[2].trigger.classToken == "HUNTER" and d.triggers[3].trigger.source == "spell_known",
    d.id .. " requires Hunter class and a learned spell while keeping the native display source")
end
local id = displays[4].id
saved[id] = {id = id, width = 999}
local collision = F.BuildHunterPreset(book)
T.expect(collision[4].id == id .. " 2" and saved[id].width == 999, "child name collisions preserve unrelated auras")
saved = {}
combat = true
F.HunterCommand("")
T.expect(writes == 0, "creation is deferred during combat")
combat, loggedIn = false, false
F.HunterCommand("")
T.expect(writes == 0, "creation waits for the real login boundary")
loggedIn = true
F.HunterCommand("")
T.expect(writes == 10 and scans == 1 and opens == 1, "explicit command creates parent, children, and refreshed parent")
local group = saved["Forever Hunter"]
local removed = table.remove(group.controlledChildren)
saved[removed] = nil
group.xOffset = 137
local before = writes
F.HunterCommand("")
T.expect(writes == before and group.xOffset == 137 and saved[removed] == nil,
  "running creation again does not reset position or restore deleted auras")
F.HunterCommand("validate")
T.expect(writes == before, "validation never changes saved auras")
displays[4].regionType = "aurabar"
T.expect(#F.ValidateHunterPreset(displays, book) == 1, "rejects an icon-only native source on a bar")
displays[4].regionType = "icon"
displays[4].triggers[1].trigger.spellID = 999999
T.expect(#F.ValidateHunterPreset(displays, book) == 1, "rejects a cooldown ID absent from the spellbook")
displays[4].triggers[1].trigger.spellID = 14281
displays[1].controlledChildren[#displays[1].controlledChildren + 1] = "missing-child"
T.expect(#F.ValidateHunterPreset(displays, book) == 1, "rejects dangling group membership")

T.section("Mana rendering forwards opaque values only to native setters")
local percent, current, maximum = {}, {}, {}
local calls, received, format, values = 0
UnitPowerPercent = function(unit, power, unmodified, curve)
  assert(unit == "player" and power == 0 and not unmodified)
  calls = calls + 1
  received = curve
  return percent
end
UnitPower = function(unit, power) assert(unit == "player" and power == 0) return current end
UnitPowerMax = function(unit, power) assert(unit == "player" and power == 0) return maximum end
local bar = {SetValue = function(_, value) values = value end}
local text = {SetFormattedText = function(_, pattern, first, second)
  format = {pattern, first, second}
end, SetText = function(_, value) format = value end}
F.DrawMana(bar, text, false, nil, 0)
T.expect(values == percent and format[1] == "%d / %d" and format[2] == current and format[3] == maximum,
  "does not compare, divide or stringify opaque mana before the native setters")
local inverseCurve = {}
F.DrawMana(bar, text, false, inverseCurve, 0)
T.expect(received == inverseCurve, "inversion delegates to Blizzard's curve evaluator")
F.DrawMana(bar, text, true, nil, 0)
T.expect(calls == 2 and values == 0.75 and format == "750 / 1000", "editor sample does not query live mana")
F.DrawMana(bar, text, true, inverseCurve, 0)
T.expect(values == 0.25, "inverse preview agrees with inverse rendering")
local state = F.MakeState({source = "mana"}, false)
T.expect(state.show and state.available and state.count == nil and calls == 2,
  "mana values never enter trigger state, condition fields or WA formatters")
local hidden, foreground, spark = false
local original = function() end
local region = {foreverManaMethods = {UpdateValue = original, PreShow = false},
  UpdateValue = function() error("stale native writer") end, PreShow = original,
  foreverMana = {Hide = function() hidden = true end},
  bar = {fg = {SetAlpha = function(_, v) foreground = v end}, spark = {SetAlpha = function(_, v) spark = v end}}}
F.UnbindMana(region)
F.UnbindMana(region)
T.expect(region.UpdateValue == original and region.PreShow == nil and region.foreverManaMethods == nil
  and hidden and foreground == 1 and spark == 1, "switching source restores writers and hides native rendering idempotently")
T.finish()
