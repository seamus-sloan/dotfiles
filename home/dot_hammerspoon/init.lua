local REX = "com.superlogical.rex"
local HEIGHT_RATIO_KEY = "rexHeightRatio"

hs.autoLaunch(true)
-- Instant moves, so the frame read right after one is the size Rex settled on.
hs.window.animationDuration = 0

local heightRatio = hs.settings.get(HEIGHT_RATIO_KEY) or 0.5
local dockedHeight

local function dockToTop(win)
  -- Only a resize since the last dock changes the saved share; Rex's minimum height doesn't.
  local height = win:frame().h
  if dockedHeight and math.abs(height - dockedHeight) > 1 then
    heightRatio = height / win:screen():frame().h
    hs.settings.set(HEIGHT_RATIO_KEY, heightRatio)
  end

  local screen = (hs.mouse.getCurrentScreen() or hs.screen.mainScreen()):frame()
  win:setFrame({ x = screen.x, y = screen.y, w = screen.w, h = screen.h * heightRatio })
  dockedHeight = win:frame().h
  win:focus()
end

hs.hotkey.bind({ "cmd" }, "g", function()
  local app = hs.application.get(REX)
  if not app then
    hs.application.launchOrFocusByBundleID(REX)
    return
  end
  if app:isFrontmost() then
    app:hide()
    return
  end

  app:unhide()
  local win = app:mainWindow()
  if not win then
    app:activate()
    return
  end
  if win:isFullScreen() then
    win:setFullScreen(false)
    hs.timer.waitUntil(function() return not win:isFullScreen() end, function() dockToTop(win) end, 0.1)
  else
    dockToTop(win)
  end
end)
