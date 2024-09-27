AddCSLuaFile("autorun/client/cl_money.lua")
AddCSLuaFile("autorun/sh_money.lua")

include("autorun/sh_money.lua")

local DATA_FILE = "moneySaveData.txt"

function LoadDataFromFile()
	-- Create the data file if it doesn't exist
	if not file.Exists(DATA_FILE, "DATA") then
		file.Write(DATA_FILE, "")
	end

	local content = file.Read(DATA_FILE, "DATA") -- read saved data
	return util.JSONToTable(content or "") or {} -- json decode it, default to empty table
end

function SaveDataToFile(data)
	local content = util.TableToJSON(data) -- json encode it
	file.Write(DATA_FILE, content) -- write to file
end

local playerData = LoadDataFromFile()

hook.Add( "PlayerInitialSpawn","moneyaddon-on-join",function(client)
	if playerData[client:AccountID()] then -- if the player has data, load it
		client:SetNWInt("BankMoney",data[client:AccountID()].Bank)
		client:SetNWInt("Money",data[client:AccountID()].Wallet)
	else -- otherwise create and save data for them
		client:SetNWInt("Money",100)
		client:SetNWInt("BankMoney",0)
		playerData[client:AccountID()] = {Bank = 0, Wallet = 100}
		SaveDataToFile(playerData)
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
	playerData[client:AccountID()] = {Bank = client:GetNWInt("BankMoney"), Wallet = client:GetNWInt("Money")}
	SaveDataToFile(playerData)
end)