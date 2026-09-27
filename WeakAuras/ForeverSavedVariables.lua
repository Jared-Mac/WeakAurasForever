-- Standalone WAF storage, 2026-09-23. See docs/MIGRATION.md.
-- Legacy globals remain runtime aliases, never a source of persisted data.
-- Earlier fork saves are migrated explicitly offline; empty WAF saves win.
function WeakAuras.ForeverSavedVariables(suffix)
  local name = WeakAuras.addonName .. suffix
  if _G[name] == nil then
    _G[name] = {}
  end
  return _G[name]
end
