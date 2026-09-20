-- Forever prototype modifications, 2026-09-20. See FOREVER.md.
if not WeakAuras.IsLibsOK() then return end
local OptionsPrivate = select(2, ...)
local L = WeakAuras.L

local function options(data, index)
  local trigger = data.triggers[index].trigger
  local result = {
    __title = L["Forever source"], __order = index, __collapsed = false,
    source = {
      type = "select", name = L["Track"], order = 2,
      values = OptionsPrivate.Private.Forever.sourceNames,
      get = function() return trigger.source or "ammo" end
    },
    spellID = {
      type = "input", name = L["Spell ID"], order = 3,
      hidden = function() return (trigger.source or "ammo") == "ammo" end,
      get = function() return tostring(trigger.spellID or "") end,
      validate = function(_, value)
        local id = tonumber(value)
        return id and id > 0 and id == math.floor(id) or L["Enter a positive spell ID."]
      end
    },
    maximum = {
      type = "range", name = L["Bar maximum"], order = 3, min = 1, max = 10000, step = 1,
      hidden = function() return (trigger.source or "ammo") ~= "ammo" end,
      get = function() return trigger.maximum or 200 end
    },
    lowOnly = {
      type = "toggle", name = L["Only show when ammunition is low"], order = 4,
      hidden = function() return (trigger.source or "ammo") ~= "ammo" end
    },
    threshold = {
      type = "range", name = L["Show at or below"], order = 5, min = 0, max = 10000, step = 1,
      hidden = function() return (trigger.source or "ammo") ~= "ammo" or not trigger.lowOnly end,
      get = function() return trigger.threshold or 100 end
    },
    help = {
      type = "description", order = 6, width = "full",
      name = function()
        if (trigger.source or "ammo") == "ammo" then
          return L["Counts equipped ammunition in your bags. Use Conditions > Ammo count to change color, glow or other styling. Missing ammunition counts as zero; unavailable data hides the display."]
        elseif trigger.source == "buff" then
          return L["Icon only. Blizzard displays this player's exact buff, including its native timer. Buff presence, stacks and remaining time are unavailable to conditions. Extra WA borders and text are independent of buff visibility. One native source per icon."]
        end
        return L["Icon only. Blizzard draws the cooldown and timer. Keep Display > Cooldown enabled. Numeric remaining time and ready-state conditions are not supported yet. One native source per icon."]
      end
    }
  }
  OptionsPrivate.commonOptions.AddCommonTriggerOptions(result, data, index)
  OptionsPrivate.commonOptions.AddTriggerGetterSetter(result, data, index)
  OptionsPrivate.AddTriggerMetaFunctions(result, data, index)
  return {["trigger." .. index .. ".forever"] = result}
end
WeakAuras.RegisterTriggerSystemOptions({"forever"}, options)
