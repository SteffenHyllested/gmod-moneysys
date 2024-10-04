include("shared.lua")
local imgui = include("libs/imgui.lua")

local TRANSFER_NONE = nil
local TRANSFER_WITHDRAW = 0
local TRANSFER_DEPOSIT = 1

local FRONT_PAGE = 0
local MAIN_PAGE = 1
local ACCOUNT_PAGE = 2
local TRANSFER_PAGE = 3
local HISTORY_PAGE = 4

local ATM_UI_WIDTH = 400
local ATM_UI_HEIGHT = 230

local ATM_UI_PADDING_Y = 15
local ATM_UI_PADDING_X = 50
local ATM_LINE_PADDING = 5
local ATM_BUTTON_PADDING = 5

local ATM_ARROW_BUTTON_WIDTH = 35
local ATM_ARROW_BUTTON_HEIGHT = 35

local ATM_MENU_BUTTON_HEIGHT = 35

local ATM_TRANSFER_BUTTON_HEIGHT = 35

local WHITE = Color(255, 255, 255, 255)
local TRANSPARENT_WHITE = Color(255, 255, 255, 0)
local GREEN = Color(100, 200, 125, 255)
local GREEN_DARK = Color(50, 150, 75, 255)
local DARK_GREY = Color(25, 25, 25, 255)
local ATM_BACKDROP_COLOR = Color(50, 50, 50, 255)
local TRANSPARENT_ATM_BACKDROP_COLOR = Color(50, 50, 50, 0)
local ATM_GREY_BUTTON_COLOR = Color(35, 35, 35, 255)
local ATM_GREY_BUTTON_COLOR_DARK = Color(30, 30, 30, 255)

local FONT_HEIGHT = draw.GetFontHeight("HyllestedMoney:MainFont")
local FONT_HEIGHT_SMALL = draw.GetFontHeight("HyllestedMoney:MainFontSmall")

local CLICK_SOUND = Sound("ui/bubble_click.wav")

local DISTANCE_LIMIT = 100

function CubicEase(n)
    return n^2 * (3 - 2*n)
end

function ENT:OpenTransferSelectionMenu()
    local entity = self

    local popupWidth, popupHeight = 225, 55

    local frame = vgui.Create( "DFrame" )
    frame:SetPos( ScrW() / 2 - popupWidth / 2, ScrH() / 2 - popupHeight / 2 ) 
    frame:SetSize( popupWidth, popupHeight ) 
    frame:SetTitle( "Select Transfer Target" ) 
    frame:SetVisible( true ) 
    frame:SetDraggable( false ) 
    frame:ShowCloseButton( true ) 
    frame:MakePopup()

    local textEntry = vgui.Create("DTextEntry", frame)
    textEntry:Dock(TOP)
    textEntry:SetPlaceholderText("SteamID (x64)")
    textEntry:SetNumeric(true)
    textEntry:RequestFocus()

    function textEntry:OnEnter( value )
        entity.transferTarget = value
        frame:Close()
    end
end

function ENT:OpenTransferConfirmMenu()
    local entity = self

    local popupWidth, popupHeight = 400, 100

    local frame = vgui.Create( "DFrame" )
    frame:SetPos( ScrW() / 2 - popupWidth / 2, ScrH() / 2 - popupHeight / 2 ) 
    frame:SetSize( popupWidth, popupHeight ) 
    frame:SetTitle( "Transfer Confirmation" ) 
    frame:SetVisible( true ) 
    frame:SetDraggable( false ) 
    frame:ShowCloseButton( true ) 
    frame:MakePopup()

    local label = vgui.Create( "DLabel", frame )
    label:Dock( TOP )
    label:SetSize( 400, 45 )
    label:SetFont( "HyllestedMoney:MainFontSmall" )
    label:SetText( string.format( "Are you sure you want to transfer $%d\nTo account: %d?", self.increment, self.transferTarget ) )
    label:SetTextColor( DARK_GREY )

    local confirmButton = vgui.Create( "DButton", frame )
    confirmButton:Dock(LEFT)
    confirmButton:SetText( "Confirm" )

    local cancelButton = vgui.Create( "DButton", frame )
    cancelButton:Dock(LEFT)
    cancelButton:SetText( "Cancel" )

    function cancelButton:DoClick()
        frame:Close()
    end

    function confirmButton:DoClick()
        net.Start("HyllestedMoney:PlayerTransferMoney")
            net.WriteUInt64(entity.transferTarget)
            net.WriteUInt(entity.increment,32)
        net.SendToServer()
        frame:Close()
    end
end

function ENT:Initialize()
    self.increment = 10
    self.page = FRONT_PAGE
    self.transferTarget = "" -- SteamID (x64) of the player to send money to
    self.active = false -- This denotes whether or not the player has interacted with the ATM yet

    self.startupAnimation = {
        active = false,
        duration = 1,
        startTime = 0,
    }

    self.pageFadeAnimation = {
        active = false,
        duration = 1,
        startTime = 0,
        fadeTo = FRONT_PAGE,
    }
end

function ENT:DrawTranslucent()
    local client = LocalPlayer()
    local distance = client:GetPos():Distance(self:GetPos())

    if imgui.Entity3D2D(self, Vector(1, -20.15, 23.75), Angle(0, 90, 85), 0.1) then // These values would need to be adjusted depending on the model used.
        local buttons = {}

        // Drawing the monitor backdrop
        surface.SetDrawColor(ATM_BACKDROP_COLOR)
        surface.DrawRect(0, 0, ATM_UI_WIDTH, ATM_UI_HEIGHT)
        if self.page == FRONT_PAGE then
            local labelPositionY = ATM_UI_HEIGHT / 2 - FONT_HEIGHT
            local subtextColor = WHITE

            if self.startupAnimation.active then
                local timePassed = CurTime() - self.startupAnimation.startTime
                local timeFraction = math.min(timePassed / self.startupAnimation.duration, 1)
                local timeEased = CubicEase(timeFraction)

                subtextColor = WHITE:Lerp(TRANSPARENT_WHITE, timeEased)
                labelPositionY = math.max(labelPositionY - (labelPositionY - ATM_UI_PADDING_Y) * timeEased, ATM_UI_PADDING_Y)

                local animationEnded = timeFraction == 1
                if animationEnded then
                    self.startupAnimation.active = false
                    self.active = true
                    self.pageFadeAnimation.active = true
                    self.pageFadeAnimation.startTime = CurTime()
                    self.pageFadeAnimation.fadeTo = MAIN_PAGE
                end
            end

            if not self.active then
                draw.DrawText("ATM - MoneyBank™", "HyllestedMoney:MainFont", ATM_UI_WIDTH / 2, labelPositionY, WHITE, TEXT_ALIGN_CENTER)
                draw.DrawText("Touch to Begin", "HyllestedMoney:MainFontSmall", ATM_UI_WIDTH / 2, labelPositionY + FONT_HEIGHT, subtextColor, TEXT_ALIGN_CENTER)

                table.insert(buttons, {x = 0, y = 0, w = ATM_UI_WIDTH, h = ATM_UI_HEIGHT, callback = function()
                    if not self.startupAnimation.active then
                        self.startupAnimation.active = true 
                        self.startupAnimation.startTime = CurTime()
                    end
                end})
            end
        elseif self.page == MAIN_PAGE then
            local accountPageButtonX = ATM_UI_PADDING_X
            local transferPageButtonX = ATM_UI_PADDING_X
            local historyPageButtonX = ATM_UI_PADDING_X

            local accountPageButtonY = ATM_UI_PADDING_Y + FONT_HEIGHT + ATM_LINE_PADDING
            local transferPageButtonY = accountPageButtonY + ATM_MENU_BUTTON_HEIGHT + ATM_LINE_PADDING
            local historyPageButtonY = transferPageButtonY + ATM_MENU_BUTTON_HEIGHT + ATM_LINE_PADDING

            local isHoveringAccountButton = imgui.IsHovering(accountPageButtonX, accountPageButtonY, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, ATM_MENU_BUTTON_HEIGHT)
            local isHoveringTransferButton = imgui.IsHovering(transferPageButtonX, transferPageButtonY, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, ATM_MENU_BUTTON_HEIGHT)
            local isHoveringHistoryButton = imgui.IsHovering(historyPageButtonX, historyPageButtonY, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, ATM_MENU_BUTTON_HEIGHT)

            // (title is draw here as well because of the fade out animation when stepping away from the ATM requiring it)
            draw.DrawText("ATM - MoneyBank™", "HyllestedMoney:MainFont", ATM_UI_WIDTH / 2, ATM_UI_PADDING_Y, WHITE, TEXT_ALIGN_CENTER)

            -- Draw account page button
            surface.SetDrawColor(isHoveringAccountButton and ATM_GREY_BUTTON_COLOR_DARK or ATM_GREY_BUTTON_COLOR)
            surface.DrawRect(accountPageButtonX, accountPageButtonY, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, ATM_MENU_BUTTON_HEIGHT)
            draw.DrawText("Account", "HyllestedMoney:MainFontSmall", ATM_UI_WIDTH / 2, accountPageButtonY + (ATM_MENU_BUTTON_HEIGHT - FONT_HEIGHT_SMALL) / 2, WHITE, TEXT_ALIGN_CENTER)

            -- Draw transfer page button
            surface.SetDrawColor(isHoveringTransferButton and ATM_GREY_BUTTON_COLOR_DARK or ATM_GREY_BUTTON_COLOR)
            surface.DrawRect(transferPageButtonX, transferPageButtonY, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, ATM_MENU_BUTTON_HEIGHT)
            draw.DrawText("Transfer", "HyllestedMoney:MainFontSmall", ATM_UI_WIDTH / 2, transferPageButtonY + (ATM_MENU_BUTTON_HEIGHT - FONT_HEIGHT_SMALL) / 2, WHITE, TEXT_ALIGN_CENTER)

            -- Draw history page button
            surface.SetDrawColor(isHoveringHistoryButton and ATM_GREY_BUTTON_COLOR_DARK or ATM_GREY_BUTTON_COLOR)
            surface.DrawRect(historyPageButtonX, historyPageButtonY, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, ATM_MENU_BUTTON_HEIGHT)
            draw.DrawText("History", "HyllestedMoney:MainFontSmall", ATM_UI_WIDTH / 2, historyPageButtonY + (ATM_MENU_BUTTON_HEIGHT - FONT_HEIGHT_SMALL) / 2, WHITE, TEXT_ALIGN_CENTER)

            table.insert(buttons, {x = accountPageButtonX, y = accountPageButtonY, w = ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, h = ATM_MENU_BUTTON_HEIGHT, callback = function()
                if not self.pageFadeAnimation.active then
                    self.pageFadeAnimation.active = true 
                    self.pageFadeAnimation.startTime = CurTime()
                    self.pageFadeAnimation.fadeTo = ACCOUNT_PAGE
                end
            end})

            table.insert(buttons, {x = transferPageButtonX, y = transferPageButtonY, w = ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, h = ATM_MENU_BUTTON_HEIGHT, callback = function()
                if not self.pageFadeAnimation.active then
                    self.pageFadeAnimation.active = true 
                    self.pageFadeAnimation.startTime = CurTime()
                    self.pageFadeAnimation.fadeTo = TRANSFER_PAGE
                end
            end})

            table.insert(buttons, {x = historyPageButtonX, y = historyPageButtonY, w = ATM_UI_WIDTH - ATM_UI_PADDING_X * 2, h = ATM_MENU_BUTTON_HEIGHT, callback = function()
                if not self.pageFadeAnimation.active then
                    self.pageFadeAnimation.active = true 
                    self.pageFadeAnimation.startTime = CurTime()
                    self.pageFadeAnimation.fadeTo = HISTORY_PAGE
                end
            end})
        elseif self.page == ACCOUNT_PAGE then
            local leftArrowPositionX = ATM_UI_PADDING_X
            local rightArrowPositionX = ATM_UI_WIDTH - ATM_UI_PADDING_X - ATM_ARROW_BUTTON_WIDTH
            local arrowPositionY = ATM_UI_PADDING_Y + FONT_HEIGHT * 2 + ATM_LINE_PADDING * 5

            local depositButtonPositionX = ATM_UI_PADDING_X
            local withdrawButtonPositionX = ATM_UI_WIDTH / 2 + ATM_BUTTON_PADDING / 2
            local transferButtonPositionY = arrowPositionY + ATM_ARROW_BUTTON_HEIGHT + ATM_LINE_PADDING
            local transferButtonWidth = ATM_UI_WIDTH / 2 - ATM_UI_PADDING_X - ATM_BUTTON_PADDING / 2

            local isHoveringLeftArrow = imgui.IsHovering(leftArrowPositionX, arrowPositionY, ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT)
            local isHoveringRightArrow = imgui.IsHovering(rightArrowPositionX, arrowPositionY, ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT)
            local isHoveringDeposit = imgui.IsHovering(depositButtonPositionX,transferButtonPositionY, transferButtonWidth, ATM_TRANSFER_BUTTON_HEIGHT)
            local isHoveringWithdraw = imgui.IsHovering(withdrawButtonPositionX,transferButtonPositionY, transferButtonWidth, ATM_TRANSFER_BUTTON_HEIGHT)

            // ATM title and current balance (title is draw here as well because of the fade out animation when stepping away from the ATM requiring it)
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
            draw.DrawText(string.format("$%.2f",self.increment),"HyllestedMoney:MainFont", ATM_UI_WIDTH / 2, arrowPositionY + (ATM_ARROW_BUTTON_HEIGHT - FONT_HEIGHT) / 2, WHITE, TEXT_ALIGN_CENTER)

            // This draws the deposit and withdraw buttons
            surface.SetDrawColor(isHoveringDeposit and GREEN_DARK or GREEN)
            surface.DrawRect(depositButtonPositionX, transferButtonPositionY, transferButtonWidth, ATM_TRANSFER_BUTTON_HEIGHT)

            surface.SetDrawColor(isHoveringWithdraw and GREEN_DARK or GREEN)
            surface.DrawRect(withdrawButtonPositionX, transferButtonPositionY, transferButtonWidth, ATM_TRANSFER_BUTTON_HEIGHT)

            // This draws the text for the deposit and withdraw buttons
            draw.DrawText("Deposit","HyllestedMoney:MainFontSmall",depositButtonPositionX + transferButtonWidth / 2, transferButtonPositionY + (ATM_TRANSFER_BUTTON_HEIGHT - FONT_HEIGHT_SMALL) / 2, WHITE, TEXT_ALIGN_CENTER)
            draw.DrawText("Withdraw","HyllestedMoney:MainFontSmall",withdrawButtonPositionX + transferButtonWidth / 2, transferButtonPositionY + (ATM_TRANSFER_BUTTON_HEIGHT - FONT_HEIGHT_SMALL) / 2, WHITE, TEXT_ALIGN_CENTER)

            table.insert(buttons, {x = leftArrowPositionX, y = arrowPositionY, w = ATM_ARROW_BUTTON_WIDTH, h = ATM_ARROW_BUTTON_HEIGHT, callback = function()
                local increment = input.IsShiftDown() and 10 or 1 -- Hold shift to change increment to 10 instead of 1
                self.increment = math.max(self.increment - increment, 1) -- Lower limit is 1
            end})

            table.insert(buttons, {x = rightArrowPositionX, y = arrowPositionY, w = ATM_ARROW_BUTTON_WIDTH, h = ATM_ARROW_BUTTON_HEIGHT, callback = function()
                local increment = input.IsShiftDown() and 10 or 1 -- Hold shift to change increment to 10 instead of 1
                self.increment = math.min(self.increment + increment, 2^32) -- Upper limit is set by 32 bit limit
            end})

            table.insert(buttons, {x = depositButtonPositionX, y = transferButtonPositionY, w = transferButtonWidth, h = ATM_TRANSFER_BUTTON_HEIGHT, callback = function()
                net.Start("HyllestedMoney:TransferMoney")
                    net.WriteUInt(TRANSFER_DEPOSIT,1)
                    net.WriteUInt(self.increment,32)
                net.SendToServer()
            end})

            table.insert(buttons, {x = withdrawButtonPositionX, y = transferButtonPositionY, w = transferButtonWidth, h = ATM_TRANSFER_BUTTON_HEIGHT, callback = function()
                net.Start("HyllestedMoney:TransferMoney")
                    net.WriteUInt(TRANSFER_WITHDRAW,1)
                    net.WriteUInt(self.increment,32)
                net.SendToServer()
            end})
        elseif self.page == TRANSFER_PAGE then
            local leftArrowPositionX = ATM_UI_PADDING_X
            local rightArrowPositionX = ATM_UI_WIDTH - ATM_UI_PADDING_X - ATM_ARROW_BUTTON_WIDTH
            local arrowPositionY = ATM_UI_PADDING_Y + FONT_HEIGHT * 2 + ATM_LINE_PADDING

            local targetEntryPositionX = ATM_UI_PADDING_X
            local targetEntryPositionY = arrowPositionY + ATM_ARROW_BUTTON_HEIGHT + ATM_LINE_PADDING

            local targetEditButtonPositionX = ATM_UI_WIDTH - ATM_UI_PADDING_X - ATM_ARROW_BUTTON_WIDTH

            local transferButtonPositionX = ATM_UI_PADDING_X
            local transferButtonPositionY = targetEntryPositionY + ATM_ARROW_BUTTON_HEIGHT + ATM_LINE_PADDING
            local transferButtonWidth = ATM_UI_WIDTH - ATM_UI_PADDING_X * 2

            local isHoveringLeftArrow = imgui.IsHovering(leftArrowPositionX, arrowPositionY, ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT)
            local isHoveringRightArrow = imgui.IsHovering(rightArrowPositionX, arrowPositionY, ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT)
            local isHoveringTargetEdit = imgui.IsHovering(targetEditButtonPositionX, targetEntryPositionY, ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT)
            local isHoveringTransfer = imgui.IsHovering(transferButtonPositionX,transferButtonPositionY, transferButtonWidth, ATM_TRANSFER_BUTTON_HEIGHT)

            // ATM title and current balance (title is draw here as well because of the fade out animation when stepping away from the ATM requiring it)
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
            draw.DrawText(string.format("$%.2f",self.increment),"HyllestedMoney:MainFont", ATM_UI_WIDTH / 2, arrowPositionY + (ATM_ARROW_BUTTON_HEIGHT - FONT_HEIGHT) / 2, WHITE, TEXT_ALIGN_CENTER)

            // This draws the UI for selected the target for the transfer
            surface.SetDrawColor(DARK_GREY)
            surface.DrawRect(targetEntryPositionX, targetEntryPositionY, ATM_UI_WIDTH - ATM_UI_PADDING_X * 2 - ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT)

            draw.DrawText(self.transferTarget, "HyllestedMoney:MainFontSmall", targetEntryPositionX + (ATM_UI_WIDTH - ATM_UI_PADDING_X * 2 - ATM_ARROW_BUTTON_WIDTH) / 2, targetEntryPositionY + (ATM_ARROW_BUTTON_HEIGHT - FONT_HEIGHT_SMALL) / 2, WHITE, TEXT_ALIGN_CENTER)

            // This draws the edit button for the transfer target
            surface.SetDrawColor(isHoveringTargetEdit and ATM_GREY_BUTTON_COLOR_DARK or ATM_GREY_BUTTON_COLOR)
            surface.DrawRect(targetEditButtonPositionX, targetEntryPositionY, ATM_ARROW_BUTTON_WIDTH, ATM_ARROW_BUTTON_HEIGHT)

            // This fills said edit button with text
            draw.DrawText("...","HyllestedMoney:MainFontSmall", targetEditButtonPositionX + ATM_ARROW_BUTTON_WIDTH / 2, targetEntryPositionY + (ATM_ARROW_BUTTON_HEIGHT - FONT_HEIGHT_SMALL) / 2, WHITE, TEXT_ALIGN_CENTER)

            // This draws the transfer button
            surface.SetDrawColor(isHoveringTransfer and GREEN_DARK or GREEN)
            surface.DrawRect(transferButtonPositionX, transferButtonPositionY, transferButtonWidth, ATM_TRANSFER_BUTTON_HEIGHT)

            // This draws the text for the transfer button
            draw.DrawText("Transfer","HyllestedMoney:MainFontSmall", ATM_UI_WIDTH / 2, transferButtonPositionY + (ATM_TRANSFER_BUTTON_HEIGHT - FONT_HEIGHT_SMALL) / 2, WHITE, TEXT_ALIGN_CENTER)

            table.insert(buttons, {x = targetEditButtonPositionX, y = targetEntryPositionY, w = ATM_ARROW_BUTTON_WIDTH, h = ATM_ARROW_BUTTON_HEIGHT, callback = function() self:OpenTransferSelectionMenu() end})

            table.insert(buttons, {x = leftArrowPositionX, y = arrowPositionY, w = ATM_ARROW_BUTTON_WIDTH, h = ATM_ARROW_BUTTON_HEIGHT, callback = function()
                local increment = input.IsShiftDown() and 10 or 1 -- Hold shift to change increment to 10 instead of 1
                self.increment = math.max(self.increment - increment, 1) -- Lower limit is 1
            end})

            table.insert(buttons, {x = rightArrowPositionX, y = arrowPositionY, w = ATM_ARROW_BUTTON_WIDTH, h = ATM_ARROW_BUTTON_HEIGHT, callback = function()
                local increment = input.IsShiftDown() and 10 or 1 -- Hold shift to change increment to 10 instead of 1
                self.increment = math.min(self.increment + increment, 2^32) -- Upper limit is set by 32 bit limit
            end})

            table.insert(buttons, {x = transferButtonPositionX, y = transferButtonPositionY, w = transferButtonWidth, h = ATM_TRANSFER_BUTTON_HEIGHT, callback = function()
                if self.transferTarget == "" then
                -- Doesn't used DarkRP method as it is server only
                    notification.AddLegacy( "No Transfer recipient selected!", NOTIFY_ERROR, 5 )
                    return
                end

                self:OpenTransferConfirmMenu()
            end})
        end

        -- Draw back arrow on selected pages
        if self.page == ACCOUNT_PAGE or self.page == TRANSFER_PAGE or self.page == HISTORY_PAGE then
            local backButtonX = 5
            local backButtonY = 5
            local backButtonWidth = 25
            local backButtonHeight = 25

            local isHoveringBackButton = imgui.IsHovering(backButtonX, backButtonY, backButtonWidth, backButtonHeight)

            surface.SetDrawColor(isHoveringBackButton and ATM_GREY_BUTTON_COLOR_DARK or ATM_GREY_BUTTON_COLOR)
            surface.DrawRect(backButtonX, backButtonY, backButtonWidth, backButtonHeight)
            draw.DrawText("<", "HyllestedMoney:MainFontSmall", backButtonX + backButtonWidth / 2, backButtonY + (backButtonHeight - FONT_HEIGHT_SMALL) / 2, WHITE, TEXT_ALIGN_CENTER)

            table.insert(buttons, {x = backButtonX, y = backButtonY, w = backButtonHeight, h = backButtonHeight, callback = function()
                if not self.pageFadeAnimation.active then
                    self.pageFadeAnimation.active = true 
                    self.pageFadeAnimation.startTime = CurTime()
                    self.pageFadeAnimation.fadeTo = MAIN_PAGE
                end
            end})
        end

        if self.pageFadeAnimation.active then
            local timePassed = CurTime() - self.pageFadeAnimation.startTime
            local timeFraction = math.min(timePassed / self.pageFadeAnimation.duration, 1)

            local fadeColor = nil
            if timeFraction <= 0.5 then -- If we are currently fading out
                local timeEased = CubicEase(timeFraction*2)
                fadeColor = TRANSPARENT_ATM_BACKDROP_COLOR:Lerp(ATM_BACKDROP_COLOR, timeEased)
            else -- If we are current fading in
                self.page = self.pageFadeAnimation.fadeTo

                local timeEased = CubicEase((timeFraction-0.5)*2)
                fadeColor = ATM_BACKDROP_COLOR:Lerp(TRANSPARENT_ATM_BACKDROP_COLOR, timeEased)

                local animationEnded = timeFraction == 1
                if animationEnded then
                    self.pageFadeAnimation.active = false
                end
            end
            
            surface.SetDrawColor(fadeColor)
            surface.DrawRect(0, 0, ATM_UI_WIDTH, ATM_UI_HEIGHT)
        end

        -- Draw the title here so that the fade animation doesn't affect it
        if self.active then
            draw.DrawText("ATM - MoneyBank™", "HyllestedMoney:MainFont", ATM_UI_WIDTH / 2, ATM_UI_PADDING_Y, WHITE, TEXT_ALIGN_CENTER)
        end

        if imgui.IsPressed() and imgui.IsHovering(0, 0, ATM_UI_WIDTH, ATM_UI_HEIGHT) and distance <= DISTANCE_LIMIT then
            for _, button in pairs(buttons) do
                if imgui.IsHovering(button.x, button.y, button.w, button.h) then
                    self:EmitSound(CLICK_SOUND)
                    button.callback()
                end
            end
        end

        if distance > DISTANCE_LIMIT * 2 then -- Player has moved away
            if not self.pageFadeAnimation.active and self.active then
                self.pageFadeAnimation.active = true 
                self.pageFadeAnimation.startTime = CurTime()
                self.pageFadeAnimation.fadeTo = FRONT_PAGE
                self.active = false
            end
        end
        imgui.End3D2D()
    end
end

function ENT:Draw()
    self:DrawModel()
end