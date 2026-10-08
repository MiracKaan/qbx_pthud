Config = {}

-- ==========================================
-- GENEL AYARLAR
-- ==========================================
Config.EnableStress = true              -- Stres göstergesi açık/kapalı
Config.BleedingHealthThreshold = 170   -- Bu can değerinin altında kanama başlar
Config.CrashSpeedThreshold = 15.0      -- Kaza sayılan minimum hız (km/h)

-- ==========================================
-- STRES AYARLARI
-- ==========================================
Config.Stress = {
    chance = 0.1,                       -- Ateş ederken stres kazanma şansı (0.1 = %10)
    minForShaking = 50,                 -- Ekranda titreme/blur için minimum stres seviyesi
    minSpeedForStress = 160,            -- Kemer takılıyken stres başlangıç hızı (km/h)
    minSpeedForStressUnbuckled = 80,    -- Kemer TAKILI DEĞİLKEN stres başlangıç hızı (km/h)
    whitelistedWeapons = {              -- Stres VERMEYEN silahlar
        `weapon_petrolcan`,
        `weapon_hazardcan`,
        `weapon_fireextinguisher`,
    }
}

-- ==========================================
-- İYİLEŞME EVENTLERİ (bunlar gelince kanama/kırık temizlenir)
-- ==========================================
Config.HealingEvents = {
    "hospital:client:Revive",
    "hospital:client:HealInjuries",
    "hospital:client:TreatWounds",
    "esx_ambulancejob:revive",
    "QBCore:Client:OnPlayerLoaded"
}

-- ==========================================
-- NİTRO AYARLARI
-- ==========================================
Config.Nitro = {
    RequirePurge = true,    -- Nitro kullanmadan önce purge şarj edilmeli mi?

    -- ------------------------------------------------------------
    -- NİTRO TAKILAMAYAN ARAÇLAR
    -- ------------------------------------------------------------
    BlockElectric = true,   -- Elektrikli araçlara nitro takılamaz (true/false)

    -- Araç SINIFI (GetVehicleClass) ile engelle. Eklemek/çıkarmak için satırı yaz/sil.
    -- 0 Compacts, 1 Sedans, 2 SUV, 3 Coupes, 4 Muscle, 5 Sports Classics, 6 Sports, 7 Super,
    -- 8 Motorcycles, 9 Off-road, 10 Industrial, 11 Utility, 12 Vans, 13 Cycles, 14 Boats,
    -- 15 Helicopters, 16 Planes, 17 Service, 18 Emergency, 19 Military, 20 Commercial, 21 Trains
    BlockedClasses = {
        [8]  = true,        -- Motosiklet
        [13] = true,        -- Bisiklet
        -- [14] = true,     -- Tekne (istersen # kaldır)
    },

    -- Araç MODELİ (spawn adı) ile engelle. Eklemek/çıkarmak için satırı yaz/sil.
    BlockedModels = {
        -- 'adder',
    },

    -- Elektrikli sayılacak modeller (otomatik algılama kaçırırsa buraya ekle)
    ElectricModels = {
        'voltic', 'voltic2', 'raiden', 'cyclone', 'cyclone2', 'tezeract',
        'neon', 'imorgon', 'iwagen', 'omnisegt', 'khamelion', 'surge',
        'dilettante', 'caddy3', 'airtug', 'rcbandito',
    },

    -- Elektrikli olsa bile nitro takılabilsin istediklerin (istisna listesi)
    AllowedModels = {
        -- 'raiden',
    },

    BlockedMessage = "Bu araca nitro takılamaz!",
}
