-- Math Tower Race: displays answers; optional auto mode starts disabled.
local fractionMap = {
    ["½"]="(1/2)", ["⅓"]="(1/3)", ["⅔"]="(2/3)",
    ["¼"]="(1/4)", ["¾"]="(3/4)", ["⅕"]="(1/5)",
    ["⅖"]="(2/5)", ["⅗"]="(3/5)", ["⅘"]="(4/5)",
    ["⅙"]="(1/6)", ["⅚"]="(5/6)", ["⅐"]="(1/7)",
    ["⅛"]="(1/8)", ["⅜"]="(3/8)", ["⅝"]="(5/8)",
    ["⅞"]="(7/8)", ["⅑"]="(1/9)", ["⅒"]="(1/10)",
}
local smallDigits = {
    ["⁰"]="0", ["¹"]="1", ["²"]="2", ["³"]="3", ["⁴"]="4",
    ["⁵"]="5", ["⁶"]="6", ["⁷"]="7", ["⁸"]="8", ["⁹"]="9",
    ["₀"]="0", ["₁"]="1", ["₂"]="2", ["₃"]="3", ["₄"]="4",
    ["₅"]="5", ["₆"]="6", ["₇"]="7", ["₈"]="8", ["₉"]="9",
}
local function clean(text)
    local s = text:gsub("<[^>]*>", ""):gsub("−", "-"):gsub("–", "-")
        :gsub("×", "*"):gsub("÷", "/"):gsub("%?+", "?")
        :gsub("…", ""):gsub("%.%.%.", "")
    if s:find("⁄", 1, true) then
        for symbol, digit in pairs(smallDigits) do s = s:gsub(symbol, digit) end
        s = s:gsub("⁄", "/")
    else
        s = s:gsub("²", "^2"):gsub("³", "^3")
    end
    for symbol, value in pairs(fractionMap) do
        s = s:gsub("(%d+)%s+" .. symbol, function(whole)
            return "(" .. whole .. "+" .. value .. ")"
        end)
        s = s:gsub(symbol, value)
    end
    return s
end
local function close(a, b)
    return math.abs(a-b) <= 1e-7 * math.max(1, math.abs(a), math.abs(b))
end
local function calculate(text)
    local s = clean(text):gsub("%s+", ""):gsub("%%$", "/100")
    if #s == 0 or #s > 256 then return nil end
    local pos, parse = 1, nil
    local priority = {["+"]=10, ["-"]=10, ["*"]=20, ["/"]=20, ["^"]=30}
    local function peek() return s:sub(pos, pos) end
    parse = function(minimum)
        local value, ch = nil, peek()
        if ch == "+" or ch == "-" then
            pos = pos + 1
            value = parse(25)
            if ch == "-" then value = -value end
        elseif ch == "(" then
            pos = pos + 1
            value = parse(0)
            assert(peek() == ")", "missing parenthesis")
            pos = pos + 1
        else
            local tail = s:sub(pos)
            local number = tail:match("^%d+%.?%d*") or tail:match("^%.%d+")
            assert(number, "expected number")
            value = assert(tonumber(number))
            pos = pos + #number
        end
        while true do
            local op = peek()
            local p = priority[op]
            if not p or p < minimum then break end
            pos = pos + 1
            local right = parse(op == "^" and p or p+1)
            if op == "+" then value = value + right
            elseif op == "-" then value = value - right
            elseif op == "*" then value = value * right
            elseif op == "/" then assert(right ~= 0); value = value / right
            else value = value ^ right end
        end
        return value
    end
    local ok, value = pcall(function()
        local n = parse(0)
        assert(pos > #s, "unexpected characters")
        return n
    end)
    if ok and type(value) == "number" and value == value and math.abs(value) < math.huge then
        return value
    end
end
local function sequence(text)
    if not text:find(",", 1, true) or not text:match("^[%d%s,%?%.%+%-]+$") then return nil end
    local known, missing, count = {}, nil, 0
    -- Preserve positions, including an unknown at the beginning or in the middle.
    for part in (text..","):gmatch("(.-),") do
        count = count+1
        if part:match("^%s*%?%s*$") then
            if missing then return nil end
            missing = count
        else
            local n = tonumber(part)
            if not n then return nil end
            known[#known+1] = {index=count,value=n}
        end
    end
    if #known<3 or not missing then return nil end
    local first, second = known[1], known[2]
    local difference = (second.value-first.value)/(second.index-first.index)
    local arithmetic = true
    for _, item in ipairs(known) do
        local predicted = first.value+difference*(item.index-first.index)
        if not close(predicted,item.value) then arithmetic=false; break end
    end
    local arithmeticValue=arithmetic and (first.value+difference*(missing-first.index)) or nil
    local ratio
    for i=2,#known do
        local previous, current = known[i-1], known[i]
        if current.index-previous.index==1 and previous.value~=0 then
            ratio=current.value/previous.value
            break
        end
    end
    if not ratio or ratio==0 then return arithmeticValue end
    for _, item in ipairs(known) do
        local predicted=first.value*ratio^(item.index-first.index)
        if not close(predicted,item.value) then return arithmeticValue end
    end
    local geometricValue=first.value*ratio^(missing-first.index)
    if arithmeticValue~=nil and not close(arithmeticValue,geometricValue) then return nil end
    return geometricValue
end
local function contains(text, part) return text:find(part, 1, true) ~= nil end
local function solve(question, answers, instruction)
    answers, instruction = answers or {}, instruction or ""
    local text = clean(question)
    local wording = clean(question .. " " .. instruction)
    local english = wording:lower()
    local left, right = text:match("^(.-)%[%s*%?%s*%](.-)$")
    if not left then left, right = text:match("^(.-)%?(.-)$") end
    if left and not contains(text, "=") then
        local a, b = calculate(left), calculate(right)
        if a and b then return close(a,b) and "=" or (a>b and ">" or "<") end
    end
    local nextNumber = sequence(text)
    if nextNumber ~= nil then return nextNumber end
    local nearestInteger = contains(english,"nearest whole") or contains(english,"nearest integer")
        or contains(wording,"ближайшего целого") or contains(wording,"ближайшее целое")
    if nearestInteger then
        local numbers = {}
        for token in text:gsub(",", "."):gmatch("[+-]?%d+%.?%d*") do
            numbers[#numbers+1] = tonumber(token)
        end
        if #numbers == 1 then
            local n = numbers[1]
            return n>=0 and math.floor(n+0.5) or math.ceil(n-0.5)
        end
        return nil
    end
    local parity = contains(english,"odd or even") or contains(english,"even or odd")
        or contains(wording,"Чётное или нечётное") or contains(wording,"четное или нечетное")
    if parity then
        local n = calculate(text) or tonumber(text:match("[+-]?%d+"))
        if n and n%1 == 0 then return n%2 == 0 and "even" or "odd" end
        return nil
    end
    left, right = text:match("^%s*(.-)%s*=%s*(.-)%s*$")
    if not left then return calculate(text:gsub("[xX]", "*")) end
    local percent = right:match("^%s*%?%s*%%%s*$")
    if right:match("^%s*%?%s*$") or percent then
        if not contains(left,"?") then
            local n = calculate(left:gsub("[xX]", "*"))
            if n then return percent and tostring(n*100).."%" or n end
        end
    end
    local hasQuestion = contains(text,"?")
    local hasX = text:find("[xX]") ~= nil
    if not hasQuestion and not hasX then return nil end
    local function difference(n)
        local replacement = "("..string.format("%.15f", n)..")"
        local function substitute(part)
            if hasQuestion then
                part = part:gsub("[xX]", "*"):gsub("%?", function() return replacement end)
            else
                part = part:gsub("[xX]", function() return replacement end)
            end
            return calculate(part)
        end
        local a, b = substitute(left), substitute(right)
        if a and b then return a-b end
    end
    -- Solve affine equations; verify the result in the original expression.
    local d0, d1, d2 = difference(0), difference(1), difference(2)
    if d0 and d1 and d2 then
        local slope = d1-d0
        if not close(slope,0) and close(d2-d1,slope) then
            local n = -d0/slope
            local check = difference(n)
            if check and close(check,0) then return n end
        end
    end
    -- Nonlinear equations can be checked against the available answers.
    local result
    for _, answer in ipairs(answers) do
        local n = calculate(answer.text)
        if n then
            local check = difference(n)
            if check and close(check,0) then
                if result ~= nil and not close(result,n) then return nil end
                result = n
            end
        end
    end
    return result
end

-- Data-based graphical questions. Only the active content is supplied here.
local function solveGraphic(data, instruction)
    local wording = instruction:lower()
    local area = contains(wording,"area") or contains(instruction,"площад")
        or contains(instruction,"Площад")
    local perimeter = contains(wording,"perimeter") or contains(instruction,"периметр")
        or contains(instruction,"Периметр")
    if area or perimeter then
        local shape = data.triangle or data.rectangle
        if shape and shape.width and shape.height and shape.width>0 and shape.height>0 then
            if area then return shape.width*shape.height/(data.triangle and 2 or 1) end
            if data.rectangle and not data.triangle then return 2*(shape.width+shape.height) end
        end
        return nil
    end
    if data.clock then
        local minuteAngle = data.clock.minute % 360
        local hourAngle = data.clock.hour % 360
        local minute = math.floor(minuteAngle/6+0.5)%60
        -- Supports both continuously moving and whole-hour hour hands.
        local hour = math.floor(hourAngle/30+1e-5)%12
        if hour==0 then hour=12 end
        return string.format("%d:%02d",hour,minute)
    end
    if data.moneyCents then return tostring(data.moneyCents).."¢" end
    if data.angle then
        local delta = math.abs((data.angle.first-data.angle.second)%360)
        local degrees = math.min(delta,360-delta)
        if data.angle.lines then
            if close(degrees,0) or close(degrees,180) then return "Parallel Lines" end
            if close(degrees,90) then return "Perpendicular Lines" end
            return "Intersecting Lines"
        end
        if close(degrees,90) then return "Right Angle" end
        if close(degrees,180) then return "Straight Angle" end
        if degrees>0 and degrees<90 then return "Acute Angle" end
        if degrees>90 and degrees<180 then return "Obtuse Angle" end
    end
end

local function parseDelaySettings(mode,fixed,minimum,maximum)
    local function number(value)
        local n=tonumber((tostring(value):gsub(",",".")))
        if n and n==n and n>=0 and n<=120 then return n end
    end
    if mode=="fixed" then
        local n=number(fixed)
        if not n then return nil,"Введи задержку от 0 до 120 секунд" end
        return {mode="fixed",fixed=n}
    elseif mode=="random" then
        local low,high=number(minimum),number(maximum)
        if not low or not high then return nil,"Границы должны быть от 0 до 120 секунд" end
        if low>high then return nil,"Значение «От» должно быть не больше «До»" end
        return {mode="random",minimum=low,maximum=high}
    end
    return nil,"Выбери режим задержки"
end
local function pickDelay(settings,random)
    if settings.mode=="random" then
        return settings.minimum+(settings.maximum-settings.minimum)*(random or math.random)()
    end
    return settings.fixed
end

-- ROBLOX UI
local player = game:GetService("Players").LocalPlayer
assert(player, "Запусти внутри игры на клиенте")
local gui = player:WaitForChild("PlayerGui")
local env = (getgenv and getgenv()) or _G
for _, name in ipairs({"MathRaceSolver", "MathRaceAnswerHelper"}) do
    local old = env[name]
    if type(old) == "table" then
        old.running = false
        if old.connection then pcall(function() old.connection:Disconnect() end) end
        for _, connection in ipairs(old.connections or {}) do
            pcall(function() connection:Disconnect() end)
        end
    end
end
local saved=env.MathRaceHelperSettings
if type(saved)~="table" then saved={} end
local settings={mode="fixed",fixed=1,minimum=1,maximum=5}
local valid=parseDelaySettings("fixed",saved.fixed or 1)
if valid then settings.fixed=valid.fixed end
valid=parseDelaySettings("random",nil,saved.minimum or 1,saved.maximum or 5)
if valid then settings.minimum=valid.minimum; settings.maximum=valid.maximum end
if saved.mode=="random" then settings.mode="random" end
env.MathRaceHelperSettings=settings
local state = {running=true,auto=false,connections={}}
local autoRound={signature=nil,since=0,handled=false,countdown=nil,pendingAt=nil,delay=nil}
env.MathRaceAnswerHelper = state
local oldPanel = gui:FindFirstChild("MathRaceAnswerPanel")
if oldPanel then oldPanel:Destroy() end
local panel = Instance.new("ScreenGui")
panel.Name = "MathRaceAnswerPanel"
panel.ResetOnSpawn = false
panel.IgnoreGuiInset = true
panel.DisplayOrder = 10000
panel.Parent = gui
local colors={background=Color3.fromRGB(18,22,34),card=Color3.fromRGB(28,34,50),
    text=Color3.fromRGB(232,237,248),muted=Color3.fromRGB(153,166,191),
    accent=Color3.fromRGB(100,116,255),green=Color3.fromRGB(94,229,171)}
local function make(class,parent,properties)
    local obj=Instance.new(class)
    for key,value in pairs(properties or {}) do obj[key]=value end
    obj.Parent=parent
    return obj
end
local function rounded(obj,radius)
    make("UICorner",obj,{CornerRadius=UDim.new(0,radius or 10)})
end
local function text(parent,value,x,y,w,h,size,color)
    return make("TextLabel",parent,{Text=value,Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,Font=Enum.Font.Gotham,
        TextSize=size or 14,TextColor3=color or colors.text,
        TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})
end
local function button(parent,value,x,y,w,h)
    local obj=make("TextButton",parent,{Text=value,Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,h),BackgroundColor3=colors.card,BorderSizePixel=0,
        Font=Enum.Font.GothamMedium,TextSize=14,TextColor3=colors.text,TextWrapped=true})
    rounded(obj,8)
    return obj
end
local root=make("Frame",panel,{Name="Window",Position=UDim2.fromOffset(18,190),
    Size=UDim2.fromOffset(350,232),BackgroundColor3=colors.background,BorderSizePixel=0})
rounded(root,14)
local windowScale=make("UIScale",root,{Scale=1})
make("UIStroke",root,{Color=Color3.fromRGB(62,72,104),Thickness=1,Transparency=0.25})
local header=make("Frame",root,{Size=UDim2.new(1,-54,0,46),BackgroundTransparency=1,Active=true})
local title=text(header,"MATH  /  помощник",18,8,265,30,16)
title.Font=Enum.Font.GothamBold
local minimize=button(root,"−",306,10,30,28)
local body=make("Frame",root,{Position=UDim2.fromOffset(0,46),
    Size=UDim2.new(1,0,1,-46),BackgroundTransparency=1})
local answerCard=make("Frame",body,{Position=UDim2.fromOffset(14,0),
    Size=UDim2.fromOffset(322,66),BackgroundColor3=colors.card,BorderSizePixel=0})
rounded(answerCard,10)
text(answerCard,"ПРАВИЛЬНЫЙ ОТВЕТ",12,7,298,14,10,colors.muted)
local label=text(answerCard,"Ожидание вопроса...",12,24,298,35,19,colors.green)
label.Font=Enum.Font.GothamBold
local autoButton=button(body,"Авто: ВЫКЛ",14,77,155,36)
local settingsButton=button(body,"Настройки задержки",181,77,155,36)
local autoStatus=text(body,"Ручной выбор ответа",16,118,318,33,12,colors.muted)
local delaySummary=text(body,"",16,151,318,20,12,colors.muted)
local settingsFrame=make("Frame",body,{Position=UDim2.fromOffset(14,183),
    Size=UDim2.fromOffset(322,215),BackgroundColor3=colors.card,BorderSizePixel=0,Visible=false})
rounded(settingsFrame,10)
text(settingsFrame,"ЗАДЕРЖКА НАЖАТИЯ",12,9,298,20,11,colors.muted)
local fixedButton=button(settingsFrame,"Фиксированная",12,35,143,32)
local randomButton=button(settingsFrame,"Случайная",167,35,143,32)
local fixedFields=make("Frame",settingsFrame,{Position=UDim2.fromOffset(12,78),
    Size=UDim2.fromOffset(298,65),BackgroundTransparency=1})
local randomFields=make("Frame",settingsFrame,{Position=UDim2.fromOffset(12,78),
    Size=UDim2.fromOffset(298,65),BackgroundTransparency=1,Visible=false})
local function input(parent,value,x,width)
    local obj=make("TextBox",parent,{Position=UDim2.fromOffset(x,23),
        Size=UDim2.fromOffset(width,36),Text=tostring(value),PlaceholderText="Секунды",
        BackgroundColor3=colors.background,BorderSizePixel=0,TextColor3=colors.text,
        Font=Enum.Font.GothamMedium,TextSize=17,ClearTextOnFocus=false})
    rounded(obj,8)
    return obj
end
text(fixedFields,"Задержка, сек.",0,0,298,20,12,colors.muted)
local fixedInput=input(fixedFields,settings.fixed,0,298)
text(randomFields,"От, сек.",0,0,143,20,12,colors.muted)
text(randomFields,"До, сек.",155,0,143,20,12,colors.muted)
local minInput=input(randomFields,settings.minimum,0,143)
local maxInput=input(randomFields,settings.maximum,155,143)
local settingsMessage=text(settingsFrame,"Можно вводить дробные секунды: 1,5",12,145,298,27,11,colors.muted)
local applyButton=button(settingsFrame,"Применить",12,177,298,28)
applyButton.BackgroundColor3=colors.accent
local draftMode=settings.mode
local function refreshMode()
    fixedFields.Visible=draftMode=="fixed"
    randomFields.Visible=draftMode=="random"
    fixedButton.BackgroundColor3=draftMode=="fixed" and colors.accent or colors.background
    randomButton.BackgroundColor3=draftMode=="random" and colors.accent or colors.background
end
local function refreshSummary()
    delaySummary.Text=settings.mode=="fixed"
        and string.format("Задержка: %.2g сек.",settings.fixed)
        or string.format("Случайная задержка: %.2g–%.2g сек.",settings.minimum,settings.maximum)
end
local function refreshAuto()
    autoButton.Text=state.auto and "Авто: ВКЛ" or "Авто: ВЫКЛ"
    autoButton.BackgroundColor3=state.auto and Color3.fromRGB(28,99,75) or colors.card
end
autoButton.Activated:Connect(function()
    state.auto=not state.auto
    autoRound.pendingAt=nil
    refreshAuto()
    autoStatus.Text=state.auto and "Ожидание правильного варианта..." or "Ручной выбор ответа"
end)
fixedButton.Activated:Connect(function() draftMode="fixed"; refreshMode() end)
randomButton.Activated:Connect(function() draftMode="random"; refreshMode() end)
applyButton.Activated:Connect(function()
    local parsed,err=parseDelaySettings(draftMode,fixedInput.Text,minInput.Text,maxInput.Text)
    if not parsed then
        settingsMessage.TextColor3=Color3.fromRGB(255,150,150)
        settingsMessage.Text=err
        return
    end
    for key,value in pairs(parsed) do settings[key]=value end
    autoRound.pendingAt=nil
    refreshSummary()
    settingsMessage.TextColor3=colors.green
    settingsMessage.Text="Сохранено. Задержка отсчитывается до клика."
end)
local collapsed=false
local function fitWindow()
    local camera=workspace.CurrentCamera
    if not camera then return end
    local viewport=camera.ViewportSize
    windowScale.Scale=math.min(1,math.max(0.35,(viewport.X-24)/350),math.max(0.35,(viewport.Y-24)/460))
    local width,height=350*windowScale.Scale,root.Size.Y.Offset*windowScale.Scale
    root.Position=UDim2.fromOffset(
        math.clamp(root.Position.X.Offset,8,math.max(8,viewport.X-width-8)),
        math.clamp(root.Position.Y.Offset,8,math.max(8,viewport.Y-height-8)))
end
local function resizeWindow()
    body.Visible=not collapsed
    root.Size=UDim2.fromOffset(350,collapsed and 46 or (settingsFrame.Visible and 460 or 232))
    minimize.Text=collapsed and "+" or "−"
    fitWindow()
end
settingsButton.Activated:Connect(function()
    settingsFrame.Visible=not settingsFrame.Visible
    resizeWindow()
end)
minimize.Activated:Connect(function() collapsed=not collapsed; resizeWindow() end)
refreshMode()
refreshSummary()
fitWindow()
if workspace.CurrentCamera then
    state.connections[#state.connections+1]=workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitWindow)
end
-- Drag the header; all global input connections are cleaned up on rerun.
local UIS=game:GetService("UserInputService")
local dragging,dragStart,startPosition,dragTouch=false,nil,nil,nil
header.InputBegan:Connect(function(event)
    if event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch then
        dragging=true; dragStart=event.Position; startPosition=root.Position
        dragTouch=event.UserInputType==Enum.UserInputType.Touch and event or nil
    end
end)
state.connections[#state.connections+1]=UIS.InputChanged:Connect(function(event)
    if dragging and ((not dragTouch and event.UserInputType==Enum.UserInputType.MouseMovement) or event==dragTouch) then
        local delta=event.Position-dragStart
        root.Position=UDim2.fromOffset(startPosition.X.Offset+delta.X,startPosition.Y.Offset+delta.Y)
        fitWindow()
    end
end)
state.connections[#state.connections+1]=UIS.InputEnded:Connect(function(event)
    if event==dragTouch or (not dragTouch and event.UserInputType==Enum.UserInputType.MouseButton1) then
        dragging=false; dragTouch=nil
    end
end)
local function find(root,path)
    for name in path:gmatch("[^.]+") do
        root = root and root:FindFirstChild(name)
        if not root then return nil end
    end
    return root
end
local function visible(obj)
    if not obj or not obj:IsDescendantOf(gui) then return false end
    while obj and obj ~= gui do
        if obj:IsA("GuiObject") and not obj.Visible then return false end
        if obj:IsA("ScreenGui") and not obj.Enabled then return false end
        obj = obj.Parent
    end
    return true
end
local coinValues = {Nickel=5,Penny=1,Dime=10,Quarter=25}
local coinImages = {
    ["2025552010"]=5,["2025533936"]=1,["2025544294"]=10,["2025554507"]=25,
}
local function graphicData(center)
    local data = {}
    local content = center:FindFirstChild("ContentFrame")
    if not visible(content) then return data end
    for _, entry in ipairs({{"ShapeObject","rectangle"},{"TriangleObject","triangle"}}) do
        local shape=content:FindFirstChild(entry[1])
        if visible(shape) then
            local width=find(shape,"WidthSizeFrame.SizeLabel")
            local height=find(shape,"HeightSizeFrame.SizeLabel")
            if visible(width) and visible(height) then
                data[entry[2]]={width=calculate(width.Text),height=calculate(height.Text)}
            end
        end
    end
    local clock=content:FindFirstChild("AnalogClockFrame")
    if visible(clock) then
        local hour=clock:FindFirstChild("HOUR_HAND")
        local minute=clock:FindFirstChild("MINUTE_HAND")
        if visible(hour) and visible(minute) then
            data.clock={hour=hour.Rotation,minute=minute.Rotation}
        end
    end
    local coins=content:FindFirstChild("HowManyFrame")
    if visible(coins) then
        local total,count,unknown=0,0,false
        for _, obj in ipairs(coins:GetDescendants()) do
            if visible(obj) and (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) then
                local id=obj.Image:match("%d+")
                local value=coinValues[obj.Name] or coinImages[id]
                -- A coin can contain decorative images: count just the outer coin.
                local parent,insideCoin=obj.Parent,false
                while parent and parent~=coins do
                    if coinValues[parent.Name] then insideCoin=true; break end
                    parent=parent.Parent
                end
                if value and not insideCoin then total=total+value; count=count+1 end
                if not value and not insideCoin then
                    local hasCoinChild=false
                    for _, child in ipairs(obj:GetDescendants()) do
                        if coinValues[child.Name] then hasCoinChild=true; break end
                    end
                    if not hasCoinChild then unknown=true end
                end
            end
        end
        if count>0 and not unknown then data.moneyCents=total end
    end
    local angles=content:FindFirstChild("AngleFrame")
    if visible(angles) then
        for _, obj in ipairs(angles:GetChildren()) do
            if visible(obj) then
                local first=obj:FindFirstChild("ANGLE1")
                local second=obj:FindFirstChild("ANGLE2")
                if visible(first) and visible(second) then
                    if data.angle then data.angle=nil; break end
                    data.angle={first=first.Rotation,second=second.Rotation,
                        lines=obj.Name:match("^lines")~=nil}
                end
            end
        end
    end
    return data
end
local function answerMatches(result,text)
    if type(result)=="number" then
        local n=calculate(text)
        return n~=nil and close(result,n)
    end
    local s=clean(text):gsub("%s+", ""):lower()
    local normalizedResult=clean(result):gsub("%s+", ""):lower()
    if result=="even" then return s=="even" or s=="чётное" or s=="четное" end
    if result=="odd" then return s=="odd" or s=="нечётное" or s=="нечетное" end
    if s==normalizedResult then return true end
    local aliases={
        ["Right Angle"]={"right","прямой","прямойугол"},
        ["Acute Angle"]={"acute","острый","острыйугол"},
        ["Obtuse Angle"]={"obtuse","тупой","тупойугол"},
        ["Straight Angle"]={"straight","развёрнутый","развернутый","развёрнутыйугол"},
        ["Parallel Lines"]={"parallel","параллельные","параллельныелинии"},
        ["Perpendicular Lines"]={"perpendicular","перпендикулярные","перпендикулярныелинии"},
        ["Intersecting Lines"]={"intersecting","пересекающиеся","пересекающиесялинии"},
    }
    for _, alias in ipairs(aliases[result] or {}) do if s==alias then return true end end
    if result:find("¢$",1) then
        local cents=tonumber(result:match("^(%d+)"))
        if s:find("¢",1,true) then return tonumber(s:match("[%d%.]+"))==cents end
        if s:find("$",1,true) then
            local dollars=tonumber(s:match("[%d%.]+"))
            return dollars~=nil and close(dollars*100,cents)
        end
        local n=calculate(text)
        if n then return close(n,cents) end
    end
    if result:match("^%d+:%d%d$") then
        local h,m=s:match("^(%d+):(%d%d)$")
        local rh,rm=result:match("^(%d+):(%d%d)$")
        return h~=nil and tonumber(h)%12==tonumber(rh)%12 and tonumber(m)==tonumber(rm)
    end
    if result:find("%%$") then
        local a,b=calculate(result),calculate(text)
        return a~=nil and b~=nil and close(a,b)
    end
    return false
end
local function safeRead(object,key)
    local ok,value=pcall(function() return object[key] end)
    if ok then return value end
end
local function clickCenter(btn)
    local x=btn.AbsolutePosition.X+btn.AbsoluteSize.X/2
    local y=btn.AbsolutePosition.Y+btn.AbsoluteSize.Y/2
    local screen=btn:FindFirstAncestorWhichIsA("ScreenGui")
    if screen and not screen.IgnoreGuiInset then
        local ok,inset=pcall(function() return game:GetService("GuiService"):GetGuiInset() end)
        if ok then x=x+inset.X; y=y+inset.Y end
    end
    return math.floor(x+0.5),math.floor(y+0.5)
end
local function virtualClick(btn)
    local x,y=clickCenter(btn)
    local lastError
    -- Use Roblox's virtual-input API where it is available.
    local ok,input=pcall(function()
        return game:GetService("UserInputService"):CreateVirtualInput()
    end)
    if ok and input then
        local pressed=false
        local success,err=pcall(function()
            input:SendMousePosition(Vector2.new(x,y))
            input:SendMouseButton(Vector2.new(x,y),Enum.UserInputType.MouseButton1,true,0)
            pressed=true
            task.wait(0.04)
            input:SendMouseButton(Vector2.new(x,y),Enum.UserInputType.MouseButton1,false,0)
        end)
        if success then return true,"Отправлен клик VirtualInput" end
        lastError=tostring(err)
        if pressed then
            pcall(function()
                input:SendMouseButton(Vector2.new(x,y),Enum.UserInputType.MouseButton1,false,0)
            end)
            return false,lastError
        end
    elseif not ok then lastError=tostring(input) end
    -- Some executors expose the internal input service instead.
    local pressed=false
    local manager
    local success,err=pcall(function()
        manager=game:GetService("VirtualInputManager")
        manager:SendMouseButtonEvent(x,y,0,true,game,0)
        pressed=true
        task.wait(0.04)
        manager:SendMouseButtonEvent(x,y,0,false,game,0)
    end)
    if success then return true,"Отправлен клик VirtualInputManager" end
    if pressed then
        pcall(function() manager:SendMouseButtonEvent(x,y,0,false,game,0) end)
    end
    return false,tostring(err or lastError or "Виртуальный ввод недоступен")
end
local function sendAnswer(btn)
    if not visible(btn) or not btn.Active or not btn.Interactable then
        return false,"Кнопка ответа недоступна"
    end
    if type(firesignal)=="function" then
        local ok,err=pcall(function() firesignal(btn.Activated,nil,1) end)
        if ok then return true,"Отправлен сигнал Activated" end
    end
    -- Try one event only, so a single answer is not submitted through several events.
    for _, name in ipairs(type(getconnections)=="function" and {"Activated","MouseButton1Click"} or {}) do
        local ok,connections=pcall(function() return getconnections(btn[name]) end)
        if ok and type(connections)=="table" then
            local sent=0
            local lastError
            for _, connection in ipairs(connections) do
                local success,called=pcall(function()
                    if safeRead(connection,"Enabled")==false
                        or safeRead(connection,"Connected")==false
                        or safeRead(connection,"ForeignState")==true then return false end
                    local args
                    if name=="Activated" then
                        args=table.pack(nil,1)
                    else
                        args=table.pack(btn.AbsolutePosition.X+btn.AbsoluteSize.X/2,
                            btn.AbsolutePosition.Y+btn.AbsoluteSize.Y/2)
                    end
                    local fire=safeRead(connection,"Fire")
                    if type(fire)=="function" then
                        fire(connection,table.unpack(args,1,args.n))
                        return true
                    end
                    local callback=safeRead(connection,"Function")
                    if type(callback)=="function" then
                        callback(table.unpack(args,1,args.n))
                        return true
                    end
                    return false
                end)
                if success and called then sent=sent+1 end
                if not success then lastError=tostring(called) end
            end
            if sent>0 then return true,"Вызван обработчик "..name end
            if lastError then warn("MATH HELPER: обработчик недоступен:",lastError) end
        end
    end
    return virtualClick(btn)
end
local function observeRound(signature,countdown,now)
    if signature~=autoRound.signature or (countdown and autoRound.countdown
        and countdown>autoRound.countdown+1) then
        autoRound.signature=signature
        autoRound.since=now
        autoRound.handled=false
        autoRound.pendingAt=nil
        autoRound.delay=nil
        if state.auto then autoStatus.Text="Ожидание обновления вопроса..." end
    end
    autoRound.countdown=countdown
end
local function update()
    local gameplay=gui:FindFirstChild("Gameplay")
    local topic,center
    for _, name in ipairs({"TopicFrame", "TopicFrameBottom"}) do
        local candidateCenter=find(gameplay,"TopicGui."..name..".CenterFrame")
        if visible(candidateCenter) then
            local candidate=candidateCenter:FindFirstChild("TopicLabel")
            local side=candidateCenter:FindFirstChild("SideTopicLabel")
            if visible(candidate) or visible(side) then
                center=candidateCenter
                topic=visible(candidate) and candidate or side
                break
            end
        end
    end
    if not topic then
        label.Text="Ожидание вопроса..."
        autoRound.signature=nil
        autoRound.handled=false
        autoRound.countdown=nil
        autoRound.pendingAt=nil
        if state.auto then autoStatus.Text="Ожидание нового вопроса..." end
        return
    end
    local answers={}
    local input=find(gameplay,"AnswerGui.AnswerFrame.CenterFrame.InputFrame")
    if visible(input) then
        for i=1,4 do
            local btn=find(input,"Answer"..i..".TriggerBtn")
            if btn and btn:IsA("TextButton") and visible(btn) then
                answers[#answers+1]={text=btn.Text,index=i}
            end
        end
    end
    local side=center:FindFirstChild("SideTopicLabel")
    local instruction=side and visible(side) and side.Text or ""
    local result=solveGraphic(graphicData(center),instruction)
    if result==nil and topic.Name=="TopicLabel" then result=solve(topic.Text,answers,instruction) end
    local parts={topic.Text,instruction,tostring(result)}
    for _, answer in ipairs(answers) do parts[#parts+1]=answer.index..":"..answer.text end
    local timer=center:FindFirstChild("CountdownLabel")
    local minutes,seconds
    if timer then minutes,seconds=timer.Text:match("(%d+):(%d+)") end
    local countdown=minutes and tonumber(minutes)*60+tonumber(seconds) or nil
    observeRound(table.concat(parts,"|"),countdown,os.clock())
    if result==nil then
        label.TextColor3=Color3.fromRGB(255,210,100)
        label.Text="Не распознано: "..topic.Text
        autoRound.pendingAt=nil
        if state.auto then autoStatus.Text="Этот вопрос нужно решить вручную" end
        return
    end
    local index
    for _, answer in ipairs(answers) do
        if answerMatches(result,answer.text) then index=answer.index; break end
    end
    local displayed=type(result)=="number" and string.format("%.10g",result) or result
    if result=="even" then displayed="Чётное" elseif result=="odd" then displayed="Нечётное" end
    label.TextColor3=Color3.fromRGB(100,255,140)
    label.Text="Ответ: "..displayed..(index and "  |  Кнопка: "..index or "")
    if not state.auto or autoRound.handled then return end
    if not index then
        autoRound.pendingAt=nil
        autoStatus.Text="Нет подходящей кнопки — выбери ответ вручную"
        return
    end
    local now=os.clock()
    if now-autoRound.since<0.35 then return end
    local btn=find(input,"Answer"..index..".TriggerBtn")
    if not visible(btn) or not btn.Active or not btn.Interactable then
        autoRound.pendingAt=nil
        return
    end
    if countdown and countdown<=0 then
        autoRound.handled=true
        autoRound.pendingAt=nil
        autoStatus.Text="Время вопроса истекло — ответ пропущен"
        return
    end
    if not autoRound.pendingAt then
        autoRound.delay=pickDelay(settings)
        autoRound.pendingAt=now+autoRound.delay
    end
    local remaining=autoRound.pendingAt-now
    if remaining>0 then
        autoStatus.Text=string.format("Нажатие через %.1f сек.  ·  Задержка %.1f сек.",remaining,autoRound.delay)
        return
    end
    autoRound.handled=true
    local ok,message=sendAnswer(btn)
    if ok then
        autoStatus.Text="Кнопка "..index..": "..message
    else
        state.auto=false
        refreshAuto()
        autoStatus.Text="Авто отключено: "..message
        warn("MATH HELPER AUTO:",message)
    end
end
print("MATH HELPER: запущен; авто выключено, включается кнопкой")
task.spawn(function()
    while state.running and panel.Parent do
        task.wait(0.25)
        if not state.running then break end
        local ok,err=pcall(update)
        if not ok then
            label.Text="Ошибка: "..tostring(err)
            warn("MATH HELPER:",err)
            break
        end
    end
end)
