ChangeVehicleConfigEventExtension = {}

local function getExecutionSide()
    if g_server ~= nil and g_client ~= nil then
        return "server+client"
    elseif g_server ~= nil then
        return "server"
    elseif g_client ~= nil then
        return "client"
    end

    return "local"
end

local function getFarmMoneyById(farmId)
    if farmId == nil or g_farmManager == nil then
        return "nil"
    end

    local farm = g_farmManager:getFarmById(farmId)
    if farm == nil or farm.money == nil then
        return "nil"
    end

    return tostring(farm.money)
end

local function getFallbackConfigPrice(vehicle, vehicleBuyData)
    if vehicle == nil or vehicleBuyData == nil or vehicleBuyData.storeItem == nil then
        return 0
    end

    local storeItem = vehicleBuyData.storeItem
    local requestedConfigurations = vehicleBuyData.configurations or {}
    local currentBoughtConfigurations = vehicle.boughtConfigurations or {}
    local fallbackPrice = 0

    if storeItem.configurations == nil then
        return 0
    end

    for configName, requestedConfigId in pairs(requestedConfigurations) do
        local hasBoughtConfig = currentBoughtConfigurations[configName] ~= nil
            and currentBoughtConfigurations[configName][requestedConfigId] == true

        if not hasBoughtConfig then
            local configItems = storeItem.configurations[configName]
            local configItem = configItems ~= nil and configItems[requestedConfigId] or nil
            local configPrice = configItem ~= nil and tonumber(configItem.price) or 0
            fallbackPrice = fallbackPrice + configPrice
        end
    end

    return fallbackPrice
end

local function logEventState(label, event)
    ShopFavoritesDebug.logObject(label, event)

    if event ~= nil and event.buyVehicleData ~= nil then
        ShopFavoritesDebug.logObject(label .. ".buyVehicleData", event.buyVehicleData)
        ShopFavoritesDebug.log(label .. ".buyVehicleData.configurations "
            .. ShopFavoritesDebug.describeTableShallow(event.buyVehicleData.configurations))
        ShopFavoritesDebug.log(label .. ".buyVehicleData.boughtConfigurations "
            .. ShopFavoritesDebug.describeTableShallow(event.buyVehicleData.boughtConfigurations))
    end

    if event ~= nil and event.vehicleBuyData ~= nil then
        ShopFavoritesDebug.logObject(label .. ".vehicleBuyData", event.vehicleBuyData)
        ShopFavoritesDebug.log(label .. ".vehicleBuyData.configurations "
            .. ShopFavoritesDebug.describeTableShallow(event.vehicleBuyData.configurations))
        ShopFavoritesDebug.log(label .. ".vehicleBuyData.boughtConfigurations "
            .. ShopFavoritesDebug.describeTableShallow(event.vehicleBuyData.boughtConfigurations))
    end
end

if ChangeVehicleConfigEvent ~= nil then
    if ChangeVehicleConfigEvent.writeStream ~= nil then
        ChangeVehicleConfigEvent.writeStream = Utils.overwrittenFunction(ChangeVehicleConfigEvent.writeStream,
            function(self, superFunc, streamId, connection)
                logEventState("ChangeVehicleConfigEvent.writeStream", self)
                return superFunc(self, streamId, connection)
            end)
    end

    if ChangeVehicleConfigEvent.readStream ~= nil then
        ChangeVehicleConfigEvent.readStream = Utils.overwrittenFunction(ChangeVehicleConfigEvent.readStream,
            function(self, superFunc, streamId, connection)
                local result = superFunc(self, streamId, connection)
                logEventState("ChangeVehicleConfigEvent.readStream", self)
                return result
            end)
    end

    if ChangeVehicleConfigEvent.run ~= nil then
        ChangeVehicleConfigEvent.run = Utils.overwrittenFunction(ChangeVehicleConfigEvent.run,
            function(self, superFunc, connection)
                local vehicleBuyData = self.vehicleBuyData or self.buyVehicleData
                local farmId = vehicleBuyData ~= nil and vehicleBuyData.ownerFarmId or nil
                if g_server ~= nil
                    and vehicleBuyData ~= nil
                    and self.vehicle ~= nil
                    and (vehicleBuyData.price == nil or vehicleBuyData.price == 0) then
                    local fallbackPrice = getFallbackConfigPrice(self.vehicle, vehicleBuyData)
                    if fallbackPrice > 0 then
                        ShopFavoritesDebug.log(string.format(
                            "ChangeVehicleConfigEvent.run applying fallback price=%s for storeItem=%s",
                            tostring(fallbackPrice),
                            tostring(vehicleBuyData.storeItem ~= nil and vehicleBuyData.storeItem.name or "nil")
                        ))
                        vehicleBuyData.price = fallbackPrice
                    end
                end

                local price = vehicleBuyData ~= nil and vehicleBuyData.price or nil
                local moneyBefore = getFarmMoneyById(farmId)

                ShopFavoritesDebug.activeChangeVehicleConfig = {
                    farmId = farmId,
                    price = price,
                    side = getExecutionSide()
                }

                ShopFavoritesDebug.log(string.format(
                    "ChangeVehicleConfigEvent.run before side=%s farmId=%s price=%s moneyBefore=%s",
                    tostring(getExecutionSide()),
                    tostring(farmId),
                    tostring(price),
                    tostring(moneyBefore)
                ))
                logEventState("ChangeVehicleConfigEvent.run", self)
                local result = superFunc(self, connection)

                ShopFavoritesDebug.log(string.format(
                    "ChangeVehicleConfigEvent.run after side=%s farmId=%s price=%s moneyAfter=%s",
                    tostring(getExecutionSide()),
                    tostring(farmId),
                    tostring(price),
                    tostring(getFarmMoneyById(farmId))
                ))

                ShopFavoritesDebug.activeChangeVehicleConfig = nil

                return result
            end)
    end
end

if FSBaseMission ~= nil and FSBaseMission.addMoney ~= nil then
    FSBaseMission.addMoney = Utils.overwrittenFunction(FSBaseMission.addMoney,
        function(self, superFunc, amount, farmId, moneyType, ...)
            local context = ShopFavoritesDebug.activeChangeVehicleConfig
            if context ~= nil then
                ShopFavoritesDebug.log(string.format(
                    "FSBaseMission.addMoney side=%s amount=%s farmId=%s moneyType=%s before=%s contextPrice=%s",
                    tostring(getExecutionSide()),
                    tostring(amount),
                    tostring(farmId),
                    tostring(moneyType),
                    tostring(getFarmMoneyById(farmId)),
                    tostring(context.price)
                ))
            end

            local result = superFunc(self, amount, farmId, moneyType, ...)

            if context ~= nil then
                ShopFavoritesDebug.log(string.format(
                    "FSBaseMission.addMoney after side=%s amount=%s farmId=%s after=%s",
                    tostring(getExecutionSide()),
                    tostring(amount),
                    tostring(farmId),
                    tostring(getFarmMoneyById(farmId))
                ))
            end

            return result
        end)
end
