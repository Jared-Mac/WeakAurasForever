-- Forever native mana rendering. See FOREVER.md for the restricted-data boundary.
if not WeakAuras.IsLibsOK() then return end
local Private = select(2, ...)
local F = Private.Forever

function F.DrawMana(bar, text, preview, inverseCurve, interpolation)
  if preview then
    bar:SetValue(inverseCurve and 0.25 or 0.75)
    text:SetText("750 / 1000")
  else
    -- The WA bar is a Lua texture/mask implementation. Only this real Blizzard
    -- StatusBar and FontString receive mana values; never read them back.
    bar:SetValue(UnitPowerPercent("player", 0, false, inverseCurve), interpolation)
    text:SetFormattedText("%d / %d", UnitPower("player", 0), UnitPowerMax("player", 0))
  end
end

function F.UnbindMana(region)
  if not region.foreverManaMethods then return end
  for name, method in pairs(region.foreverManaMethods) do region[name] = method or nil end
  region.foreverManaMethods = nil
  region.foreverMana:Hide()
  region.bar.fg:SetAlpha(1)
  region.bar.spark:SetAlpha(1)
end

function F.BindMana(region, data)
  local trigger
  for _, entry in ipairs(data.triggers) do
    if entry.trigger.type == "forever" and entry.trigger.source == "mana" then
      trigger = entry.trigger
      break
    end
  end
  if not trigger or type(UnitPowerPercent) ~= "function" then return end
  local native = region.foreverMana
  if not native then
    native = CreateFrame("StatusBar", nil, region)
    native:SetAllPoints(region.bar)
    native:SetMinMaxValues(0, 1)
    native.texture = native:CreateTexture(nil, "ARTWORK")
    native:SetStatusBarTexture(native.texture)
    native.text = native:CreateFontString(nil, "OVERLAY")
    native.text:SetPoint("CENTER")
    native.text:SetTextColor(1, 1, 1, 1)
    native.inverseCurve = C_CurveUtil.CreateCurve()
    native.inverseCurve:SetType(Enum.LuaCurveType.Linear)
    native.inverseCurve:AddPoint(0, 1)
    native.inverseCurve:AddPoint(1, 0)
    region.foreverMana = native
  end
  native.text:SetFont(STANDARD_TEXT_FONT, trigger.manaTextSize or 12, "OUTLINE")
  native.text:SetShown(trigger.manaText ~= false)
  region.bar.fg:SetAlpha(0)
  region.bar.spark:SetAlpha(0)
  region.bar:SetAdditionalBars({}, {}, {}, 0, 1, false, false)
  region.FrameTick = nil
  region.subRegionEvents:RemoveSubscriber("FrameTick", region)

  local function render()
    local interpolation = region.smoothProgress and Enum.StatusBarInterpolation.ExponentialEaseOut
      or Enum.StatusBarInterpolation.Immediate
    F.DrawMana(native, native.text, WeakAuras.IsOptionsOpen(),
      region.inverseDirection and native.inverseCurve or nil, interpolation)
  end
  local function style()
    local orientation = region.effectiveOrientation or "HORIZONTAL"
    native:SetOrientation(orientation:find("VERTICAL", 1, true) and "VERTICAL" or "HORIZONTAL")
    native:SetReverseFill(orientation:find("INVERSE", 1, true) ~= nil)
    native:SetRotatesTexture(true)
    native:SetFrameLevel(region:GetFrameLevel())
    Private.SetTextureOrAtlas(native.texture, region.bar:GetStatusBarTexture())
    local r = region.color_anim_r or region.color_r
    local g = region.color_anim_g or region.color_g
    local b = region.color_anim_b or region.color_b
    local a = region.color_anim_a or region.color_a
    native:SetStatusBarColor(1, 1, 1, 1)
    native.texture:SetGradient(region.enableGradient and region.gradientOrientation or "HORIZONTAL",
      CreateColor(r, g, b, a), region.enableGradient and CreateColor(unpack(region.barColor2)) or CreateColor(r, g, b, a))
  end

  -- Only wrap this addon-owned region. Restore every writer before the next
  -- modify, so changing source or reusing a pooled region restores WA behavior.
  region.foreverManaMethods = {}
  local function replace(name, callback)
    region.foreverManaMethods[name] = region[name] or false
    region[name] = callback
  end
  replace("UpdateValue", render)
  replace("UpdateTime", render)
  replace("PreShow", function() style() render() end)
  replace("SetAdditionalProgress", function() end)
  for _, name in ipairs({"UpdateForegroundColor", "UpdateStatusBarTexture", "UpdateEffectiveOrientation", "SetFrameLevel"}) do
    local original = region[name]
    replace(name, function(self, ...)
      original(self, ...)
      style()
    end)
  end
  local originalInverse = region.SetInverse
  replace("SetInverse", function(self, inverse)
    originalInverse(self, inverse)
    render()
  end)
  style()
  render()
  native:Show()
end
