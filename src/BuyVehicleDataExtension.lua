BuyVehicleDataExtension = {}

-- Estensione di BuyVehicleData per gestire i preferiti
-- Nota: Con il nuovo sistema basato su xmlFilename, questo file e' principalmente
-- per compatibilita' e per debug del flusso di acquisto.

function BuyVehicleDataExtension:setFavoriteXml(xmlFilename)
    self.favoriteXml = xmlFilename
end

function BuyVehicleDataExtension:writeStream(streamId, connection)
    streamWriteBool(streamId, self.favoriteXml ~= nil)
    if self.favoriteXml then
        streamWriteString(streamId, self.favoriteXml or "")
    end
end

function BuyVehicleDataExtension:readStream(streamId, connection)
    if streamReadBool(streamId) then
        self.favoriteXml = streamReadString(streamId)
    else
        self.favoriteXml = nil
    end
end

function BuyVehicleDataExtension.onBought(buyVehicleData, loadedVehicles, loadingState, callbackArguments)
    print("ShopFavorites: BuyVehicleData.onBought loadingState=" .. tostring(loadingState)
        .. " loadedVehicles=" .. tostring(loadedVehicles and #loadedVehicles or 0))
end

function BuyVehicleDataExtension.isValid(buyVehicleData, superFunc)
    local isValid = superFunc(buyVehicleData)
    print("ShopFavorites: BuyVehicleData.isValid result=" .. tostring(isValid)
        .. " storeItem=" .. tostring(buyVehicleData.storeItem and buyVehicleData.storeItem.name)
        .. " ownerFarmId=" .. tostring(buyVehicleData.ownerFarmId)
        .. " leaseVehicle=" .. tostring(buyVehicleData.leaseVehicle)
        .. " price=" .. tostring(buyVehicleData.price))
    return isValid
end

function BuyVehicleDataExtension.buy(buyVehicleData, superFunc, storePlaces, usedStorePlaces, callback, callbackTarget, callbackArguments)
    print("ShopFavorites: BuyVehicleData.buy storeItem=" .. tostring(buyVehicleData.storeItem and buyVehicleData.storeItem.name)
        .. " ownerFarmId=" .. tostring(buyVehicleData.ownerFarmId)
        .. " leaseVehicle=" .. tostring(buyVehicleData.leaseVehicle)
        .. " price=" .. tostring(buyVehicleData.price)
        .. " storePlaces=" .. tostring(storePlaces ~= nil)
        .. " usedStorePlaces=" .. tostring(usedStorePlaces ~= nil))
    return superFunc(buyVehicleData, storePlaces, usedStorePlaces, callback, callbackTarget, callbackArguments)
end

function BuyVehicleDataExtension:setOwnerFarmId(ownerFarmId)
    print("ShopFavorites: BuyVehicleData.setOwnerFarmId ownerFarmId=" .. tostring(ownerFarmId))
end

function BuyVehicleDataExtension:setLeaseVehicle(leaseVehicle)
    print("ShopFavorites: BuyVehicleData.setLeaseVehicle leaseVehicle=" .. tostring(leaseVehicle))
end

function BuyVehicleDataExtension:setPrice(price)
    print("ShopFavorites: BuyVehicleData.setPrice price=" .. tostring(price))
end

function BuyVehicleDataExtension.updatePrice(buyVehicleData, superFunc)
    superFunc(buyVehicleData)
    print("ShopFavorites: BuyVehicleData.updatePrice price=" .. tostring(buyVehicleData.price)
        .. " leaseVehicle=" .. tostring(buyVehicleData.leaseVehicle)
        .. " storeItem=" .. tostring(buyVehicleData.storeItem and buyVehicleData.storeItem.name))
end

BuyVehicleData.setFavoriteXml = BuyVehicleDataExtension.setFavoriteXml
BuyVehicleData.writeStream = Utils.appendedFunction(BuyVehicleData.writeStream, BuyVehicleDataExtension.writeStream)
BuyVehicleData.readStream = Utils.appendedFunction(BuyVehicleData.readStream, BuyVehicleDataExtension.readStream)
BuyVehicleData.onBought = Utils.prependedFunction(BuyVehicleData.onBought, BuyVehicleDataExtension.onBought)
BuyVehicleData.isValid = Utils.overwrittenFunction(BuyVehicleData.isValid, BuyVehicleDataExtension.isValid)
BuyVehicleData.buy = Utils.overwrittenFunction(BuyVehicleData.buy, BuyVehicleDataExtension.buy)
BuyVehicleData.setOwnerFarmId = Utils.appendedFunction(BuyVehicleData.setOwnerFarmId, BuyVehicleDataExtension.setOwnerFarmId)
BuyVehicleData.setLeaseVehicle = Utils.appendedFunction(BuyVehicleData.setLeaseVehicle, BuyVehicleDataExtension.setLeaseVehicle)
BuyVehicleData.setPrice = Utils.appendedFunction(BuyVehicleData.setPrice, BuyVehicleDataExtension.setPrice)
BuyVehicleData.updatePrice = Utils.overwrittenFunction(BuyVehicleData.updatePrice, BuyVehicleDataExtension.updatePrice)
