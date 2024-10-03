include("shared.lua")
local imgui = include("libs/imgui.lua")

local TRANSFER_NONE = nil
local TRANSFER_WITHDRAW = 0
local TRANSFER_DEPOSIT = 1

local ATM_UI_WIDTH = 400
local ATM_UI_HEIGHT = 230

local ATM_UI_PADDING_Y = 20
local ATM_UI_PADDING_X = 50
local ATM_LINE_PADDING = 8
local ATM_BUTTON_PADDING = 8

local ATM_ARROW_BUTTON_WIDTH = 50
local ATM_ARROW_BUTTON_HEIGHT = 50

local ATM_TRANSFER_BUTTON_HEIGHT = 50

local WHITE = Color(255, 255, 255, 255)
local GREEN = Color(100, 200, 125, 255)
local GREEN_DARK = Color(50, 150, 75, 255)
local DARK_GREY = Color(25, 25, 25, 255)
local ATM_BACKDROP_COLOR = Color(50, 50, 50, 255)
local ATM_GREY_BUTTON_COLOR = Color(35, 35, 35, 255)
local ATM_GREY_BUTTON_COLOR_DARK = Color(30, 30, 30, 255)

local FONT_HEIGHT = draw.GetFontHeight("HyllestedMoney:MainFont")
local FONT_HEIGHT_SMALL = draw.GetFontHeight("HyllestedMoney:MainFontSmall")

function ENT:Initialize()
    self.Increment = 10
end

function ENT:DrawTranslucent()
    local client = LocalPlayer()

    if imgui.Entity3D2D(self, Vector(1, -20.15, 24), Angle(0, 90, 85), 0.1) then // These values would need to be adjusted depending on the model used.
            local leftArrowPositionX = ATM_UI_PADDING_X
            local rightArrowPositionX = ATM_UI_WIDTH - ATM_UI_PADDING_X - ATM_ARROW_BUTTON_WIDTH
            local arrowPositionY = ATM_UI_PADDING_Y + FONT_HEIGHT * 2 + ATM_LINE_PADDING

            local depositButtonPositionX = ATM_UI_PADDING_X
            local withdrawButtonPositionX = ATM_UI_WIDTH / 2 + ATM_BUTTON_PADDING / 2
            local transferButtonPositionY = arrowPositionY + ATM_ARROW_BUTTON_HEIGHT + ATM_LINE_PADDING
            local transferButtonWidth = ATM_UI_WIDTH / 2 - ATM_UI_PADDING_X - ATM_BUTTON_PADDING / 2

            local isHoveringLeftArrow = imgui.IsHovering(leftArrowPositionX, arrowPositionY, ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT)
            local isHoveringRightArrow = imgui.IsHovering(rightArrowPositionX, arrowPositionY, ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT)
            local isHoveringDeposit = imgui.IsHovering(depositButtonPositionX,transferButtonPositionY, transferButtonWidth, ATM_TRANSFER_BUTTON_HEIGHT)
            local isHoveringWithdraw = imgui.IsHovering(withdrawButtonPositionX,transferButtonPositionY, transferButtonWidth, ATM_TRANSFER_BUTTON_HEIGHT)

            // Drawing the monitor backdrop
            surface.SetDrawColor(ATM_BACKDROP_COLOR)
            surface.DrawRect(0, 0, ATM_UI_WIDTH, ATM_UI_HEIGHT)

            // ATM title and current balance
            draw.DrawText("ATM - MoneyBank™", "HyllestedMoney:MainFont", ATM_UI_WIDTH / 2, ATM_UI_PADDING_Y, WHITE, TEXT_ALIGN_CENTER)
            draw.DrawText("Current Balance:", "HyllestedMoney:MainFontSmall", ATM_UI_PADDING_X, ATM_UI_PADDING_Y + FONT_HEIGHT + FONT_HEIGHT_SMALL / 2, WHITE, TEXT_ALIGN_LEFT)
            draw.DrawText(string.format("$%.2f",client:GetNWInt("bankBalance")), "HyllestedMoney:MainFont",ATM_UI_WIDTH - ATM_UI_PADDING_X, ATM_UI_PADDING_Y + FONT_HEIGHT, GREEN,TEXT_ALIGN_RIGHT)

            // This draws the left and right arrow buttons for adjusting amount deposited/withdrawn
            surface.SetDrawColor(isHoveringLeftArrow and ATM_GREY_BUTTON_COLOR_DARK or ATM_GREY_BUTTON_COLOR)
            surface.DrawRect(leftArrowPositionX, arrowPositionY, ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT)

            surface.SetDrawColor(isHoveringRightArrow and ATM_GREY_BUTTON_COLOR_DARK or ATM_GREY_BUTTON_COLOR)
            surface.DrawRect(rightArrowPositionX, arrowPositionY, ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT)

            // This draws the arrows themselves in the buttons drawn above
            draw.DrawText("<", "HyllestedMoney:MainFont", leftArrowPositionX + ATM_ARROW_BUTTON_WIDTH / 2, arrowPositionY + (ATM_ARROW_BUTTON_HEIGHT - FONT_HEIGHT) / 2, WHITE, TEXT_ALIGN_CENTER)
            draw.DrawText(">", "HyllestedMoney:MainFont", rightArrowPositionX + ATM_ARROW_BUTTON_WIDTH / 2, arrowPositionY + (ATM_ARROW_BUTTON_HEIGHT - FONT_HEIGHT) / 2, WHITE, TEXT_ALIGN_CENTER)

            // This fills the space between the 2 arrow buttons
            surface.SetDrawColor(DARK_GREY)
            surface.DrawRect(leftArrowPositionX + ATM_ARROW_BUTTON_WIDTH, arrowPositionY, rightArrowPositionX - leftArrowPositionX - ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT)

            // This draws the current amount being deposited/withdrawn into the space drawn above
            draw.DrawText(string.format("$%.2f",self.Increment),"HyllestedMoney:MainFont", ATM_UI_WIDTH / 2, arrowPositionY + (ATM_ARROW_BUTTON_HEIGHT - FONT_HEIGHT) / 2, WHITE, TEXT_ALIGN_CENTER)

            // This draws the deposit and withdraw buttons
            surface.SetDrawColor(isHoveringDeposit and GREEN_DARK or GREEN)
            surface.DrawRect(depositButtonPositionX, transferButtonPositionY, transferButtonWidth, ATM_TRANSFER_BUTTON_HEIGHT)

            surface.SetDrawColor(isHoveringWithdraw and GREEN_DARK or GREEN)
            surface.DrawRect(withdrawButtonPositionX, transferButtonPositionY, transferButtonWidth, ATM_TRANSFER_BUTTON_HEIGHT)

            // This draws the text for the deposit and withdraw buttons
            draw.DrawText("Deposit","HyllestedMoney:MainFontSmall",depositButtonPositionX + transferButtonWidth / 2, transferButtonPositionY + (ATM_TRANSFER_BUTTON_HEIGHT - FONT_HEIGHT_SMALL) / 2, WHITE, TEXT_ALIGN_CENTER)
            draw.DrawText("Withdraw","HyllestedMoney:MainFontSmall",withdrawButtonPositionX + transferButtonWidth / 2, transferButtonPositionY + (ATM_TRANSFER_BUTTON_HEIGHT - FONT_HEIGHT_SMALL) / 2, WHITE, TEXT_ALIGN_CENTER)

            // If the player is pressing E
            if imgui.IsPressed() then
                local increment = 1
                if input.IsShiftDown() then -- Hold shift to change increment to 10 instead of 1
                    increment = 10
                end

                if isHoveringLeftArrow then // Left arrow button is being pressed
                    self.Increment = math.max(self.Increment - increment, 1) -- Lower limit is 1
                elseif isHoveringRightArrow then // Right arrow button is being pressed
                    self.Increment = math.min(self.Increment + increment, 2^32) -- Upper limit is set by 32 bit limit
                end

                local transferType = (isHoveringDeposit and TRANSFER_DEPOSIT) or (isHoveringWithdraw and TRANSFER_WITHDRAW) or TRANSFER_NONE

                if transferType ~= TRANSFER_NONE then // A transfer is being done
                    net.Start("HyllestedMoney:TransferMoney")
                        net.WriteUInt(transferType,1)
                        net.WriteUInt(self.Increment,32)
                    net.SendToServer()
                end
            end
        imgui.End3D2D()
    end
end

function ENT:Draw()
    self:DrawModel()
end