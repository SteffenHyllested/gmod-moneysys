include("shared.lua")
local imgui = include("libs/imgui.lua")

local MainFontData = {font = "Arial",size = 36,weight = 1000,}
local SmallMainFontData = {font = "Arial",size = 20,weight = 1500,}
surface.CreateFont("HyllestedMoney:MainFont", MainFontData)
surface.CreateFont("HyllestedMoney:MainFontSmall", SmallMainFontData)

function ENT:Initialize()
    self.Increment = 1
end

function ENT:DrawTranslucent()
    local client = LocalPlayer()

    if imgui.Entity3D2D(self, Vector(1, -20, 24), Angle(0, 90, 85), 0.1) then // These values would need to be adjusted depending on the model used.
            // Drawing the monitor backdrop
            surface.SetDrawColor(50,50,50,255)
            surface.DrawRect(0,0,400,230)

            // ATM title and current balance
            draw.DrawText("ATM - MoneyBank™", "HyllestedMoney:MainFont",200,20, Color( 255,255,255, 255 ),TEXT_ALIGN_CENTER)
            draw.DrawText("Current Balance:", "HyllestedMoney:MainFontSmall",52,66, Color( 255,255,255, 255 ),TEXT_ALIGN_LEFT)
            draw.DrawText(string.format("$%.2f",client:GetNWInt("BankMoney")), "HyllestedMoney:MainFont",348,56, Color( 100,255,150, 255 ),TEXT_ALIGN_RIGHT)

            // This draws the left and right arrow buttons for adjusting amount deposited/withdrawn
            surface.SetDrawColor(35,35,35,255)
            surface.DrawRect(52,100,30,50)
            surface.DrawRect(318,100,30,50)

            // This draws the arrows themselves in the buttons drawn above
            draw.DrawText("<", "HyllestedMoney:MainFont", 58, 108, Color( 255, 255, 255, 255 ), TEXT_ALIGN_LEFT)
            draw.DrawText(">", "HyllestedMoney:MainFont", 342, 108, Color( 255, 255, 255, 255 ), TEXT_ALIGN_RIGHT)

            // This fills the space between the 2 arrow buttons
            surface.SetDrawColor(25,25,25,255)
            surface.DrawRect(82,100,236,50)

            // This draws the current amount being deposited/withdrawn into the space drawn above
            draw.DrawText(string.format("$%.2f",self.Increment),"HyllestedMoney:MainFont",200,108,Color(255,255,255,255), TEXT_ALIGN_CENTER)

            // This draws the deposit and withdraw buttons
            surface.SetDrawColor(20,120,60,255)
            surface.DrawRect(52,160,144,50)
            surface.DrawRect(204,160,144,50)

            // This draws the text for the deposit and withdraw buttons
            draw.DrawText("Deposit","HyllestedMoney:MainFontSmall",124,175,Color(255,255,255,255), TEXT_ALIGN_CENTER)
            draw.DrawText("Withdraw","HyllestedMoney:MainFontSmall",276,175,Color(255,255,255,255), TEXT_ALIGN_CENTER)

            // If the player is pressing E
            if imgui.IsPressed() then
                local transferRate = 0 // Denotes what kind of, if any, transfer is being done.
                if imgui.IsHovering(52,160,144,50) then // Deposit button is being pressed
                    transferRate = 1
                elseif imgui.IsHovering(204,160,144,50) then // Withdraw button is being pressed
                    transferRate = -1
                elseif imgui.IsHovering(52,100,30,50) then // Left arrow button is being pressed
                    self.Increment = math.max(self.Increment - 1,1)
                elseif imgui.IsHovering(318,100,30,50) then // Right arrow button is being pressed
                    self.Increment = self.Increment + 1
                end

                if transferRate ~= 0 then
                    net.Start("TransferMoney")
                        net.WriteInt(transferRate,2)
                        net.WriteInt(self.Increment,32)
                    net.SendToServer()
                end
            end
        imgui.End3D2D()
    end
end

function ENT:Draw()
    self:DrawModel()
end