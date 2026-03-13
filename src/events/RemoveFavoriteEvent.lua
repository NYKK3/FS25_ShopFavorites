-- Evento per rimuovere un veicolo dai preferiti (per multiplayer)
RemoveFavoriteEvent = {}
local RemoveFavoriteEvent_mt = Class(RemoveFavoriteEvent, Event)

InitEventClass(RemoveFavoriteEvent, "RemoveFavoriteEvent")

function RemoveFavoriteEvent.emptyNew()
    return Event.new(RemoveFavoriteEvent_mt)
end

function RemoveFavoriteEvent.new(xmlFilename)
    local self = RemoveFavoriteEvent.emptyNew()
    self.xmlFilename = xmlFilename
    return self
end

function RemoveFavoriteEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.xmlFilename or "")
end

function RemoveFavoriteEvent:readStream(streamId, connection)
    self.xmlFilename = streamReadString(streamId)
    self:run(connection)
end

function RemoveFavoriteEvent:run(connection)
    if g_currentMission.FavoriteManager ~= nil then
        for i, favorite in ipairs(g_currentMission.FavoriteManager.favorites) do
            if favorite.xmlFilename == self.xmlFilename then
                table.remove(g_currentMission.FavoriteManager.favorites, i)
                -- Salva i preferiti
                g_currentMission.FavoriteManager:saveToXMLFile()
                break
            end
        end
    end
end
