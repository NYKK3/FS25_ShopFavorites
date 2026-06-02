ShopFavoritesDebug = {
    enabled = false
}

function ShopFavoritesDebug.log(message)
    if ShopFavoritesDebug.enabled then
        print(string.format("ShopFavorites: %s", tostring(message)))
    end
end
