script_name('Mine Tools')
script_author('Victor Strand')
script_description('special edition - MonetLoader Android')
script_version('1.1-monet')
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

local SOUND_URL  = 'https://raw.githubusercontent.com/victorstrand250-cpu/Photo-Katalog/b4d2477ff14db881184baa85def75fa6a9fa146c/faaah.mp3'
local SOUND_DIR  = getWorkingDirectory()..'/MineTools'
local SOUND_FILE = SOUND_DIR..'/ore_pickup.mp3'
local MENU_OPEN_URL  = 'https://files.catbox.moe/ejuk3l.mp3'
local MENU_OPEN_FILE = SOUND_DIR..'/menu_open.mp3'

local menuSoundPlayed = false
local menuStream      = 0
local bass            = nil
local oreStream       = 0
local oreSoundEnabled = new.bool(true)

pcall(function()
    bass = ffi.load('libbass.so')
    ffi.cdef[[
        int           BASS_Init(int device, unsigned long freq, unsigned long flags, void* win, void* clsid);
        unsigned long BASS_StreamCreateFile(int mem, const char* file, unsigned long long offset, unsigned long long length, unsigned long flags);
        unsigned long BASS_StreamCreateURL(const char* url, unsigned long offset, unsigned long flags, void* proc, void* user);
        int           BASS_ChannelPlay(unsigned long handle, int restart);
        int           BASS_ChannelStop(unsigned long handle);
        int           BASS_ChannelSetAttribute(unsigned long handle, unsigned long attrib, float value);
        int           BASS_StreamFree(unsigned long handle);
    ]]
    pcall(function() bass.BASS_Init(-1, 44100, 0, nil, nil) end)
end)

-- ============================================================================
-- ORE TYPE DETECTION
-- ============================================================================

local oreTextures = {
    ['cs_rockdetail2'] = 1,  -- Stone
    ['ab_flakeywall']  = 2,  -- Stone
    ['metalic128']     = 3,  -- Metal
    ['Strip_Gold']     = 4,  -- Gold
    ['gold128']        = 5   -- Gold
}

local oreNames = {
    [1] = u8('Камень'),      -- Stone
    [2] = u8('Камень'),      -- Stone
    [3] = u8('Металл'),      -- Metal
    [4] = u8('Золото'),      -- Gold
    [5] = u8('Золото')       -- Gold
}

-- ============================================================================
-- COLOR SYSTEM BY SPAWN TIME
-- ============================================================================

local function getOreTimerColor(spawnTime)
    local currentTime = os.time()
    local timeLeft = spawnTime - currentTime
    
    if timeLeft <= 0 then
        -- Green - already spawned
        return 0x00FF00FF
    elseif timeLeft <= 30 then
        -- Yellow - 0-30 seconds left
        return 0xFFFF00FF
    elseif timeLeft <= 75 then
        -- Dark Orange - 30-75 seconds (1:15) left
        return 0xFF8800FF
    elseif timeLeft <= 180 then
        -- Red - 75-180 seconds (1:15 - 3:00) left
        return 0xFF0000FF
    else
        -- Don't show - more than 3 minutes left
        return nil
    end
end

-- ============================================================================
-- AUDIO FUNCTIONS
-- ============================================================================

local function playMenuOpenSound()
    if not bass then return end
    lua_thread.create(function()
        pcall(function()
            if menuStream ~= 0 then
                bass.BASS_ChannelStop(menuStream)
                bass.BASS_StreamFree(menuStream)
                menuStream = 0
            end
            if doesFileExist(MENU_OPEN_FILE) then
                menuStream = bass.BASS_StreamCreateFile(0, MENU_OPEN_FILE, 0, 0, 0)
            end
            if menuStream ~= 0 then
                bass.BASS_ChannelSetAttribute(menuStream, 2, 1.0)
                bass.BASS_ChannelPlay(menuStream, 1)
            end
        end)
    end)
end

local function downloadMenuOpenSound()
    lua_thread.create(function()
        while not isSampAvailable() do wait(500) end
        wait(3000)
        if doesFileExist(MENU_OPEN_FILE) then return end
        local ok, resp = pcall(requests.get, MENU_OPEN_URL)
        if ok and resp and resp.status_code == 200 and resp.text and #resp.text > 100 then
            local f = io.open(MENU_OPEN_FILE, 'wb')
            if f then f:write(resp.text); f:close() end
        end
    end)
end

local function playOreSound()
    if not bass or not oreSoundEnabled[0] then return end
    lua_thread.create(function()
        if not doesFileExist(SOUND_FILE) then return end
        pcall(function()
            if oreStream ~= 0 then
                bass.BASS_ChannelStop(oreStream)
                bass.BASS_StreamFree(oreStream)
                oreStream = 0
            end
            oreStream = bass.BASS_StreamCreateFile(0, SOUND_FILE, 0, 0, 0)
            if oreStream ~= 0 then
                bass.BASS_ChannelSetAttribute(oreStream, 2, 0.8)
                bass.BASS_ChannelPlay(oreStream, 1)
            end
        end)
    end)
end

local function downloadOreSound()
    lua_thread.create(function()
        while not isSampAvailable() do wait(500) end
        pcall(function()
            if not doesDirectoryExist(SOUND_DIR) then
                createDirectory(SOUND_DIR)
            end
        end)
        if doesFileExist(SOUND_FILE) then return end
        local ok, resp = pcall(requests.get, SOUND_URL)
        if ok and resp and resp.status_code == 200 and resp.text and #resp.text > 100 then
            local f = io.open(SOUND_FILE, 'wb')
            if f then f:write(resp.text); f:close() end
        end
    end)
end

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local AUTHOR_TG  = 'https://t.me/victor_st0'
local CHANNEL_TG = 'https://t.me/strand_scripts'
local CAT_CFG    = 'catalog_scripts'
local CAT_FOLDER = getWorkingDirectory()..'/MineTools'
local CAT_IMAGES = CAT_FOLDER..'/images'

local CFG_FILE = 'minetools.ini'
local cfgDir   = getWorkingDirectory()..'/config'
if not doesDirectoryExist(cfgDir) then createDirectory(cfgDir) end

local settings = inicfg.load({
    main = {
        renderOre           = false,
        renderStone         = false,
        renderMetal         = false,
        renderSilver        = false,
        renderBronze        = false,
        renderGold          = false,
        showOreName         = false,
        showOreLine         = false,
        showOreDistance     = false,
        cjSkin              = false,
        autoDig             = false,
        fastRun             = false,
        teleportToMine      = false,
        antiBhop            = false,
        wallHack            = false,
        statisticsWindow    = false,
        statisticsStone     = false,
        statisticsMetal     = false,
        statisticsSilver    = false,
        statisticsBronze    = false,
        statisticsGold      = false,
        totalPrice          = false,
        oreTimer            = false,
        oreTimerDistance    = false,
        oreTimerLine        = false,
        selectedPage        = 2,
        renderRadius        = 100,
        renderSize          = 21,
        renderOreTimerSize  = 21,
        statisticsPosX      = 300,
        statisticsPosY      = 300,
        priceStone          = 20000,
        priceMetal          = 45000,
        priceSilver         = 25000,
        priceBronze         = 70000,
        priceGold           = 50000,
        countStone          = 0,
        countMetal          = 0,
        countSilver         = 0,
        countBronze         = 0,
        countGold           = 0,
        commandOpenMenu     = 'mt',
        defoltSkin          = 0,
        oreSoundEnabled     = true,
        subscribed          = false,
    },
}, CFG_FILE)

inicfg.load(settings, CFG_FILE)
if not doesFileExist(getWorkingDirectory()..'/config/'..CFG_FILE) then
    inicfg.save(settings, CFG_FILE)
end

local prefix = '{696969}[{DCDCDC}MineTools{696969}]{696969}: '
local str    = ffi.string

-- ============================================================================
-- UI VARIABLES
-- ============================================================================

local renderOre        = new.bool(settings.main.renderOre)
local renderStone      = new.bool(settings.main.renderStone)
local renderMetal      = new.bool(settings.main.renderMetal)
local renderSilver     = new.bool(settings.main.renderSilver)
local renderBronze     = new.bool(settings.main.renderBronze)
local renderGold       = new.bool(settings.main.renderGold)
local showOreName      = new.bool(settings.main.showOreName)
local showOreLine      = new.bool(settings.main.showOreLine)
local showOreDistance  = new.bool(settings.main.showOreDistance)
local oreTimer         = new.bool(settings.main.oreTimer)
local oreTimerDistance = new.bool(settings.main.oreTimerDistance)
local oreTimerLine     = new.bool(settings.main.oreTimerLine)
local renderRadius     = new.int(settings.main.renderRadius)
local renderSize       = new.int(settings.main.renderSize)
local renderOreTimerSize = new.int(settings.main.renderOreTimerSize)

local mainWindow      = new.bool(false)
local render          = new.bool(true)
local font            = {}
local oreTimerList    = {}
local oreObjCache     = {}
local oreColorCache   = {}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

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

local function cachedColor(argb)
    if not oreColorCache[argb] then
        local aa = bit.band(bit.rshift(argb,24),0xFF)/255
        local rr = bit.band(bit.rshift(argb,16),0xFF)/255
        local gg = bit.band(bit.rshift(argb, 8),0xFF)/255
        local bb = bit.band(argb,0xFF)/255
        oreColorCache[argb] = imgui.GetColorU32Vec4(imgui.ImVec4(aa,rr,gg,bb))
    end
    return oreColorCache[argb]
end

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
    
    minetools_theme()
end)

function minetools_theme()
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
        
        imgui.Begin(u8('Mine Tools'), mainWindow, flags)
        
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
            local titleText = u8('Шахта  |  Mine Tools')
            local titleCalc = imgui.CalcTextSize(titleText)
            imgui.SetCursorPosX(tw2 / 2 - titleCalc.x / 2)
            imgui.TextColored(imgui.ImVec4(1.0,0.90,0.70,1.0), titleText)
            if font[18] then imgui.PopFont() end
        imgui.EndChild()
        
        local contentH = winH - titleH - 16*MDS
        imgui.BeginChild('##content', imgui.ImVec2(-1, contentH), false)
        
        imgui.Spacing()
        
        if imgui.Checkbox(u8('Поиск руды'), renderOre) then
            settings.main.renderOre = renderOre[0]; inicfg.save(settings, CFG_FILE)
        end
        
        imgui.Separator()
        
        local bW = (winW - 32*MDS) * 0.5
        
        if imgui.Checkbox(u8('Показывать название'), showOreName) then
            settings.main.showOreName = showOreName[0]; inicfg.save(settings, CFG_FILE)
        end
        
        if imgui.Checkbox(u8('Показывать линию'), showOreLine) then
            settings.main.showOreLine = showOreLine[0]; inicfg.save(settings, CFG_FILE)
        end
        
        if imgui.Checkbox(u8('Показывать дистанцию'), showOreDistance) then
            settings.main.showOreDistance = showOreDistance[0]; inicfg.save(settings, CFG_FILE)
        end
        
        imgui.Spacing()
        imgui.PushItemWidth(bW)
        if imgui.SliderInt(u8('Радиус поиска'), renderRadius, 1, 600) then
            settings.main.renderRadius = renderRadius[0]; inicfg.save(settings, CFG_FILE)
        end
        if imgui.SliderInt(u8('Размер шрифта'), renderSize, 10, 27) then
            settings.main.renderSize = renderSize[0]; inicfg.save(settings, CFG_FILE)
        end
        imgui.PopItemWidth()
        
        imgui.Separator()
        
        if imgui.Checkbox(u8('Таймер руды'), oreTimer) then
            settings.main.oreTimer = oreTimer[0]; inicfg.save(settings, CFG_FILE)
        end
        
        if imgui.Checkbox(u8('Показ. дистанцию до руды'), oreTimerDistance) then
            settings.main.oreTimerDistance = oreTimerDistance[0]; inicfg.save(settings, CFG_FILE)
        end
        
        if imgui.Checkbox(u8('Показ. линию до таймера'), oreTimerLine) then
            settings.main.oreTimerLine = oreTimerLine[0]; inicfg.save(settings, CFG_FILE)
        end
        
        imgui.PushItemWidth(bW)
        if imgui.SliderInt(u8('Размер таймера'), renderOreTimerSize, 10, 27) then
            settings.main.renderOreTimerSize = renderOreTimerSize[0]; inicfg.save(settings, CFG_FILE)
        end
        imgui.PopItemWidth()
        
        imgui.Spacing()
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
        
        if oreTimer[0] then
            local ok0, mx, my, mz = pcall(getCharCoordinates, PLAYER_PED)
            if ok0 and mx then
                local cx, cy = convert3DCoordsToScreen(mx, my, mz)
                for k = #oreTimerList, 1, -1 do
                    local v    = oreTimerList[k]
                    local diff = v[5] - os.time()
                    
                    if diff < -30 then
                        table.remove(oreTimerList, k)
                    else
                        local color = getOreTimerColor(v[5])
                        
                        if color then
                            local ok_s, tx, ty = pcall(convert3DCoordsToScreen, v[1], v[2], v[3])
                            if ok_s and tx and ty then
                                local dist    = math.floor(safeDist3d(v[1],v[2],v[3],mx,my,mz))
                                
                                if dist <= renderRadius[0] and isPointOnScreen(v[1], v[2], v[3], 0) then
                                    local col = cachedColor(color)
                                    
                                    if oreTimerLine[0] then
                                        DL:AddLine(imgui.ImVec2(tx,ty), imgui.ImVec2(cx,cy), u32c(0,0,0,0.35), 3.5*MDS)
                                        DL:AddLine(imgui.ImVec2(tx,ty), imgui.ImVec2(cx,cy), col, 1.8*MDS)
                                    end
                                    
                                    local oreName = oreNames[v[4]] or u8('Руда')
                                    local text = oreName
                                    if oreTimerDistance[0] then 
                                        text = text..' ['..math.floor(dist)..']' 
                                    end
                                    
                                    local timeLeft = v[5] - os.time()
                                    if timeLeft <= 0 then
                                        text = text..' [OK]'
                                    else
                                        text = text..' ['..os.date('%M:%S', timeLeft)..']'
                                    end
                                    
                                    local fnt = font[renderOreTimerSize[0]]
                                    local fsz = renderOreTimerSize[0] * MDS
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

function sampev.onSetObjectMaterial(id, data)
    local ok, object = pcall(sampGetObjectHandleBySampId, id)
    if not ok or not object then return end
    local ok2, model = pcall(getObjectModel, object)
    if not ok2 then return end
    
    if doesObjectExist(object) and model == 3930 then
        if oreTextures[data.textureName] then
            local ok_c, ox, oy, oz = pcall(getObjectCoordinates, object)
            local x = ok_c and tonumber(ox) or nil
            local y = ok_c and tonumber(oy) or nil
            local z = ok_c and tonumber(oz) or nil
            if not (x and y and z) then return end
            
            -- Store ore data with spawn time (375 seconds = 6:15)
            table.insert(oreTimerList, {x, y, z, oreTextures[data.textureName], os.time() + 375})
        end
    end
end

function sampev.onDestroyObject(id)
    -- Cleanup if needed
end

function sampev.onSendSpawn()
    -- Handle spawn if needed
end

-- ============================================================================
-- MAIN
-- ============================================================================

function main()
    while not isSampAvailable() do wait(100) end
    while not sampIsLocalPlayerSpawned() do wait(200) end
    
    downloadOreSound()
    downloadMenuOpenSound()
    
    sampRegisterChatCommand(settings.main.commandOpenMenu, function()
        mainWindow[0] = not mainWindow[0]
        if mainWindow[0] and not menuSoundPlayed then
            menuSoundPlayed = true
            playMenuOpenSound()
        end
    end)
    
    sampRegisterChatCommand('mtore', function()
        renderOre[0] = not renderOre[0]
        settings.main.renderOre = renderOre[0]
        inicfg.save(settings, CFG_FILE)
        sampAddChatMessage(prefix..('\xd0\xf3\xe4\xe0: '..(renderOre[0] and '{00FF00}\xc2\xca\xcb' or '{FF4444}\xc2\xdb\xca\xcb')), -1)
    end)
    
    sampRegisterChatCommand('mttimer', function()
        oreTimer[0] = not oreTimer[0]
        settings.main.oreTimer = oreTimer[0]
        inicfg.save(settings, CFG_FILE)
        sampAddChatMessage(prefix..('\xd2\xe0\xe9\xec\xe5\xf0: '..(oreTimer[0] and '{00FF00}\xc2\xca\xcb' or '{FF4444}\xc2\xdb\xca\xcb')), -1)
    end)
    
    sampAddChatMessage('{FF8C00}> {FFCC00}Mine Tools {FF8C00}| {FFFFFF}\xc0\xe2\xf2\xee\xf0: {FFD700}Victor Strand', -1)
    sampAddChatMessage('{FF8C00}> {AAAAAA}\xcc\xe5\xed\xfe: {FFFFFF}/'..settings.main.commandOpenMenu..'{AAAAAA} | \xd0\xf3\xe4\xe0: {FFFFFF}/mtore{AAAAAA} | \xd2\xe0\xe9\xec\xe5\xf0: {FFFFFF}/mttimer', -1)
    sampAddChatMessage('{FF8C00}> {00CC66}\xd8\xe0\xf5\xf2\xe5\xf0\xf1\xea\xe8\xe9 \xea\xe0\xf0\xfc\xe5\xf0 \xed\xe0\xf7\xe8\xed\xe0\xe5\xf2\xf1\xff. \xd3\xe4\xe0\xf7\xe8!', -1)
    
    while true do
        wait(0)
    end
end
