--[[
╔══════════════════════════════════════════════════════════════════╗
║              ViaLua Ai Coder  ·  v2.6.0                        ║
║  Normal UI options:                                            ║
║    • Profile          (Roblox info + HWID)                     ║
║    • Studio lite auto Code  (AI coding)                        ║
║  Private UI: vialua Ai logs (Owner key system, max 10 users)   ║
╚══════════════════════════════════════════════════════════════════╝
--]]

-- ═══════════════════════════════════════════════════════════════
--  EXECUTOR COMPAT
-- ═══════════════════════════════════════════════════════════════
local httpRequest = (syn and syn.request)
    or (http and http.request)
    or (request and request)
    or error("[ViaLua] No HTTP request function found.")

local function safeSpawn(fn)
    if task and task.spawn then task.spawn(fn) else coroutine.wrap(fn)() end
end

local function safeWait(t)
    if task and task.wait then task.wait(t or 0) else wait(t or 0) end
end

-- ═══════════════════════════════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════════════════════════════
local CFG = {
    KEY_URL    = "https://pastebin.com/raw/par3cMZt",
    KEY_LINK   = "https://linkvertise.com/9491639/UbGlxUkYstt2",
    OPENAI_KEY = "YOUR_OPENAI_API_KEY",
    CLAUDE_KEY = "YOUR_ANTHROPIC_API_KEY",
    GROK_KEY   = "YOUR_XAI_API_KEY",

    -- Owner Master Key (change this!)
    OWNER_MASTER_KEY = "Via_31A_WJN_9XO_Lua",
    MAX_PRIVATE_USERS = 10,
}

-- ═══════════════════════════════════════════════════════════════
--  AI MODELS
-- ═══════════════════════════════════════════════════════════════
local AI = {
    chatgpt = { label = "ChatGPT", models = {"gpt-4o-mini", "gpt-4.1-mini", "gpt-3.5-turbo"} },
    claude  = { label = "Claude",  models = {"claude-haiku-5-5", "claude-haiku-4-5", "claude-3-5-sonnet", "claude-sonnet-4"} },
    grok    = { label = "Grok",    models = {"grok-3-mini", "grok-2-mini", "grok-beta"} },
}

-- ═══════════════════════════════════════════════════════════════
--  SERVICES + STORAGE
-- ═══════════════════════════════════════════════════════════════
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local lp = Players.LocalPlayer

local STORAGE = {
    REMEMBER     = "ViaLua_RememberKey.txt",
    PRIVATE_KEYS = "ViaLua_PrivateKeys.txt",
    ADMIN_CHAT   = "ViaLua_AdminChat.txt",
    LOGS         = "ViaLua_Logs.txt",
    ORDERS       = "ViaLua_Orders.txt",
}

local function saveFile(name, data)
    pcall(function()
        if writefile then writefile(name, data)
        else getgenv()[name] = data end
    end)
end

local function loadFile(name)
    local raw
    pcall(function()
        if isfile and isfile(name) then raw = readfile(name)
        elseif getgenv()[name] then raw = getgenv()[name] end
    end)
    return raw
end

-- ═══════════════════════════════════════════════════════════════
--  HWID
-- ═══════════════════════════════════════════════════════════════
local function getHWID()
    local hwid = "Unknown"
    pcall(function()
        if gethwid then
            hwid = gethwid()
        elseif getexecutorname then
            hwid = getexecutorname() .. "_" .. tostring(lp.UserId)
        else
            hwid = tostring(lp.UserId) .. "_" .. tostring(game.PlaceId)
        end
    end)
    return tostring(hwid)
end

-- ═══════════════════════════════════════════════════════════════
--  PRIVATE KEY SYSTEM
-- ═══════════════════════════════════════════════════════════════
local function getPrivateKeys()
    local raw = loadFile(STORAGE.PRIVATE_KEYS) or ""
    local keys = {}
    for line in string.gmatch(raw .. "\n", "([^\r\n]*)\r?\n") do
        line = string.match(line, "^%s*(.-)%s*$")
        if line ~= "" then table.insert(keys, line) end
    end
    return keys
end

local function savePrivateKeys(keys)
    saveFile(STORAGE.PRIVATE_KEYS, table.concat(keys, "\n"))
end

local function generatePrivateKey()
    local chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    local key = "VL-"
    for i = 1, 12 do
        local r = math.random(1, #chars)
        key = key .. string.sub(chars, r, r)
        if i == 4 or i == 8 then key = key .. "-" end
    end
    return key
end

local function isValidPrivateKey(key)
    if key == CFG.OWNER_MASTER_KEY then return true, "OWNER" end
    local keys = getPrivateKeys()
    for _, k in ipairs(keys) do
        if k == key then return true, "USER" end
    end
    return false, nil
end

local function addLog(text)
    local old = loadFile(STORAGE.LOGS) or ""
    saveFile(STORAGE.LOGS, old .. "[" .. os.date("%H:%M:%S") .. "] " .. text .. "\n")
end

local function getLogs()
    return loadFile(STORAGE.LOGS) or "No logs yet."
end

local function addOrder(text)
    local old = loadFile(STORAGE.ORDERS) or ""
    saveFile(STORAGE.ORDERS, old .. "[" .. os.date("%H:%M:%S") .. "] ORDER: " .. text .. "\n")
    addLog("Owner issued order: " .. text)
end

local function getOrders()
    return loadFile(STORAGE.ORDERS) or "No orders yet."
end

local function addAdminMessage(sender, text)
    local old = loadFile(STORAGE.ADMIN_CHAT) or ""
    saveFile(STORAGE.ADMIN_CHAT, old .. "[" .. os.date("%H:%M:%S") .. "] " .. sender .. ": " .. text .. "\n")
end

local function getAdminChat()
    return loadFile(STORAGE.ADMIN_CHAT) or "No messages yet."
end

-- ═══════════════════════════════════════════════════════════════
--  NORMAL KEY SYSTEM
-- ═══════════════════════════════════════════════════════════════
local function validateKey(raw)
    local key = string.match(tostring(raw or ""), "^%s*(.-)%s*$")
    if not key or key == "" then return false, "Key cannot be empty." end
    local ok, res = pcall(function()
        return httpRequest({ Url = CFG.KEY_URL, Method = "GET" })
    end)
    if not ok or not res then return false, "Cannot reach key server." end
    if res.StatusCode and res.StatusCode ~= 200 then
        return false, "Key server error: " .. tostring(res.StatusCode)
    end
    local body = res.Body or res.body or ""
    if string.find(body, key, 1, true) then
        return true, "Key valid — 24h access"
    end
    return false, "Invalid key."
end

local function saveRemember(key)
    saveFile(STORAGE.REMEMBER, key .. "|" .. tostring(os.time() + 86400))
end

local function loadRemember()
    local raw = loadFile(STORAGE.REMEMBER)
    if not raw then return nil end
    local key, exp = string.match(raw, "^(.-)|(%d+)$")
    if key and exp and os.time() < tonumber(exp) then return key end
    return nil
end

-- ═══════════════════════════════════════════════════════════════
--  UI HELPERS
-- ═══════════════════════════════════════════════════════════════
local function makeDraggable(frame, handle)
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function makeResizable(frame)
    local resize = Instance.new("TextButton")
    resize.Size = UDim2.new(0,16,0,16)
    resize.Position = UDim2.new(1,-16,1,-16)
    resize.BackgroundColor3 = Color3.fromRGB(110,90,220)
    resize.BackgroundTransparency = 0.3
    resize.Text = ""
    resize.ZIndex = 10
    resize.Parent = frame
    Instance.new("UICorner", resize).CornerRadius = UDim.new(0,4)

    local resizing, startPos, startSize
    resize.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = true
            startPos = input.Position
            startSize = frame.Size
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then resizing = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - startPos
            frame.Size = UDim2.new(0, math.clamp(startSize.X.Offset + delta.X, 400, 900), 0, math.clamp(startSize.Y.Offset + delta.Y, 320, 700))
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════
--  LOADING SCREEN
-- ═══════════════════════════════════════════════════════════════
local function showLoadingScreen(callback)
    local gui = Instance.new("ScreenGui")
    gui.Name = "ViaLua_Loading"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    pcall(function() gui.Parent = CoreGui end)
    if not gui.Parent then gui.Parent = lp:WaitForChild("PlayerGui") end

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1,0,1,0)
    bg.BackgroundColor3 = Color3.fromRGB(8,8,12)
    bg.BorderSizePixel = 0
    bg.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,0,0,40)
    title.Position = UDim2.new(0,0,0.42,0)
    title.BackgroundTransparency = 1
    title.Text = "ViaLua Ai Coder"
    title.TextColor3 = Color3.fromRGB(180,180,255)
    title.TextSize = 28
    title.Font = Enum.Font.GothamBold
    title.Parent = bg

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1,0,0,24)
    status.Position = UDim2.new(0,0,0.48,0)
    status.BackgroundTransparency = 1
    status.Text = "Loading..."
    status.TextColor3 = Color3.fromRGB(140,140,160)
    status.TextSize = 15
    status.Font = Enum.Font.Gotham
    status.Parent = bg

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(0,280,0,6)
    barBg.Position = UDim2.new(0.5,-140,0.55,0)
    barBg.BackgroundColor3 = Color3.fromRGB(30,30,40)
    barBg.BorderSizePixel = 0
    barBg.Parent = bg
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(1,0)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0,0,1,0)
    bar.BackgroundColor3 = Color3.fromRGB(110,110,255)
    bar.BorderSizePixel = 0
    bar.Parent = barBg
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)

    safeSpawn(function()
        for i = 1, 5 do
            status.Text = ({"Loading modules...","Checking executor...","Preparing systems...","Almost ready...","Starting..."})[i]
            pcall(function()
                TweenService:Create(bar, TweenInfo.new(0.9), {Size = UDim2.new(i/5,0,1,0)}):Play()
            end)
            safeWait(1)
        end
        gui:Destroy()
        if callback then callback() end
    end)
end

-- ═══════════════════════════════════════════════════════════════
--  NORMAL KEY SYSTEM
-- ═══════════════════════════════════════════════════════════════
local function createKeySystem(onSuccess)
    local gui = Instance.new("ScreenGui")
    gui.Name = "ViaLua_KeySystem"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    pcall(function() gui.Parent = CoreGui end)
    if not gui.Parent then gui.Parent = lp:WaitForChild("PlayerGui") end

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1,0,1,0)
    bg.BackgroundColor3 = Color3.fromRGB(10,10,18)
    bg.BorderSizePixel = 0
    bg.Parent = gui

    local flash = Instance.new("Frame")
    flash.Size = UDim2.new(1,0,1,0)
    flash.BackgroundColor3 = Color3.fromRGB(40,20,80)
    flash.BackgroundTransparency = 0.85
    flash.BorderSizePixel = 0
    flash.Parent = bg

    safeSpawn(function()
        while flash and flash.Parent do
            pcall(function()
                TweenService:Create(flash, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.7}):Play()
            end)
            safeWait(1.2)
            pcall(function()
                TweenService:Create(flash, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.92}):Play()
            end)
            safeWait(1.2)
        end
    end)

    local card = Instance.new("Frame")
    card.Size = UDim2.new(0,380,0,320)
    card.Position = UDim2.new(0.5,-190,0.5,-160)
    card.BackgroundColor3 = Color3.fromRGB(16,16,24)
    card.BorderSizePixel = 0
    card.Parent = bg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0,14)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(90,70,180)
    stroke.Thickness = 1.5
    stroke.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,0,0,40)
    title.Position = UDim2.new(0,0,0,12)
    title.BackgroundTransparency = 1
    title.Text = "🔑  ViaLua Key System"
    title.TextColor3 = Color3.fromRGB(230,230,255)
    title.TextSize = 20
    title.Font = Enum.Font.GothamBold
    title.Parent = card

    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(1,-40,0,36)
    copyBtn.Position = UDim2.new(0,20,0,60)
    copyBtn.BackgroundColor3 = Color3.fromRGB(70,50,160)
    copyBtn.Text = "📋  Copy Key Link"
    copyBtn.TextColor3 = Color3.fromRGB(255,255,255)
    copyBtn.TextSize = 14
    copyBtn.Font = Enum.Font.GothamSemibold
    copyBtn.Parent = card
    Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0,8)

    copyBtn.MouseButton1Click:Connect(function()
        pcall(function()
            if setclipboard then setclipboard(CFG.KEY_LINK)
            elseif toclipboard then toclipboard(CFG.KEY_LINK) end
        end)
        copyBtn.Text = "✅  Copied!"
        safeWait(1.5)
        copyBtn.Text = "📋  Copy Key Link"
    end)

    local boxHolder = Instance.new("Frame")
    boxHolder.Size = UDim2.new(1,-40,0,40)
    boxHolder.Position = UDim2.new(0,20,0,115)
    boxHolder.BackgroundColor3 = Color3.fromRGB(28,28,40)
    boxHolder.BorderSizePixel = 0
    boxHolder.Parent = card
    Instance.new("UICorner", boxHolder).CornerRadius = UDim.new(0,8)

    local keyBox = Instance.new("TextBox")
    keyBox.Size = UDim2.new(1,-16,1,0)
    keyBox.Position = UDim2.new(0,8,0,0)
    keyBox.BackgroundTransparency = 1
    keyBox.PlaceholderText = "Paste your key here..."
    keyBox.PlaceholderColor3 = Color3.fromRGB(90,90,110)
    keyBox.TextColor3 = Color3.fromRGB(220,220,240)
    keyBox.TextSize = 14
    keyBox.Font = Enum.Font.Gotham
    keyBox.ClearTextOnFocus = false
    keyBox.Text = ""
    keyBox.Parent = boxHolder

    local remember = false
    local checkBtn = Instance.new("TextButton")
    checkBtn.Size = UDim2.new(0,22,0,22)
    checkBtn.Position = UDim2.new(0,22,0,170)
    checkBtn.BackgroundColor3 = Color3.fromRGB(40,40,55)
    checkBtn.Text = ""
    checkBtn.TextColor3 = Color3.fromRGB(255,255,255)
    checkBtn.TextSize = 14
    checkBtn.Font = Enum.Font.GothamBold
    checkBtn.Parent = card
    Instance.new("UICorner", checkBtn).CornerRadius = UDim.new(0,5)

    local checkLabel = Instance.new("TextLabel")
    checkLabel.Size = UDim2.new(0,200,0,22)
    checkLabel.Position = UDim2.new(0,52,0,170)
    checkLabel.BackgroundTransparency = 1
    checkLabel.Text = "Remember key (24 hours)"
    checkLabel.TextColor3 = Color3.fromRGB(160,160,180)
    checkLabel.TextSize = 13
    checkLabel.Font = Enum.Font.Gotham
    checkLabel.TextXAlignment = Enum.TextXAlignment.Left
    checkLabel.Parent = card

    checkBtn.MouseButton1Click:Connect(function()
        remember = not remember
        checkBtn.BackgroundColor3 = remember and Color3.fromRGB(80,160,90) or Color3.fromRGB(40,40,55)
        checkBtn.Text = remember and "✓" or ""
    end)

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1,-40,0,20)
    status.Position = UDim2.new(0,20,0,205)
    status.BackgroundTransparency = 1
    status.Text = ""
    status.TextColor3 = Color3.fromRGB(220,80,80)
    status.TextSize = 13
    status.Font = Enum.Font.Gotham
    status.Parent = card

    local contBtn = Instance.new("TextButton")
    contBtn.Size = UDim2.new(1,-40,0,42)
    contBtn.Position = UDim2.new(0,20,0,240)
    contBtn.BackgroundColor3 = Color3.fromRGB(50,160,100)
    contBtn.Text = "Continue"
    contBtn.TextColor3 = Color3.fromRGB(255,255,255)
    contBtn.TextSize = 16
    contBtn.Font = Enum.Font.GothamBold
    contBtn.Parent = card
    Instance.new("UICorner", contBtn).CornerRadius = UDim.new(0,8)

    local saved = loadRemember()
    if saved then
        keyBox.Text = saved
        remember = true
        checkBtn.BackgroundColor3 = Color3.fromRGB(80,160,90)
        checkBtn.Text = "✓"
    end

    local function tryContinue()
        contBtn.Text = "Checking..."
        contBtn.BackgroundColor3 = Color3.fromRGB(70,70,100)
        status.Text = ""
        safeSpawn(function()
            local valid, msg = validateKey(keyBox.Text)
            if valid then
                status.TextColor3 = Color3.fromRGB(80,200,120)
                status.Text = "✓  " .. msg
                if remember then saveRemember(keyBox.Text) end
                safeWait(0.8)
                contBtn.Text = "Loading..."
                safeWait(2)
                gui:Destroy()
                if onSuccess then onSuccess() end
            else
                status.TextColor3 = Color3.fromRGB(220,80,80)
                status.Text = "✕  " .. msg
                contBtn.Text = "Continue"
                contBtn.BackgroundColor3 = Color3.fromRGB(50,160,100)
            end
        end)
    end

    contBtn.MouseButton1Click:Connect(tryContinue)
    keyBox.FocusLost:Connect(function(enter) if enter then tryContinue() end end)
end

-- ═══════════════════════════════════════════════════════════════
--  NORMAL PUBLIC UI  (Sidebar style like WindUI)
-- ═══════════════════════════════════════════════════════════════
local function createPublicUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "ViaLua_Public"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() gui.Parent = CoreGui end)
    if not gui.Parent then gui.Parent = lp:WaitForChild("PlayerGui") end

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 520, 0, 400)
    main.Position = UDim2.new(0.5, -260, 0.5, -200)
    main.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
    main.BorderSizePixel = 0
    main.Parent = gui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(70, 55, 140)
    stroke.Thickness = 1.5
    stroke.Parent = main

    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = main
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12)

    local titleFix = Instance.new("Frame")
    titleFix.Size = UDim2.new(1, 0, 0.5, 0)
    titleFix.Position = UDim2.new(0, 0, 0.5, 0)
    titleFix.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
    titleFix.BorderSizePixel = 0
    titleFix.Parent = titleBar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -50, 1, 0)
    title.Position = UDim2.new(0, 14, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🤖  ViaLua Ai Coder"
    title.TextColor3 = Color3.fromRGB(230, 230, 245)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -36, 0.5, -14)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 60)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = titleBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

    makeDraggable(main, titleBar)
    makeResizable(main)

    -- ========== LEFT SIDEBAR ==========
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 140, 1, -50)
    sidebar.Position = UDim2.new(0, 8, 0, 46)
    sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    sidebar.BorderSizePixel = 0
    sidebar.Parent = main
    Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 10)

    local sideLayout = Instance.new("UIListLayout")
    sideLayout.Padding = UDim.new(0, 6)
    sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sideLayout.Parent = sidebar

    local sidePad = Instance.new("UIPadding")
    sidePad.PaddingTop = UDim.new(0, 10)
    sidePad.PaddingLeft = UDim.new(0, 8)
    sidePad.PaddingRight = UDim.new(0, 8)
    sidePad.Parent = sidebar

    local function createSideBtn(text, order)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 36)
        b.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
        b.Text = text
        b.TextColor3 = Color3.fromRGB(180, 180, 200)
        b.TextSize = 13
        b.Font = Enum.Font.GothamSemibold
        b.LayoutOrder = order
        b.Parent = sidebar
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        return b
    end

    local tabProfile = createSideBtn("Profile", 1)
    local tabStudio  = createSideBtn("Studio lite", 2)

    -- ========== CONTENT AREA ==========
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -160, 1, -56)
    content.Position = UDim2.new(0, 156, 0, 48)
    content.BackgroundTransparency = 1
    content.Parent = main

    local pageProfile = Instance.new("Frame")
    pageProfile.Size = UDim2.new(1, 0, 1, 0)
    pageProfile.BackgroundTransparency = 1
    pageProfile.Parent = content

    local pageStudio = Instance.new("Frame")
    pageStudio.Size = UDim2.new(1, 0, 1, 0)
    pageStudio.BackgroundTransparency = 1
    pageStudio.Visible = false
    pageStudio.Parent = content

    local function showTab(name)
        pageProfile.Visible = (name == "profile")
        pageStudio.Visible = (name == "studio")
        tabProfile.BackgroundColor3 = name == "profile" and Color3.fromRGB(70, 55, 160) or Color3.fromRGB(35, 35, 50)
        tabStudio.BackgroundColor3  = name == "studio"  and Color3.fromRGB(70, 55, 160) or Color3.fromRGB(35, 35, 50)
        tabProfile.TextColor3 = name == "profile" and Color3.fromRGB(255,255,255) or Color3.fromRGB(180,180,200)
        tabStudio.TextColor3  = name == "studio"  and Color3.fromRGB(255,255,255) or Color3.fromRGB(180,180,200)
    end

    tabProfile.MouseButton1Click:Connect(function() showTab("profile") end)
    tabStudio.MouseButton1Click:Connect(function() showTab("studio") end)
    showTab("profile")

    -- ========== PROFILE PAGE ==========
    local function addInfo(parent, label, value, y)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 18)
        l.Position = UDim2.new(0, 0, 0, y)
        l.BackgroundTransparency = 1
        l.Text = label
        l.TextColor3 = Color3.fromRGB(140, 140, 165)
        l.TextSize = 12
        l.Font = Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = parent

        local v = Instance.new("TextLabel")
        v.Size = UDim2.new(1, 0, 0, 20)
        v.Position = UDim2.new(0, 0, 0, y + 16)
        v.BackgroundTransparency = 1
        v.Text = value
        v.TextColor3 = Color3.fromRGB(220, 220, 240)
        v.TextSize = 14
        v.Font = Enum.Font.GothamSemibold
        v.TextXAlignment = Enum.TextXAlignment.Left
        v.TextTruncate = Enum.TextTruncate.AtEnd
        v.Parent = parent
    end

    local username = lp.Name
    local displayName = lp.DisplayName
    local userId = tostring(lp.UserId)
    local accountAge = tostring(lp.AccountAge) .. " days"
    local hwid = getHWID()
    local created = "Unknown"
    pcall(function()
        created = os.date("%Y-%m-%d", os.time() - (lp.AccountAge * 86400))
    end)

    addInfo(pageProfile, "Username", username, 8)
    addInfo(pageProfile, "Display Name", displayName, 55)
    addInfo(pageProfile, "User ID", userId, 102)
    addInfo(pageProfile, "Account Created", created .. "  (" .. accountAge .. ")", 149)
    addInfo(pageProfile, "HWID", hwid, 196)

    local copyHwid = Instance.new("TextButton")
    copyHwid.Size = UDim2.new(1, 0, 0, 34)
    copyHwid.Position = UDim2.new(0, 0, 1, -40)
    copyHwid.BackgroundColor3 = Color3.fromRGB(60, 50, 120)
    copyHwid.Text = "Copy HWID"
    copyHwid.TextColor3 = Color3.fromRGB(255,255,255)
    copyHwid.TextSize = 13
    copyHwid.Font = Enum.Font.GothamSemibold
    copyHwid.Parent = pageProfile
    Instance.new("UICorner", copyHwid).CornerRadius = UDim.new(0, 8)

    copyHwid.MouseButton1Click:Connect(function()
        pcall(function()
            if setclipboard then setclipboard(hwid)
            elseif toclipboard then toclipboard(hwid) end
        end)
        copyHwid.Text = "Copied!"
        safeWait(1.2)
        copyHwid.Text = "Copy HWID"
    end)

    -- ========== STUDIO LITE AUTO CODE ==========
    local studioLabel = Instance.new("TextLabel")
    studioLabel.Size = UDim2.new(1, 0, 0, 18)
    studioLabel.BackgroundTransparency = 1
    studioLabel.Text = "Describe what you want the AI to create"
    studioLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
    studioLabel.TextSize = 12
    studioLabel.Font = Enum.Font.Gotham
    studioLabel.TextXAlignment = Enum.TextXAlignment.Left
    studioLabel.Parent = pageStudio

    local promptBox = Instance.new("TextBox")
    promptBox.Size = UDim2.new(1, 0, 0, 60)
    promptBox.Position = UDim2.new(0, 0, 0, 24)
    promptBox.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
    promptBox.PlaceholderText = "Example: make a speed script with GUI"
    promptBox.PlaceholderColor3 = Color3.fromRGB(90, 90, 110)
    promptBox.TextColor3 = Color3.fromRGB(220, 220, 240)
    promptBox.TextSize = 13
    promptBox.Font = Enum.Font.Gotham
    promptBox.TextXAlignment = Enum.TextXAlignment.Left
    promptBox.TextYAlignment = Enum.TextYAlignment.Top
    promptBox.ClearTextOnFocus = false
    promptBox.MultiLine = true
    promptBox.Text = ""
    promptBox.Parent = pageStudio
    Instance.new("UICorner", promptBox).CornerRadius = UDim.new(0, 8)

    local generateBtn = Instance.new("TextButton")
    generateBtn.Size = UDim2.new(1, 0, 0, 34)
    generateBtn.Position = UDim2.new(0, 0, 0, 94)
    generateBtn.BackgroundColor3 = Color3.fromRGB(70, 55, 160)
    generateBtn.Text = "Generate Code"
    generateBtn.TextColor3 = Color3.fromRGB(255,255,255)
    generateBtn.TextSize = 14
    generateBtn.Font = Enum.Font.GothamBold
    generateBtn.Parent = pageStudio
    Instance.new("UICorner", generateBtn).CornerRadius = UDim.new(0, 8)

    local resultScroll = Instance.new("ScrollingFrame")
    resultScroll.Size = UDim2.new(1, 0, 1, -170)
    resultScroll.Position = UDim2.new(0, 0, 0, 138)
    resultScroll.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    resultScroll.BorderSizePixel = 0
    resultScroll.ScrollBarThickness = 4
    resultScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    resultScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    resultScroll.Parent = pageStudio
    Instance.new("UICorner", resultScroll).CornerRadius = UDim.new(0, 8)

    local resultText = Instance.new("TextLabel")
    resultText.Size = UDim2.new(1, -12, 0, 0)
    resultText.Position = UDim2.new(0, 6, 0, 6)
    resultText.AutomaticSize = Enum.AutomaticSize.Y
    resultText.BackgroundTransparency = 1
    resultText.Text = "Generated code will appear here..."
    resultText.TextColor3 = Color3.fromRGB(200, 200, 220)
    resultText.TextSize = 13
    resultText.Font = Enum.Font.Code
    resultText.TextWrapped = true
    resultText.TextXAlignment = Enum.TextXAlignment.Left
    resultText.TextYAlignment = Enum.TextYAlignment.Top
    resultText.Parent = resultScroll

    local copyCodeBtn = Instance.new("TextButton")
    copyCodeBtn.Size = UDim2.new(1, 0, 0, 32)
    copyCodeBtn.Position = UDim2.new(0, 0, 1, -36)
    copyCodeBtn.BackgroundColor3 = Color3.fromRGB(50, 140, 90)
    copyCodeBtn.Text = "Copy Code"
    copyCodeBtn.TextColor3 = Color3.fromRGB(255,255,255)
    copyCodeBtn.TextSize = 13
    copyCodeBtn.Font = Enum.Font.GothamSemibold
    copyCodeBtn.Parent = pageStudio
    Instance.new("UICorner", copyCodeBtn).CornerRadius = UDim.new(0, 8)

    local lastCode = ""

    generateBtn.MouseButton1Click:Connect(function()
        local prompt = string.match(promptBox.Text, "^%s*(.-)%s*$")
        if prompt == "" then return end

        generateBtn.Text = "Generating..."
        generateBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
        resultText.Text = "Thinking..."

        safeSpawn(function()
            local reply = "Error generating code."

            local ok, res = pcall(function()
                return httpRequest({
                    Url = "https://api.openai.com/v1/chat/completions",
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json",
                        ["Authorization"] = "Bearer " .. CFG.OPENAI_KEY,
                    },
                    Body = HttpService:JSONEncode({
                        model = "gpt-4o-mini",
                        messages = {
                            {role = "system", content = "You are an expert Roblox Lua developer. Generate complete working scripts only. Wrap code in ```lua blocks. Keep it clean and ready to execute."},
                            {role = "user", content = prompt},
                        },
                        max_tokens = 1200,
                    }),
                })
            end)

            if ok and res then
                local data = HttpService:JSONDecode(res.Body or res.body or "{}")
                if data.choices and data.choices[1] then
                    reply = data.choices[1].message.content
                end
            end

            lastCode = reply
            resultText.Text = reply
            generateBtn.Text = "Generate Code"
            generateBtn.BackgroundColor3 = Color3.fromRGB(70, 55, 160)
            addLog("Studio lite generated code for: " .. prompt)
        end)
    end)

    copyCodeBtn.MouseButton1Click:Connect(function()
        if lastCode ~= "" then
            pcall(function()
                if setclipboard then setclipboard(lastCode)
                elseif toclipboard then toclipboard(lastCode) end
            end)
            copyCodeBtn.Text = "Copied!"
            safeWait(1.2)
            copyCodeBtn.Text = "Copy Code"
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════
--  PRIVATE UI (vialua Ai logs) - same as before
-- ═══════════════════════════════════════════════════════════════
local function createPrivateUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "vialua_Ai_logs"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() gui.Parent = CoreGui end)
    if not gui.Parent then gui.Parent = lp:WaitForChild("PlayerGui") end

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 480, 0, 420)
    main.Position = UDim2.new(0.5, -240, 0.5, -210)
    main.BackgroundColor3 = Color3.fromRGB(12, 10, 18)
    main.BorderSizePixel = 0
    main.Parent = gui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(140, 40, 180)
    stroke.Thickness = 2
    stroke.Parent = main

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 15, 45)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = main
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12)

    local titleFix = Instance.new("Frame")
    titleFix.Size = UDim2.new(1, 0, 0.5, 0)
    titleFix.Position = UDim2.new(0, 0, 0.5, 0)
    titleFix.BackgroundColor3 = Color3.fromRGB(30, 15, 45)
    titleFix.BorderSizePixel = 0
    titleFix.Parent = titleBar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -50, 1, 0)
    title.Position = UDim2.new(0, 14, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🔮  vialua Ai logs"
    title.TextColor3 = Color3.fromRGB(220, 160, 255)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -36, 0.5, -14)
    closeBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 70)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = titleBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

    makeDraggable(main, titleBar)
    makeResizable(main)

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -20, 1, -60)
    content.Position = UDim2.new(0, 10, 0, 50)
    content.BackgroundTransparency = 1
    content.Parent = main

    -- Login
    local loginFrame = Instance.new("Frame")
    loginFrame.Size = UDim2.new(1, 0, 1, 0)
    loginFrame.BackgroundTransparency = 1
    loginFrame.Parent = content

    local loginTitle = Instance.new("TextLabel")
    loginTitle.Size = UDim2.new(1, 0, 0, 30)
    loginTitle.BackgroundTransparency = 1
    loginTitle.Text = "Enter Private Key"
    loginTitle.TextColor3 = Color3.fromRGB(220, 180, 255)
    loginTitle.TextSize = 18
    loginTitle.Font = Enum.Font.GothamBold
    loginTitle.Parent = loginFrame

    local keyInput = Instance.new("TextBox")
    keyInput.Size = UDim2.new(1, 0, 0, 40)
    keyInput.Position = UDim2.new(0, 0, 0, 50)
    keyInput.BackgroundColor3 = Color3.fromRGB(25, 18, 35)
    keyInput.PlaceholderText = "VL-XXXX-XXXX-XXXX or Owner Master Key"
    keyInput.PlaceholderColor3 = Color3.fromRGB(120, 100, 140)
    keyInput.TextColor3 = Color3.fromRGB(230, 210, 255)
    keyInput.TextSize = 14
    keyInput.Font = Enum.Font.Gotham
    keyInput.ClearTextOnFocus = false
    keyInput.Text = ""
    keyInput.Parent = loginFrame
    Instance.new("UICorner", keyInput).CornerRadius = UDim.new(0, 8)

    local loginStatus = Instance.new("TextLabel")
    loginStatus.Size = UDim2.new(1, 0, 0, 20)
    loginStatus.Position = UDim2.new(0, 0, 0, 100)
    loginStatus.BackgroundTransparency = 1
    loginStatus.Text = ""
    loginStatus.TextColor3 = Color3.fromRGB(220, 80, 80)
    loginStatus.TextSize = 13
    loginStatus.Font = Enum.Font.Gotham
    loginStatus.Parent = loginFrame

    local loginBtn = Instance.new("TextButton")
    loginBtn.Size = UDim2.new(1, 0, 0, 40)
    loginBtn.Position = UDim2.new(0, 0, 0, 130)
    loginBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 160)
    loginBtn.Text = "Enter"
    loginBtn.TextColor3 = Color3.fromRGB(255,255,255)
    loginBtn.TextSize = 15
    loginBtn.Font = Enum.Font.GothamBold
    loginBtn.Parent = loginFrame
    Instance.new("UICorner", loginBtn).CornerRadius = UDim.new(0, 8)

    -- Panel after login
    local panelFrame = Instance.new("Frame")
    panelFrame.Size = UDim2.new(1, 0, 1, 0)
    panelFrame.BackgroundTransparency = 1
    panelFrame.Visible = false
    panelFrame.Parent = content

    local roleLabel = Instance.new("TextLabel")
    roleLabel.Size = UDim2.new(1, 0, 0, 24)
    roleLabel.BackgroundTransparency = 1
    roleLabel.Text = ""
    roleLabel.TextColor3 = Color3.fromRGB(180, 140, 255)
    roleLabel.TextSize = 14
    roleLabel.Font = Enum.Font.GothamBold
    roleLabel.Parent = panelFrame

    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, 0, 0, 32)
    tabBar.Position = UDim2.new(0, 0, 0, 30)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = panelFrame

    local function createTab(name, pos)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.32, -4, 1, 0)
        b.Position = UDim2.new(pos, 0, 0, 0)
        b.BackgroundColor3 = Color3.fromRGB(40, 25, 60)
        b.Text = name
        b.TextColor3 = Color3.fromRGB(200, 170, 255)
        b.TextSize = 12
        b.Font = Enum.Font.GothamSemibold
        b.Parent = tabBar
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        return b
    end

    local tabAdmin = createTab("ADMINISTRATOR", 0)
    local tabChat  = createTab("Admin message", 0.34)
    local tabLogs  = createTab("Logs", 0.68)

    local pages = {}
    local function createPage()
        local p = Instance.new("Frame")
        p.Size = UDim2.new(1, 0, 1, -70)
        p.Position = UDim2.new(0, 0, 0, 70)
        p.BackgroundTransparency = 1
        p.Visible = false
        p.Parent = panelFrame
        return p
    end

    pages.admin = createPage()
    pages.chat  = createPage()
    pages.logs  = createPage()

    local function showPage(name)
        for k, v in pairs(pages) do v.Visible = (k == name) end
        tabAdmin.BackgroundColor3 = name == "admin" and Color3.fromRGB(100, 40, 150) or Color3.fromRGB(40, 25, 60)
        tabChat.BackgroundColor3  = name == "chat"  and Color3.fromRGB(100, 40, 150) or Color3.fromRGB(40, 25, 60)
        tabLogs.BackgroundColor3  = name == "logs"  and Color3.fromRGB(100, 40, 150) or Color3.fromRGB(40, 25, 60)
    end

    tabAdmin.MouseButton1Click:Connect(function() showPage("admin") end)
    tabChat.MouseButton1Click:Connect(function() showPage("chat") end)
    tabLogs.MouseButton1Click:Connect(function() showPage("logs") end)

    -- Admin page content (generate keys)
    local adminInfo = Instance.new("TextLabel")
    adminInfo.Size = UDim2.new(1, 0, 0, 40)
    adminInfo.BackgroundTransparency = 1
    adminInfo.Text = "Owner Panel — Generate keys (max 10 users)"
    adminInfo.TextColor3 = Color3.fromRGB(200, 180, 255)
    adminInfo.TextSize = 13
    adminInfo.Font = Enum.Font.Gotham
    adminInfo.TextWrapped = true
    adminInfo.Parent = pages.admin

    local genBtn = Instance.new("TextButton")
    genBtn.Size = UDim2.new(1, 0, 0, 36)
    genBtn.Position = UDim2.new(0, 0, 0, 50)
    genBtn.BackgroundColor3 = Color3.fromRGB(100, 40, 160)
    genBtn.Text = "Generate New User Key"
    genBtn.TextColor3 = Color3.fromRGB(255,255,255)
    genBtn.TextSize = 14
    genBtn.Font = Enum.Font.GothamBold
    genBtn.Parent = pages.admin
    Instance.new("UICorner", genBtn).CornerRadius = UDim.new(0, 8)

    local keysList = Instance.new("ScrollingFrame")
    keysList.Size = UDim2.new(1, 0, 1, -100)
    keysList.Position = UDim2.new(0, 0, 0, 100)
    keysList.BackgroundColor3 = Color3.fromRGB(20, 14, 30)
    keysList.BorderSizePixel = 0
    keysList.ScrollBarThickness = 4
    keysList.CanvasSize = UDim2.new(0, 0, 0, 0)
    keysList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    keysList.Parent = pages.admin
    Instance.new("UICorner", keysList).CornerRadius = UDim.new(0, 8)

    local keysLayout = Instance.new("UIListLayout")
    keysLayout.Padding = UDim.new(0, 4)
    keysLayout.Parent = keysList

    local function refreshKeysList()
        for _, c in ipairs(keysList:GetChildren()) do
            if c:IsA("TextLabel") then c:Destroy() end
        end
        local keys = getPrivateKeys()
        local countLabel = Instance.new("TextLabel")
        countLabel.Size = UDim2.new(1, -10, 0, 22)
        countLabel.BackgroundTransparency = 1
        countLabel.Text = "Active keys: " .. #keys .. " / " .. CFG.MAX_PRIVATE_USERS
        countLabel.TextColor3 = Color3.fromRGB(160, 200, 255)
        countLabel.TextSize = 13
        countLabel.Font = Enum.Font.GothamBold
        countLabel.Parent = keysList

        for i, k in ipairs(keys) do
            local row = Instance.new("TextLabel")
            row.Size = UDim2.new(1, -10, 0, 22)
            row.BackgroundTransparency = 1
            row.Text = i .. ". " .. k
            row.TextColor3 = Color3.fromRGB(200, 180, 255)
            row.TextSize = 12
            row.Font = Enum.Font.Code
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.Parent = keysList
        end
    end

    genBtn.MouseButton1Click:Connect(function()
        local keys = getPrivateKeys()
        if #keys >= CFG.MAX_PRIVATE_USERS then
            genBtn.Text = "Max 10 users reached!"
            safeWait(1.5)
            genBtn.Text = "Generate New User Key"
            return
        end
        local newKey = generatePrivateKey()
        table.insert(keys, newKey)
        savePrivateKeys(keys)
        refreshKeysList()
        genBtn.Text = "Generated: " .. newKey
        if setclipboard then pcall(setclipboard, newKey) end
        safeWait(2)
        genBtn.Text = "Generate New User Key"
        addLog("Owner generated new key: " .. newKey)
    end)

    -- Chat page
    local chatScroll = Instance.new("ScrollingFrame")
    chatScroll.Size = UDim2.new(1, 0, 1, -50)
    chatScroll.BackgroundColor3 = Color3.fromRGB(20, 14, 30)
    chatScroll.BorderSizePixel = 0
    chatScroll.ScrollBarThickness = 4
    chatScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    chatScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    chatScroll.Parent = pages.chat
    Instance.new("UICorner", chatScroll).CornerRadius = UDim.new(0, 8)

    local chatLayout = Instance.new("UIListLayout")
    chatLayout.Padding = UDim.new(0, 3)
    chatLayout.Parent = chatScroll

    local function refreshChat()
        for _, c in ipairs(chatScroll:GetChildren()) do
            if c:IsA("TextLabel") then c:Destroy() end
        end
        local raw = getAdminChat()
        for line in string.gmatch(raw .. "\n", "([^\r\n]*)\r?\n") do
            if line ~= "" then
                local l = Instance.new("TextLabel")
                l.Size = UDim2.new(1, -8, 0, 0)
                l.AutomaticSize = Enum.AutomaticSize.Y
                l.BackgroundTransparency = 1
                l.Text = line
                l.TextColor3 = Color3.fromRGB(200, 180, 255)
                l.TextSize = 12
                l.Font = Enum.Font.Code
                l.TextWrapped = true
                l.TextXAlignment = Enum.TextXAlignment.Left
                l.Parent = chatScroll
            end
        end
    end

    local chatInput = Instance.new("TextBox")
    chatInput.Size = UDim2.new(1, -70, 0, 36)
    chatInput.Position = UDim2.new(0, 0, 1, -40)
    chatInput.BackgroundColor3 = Color3.fromRGB(30, 20, 45)
    chatInput.PlaceholderText = "Type message..."
    chatInput.PlaceholderColor3 = Color3.fromRGB(120, 100, 140)
    chatInput.TextColor3 = Color3.fromRGB(230, 210, 255)
    chatInput.TextSize = 13
    chatInput.Font = Enum.Font.Gotham
    chatInput.ClearTextOnFocus = false
    chatInput.Text = ""
    chatInput.Parent = pages.chat
    Instance.new("UICorner", chatInput).CornerRadius = UDim.new(0, 6)

    local chatSend = Instance.new("TextButton")
    chatSend.Size = UDim2.new(0, 60, 0, 36)
    chatSend.Position = UDim2.new(1, -60, 1, -40)
    chatSend.BackgroundColor3 = Color3.fromRGB(120, 40, 160)
    chatSend.Text = "Send"
    chatSend.TextColor3 = Color3.fromRGB(255,255,255)
    chatSend.TextSize = 13
    chatSend.Font = Enum.Font.GothamBold
    chatSend.Parent = pages.chat
    Instance.new("UICorner", chatSend).CornerRadius = UDim.new(0, 6)

    chatSend.MouseButton1Click:Connect(function()
        local msg = string.match(chatInput.Text, "^%s*(.-)%s*$")
        if msg ~= "" then
            addAdminMessage("OWNER", msg)
            chatInput.Text = ""
            refreshChat()
        end
    end)

    -- Logs page
    local logsScroll = Instance.new("ScrollingFrame")
    logsScroll.Size = UDim2.new(1, 0, 1, -90)
    logsScroll.BackgroundColor3 = Color3.fromRGB(20, 14, 30)
    logsScroll.BorderSizePixel = 0
    logsScroll.ScrollBarThickness = 4
    logsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    logsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    logsScroll.Parent = pages.logs
    Instance.new("UICorner", logsScroll).CornerRadius = UDim.new(0, 8)

    local logsLayout = Instance.new("UIListLayout")
    logsLayout.Padding = UDim.new(0, 3)
    logsLayout.Parent = logsScroll

    local function refreshLogs()
        for _, c in ipairs(logsScroll:GetChildren()) do
            if c:IsA("TextLabel") then c:Destroy() end
        end
        local raw = getLogs() .. "\n" .. getOrders()
        for line in string.gmatch(raw .. "\n", "([^\r\n]*)\r?\n") do
            if line ~= "" then
                local l = Instance.new("TextLabel")
                l.Size = UDim2.new(1, -8, 0, 0)
                l.AutomaticSize = Enum.AutomaticSize.Y
                l.BackgroundTransparency = 1
                l.Text = line
                l.TextColor3 = Color3.fromRGB(180, 200, 255)
                l.TextSize = 12
                l.Font = Enum.Font.Code
                l.TextWrapped = true
                l.TextXAlignment = Enum.TextXAlignment.Left
                l.Parent = logsScroll
            end
        end
    end

    local orderInput = Instance.new("TextBox")
    orderInput.Size = UDim2.new(1, -80, 0, 36)
    orderInput.Position = UDim2.new(0, 0, 1, -40)
    orderInput.BackgroundColor3 = Color3.fromRGB(30, 20, 45)
    orderInput.PlaceholderText = "Give custom order to users..."
    orderInput.PlaceholderColor3 = Color3.fromRGB(120, 100, 140)
    orderInput.TextColor3 = Color3.fromRGB(230, 210, 255)
    orderInput.TextSize = 13
    orderInput.Font = Enum.Font.Gotham
    orderInput.ClearTextOnFocus = false
    orderInput.Text = ""
    orderInput.Parent = pages.logs
    Instance.new("UICorner", orderInput).CornerRadius = UDim.new(0, 6)

    local orderBtn = Instance.new("TextButton")
    orderBtn.Size = UDim2.new(0, 70, 0, 36)
    orderBtn.Position = UDim2.new(1, -70, 1, -40)
    orderBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 80)
    orderBtn.Text = "Order"
    orderBtn.TextColor3 = Color3.fromRGB(255,255,255)
    orderBtn.TextSize = 13
    orderBtn.Font = Enum.Font.GothamBold
    orderBtn.Parent = pages.logs
    Instance.new("UICorner", orderBtn).CornerRadius = UDim.new(0, 6)

    orderBtn.MouseButton1Click:Connect(function()
        local msg = string.match(orderInput.Text, "^%s*(.-)%s*$")
        if msg ~= "" then
            addOrder(msg)
            orderInput.Text = ""
            refreshLogs()
        end
    end)

    -- Login logic
    local function doLogin()
        local key = string.match(keyInput.Text, "^%s*(.-)%s*$")
        local valid, role = isValidPrivateKey(key)
        if not valid then
            loginStatus.Text = "Invalid key"
            return
        end

        loginFrame.Visible = false
        panelFrame.Visible = true

        if role == "OWNER" then
            roleLabel.Text = "Role: OWNER"
            tabAdmin.Visible = true
            showPage("admin")
            refreshKeysList()
            refreshChat()
            refreshLogs()
            addLog("Owner logged into vialua Ai logs")
        else
            roleLabel.Text = "Role: USER"
            tabAdmin.Visible = false
            showPage("chat")
            refreshChat()
            refreshLogs()
            addLog("User logged in with key")
        end
    end

    loginBtn.MouseButton1Click:Connect(doLogin)
    keyInput.FocusLost:Connect(function(enter) if enter then doLogin() end end)
end

-- ═══════════════════════════════════════════════════════════════
--  START
-- ═══════════════════════════════════════════════════════════════
showLoadingScreen(function()
    createPrivateUI()          -- Private (needs custom key)
    createKeySystem(function() -- Normal (needs normal key)
        createPublicUI()
    end)
end)
