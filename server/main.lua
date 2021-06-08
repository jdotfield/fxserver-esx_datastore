local DataStores, DataStoresIndex, SharedDataStores = {}, {}, {}
ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

MySQL.ready(function()
	local result = MySQL.Sync.fetchAll('SELECT * FROM datastore')

	for i=1, #result, 1 do
		local name, shared = result[i].name, result[i].shared

        if shared == 0 then
			table.insert(DataStoresIndex, name)
			DataStores[name] = {}
        else
            local result2 = MySQL.Sync.fetchAll('SELECT * FROM datastore_data WHERE name = @name', {
                ['@name'] = name
            })

            local data

            if #result2 == 0 then
				MySQL.Sync.execute('INSERT INTO datastore_data (name, owner, data) VALUES (@name, NULL, \'{}\')', {
					['@name'] = name
				})

				data = {}
			else
				data = json.decode(result2[1].data)
			end

			SharedDataStores[name] = CreateDataStore(name, nil, data)
        end
	end
end)

function GetDataStore(name, owner)
    if not DataStores[name][owner] then
		MySQL.Sync.fetchAll('SELECT data FROM datastore_data WHERE name = @name AND owner = @owner LIMIT 1', {
            ['@name'] = name,
            ['@owner'] = owner
        }, function(result)
			if result[1] then
				DataStores[name][owner] = CreateDataStore(name, owner, json.decode(result[1].data))
			else
				MySQL.Sync.execute('INSERT INTO datastore_data (name, owner, data) VALUES (@name, @owner, \'{}\')', {
					['@name'] = name,
            		['@owner'] = owner
				}, function(result)
					DataStores[name][owner] = CreateDataStore(name, owner, {})
				end)
			end
		end)
    end

    return DataStores[name][owner]
end

function GetDataStoreOwners(name)
	local identifiers = {}

    for owner, _ in pairs(DataStores[name]) do
        table.insert(identifiers, owner)
    end

	return identifiers
end

function GetSharedDataStore(name)
	return SharedDataStores[name]
end

AddEventHandler('esx_datastore:getDataStore', function(name, owner, cb)
	cb(GetDataStore(name, owner))
end)

AddEventHandler('esx_datastore:getDataStoreOwners', function(name, cb)
	cb(GetDataStoreOwners(name))
end)

AddEventHandler('esx_datastore:getSharedDataStore', function(name, cb)
	cb(GetSharedDataStore(name))
end)

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    MySQL.Async.fetchAll('SELECT name, data FROM datastore_data WHERE owner = @owner', {
        ['@owner'] = xPlayer.identifier
    }, function(result)
        for i=1, #result, 1 do
			local name, data = result[i].name, result[i].data == nil and {} or json.decode(result[i].data)
			local dataStore = CreateDataStore(name, xPlayer.identifier, data)
            DataStores[name][xPlayer.identifier] = dataStore
        end
    end)
end)

AddEventHandler('esx:playerDropped', function(playerId, reason)
    local xPlayer = ESX.GetPlayerFromId(playerId)

	for i=1, #DataStoresIndex, 1 do
		local name = DataStoresIndex[i]

        if DataStores[name][xPlayer.identifier] then
            DataStores[name][xPlayer.identifier] = nil
        end
	end
end)
