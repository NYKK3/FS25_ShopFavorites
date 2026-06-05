ShopFavoritesDebug = {
    enabled = false
}

function ShopFavoritesDebug.log(message)
    if ShopFavoritesDebug.enabled then
        print(string.format("ShopFavorites: %s", tostring(message)))
    end
end

function ShopFavoritesDebug.describeValue(value)
    local valueType = type(value)

    if valueType == "table" then
        if value.getUniqueId ~= nil then
            return string.format("table(uid=%s)", tostring(value:getUniqueId()))
        end

        if value.name ~= nil then
            return string.format("table(name=%s)", tostring(value.name))
        end

        if value.storeItem ~= nil and value.storeItem.name ~= nil then
            return string.format("table(storeItem=%s)", tostring(value.storeItem.name))
        end

        return "table"
    end

    return tostring(value)
end

function ShopFavoritesDebug.describeTableShallow(tbl)
    if tbl == nil then
        return "nil"
    end

    local parts = {}
    for key, value in pairs(tbl) do
        local valueType = type(value)

        if valueType == "table" then
            local nested = {}
            for nestedKey, nestedValue in pairs(value) do
                if type(nestedKey) == "string" or type(nestedKey) == "number" then
                    table.insert(nested, string.format("%s=%s", tostring(nestedKey), tostring(nestedValue)))
                end
            end

            table.sort(nested)
            table.insert(parts, string.format("%s={%s}", tostring(key), table.concat(nested, ",")))
        else
            table.insert(parts, string.format("%s=%s", tostring(key), tostring(value)))
        end
    end

    table.sort(parts)
    return table.concat(parts, "; ")
end

function ShopFavoritesDebug.describeTableDeep(value, maxDepth, visited)
    maxDepth = maxDepth or 3
    visited = visited or {}

    local valueType = type(value)
    if valueType ~= "table" then
        return tostring(value)
    end

    if visited[value] then
        return "<recursive>"
    end

    if maxDepth <= 0 then
        return "<max-depth>"
    end

    visited[value] = true

    local parts = {}
    for key, childValue in pairs(value) do
        local keyType = type(key)
        if keyType == "string" or keyType == "number" then
            local childType = type(childValue)
            if childType == "table" then
                table.insert(parts, string.format("%s={%s}",
                    tostring(key),
                    ShopFavoritesDebug.describeTableDeep(childValue, maxDepth - 1, visited)))
            else
                table.insert(parts, string.format("%s=%s", tostring(key), tostring(childValue)))
            end
        end
    end

    visited[value] = nil

    table.sort(parts)
    return table.concat(parts, "; ")
end

function ShopFavoritesDebug.logObject(label, object)
    if not ShopFavoritesDebug.enabled or object == nil then
        return
    end

    local parts = {}
    for key, value in pairs(object) do
        local keyType = type(key)
        if keyType == "string" or keyType == "number" then
            table.insert(parts, string.format("%s=%s", tostring(key), ShopFavoritesDebug.describeValue(value)))
        end
    end

    table.sort(parts)
    ShopFavoritesDebug.log(string.format("%s %s", tostring(label), table.concat(parts, ", ")))
end
