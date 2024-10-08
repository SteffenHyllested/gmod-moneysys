local TABLE_NAME = "HyllestedMoney:PlayerData"
local TRANSFERS_TABLE_NAME = "HyllestedMoney:Transfers"

local TRANSFER_WITHDRAW = 0
local TRANSFER_DEPOSIT = 1

-- For some reason, these Enums are nil by default
local NOTIFY_GENERIC = 0
local NOTIFY_ERROR = 1

local HISTORY_PAGE_SIZE = 4

local RATE_LIMIT = 3 -- How often the player can transfer money in seconds

local lastTransfer = {} -- Used for tracking when the player last did a transfer, to add a rate limit

-- Create the table if it doesn't exist
if not sql.TableExists(TABLE_NAME) then
	sql.Begin()
		sql.Query("CREATE TABLE `" .. TABLE_NAME .. "`( id int, bank int )")
	sql.Commit()
end

if not sql.TableExists(TRANSFERS_TABLE_NAME) then
	sql.Begin()
		sql.Query("CREATE TABLE `" .. TRANSFERS_TABLE_NAME .. "`( toId int, fromId int, amount int, timestamp int )")
	sql.Commit()
end

function IdHasEntry( id )
	local sanitizedId = sql.SQLStr(id)
	local query = string.format("SELECT id FROM `" .. TABLE_NAME .. "` WHERE id=" .. id)
	local result = sql.Query(query)

	if not result then
		return false -- Could be an error OR no data found
	end
	return true
end

function LogTransfer( to, from, amount )
	local query = string.format("INSERT INTO `%s` ( toId, fromId, amount, timestamp ) VALUES ( %s, %s, %d, %d )", TRANSFERS_TABLE_NAME, to, from, amount, os.time() )
	sql.Begin()
		local s = sql.Query(query)
	sql.Commit()
end

function FetchTransfers( id, page )
	local query = string.format("SELECT * FROM `%s` WHERE (toId=%s OR fromId=%s) ORDER BY timestamp DESC", TRANSFERS_TABLE_NAME, id, id)
	local result = sql.Query(query)

	local data = {}
	if not result then return data end

	local skipped = 0

	for i, transfer in pairs(result) do
		if tostring(transfer.toId) == id then
			if skipped >= page * HISTORY_PAGE_SIZE then
				table.insert(data,{
					amount = transfer.amount,
					toFrom = transfer.fromId,
					timestamp = transfer.timestamp,
				})
			else
				skipped = skipped + 1
			end
		end

		if #data >= HISTORY_PAGE_SIZE then break end

		if tostring(transfer.fromId) == id then
			if skipped >= page * HISTORY_PAGE_SIZE then
				table.insert(data,{
					amount = -transfer.amount,
					toFrom = transfer.toId,
					timestamp = transfer.timestamp,
				})
			else
				skipped = skipped + 1
			end
		end

		if #data >= HISTORY_PAGE_SIZE then break end
	end

	return data
end

function SavePlayerData( client )
	local bank = client:GetNWInt("bankBalance")
	local query = string.format("UPDATE `%s` SET bank=%d WHERE id=%q", TABLE_NAME, bank, client:SteamID64() )
	sql.Begin()
		sql.Query(query)
	sql.Commit()
end

function LoadPlayerData( client )
	local query = string.format("SELECT bank FROM `%s` WHERE id=%q", TABLE_NAME, client:SteamID64() )
	local playerData = sql.QueryRow("SELECT bank FROM `" .. TABLE_NAME .. "` WHERE id=" .. client:SteamID64() ) // This structuring could be prone to SQL injection, however given the nature of the values being concatenated, it is safe here.

	if not playerData then
		sql.Begin()
			local query = string.format("INSERT INTO `%s` ( id, bank ) VALUES ( %q, %d )", TABLE_NAME, client:SteamID64(), 0 )
			sql.Query( query )
		sql.Commit()
		client:SetNWInt( "bankBalance", 0 )
	else
		client:SetNWInt( "bankBalance", tonumber(playerData.bank) )
	end
end

hook.Add( "PlayerInitialSpawn", "hyllestedmoney-on-join", function(client)
	LoadPlayerData(client)
end)

hook.Add( "playerGetSalary", "hyllestedmoney-on-salary", function(client, amount)
	local bankBalance = client:GetNWInt("bankBalance")
	client:SetNWInt("bankBalance",bankBalance + amount)
	SavePlayerData(client)

	return false, string.format("Payday! $%d has been transferred to your bank account!", amount), 0
end)

util.AddNetworkString("HyllestedMoney:TransferMoney") -- Transfering funds to/from bank/wallet
util.AddNetworkString("HyllestedMoney:PlayerTransferMoney") -- Transfering funds between players
util.AddNetworkString("HyllestedMoney:RequestTransfers") -- Replicating transfer data to client

net.Receive("HyllestedMoney:TransferMoney",function(length,client)
	local transferType = net.ReadUInt(1)
	local transferAmount = net.ReadUInt(32)

	local bankBalance = client:GetNWInt("bankBalance")

	if transferType == TRANSFER_DEPOSIT then -- Deposit
		if not client:canAfford(transferAmount) then
			DarkRP.notify(client, NOTIFY_ERROR, 5, string.format("Insufficient funds to deposit $%d!", transferAmount))
			return -- Bail out as client has insufficient money in wallet
		end

		client:addMoney(-transferAmount)
		client:SetNWInt("bankBalance",bankBalance + transferAmount)
		DarkRP.notify(client, NOTIFY_GENERIC, 5, string.format("Successfully deposited $%d!", transferAmount))
	elseif transferType == TRANSFER_WITHDRAW then -- Withdrawal
		local sufficientBankBalance = bankBalance >= transferAmount
		if not sufficientBankBalance then
			DarkRP.notify(client, NOTIFY_ERROR, 5, string.format("Insufficient funds to withdraw $%d!", transferAmount))
			return -- Bail out as client has insufficient money in bank
		end

		client:addMoney(transferAmount)
		client:SetNWInt("bankBalance",bankBalance - transferAmount)
		DarkRP.notify(client, NOTIFY_GENERIC, 5, string.format("Successfully withdrew $%d!", transferAmount))
	else
		print(string.format("Warning: Invalid transferType %d, expected %d or %d", transferType, TRANSFER_DEPOSIT, TRANSFER_WITHDRAW))
		DarkRP.notify(client, NOTIFY_ERROR, 5, "An error occured while handling your transfer.")
		return
	end

	SavePlayerData(client)
end)

net.Receive("HyllestedMoney:PlayerTransferMoney", function(length, client)
	local transferTarget = net.ReadUInt64()
	local transferAmount = net.ReadUInt(32)

	local targetSanitized = sql.SQLStr(transferTarget)

	local bankBalance = client:GetNWInt("bankBalance")

	if bankBalance < transferAmount then
		DarkRP.notify(client, NOTIFY_ERROR, 5, string.format("Insufficient funds to transfer $%d!", transferAmount))
		return
	end
	
	-- NOTE: Add a rate limit here so that players can not spam this.

	if CurTime() - (lastTransfer[client:SteamID64()] or 0) < RATE_LIMIT then
		DarkRP.notify(client, NOTIFY_ERROR, 5, "Slow down! You're doing that too fast.")
		return
	end
	lastTransfer[client:SteamID64()] = CurTime()

	-- We must behave dependently on whether the target player is currently online
	local targetClient = player.GetBySteamID64(transferTarget)
	if targetClient then -- The player is online
		targetClient:SetNWInt("bankBalance", targetClient:GetNWInt("bankBalance") + transferAmount)
		client:SetNWInt("bankBalance", client:GetNWInt("bankBalance") - transferAmount)

		SavePlayerData(client)
		SavePlayerData(targetClient)

		DarkRP.notify(client, NOTIFY_GENERIC, 5, string.format("Successfully transfered $%d!", transferAmount))
		DarkRP.notify(targetClient, NOTIFY_GENERIC, 5, string.format("You received $%d from %s!", transferAmount, client:Name()))
	else -- There is no player online with that steamid
		local playerExists = IdHasEntry(transferTarget) -- Checks whether or not the steamid is in the databse, i.e. have they ever played
		if not playerExists then -- Don't allow transfers to players that have never played, as it was probably typo
			DarkRP.notify(client, NOTIFY_ERROR, 5, "No such account Id.")
			return
		end

		client:SetNWInt("bankBalance", client:GetNWInt("bankBalance") - transferAmount)
		SavePlayerData(client)

		local targetBalance = sql.Query(string.format("SELECT bank FROM `%s` WHERE id=%q", TABLE_NAME, targetSanitized))

		local query = string.format("UPDATE `%s` SET bank=%d WHERE id=%q", TABLE_NAME, targetBalance + transferAmount, targetSanitized )

		sql.Begin()
			sql.Query(query)
		sql.Commit()
		DarkRP.notify(client, NOTIFY_GENERIC, 5, string.format("Successfully transfered $%d!", transferAmount))
	end

	LogTransfer( targetSanitized, client:SteamID64(), transferAmount)
end)

net.Receive("HyllestedMoney:RequestTransfers", function( length, client )
	local entity = net.ReadEntity()
	local pageNumber = net.ReadUInt( 32 )
	local clientTime = net.ReadInt( 32 )

	local data = FetchTransfers( client:SteamID64(), pageNumber )

	net.Start( "HyllestedMoney:RequestTransfers" )
		net.WriteEntity( entity )
		net.WriteTable( data, true )
		net.WriteInt( os.difftime(os.time(), clientTime), 32 )
	net.Send( client )
end)