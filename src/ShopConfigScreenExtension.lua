--
-- FS25 - ShopFavorites
--
-- Estensione per ShopConfigScreen che aggiunge il pulsante preferiti
-- e gestisce l'apertura dei preferiti nella schermata di configurazione.

ShopConfigScreenExtension = {}

-- Configurazioni da applicare al prossimo storeItem aperto
ShopConfigScreenExtension.pendingConfigurations = nil
-- StoreItem da aprire quando ShopConfigScreen viene mostrata dai preferiti
ShopConfigScreenExtension.pendingStoreItem = nil
ShopConfigScreenExtension.isApplyingFavoriteStoreItem = false
ShopConfigScreenExtension.pendingDefaultConfigRestore = nil
-- Action event ID per il tasto preferiti
ShopConfigScreenExtension.favoriteActionEventId = nil
-- Flag per verificare se l'azione e' gia' registrata
ShopConfigScreenExtension.isActionRegistered = false

local function tableSize(tbl)
    if tbl == nil then
        return 0
    end

    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end

    return count
end

local function getScreenClassName(screenClass)
    if screenClass == nil then
        return "nil"
    elseif screenClass == ShopMenu then
        return "ShopMenu"
    elseif screenClass == ShopConfigScreen then
        return "ShopConfigScreen"
    elseif screenClass == WorkshopScreen then
        return "WorkshopScreen"
    end

    return tostring(screenClass)
end

local function getCurrentFarmMoney()
    if g_currentMission == nil or g_farmManager == nil or g_currentMission.getFarmId == nil then
        return "nil"
    end

    local farmId = g_currentMission:getFarmId()
    if farmId == nil then
        return "nil"
    end

    local farm = g_farmManager:getFarmById(farmId)
    if farm == nil or farm.money == nil then
        return "nil"
    end

    return tostring(farm.money)
end

function ShopConfigScreenExtension.logScreenState(shopConfigScreen, label)
    if not ShopFavoritesDebug.enabled then
        return
    end

    if shopConfigScreen == nil then
        ShopFavoritesDebug.log(label .. " screen=nil")
        return
    end

    local storeItemName = shopConfigScreen.storeItem ~= nil and shopConfigScreen.storeItem.name or "nil"
    local returnScreen = getScreenClassName(shopConfigScreen.returnScreenClass)
    local vehicleId = shopConfigScreen.vehicle ~= nil and tostring(shopConfigScreen.vehicle:getUniqueId()) or "nil"
    local workshop = tostring(ShopConfigScreenExtension.isWorkshopContext(shopConfigScreen))

    ShopFavoritesDebug.log(string.format(
        "%s storeItem=%s returnScreen=%s vehicle=%s workshop=%s totalPrice=%s configBasePrice=%s lastMoney=%s farmMoney=%s favoriteContext=%s configs=%d boughtConfigs=%d previewVehicles=%d",
        label,
        tostring(storeItemName),
        tostring(returnScreen),
        tostring(vehicleId),
        workshop,
        tostring(shopConfigScreen.totalPrice),
        tostring(shopConfigScreen.configBasePrice),
        tostring(shopConfigScreen.lastMoney),
        getCurrentFarmMoney(),
        tostring(shopConfigScreen.shopFavoritesOpenedFromFavorite == true),
        tableSize(shopConfigScreen.configurations),
        tableSize(shopConfigScreen.boughtConfigurations),
        tableSize(shopConfigScreen.previewVehicles)
    ))

    ShopFavoritesDebug.log(string.format("%s configurations=%s",
        label, ShopFavoritesDebug.describeTableShallow(shopConfigScreen.configurations)))
    ShopFavoritesDebug.log(string.format("%s boughtConfigurations=%s",
        label, ShopFavoritesDebug.describeTableShallow(shopConfigScreen.boughtConfigurations)))
end

function ShopConfigScreenExtension.setPendingConfigurations(configurations)
    ShopConfigScreenExtension.pendingConfigurations = configurations
end

function ShopConfigScreenExtension.setPendingStoreItem(storeItem)
    ShopConfigScreenExtension.pendingStoreItem = storeItem
end

function ShopConfigScreenExtension.initializeFinancialState(shopConfigScreen)
    if shopConfigScreen == nil or g_currentMission == nil then
        return
    end

    local farmId = g_currentMission:getFarmId()
    if farmId ~= nil then
        local farm = g_farmManager ~= nil and g_farmManager:getFarmById(farmId) or nil
        if farm ~= nil and farm.money ~= nil then
            shopConfigScreen.lastMoney = farm.money
        elseif g_currentMission.getMoney ~= nil then
            shopConfigScreen.lastMoney = g_currentMission:getMoney()
        end
    end
end

function ShopConfigScreenExtension.hasBuyPermission()
    if g_currentMission == nil or g_currentMission.getHasPlayerPermission == nil then
        return true
    end

    return g_currentMission:getHasPlayerPermission(Farm.PERMISSION.BUY_VEHICLE)
end

function ShopConfigScreenExtension.showNoPermissionDialog()
    InfoDialog.show(g_i18n:getText("shop_messageNoPermissionGeneral"))
end

function ShopConfigScreenExtension.isWorkshopContext(shopConfigScreen)
    return shopConfigScreen ~= nil and shopConfigScreen.returnScreenClass == WorkshopScreen
end

function ShopConfigScreenExtension.closePurchaseScreens()
    if g_gui ~= nil then
        g_gui:closeDialogByName("YesNoDialog")
        g_gui:changeScreen(nil, ShopMenu)
    end
end

function ShopConfigScreenExtension.createVehicleBuyData(shopConfigScreen, leaseVehicle, farmId)
    local data = BuyVehicleData.new()
    data:setStoreItem(shopConfigScreen.storeItem)
    -- Per un acquisto nuovo non dobbiamo riusare boughtConfigurations della schermata,
    -- altrimenti il veicolo puo' nascere con upgrade gia' segnati come acquistati.
    data:setConfigurations(shopConfigScreen.configurations)
    data:setConfigurationData(shopConfigScreen.configurationData)
    data:setLeaseVehicle(leaseVehicle)
    data:setOwnerFarmId(farmId)

    if data.setLicensePlateData ~= nil then
        data:setLicensePlateData(shopConfigScreen.licensePlateData)
    end

    if shopConfigScreen.saleItem ~= nil then
        data:setSaleItem(shopConfigScreen.saleItem)
    end

    data:setPrice(leaseVehicle and shopConfigScreen.initialLeasingCosts or shopConfigScreen.totalPrice)

    return data
end

function ShopConfigScreenExtension.createHandToolBuyData(shopConfigScreen, farmId)
    local data = BuyHandToolData.new()
    data:setStoreItem(shopConfigScreen.storeItem)
    data:setOwnerFarmId(farmId)
    data:setPrice(shopConfigScreen.totalPrice)

    return data
end

function ShopConfigScreenExtension.executeFavoritePurchase(shopConfigScreen, leaseVehicle)
    if shopConfigScreen == nil or shopConfigScreen.storeItem == nil or g_currentMission == nil then
        return false
    end

    ShopConfigScreenExtension.logScreenState(shopConfigScreen,
        string.format("Executing favorite purchase flow lease=%s", tostring(leaseVehicle)))

    if not ShopConfigScreenExtension.hasBuyPermission() then
        ShopConfigScreenExtension.showNoPermissionDialog()
        return true
    end

    local storeItem = shopConfigScreen.storeItem
    local farmId = g_currentMission:getFarmId()

    if StoreItemUtil.getIsVehicle(storeItem) then
        local data = ShopConfigScreenExtension.createVehicleBuyData(shopConfigScreen, leaseVehicle, farmId)
        if data:isValid() then
            data:updatePrice()

            if g_server == nil and g_client ~= nil then
                g_client:getServerConnection():sendEvent(BuyVehicleEvent.new(data))
                ShopConfigScreenExtension.closePurchaseScreens()
            else
                data:buy(g_currentMission.storeSpawnPlaces, g_currentMission.usedStorePlaces, function()
                    g_gui:changeScreen(nil, ShopMenu)
                end)
            end

            return true
        end
    elseif StoreItemUtil.getIsHandTool(storeItem) then
        local data = ShopConfigScreenExtension.createHandToolBuyData(shopConfigScreen, farmId)
        if data:isValid() then
            data:updatePrice()

            if g_server == nil and g_client ~= nil then
                g_client:getServerConnection():sendEvent(BuyHandToolEvent.new(data))
                ShopConfigScreenExtension.closePurchaseScreens()
            else
                data:buy(function()
                    g_gui:changeScreen(nil, ShopMenu)
                end)
            end

            return true
        end
    end

    return false
end

function ShopConfigScreenExtension.shouldHandleFavoritePurchase(shopConfigScreen)
    return shopConfigScreen ~= nil
        and shopConfigScreen.shopFavoritesOpenedFromFavorite == true
        and shopConfigScreen.vehicle == nil
        and not ShopConfigScreenExtension.isWorkshopContext(shopConfigScreen)
end

-- Aggiunge un pulsante per aggiungere/rimuovere dai preferiti nella schermata di configurazione del negozio
function ShopConfigScreenExtension:onSetStoreItem(shopConfigScreen, storeItem)
    ShopConfigScreenExtension.logScreenState(shopConfigScreen, "onSetStoreItem")

    if ShopConfigScreenExtension.isWorkshopContext(shopConfigScreen) then
        if shopConfigScreen.favoriteButton ~= nil then
            shopConfigScreen.favoriteButton:setDisabled(true)
            shopConfigScreen.favoriteButton:setVisible(false)
        end

        ShopFavoritesDebug.log("Workshop context detected in onSetStoreItem, favorite button disabled")
        ShopConfigScreenExtension:unregisterActionEvent()
        return
    end

    local sourceButton = shopConfigScreen.buyButton
    local favoriteButton = shopConfigScreen.favoriteButton

    if not favoriteButton and sourceButton then
        local parent = sourceButton.parent
        favoriteButton = sourceButton:clone(parent)
        favoriteButton.name = "favoriteButton"
        favoriteButton.inputActionName = "SHOPFAVORITES_TOGGLE_FAVORITE"
        shopConfigScreen.favoriteButton = favoriteButton
    end

    if favoriteButton ~= nil then
        if storeItem == nil then
            favoriteButton:setDisabled(true)
            favoriteButton:setVisible(false)
        else
            local isFavorite = false
            if g_currentMission.FavoriteManager ~= nil then
                isFavorite = g_currentMission.FavoriteManager:isFavoriteByXml(storeItem.xmlFilename)
            end

            favoriteButton:setDisabled(false)
            favoriteButton:setVisible(true)
            favoriteButton:setText(g_i18n:getText(isFavorite and "sf_remove_favorite" or "sf_add_favorite"))

            shopConfigScreen.onClickFavorite = function()
                if g_currentMission.FavoriteManager ~= nil and storeItem ~= nil then
                    if g_currentMission.FavoriteManager:isFavoriteByXml(storeItem.xmlFilename) then
                        g_currentMission.FavoriteManager:removeFavoriteByXml(storeItem.xmlFilename)
                        favoriteButton:setText(g_i18n:getText("sf_add_favorite"))
                    else
                        local configurations = ShopConfigScreenExtension.getCurrentConfigurations(shopConfigScreen)
                        g_currentMission.FavoriteManager:addFavoriteFromStoreItem(storeItem, configurations)
                        favoriteButton:setText(g_i18n:getText("sf_remove_favorite"))
                    end
                end
            end

            favoriteButton.onClickCallback = shopConfigScreen.onClickFavorite
            favoriteButton:setCallback("onClickCallback", "onClickFavorite")

            ShopConfigScreenExtension:registerActionEvent(shopConfigScreen)
        end
    end
end

function ShopConfigScreenExtension.getCurrentConfigurations(shopConfigScreen)
    local configurations = {}

    if shopConfigScreen == nil then
        return configurations
    end

    if shopConfigScreen.configurations ~= nil then
        for configName, configIndex in pairs(shopConfigScreen.configurations) do
            configurations[configName] = configIndex
        end
    end

    return configurations
end

function ShopConfigScreenExtension:updateButtons(shopConfigScreen, storeItem, vehicle, saleItem)
    if shopConfigScreen.favoriteButton then
        if ShopConfigScreenExtension.isWorkshopContext(shopConfigScreen) then
            shopConfigScreen.favoriteButton:setVisible(false)
            shopConfigScreen.favoriteButton:setDisabled(true)
            ShopConfigScreenExtension.logScreenState(shopConfigScreen, "updateButtons workshop context")
            return
        end

        shopConfigScreen.favoriteButton:setVisible(vehicle == nil and saleItem == nil)
        ShopConfigScreenExtension.logScreenState(shopConfigScreen, "updateButtons normal context")
    end
end

function ShopConfigScreenExtension:registerActionEvent(shopConfigScreen)
    if ShopConfigScreenExtension.isActionRegistered then
        return
    end

    local valid, eventId = g_inputBinding:registerActionEvent(
        "SHOPFAVORITES_TOGGLE_FAVORITE",
        shopConfigScreen,
        ShopConfigScreenExtension.onToggleFavoriteInput,
        false,
        true,
        false,
        true
    )

    if valid then
        ShopConfigScreenExtension.favoriteActionEventId = eventId
        ShopConfigScreenExtension.isActionRegistered = true
        g_inputBinding:setActionEventTextVisibility(eventId, false)
    end
end

function ShopConfigScreenExtension:unregisterActionEvent()
    if ShopConfigScreenExtension.favoriteActionEventId ~= nil then
        g_inputBinding:removeActionEvent(ShopConfigScreenExtension.favoriteActionEventId)
        ShopConfigScreenExtension.favoriteActionEventId = nil
        ShopConfigScreenExtension.isActionRegistered = false
    end
end

function ShopConfigScreenExtension.onToggleFavoriteInput(shopConfigScreen)
    if shopConfigScreen.onClickFavorite ~= nil then
        shopConfigScreen.onClickFavorite()
    end
end

ShopConfigScreen.setStoreItem = Utils.prependedFunction(ShopConfigScreen.setStoreItem,
    function(self, storeItem, ...)
        local isFavoriteStoreItem = ShopConfigScreenExtension.isApplyingFavoriteStoreItem == true
            and not ShopConfigScreenExtension.isWorkshopContext(self)

        ShopFavoritesDebug.log(string.format("setStoreItem begin storeItem=%s pendingConfigs=%s applyingFavorite=%s",
            tostring(storeItem ~= nil and storeItem.name or "nil"),
            tostring(ShopConfigScreenExtension.pendingConfigurations ~= nil),
            tostring(isFavoriteStoreItem)))

        self.shopFavoritesOpenedFromFavorite = isFavoriteStoreItem
        ShopConfigScreenExtension.pendingDefaultConfigRestore = nil

        if isFavoriteStoreItem
            and ShopConfigScreenExtension.pendingConfigurations ~= nil
            and storeItem ~= nil then
            local newDefaults = {}

            if storeItem.defaultConfigurationIds ~= nil then
                for k, v in pairs(storeItem.defaultConfigurationIds) do
                    newDefaults[k] = v
                end
            end

            for configName, configIndex in pairs(ShopConfigScreenExtension.pendingConfigurations) do
                newDefaults[configName] = configIndex
            end

            ShopConfigScreenExtension.pendingDefaultConfigRestore = {
                storeItem = storeItem,
                defaultConfigurationIds = storeItem.defaultConfigurationIds
            }

            storeItem.defaultConfigurationIds = newDefaults
            ShopConfigScreenExtension.pendingConfigurations = nil
        end
    end)

ShopConfigScreen.setStoreItem = Utils.appendedFunction(ShopConfigScreen.setStoreItem,
    function(self, storeItem, ...)
        local restoreData = ShopConfigScreenExtension.pendingDefaultConfigRestore
        if restoreData ~= nil and restoreData.storeItem == storeItem and storeItem ~= nil then
            storeItem.defaultConfigurationIds = restoreData.defaultConfigurationIds
        end
        ShopConfigScreenExtension.pendingDefaultConfigRestore = nil

        ShopConfigScreenExtension.logScreenState(self, "setStoreItem end")
        ShopConfigScreenExtension:onSetStoreItem(self, storeItem)
    end)

ShopConfigScreen.updateButtons = Utils.prependedFunction(ShopConfigScreen.updateButtons,
    function(self, storeItem, vehicle, saleItem)
        ShopConfigScreenExtension:updateButtons(self, storeItem, vehicle, saleItem)
    end)

-- Consuma il preferito dopo che la GUI ha completato il cambio schermata.
Gui.changeScreen = Utils.appendedFunction(Gui.changeScreen,
    function(self, sourceScreen, screenClass, returnScreenClass)
        ShopFavoritesDebug.log(string.format("Gui.changeScreen source=%s target=%s return=%s pendingStoreItem=%s",
            getScreenClassName(sourceScreen),
            getScreenClassName(screenClass),
            getScreenClassName(returnScreenClass),
            tostring(ShopConfigScreenExtension.pendingStoreItem ~= nil)))

        if screenClass == ShopConfigScreen and ShopConfigScreenExtension.pendingStoreItem ~= nil then
            local shopConfigScreen = self.screenControllers[ShopConfigScreen]
            local storeItem = ShopConfigScreenExtension.pendingStoreItem
            ShopConfigScreenExtension.pendingStoreItem = nil

            if shopConfigScreen ~= nil then
                ShopConfigScreenExtension.initializeFinancialState(shopConfigScreen)
                ShopConfigScreenExtension.isApplyingFavoriteStoreItem = true
                ShopConfigScreenExtension.logScreenState(shopConfigScreen, "Applying pending favorite storeItem")
                shopConfigScreen:setStoreItem(storeItem)
                ShopConfigScreenExtension.isApplyingFavoriteStoreItem = false
            end
        end
    end)

ShopConfigScreen.onClose = Utils.appendedFunction(ShopConfigScreen.onClose,
    function(self)
        ShopConfigScreenExtension.logScreenState(self, "onClose")
        ShopConfigScreenExtension:unregisterActionEvent()

        ShopConfigScreenExtension.pendingStoreItem = nil
        ShopConfigScreenExtension.pendingConfigurations = nil
        ShopConfigScreenExtension.isApplyingFavoriteStoreItem = false

        self.shopFavoritesOpenedFromFavorite = false
    end)

if ShopConfigScreen.onClickOk ~= nil then
    ShopConfigScreen.onClickOk = Utils.overwrittenFunction(ShopConfigScreen.onClickOk,
        function(self, superFunc, ...)
            ShopConfigScreenExtension.logScreenState(self, "onClickOk before")
            return superFunc(self, ...)
        end)
end

if ShopConfigScreen.onClickActivate ~= nil then
    ShopConfigScreen.onClickActivate = Utils.overwrittenFunction(ShopConfigScreen.onClickActivate,
        function(self, superFunc, ...)
            ShopConfigScreenExtension.logScreenState(self, "onClickActivate before")
            return superFunc(self, ...)
        end)
end

if ShopConfigScreen.onYesNoBuy ~= nil then
    ShopConfigScreen.onYesNoBuy = Utils.overwrittenFunction(ShopConfigScreen.onYesNoBuy,
        function(self, superFunc, yes, ...)
            ShopConfigScreenExtension.logScreenState(self, "onYesNoBuy before")
            if yes and ShopConfigScreenExtension.shouldHandleFavoritePurchase(self) then
                ShopFavoritesDebug.log("Intercepting ShopConfigScreen.onYesNoBuy for favorite purchase")
                local handled = ShopConfigScreenExtension.executeFavoritePurchase(self, false)
                if handled then
                    return
                end
            end

            return superFunc(self, yes, ...)
        end)
end

if ShopConfigScreen.onYesNoLease ~= nil then
    ShopConfigScreen.onYesNoLease = Utils.overwrittenFunction(ShopConfigScreen.onYesNoLease,
        function(self, superFunc, yes, ...)
            ShopConfigScreenExtension.logScreenState(self, "onYesNoLease before")
            if yes and ShopConfigScreenExtension.shouldHandleFavoritePurchase(self) then
                ShopFavoritesDebug.log("Intercepting ShopConfigScreen.onYesNoLease for favorite lease")
                local handled = ShopConfigScreenExtension.executeFavoritePurchase(self, true)
                if handled then
                    return
                end
            end

            return superFunc(self, yes, ...)
        end)
end

if WorkshopScreen ~= nil and WorkshopScreen.onOpen ~= nil then
    WorkshopScreen.onOpen = Utils.appendedFunction(WorkshopScreen.onOpen,
        function(self)
            ShopFavoritesDebug.log(string.format("WorkshopScreen.onOpen vehicles=%d", tableSize(self.vehicles)))
        end)
end

if WorkshopScreen ~= nil and WorkshopScreen.onClose ~= nil then
    WorkshopScreen.onClose = Utils.appendedFunction(WorkshopScreen.onClose,
        function(self)
            ShopFavoritesDebug.log("WorkshopScreen.onClose")
        end)
end
