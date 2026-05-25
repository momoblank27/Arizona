# 📱 ArizonaX Mobile UI & ESP Framework

**Advanced MoonLoader UI System for SAMP Mobile Servers**

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/momoblank27/Arizona)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Lua](https://img.shields.io/badge/lua-5.1+-yellow.svg)](https://www.lua.org/)

---

## ✨ Основные возможности

- ✅ **Drag-and-Drop** система перемещения окон
- ✅ **Ползунки (Sliders)** для управления значениями  
- ✅ **Интерактивные кнопки** с колбеками
- ✅ **ESP система** с визуализацией объектов
- ✅ **Динамическое масштабирование** UI
- ✅ **Оптимизированный рендеринг** с кешированием
- ✅ **Преобразование 3D → 2D** координат
- ✅ **Сканирование мира** с фильтрацией объектов

---

## 📦 Структура проекта

```
Arizona/
├── lua/
│   ├── mobile_ui_framework.lua    # Основной UI фреймворк
│   └── esp_system.lua             # ESP система визуализации
├── main.lua                       # Пример интеграции
├── README.md                      # Документация
├── LICENSE                        # MIT License
└── docs/
    └── INDEX.md                   # Полная документация
```

---

## 🚀 Быстрый старт

### 1. Инициализация

```lua
local UIFramework = require("lua.mobile_ui_framework")
local ESPSystem = require("lua.esp_system")

function main()
    while not isSampAvailable() do wait(100) end
    
    -- Инициализируем фреймворк
    UIFramework:initialize()
    ESPSystem:initialize(UIFramework.state.fonts.main, UIFramework.state.fonts.small)
    
    -- Команды
    sampRegisterChatCommand("mmenu", function()
        UIFramework:toggleMenu()
    end)
    
    -- Основной цикл
    while true do
        wait(0)
        if UIFramework.state.menuVisible then
            UIFramework:render()
        end
    end
end
```

### 2. Команды в игре

```
/mmenu              - Открыть/закрыть меню
/esp                - Включить/отключить ESP
/esplines           - Включить/отключить линии
/uiinfo             - Информация отладки
```

---

## 📚 API Фреймворка

### UIFramework Methods

#### Инициализация

```lua
UIFramework:initialize()              -- Полная инициализация
UIFramework:initializeFonts()         -- Создание шрифтов (один раз)
UIFramework:initializeScaling()       -- Инициализировать масштаб
```

#### Управление меню

```lua
UIFramework:toggleMenu()              -- Переключить видимость
UIFramework:setMenuVisible(true)      -- Установить видимость
UIFramework:setMenuPosition(50, 100)  -- Установить позицию
UIFramework:getMenuPosition()         -- Получить позицию
UIFramework:getState()                -- Получить состояние
```

#### Ползунки

```lua
UIFramework:renderSlider(id, label, min, max, x, y, width, mouseX, mouseY, mouseButton)
UIFramework:getSliderValue(id)        -- Получить значен��е
UIFramework:setSliderValue(id, value) -- Установить значение
```

#### Кнопки

```lua
UIFramework:registerButton(id, label, x, y, width, height, callback)
UIFramework:renderButton(id, mouseX, mouseY, mouseButton)
```

#### Отрисовка

```lua
UIFramework:render()                  -- Главная функция отрисовки
UIFramework:renderMenu(mouseX, mouseY, mouseButton, buttons, sliders)
```

---

## 🎯 Система Drag-and-Drop

**Как это работает:**

1. ✅ Отслеживаем нажатие левой кнопки мыши (0x01) на заголовке меню
2. ✅ Вычисляем смещение курсора от левого края окна
3. ✅ При движении мыши плавно обновляем позицию меню
4. ✅ Ограничиваем координаты границами экрана

**Пример кода:**

```lua
function UIFramework:handleDragAndDrop()
    local mouseX, mouseY = getCursorPos()
    local inHeader = self:isPosInArea(mouseX, mouseY, headerX, headerY, headerW, headerH)
    
    if isKeyDown(0x01) and inHeader then
        if not self.state.dragging then
            self.state.dragging = true
            self.state.dragOffsetX = mouseX - self.state.menuX
        end
    else
        self.state.dragging = false
    end
    
    if self.state.dragging then
        self.state.menuX = mouseX - self.state.dragOffsetX
        self:clampMenuPosition()
    end
end
```

---

## 🎚️ Система Ползунка (Slider)

**Особенности:**

- ✅ Визуальная отрисовка трека и ручки
- ✅ Обработка кликов на трек (мгновенное перемещение)
- ✅ Обработка удержания на ручке (плавное перемещение)
- ✅ Привязка к диапазону min/max
- ✅ Callbacks при изменении значения

**Пример использования:**

```lua
local sliders = {
    {
        id = "slider_speed",
        label = "Скорость:",
        min = 1,
        max = 50,
        value = 25,
        onChanged = function(val)
            print("Скорость: " .. val)
        end
    }
}

-- Отрисовка
UIFramework:renderSlider(
    "slider_speed",           -- ID
    "Скорость:",              -- Метка
    1, 50,                    -- Min, Max
    50, 100,                  -- X, Y позиция
    200,                      -- Ширина
    mouseX, mouseY,           -- Координаты мыши
    isKeyDown(0x01) and 0x01  -- Статус кнопки мыши
)

-- Получить значение
local speed = UIFramework:getSliderValue("slider_speed")
```

---

## 📊 ESP Система

### Регистрация объектов

```lua
-- Абстрактный пример: сканирование объектов
for _, objectHandle in ipairs(getAllObjects()) do
    if getObjectModel(objectHandle) == TARGET_MODEL_ID then
        local x, y, z = getObjectCoordinates(objectHandle)
        
        ESPSystem:registerObject(
            objectHandle,      -- ID объекта
            "object",          -- Тип: "player", "object", "vehicle", "item"
            TARGET_MODEL_ID,   -- Model ID
            x, y, z,           -- 3D координаты
            "Target"           -- Текстовая метка
        )
    end
end
```

### Преобразование координат (3D → 2D)

**Основная концепция:**

```lua
-- Получаем 3D мировые координаты
local playerX, playerY, playerZ = getCharCoordinates(PLAYER_PED)
local objectX, objectY, objectZ = 123.4, 567.8, 910.1

-- Преобразуем 3D координаты в 2D экранные
local startX, startY = convert3DCoordsToScreen(playerX, playerY, playerZ)
local endX, endY = convert3DCoordsToScreen(objectX, objectY, objectZ)

-- Если обе точки видны на экране (не nil), рисуем линию
if startX and endX then
    renderDrawLine(startX, startY, endX, endY, 0xFF2196F3, 2)
end
```

**Абстрактные примеры сканирования:**

```lua
--[[ ПРИМЕР 1: Сканирование объектов ]]
for _, objectHandle in ipairs(getAllObjects()) do
    if getObjectModel(objectHandle) == 1234 then
        local x, y, z = getObjectCoordinates(objectHandle)
        -- Использование в ESP...
    end
end

--[[ ПРИМЕР 2: Сканирование игроков ]]
for _, playerId in ipairs(getAllPlayers()) do
    if playerId ~= SELECT_PLAYER_ID() then
        local ped = getCharFromPlayerHandle(playerId)
        local x, y, z = getCharCoordinates(ped)
        -- Использование в ESP...
    end
end

--[[ ПРИМЕР 3: Сканирование транспорта ]]
for _, vehicleId in ipairs(getAllVehicles()) do
    local vx, vy, vz = getVehicleCoordinates(vehicleId)
    -- Использование в ESP...
end
```

### Методы ESP

```lua
ESPSystem:initialize(fontMain, fontSmall)    -- Инициализация
ESPSystem:registerObject(id, type, modelId, x, y, z, label)  -- Добавить объект
ESPSystem:render()                           -- Отрисовать все
ESPSystem:scanWorld()                        -- Сканировать мир
ESPSystem:clearCache()                       -- Очистить кеш
ESPSystem:printStats()                       -- Статистика
```

---

## 🎨 Цветовая палитра

### Material Design Palette

```lua
-- UI Framework Colors
colors = {
    header = 0xFF2196F3,        -- Синий (заголовок)
    background = 0xFF1E1E1E,    -- Черный (фон)
    button = 0xFF424242,        -- Серый (кнопка)
    button_hover = 0xFF616161,  -- Светло-серый (наведение)
    slider_bg = 0xFF424242,     -- Серый (фон ползунка)
    slider_active = 0xFF2196F3, -- Синий (активный ползунок)
    text = 0xFFFFFFFF,          -- Белый (текст)
    text_shadow = 0xFF000000    -- Черный (тень)
}

-- ESP System Colors
esp_colors = {
    player = 0xFF4CAF50,        -- Зеленый (игроки)
    npc = 0xFF2196F3,           -- Синий (NPC)
    object = 0xFFFF9800,        -- Оранжевый (объекты)
    vehicle = 0xFF9C27B0,       -- Фиолетовый (машины)
    target = 0xFFF44336,        -- Красный (враги)
    item = 0xFFFFEB3B,          -- Желтый (предметы)
    line = 0xFF2196F3           -- Синий (линии)
}
```

---

## ⚙️ Конфигурация

### Размеры элементов

```lua
UIFramework.config = {
    menu_width = 280,          -- Ширина меню
    menu_height = 400,         -- Высота меню
    header_height = 30,        -- Высота заголовка
    button_height = 35,        -- Высота кнопки
    slider_height = 45,        -- Высота ползунка
    padding = 10               -- Внутренний отступ
}
```

### Параметры ESP

```lua
ESPSystem.config = {
    maxDistance = 500,         -- Макс расстояние (м)
    markerSize = 8,            -- Размер маркера (px)
    lineWidth = 2,             -- Толщина линии
    updateInterval = 100       -- Интервал обновления (мс)
}
```

---

## 💻 Примеры кода

### Пример 1: Создание простого меню

```lua
local buttons = {
    {
        id = "btn_start",
        label = "▶ Запустить",
        callback = function()
            sampAddChatMessage("Запущено!", 0x00FF00)
        end
    }
}

UIFramework:renderMenu(mouseX, mouseY, mouseButton, buttons, {})
```

### Пример 2: Использование ползунка

```lua
local sliders = {
    {
        id = "slider_volume",
        label = "Громкость:",
        min = 0,
        max = 100,
        value = 50
    }
}

UIFramework:renderMenu(mouseX, mouseY, mouseButton, {}, sliders)
local volume = UIFramework:getSliderValue("slider_volume")
```

### Пример 3: ESP с визуализацией

```lua
-- Получаем координаты игрока
local playerX, playerY, playerZ = getCharCoordinates(PLAYER_PED)

-- Сканируем объекты
for _, objectHandle in ipairs(getAllObjects()) do
    if getObjectModel(objectHandle) == 1234 then
        local x, y, z = getObjectCoordinates(objectHandle)
        ESPSystem:registerObject(objectHandle, "object", 1234, x, y, z, "Target")
    end
end

-- Отрисовываем
ESPSystem:render(playerX, playerY, playerZ)
```

---

## 🔧 Системные требования

- **MoonLoader** 0.26+
- **Lua** 5.1+
- **GTA: San Andreas** (SAMP)
- **Мобильное устройство** (Android/iOS)

---

## 📊 Оптимизация производительности

### Ключевые улучшения

✅ **Кеширование шрифтов** - создаются один раз при инициализации  
✅ **Структурированные данные** - упрощение управления компонентами  
✅ **Интервалы обновления** - снижение нагрузки на процессор  
✅ **Фильтрация расстояния** - отрисовка только видимых объектов  
✅ **Динамическое масштабирование** - адаптация под разные экраны  

### Рекомендации по использованию

- Используйте интервалы обновления ESP: 100-200мс
- Ограничьте максимальное расстояние: 300-500м
- Отключайте линии при 100+ объектах
- Кешируйте результаты поиска объектов

---

## 🐛 Отладка

### Включить режим отладки

```lua
-- Информация о фреймворке
UIFramework:printDebugInfo()

-- Статистика ESP
ESPSystem:printStats()

-- Получить состояние
local state = UIFramework:getState()
print("Menu:", state.menuX, state.menuY)
print("Scale:", state.scale)
```

---

## 📝 Лицензия

**MIT License** - Свободное использование и модификация

---

## 👥 Авторы

- **MoonLoader Dev** - Разработчик основного фреймворка
- **ArizonaX Team** - Интеграция и оптимизация

---

## 📞 Поддержка

Для вопросов и предложений:
- 🔗 GitHub Issues: [ArizonaX Issues](https://github.com/momoblank27/Arizona/issues)
- 💬 GitHub Discussions

---

## 🔗 Полезные ссылки

- [MoonLoader GitHub](https://github.com/qo-op/MoonLoader)
- [SAMP Documentation](https://www.sa-mp.com/)
- [Lua Documentation](https://www.lua.org/docs.html)
- [Material Design Colors](https://material.io/design/color)

---

**Made with ❤️ for ArizonaX Server**

**Last Updated:** 2026-05-25  
**Version:** 2.0.0
