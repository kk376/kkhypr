--!nonstrict
local function refresh()
  noctalia.runAsync("cat /run/user/$(id -u)/bt_battery.json 2>/dev/null || cat /run/user/1000/bt_battery.json", function(result)
    if result.exitCode == 0 and result.stdout and result.stdout ~= "" then
      local connected = result.stdout:match('"connected":%s*true') ~= nil
      local percent = tonumber(result.stdout:match('"percent":%s*(%d+)'))
      local name = result.stdout:match('"name":%s*"([^"]+)"')

      if connected and percent then
        barWidget.setVisible(true)
        barWidget.setGlyph("bluetooth")
        barWidget.setText(tostring(percent) .. "%")
        local deviceName = (name and name ~= "") and name or "Bluetooth Device"
        barWidget.setTooltip(deviceName .. " " .. tostring(percent) .. "%")
        return
      end
    end
    barWidget.setVisible(false)
  end)
end

function update()
  noctalia.setUpdateInterval(2000)
  refresh()
end

function onIpc(event, payload)
  if event == "quit" then
    noctalia.runAsync("/home/kk376/.config/hypr/scripts/app_menu.sh", function() end)
  end
end

refresh()
