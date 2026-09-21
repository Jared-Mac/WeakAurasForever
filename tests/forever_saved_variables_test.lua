-- The actual save-selection boundary, without emulating the WoW addon loader.
local testsDir = arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path = testsDir .. "/?.lua;" .. package.path
local T = require("helpers")
WeakAuras = {addonName = "WAF"}
T.loadAddonFile("WeakAuras/ForeverSavedVariables.lua", "WAF", {})

for _, suffix in ipairs({"Saved", "OptionsSaved", "Archive"}) do
  local name = "WAF" .. suffix
  local old = {displays = {kept = {uid = "stable", xOffset = 123}}, collapsed = false}
  _G[name] = nil
  local adopted = WeakAuras.ForeverSavedVariables(suffix, old)
  T.expect(adopted == old and _G[name] == old, suffix .. " adopts the complete legacy table")
  T.expect(adopted.displays.kept.uid == "stable" and adopted.collapsed == false,
           suffix .. " retains IDs, settings and explicit false values")

  adopted.displays.kept = nil
  local stale = {displays = {kept = {uid = "old"}, removed = {}}}
  T.expect(WeakAuras.ForeverSavedVariables(suffix, stale) == adopted,
           suffix .. " keeps the new save when a legacy save also exists")
  T.expect(next(adopted.displays) == nil, suffix .. " does not resurrect deleted auras")

  _G[name] = {}
  T.expect(WeakAuras.ForeverSavedVariables(suffix, old) == _G[name] and next(_G[name]) == nil,
           suffix .. " honors an explicitly empty new save")
  _G[name] = nil
  local fresh = WeakAuras.ForeverSavedVariables(suffix, nil)
  T.expect(type(fresh) == "table" and next(fresh) == nil and _G[name] == fresh,
           suffix .. " supports a fresh install with no legacy data")
end
T.finish()
