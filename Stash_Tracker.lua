script_name('Stash Tracker')
script_author('Victor Strand')
script_description('Stash Spawn Timer & ESP System - MonetLoader Android')
script_version('1.0-monet')
script_properties('work-in-pause')

require('lib.samp.events')

local imgui   = require('mimgui')
local ffi     = require('ffi')
local enc     = require('encoding')
enc.default   = 'CP1251'
local u8      = enc.UTF8
local inicfg  = require('inicfg')
local jsoncfg = require('jsoncfg')
local requests= require('requests')
local lfs     = require('lfs')
local sampev  = require('lib.samp.events')
local mem     = require('memory')

local MDS = MONET_DPI_SCALE
local new = imgui.new

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local CFG_FILE = 'stashtracker.ini'
local cfgDir   = getWorkingDirectory()..'/config'
if not doesDirectoryExist(cfgDir) then createDirectory(cfgDir) end

local settings = inicfg.load({
    main = {
        renderStashes      = true,
        showStashLine      = true,
        showStashDistance  = true,
        statisticsWindow   = false,
        stashTimerSize     = 21,
        renderRadius       = 300,
        commandOpenMenu    = 'stash',
        colorNotSpawned    = 0x0000FFFF,  -- Blue
        colorSpawned       = 0x00FF00FF,  -- Green
    },
}, CFG_FILE)

inicfg.load(settings, CFG_FILE)
if not doesFileExist(getWorkingDirectory()..'/config/'..CFG_FILE) then
    inicfg.save(settings, CFG_FILE)
end

-- ============================================================================
-- COLOR SYSTEM - SIMPLE (NO TIME LIMITS)
-- ============================================================================

local function getStashColor(spawnTime)
    local currentTime = os.time()
    local timeLeft = spawnTime - currentTime
    
    if timeLeft <= 0 then
        -- Green - already spawned
        return settings.main.colorSpawned  -- 0x00FF00FF
    else
        -- Blue - not spawned yet (NO LIMIT)
        return settings.main.colorNotSpawned  -- 0x0000FFFF
    end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local prefix = '{696969}[{DCDCDC}StashTracker{696969}]{696969}: '

local function u32c(r,g,b,a)
    a = a or 1.0
    return bit.bor(
        bit.lshift(math.min(255,math.floor(a*255+.5)),24),
        bit.lshift(math.min(255,math.floor(b*255+.5)),16),
        bit.lshift(math.min(255,math.floor(g*255+.5)), 8),
                   math.min(255,math.floor(r*255+.5)))
end

local function safeNum(v)
    return tonumber(v) or 0
end

local function safeDist3d(x1,y1,z1,x2,y2,z2)
    x1=tonumber(x1) or 0; y1=tonumber(y1) or 0; z1=tonumber(z1) or 0
    x2=tonumber(x2) or 0; y2=tonumber(y2) or 0; z2=tonumber(z2) or 0
    local dx,dy,dz = x1-x2, y1-y2, z1-z2
    return math.sqrt(dx*dx+dy*dy+dz*dz)
end

local function openLink(url)
    pcall(function()
        local gta = ffi.load('GTASA')
        pcall(ffi.cdef, [[ void _Z12AND_OpenLinkPKc(const char* link); ]])
        gta._Z12AND_OpenLinkPKc(url)
    end)
end

local function cachedColor(argb, cache)
    if not cache[argb] then
        local aa = bit.band(bit.rshift(argb,24),0xFF)/255
        local rr = bit.band(bit.rshift(argb,16),0xFF)/255
        local gg = bit.band(bit.rshift(argb, 8),0xFF)/255
        local bb = bit.band(argb,0xFF)/255
        cache[argb] = imgui.GetColorU32Vec4(imgui.ImVec4(aa,rr,gg,bb))
    end
    return cache[argb]
end

-- ============================================================================
-- UI VARIABLES
-- ============================================================================

local mainWindow = new.bool(false)
local render = new.bool(true)
local renderStashes = new.bool(settings.main.renderStashes)
local showStashLine = new.bool(settings.main.showStashLine)
local showStashDistance = new.bool(settings.main.showStashDistance)
local statisticsWindow = new.bool(settings.main.statisticsWindow)
local renderRadius = new.int(settings.main.renderRadius)
local stashTimerSize = new.int(settings.main.stashTimerSize)
local commandOpenMenu = new.char[256](u8(settings.main.commandOpenMenu))

local font = {}
local stashTimerList = {}
local stashColorCache = {}

-- ============================================================================
-- IMGUI INITIALIZATION
-- ============================================================================

imgui.OnInitialize(function()
    imgui.SwitchContext()
    local io = imgui.GetIO()
    io.IniFilename = nil
    imgui.GetStyle():ScaleAllSizes(MDS)
    
    local ranges = io.Fonts:GetGlyphRangesCyrillic()
    local ttf    = getWorkingDirectory()..'/lib/mimgui/trebucbd.ttf'
    if not doesFileExist(ttf) then
        ttf = getWorkingDirectory()..'/../trebucbd.ttf'
    end
    io.Fonts:AddFontFromFileTTF(ttf, 14*MDS, nil, ranges)
    for size = 10, 27 do
        font[size] = io.Fonts:AddFontFromFileTTF(ttf, size*MDS, nil, ranges)
    end
    
    stash_theme()
end)

function stash_theme()
    local s   = imgui.GetStyle()
    local c   = s.Colors
    local C   = imgui.Col
    local IV4 = imgui.ImVec4
    local IV2 = imgui.ImVec2
    
    s.WindowTitleAlign  = IV2(0.5, 0.5)
    s.ButtonTextAlign   = IV2(0.5, 0.5)
    s.WindowPadding     = IV2(8*MDS,  8*MDS)
    s.FramePadding      = IV2(6*MDS,  5*MDS)
    s.ItemSpacing       = IV2(7*MDS,  6*MDS)
    s.ItemInnerSpacing  = IV2(4*MDS,  4*MDS)
    s.TouchExtraPadding = IV2(4*MDS,  4*MDS)
    s.IndentSpacing     = 14*MDS
    s.WindowBorderSize  = 1
    s.ChildBorderSize   = 1
    s.PopupBorderSize   = 1
    s.FrameBorderSize   = 0
    s.TabBorderSize     = 0
    s.ScrollbarSize     = 8*MDS
    s.GrabMinSize       = 10*MDS
    s.WindowRounding    = 6*MDS
    s.ChildRounding     = 4*MDS
    s.FrameRounding     = 4*MDS
    s.PopupRounding     = 5*MDS
    s.ScrollbarRounding = 4*MDS
    s.GrabRounding      = 3*MDS
    s.TabRounding       = 4*MDS
    
    c[C.Text]                = IV4(0.92, 0.88, 0.76, 1.00)
    c[C.TextDisabled]        = IV4(0.48, 0.44, 0.36, 1.00)
    c[C.WindowBg]            = IV4(0.07, 0.06, 0.04, 0.98)
    c[C.ChildBg]             = IV4(0.10, 0.09, 0.06, 0.95)
    c[C.PopupBg]             = IV4(0.09, 0.08, 0.05, 0.98)
    c[C.Border]              = IV4(0.45, 0.32, 0.12, 0.70)
    c[C.BorderShadow]        = IV4(0.00, 0.00, 0.00, 0.30)
    c[C.FrameBg]             = IV4(0.14, 0.12, 0.08, 1.00)
    c[C.FrameBgHovered]      = IV4(0.20, 0.17, 0.10, 1.00)
    c[C.FrameBgActive]       = IV4(0.26, 0.21, 0.11, 1.00)
    c[C.TitleBg]             = IV4(0.08, 0.07, 0.04, 1.00)
    c[C.TitleBgActive]       = IV4(0.52, 0.20, 0.05, 1.00)
    c[C.TitleBgCollapsed]    = IV4(0.07, 0.06, 0.04, 1.00)
    c[C.MenuBarBg]           = IV4(0.10, 0.09, 0.06, 1.00)
    c[C.ScrollbarBg]         = IV4(0.07, 0.06, 0.04, 1.00)
    c[C.ScrollbarGrab]       = IV4(0.38, 0.28, 0.12, 1.00)
    c[C.ScrollbarGrabHovered]= IV4(0.52, 0.38, 0.16, 1.00)
    c[C.ScrollbarGrabActive] = IV4(0.64, 0.26, 0.07, 1.00)
    c[C.CheckMark]           = IV4(0.88, 0.68, 0.18, 1.00)
    c[C.SliderGrab]          = IV4(0.60, 0.44, 0.14, 1.00)
    c[C.SliderGrabActive]    = IV4(0.78, 0.30, 0.07, 1.00)
    c[C.Button]              = IV4(0.20, 0.16, 0.09, 1.00)
    c[C.ButtonHovered]       = IV4(0.52, 0.22, 0.06, 0.95)
    c[C.ButtonActive]        = IV4(0.68, 0.17, 0.04, 1.00)
    c[C.Header]              = IV4(0.32, 0.18, 0.06, 0.85)
    c[C.HeaderHovered]       = IV4(0.50, 0.24, 0.07, 0.95)
    c[C.HeaderActive]        = IV4(0.62, 0.20, 0.05, 1.00)
    c[C.Tab]                 = IV4(0.12, 0.10, 0.06, 1.00)
    c[C.TabHovered]          = IV4(0.48, 0.21, 0.06, 1.00)
    c[C.TabActive]           = IV4(0.58, 0.23, 0.06, 1.00)
    c[C.Separator]           = IV4(0.38, 0.28, 0.10, 0.75)
    c[C.SeparatorHovered]    = IV4(0.58, 0.30, 0.08, 1.00)
    c[C.SeparatorActive]     = IV4(0.70, 0.24, 0.06, 1.00)
    c[C.ResizeGrip]          = IV4(0.42, 0.30, 0.10, 0.50)
    c[C.ResizeGripHovered]   = IV4(0.60, 0.38, 0.12, 0.80)
    c[C.ResizeGripActive]    = IV4(0.75, 0.28, 0.07, 1.00)
    c[C.PlotLines]           = IV4(0.85, 0.65, 0.20, 1.00)
    c[C.PlotHistogram]       = IV4(0.80, 0.50, 0.10, 1.00)
    c[C.TextSelectedBg]      = IV4(0.55, 0.22, 0.07, 0.45)
    c[C.NavHighlight]        = IV4(0.75, 0.55, 0.15, 1.00)
end

-- ============================================================================
-- IMGUI FRAMES
-- ============================================================================

imgui.OnFrame(
    function() return mainWindow[0] end,
    function(self)
        self.HideCursor = false
        local sw, sh = getScreenResolution()
        local winW = math.min(sw * 0.68, 640 * MDS)
        local winH = sh * 0.68
        
        imgui.SetNextWindowPos(imgui.ImVec2(sw*0.5, sh*0.5), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(winW, winH), imgui.Cond.Always)
        
        local flags = imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize
                    + imgui.WindowFlags.NoTitleBar  + imgui.WindowFlags.NoScrollbar
                    + imgui.WindowFlags.NoScrollWithMouse
        
        imgui.Begin(u8('Stash Tracker'), mainWindow, flags)
        
        local titleH = 40 * MDS
        imgui.BeginChild('##title', imgui.ImVec2(-1, titleH), false)
            local DLt = imgui.GetWindowDrawList()
            local tp2 = imgui.GetWindowPos()
            local tw2 = imgui.GetWindowWidth()
            DLt:AddRectFilledMultiColor(
                imgui.ImVec2(tp2.x, tp2.y),
                imgui.ImVec2(tp2.x+tw2, tp2.y+titleH),
                u32c(0.58,0.22,0.06,1), u32c(0.30,0.10,0.03,1),
                u32c(0.30,0.10,0.03,1), u32c(0.58,0.22,0.06,1))
            DLt:AddLine(
                imgui.ImVec2(tp2.x, tp2.y+titleH-1),
                imgui.ImVec2(tp2.x+tw2, tp2.y+titleH-1),
                u32c(0.88,0.68,0.18,1), 1.5*MDS)
            if font[18] then imgui.PushFont(font[18]) end
            imgui.SetCursorPosY((titleH - imgui.GetTextLineHeight()) * 0.5)
            local titleText = u8('Тайники  |  Stash Tracker')
            local titleCalc = imgui.CalcTextSize(titleText)
            imgui.SetCursorPosX(tw2 / 2 - titleCalc.x / 2)
            imgui.TextColored(imgui.ImVec4(1.0,0.90,0.70,1.0), titleText)
            if font[18] then imgui.PopFont() end
        imgui.EndChild()
        
        local contentH = winH - titleH - 16*MDS
        imgui.BeginChild('##content', imgui.ImVec2(-1, contentH), false)
        
        imgui.Spacing()
        
        if imgui.Checkbox(u8('Отображение тайников'), renderStashes) then
            settings.main.renderStashes = renderStashes[0]; inicfg.save(settings, CFG_FILE)
        end
        
        imgui.Separator()
        
        local bW = (winW - 32*MDS) * 0.5
        
        if imgui.Checkbox(u8('Показывать линию'), showStashLine) then
            settings.main.showStashLine = showStashLine[0]; inicfg.save(settings, CFG_FILE)
        end
        
        if imgui.Checkbox(u8('Показывать дистанцию'), showStashDistance) then
            settings.main.showStashDistance = showStashDistance[0]; inicfg.save(settings, CFG_FILE)
        end
        
        imgui.Spacing()
        imgui.PushItemWidth(bW)
        if imgui.SliderInt(u8('Радиус отображения'), renderRadius, 1, 600) then
            settings.main.renderRadius = renderRadius[0]; inicfg.save(settings, CFG_FILE)
        end
        if imgui.SliderInt(u8('Размер шрифта таймера'), stashTimerSize, 10, 27) then
            settings.main.stashTimerSize = stashTimerSize[0]; inicfg.save(settings, CFG_FILE)
        end
        imgui.PopItemWidth()
        
        imgui.Separator()
        imgui.Spacing()
        
        if font[14] then imgui.PushFont(font[14]) end
        imgui.TextColored(imgui.ImVec4(0.88,0.68,0.18,1), u8('Автор: Victor Strand'))
        if font[14] then imgui.PopFont() end
        
        imgui.EndChild()
        imgui.End()
    end
)

imgui.OnFrame(
    function() return render[0] end,
    function(self)
        self.HideCursor = true
        local DL = imgui.GetBackgroundDrawList()
        
        if renderStashes[0] then
            local ok_p, mx, my, mz = pcall(getCharCoordinates, PLAYER_PED)
            if ok_p and mx then
                local cx, cy  = convert3DCoordsToScreen(mx, my, mz)
                local radius  = renderRadius[0]
                
                for k = #stashTimerList, 1, -1 do
                    local v    = stashTimerList[k]
                    local diff = v[4] - os.time()
                    
                    -- NO TIME LIMIT - Keep showing indefinitely
                    if diff < -86400 then
                        -- Remove if more than 24 hours past spawn (safety)
                        table.remove(stashTimerList, k)
                    else
                        local color = getStashColor(v[4])
                        
                        if color then
                            local ok_s, tx, ty = pcall(convert3DCoordsToScreen, v[1], v[2], v[3])
                            if ok_s and tx and ty then
                                local dist    = math.floor(safeDist3d(v[1],v[2],v[3],mx,my,mz))
                                
                                if dist <= radius and isPointOnScreen(v[1], v[2], v[3], 0) then
                                    local col = cachedColor(color, stashColorCache)
                                    
                                    if showStashLine[0] then
                                        DL:AddLine(imgui.ImVec2(tx,ty), imgui.ImVec2(cx,cy), u32c(0,0,0,0.35), 3.5*MDS)
                                        DL:AddLine(imgui.ImVec2(tx,ty), imgui.ImVec2(cx,cy), col, 1.8*MDS)
                                    end
                                    
                                    local text = u8('Тайник')
                                    if showStashDistance[0] then 
                                        text = text..' ['..math.floor(dist)..']' 
                                    end
                                    
                                    local timeLeft = v[4] - os.time()
                                    if timeLeft <= 0 then
                                        text = text..' [СПАВН]'
                                    else
                                        text = text..' ['..os.date('%M:%S', timeLeft)..']'
                                    end
                                    
                                    local fnt = font[stashTimerSize[0]]
                                    local fsz = stashTimerSize[0] * MDS
                                    local tsz = imgui.CalcTextSize(text)
                                    local tx2 = tx - tsz.x*.5
                                    local ty2 = ty - fsz - 2*MDS
                                    
                                    if fnt then
                                        DL:AddTextFontPtr(fnt, fsz, imgui.ImVec2(tx2+1,ty2+1), u32c(0,0,0,0.7), text)
                                        DL:AddTextFontPtr(fnt, fsz, imgui.ImVec2(tx2,ty2), col, text)
                                    else
                                        DL:AddText(imgui.ImVec2(tx2+1,ty2+1), u32c(0,0,0,0.7), text)
                                        DL:AddText(imgui.ImVec2(tx2,ty2), col, text)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
)

-- ============================================================================
-- SAMP EVENTS
-- ============================================================================

function sampev.onCreate3DText(id, color, position, dist, testLOS, player, vehicle, text)
    -- Detect stash spawn text
    if text:find('Тайник') or text:find('Stash') then
        local px = tonumber(type(position)=='table' and position.x or nil)
        local py = tonumber(type(position)=='table' and position.y or nil)
        local pz = tonumber(type(position)=='table' and position.z or nil)
        if px and py and pz then
            -- Add to stash list with spawn time (375 seconds)
            table.insert(stashTimerList, {px, py, pz, os.time() + 375})
        end
    end
end

function sampev.onRemove3DTextLabel(id)
    -- Cleanup if needed
end

-- ============================================================================
-- MAIN
-- ============================================================================

function main()
    while not isSampAvailable() do wait(100) end
    while not sampIsLocalPlayerSpawned() do wait(200) end
    
    sampRegisterChatCommand(settings.main.commandOpenMenu, function()
        mainWindow[0] = not mainWindow[0]
    end)
    
    sampAddChatMessage('{FF8C00}> {FFCC00}Stash Tracker {FF8C00}| {FFFFFF}\xc0\xe2\xf2\xee\xf0: {FFD700}Victor Strand', -1)
    sampAddChatMessage('{FF8C00}> {AAAAAA}\xcc\xe5\xed\xfe: {FFFFFF}/'..settings.main.commandOpenMenu, -1)
    sampAddChatMessage('{FF8C00}> {00CC66}\xd2\xf0\xe0\xea\xe5\xf0 \xf2\xe0\xe9\xed\xe8\xea\xee\xe2 \xca\xe0\xf8\xf2\xeb\xfc\xe1\xe0! \xd3\xe4\xe0\xf7\xe8!', -1)
    
    while true do
        wait(0)
    end
end
