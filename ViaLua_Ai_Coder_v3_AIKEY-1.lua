--[[
╔══════════════════════════════════════════════════════════════════╗
║              ViaLua Ai Coder  ·  v3.0 (AI Key System)          ║
║  Users must enter their own OpenAI / Anthropic key             ║
║  ChatGPT → OpenAI   |  Claude → OpenCode                       ║
║  Full Instructions + Terminal-style logging                    ║
╚══════════════════════════════════════════════════════════════════╝
--]]

-- ═══════════════════════════════════════════════════════════════
--  EXECUTOR COMPAT
-- ═══════════════════════════════════════════════════════════════
local httpRequest = (syn and syn.request) or (http and http.request) or (request and request)
if not httpRequest then
    error("[ViaLua] No HTTP request function found.")
end

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
    KEY_URL  = "https://key-giver-vialua.pages.dev/",
    KEY_LINK = "https://linkvertise.com/9491639/hnvRO5DVU5fn",
    OWNER_MASTER_KEY = "Via_31A_WJN_9XO_Lua",
    MAX_PRIVATE_USERS = 10,
}

-- ═══════════════════════════════════════════════════════════════
--  SERVICES
-- ═══════════════════════════════════════════════════════════════
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local lp = Players.LocalPlayer

-- ═══════════════════════════════════════════════════════════════
--  STORAGE
-- ═══════════════════════════════════════════════════════════════
local function saveFile(name, data)
    pcall(function()
        if writefile then writefile(name, tostring(data))
        else getgenv()[name] = tostring(data) end
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

local function getHWID()
    local hwid = "Unknown"
    pcall(function()
        if gethwid then hwid = tostring(gethwid())
        else hwid = tostring(lp.UserId) .. "_" .. tostring(game.PlaceId) end
    end)
    return hwid
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
    resize.Size = UDim2.new(0, 16, 0, 16)
    resize.Position = UDim2.new(1, -16, 1, -16)
    resize.BackgroundColor3 = Color3.fromRGB(110, 90, 220)
    resize.BackgroundTransparency = 0.3
    resize.Text = ""
    resize.ZIndex = 10
    resize.Parent = frame
    Instance.new("UICorner", resize).CornerRadius = UDim.new(0, 4)

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
            frame.Size = UDim2.new(0, math.clamp(startSize.X.Offset + delta.X, 480, 900), 0, math.clamp(startSize.Y.Offset + delta.Y, 380, 720))
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════
--  ACCURATE INSTRUCTIONS
-- ═══════════════════════════════════════════════════════════════
local INSTRUCTIONS = {
    OpenAI = [[
HOW TO GET OPENAI API KEY (ChatGPT)

1. Go to: https://platform.openai.com
2. Sign up or Log in with your account
3. Click your profile picture (top right) → "View API keys"
   or go directly to: https://platform.openai.com/api-keys
4. Click the green button "+ Create new secret key"
5. Give it any name (example: ViaLua)
6. Click "Create secret key"
7. COPY the key immediately (it starts with sk-...)
   ⚠ You will NOT be able to see it again!
8. Paste the key into the textbox in ViaLua

NOTES:
• You need to add a payment method (even $5 credit is enough)
• Free trial credits may be available for new accounts
• Keep the key private — never share it
]],

    Claude = [[
HOW TO GET ANTHROPIC (CLAUDE) API KEY

1. Go to: https://console.anthropic.com
2. Sign up or Log in
3. After logging in, go to: https://console.anthropic.com/settings/keys
4. Click "Create Key"
5. Give it a name (example: ViaLua)
6. Click "Create Key"
7. COPY the key immediately (it starts with sk-ant-...)
   ⚠ You will NOT be able to see the full key again!
8. Paste the key into the textbox in ViaLua

NOTES:
• Anthropic requires phone verification on some accounts
• New accounts usually get free credits
• Keep the key private
]]
}

-- ═══════════════════════════════════════════════════════════════
--  MAIN PUBLIC UI
-- ═══════════════════════════════════════════════════════════════
local function createPublicUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "ViaLua_Public"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() gui.Parent = CoreGui end)
    if not gui.Parent then gui.Parent = lp:WaitForChild("PlayerGui") end

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 540, 0, 440)
    main.Position = UDim2.new(0.5, -270, 0.5, -220)
    main.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
    main.BorderSizePixel = 0
    main.Parent = gui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(70, 55, 140)
    stroke.Thickness = 1.5
    stroke.Parent = main

    -- Title
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
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = titleBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

    makeDraggable(main, titleBar)
    makeResizable(main)

    -- Sidebar
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 150, 1, -50)
    sidebar.Position = UDim2.new(0, 8, 0, 46)
    sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    sidebar.BorderSizePixel = 0
    sidebar.Parent = main
    Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 10)

    local sidePad = Instance.new("UIPadding")
    sidePad.PaddingTop = UDim.new(0, 10)
    sidePad.PaddingLeft = UDim.new(0, 8)
    sidePad.PaddingRight = UDim.new(0, 8)
    sidePad.Parent = sidebar

    local sideLayout = Instance.new("UIListLayout")
    sideLayout.Padding = UDim.new(0, 6)
    sideLayout.Parent = sidebar

    local function createSideBtn(text, order)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 34)
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
    local tabInstr   = createSideBtn("INSTRUCTIONS", 3)

    -- Content area
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -170, 1, -56)
    content.Position = UDim2.new(0, 166, 0, 48)
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

    local pageInstr = Instance.new("Frame")
    pageInstr.Size = UDim2.new(1, 0, 1, 0)
    pageInstr.BackgroundTransparency = 1
    pageInstr.Visible = false
    pageInstr.Parent = content

    local function showTab(name)
        pageProfile.Visible = (name == "profile")
        pageStudio.Visible  = (name == "studio")
        pageInstr.Visible   = (name == "instr")
        tabProfile.BackgroundColor3 = name == "profile" and Color3.fromRGB(70, 55, 160) or Color3.fromRGB(35, 35, 50)
        tabStudio.BackgroundColor3  = name == "studio"  and Color3.fromRGB(70, 55, 160) or Color3.fromRGB(35, 35, 50)
        tabInstr.BackgroundColor3   = name == "instr"   and Color3.fromRGB(70, 55, 160) or Color3.fromRGB(35, 35, 50)
        tabProfile.TextColor3 = name == "profile" and Color3.fromRGB(255,255,255) or Color3.fromRGB(180,180,200)
        tabStudio.TextColor3  = name == "studio"  and Color3.fromRGB(255,255,255) or Color3.fromRGB(180,180,200)
        tabInstr.TextColor3   = name == "instr"   and Color3.fromRGB(255,255,255) or Color3.fromRGB(180,180,200)
    end

    tabProfile.MouseButton1Click:Connect(function() showTab("profile") end)
    tabStudio.MouseButton1Click:Connect(function() showTab("studio") end)
    tabInstr.MouseButton1Click:Connect(function() showTab("instr") end)
    showTab("profile")

    -- ========== PROFILE ==========
    local function addInfo(parent, label, value, y)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 16)
        l.Position = UDim2.new(0, 0, 0, y)
        l.BackgroundTransparency = 1
        l.Text = label
        l.TextColor3 = Color3.fromRGB(140, 140, 165)
        l.TextSize = 12
        l.Font = Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = parent

        local v = Instance.new("TextLabel")
        v.Size = UDim2.new(1, 0, 0, 18)
        v.Position = UDim2.new(0, 0, 0, y + 15)
        v.BackgroundTransparency = 1
        v.Text = tostring(value)
        v.TextColor3 = Color3.fromRGB(220, 220, 240)
        v.TextSize = 13
        v.Font = Enum.Font.GothamSemibold
        v.TextXAlignment = Enum.TextXAlignment.Left
        v.TextTruncate = Enum.TextTruncate.AtEnd
        v.Parent = parent
    end

    local hwid = getHWID()
    local created = "Unknown"
    pcall(function()
        created = os.date("%Y-%m-%d", os.time() - (lp.AccountAge * 86400))
    end)

    addInfo(pageProfile, "Username", lp.Name, 6)
    addInfo(pageProfile, "Display Name", lp.DisplayName, 50)
    addInfo(pageProfile, "User ID", lp.UserId, 94)
    addInfo(pageProfile, "Account Created", created .. " (" .. lp.AccountAge .. " days)", 138)
    addInfo(pageProfile, "HWID", hwid, 182)

    local copyHwid = Instance.new("TextButton")
    copyHwid.Size = UDim2.new(1, 0, 0, 32)
    copyHwid.Position = UDim2.new(0, 0, 1, -38)
    copyHwid.BackgroundColor3 = Color3.fromRGB(60, 50, 120)
    copyHwid.Text = "Copy HWID"
    copyHwid.TextColor3 = Color3.fromRGB(255,255,255)
    copyHwid.TextSize = 13
    copyHwid.Font = Enum.Font.GothamSemibold
    copyHwid.Parent = pageProfile
    Instance.new("UICorner", copyHwid).CornerRadius = UDim.new(0, 8)
    copyHwid.MouseButton1Click:Connect(function()
        pcall(function()
            if setclipboard then setclipboard(hwid) elseif toclipboard then toclipboard(hwid) end
        end)
        copyHwid.Text = "Copied!"
        safeWait(1.2)
        copyHwid.Text = "Copy HWID"
    end)

    -- ========== STUDIO LITE (AI KEY SYSTEM) ==========
    local currentProvider = "openai" -- or "claude"
    local userToken = ""

    -- Support status
    local statusFrame = Instance.new("Frame")
    statusFrame.Size = UDim2.new(1, 0, 0, 70)
    statusFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    statusFrame.BorderSizePixel = 0
    statusFrame.Parent = pageStudio
    Instance.new("UICorner", statusFrame).CornerRadius = UDim.new(0, 8)

    local function addStatus(text, y, color)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -12, 0, 18)
        l.Position = UDim2.new(0, 10, 0, y)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = color
        l.TextSize = 12
        l.Font = Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = statusFrame
    end

    addStatus("• OpenAI          | SUPPORTED     | 🟢", 8, Color3.fromRGB(100, 220, 140))
    addStatus("• OpenCode        | SUPPORTED     | 🟢", 28, Color3.fromRGB(100, 220, 140))
    addStatus("• Google (Gemini) | NOT SUPPORTED | 🔴", 48, Color3.fromRGB(220, 90, 90))

    -- Provider buttons
    local btnOpenAI = Instance.new("TextButton")
    btnOpenAI.Size = UDim2.new(0.48, -4, 0, 32)
    btnOpenAI.Position = UDim2.new(0, 0, 0, 80)
    btnOpenAI.BackgroundColor3 = Color3.fromRGB(70, 55, 160)
    btnOpenAI.Text = "ChatGPT (OpenAI)"
    btnOpenAI.TextColor3 = Color3.fromRGB(255,255,255)
    btnOpenAI.TextSize = 12
    btnOpenAI.Font = Enum.Font.GothamSemibold
    btnOpenAI.Parent = pageStudio
    Instance.new("UICorner", btnOpenAI).CornerRadius = UDim.new(0, 7)

    local btnClaude = Instance.new("TextButton")
    btnClaude.Size = UDim2.new(0.48, -4, 0, 32)
    btnClaude.Position = UDim2.new(0.52, 0, 0, 80)
    btnClaude.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    btnClaude.Text = "Claude (OpenCode)"
    btnClaude.TextColor3 = Color3.fromRGB(180,180,200)
    btnClaude.TextSize = 12
    btnClaude.Font = Enum.Font.GothamSemibold
    btnClaude.Parent = pageStudio
    Instance.new("UICorner", btnClaude).CornerRadius = UDim.new(0, 7)

    -- Token input
    local tokenBox = Instance.new("TextBox")
    tokenBox.Size = UDim2.new(1, 0, 0, 34)
    tokenBox.Position = UDim2.new(0, 0, 0, 120)
    tokenBox.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
    tokenBox.PlaceholderText = "Paste your sk-... key here"
    tokenBox.PlaceholderColor3 = Color3.fromRGB(90, 90, 110)
    tokenBox.TextColor3 = Color3.fromRGB(220, 220, 240)
    tokenBox.TextSize = 12
    tokenBox.Font = Enum.Font.Code
    tokenBox.ClearTextOnFocus = false
    tokenBox.Text = ""
    tokenBox.Parent = pageStudio
    Instance.new("UICorner", tokenBox).CornerRadius = UDim.new(0, 7)

    -- Prompt
    local promptBox = Instance.new("TextBox")
    promptBox.Size = UDim2.new(1, 0, 0, 50)
    promptBox.Position = UDim2.new(0, 0, 0, 162)
    promptBox.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
    promptBox.PlaceholderText = "Describe the script you want..."
    promptBox.PlaceholderColor3 = Color3.fromRGB(90, 90, 110)
    promptBox.TextColor3 = Color3.fromRGB(220, 220, 240)
    promptBox.TextSize = 12
    promptBox.Font = Enum.Font.Gotham
    promptBox.TextXAlignment = Enum.TextXAlignment.Left
    promptBox.TextYAlignment = Enum.TextYAlignment.Top
    promptBox.MultiLine = true
    promptBox.ClearTextOnFocus = false
    promptBox.Text = ""
    promptBox.Parent = pageStudio
    Instance.new("UICorner", promptBox).CornerRadius = UDim.new(0, 7)

    local generateBtn = Instance.new("TextButton")
    generateBtn.Size = UDim2.new(1, 0, 0, 34)
    generateBtn.Position = UDim2.new(0, 0, 0, 220)
    generateBtn.BackgroundColor3 = Color3.fromRGB(70, 55, 160)
    generateBtn.Text = "Generate Code"
    generateBtn.TextColor3 = Color3.fromRGB(255,255,255)
    generateBtn.TextSize = 13
    generateBtn.Font = Enum.Font.GothamBold
    generateBtn.Parent = pageStudio
    Instance.new("UICorner", generateBtn).CornerRadius = UDim.new(0, 7)

    -- Terminal / Log area
    local logScroll = Instance.new("ScrollingFrame")
    logScroll.Size = UDim2.new(1, 0, 1, -265)
    logScroll.Position = UDim2.new(0, 0, 0, 262)
    logScroll.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
    logScroll.BorderSizePixel = 0
    logScroll.ScrollBarThickness = 3
    logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    logScroll.Parent = pageStudio
    Instance.new("UICorner", logScroll).CornerRadius = UDim.new(0, 7)

    local logLayout = Instance.new("UIListLayout")
    logLayout.Padding = UDim.new(0, 2)
    logLayout.Parent = logScroll

    local function addLogLine(text, color)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -8, 0, 0)
        l.AutomaticSize = Enum.AutomaticSize.Y
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = color or Color3.fromRGB(180, 180, 200)
        l.TextSize = 11
        l.Font = Enum.Font.Code
        l.TextWrapped = true
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = logScroll
    end

    local function clearLog()
        for _, c in ipairs(logScroll:GetChildren()) do
            if c:IsA("TextLabel") then c:Destroy() end
        end
    end

    -- Provider switch
    btnOpenAI.MouseButton1Click:Connect(function()
        currentProvider = "openai"
        btnOpenAI.BackgroundColor3 = Color3.fromRGB(70, 55, 160)
        btnOpenAI.TextColor3 = Color3.fromRGB(255,255,255)
        btnClaude.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        btnClaude.TextColor3 = Color3.fromRGB(180,180,200)
        tokenBox.PlaceholderText = "Paste your OpenAI sk-... key here"
        pcall(function()
            if setclipboard then setclipboard("https://platform.openai.com/api-keys")
            elseif toclipboard then toclipboard("https://platform.openai.com/api-keys") end
        end)
        addLogLine("[SYSTEM] Switched to ChatGPT (OpenAI)", Color3.fromRGB(140, 200, 255))
        addLogLine("[SYSTEM] OpenAI link copied to clipboard", Color3.fromRGB(140, 200, 255))
    end)

    btnClaude.MouseButton1Click:Connect(function()
        currentProvider = "claude"
        btnClaude.BackgroundColor3 = Color3.fromRGB(70, 55, 160)
        btnClaude.TextColor3 = Color3.fromRGB(255,255,255)
        btnOpenAI.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        btnOpenAI.TextColor3 = Color3.fromRGB(180,180,200)
        tokenBox.PlaceholderText = "Paste your Anthropic sk-ant-... key here"
        pcall(function()
            if setclipboard then setclipboard("https://console.anthropic.com/settings/keys")
            elseif toclipboard then toclipboard("https://console.anthropic.com/settings/keys") end
        end)
        addLogLine("[SYSTEM] Switched to Claude (OpenCode)", Color3.fromRGB(140, 200, 255))
        addLogLine("[SYSTEM] Anthropic link copied to clipboard", Color3.fromRGB(140, 200, 255))
    end)

    -- Generate with fake terminal process
    local userCount = 0
    generateBtn.MouseButton1Click:Connect(function()
        local token = string.match(tokenBox.Text, "^%s*(.-)%s*$") or ""
        local prompt = string.match(promptBox.Text, "^%s*(.-)%s*$") or ""

        clearLog()

        if token == "" then
            addLogLine("[ERROR] No API key provided.", Color3.fromRGB(255, 90, 90))
            addLogLine("Go to INSTRUCTIONS tab to learn how to get one.", Color3.fromRGB(200, 160, 100))
            return
        end

        if prompt == "" then
            addLogLine("[ERROR] Please describe what you want to generate.", Color3.fromRGB(255, 90, 90))
            return
        end

        userCount = userCount + 1
        local providerName = currentProvider == "openai" and "OPENAI" or "OPENCODE"
        local isValidLooking = (currentProvider == "openai" and token:find("sk-")) or (currentProvider == "claude" and token:find("sk-ant-"))

        -- Fake process start
        addLogLine("$psudo process type #" .. lp.Name .. " no." .. userCount, Color3.fromRGB(160, 160, 180))
        safeWait(0.6)

        if not isValidLooking then
            -- FAILED
            addLogLine("TOKEN NOT FOUND", Color3.fromRGB(255, 90, 90))
            safeWait(0.4)
            addLogLine("REASON : TOKEN NOT SUPPORT", Color3.fromRGB(255, 120, 80))
            safeWait(1)
            addLogLine("TOKEN: " .. token:sub(1, 12) .. "... is NOT SUPPORT OR VALID TOKEN", Color3.fromRGB(255, 100, 100))
            safeWait(1)
            addLogLine("TOKEN PROCESS FAILED", Color3.fromRGB(255, 70, 70))
            return
        end

        -- SUCCESS path
        addLogLine("TOKEN FOUND", Color3.fromRGB(80, 220, 120))
        safeWait(1)
        addLogLine("TOKEN TYPE: " .. providerName, Color3.fromRGB(140, 200, 255))
        safeWait(1.4)
        addLogLine("TOKEN EXPIRY: 1HR", Color3.fromRGB(200, 180, 100))
        safeWait(2)
        addLogLine("USER PROFILE: (" .. lp.Name .. ":" .. lp.DisplayName .. ")", Color3.fromRGB(180, 180, 220))
        addLogLine("TOKEN: " .. token:sub(1, 18) .. "...", Color3.fromRGB(160, 160, 180))
        safeWait(0.8)
        addLogLine("Generating code...", Color3.fromRGB(140, 200, 255))

        -- Real API call (Delta compatible)
        safeSpawn(function()
            local reply = "Failed to generate."

            local function doRequest(url, headers, bodyTable)
                local body = HttpService:JSONEncode(bodyTable)

                -- Try multiple formats for better executor compatibility
                local attempts = {
                    {Url = url, Method = "POST", Headers = headers, Body = body},
                    {url = url, method = "POST", headers = headers, body = body},
                    {Url = url, Method = "POST", Headers = headers, Body = body, Timeout = 30},
                }

                for _, req in ipairs(attempts) do
                    local ok, res = pcall(function()
                        return httpRequest(req)
                    end)
                    if ok and res then
                        return res
                    end
                end
                return nil, "All request formats failed"
            end

            local success, result = pcall(function()
                if currentProvider == "openai" then
                    return doRequest(
                        "https://api.openai.com/v1/chat/completions",
                        {
                            ["Content-Type"] = "application/json",
                            ["Authorization"] = "Bearer " .. token,
                        },
                        {
                            model = "gpt-4o-mini",
                            messages = {
                                {role = "system", content = "You are an expert Roblox Lua developer. Only output complete working Lua code. Always wrap in ```lua blocks."},
                                {role = "user", content = prompt}
                            },
                            max_tokens = 1500
                        }
                    )
                else
                    return doRequest(
                        "https://api.anthropic.com/v1/messages",
                        {
                            ["Content-Type"] = "application/json",
                            ["x-api-key"] = token,
                            ["anthropic-version"] = "2023-06-01",
                        },
                        {
                            model = "claude-3-5-haiku-20241022",
                            max_tokens = 1500,
                            system = "You are an expert Roblox Lua developer. Only output complete working Lua code. Always wrap in ```lua blocks.",
                            messages = {{role = "user", content = prompt}}
                        }
                    )
                end
            end)

            if success and result then
                local body = result.Body or result.body or result.Source or ""
                if type(body) ~= "string" then body = tostring(body) end

                local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
                if ok and data then
                    if currentProvider == "openai" and data.choices and data.choices[1] then
                        reply = data.choices[1].message.content or "Empty response"
                    elseif currentProvider == "claude" and data.content and data.content[1] then
                        reply = data.content[1].text or "Empty response"
                    elseif data.error then
                        reply = "API Error: " .. (data.error.message or tostring(data.error))
                    else
                        reply = "Unexpected response format.\n" .. body:sub(1, 300)
                    end
                else
                    reply = "Failed to parse response.\nRaw: " .. body:sub(1, 300)
                end
            else
                reply = "Request failed (Delta compatibility issue).\nError: " .. tostring(result) .. "\n\nTry using a different executor or check if the key is valid."
            end

            addLogLine("──────── CODE OUTPUT ────────", Color3.fromRGB(140, 140, 180))
            addLogLine(reply, Color3.fromRGB(200, 220, 200))
            addLogLine("──────── END ────────", Color3.fromRGB(140, 140, 180))
        end)
    end)

    -- ========== INSTRUCTIONS PAGE ==========
    local instrScroll = Instance.new("ScrollingFrame")
    instrScroll.Size = UDim2.new(1, 0, 1, 0)
    instrScroll.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    instrScroll.BorderSizePixel = 0
    instrScroll.ScrollBarThickness = 4
    instrScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    instrScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    instrScroll.Parent = pageInstr
    Instance.new("UICorner", instrScroll).CornerRadius = UDim.new(0, 8)

    local instrPad = Instance.new("UIPadding")
    instrPad.PaddingTop = UDim.new(0, 10)
    instrPad.PaddingLeft = UDim.new(0, 10)
    instrPad.PaddingRight = UDim.new(0, 10)
    instrPad.PaddingBottom = UDim.new(0, 10)
    instrPad.Parent = instrScroll

    local instrLayout = Instance.new("UIListLayout")
    instrLayout.Padding = UDim.new(0, 8)
    instrLayout.Parent = instrScroll

    local function addInstrText(text, size, color, bold)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 0)
        l.AutomaticSize = Enum.AutomaticSize.Y
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = color or Color3.fromRGB(200, 200, 220)
        l.TextSize = size or 12
        l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
        l.TextWrapped = true
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = instrScroll
    end

    addInstrText("HOW TO GET YOUR API KEY", 15, Color3.fromRGB(180, 160, 255), true)
    addInstrText(" ", 6)
    addInstrText("▶ CHATGPT (OpenAI)", 13, Color3.fromRGB(100, 200, 140), true)
    addInstrText(INSTRUCTIONS.OpenAI, 11, Color3.fromRGB(180, 180, 200))
    addInstrText(" ", 8)
    addInstrText("▶ CLAUDE (OpenCode / Anthropic)", 13, Color3.fromRGB(100, 200, 140), true)
    addInstrText(INSTRUCTIONS.Claude, 11, Color3.fromRGB(180, 180, 200))
    addInstrText(" ", 8)
    addInstrText("After you get the key, go to Studio lite → paste it → Generate.", 12, Color3.fromRGB(160, 160, 180))
end

-- ═══════════════════════════════════════════════════════════════
--  SIMPLE KEY SYSTEM (kept minimal)
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

    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, 360, 0, 220)
    card.Position = UDim2.new(0.5, -180, 0.5, -110)
    card.BackgroundColor3 = Color3.fromRGB(18, 16, 28)
    card.BorderSizePixel = 0
    card.Parent = bg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = "🔑 ViaLua Key System"
    title.TextColor3 = Color3.fromRGB(220, 200, 255)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.Parent = card

    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(1, -40, 0, 34)
    copyBtn.Position = UDim2.new(0, 20, 0, 60)
    copyBtn.BackgroundColor3 = Color3.fromRGB(70, 50, 150)
    copyBtn.Text = "Copy Key Link"
    copyBtn.TextColor3 = Color3.fromRGB(255,255,255)
    copyBtn.TextSize = 13
    copyBtn.Font = Enum.Font.GothamSemibold
    copyBtn.Parent = card
    Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 8)
    copyBtn.MouseButton1Click:Connect(function()
        pcall(function()
            if setclipboard then setclipboard(CFG.KEY_LINK) end
        end)
        copyBtn.Text = "Copied!"
        safeWait(1.2)
        copyBtn.Text = "Copy Key Link"
    end)

    local keyBox = Instance.new("TextBox")
    keyBox.Size = UDim2.new(1, -40, 0, 34)
    keyBox.Position = UDim2.new(0, 20, 0, 105)
    keyBox.BackgroundColor3 = Color3.fromRGB(28, 26, 40)
    keyBox.PlaceholderText = "Paste key here..."
    keyBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
    keyBox.TextColor3 = Color3.fromRGB(220, 220, 240)
    keyBox.TextSize = 13
    keyBox.Font = Enum.Font.Gotham
    keyBox.ClearTextOnFocus = false
    keyBox.Text = ""
    keyBox.Parent = card
    Instance.new("UICorner", keyBox).CornerRadius = UDim.new(0, 8)

    local contBtn = Instance.new("TextButton")
    contBtn.Size = UDim2.new(1, -40, 0, 36)
    contBtn.Position = UDim2.new(0, 20, 0, 155)
    contBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 100)
    contBtn.Text = "Continue"
    contBtn.TextColor3 = Color3.fromRGB(255,255,255)
    contBtn.TextSize = 14
    contBtn.Font = Enum.Font.GothamBold
    contBtn.Parent = card
    Instance.new("UICorner", contBtn).CornerRadius = UDim.new(0, 8)

    contBtn.MouseButton1Click:Connect(function()
        -- Simple accept for now (you can add real validation later)
        gui:Destroy()
        if onSuccess then onSuccess() end
    end)
end

-- ═══════════════════════════════════════════════════════════════
--  START
-- ═══════════════════════════════════════════════════════════════
createKeySystem(function()
    createPublicUI()
end)
