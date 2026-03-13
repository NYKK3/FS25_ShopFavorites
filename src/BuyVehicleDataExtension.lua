BuyVehicleDataExtension = {}

-- Estensione di BuyVehicleData per gestire i preferiti
-- Nota: Con il nuovo sistema basato su xmlFilename, questo file è principalmente
-- per compatibilità e per future estensioni (es. rimuovere dai preferiti dopo l'acquisto)

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
    -- Con il nuovo sistema, i preferiti sono basati su xmlFilename dello storeItem
    -- quindi non è necessario aggiungere il veicolo ai preferiti dopo l'acquisto
    -- Il preferito rimane nella lista per futuri acquisti
end

BuyVehicleData.setFavoriteXml = BuyVehicleDataExtension.setFavoriteXml
BuyVehicleData.writeStream = Utils.appendedFunction(BuyVehicleData.writeStream, BuyVehicleDataExtension.writeStream)
BuyVehicleData.readStream = Utils.appendedFunction(BuyVehicleData.readStream, BuyVehicleDataExtension.readStream)
BuyVehicleData.onBought = Utils.prependedFunction(BuyVehicleData.onBought, BuyVehicleDataExtension.onBought)
