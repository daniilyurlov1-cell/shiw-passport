local RSGCore = exports['rsg-core']:GetCoreObject()
local spawnedNPCs = {}
local PassportPrompt = nil
local RegistrationPrompt = nil

-- Функция уведомлений
function Notify(title, description, type, duration)
    TriggerEvent("bln_notify:send", {
        title = title or "Паспорт",
        description = description,
        icon = type or "info",
        placement = "middle-left",
        duration = duration or 3000
    })
end

-- Закрытие NUI
function CloseNUI()
    SetNuiFocus(false, false)
    SendNUIMessage({action = 'hide'})
end

-- Открытие собственного паспорта
RegisterNetEvent('rsg-passport:client:openPassport', function(passportData)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "setResourceName",
        name = GetCurrentResourceName()
    })
    SendNUIMessage({
        action = "openPassport",
        data = passportData,
        own = true
    })
end)

-- Получение паспорта от другого игрока
RegisterNetEvent('rsg-passport:client:receivePassport', function(passportData, showName)
    Notify("Паспорт", showName .. " показывает вам паспорт", "info", 3000)
    
    Wait(300)
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "setResourceName",
        name = GetCurrentResourceName()
    })
    SendNUIMessage({
        action = "openPassport",
        data = passportData,
        own = false,
        showName = showName
    })
end)

-- NUI Callbacks
RegisterNUICallback('closePassport', function(data, cb)
    cb({ok = true})
    SetNuiFocus(false, false)
end)

-- NUI Callback для создания паспорта
RegisterNUICallback('createPassportWithParams', function(data, cb)
    print("^2[Passport] Создание паспорта...^7")
    cb({ok = true})
    SetNuiFocus(false, false)
    
    CreateThread(function()
        Wait(100)
        
        local passportData = {
            firstname = data.firstname,
            lastname = data.lastname,
            gender = data.gender,
            religion = data.religion,
            eyecolor = data.eyecolor,
            city = data.city
        }
        
        TriggerServerEvent('rsg-passport:server:createPassport', passportData)
    end)
end)

RegisterNUICallback('cancelPassportCreation', function(data, cb)
    cb({ok = true})
    SetNuiFocus(false, false)
end)

-- ==========================================
-- OX_TARGET: Показать паспорт игроку
-- ==========================================
CreateThread(function()
    Wait(2000)
    
    -- Добавляем опцию на всех игроков
    exports.ox_target:addGlobalPlayer({
        {
            name = 'passport_show_to_player',
            icon = 'fas fa-id-card',
            label = 'Показать паспорт',
            distance = Config.ShowDistance,
            onSelect = function(data)
                if data.entity then
                    local targetServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
                    if targetServerId and targetServerId > 0 then
                        -- Проверяем есть ли паспорт
                        RSGCore.Functions.TriggerCallback('rsg-passport:server:hasPassportItem', function(hasPass)
                            if hasPass then
                                TriggerServerEvent('rsg-passport:server:showPassport', targetServerId)
                            else
                                Notify("Ошибка", "У вас нет паспорта!", "error")
                            end
                        end)
                    end
                end
            end
        }
    })
    
    print("^2[Passport] ox_target опция добавлена^7")
end)

-- Создание NPC при загрузке ресурса
CreateThread(function()
    Wait(1000)
    
    for _, location in pairs(Config.PassportLocations) do
        print("^3[Passport] Создание NPC: " .. location.displayName .. "^7")
        
        if location.blip then
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, location.coords.x, location.coords.y, location.coords.z)
            SetBlipSprite(blip, `blip_proc_home`, true)
            SetBlipScale(blip, 0.2)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, "Паспортный стол")
        end

        local modelHash = location.npcModel
        RequestModel(modelHash)
        
        local timeout = 0
        while not HasModelLoaded(modelHash) and timeout < 100 do
            Wait(100)
            timeout = timeout + 1
        end

        if not HasModelLoaded(modelHash) then
            print("^1[Passport] Ошибка модели: " .. location.displayName .. "^7")
            goto continue
        end

        local npc = CreatePed(modelHash, location.coords.x, location.coords.y, location.coords.z - 1.0, location.coords.w, false, false, false, false)
        
        Wait(100)
        
        if not DoesEntityExist(npc) then
            print("^1[Passport] NPC не создан: " .. location.displayName .. "^7")
            goto continue
        end

        Citizen.InvokeNative(0x283978A15512B2FE, npc, true)
        SetEntityCanBeDamaged(npc, false)
        SetEntityInvincible(npc, true)
        FreezeEntityPosition(npc, true)
        SetBlockingOfNonTemporaryEvents(npc, true)
        Citizen.InvokeNative(0x9587913B9E772D29, npc, true)
        SetPedFleeAttributes(npc, 0, false)
        SetPedCombatAttributes(npc, 17, true)
        
        SetEntityAsMissionEntity(npc, true, true)
        SetModelAsNoLongerNeeded(modelHash)

        print("^2[Passport] NPC создан: " .. location.displayName .. "^7")

        table.insert(spawnedNPCs, {
            npc = npc,
            location = location
        })

        ::continue::
    end
    
    print("^3[Passport] Всего NPC: " .. #spawnedNPCs .. "^7")
end)

-- Создание промптов
CreateThread(function()
    Wait(2000)
    
    local str = CreateVarString(10, 'LITERAL_STRING', 'Оформить паспорт')
    PassportPrompt = PromptRegisterBegin()
    PromptSetControlAction(PassportPrompt, 0xF3830D8E)
    PromptSetText(PassportPrompt, str)
    PromptSetEnabled(PassportPrompt, false)
    PromptSetVisible(PassportPrompt, false)
    PromptSetHoldMode(PassportPrompt, true)
    PromptRegisterEnd(PassportPrompt)
    
    local str2 = CreateVarString(10, 'LITERAL_STRING', 'Оформить прописку ($' .. Config.RegistrationPrice .. ')')
    RegistrationPrompt = PromptRegisterBegin()
    PromptSetControlAction(RegistrationPrompt, 0x8CC9CD42)
    PromptSetText(RegistrationPrompt, str2)
    PromptSetEnabled(RegistrationPrompt, false)
    PromptSetVisible(RegistrationPrompt, false)
    PromptSetHoldMode(RegistrationPrompt, true)
    PromptRegisterEnd(RegistrationPrompt)
    
    print("^2[Passport] Промпты созданы^7")
end)

-- Основной цикл взаимодействия с NPC
CreateThread(function()
    Wait(3000)
    
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local nearNPC = false
        local currentLocation = nil

        for _, data in pairs(spawnedNPCs) do
            if DoesEntityExist(data.npc) then
                local npcCoords = GetEntityCoords(data.npc)
                local distance = #(playerCoords - npcCoords)
                
                if distance < 3.0 then
                    sleep = 0
                    nearNPC = true
                    currentLocation = data.location
                    break
                end
            end
        end

        if nearNPC then
            if PassportPrompt then
                PromptSetEnabled(PassportPrompt, true)
                PromptSetVisible(PassportPrompt, true)
                
                if PromptHasHoldModeCompleted(PassportPrompt) then
                    OpenPassportMenu(currentLocation)
                    Wait(500)
                end
            end
            
            if RegistrationPrompt then
                PromptSetEnabled(RegistrationPrompt, true)
                PromptSetVisible(RegistrationPrompt, true)
                
                if PromptHasHoldModeCompleted(RegistrationPrompt) then
                    OpenRegistrationMenu(currentLocation)
                    Wait(500)
                end
            end
        else
            if PassportPrompt then
                PromptSetEnabled(PassportPrompt, false)
                PromptSetVisible(PassportPrompt, false)
            end
            if RegistrationPrompt then
                PromptSetEnabled(RegistrationPrompt, false)
                PromptSetVisible(RegistrationPrompt, false)
            end
        end

        Wait(sleep)
    end
end)

-- Открытие меню паспорта
function OpenPassportMenu(location)
    RSGCore.Functions.TriggerCallback('rsg-passport:server:hasPassport', function(hasPass)
        if hasPass then
            -- Паспорт есть в БД — проверяем есть ли предмет
            RSGCore.Functions.TriggerCallback('rsg-passport:server:hasPassportItem', function(hasItem)
                if hasItem then
                    Notify("Ошибка", "У вас уже есть паспорт!", "error")
                else
                    -- Предмет утерян — предлагаем перевыпуск
                    Notify("Паспорт", "Перевыпуск паспорта за $" .. Config.ReissuePrice .. "...", "info")
                    TriggerServerEvent('rsg-passport:server:reissuePassport')
                end
            end)
            return
        end

        RSGCore.Functions.TriggerCallback('rsg-passport:server:getPlayerData', function(playerData)
            if not playerData then
                Notify("Ошибка", "Ошибка получения данных", "error")
                return
            end

            SetNuiFocus(true, true)
            SendNUIMessage({
                action = "setResourceName",
                name = GetCurrentResourceName()
            })
            SendNUIMessage({
                action = "openPassportCreation",
                playerData = playerData,
                city = location.displayName,
                religions = Config.Religions,
                eyecolors = Config.EyeColors,
                price = Config.PassportPrice
            })
        end)
    end)
end

-- Открытие меню прописки
function OpenRegistrationMenu(location)
    RSGCore.Functions.TriggerCallback('rsg-passport:server:hasPassportItem', function(hasPass)
        if not hasPass then
            Notify("Ошибка", "Сначала оформите паспорт!", "error")
            return
        end
        
        RSGCore.Functions.TriggerCallback('rsg-passport:server:canChangeRegistration', function(canChange, reason)
            if not canChange then
                Notify("Ошибка", reason, "error")
                return
            end
            
            if reason then
                Notify("Информация", "Текущая прописка: " .. reason, "info")
                Wait(2000)
            end
            
            Notify("Прописка", "Оформление в " .. location.displayName .. " за $" .. Config.RegistrationPrice, "info")
            TriggerServerEvent('rsg-passport:server:setRegistration', location.displayName)
        end)
    end)
end

-- Команда закрытия NUI
RegisterCommand('closenui', function()
    CloseNUI()
end, false)

-- Очистка при выгрузке
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        CloseNUI()
        exports.ox_target:removeGlobalPlayer('passport_show_to_player')
        
        for _, data in pairs(spawnedNPCs) do
            if DoesEntityExist(data.npc) then
                DeletePed(data.npc)
            end
        end
    end
end)