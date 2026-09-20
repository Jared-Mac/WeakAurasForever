-- Forever prototype modifications, 2026-09-20. See FOREVER.md.
if not WeakAuras.IsLibsOK() then return end
local Private = select(2, ...)
local L = WeakAuras.L

-- The matching scanForLoadsImpl branch supplies only this public combat flag.
Private.load_prototype = {
  args = {
    {name = "combat", display = L["In Combat"], type = "tristate", init = "arg",
     optional = true, events = {"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}},
    {name = "never", display = L["Never"], type = "toggle", test = "false"}
  }
}
Private.data_stub.triggers[1].trigger = {type = "forever", source = "ammo", maximum = 200}
Private.format_types.GCDTime = nil
Private.format_types_display.GCDTime = nil

-- These text helpers also serve the editor and dynamic groups, independently
-- of the legacy event scanner that normally defines them.
function WeakAuras.split(input)
  local result = {}
  for value in (input or ""):gmatch("[^,%s]+") do
    result[#result + 1] = value
  end
  return result
end

function Private.splitAtOr(input)
  local result = {}
  input = (input or ""):gsub(" or ", "|")
  for value in input:gmatch("[^|]+") do result[#result + 1] = value end
  return result
end
