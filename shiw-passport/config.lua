Config = {}

Config.PassportPrice = 0
Config.ReissuePrice = 100
Config.ReissueCooldown = 3 -- дней после создания/перевыпуска
Config.RegistrationPrice = 50
Config.RegistrationCooldown = 60 -- дней
Config.ShowDistance = 3.0

Config.Religions = {
    "Христианство",
    "Католицизм",
    "Протестантизм",
    "Язычество",
    "Атеизм",
    "Иудаизм",
    "Мармон"
}

Config.EyeColors = {
    "Карие",
    "Голубые",
    "Зеленые",
    "Серые",
    "Черные",
    "Янтарные"
}

Config.PassportLocations = {
    {
        name = "Valentine",
        displayName = "Валентайн",
        coords = vec4(-175.25, 631.82, 114.14, 327.54),
        npcModel = `amsp_robsdgunsmith_males_01`,
        blip = true
    },
    {
        name = "SaintDenis",
        displayName = "Сан-Дени",
        coords = vec4(2520.32, -1190.20, 53.66, 177.95),
        npcModel = `amsp_robsdgunsmith_males_01`,
        blip = true
    },
    {
        name = "Blackwater",
        displayName = "Блеквотер",
        coords = vec4(-805.19, -1199.29, 44.14, 279.09),
        npcModel = `amsp_robsdgunsmith_males_01`,
        blip = true
    },
    {
        name = "Rhodes",
        displayName = "Роудс",
        coords = vec4(1292.94, -1304.56, 77.09, 312.93),
        npcModel = `amsp_robsdgunsmith_males_01`,
        blip = true
    },
    {
        name = "Armadillo",
        displayName = "Армадилло",
        coords = vec4(-3729.28, -2601.39, -12.89, 176.44),
        npcModel = `amsp_robsdgunsmith_males_01`,
        blip = true
    }
}