--[[ 
    ArizonaX Mobile UI Framework - Main Integration Script
    Интеграция Mobile UI Framework и ESP System
]]

local UIFramework = require("lua.mobile_ui_framework")
local ESPSystem = require("lua.esp_system")

-- Инициализация фреймворков
function main()
    while not isSampAvailable() do wait(100) end
    
    -- Инициализируем UI фреймворк
    UIFramework.initializeFonts()
    UIFramework.initializeScaling()
    
    -- Инициализируем ESP систему
    ESPSystem.initialize(UIFramework.state.fonts.main, UIFramework.state.fonts.small)
    
    -- Регистрируем команды
    sampRegisterChatCommand("mmenu", function()
        UIFramework.toggleMenu()
    end)
    
    sampRegisterChatCommand("esp", function()
        local enabled = not ESPSystem.getConfig().enabled
        ESPSystem.setEnabled(enabled)
        sampAddChatMessage("[ESP] " .. (enabled and "Включена ✓" or "Отключена ✗"), 0x2196F3)
    end)
    
    sampRegisterChatCommand("esplines", function()
        local enabled = not ESPSystem.getConfig().drawLines
        ESPSystem.setLineDrawing(enabled)
        sampAddChatMessage("[ESP] Линии " .. (enabled and "включены ✓" or "отключены ✗"), 0x2196F3)
    end)
    
    sampRegisterChatCommand("espstats", function()
        ESPSystem.printStats()
    end)
    
    sampRegisterChatCommand("uiinfo", function()
        local state = UIFramework.getState()
        sampAddChatMessage("[UI] Menu: " .. state.menuX .. ", " .. state.menuY, 0x2196F3)
        sampAddChatMessage("[UI] Scale: " .. string.format("%.2f", state.scale), 0x2196F3)
        sampAddChatMessage("[UI] ESP: " .. (state.espEnabled and "ON" or "OFF"), 0x2196F3)
    end)
    
    -- Основной игровой цикл
    while true do
        wait(0)
        
        -- Получаем координаты мыши
        local mouseX, mouseY = getCursorPos()
        local mouseButton = isKeyJustPressed(0x01) and 0x01 or nil
        
        -- Определяем кнопки меню
        local buttons = {
            {id = "btn_esp_toggle", label = "🎯 ESP Вкл/Выкл"},
            {id = "btn_draw_lines", label = "📍 Линии"},
            {id = "btn_clear_cache", label = "🔄 Очистить"}
        }
        
        -- Определяем ползунки меню
        local sliders = {
            {id = "slider_distance", label = "Дистанция (м):", min = 50, max = 500, value = 250},
            {id = "slider_opacity", label = "Прозрачность:", min = 0, max = 100, value = 100}
        }
        
        -- Отрисовываем меню UI
        UIFramework.renderMenu(mouseX, mouseY, mouseButton, buttons, sliders)
        
        -- Получаем координаты игрока (абстрактная функция)
        local playerX, playerY, playerZ = 0, 0, 0  -- getCharCoordinates(PLAYER_PED)
        
        -- Отрисовываем ESP
        ESPSystem.render(playerX, playerY, playerZ)
    end
end

-- Запускаем главную функцию
main()
