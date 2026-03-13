--
-- FS25 - ShopFavorites
--
-- Estensione per ShopConfigScreen che aggiunge il pulsante preferiti
-- Ottiene le configurazioni correnti e le passa al FavoriteManager
-- Applica le configurazioni salvate quando si apre un preferito

ShopConfigScreenExtension = {}

-- Variabile temporanea per memorizzare le configurazioni da applicare
ShopConfigScreenExtension.pendingConfigurations = nil
-- StoreItem originale per ripristinare i default
ShopConfigScreenExtension.originalDefaultConfigIds = nil
-- Action event ID per il tasto preferiti
ShopConfigScreenExtension.favoriteActionEventId = nil
-- Flag per verificare se l'azione è già registrata
ShopConfigScreenExtension.isActionRegistered = false

-- Imposta le configurazioni da applicare al prossimo setStoreItem
function ShopConfigScreenExtension.setPendingConfigurations(configurations)
    ShopConfigScreenExtension.pendingConfigurations = configurations
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
        -- Mostra il pulsante per tutti gli articoli del negozio
        if storeItem == nil then
            favoriteButton:setDisabled(true)
            favoriteButton:setVisible(false)
        else
            -- Verifica se già nei preferiti usando xmlFilename
            local isFavorite = false
            if g_currentMission.FavoriteManager ~= nil and storeItem ~= nil then
                isFavorite = g_currentMission.FavoriteManager:isFavoriteByXml(storeItem.xmlFilename)
            end

            favoriteButton:setDisabled(false)
            favoriteButton:setVisible(true)
            favoriteButton:setText(g_i18n:getText(isFavorite and "sf_remove_favorite" or "sf_add_favorite"))

            -- Imposta il callback correttamente
            shopConfigScreen.onClickFavorite = function()
                if g_currentMission.FavoriteManager ~= nil and storeItem ~= nil then
                    if g_currentMission.FavoriteManager:isFavoriteByXml(storeItem.xmlFilename) then
                        g_currentMission.FavoriteManager:removeFavoriteByXml(storeItem.xmlFilename)
                        favoriteButton:setText(g_i18n:getText("sf_add_favorite"))
                    else
                        -- Ottieni le configurazioni correnti dallo ShopConfigScreen
                        local configurations = ShopConfigScreenExtension.getCurrentConfigurations(shopConfigScreen)
                        
                        -- Aggiungi il preferito con le configurazioni
                        g_currentMission.FavoriteManager:addFavoriteFromStoreItem(storeItem, configurations)
                        favoriteButton:setText(g_i18n:getText("sf_remove_favorite"))
                    end
                end
            end

            -- Collega il callback al pulsante
            favoriteButton.onClickCallback = shopConfigScreen.onClickFavorite
            favoriteButton:setCallback("onClickCallback", "onClickFavorite")
            
            -- Registra l'azione input se non è già registrata
            ShopConfigScreenExtension:registerActionEvent(shopConfigScreen)
        end
    end
end

-- Ottiene le configurazioni correnti dallo ShopConfigScreen
function ShopConfigScreenExtension.getCurrentConfigurations(shopConfigScreen)
    local configurations = {}
    
    if shopConfigScreen == nil then
        return configurations
    end
    
    -- Lo ShopConfigScreen ha una proprietà 'configurations' che contiene le configurazioni selezionate
    if shopConfigScreen.configurations ~= nil then
        for configName, configIndex in pairs(shopConfigScreen.configurations) do
            configurations[configName] = configIndex
        end
    end
    
    return configurations
end

function ShopConfigScreenExtension:updateButtons(shopConfigScreen, storeItem, vehicle, saleItem)
    if shopConfigScreen.favoriteButton then
        -- Mostra il pulsante solo quando non stiamo configurando un veicolo esistente
        shopConfigScreen.favoriteButton:setVisible(vehicle == nil and saleItem == nil)
    end
end

-- Registra l'azione input per il tasto preferiti
function ShopConfigScreenExtension:registerActionEvent(shopConfigScreen)
    -- Se l'azione è già registrata, non fare nulla
    if ShopConfigScreenExtension.isActionRegistered then
        return
    end
    
    -- Registra il nuovo evento - passa il nome dell'azione come stringa
    local actionName = "SHOPFAVORITES_TOGGLE_FAVORITE"
    
    local valid, eventId = g_inputBinding:registerActionEvent(
        actionName,
        shopConfigScreen,
        ShopConfigScreenExtension.onToggleFavoriteInput,
        false,  -- triggerUp
        true,   -- triggerDown
        false,  -- triggerAlways
        true    -- startActive
    )
    
    if valid then
        ShopConfigScreenExtension.favoriteActionEventId = eventId
        ShopConfigScreenExtension.isActionRegistered = true
        g_inputBinding:setActionEventTextVisibility(eventId, false)
    end
end

-- Rimuove l'azione input registrata
function ShopConfigScreenExtension:unregisterActionEvent()
    if ShopConfigScreenExtension.favoriteActionEventId ~= nil then
        g_inputBinding:removeActionEvent(ShopConfigScreenExtension.favoriteActionEventId)
        ShopConfigScreenExtension.favoriteActionEventId = nil
        ShopConfigScreenExtension.isActionRegistered = false
    end
end

-- Callback chiamato quando viene premuto il tasto preferiti
function ShopConfigScreenExtension.onToggleFavoriteInput(shopConfigScreen)
    if shopConfigScreen.onClickFavorite ~= nil then
        shopConfigScreen.onClickFavorite()
    end
end

-- Hook setStoreItem per applicare le configurazioni e gestire il pulsante preferiti
ShopConfigScreen.setStoreItem = Utils.overwrittenFunction(ShopConfigScreen.setStoreItem,
    function(self, superFunc, storeItem, ...)
        print("ShopFavorites: setStoreItem called with storeItem: " .. tostring(storeItem and storeItem.name))
        print("ShopFavorites: self.storeItem before superFunc: " .. tostring(self.storeItem and self.storeItem.name))
        
        -- Se ci sono configurazioni pending, applicale allo storeItem PRIMA di chiamare superFunc
        if ShopConfigScreenExtension.pendingConfigurations ~= nil and storeItem ~= nil then
            print("ShopFavorites: Pending configurations found, applying to storeItem")
            local configsToApply = ShopConfigScreenExtension.pendingConfigurations
            
            -- Salva i default originali per ripristinarli dopo
            ShopConfigScreenExtension.originalDefaultConfigIds = storeItem.defaultConfigurationIds
            
            -- Crea una copia dei default e modifica con le nostre configurazioni
            local newDefaults = {}
            if storeItem.defaultConfigurationIds ~= nil then
                for k, v in pairs(storeItem.defaultConfigurationIds) do
                    newDefaults[k] = v
                end
            end
            
            -- Applica le nostre configurazioni come nuovi default
            for configName, configIndex in pairs(configsToApply) do
                print("ShopFavorites: Applying config " .. configName .. " = " .. configIndex .. " to storeItem")
                newDefaults[configName] = configIndex
            end
            
            -- Sostituisci i default dello storeItem temporaneamente
            storeItem.defaultConfigurationIds = newDefaults
            
            -- Cancella le configurazioni pending
            ShopConfigScreenExtension.pendingConfigurations = nil
            print("ShopFavorites: Configurations applied to storeItem")
        else
            print("ShopFavorites: No pending configurations")
        end
        
        -- Chiama la funzione originale con le configurazioni applicate
        superFunc(self, storeItem, ...)
        
        print("ShopFavorites: superFunc called, self.configurations: " .. tostring(self.configurations ~= nil))
        print("ShopFavorites: self.storeItem after superFunc: " .. tostring(self.storeItem and self.storeItem.name))
        
        -- NON ripristinare i default originali qui, li ripristiniamo in onClose
        
        -- Gestisce il pulsante preferiti
        ShopConfigScreenExtension:onSetStoreItem(self, storeItem)
    end)

ShopConfigScreen.updateButtons = Utils.prependedFunction(ShopConfigScreen.updateButtons,
    function(self, storeItem, vehicle, saleItem)
        ShopConfigScreenExtension:updateButtons(self, storeItem, vehicle, saleItem)
    end)

-- Hook onFrameOpen per applicare le configurazioni pending quando la schermata viene aperta
ShopConfigScreen.onFrameOpen = Utils.appendedFunction(ShopConfigScreen.onFrameOpen,
    function(self)
        -- Se ci sono configurazioni pending e un storeItem è stato impostato, applicale
        if ShopConfigScreenExtension.pendingConfigurations ~= nil and self.storeItem ~= nil then
            local configsToApply = ShopConfigScreenExtension.pendingConfigurations
            
            -- Salva i default originali
            ShopConfigScreenExtension.originalDefaultConfigIds = self.storeItem.defaultConfigurationIds
            
            -- Crea una copia dei default e modifica con le nostre configurazioni
            local newDefaults = {}
            if self.storeItem.defaultConfigurationIds ~= nil then
                for k, v in pairs(self.storeItem.defaultConfigurationIds) do
                    newDefaults[k] = v
                end
            end
            
            -- Applica le nostre configurazioni come nuovi default
            for configName, configIndex in pairs(configsToApply) do
                newDefaults[configName] = configIndex
            end
            
            -- Sostituisci i default dello storeItem
            self.storeItem.defaultConfigurationIds = newDefaults
            
            -- Cancella le configurazioni pending
            ShopConfigScreenExtension.pendingConfigurations = nil
        end
    end)

-- Hook onClose per rimuovere l'azione input e ripristinare i default originali
ShopConfigScreen.onClose = Utils.appendedFunction(ShopConfigScreen.onClose,
    function(self)
        ShopConfigScreenExtension:unregisterActionEvent()
        
        -- Ripristina i default originali dello storeItem se necessario
        if ShopConfigScreenExtension.originalDefaultConfigIds ~= nil and self.storeItem ~= nil then
            self.storeItem.defaultConfigurationIds = ShopConfigScreenExtension.originalDefaultConfigIds
            ShopConfigScreenExtension.originalDefaultConfigIds = nil
            print("ShopFavorites: Original defaults restored in onClose")
        end
    end)
