local MainFontData = {font = "Arial",size = 24,weight = 500,blursize = 0,scanlines = 0,antialias = true,underline = false,italic = false,strikeout = false,symbol = false,rotary = false,shadow = false,additive = false,outline = false,}
surface.CreateFont("MainFont", MainFontData)

hook.Add("HUDPaint", "draw-money-hud", function()
    local client = LocalPlayer()
    local Width, Height = ScrW(), ScrH()
    local BoxWidth, BoxHeight = 300, 100
    draw.RoundedBox(15, Width/2 - BoxWidth/2, 50, BoxWidth, BoxHeight, Color(0,0,0,100))
    draw.SimpleTextOutlined("Current Balance", "MainFont", Width/2, 55, Color( 255, 255, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0,0,0,255))
    draw.SimpleTextOutlined(string.format("$%.2f",client:GetNWInt("Money")), "MainFont", Width/2, 100, Color( 100, 255, 100, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0,0,0,255))
end)