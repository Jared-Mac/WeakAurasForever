-- Build the real Trigger tab option tables, including the registered Forever
-- provider and shared header/flattening/getter/setter functions. Only core
-- registry, traversal and editor refresh callbacks are fixtures; no WoW UI is
-- emulated, and no spell/inventory APIs are needed to label a trigger.
local testsDir = arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path = testsDir .. "/?.lua;" .. package.path
local T = require("helpers")
local stubs = require("wow_stubs")
stubs.install()
max = math.max
C_AddOns = {GetAddOnEnableState = function() return 0 end}
Enum = {AddOnEnableState = {None = 0}}
local updates = 0
WeakAuras = {
  IsLibsOK = function() return true end,
  IsForever = function() return true end,
  L = setmetatable({}, {__index = function(_, key) return key end}),
  normalWidth = 1.3, doubleWidth = 2.6,
  Add = function() updates = updates + 1 end,
  ClearAndUpdateOptions = function() end,
  UpdateThumbnail = function() end
}
local private = {
  event_prototypes = {Health = {name = "Health"}},
  event_categories = {},
  triggerTypes = {forever = {GetName = function() return "Forever" end}},
  triggerTypesOptions = {},
  TraverseLeafsOrAura = function(data)
    local pending = true
    return function()
      if pending then pending = false return data end
    end
  end,
  SortOrderForValues = function(values)
    local result = {}
    for key in pairs(values) do result[#result + 1] = key end
    table.sort(result)
    return result
  end
}
local optionsPrivate = {
  Private = private,
  IsCollapsed = function(_, _, _, default) return default end,
  SetCollapsed = function() end,
  MoveCollapseDataUp = function() end,
  MoveCollapseDataDown = function() end
}
WeakAuras.RegisterTriggerSystemOptions = function(types, provider)
  for _, kind in ipairs(types) do private.triggerTypesOptions[kind] = provider end
end
T.loadAddonFile("WeakAuras/ForeverState.lua", "WeakAuras", private)
T.loadAddonFile("WeakAurasOptions/CommonOptions.lua", "WeakAurasOptions", optionsPrivate)
T.loadAddonFile("WeakAurasOptions/TriggerOptions.lua", "WeakAurasOptions", optionsPrivate)
T.loadAddonFile("WeakAurasOptions/ForeverTrigger.lua", "WeakAurasOptions", optionsPrivate)
local data = {id = "test", triggers = {{trigger = {type = "forever", source = "ammo"}}},
              conditions = {}, subRegions = {}}
T.section("Forever providers reach the real shared Trigger tab builder")
local ok, panel = pcall(optionsPrivate.GetTriggerOptions, data)
if not T.expect(ok, "builds the ammunition Trigger tab without a legacy event prototype") then
  print(tostring(panel))
  T.finish()
end
local function header(index)
  return "trigger." .. index .. ".forevercollapseButton"
end
T.expect(panel.args[header(1)].name == "Trigger 1: Equipped ammunition", "uses the source label in the real collapsible heading")
T.expect(panel.args["trigger.1.forever.source"].get() == "ammo", "source control reads the current source")
for source, title in pairs(private.Forever.sourceNames) do
  data.triggers[1].trigger.source = source
  panel = optionsPrivate.GetTriggerOptions(data)
  T.expect(panel.args[header(1)].name == "Trigger 1: " .. title, "builds and labels " .. source)
end
-- The Add Trigger button creates {type='forever'} without an event or source.
panel.args["addTriggerOption.addTrigger"].func()
panel = optionsPrivate.GetTriggerOptions(data)
T.expect(data.triggers[2].trigger.type == "forever" and data.triggers[2].trigger.source == nil,
         "tests the actual Add Trigger default shape")
T.expect(panel.args[header(2)].name == "Trigger 2: Equipped ammunition", "new triggers use the runtime's default source")
-- A lingering event field from switching trigger types must not win the title.
data.triggers[1].trigger.event = "Health"
data.triggers[1].trigger.source = "buff"
panel = optionsPrivate.GetTriggerOptions(data)
T.expect(panel.args[header(1)].name == "Trigger 1: Buff / debuff display (native)", "ignores stale legacy event metadata for Forever")
local before = updates
panel.args["trigger.1.forever.source"].set(nil, "cooldown")
panel = optionsPrivate.GetTriggerOptions(data)
T.expect(updates == before + 1 and panel.args[header(1)].name == "Trigger 1: Spell cooldown (native)", "source editing rebuilds the title through the real setter")
panel.args["trigger.1.foreverdownButton"].func()
panel = optionsPrivate.GetTriggerOptions(data)
T.expect(panel.args[header(1)].name == "Trigger 1: Equipped ammunition"
  and panel.args[header(2)].name == "Trigger 2: Spell cooldown (native)", "reordering keeps source labels with their triggers")
T.expect(optionsPrivate.GetTriggerTitle(data, 2) == panel.args[header(2)].name,
         "the shared title helper used by Conditions agrees with the Trigger tab")
data.triggers[1].trigger.source = "future-source"
T.expect(optionsPrivate.GetTriggerTitle(data, 1) == "Trigger 1: Forever", "unknown Forever source keeps a generic source title")

T.section("Existing trigger headings remain unchanged")
for _, item in ipairs({{"aura2", "Aura"}, {"custom", "Custom"}, {"unit", "Health"}}) do
  data.triggers[1].trigger = {type = item[1], event = "Health"}
  T.expect(optionsPrivate.GetTriggerTitle(data, 1) == "Trigger 1: " .. item[2], "preserves " .. item[1] .. " heading")
end
T.expect(optionsPrivate.GetTriggerTitle(data, 3) == "Trigger 3", "missing trigger slot keeps the existing generic heading")
T.section("Category controls, focused fields and persisted settings")
WeakAuras.class_types = {HUNTER = "Hunter", MAGE = "Mage"}
WeakAuras.spellCache = {Get = function() return {
  ["Raptor Strike"] = {spells = "2973=132223"},
  ["Aspect of the Monkey"] = {spells = "13163=132159"}
} end}
C_Spell = {GetSpellName = function() return "Raptor Strike" end}
issecretvalue = function() return false end
canaccessvalue = function() return true end
GetRealZoneText = function() return "Teldrassil" end
local function control(key) return panel.args["trigger.1.forever." .. key] end
local function rebuild() panel = optionsPrivate.GetTriggerOptions(data) end
data.triggers = {{trigger = {type = "forever", source = "ammo", lowOnly = true, threshold = 42}}}
rebuild()
T.expect(control("category").get() == "item", "existing ammo opens in Item")
T.expect(control("compare").get() == "<=" and control("threshold").get() == "42", "legacy low-only threshold appears unchanged")
T.expect(control("source").values().ammo and not control("source").values().buff, "Track lists only the selected category")
T.expect(control("spellID").hidden() and not control("threshold").hidden(), "ammo exposes relevant inputs")
control("compare").set(nil, "always")
rebuild()
T.expect(data.triggers[1].trigger.lowOnly == nil and control("threshold").hidden(), "disabling legacy low-only removes the old constraint")
control("category").set(nil, "spell")
rebuild()
T.expect(data.triggers[1].trigger.type == "forever" and control("source").get() == "cooldown", "category change keeps the persisted provider and selects a source")
T.expect(control("showWhen").hidden() and not control("spellID").hidden(), "native display exposes no presence show/hide setting")
local book = control("spellbook").values()
T.expect(book[2973] == "Raptor Strike (2973)" and book[13163], "picker uses cached spellbook entries and IDs")
control("spellbook").set(nil, 2973)
T.expect(data.triggers[1].trigger.spellID == 2973, "picker writes the ID through the editor update path")
control("category").set(nil, "aura")
rebuild()
control("source").set(nil, "aura_presence")
rebuild()
control("spellbook").set(nil, 13163)
rebuild()
control("spellbook").set(nil, 13163)
T.expect(data.triggers[1].trigger.spellIDs == "2973, 13163", "effect picker appends and deduplicates IDs")
T.expect(control("showWhen").values()["false"] == "None of the effects are present", "Any inverse clearly says none present")
control("auraMatch").set(nil, "all")
rebuild()
T.expect(control("showWhen").values()["false"] == "At least one effect is missing", "All inverse clearly says at least one missing")
T.expect(control("spellIDs").validate(nil, "bad") ~= true, "invalid effect lists are rejected")
control("category").set(nil, "item")
rebuild()
control("compare").set(nil, "<=")
rebuild()
T.expect(control("threshold").validate(nil, "0") == true and control("threshold").validate(nil, "-1") ~= true, "threshold accepts zero and rejects negatives")
control("threshold").set(nil, "12.5")
T.expect(data.triggers[1].trigger.threshold == 12.5, "threshold is persisted as a number")
-- Build and evaluate every visible source's controls through the actual flattening
-- layer. The spellbook fixture is the same name/spells shape produced by Cache.
for source in pairs(private.Forever.sources) do
  data.triggers[1].trigger = {type = "forever", source = source, spellID = 2973}
  rebuild()
  local success, err = pcall(function()
    for key, option in pairs(panel.args) do
      if key:find("trigger.1.forever.", 1, true) == 1 and not (type(option.hidden) == "function" and option.hidden()) then
        for _, property in ipairs({"get", "name", "values", "desc"}) do
          if type(option[property]) == "function" then option[property]() end
        end
      end
    end
  end)
  T.expect(success, "visible controls evaluate for " .. source .. (err and ": " .. tostring(err) or ""))
end
T.finish()
