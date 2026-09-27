-- Exercise the widget's actual hover callbacks with only region-query and
-- drawing recorders. No frame construction, AceGUI layout or mouse emulation.
local testsDir = arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path = testsDir .. "/?.lua;" .. package.path
local T = require("helpers")

local constructor
local ace = {
  GetWidgetVersion = function() return nil end,
  RegisterWidgetType = function(_, name, create)
    assert(name == "WeakAurasSpinBox")
    constructor = create
  end
}
local env = setmetatable({
  WeakAuras = {IsClassicOrTBCOrWrathOrCata = function() return true end},
  LibStub = function() return ace end,
  IsMouseButtonDown = function() return false end,
}, {__index = function(_, name)
  if name == "MouseIsOver" then return nil end
  return _G[name]
end})
local chunk = assert(loadfile(T.repoRoot .. "/WeakAurasOptions/AceGUI-Widgets/AceGUIWidget-WeakAurasSpinBox.lua"))
setfenv(chunk, env)("WAFOptions", {})

local function callback(name)
  local i = 1
  while true do
    local key, value = debug.getupvalue(constructor, i)
    assert(key, "Missing registered callback: " .. name)
    if key == name then return value end
    i = i + 1
  end
end

local enter = callback("Frame_OnEnter")
local update = callback("ProgressBarHandle_OnUpdate")
local overControl, overHandle = true, false
local shown, color, commits = false, nil, 0
local widget = {
  frame = {IsMouseOver = function() return overControl end},
  progressBarHandle = {
    IsMouseOver = function() return overHandle end,
    Show = function() shown = true end,
    Hide = function() shown = false end,
  },
  progressBarHandleTexture = {
    SetColorTexture = function(_, r, g, b, a) color = {r, g, b, a} end,
  },
  GetValue = function() return 42 end,
  SetValue = function(_, value, commit)
    assert(value == 42 and commit == true)
    commits = commits + 1
  end,
}
widget.frame.obj, widget.progressBarHandle.obj = widget, widget

T.section("Hover callbacks without the retired MouseIsOver global")
local ok, err = pcall(enter, widget.frame)
if not T.expect(ok, "entering the number control works without MouseIsOver") then
  print(err)
  T.finish()
end
T.expect(shown and color[1] == 0.4, "hovering the control reveals the idle handle")
overHandle = true
enter(widget.frame)
T.expect(shown and color[1] == 0.8, "hovering the handle highlights it")
overControl, overHandle = false, false
update(widget.progressBarHandle, 0.01)
T.expect(not shown, "leaving the control hides the handle")

overControl = true
widget.progressBarHandle.mouseDown = true
enter(widget.frame)
T.expect(shown and color[1] == 0.6, "a held handle retains its drag color")
update(widget.progressBarHandle, 0.01)
T.expect(commits == 1 and not widget.progressBarHandle.mouseDown,
         "mouse release commits the value and clears dragging")
update(widget.progressBarHandle, 0.01)
T.expect(commits == 1, "later hover updates do not commit again")

env.MouseIsOver = function() error("Retired global was called") end
local compatible = pcall(enter, widget.frame)
T.expect(compatible, "clients with the legacy global also use the region method")
T.finish()
