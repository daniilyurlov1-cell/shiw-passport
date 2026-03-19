local RSGCore = exports['rsg-core']:GetCoreObject()

-- Функция уведомлений
function Notify(source, title, description, type, duration)
    TriggerClientEvent("bln_notify:send", source, {
        title = title or "Паспорт",
        description = description,
        icon = type or "info",
        placement = "middle-left",
        duration = duration or 3000
    })
end

-- Создание/обновление таблицы в БД
MySQL.ready(function()
    -- Создаём новую таблицу без height/weight
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS player_passports (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) UNIQUE NOT NULL,
            serial VARCHAR(20) UNIQUE NOT NULL,
            firstname VARCHAR(50) NOT NULL,
            lastname VARCHAR(50) NOT NULL,
            gender INT NOT NULL,
            eyecolor VARCHAR(20) NOT NULL,
            religion VARCHAR(50) NOT NULL,
            birthdate VARCHAR(20) DEFAULT '01.01.1860',
            city VARCHAR(50) NOT NULL,
            registration VARCHAR(50) DEFAULT NULL,
            registration_date INT DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    
    -- Если таблица уже существует со старыми колонками, добавляем birthdate
    MySQL.query("ALTER TABLE player_passports ADD COLUMN IF NOT EXISTS birthdate VARCHAR(20) DEFAULT '01.01.1860'")
    MySQL.query("ALTER TABLE player_passports ADD COLUMN IF NOT EXISTS registration VARCHAR(50) DEFAULT NULL")
    MySQL.query("ALTER TABLE player_passports ADD COLUMN IF NOT EXISTS registration_date INT DEFAULT NULL")
    
    -- Устанавливаем дефолт для height если колонка существует (для старых баз)
    MySQL.query("ALTER TABLE player_passports MODIFY COLUMN height INT DEFAULT 170")
    MySQL.query("ALTER TABLE player_passports MODIFY COLUMN weight INT DEFAULT 70")
    
    print("^2[Passport] База данных готова^7")
end)

-- Генерация уникального серийного номера
function GenerateSerial()
    local serial = "RDR-" .. math.random(1000, 9999) .. "-" .. math.random(1000, 9999)
    
    local result = MySQL.scalar.await('SELECT serial FROM player_passports WHERE serial = ?', {serial})
    
    if result then
        return GenerateSerial()
    end
    
    return serial
end

-- Генерация даты рождения
function GenerateBirthdate(charinfo)
    if charinfo and charinfo.birthdate and charinfo.birthdate ~= '' then
        return charinfo.birthdate
    end
    
    -- Генерируем случайную дату (возраст 18-55 лет от 1899)
    local birthYear = 1899 - math.random(18, 55)
    local birthMonth = math.random(1, 12)
    local birthDay = math.random(1, 28)
    
    return string.format("%02d.%02d.%d", birthDay, birthMonth, birthYear)
end

-- Проверка наличия паспорта в БД
RSGCore.Functions.CreateCallback('rsg-passport:server:hasPassport', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end

    local result = MySQL.scalar.await('SELECT id FROM player_passports WHERE citizenid = ?', {Player.PlayerData.citizenid})
    cb(result ~= nil)
end)

-- Проверка наличия предмета паспорта
RSGCore.Functions.CreateCallback('rsg-passport:server:hasPassportItem', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end

    local passportItem = Player.Functions.GetItemByName('passport')
    cb(passportItem ~= nil)
end)

-- Получение данных игрока
RSGCore.Functions.CreateCallback('rsg-passport:server:getPlayerData', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end

    cb({
        firstname = Player.PlayerData.charinfo.firstname,
        lastname = Player.PlayerData.charinfo.lastname,
        gender = Player.PlayerData.charinfo.gender,
        birthdate = Player.PlayerData.charinfo.birthdate
    })
end)

-- Проверка возможности смены прописки
RSGCore.Functions.CreateCallback('rsg-passport:server:canChangeRegistration', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(false, "Ошибка данных") end

    local result = MySQL.single.await([[
        SELECT registration, registration_date 
        FROM player_passports 
        WHERE citizenid = ?
    ]], {Player.PlayerData.citizenid})
    
    if not result then
        return cb(false, "У вас нет паспорта!")
    end
    
    if not result.registration then
        return cb(true, nil)
    end
    
    if result.registration_date then
        local now = os.time()
        local diff = now - result.registration_date
        local daysPassed = math.floor(diff / 86400)
        
        if daysPassed < Config.RegistrationCooldown then
            local daysLeft = Config.RegistrationCooldown - daysPassed
            return cb(false, "Сменить прописку можно через " .. daysLeft .. " дней")
        end
    end
    
    return cb(true, result.registration)
end)

-- Создание паспорта
RegisterNetEvent('rsg-passport:server:createPassport', function(passportData)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end

    local existingPassport = MySQL.scalar.await('SELECT id FROM player_passports WHERE citizenid = ?', {Player.PlayerData.citizenid})
    
    if existingPassport then
        Notify(src, "Ошибка", "У вас уже есть паспорт!", "error")
        return
    end
    
    local passportItem = Player.Functions.GetItemByName('passport')
    if passportItem then
        Notify(src, "Ошибка", "У вас уже есть паспорт в инвентаре!", "error")
        return
    end

    if Player.PlayerData.money.cash < Config.PassportPrice then
        Notify(src, "Ошибка", "Недостаточно денег! Нужно: $" .. Config.PassportPrice, "error")
        return
    end

    local serial = GenerateSerial()
    local birthdate = GenerateBirthdate(Player.PlayerData.charinfo)

    -- SQL БЕЗ height и weight
    local success = MySQL.insert.await([[
        INSERT INTO player_passports 
        (citizenid, serial, firstname, lastname, gender, eyecolor, religion, birthdate, city) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        Player.PlayerData.citizenid,
        serial,
        passportData.firstname,
        passportData.lastname,
        passportData.gender,
        passportData.eyecolor,
        passportData.religion,
        birthdate,
        passportData.city
    })

    if not success then
        Notify(src, "Ошибка", "Ошибка создания паспорта", "error")
        return
    end

    Player.Functions.RemoveMoney('cash', Config.PassportPrice)

    -- Дата выдачи (текущая игровая дата)
    local issueDate = os.date("%d.%m") .. ".1899 год"

    local info = {
        _serial = serial,
        _firstname = passportData.firstname,
        _lastname = passportData.lastname,
        _gender = passportData.gender,
        _eyecolor = passportData.eyecolor,
        _religion = passportData.religion,
        _birthdate = birthdate,
        _issueDate = issueDate,
        _city = passportData.city,
        _registration = nil,
        _citizenid = Player.PlayerData.citizenid
    }

    Player.Functions.AddItem('passport', 1, false, info)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['passport'], 'add')
    Notify(src, "Успех", "Паспорт успешно оформлен!", "success")
    
    print("^2[Passport] Паспорт создан для " .. Player.PlayerData.citizenid .. "^7")
end)

-- Установка прописки
RegisterNetEvent('rsg-passport:server:setRegistration', function(city)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    if Player.PlayerData.money.cash < Config.RegistrationPrice then
        Notify(src, "Ошибка", "Недостаточно денег! Нужно: $" .. Config.RegistrationPrice, "error")
        return
    end
    
    MySQL.update([[
        UPDATE player_passports 
        SET registration = ?, registration_date = ? 
        WHERE citizenid = ?
    ]], {city, os.time(), Player.PlayerData.citizenid})
    
    Player.Functions.RemoveMoney('cash', Config.RegistrationPrice)
    
    local passportItem = Player.Functions.GetItemByName('passport')
    if passportItem and passportItem.info then
        local updatedInfo = passportItem.info
        updatedInfo._registration = city
        
        Player.Functions.RemoveItem('passport', 1)
        Wait(100)
        Player.Functions.AddItem('passport', 1, false, updatedInfo)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['passport'], 'add')
    end
    
    Notify(src, "Успех", "Прописка оформлена: " .. city, "success")
    print("^2[Passport] Прописка: " .. Player.PlayerData.citizenid .. " -> " .. city .. "^7")
end)

-- Перевыпуск паспорта (при утере предмета)
RegisterNetEvent('rsg-passport:server:reissuePassport', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Проверяем что запись в БД существует
    local passport = MySQL.single.await('SELECT * FROM player_passports WHERE citizenid = ?', {Player.PlayerData.citizenid})
    if not passport then
        Notify(src, "Ошибка", "У вас нет паспорта в базе!", "error")
        return
    end
    
    -- Проверяем что предмета действительно нет
    local passportItem = Player.Functions.GetItemByName('passport')
    if passportItem then
        Notify(src, "Ошибка", "У вас уже есть паспорт!", "error")
        return
    end
    
    -- Проверяем кулдаун (3 дня после создания/перевыпуска)
    local createdAt = MySQL.scalar.await('SELECT UNIX_TIMESTAMP(created_at) FROM player_passports WHERE citizenid = ?', {Player.PlayerData.citizenid})
    if createdAt then
        local now = os.time()
        local diff = now - createdAt
        local daysPassed = math.floor(diff / 86400)
        
        if daysPassed < Config.ReissueCooldown then
            local daysLeft = Config.ReissueCooldown - daysPassed
            Notify(src, "Ошибка", "Перевыпуск доступен через " .. daysLeft .. " дн.", "error")
            return
        end
    end
    
    -- Проверяем деньги
    if Player.PlayerData.money.cash < Config.ReissuePrice then
        Notify(src, "Ошибка", "Недостаточно денег! Нужно: $" .. Config.ReissuePrice, "error")
        return
    end
    
    -- Генерируем новый серийный номер
    local newSerial = GenerateSerial()
    
    -- Обновляем серийный номер и дату в БД
    MySQL.update('UPDATE player_passports SET serial = ?, created_at = CURRENT_TIMESTAMP WHERE citizenid = ?', {newSerial, Player.PlayerData.citizenid})
    
    -- Снимаем деньги
    Player.Functions.RemoveMoney('cash', Config.ReissuePrice)
    
    -- Новая дата выдачи
    local issueDate = os.date("%d.%m") .. ".1899 год"
    
    local info = {
        _serial = newSerial,
        _firstname = passport.firstname,
        _lastname = passport.lastname,
        _gender = passport.gender,
        _eyecolor = passport.eyecolor,
        _religion = passport.religion,
        _birthdate = passport.birthdate,
        _issueDate = issueDate,
        _city = passport.city,
        _registration = passport.registration,
        _citizenid = Player.PlayerData.citizenid
    }
    
    Player.Functions.AddItem('passport', 1, false, info)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['passport'], 'add')
    Notify(src, "Успех", "Паспорт перевыпущен с новым серийным номером!", "success")
    
    print("^2[Passport] Перевыпуск паспорта: " .. Player.PlayerData.citizenid .. " | Новый серийник: " .. newSerial .. "^7")
end)

-- Показать паспорт другому игроку
RegisterNetEvent('rsg-passport:server:showPassport', function(targetId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Target = RSGCore.Functions.GetPlayer(targetId)

    if not Player or not Target then return end

    local passportItem = Player.Functions.GetItemByName('passport')
    
    if not passportItem or not passportItem.info then
        Notify(src, "Ошибка", "У вас нет паспорта!", "error")
        return
    end

    local passportData = {
        serial = passportItem.info._serial,
        firstname = passportItem.info._firstname,
        lastname = passportItem.info._lastname,
        gender = passportItem.info._gender,
        eyecolor = passportItem.info._eyecolor,
        religion = passportItem.info._religion,
        birthdate = passportItem.info._birthdate,
        issueDate = passportItem.info._issueDate or "1899 год",
        city = passportItem.info._city,
        registration = passportItem.info._registration
    }

    local showName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    TriggerClientEvent('rsg-passport:client:receivePassport', targetId, passportData, showName)
    Notify(src, "Паспорт", "Вы показали паспорт", "success")
end)

-- Использование предмета паспорт
RSGCore.Functions.CreateUseableItem('passport', function(source, item)
    local src = source
    if item.info then
        local passportData = {
            serial = item.info._serial,
            firstname = item.info._firstname,
            lastname = item.info._lastname,
            gender = item.info._gender,
            eyecolor = item.info._eyecolor,
            religion = item.info._religion,
            birthdate = item.info._birthdate,
            issueDate = item.info._issueDate or "1899 год",
            city = item.info._city,
            registration = item.info._registration
        }
        TriggerClientEvent('rsg-passport:client:openPassport', src, passportData)
    else
        Notify(src, "Ошибка", "Паспорт поврежден", "error")
    end
end)

print("^2[Passport] Server loaded^7")