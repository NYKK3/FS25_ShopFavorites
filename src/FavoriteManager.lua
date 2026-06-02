--
-- FS25 - ShopFavorites
--
-- @Author: NYKK3
-- @Version: 1.6.0.0
--
-- Gestore dei preferiti per il negozio
-- Supporto multiplayer con preferiti per utente (salvati localmente)
-- Supporto salvataggio configurazioni (colore, motore, ruote, ecc.)
-- Supporto ordinamento per frequenza di utilizzo (openCount)

-- Helper function per contare elementi in una tabella
local function tableCount(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

FavoriteManager = {}
FavoriteManager.dir = g_currentModDirectory
FavoriteManager.modName = g_currentModName

-- Costanti per il salvataggio (stile FHSettingsRepository)
FavoriteManager.FILENAME = "FS25_ShopFavorites.xml"
FavoriteManager.BASE_KEY = "FS25_ShopFavorites"

-- Carica i file GUI
source(FavoriteManager.dir .. "src/gui/MenuFavoritesList.lua")

function FavoriteManager:loadMap()
    -- Controllo che g_shopMenu sia disponibile prima di procedere
    if g_shopMenu == nil then
        ShopFavoritesDebug.log("Error - g_shopMenu is nil during loadMap")
        return
    end
    
    -- Inizializza la struttura per utente
    self.usersFavorites = {}
    self.usersInactiveFavorites = {} -- Preferiti di mod rimosse
    self.currentUserId = nil
    self.dataLoaded = false -- Flag per verificare se i dati sono stati caricati
    
    -- Crea il frame dei preferiti
    self.favoritesPage = MenuFavoritesList.new()
    g_gui:loadGui(FavoriteManager.dir .. "src/gui/MenuFavoritesList.xml", "menuShopFavorites", self.favoritesPage, false)
    self.favoritesPage:initialize()

    -- Aggiunge la pagina al menu del negozio (dopo pageShopBrands)
    FavoriteManager.addShopPage(self.favoritesPage, "menuShopFavorites", { 0, 0, 1024, 1024 },
        FavoriteManager:makeIsFavoritesMenuCheckEnabledPredicate(), "pageShopBrands")

    -- Registra il gestore dei preferiti nel gioco
    if g_currentMission ~= nil then
        g_currentMission.FavoriteManager = self
    end

    -- Ottieni l'ID utente corrente
    self:updateCurrentUserId()
    
    -- Carica i preferiti salvati (ORA DAL MOD SETTINGS DIRECTORY)
    self:loadFromXMLFile()
end

-- Funzione helper per ottenere il percorso del file XML
-- Simile a FHSettingsRepository.getXmlFilePath
function FavoriteManager.getXmlFilePath()
    if g_modSettingsDirectory then
        return ("%s%s"):format(g_modSettingsDirectory, FavoriteManager.FILENAME)
    else
        -- Fallback nel caso raro in cui g_modSettingsDirectory non sia disponibile
        Logging.warning("ShopFavorites: Could not retrieve mod settings directory, using fallback.")
        return getUserProfileAppPath() .. FavoriteManager.FILENAME
    end
end

-- Ottiene l'ID utente corrente usando uniqueUserId
function FavoriteManager:updateCurrentUserId()
    -- Usa sempre uniqueUserId del player locale
    if g_localPlayer ~= nil and g_localPlayer.uniqueUserId ~= nil then
        self.currentUserId = g_localPlayer.uniqueUserId
    elseif g_currentMission.playerSystem ~= nil then
        local player = g_currentMission.playerSystem:getLocalPlayer()
        if player ~= nil and player.uniqueUserId ~= nil then
            self.currentUserId = player.uniqueUserId
        end
    end
    
    -- Fallback finale
    if self.currentUserId == nil then
        -- Prova con userManager
        if g_currentMission.userManager ~= nil then
            local users = g_currentMission.userManager:getUsers()
            if users ~= nil and #users > 0 then
                self.currentUserId = users[1].uniqueUserId
            end
        end
        
        if self.currentUserId == nil then
            self.currentUserId = "SinglePlayer"
        end
    end
end

function FavoriteManager:makeIsFavoritesMenuCheckEnabledPredicate()
    return function() return true end
end

-- Funzione per aggiungere una pagina al menu del negozio
function FavoriteManager.addShopPage(frame, pageName, uvs, predicateFunc, insertAfter)
    -- (Codice invariato per brevità, mantenere la versione originale)
    if g_shopMenu == nil then
        ShopFavoritesDebug.log("Error - g_shopMenu is nil")
        return false
    end

    local targetPosition = 0
    for k, v in pairs({ pageName }) do
        if g_shopMenu.controlIDs ~= nil then g_shopMenu.controlIDs[v] = nil end
    end

    if insertAfter ~= nil and g_shopMenu.pagingElement ~= nil and g_shopMenu.pagingElement.elements ~= nil then
        for i = 1, #g_shopMenu.pagingElement.elements do
            local child = g_shopMenu.pagingElement.elements[i]
            if child == g_shopMenu[insertAfter] then targetPosition = i + 1 break end
        end
    else
        targetPosition = (g_shopMenu.pagingElement.elements and #g_shopMenu.pagingElement.elements or 0) + 1
    end

    g_shopMenu[pageName] = frame
    if g_shopMenu.pagingElement ~= nil then g_shopMenu.pagingElement:addElement(g_shopMenu[pageName]) end
    if g_shopMenu.exposeControlsAsFields ~= nil then g_shopMenu:exposeControlsAsFields(pageName) end

    if g_shopMenu.pagingElement ~= nil and g_shopMenu.pagingElement.elements ~= nil then
        for i = 1, #g_shopMenu.pagingElement.elements do
            local child = g_shopMenu.pagingElement.elements[i]
            if child == g_shopMenu[pageName] then
                table.remove(g_shopMenu.pagingElement.elements, i)
                table.insert(g_shopMenu.pagingElement.elements, targetPosition, child)
                break
            end
        end
    end

    if g_shopMenu.pagingElement ~= nil and g_shopMenu.pagingElement.pages ~= nil then
        for i = 1, #g_shopMenu.pagingElement.pages do
            local child = g_shopMenu.pagingElement.pages[i]
            if child.element == g_shopMenu[pageName] then
                table.remove(g_shopMenu.pagingElement.pages, i)
                table.insert(g_shopMenu.pagingElement.pages, targetPosition, child)
                break
            end
        end
    end

    if g_shopMenu.pagingElement ~= nil then
        if g_shopMenu.pagingElement.updateAbsolutePosition ~= nil then g_shopMenu.pagingElement:updateAbsolutePosition() end
        if g_shopMenu.pagingElement.updatePageMapping ~= nil then g_shopMenu.pagingElement:updatePageMapping() end
    end

    if g_shopMenu.registerPage ~= nil then g_shopMenu:registerPage(g_shopMenu[pageName], nil, predicateFunc) end

    local iconFileName = Utils.getFilename('images/menuIcon.dds', FavoriteManager.dir)
    if g_shopMenu.addPageTab ~= nil then
        g_shopMenu:addPageTab(g_shopMenu[pageName], iconFileName, GuiUtils.getUVs(uvs))
    end

    if g_shopMenu.pageFrames ~= nil then
        for i = 1, #g_shopMenu.pageFrames do
            local child = g_shopMenu.pageFrames[i]
            if child == g_shopMenu[pageName] then
                table.remove(g_shopMenu.pageFrames, i)
                table.insert(g_shopMenu.pageFrames, targetPosition, child)
                break
            end
        end
    end

    if g_shopMenu.rebuildTabList ~= nil then g_shopMenu:rebuildTabList() end
    return true
end

-- Ottiene la lista dei preferiti per l'utente corrente
function FavoriteManager:getFavorites()
    self:updateCurrentUserId()
    if self.usersFavorites[self.currentUserId] == nil then
        self.usersFavorites[self.currentUserId] = {}
    end
    return self.usersFavorites[self.currentUserId]
end

-- Aggiunge un preferito dallo storeItem
function FavoriteManager:addFavoriteFromStoreItem(storeItem, configurations)
    if storeItem == nil then return false end
    local xmlFilename = storeItem.xmlFilename
    if xmlFilename == nil or xmlFilename == "" then return false end

    self:updateCurrentUserId()
    if self:isFavoriteByXml(xmlFilename) then return false end

    local name = storeItem.name or "Unknown Item"
    local category = storeItem.categoryName or "unknown"
    local brand = ""
    if storeItem.brand ~= nil and storeItem.brand.title ~= nil then brand = storeItem.brand.title end

    if self.usersFavorites[self.currentUserId] == nil then
        self.usersFavorites[self.currentUserId] = {}
    end

    local favorite = {
        xmlFilename = xmlFilename,
        name = name,
        category = category,
        brand = brand,
        configurations = {},
        openCount = 0
    }
    
    if configurations ~= nil then
        for configName, configIndex in pairs(configurations) do
            favorite.configurations[configName] = configIndex
        end
    end

    table.insert(self.usersFavorites[self.currentUserId], favorite)
    self:saveToXMLFile()
    return true
end

-- Aggiunge un preferito da un veicolo esistente
function FavoriteManager:addFavorite(vehicle)
    if vehicle == nil then return false end
    local xmlFilename = vehicle.xmlFilename
    if xmlFilename == nil or xmlFilename == "" then return false end

    if self:isFavoriteByXml(xmlFilename) then return false end
    self:updateCurrentUserId()
    
    if self.usersFavorites[self.currentUserId] == nil then
        self.usersFavorites[self.currentUserId] = {}
    end

    local favorite = {
        xmlFilename = xmlFilename,
        name = vehicle:name(),
        category = "owned",
        brand = "",
        configurations = {},
        openCount = 0
    }
    
    if vehicle.configurations ~= nil then
        for configName, configIndex in pairs(vehicle.configurations) do
            favorite.configurations[configName] = configIndex
        end
    end
    
    table.insert(self.usersFavorites[self.currentUserId], favorite)
    self:saveToXMLFile()
    return true
end

-- Verifica se un veicolo è nei preferiti
function FavoriteManager:isFavoriteByXml(xmlFilename)
    if xmlFilename == nil then return false end
    local favorites = self:getFavorites()
    for _, favorite in ipairs(favorites) do
        if favorite.xmlFilename == xmlFilename then return true end
    end
    return false
end

function FavoriteManager:isFavorite(uniqueId) return false end -- Deprecato

-- Rimuove un preferito
function FavoriteManager:removeFavoriteByXml(xmlFilename)
    self:updateCurrentUserId()
    if self.usersFavorites[self.currentUserId] == nil then return false end
    
    for i, favorite in ipairs(self.usersFavorites[self.currentUserId]) do
        if favorite.xmlFilename == xmlFilename then
            table.remove(self.usersFavorites[self.currentUserId], i)
            self:saveToXMLFile()
            return true
        end
    end
    return false
end

function FavoriteManager:removeFavorite(uniqueId) return false end -- Deprecato

-- Helper per verificare esistenza storeItem
function FavoriteManager:storeItemExists(xmlFilename)
    if xmlFilename == nil or g_storeManager == nil then return false end
    local items = g_storeManager:getItems()
    for _, item in ipairs(items) do
        if item.xmlFilename == xmlFilename then return true end
    end
    return false
end

function FavoriteManager:getStoreItemForFavorite(favorite)
    if favorite == nil or favorite.xmlFilename == nil then return nil end
    if g_storeManager ~= nil then
        local items = g_storeManager:getItems()
        for _, item in ipairs(items) do
            if item.xmlFilename == favorite.xmlFilename then return item end
        end
    end
    return nil
end

function FavoriteManager:getFavoriteByXml(xmlFilename)
    local favorites = self:getFavorites()
    for _, favorite in ipairs(favorites) do
        if favorite.xmlFilename == xmlFilename then return favorite end
    end
    return nil
end

function FavoriteManager:incrementOpenCount(xmlFilename)
    self:updateCurrentUserId()
    if self.usersFavorites[self.currentUserId] == nil then return false end
    for _, favorite in ipairs(self.usersFavorites[self.currentUserId]) do
        if favorite.xmlFilename == xmlFilename then
            favorite.openCount = (favorite.openCount or 0) + 1
            self:saveToXMLFile()
            return true
        end
    end
    return false
end

function FavoriteManager:getFavoritesSortedByUsage()
    local favorites = self:getFavorites()
    local sortedFavorites = {}
    for _, favorite in ipairs(favorites) do table.insert(sortedFavorites, favorite) end
    table.sort(sortedFavorites, function(a, b) return (a.openCount or 0) > (b.openCount or 0) end)
    return sortedFavorites
end

-- Helper function per salvare una lista di preferiti (Invariato)
local function saveFavoritesList(xmlFile, userKey, favorites)
    local favIndex = 0
    for i, favorite in ipairs(favorites) do
        local favKey = string.format("%s.favorite(%d)", userKey, favIndex)
        setXMLString(xmlFile, favKey .. "#xmlFilename", favorite.xmlFilename or "")
        setXMLString(xmlFile, favKey .. "#name", favorite.name or "")
        setXMLString(xmlFile, favKey .. "#category", favorite.category or "")
        setXMLString(xmlFile, favKey .. "#brand", favorite.brand or "")
        setXMLInt(xmlFile, favKey .. "#openCount", favorite.openCount or 0)
        
        if favorite.configurations ~= nil then
            local configIndex = 0
            for configName, configValue in pairs(favorite.configurations) do
                local configKey = string.format("%s.configuration(%d)", favKey, configIndex)
                setXMLString(xmlFile, configKey .. "#name", configName or "")
                setXMLInt(xmlFile, configKey .. "#index", configValue or 1)
                configIndex = configIndex + 1
            end
        end
        favIndex = favIndex + 1
    end
end

-- NUOVO SISTEMA DI SALVATAGGIO (Basato su FHSettingsRepository)
function FavoriteManager:saveToXMLFile()
    -- RIMOSSO il check "if (not g_currentMission:getIsServer())".
    -- Ora salviamo sempre localmente per il client corrente.
    
    if not self.dataLoaded then
        -- Evita salvataggi corrotti prima del caricamento iniziale
        return 
    end

    local xmlFilePath = FavoriteManager.getXmlFilePath()
    
    -- Crea un file XML vuoto usando la BASE_KEY come root
    local xmlFile = createXMLFile("favorites", xmlFilePath, FavoriteManager.BASE_KEY)
    if xmlFile == nil or xmlFile == 0 then
        Logging.error("ShopFavorites: Failed to create XML file at %s", xmlFilePath)
        return
    end

    -- Salva i preferiti attivi per ogni utente
    local userIndex = 0
    for userId, favorites in pairs(self.usersFavorites) do
        local userKey = string.format("%s.user(%d)", FavoriteManager.BASE_KEY, userIndex)
        setXMLString(xmlFile, userKey .. "#uniqueId", userId or "")
        saveFavoritesList(xmlFile, userKey, favorites)
        userIndex = userIndex + 1
    end
    
    -- Salva i preferiti inattivi (mod rimosse)
    local inactiveUserIndex = 0
    for userId, inactiveFavorites in pairs(self.usersInactiveFavorites) do
        local userKey = string.format("%s.inactiveUser(%d)", FavoriteManager.BASE_KEY, inactiveUserIndex)
        setXMLString(xmlFile, userKey .. "#uniqueId", userId or "")
        saveFavoritesList(xmlFile, userKey, inactiveFavorites)
        inactiveUserIndex = inactiveUserIndex + 1
    end

    saveXMLFile(xmlFile)
    delete(xmlFile)
end

-- Helper function per caricare una lista di preferiti (Invariato)
local function loadFavoritesList(xmlFile, userKey)
    local favorites = {}
    local favIndex = 0
    while true do
        local favKey = string.format("%s.favorite(%d)", userKey, favIndex)
        if not hasXMLProperty(xmlFile, favKey) then break end
        
        local favorite = {
            xmlFilename = getXMLString(xmlFile, favKey .. "#xmlFilename"),
            name = getXMLString(xmlFile, favKey .. "#name"),
            category = getXMLString(xmlFile, favKey .. "#category"),
            brand = getXMLString(xmlFile, favKey .. "#brand"),
            configurations = {},
            openCount = getXMLInt(xmlFile, favKey .. "#openCount") or 0
        }
        
        local configIndex = 0
        while true do
            local configKey = string.format("%s.configuration(%d)", favKey, configIndex)
            if not hasXMLProperty(xmlFile, configKey) then break end
            local configName = getXMLString(xmlFile, configKey .. "#name")
            local configValue = getXMLInt(xmlFile, configKey .. "#index")
            if configName ~= nil and configValue ~= nil then
                favorite.configurations[configName] = configValue
            end
            configIndex = configIndex + 1
        end
        table.insert(favorites, favorite)
        favIndex = favIndex + 1
    end
    return favorites
end

-- NUOVO SISTEMA DI CARICAMENTO (Basato su FHSettingsRepository)
function FavoriteManager:loadFromXMLFile()
    local xmlFilePath = FavoriteManager.getXmlFilePath()
    
    -- Inizializza le tabelle vuote di default
    self.usersFavorites = {}
    self.usersInactiveFavorites = {}

    if not fileExists(xmlFilePath) then
        ShopFavoritesDebug.log("No saved favorites found (First run or clean install).")
        self.dataLoaded = true
        return
    end

    local xmlFile = loadXMLFile("favorites", xmlFilePath)
    if xmlFile == nil or xmlFile == 0 then
        Logging.warning("ShopFavorites: Failed to load XML file despite existing.")
        self.dataLoaded = true
        return
    end

    -- Carica preferiti attivi
    local userIndex = 0
    while true do
        local userKey = string.format("%s.user(%d)", FavoriteManager.BASE_KEY, userIndex)
        if not hasXMLProperty(xmlFile, userKey) then break end
        
        local uniqueId = getXMLString(xmlFile, userKey .. "#uniqueId")
        if uniqueId ~= nil and uniqueId ~= "" then
            local loadedFavorites = loadFavoritesList(xmlFile, userKey)
            self.usersFavorites[uniqueId] = {}
            self.usersInactiveFavorites[uniqueId] = {} -- Init anche qui
            
            for _, favorite in ipairs(loadedFavorites) do
                if self:storeItemExists(favorite.xmlFilename) then
                    table.insert(self.usersFavorites[uniqueId], favorite)
                else
                    table.insert(self.usersInactiveFavorites[uniqueId], favorite)
                end
            end
        end
        userIndex = userIndex + 1
    end
    
    -- Carica preferiti inattivi
    local inactiveUserIndex = 0
    while true do
        local userKey = string.format("%s.inactiveUser(%d)", FavoriteManager.BASE_KEY, inactiveUserIndex)
        if not hasXMLProperty(xmlFile, userKey) then break end
        
        local uniqueId = getXMLString(xmlFile, userKey .. "#uniqueId")
        if uniqueId ~= nil and uniqueId ~= "" then
            if self.usersInactiveFavorites[uniqueId] == nil then
                self.usersInactiveFavorites[uniqueId] = {}
            end
            
            local loadedInactive = loadFavoritesList(xmlFile, userKey)
            
            for _, favorite in ipairs(loadedInactive) do
                if self:storeItemExists(favorite.xmlFilename) then
                    -- La mod è tornata disponibile
                    if self.usersFavorites[uniqueId] == nil then self.usersFavorites[uniqueId] = {} end
                    table.insert(self.usersFavorites[uniqueId], favorite)
                else
                    table.insert(self.usersInactiveFavorites[uniqueId], favorite)
                end
            end
        end
        inactiveUserIndex = inactiveUserIndex + 1
    end

    delete(xmlFile)
    self.dataLoaded = true
    ShopFavoritesDebug.log("Favorites loaded successfully from ModSettings.")
end

-- Hook per il salvataggio
-- Nota: Con g_modSettingsDirectory, non è strettamente necessario agganciarsi al salvataggio partita,
-- ma lo manteniamo per comodità come "auto-save" quando si salva la partita.
FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, FavoriteManager.saveToXMLFile)

addModEventListener(FavoriteManager)
