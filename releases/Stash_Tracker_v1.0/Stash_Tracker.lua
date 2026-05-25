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

-- Основные переменные
local stashData = {}
local lastUpdate = 0
local updateInterval = 5000

local function initStashTracker()
    sampAddChatMessage('[Stash Tracker] Модуль инициализирован', -1)
end

function sampev.onCreate3DText(id, color, position, dist, testLOS, player, vehicle, text)
    if text and text:match('Stash') then
        stashData[id] = {
            position = position,
            color = color,
            time = os.time(),
            active = true
        }
    end
end

function sampev.onRemove3DText(id)
    if stashData[id] then
        stashData[id].active = false
    end
end

function main()
    initStashTracker()
    
    while true do
        wait(100)
        
        local currentTime = os.time()
        for id, data in pairs(stashData) do
            if data.active then
                local spawnTime = currentTime - data.time
                if spawnTime > 900 then -- 15 минут
                    data.active = false
                end
            end
        end
    end
end

sampev.onCreate3DText(0, -1, {x=0, y=0, z=0}, 50, false, false, false, 'Stash')
