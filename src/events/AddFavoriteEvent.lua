-- Evento per aggiungere un veicolo ai preferiti (per multiplayer)
AddFavoriteEvent = {}
local AddFavoriteEvent_mt = Class(AddFavoriteEvent, Event)

InitEventClass(AddFavoriteEvent, "AddFavoriteEvent")

function AddFavoriteEvent.emptyNew()
    return Event.new(AddFavoriteEvent_mt)
end

function AddFavoriteEvent.new(xmlFilename, name, category, brand)
    local self = AddFavoriteEvent.emptyNew()
    self.xmlFilename = xmlFilename
    self.name = name
    self.category = category
    self.brand = brand
    return self
end

function AddFavoriteEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.xmlFilename or "")
    streamWriteString(streamId, self.name or "")
    streamWriteString(streamId, self.category or "")
    streamWriteString(streamId, self.brand or "")
end

function AddFavoriteEvent:readStream(streamId, connection)
    self.xmlFilename = streamReadString(streamId)
    self.name = streamReadString(streamId)
    self.category = streamReadString(streamId)
    self.brand = streamReadString(streamId)
    self:run(connection)
end

function AddFavoriteEvent:run(connection)
    if g_currentMission.FavoriteManager ~= nil then
        -- Verifica se già presente
        if not g_currentMission.FavoriteManager:isFavoriteByXml(self.xmlFilename) then
            g_currentMission.FavoriteManager.favorites[#g_currentMission.FavoriteManager.favorites + 1] = {
                xmlFilename = self.xmlFilename,
                name = self.name,
                category = self.category,
                brand = self.brand
            }
            -- Salva i preferiti
            g_currentMission.FavoriteManager:saveToXMLFile()
        end
    end
end
