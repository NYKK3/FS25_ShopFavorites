--
-- FS25 - ShopFavorites
--
-- Frame della lista dei preferiti per il menu del negozio
-- Supporto per applicare le configurazioni salvate

-- Helper function per contare elementi in una tabella
local function tableCount(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

MenuFavoritesList = {}
MenuFavoritesList._mt = Class(MenuFavoritesList, TabbedMenuFrameElement)

function MenuFavoritesList.new()
    local self = MenuFavoritesList:superClass().new(nil, MenuFavoritesList._mt)
    self.name = "menuShopFavorites"

    self.dataBindings = {}
    self.itemCache = {}
    self.currentFavorites = {}
    self.selectedIndex = -1

    self.btnBack = {
        inputAction = InputAction.MENU_BACK
    }
    self.btnPreviousPage = {
        text = g_i18n:getText("ui_ingameMenuPrev"),
        inputAction = InputAction.MENU_PAGE_PREV,
        callback = function()
            self:onPreviousPage()
        end
    }
    self.btnNextPage = {
        text = g_i18n:getText("ui_ingameMenuNext"),
        inputAction = InputAction.MENU_PAGE_NEXT,
        callback = function()
            self:onNextPage()
        end
    }
    self.btnBuyFavorite = {
        text = g_i18n:getText("button_buy"),
        inputAction = InputAction.MENU_ACCEPT,
        callback = function()
            self:onBuyFavorite()
        end
    }
    self.btnRemoveFavorite = {
        text = g_i18n:getText("sf_btn_remove"),
        inputAction = InputAction.MENU_CANCEL,
        callback = function()
            self:removeFavorite()
        end
    }
    self:setMenuButtonInfo({
        self.btnBack,
        self.btnNextPage,
        self.btnPreviousPage,
        self.btnBuyFavorite,
        self.btnRemoveFavorite
    })

    return self
end

function MenuFavoritesList:delete()
    MenuFavoritesList:superClass().delete(self)
end

function MenuFavoritesList:copyAttributes(src)
    MenuFavoritesList:superClass().copyAttributes(self, src)
    self.i18n = src.i18n
end

function MenuFavoritesList:onGuiSetupFinished()
    MenuFavoritesList:superClass().onGuiSetupFinished(self)
    
    if self.categoryList ~= nil then
        self.categoryList:setDataSource(self)
        self.categoryList:setDelegate(self)
    end
end

function MenuFavoritesList:initialize()
    if self.categoryHeaderText ~= nil then
        self.categoryHeaderText:setText(g_i18n:getText("sf_header_favorites"))
    end
end

function MenuFavoritesList:onFrameOpen()
    MenuFavoritesList:superClass().onFrameOpen(self)
    self:setMenuButtonInfoDirty()
    self:updateContent()
end

function MenuFavoritesList:onFrameClose()
    -- Controllo null per evitare errori se l'elemento non è stato inizializzato
    if self ~= nil then
        MenuFavoritesList:superClass().onFrameClose(self)
    end
end

function MenuFavoritesList:updateContent()
    self.currentFavorites = {}
    
    -- Recupera i preferiti ordinati per frequenza di utilizzo
    if g_currentMission ~= nil and g_currentMission.FavoriteManager ~= nil then
        local favorites = g_currentMission.FavoriteManager:getFavoritesSortedByUsage()
        for _, favorite in ipairs(favorites) do
            table.insert(self.currentFavorites, favorite)
        end
    end

    -- Verifica se ci sono preferiti
    if #self.currentFavorites == 0 then
        if self.noItemsText ~= nil then
            self.noItemsText:setVisible(true)
        end
    else
        if self.noItemsText ~= nil then
            self.noItemsText:setVisible(false)
        end
    end

    -- Ricarica i dati della lista
    if self.categoryList ~= nil then
        self.categoryList:reloadData()
    end
end

function MenuFavoritesList:getNumberOfSections()
    return 1
end

function MenuFavoritesList:getNumberOfItemsInSection(list, section)
    return #self.currentFavorites
end

function MenuFavoritesList:getTitleForSectionHeader(list, section)
    return ""
end

function MenuFavoritesList:getCellTypeForItemInSection(list, section, index)
    return "category"
end

function MenuFavoritesList:populateCellForItemInSection(list, section, index, cell)
    local favorite = self.currentFavorites[index]
    
    if favorite == nil then
        return
    end

    -- Cerca lo store item per l'immagine e il nome localizzato
    local storeItem = nil
    if favorite.xmlFilename ~= nil and g_storeManager ~= nil then
        for _, item in pairs(g_storeManager.items) do
            if item ~= nil and item.xmlFilename == favorite.xmlFilename then
                storeItem = item
                break
            end
        end
    end

    -- Imposta l'icona
    local iconElement = cell:getAttribute("icon")
    if iconElement ~= nil then
        if storeItem ~= nil and storeItem.imageFilename ~= nil then
            iconElement:setImageFilename(storeItem.imageFilename)
        end
    end

    -- Imposta il nome del veicolo (Brand + Nome)
    local titleElement = cell:getAttribute("title")
    if titleElement ~= nil then
        local displayName = ""
        
        if storeItem ~= nil then
            -- Ottieni il brand
            local brandTitle = ""
            if storeItem.brandIndex ~= nil then
                local brand = g_brandManager:getBrandByIndex(storeItem.brandIndex)
                if brand ~= nil and brand.name ~= "NONE" then
                    brandTitle = brand.title .. " "
                end
            end
            
            -- Combina brand + nome
            displayName = brandTitle .. (storeItem.name or g_i18n:getText("sf_unknown_vehicle"))
        else
            -- Fallback se lo storeItem non è disponibile
            displayName = favorite.name or g_i18n:getText("sf_unknown_vehicle")
        end
        
        titleElement:setText(displayName)
    end

    -- Imposta la categoria (localizzata)
    local categoryElement = cell:getAttribute("category")
    if categoryElement ~= nil then
        local displayCategory = ""
        
        if storeItem ~= nil and storeItem.categoryName ~= nil then
            -- Cerca la categoria in g_shopMenu.pageShopVehicles.categories per ottenere il label localizzato
            if g_shopMenu ~= nil and g_shopMenu.pageShopVehicles ~= nil and g_shopMenu.pageShopVehicles.categories ~= nil then
                for _, categoryList in pairs(g_shopMenu.pageShopVehicles.categories) do
                    for _, category in pairs(categoryList) do
                        if category.id == storeItem.categoryName or category.name == storeItem.categoryName then
                            displayCategory = category.label or storeItem.categoryName
                            break
                        end
                    end
                    if displayCategory ~= "" then break end
                end
            end
            
            -- Fallback se non trovato
            if displayCategory == "" then
                displayCategory = storeItem.categoryName
            end
        elseif favorite.category ~= nil and favorite.category ~= "" and favorite.category ~= "owned" then
            displayCategory = favorite.category
        end
        
        categoryElement:setText(displayCategory)
    end
end

function MenuFavoritesList:onListSelectionChanged(list, section, index)
    self.selectedIndex = index
end

function MenuFavoritesList:onBuyFavorite()
    print("ShopFavorites: onBuyFavorite called")
    
    if self.selectedIndex <= 0 or self.selectedIndex > #self.currentFavorites then
        print("ShopFavorites: Invalid selectedIndex: " .. tostring(self.selectedIndex))
        return
    end

    local favorite = self.currentFavorites[self.selectedIndex]
    if favorite == nil or favorite.xmlFilename == nil then
        print("ShopFavorites: Favorite is nil or xmlFilename is nil")
        return
    end

    print("ShopFavorites: Favorite xmlFilename: " .. tostring(favorite.xmlFilename))

    -- Cerca lo store item corrispondente
    local storeItem = nil
    if g_storeManager ~= nil then
        for _, item in pairs(g_storeManager.items) do
            if item ~= nil and item.xmlFilename == favorite.xmlFilename then
                storeItem = item
                break
            end
        end
    end

    if storeItem == nil then
        print("ShopFavorites: StoreItem not found!")
        InfoDialog.show(g_i18n:getText("sf_error_not_found"))
        return
    end

    print("ShopFavorites: StoreItem found: " .. tostring(storeItem.name))

    -- Incrementa il contatore delle aperture per questo preferito
    if g_currentMission ~= nil and g_currentMission.FavoriteManager ~= nil then
        g_currentMission.FavoriteManager:incrementOpenCount(favorite.xmlFilename)
    end

    -- Imposta le configurazioni pending PRIMA di cambiare schermata
    -- Queste verranno applicate automaticamente in onFrameOpen quando la schermata viene aperta
    if favorite.configurations ~= nil and tableCount(favorite.configurations) > 0 then
        print("ShopFavorites: Setting pending configurations")
        ShopConfigScreenExtension.setPendingConfigurations(favorite.configurations)
    else
        -- Assicurati che non ci siano configurazioni pending residue
        print("ShopFavorites: No configurations to set")
        ShopConfigScreenExtension.setPendingConfigurations(nil)
    end

    -- Apre ShopConfigScreen con ShopMenu come screen di ritorno
    -- Questo permette al pulsante "Indietro" di funzionare correttamente
    print("ShopFavorites: Changing screen to ShopConfigScreen")
    g_gui:changeScreen(nil, ShopConfigScreen, ShopMenu)
    
    -- Imposta lo storeItem nella schermata di configurazione
    -- Le configurazioni pending verranno applicate automaticamente in onFrameOpen
    print("ShopFavorites: Checking if ShopConfigScreen controller exists")
    if g_gui.screenControllers[ShopConfigScreen] ~= nil then
        print("ShopFavorites: ShopConfigScreen controller exists, calling setStoreItem")
        local shopConfigScreen = g_gui.screenControllers[ShopConfigScreen]
        shopConfigScreen:setStoreItem(storeItem)
        print("ShopFavorites: setStoreItem called")
    else
        print("ShopFavorites: ShopConfigScreen controller is nil!")
    end
end

function MenuFavoritesList:removeFavorite()
    if self.selectedIndex <= 0 or self.selectedIndex > #self.currentFavorites then
        return
    end

    local favorite = self.currentFavorites[self.selectedIndex]
    if favorite == nil then
        return
    end

    -- Cattura il xmlFilename in una variabile locale per assicurarsi che sia disponibile nella callback
    local xmlFilename = favorite.xmlFilename
    local favoriteName = favorite.name or g_i18n:getText("sf_unknown_vehicle")

    YesNoDialog.show(
        function(yes)
            if yes then
                if g_currentMission ~= nil and g_currentMission.FavoriteManager ~= nil then
                    g_currentMission.FavoriteManager:removeFavoriteByXml(xmlFilename)
                    InfoDialog.show(g_i18n:getText("sf_removed_favorite"))
                    self.selectedIndex = -1
                    self:updateContent()
                end
            end
        end,
        nil,
        string.format(g_i18n:getText("sf_confirm_remove"), favoriteName)
    )
end

-- Metodo per ottenere l'elemento per nome attributo
function MenuFavoritesList:getAttribute(name)
    if self.elements ~= nil then
        for _, element in ipairs(self.elements) do
            if element.name == name then
                return element
            end
        end
    end
    return nil
end

-- Metodo richiesto da ShopMenu per evitare errori
-- La nostra pagina non ha categorie da aprire, quindi questo metodo è vuoto
function MenuFavoritesList:onOpenCategory()
    -- Non fare nulla - la nostra pagina non ha categorie
end

-- Metodi per la paginazione del menu (cambio tab)
function MenuFavoritesList:onPreviousPage()
    if g_shopMenu ~= nil and g_shopMenu.onPagePrevious ~= nil then
        g_shopMenu:onPagePrevious()
    end
end

function MenuFavoritesList:onNextPage()
    if g_shopMenu ~= nil and g_shopMenu.onPageNext ~= nil then
        g_shopMenu:onPageNext()
    end
end
