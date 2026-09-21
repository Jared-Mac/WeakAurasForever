-- WAF rename compatibility, 2026-09-20. See FOREVER.md.
-- Required data-only addons load the previous fork's variables first. WAF's
-- own variables win even when empty, so deleted auras are never backfilled.
function WeakAuras.ForeverSavedVariables(suffix, legacy)
  local name = WeakAuras.addonName .. suffix
  if _G[name] == nil then
    _G[name] = legacy or {}
  end
  return _G[name]
end
