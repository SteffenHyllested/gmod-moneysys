AddCSLuaFile("autorun/client/cl_money.lua")
AddCSLuaFile("autorun/sh_money.lua")

include("autorun/sh_money.lua")

hook.Add( "PlayerInitialSpawn","moneyaddon-on-join",function(client)
	client:SetNWInt("Money",100)
	client:SetNWInt("BankMoney",0)

	-- Load sava data if there, otherwise create it
	if not file.Exists("moneySaveData.txt", "DATA") then
		file.Write("moneySaveData.txt", "") -- Create file
	end

	local content = file.Read("moneySaveData.txt", "DATA") -- read saved data
	local data = util.JSONToTable(content or "") or {} -- json decode it, default to empty table
	
	if data[client:AccountID()] then -- if the player has data, load it
		client:SetNWInt("BankMoney",data[client:AccountID()].Bank)
		client:SetNWInt("Money",data[client:AccountID()].Wallet)
	else -- otherwise create and save data for them
		data[client:AccountID()] = {Bank = 0, Wallet = 100}
		local json = util.TableToJSON(data)
		file.Write("moneySaveData.txt",json)
	end
end)

util.AddNetworkString("TransferMoney")
net.Receive("TransferMoney",function(length,client)
	local transferRate = net.ReadInt(2)
	local transferAmount = net.ReadInt(32)

	if not (transferRate == -1 or transferRate == 1) then return end -- Just to avoid shenanigans with people trying to exploit this
	local moneyReq = transferRate*transferAmount
	local bankReq = -transferRate*transferAmount

	if moneyReq > client:GetNWInt("Money") then return end -- Not enough money in wallet
	if bankReq > client:GetNWInt("BankMoney") then return end -- Not enough money in bank
	-- We check both so I don't have to branch off depending on whether it's a deposit or withdrawal

	client:SetNWInt("Money",client:GetNWInt("Money") + bankReq)
	client:SetNWInt("BankMoney",client:GetNWInt("BankMoney") + moneyReq)
	-- viola

	-- Update save file
	local content = file.Read("moneySaveData.txt", "THIRDPARTY") -- read saved data
	local data = util.JSONToTable(content or "") or {} -- json decode it, default to empty table
	data[client:AccountID()] = {Bank = client:GetNWInt("BankMoney"), Wallet = client:GetNWInt("Money")}
	local json = util.TableToJSON(data)
	file.Write("moneySaveData.txt",json)
end)

print("Server")