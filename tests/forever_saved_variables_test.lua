-- The actual save-selection boundary, without emulating the WoW addon loader.
local testsDir = arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path = testsDir .. "/?.lua;" .. package.path
local T = require("helpers")
WeakAuras = {addonName = "WAF"}
T.loadAddonFile("WeakAuras/ForeverSavedVariables.lua", "WAF", {})

for _, suffix in ipairs({"Saved", "OptionsSaved", "Archive"}) do
  local name = "WAF" .. suffix
  local saved = {displays = {kept = {uid = "stable", xOffset = 123}}, collapsed = false}
  _G[name] = saved
  _G["WeakAuras" .. suffix] = {displays = {stale = {}}}
  T.expect(WeakAuras.ForeverSavedVariables(suffix) == saved, suffix .. " retains the WAF table")
  T.expect(saved.displays.kept.uid == "stable" and saved.collapsed == false,
           suffix .. " retains IDs, settings and explicit false values")
  saved.displays.kept = nil
  T.expect(next(WeakAuras.ForeverSavedVariables(suffix).displays) == nil,
           suffix .. " does not resurrect deleted auras")
  _G[name] = {}
  T.expect(next(WeakAuras.ForeverSavedVariables(suffix)) == nil,
           suffix .. " honors an explicitly empty WAF save")
  _G[name] = nil
  local fresh = WeakAuras.ForeverSavedVariables(suffix)
  T.expect(type(fresh) == "table" and next(fresh) == nil and _G[name] == fresh,
           suffix .. " starts empty instead of adopting an unrelated legacy global")
end
T.finish()
