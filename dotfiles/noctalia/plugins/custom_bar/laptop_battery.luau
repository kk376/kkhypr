--!nonstrict
local function updateBattery()
  local capStr = noctalia.readFile("/sys/class/power_supply/BAT1/capacity")
  local status = noctalia.readFile("/sys/class/power_supply/BAT1/status")
  if not capStr then
    capStr = noctalia.readFile("/sys/class/power_supply/BAT0/capacity")
    status = noctalia.readFile("/sys/class/power_supply/BAT0/status")
  end

  if not capStr then
    barWidget.setVisible(false)
    return
  end

  local cap = tonumber(capStr:match("%d+")) or 0
  local cleanStatus = status and status:gsub("[\r\n]", "") or "Unknown"

  local isCharging = false
  local s = cleanStatus:lower()
  local acOnline = noctalia.readFile("/sys/class/power_supply/ADP1/online")
  if not acOnline then
    acOnline = noctalia.readFile("/sys/class/power_supply/AC/online")
  end
  local isAc = acOnline and acOnline:find("1") ~= nil

  if (s:find("charging") or isAc) and not s:find("discharging") then
    isCharging = true
  end

  local glyph = "battery-vertical-4"
  if isCharging then
    glyph = "battery-vertical-charging"
  else
    if cap >= 85 then
      glyph = "battery-vertical-4"
    elseif cap >= 60 then
      glyph = "battery-vertical-3"
    elseif cap >= 35 then
      glyph = "battery-vertical-2"
    elseif cap >= 15 then
      glyph = "battery-vertical-1"
    else
      glyph = "battery-vertical"
    end
  end

  barWidget.setVisible(true)
  barWidget.setGlyph(glyph)
  barWidget.setText(tostring(cap) .. "%")
  barWidget.setTooltip("Battery: " .. tostring(cap) .. "% (" .. cleanStatus .. ")")
end

function update()
  noctalia.setUpdateInterval(3000)
  updateBattery()
end

updateBattery()
