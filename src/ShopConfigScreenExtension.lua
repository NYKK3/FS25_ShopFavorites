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
-- StoreItem originale per ripristinare i default
ShopConfigScreenExtension.originalDefaultConfigIds = nil
-- Action event ID per il tasto preferiti
ShopConfigScreenExtension.favoriteActionEventId = nil
-- Flag per verificare se l'azione e' gia' registrata
ShopConfigScreenExtension.isActionRegistered = false

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

function ShopConfigScreenExtension.closePurchaseScreens()
    if g_gui ~= nil then
        g_gui:closeDialogByName("YesNoDialog")
        g_gui:changeScreen(nil, ShopMenu)
    end
end

function ShopConfigScreenExtension.createVehicleBuyData(shopConfigScreen, leaseVehicle, farmId)
    local data = BuyVehicleData.new()
    data:setStoreItem(shopConfigScreen.storeItem)
    data:setConfigurations(shopConfigScreen.configurations, shopConfigScreen.boughtConfigurations)
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

-- Aggiunge un pulsante per aggiungere/rimuovere dai preferiti nella schermata di configurazione del negozio
function ShopConfigScreenExtension:onSetStoreItem(shopConfigScreen, storeItem)
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
        shopConfigScreen.favoriteButton:setVisible(vehicle == nil and saleItem == nil)
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

ShopConfigScreen.setStoreItem = Utils.overwrittenFunction(ShopConfigScreen.setStoreItem,
    function(self, superFunc, storeItem, ...)
        self.shopFavoritesOpenedFromFavorite = ShopConfigScreenExtension.isApplyingFavoriteStoreItem == true

        if ShopConfigScreenExtension.pendingConfigurations ~= nil and storeItem ~= nil then
            local configsToApply = ShopConfigScreenExtension.pendingConfigurations

            ShopConfigScreenExtension.originalDefaultConfigIds = storeItem.defaultConfigurationIds

            local newDefaults = {}
            if storeItem.defaultConfigurationIds ~= nil then
                for k, v in pairs(storeItem.defaultConfigurationIds) do
                    newDefaults[k] = v
                end
            end

            for configName, configIndex in pairs(configsToApply) do
                newDefaults[configName] = configIndex
            end

            storeItem.defaultConfigurationIds = newDefaults
            ShopConfigScreenExtension.pendingConfigurations = nil
        end

        superFunc(self, storeItem, ...)

        ShopConfigScreenExtension:onSetStoreItem(self, storeItem)
    end)

ShopConfigScreen.updateButtons = Utils.prependedFunction(ShopConfigScreen.updateButtons,
    function(self, storeItem, vehicle, saleItem)
        ShopConfigScreenExtension:updateButtons(self, storeItem, vehicle, saleItem)
    end)

-- Consuma il preferito dopo che la GUI ha completato il cambio schermata.
Gui.changeScreen = Utils.overwrittenFunction(Gui.changeScreen,
    function(self, superFunc, sourceScreen, screenClass, returnScreenClass)
        local result = superFunc(self, sourceScreen, screenClass, returnScreenClass)

        if screenClass == ShopConfigScreen and ShopConfigScreenExtension.pendingStoreItem ~= nil then
            local shopConfigScreen = self.screenControllers[ShopConfigScreen]
            local storeItem = ShopConfigScreenExtension.pendingStoreItem
            ShopConfigScreenExtension.pendingStoreItem = nil

            if shopConfigScreen ~= nil then
                -- La schermata mantiene stato tra aperture. Puliamo il riferimento
                -- precedente prima di assegnare l'articolo richiesto dal preferito.
                shopConfigScreen.storeItem = nil
                ShopConfigScreenExtension.initializeFinancialState(shopConfigScreen)
                ShopConfigScreenExtension.isApplyingFavoriteStoreItem = true
                shopConfigScreen:setStoreItem(storeItem)
                ShopConfigScreenExtension.isApplyingFavoriteStoreItem = false
            end
        end

        return result
    end)

ShopConfigScreen.onClose = Utils.appendedFunction(ShopConfigScreen.onClose,
    function(self)
        ShopConfigScreenExtension:unregisterActionEvent()

        if ShopConfigScreenExtension.originalDefaultConfigIds ~= nil and self.storeItem ~= nil then
            self.storeItem.defaultConfigurationIds = ShopConfigScreenExtension.originalDefaultConfigIds
            ShopConfigScreenExtension.originalDefaultConfigIds = nil
        end

        ShopConfigScreenExtension.pendingStoreItem = nil
        ShopConfigScreenExtension.pendingConfigurations = nil
        ShopConfigScreenExtension.isApplyingFavoriteStoreItem = false

        -- Evita che l'istanza della schermata riutilizzi stato vecchio
        -- alla successiva apertura da un preferito.
        self.storeItem = nil
        self.saleItem = nil
        self.vehicle = nil
        self.shopFavoritesOpenedFromFavorite = false
        self.configurations = {}
        self.configurationData = {}
        self.previewVehicles = {}
    end)

if ShopConfigScreen.onYesNoBuy ~= nil then
    ShopConfigScreen.onYesNoBuy = Utils.overwrittenFunction(ShopConfigScreen.onYesNoBuy,
        function(self, superFunc, yes, ...)
            if yes and self.shopFavoritesOpenedFromFavorite == true and self.vehicle == nil then
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
            if yes and self.shopFavoritesOpenedFromFavorite == true and self.vehicle == nil then
                local handled = ShopConfigScreenExtension.executeFavoritePurchase(self, true)
                if handled then
                    return
                end
            end

            return superFunc(self, yes, ...)
        end)
end
