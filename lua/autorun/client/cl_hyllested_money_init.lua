local MainFontData = {font = "Arial",size = 36,weight = 1000,}
local SmallMainFontData = {font = "Arial",size = 20,weight = 1500,}
surface.CreateFont("HyllestedMoney:MainFont", MainFontData)
surface.CreateFont("HyllestedMoney:MainFontSmall", SmallMainFontData)

hook.Add("HUDPaint", "draw-money-hud", function()
    local client = LocalPlayer()
    local Width, Height = ScrW(), ScrH()
    local BoxWidth, BoxHeight = 300, 100
    draw.RoundedBox(15, Width/2 - BoxWidth/2, 50, BoxWidth, BoxHeight, Color(0,0,0,100))
    draw.SimpleTextOutlined("Current Balance", "HyllestedMoney:MainFont", Width/2, 55, Color( 255, 255, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0,0,0,255))
    draw.SimpleTextOutlined(string.format("$%.2f",client:GetNWInt("Money")), "HyllestedMoney:MainFont", Width/2, 100, Color( 100, 255, 100, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0,0,0,255))
end)