BuyVehicleDataExtension = {}

-- Estensione di BuyVehicleData per gestire i preferiti
-- Nota: Con il nuovo sistema basato su xmlFilename, questo file serve
-- principalmente per compatibilita' del flusso di acquisto.

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

function BuyVehicleDataExtension.isValid(buyVehicleData, superFunc)
    return superFunc(buyVehicleData)
end

function BuyVehicleDataExtension.buy(buyVehicleData, superFunc, storePlaces, usedStorePlaces, callback, callbackTarget, callbackArguments)
    return superFunc(buyVehicleData, storePlaces, usedStorePlaces, callback, callbackTarget, callbackArguments)
end

function BuyVehicleDataExtension.updatePrice(buyVehicleData, superFunc)
    superFunc(buyVehicleData)
end

BuyVehicleData.setFavoriteXml = BuyVehicleDataExtension.setFavoriteXml
BuyVehicleData.writeStream = Utils.appendedFunction(BuyVehicleData.writeStream, BuyVehicleDataExtension.writeStream)
BuyVehicleData.readStream = Utils.appendedFunction(BuyVehicleData.readStream, BuyVehicleDataExtension.readStream)
BuyVehicleData.isValid = Utils.overwrittenFunction(BuyVehicleData.isValid, BuyVehicleDataExtension.isValid)
BuyVehicleData.buy = Utils.overwrittenFunction(BuyVehicleData.buy, BuyVehicleDataExtension.buy)
BuyVehicleData.updatePrice = Utils.overwrittenFunction(BuyVehicleData.updatePrice, BuyVehicleDataExtension.updatePrice)
