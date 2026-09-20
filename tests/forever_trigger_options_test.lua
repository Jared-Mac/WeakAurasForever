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
T.expect(panel.args[header(1)].name == "Trigger 1: Player buff (native)", "ignores stale legacy event metadata for Forever")
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
T.finish()
