local TABLE_NAME = "HyllestedMoney:PlayerData"

local TRANSFER_WITHDRAW = 0
local TRANSFER_DEPOSIT = 1

-- Create the table if it doesn't exist
if not sql.TableExists(TABLE_NAME) then
	sql.Begin()
		sql.Query("CREATE TABLE `" .. TABLE_NAME .. "`( id int , bank int )")
	sql.Commit()
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

hook.Add( "PlayerInitialSpawn","moneyaddon-on-join",function(client)
	LoadPlayerData(client)
end)

util.AddNetworkString("HyllestedMoney:TransferMoney")
net.Receive("HyllestedMoney:TransferMoney",function(length,client)
	local transferType = net.ReadUInt(1)
	local transferAmount = net.ReadUInt(32)

	local bankBalance = client:GetNWInt("bankBalance")

	if transferType == TRANSFER_DEPOSIT then -- Deposit
		if not client:canAfford(transferAmount) then return end -- Bail out as client has insufficient money in wallet

		client:addMoney(-transferAmount)
		client:SetNWInt("bankBalance",bankBalance + transferAmount)
	elseif transferType == TRANSFER_WITHDRAW then -- Withdrawal
		local sufficientBankBalance = bankBalance >= transferAmount
		if not sufficientBankBalance then return end -- Bail out as client has insufficient money in bank

		client:addMoney(transferAmount)
		client:SetNWInt("bankBalance",bankBalance - transferAmount)
	else
		print(string.format("Warning: Invalid transferType %d, expected %d or %d", transferType, TRANSFER_DEPOSIT, TRANSFER_WITHDRAW))
		return
	end

	SavePlayerData(client)
end)