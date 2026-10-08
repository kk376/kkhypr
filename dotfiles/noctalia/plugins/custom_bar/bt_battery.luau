--!nonstrict
local function refresh()
  noctalia.runAsync("cat /run/user/$(id -u)/bt_battery.json 2>/dev/null || cat /run/user/1000/bt_battery.json", function(result)
    if result.exitCode == 0 and result.stdout and result.stdout ~= "" then
      local connected = result.stdout:match('"connected":%s*true') ~= nil
      local percent = tonumber(result.stdout:match('"percent":%s*(%d+)'))
      local name = result.stdout:match('"name":%s*"([^"]+)"')

      if connected then
        barWidget.setVisible(true)
        barWidget.setGlyph("bluetooth")
        local deviceName = (name and name ~= "") and name or "Bluetooth Device"
        if percent then
          barWidget.setText(tostring(percent) .. "%")
          barWidget.setTooltip(deviceName .. " " .. tostring(percent) .. "%")
        else
          barWidget.setText("BT")
          barWidget.setTooltip(deviceName .. " (Connecting...)")
        end
        return
      end
    end
    barWidget.setVisible(true)
    barWidget.setGlyph("bluetooth")
    barWidget.setText("")
    barWidget.setTooltip("Bluetooth (Disconnected)")
  end)
end

function update()
  noctalia.setUpdateInterval(1000)
  refresh()
end

function onClick()
  noctalia.runAsync("noctalia msg panel-toggle control-center bluetooth", function() end)
end

function onRightClick()
  noctalia.runAsync("noctalia msg panel-toggle control-center bluetooth", function() end)
end

function onIpc(event, payload)
  if event == "quit" then
    noctalia.runAsync((os.getenv("HOME") or "") .. "/.config/hypr/scripts/app_menu.sh", function() end)
  end
end

barWidget.setVisible(true)
barWidget.setGlyph("bluetooth")
barWidget.setText("")
barWidget.setTooltip("Bluetooth")
refresh()
