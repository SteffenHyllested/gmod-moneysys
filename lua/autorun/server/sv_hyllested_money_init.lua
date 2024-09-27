AddCSLuaFile("autorun/client/cl_hyllested_money_init.lua")

local TABLE_NAME = "HyllestedMoney:PlayerData" // Note there are quotes inside the string as the table name includes a colon

-- Create the table if it doesn't exist
if not sql.TableExists(TABLE_NAME) then
	sql.Begin()
		sql.Query("CREATE TABLE `" .. TABLE_NAME .. "`( id int , bank int, wallet int )")
	sql.Commit()
end

function SavePlayerData( client )
	local bank, wallet = client:GetNWInt("BankMoney"), client:GetNWInt("Money")
	local query = string.format("UPDATE `%s` SET bank=%d, wallet=%d WHERE id=%q", TABLE_NAME, bank, wallet, client:SteamID64() )
	sql.Begin()
		sql.Query(query)
	sql.Commit()
end

function LoadPlayerData( client )
	local query = string.format("SELECT bank, wallet FROM `%s` WHERE id=%q", TABLE_NAME, client:SteamID64() )
	local playerData = sql.QueryRow("SELECT bank, wallet FROM `" .. TABLE_NAME .. "` WHERE id=" .. client:SteamID64() ) // This structuring could be prone to SQL injection, however given the nature of the values being concatenated, it is safe here.

	if not playerData then
		sql.Begin()
			local query = string.format("INSERT INTO `%s` ( id, bank, wallet ) VALUES ( %q, %d, %d )", TABLE_NAME, client:SteamID64(), 0, 100 )
			sql.Query( query )
		sql.Commit()
		client:SetNWInt( "Money", 100 )
		client:SetNWInt( "BankMoney", 0 )
	else
		client:SetNWInt( "Money", tonumber(playerData.wallet) )
		client:SetNWInt( "BankMoney", tonumber(playerData.bank) )
	end
end

hook.Add( "PlayerInitialSpawn","moneyaddon-on-join",function(client)
	LoadPlayerData(client)
end)

util.AddNetworkString("HyllestedMoney:TransferMoney")
net.Receive("HyllestedMoney:TransferMoney",function(length,client)
	local transferRate = net.ReadInt(2)
	local transferAmount = net.ReadInt(32)

	if not (transferRate == -1 or transferRate == 1) then return end -- Just to avoid shenanigans with people trying to exploit this
	local moneyReq = transferRate*transferAmount
	local bankReq = -transferRate*transferAmount

	print(moneyReq)
	print(client:GetNWInt("Money"))

	if moneyReq > client:GetNWInt("Money") then return end -- Not enough money in wallet
	if bankReq > client:GetNWInt("BankMoney") then return end -- Not enough money in bank
	-- We check both so I don't have to branch off depending on whether it's a deposit or withdrawal

	client:SetNWInt("Money",client:GetNWInt("Money") + bankReq)
	client:SetNWInt("BankMoney",client:GetNWInt("BankMoney") + moneyReq)
	-- viola

	-- Update save file
	SavePlayerData(client)
end)