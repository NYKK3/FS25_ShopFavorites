VehicleExtension = {}

-- Aggiunge informazioni sui preferiti nel menu di informazioni del veicolo
function VehicleExtension:showInfo(box)
    local playerFarm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId)
    if playerFarm == nil then return end

    -- Verifica se il veicolo è nei preferiti usando xmlFilename
    if g_currentMission.FavoriteManager ~= nil and self.xmlFilename ~= nil then
        if g_currentMission.FavoriteManager:isFavoriteByXml(self.xmlFilename) then
            box:addLine("", "")
            box:addLine(g_i18n:getText("sf_is_favorite"), g_i18n:getText("ui_yes"))
        end
    end
end

Vehicle.showInfo = Utils.appendedFunction(Vehicle.showInfo, VehicleExtension.showInfo)
