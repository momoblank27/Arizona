script_name('Mine Tools')
script_author('Victor Strand')
script_description('special edition - MonetLoader Android')
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

-- Инициализация
downloadOreSound()
downloadMenuOpenSound()
