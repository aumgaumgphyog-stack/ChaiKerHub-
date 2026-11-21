local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local NEAR_SPAWN_THRESHOLD_SEC = 20 * 60

local function getGuiParent()
	local okPg, pg = pcall(function()
		return LocalPlayer:WaitForChild("PlayerGui", 5)
	end)
	if okPg and pg then
		return pg
	end
	local okCg, cg = pcall(function()
		return game:GetService("CoreGui")
	end)
	if okCg and cg then
		return cg
	end
	return nil
end

local parentGui = getGuiParent()
if not parentGui then
	warn("Chai Ker Hub: Cannot find GUI parent")
	return
end

pcall(function()
	if parentGui:FindFirstChild("ChaiKerBossTracker") then
		parentGui.ChaiKerBossTracker:Destroy()
	end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ChaiKerBossTracker"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999999

local attached = pcall(function()
	ScreenGui.Parent = parentGui
end)
if not attached then
	pcall(function()
		ScreenGui.Parent = game:GetService("CoreGui")
	end)
end

local Theme = {
	BgMain = Color3.fromRGB(18, 18, 22),
	BgTop = Color3.fromRGB(28, 20, 24),
	Card = Color3.fromRGB(32, 32, 40),
	Accent = Color3.fromRGB(225, 38, 62),
	HopBlue = Color3.fromRGB(45, 115, 225),
	StopRed = Color3.fromRGB(190, 42, 52),
	Success = Color3.fromRGB(38, 175, 110),
	Warning = Color3.fromRGB(235, 165, 40),
	MutedBtn = Color3.fromRGB(52, 52, 64),
	TextMain = Color3.fromRGB(245, 245, 250),
	TextMuted = Color3.fromRGB(170, 170, 185)
}

local BossDatabase = {
	World2 = {
		{ Id = "W2_Hydra", Name = "Hydra (ไฮดร้า)", Category = "Sea Event / Boss", Keywords = { "hydra", "ไฮดร้า" }, DefaultPos = Vector3.new(-4200, 50, 2800), RespawnSec = 3600 },
		{ Id = "W2_SeaKing", Name = "Sea King (เจ้าทะเล)", Category = "Sea Event / Boss", Keywords = { "seaking", "sea king", "เจ้าทะเล" }, DefaultPos = Vector3.new(2500, 30, -3100), RespawnSec = 3600 },
		{ Id = "W2_GhostShip", Name = "Ghost Ship (เรือผี)", Category = "Sea Event / Ship", Keywords = { "ghostship", "ghost ship", "เรือผี" }, DefaultPos = Vector3.new(-1800, 40, -2900), RespawnSec = 1800 },
		{ Id = "W2_Serpent", Name = "Serpent (เซอร์เพนท์)", Category = "Sea Event / Leviathan", Keywords = { "serpent", "sea serpent", "เซอร์เพนท์" }, DefaultPos = Vector3.new(3400, 35, 1900), RespawnSec = 2700 },
		{ Id = "W2_BigMom", Name = "Big Mom (บิ๊กมัม)", Category = "Raid / Island Boss", Keywords = { "bigmom", "big mom", "บิ๊กมัม" }, DefaultPos = Vector3.new(-2650, 120, 4100), RespawnSec = 1800 },
		{ Id = "W2_Oden", Name = "Oden (โอเด้ง)", Category = "Island Boss", Keywords = { "oden", "โอเด้ง" }, DefaultPos = Vector3.new(1450, 140, 3600), RespawnSec = 1800 }
	},
	World3 = {
		{ Id = "W3_Monkey", Name = "Monkey Boss (บอสลิง)", Category = "World 3 Boss", Keywords = { "monkey", "gorilla", "บอสลิง" }, DefaultPos = Vector3.new(1200, 110, -1800), RespawnSec = 1200 },
		{ Id = "W3_Turtle", Name = "Turtle Boss (บอสเต่า)", Category = "World 3 Boss", Keywords = { "turtle", "บอสเต่า" }, DefaultPos = Vector3.new(-2400, 90, 1600), RespawnSec = 1500 },
		{ Id = "W3_Peter", Name = "Peter Boss (บอสปีเตอร์)", Category = "World 3 Boss", Keywords = { "peter", "บอสปีเตอร์" }, DefaultPos = Vector3.new(3100, 130, 2200), RespawnSec = 1800 },
		{ Id = "W3_Serpent", Name = "Serpent W3 (เซอร์เพนท์)", Category = "Sea Event / Boss", Keywords = { "serpent", "เซอร์เพนท์" }, DefaultPos = Vector3.new(-3800, 35, -2400), RespawnSec = 2700 },
		{ Id = "W3_Halloween", Name = "Halloween Boss (บอสฮาโลวีน)", Category = "Event Boss", Keywords = { "halloween", "pumpkin", "ฮาโลวีน" }, DefaultPos = Vector3.new(850, 150, 2900), RespawnSec = 3600 },
		{ Id = "W3_AllSea", Name = "All Sea Events (บอสทะเลทุกตัว)", Category = "Timed Sea Events", Keywords = { "seaking", "hydra", "ghostship", "serpent", "kraken" }, DefaultPos = Vector3.new(0, 40, 0), RespawnSec = 1800 }
	}
}

local env = (type(getgenv) == "function" and getgenv()) or _G
env.ChaiKerSelectedHopBosses = env.ChaiKerSelectedHopBosses or {}
local selectedHopBosses = env.ChaiKerSelectedHopBosses

for _, worldList in pairs(BossDatabase) do
	for _, b in ipairs(worldList) do
		if selectedHopBosses[b.Id] == nil then
			selectedHopBosses[b.Id] = true
		end
	end
end

local trackedBoss = nil
local customResetOffsets = {}
local isHopActive = false
local visitedServers = {}

local function formatTime(seconds)
	if not seconds or seconds <= 0 then return "00:00" end
	local hrs = math.floor(seconds / 3600)
	local mins = math.floor((seconds % 3600) / 60)
	local secs = math.floor(seconds % 60)
	if hrs > 0 then
		return string.format("%02d:%02d:%02d", hrs, mins, secs)
	end
	return string.format("%02d:%02d", mins, secs)
end

local function makeDraggable(guiObject, dragHandle)
	dragHandle = dragHandle or guiObject
	local dragging = false
	local dragStart, startPos

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = guiObject.Position
		end
	end)

	dragHandle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType.Touch) then
			local delta = input.Position - dragStart
			guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

-- เข็มทิศ HUD
local CompassFrame = Instance.new("Frame")
CompassFrame.Size = UDim2.new(0, 235, 0, 72)
CompassFrame.Position = UDim2.new(0.5, -117, 0.05, 0)
CompassFrame.BackgroundColor3 = Theme.BgTop
CompassFrame.Visible = false
CompassFrame.Parent = ScreenGui
Instance.new("UICorner", CompassFrame).CornerRadius = UDim.new(0, 8)

local ArrowLabel = Instance.new("TextLabel")
ArrowLabel.Size = UDim2.new(0, 44, 0, 44)
ArrowLabel.Position = UDim2.new(0, 10, 0.5, -22)
ArrowLabel.BackgroundColor3 = Theme.Card
ArrowLabel.Text = "▲"
ArrowLabel.TextColor3 = Theme.Accent
ArrowLabel.Font = Enum.Font.GothamBold
ArrowLabel.TextSize = 20
ArrowLabel.Parent = CompassFrame
Instance.new("UICorner", ArrowLabel).CornerRadius = UDim.new(1, 0)

local CompTargetName = Instance.new("TextLabel")
CompTargetName.Size = UDim2.new(1, -90, 0, 20)
CompTargetName.Position = UDim2.new(0, 62, 0, 8)
CompTargetName.BackgroundTransparency = 1
CompTargetName.Text = "เป้าหมาย: -"
CompTargetName.TextColor3 = Theme.TextMain
CompTargetName.Font = Enum.Font.GothamBold
CompTargetName.TextSize = 12
CompTargetName.TextXAlignment = Enum.TextXAlignment.Left
CompTargetName.TextTruncate = Enum.TextTruncate.AtEnd
CompTargetName.Parent = CompassFrame

local CompDistLabel = Instance.new("TextLabel")
CompDistLabel.Size = UDim2.new(1, -90, 0, 18)
CompDistLabel.Position = UDim2.new(0, 62, 0, 28)
CompDistLabel.BackgroundTransparency = 1
CompDistLabel.Text = "ระยะทาง: 0 m"
CompDistLabel.TextColor3 = Theme.Warning
CompDistLabel.Font = Enum.Font.GothamBold
CompDistLabel.TextSize = 11
CompDistLabel.TextXAlignment = Enum.TextXAlignment.Left
CompDistLabel.Parent = CompassFrame

local CompStatusLabel = Instance.new("TextLabel")
CompStatusLabel.Size = UDim2.new(1, -90, 0, 16)
CompStatusLabel.Position = UDim2.new(0, 62, 0, 48)
CompStatusLabel.BackgroundTransparency = 1
CompStatusLabel.Text = "สถานะ: พร้อม"
CompStatusLabel.TextColor3 = Theme.TextMuted
CompStatusLabel.Font = Enum.Font.GothamMedium
CompStatusLabel.TextSize = 10
CompStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
CompStatusLabel.Parent = CompassFrame

local CloseCompBtn = Instance.new("TextButton")
CloseCompBtn.Size = UDim2.new(0, 22, 0, 22)
CloseCompBtn.Position = UDim2.new(1, -28, 0, 6)
CloseCompBtn.BackgroundColor3 = Theme.Card
CloseCompBtn.Text = "×"
CloseCompBtn.TextColor3 = Theme.TextMain
CloseCompBtn.Font = Enum.Font.GothamBold
CloseCompBtn.TextSize = 14
CloseCompBtn.Parent = CompassFrame
Instance.new("UICorner", CloseCompBtn).CornerRadius = UDim.new(0, 6)

CloseCompBtn.MouseButton1Click:Connect(function()
	trackedBoss = nil
	CompassFrame.Visible = false
end)
makeDraggable(CompassFrame, CompassFrame)

-- ปุ่มเปิด/ปิด และหน้าต่างหลัก
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 126, 0, 34)
ToggleBtn.Position = UDim2.new(0.03, 0, 0.25, 0)
ToggleBtn.BackgroundColor3 = Theme.BgTop
ToggleBtn.Text = "CHAI KER HUB"
ToggleBtn.TextColor3 = Theme.TextMain
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 12
ToggleBtn.Parent = ScreenGui
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 8)

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 430, 0, 390)
MainFrame.Position = UDim2.new(0.5, -215, 0.5, -195)
MainFrame.BackgroundColor3 = Theme.BgMain
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 36)
TopBar.BackgroundColor3 = Theme.BgTop
TopBar.Parent = MainFrame
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "CHAI KER HUB • BOSS HOP (≤ 20 นาที)"
Title.TextColor3 = Theme.TextMain
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local HideMainBtn = Instance.new("TextButton")
HideMainBtn.Size = UDim2.new(0, 26, 0, 24)
HideMainBtn.Position = UDim2.new(1, -32, 0.5, -12)
HideMainBtn.BackgroundColor3 = Theme.Accent
HideMainBtn.Text = "×"
HideMainBtn.TextColor3 = Theme.TextMain
HideMainBtn.Font = Enum.Font.GothamBold
HideMainBtn.TextSize = 14
HideMainBtn.Parent = TopBar
Instance.new("UICorner", HideMainBtn).CornerRadius = UDim.new(0, 6)

HideMainBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)
ToggleBtn.MouseButton1Click:Connect(function() MainFrame.Visible = not MainFrame.Visible end)
makeDraggable(MainFrame, TopBar)
makeDraggable(ToggleBtn, ToggleBtn)

-- แถบปุ่ม Hop / หยุด Hop
local ControlBar = Instance.new("Frame")
ControlBar.Size = UDim2.new(1, -20, 0, 34)
ControlBar.Position = UDim2.new(0, 10, 0, 42)
ControlBar.BackgroundColor3 = Theme.Card
ControlBar.Parent = MainFrame
Instance.new("UICorner", ControlBar).CornerRadius = UDim.new(0, 8)

local StartMultiHopBtn = Instance.new("TextButton")
StartMultiHopBtn.Size = UDim2.new(0.48, 0, 0, 24)
StartMultiHopBtn.Position = UDim2.new(0.015, 0, 0.5, -12)
StartMultiHopBtn.BackgroundColor3 = Theme.HopBlue
StartMultiHopBtn.Text = "เริ่ม Hop บอสที่เลือก"
StartMultiHopBtn.TextColor3 = Theme.TextMain
StartMultiHopBtn.Font = Enum.Font.GothamBold
StartMultiHopBtn.TextSize = 11
StartMultiHopBtn.Parent = ControlBar
Instance.new("UICorner", StartMultiHopBtn).CornerRadius = UDim.new(0, 6)

local StopHopBtn = Instance.new("TextButton")
StopHopBtn.Size = UDim2.new(0.48, 0, 0, 24)
StopHopBtn.Position = UDim2.new(0.505, 0, 0.5, -12)
StopHopBtn.BackgroundColor3 = Theme.StopRed
StopHopBtn.Text = "กดหยุด Hop"
StopHopBtn.TextColor3 = Theme.TextMain
StopHopBtn.Font = Enum.Font.GothamBold
StopHopBtn.TextSize = 11
StopHopBtn.Parent = ControlBar
Instance.new("UICorner", StopHopBtn).CornerRadius = UDim.new(0, 6)

-- แท็บ โลก 2 / โลก 3
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -20, 0, 28)
TabBar.Position = UDim2.new(0, 10, 0, 82)
TabBar.BackgroundTransparency = 1
TabBar.Parent = MainFrame

local TabW2 = Instance.new("TextButton")
TabW2.Size = UDim2.new(0.49, 0, 1, 0)
TabW2.BackgroundColor3 = Theme.Accent
TabW2.Text = "โลก 2 (Second Sea)"
TabW2.TextColor3 = Theme.TextMain
TabW2.Font = Enum.Font.GothamBold
TabW2.TextSize = 11
TabW2.Parent = TabBar
Instance.new("UICorner", TabW2).CornerRadius = UDim.new(0, 6)

local TabW3 = Instance.new("TextButton")
TabW3.Size = UDim2.new(0.49, 0, 1, 0)
TabW3.Position = UDim2.new(0.51, 0, 0, 0)
TabW3.BackgroundColor3 = Theme.Card
TabW3.Text = "โลก 3 (Third Sea)"
TabW3.TextColor3 = Theme.TextMain
TabW3.Font = Enum.Font.GothamBold
TabW3.TextSize = 11
TabW3.Parent = TabBar
Instance.new("UICorner", TabW3).CornerRadius = UDim.new(0, 6)

local ListScroll = Instance.new("ScrollingFrame")
ListScroll.Size = UDim2.new(1, -20, 1, -120)
ListScroll.Position = UDim2.new(0, 10, 0, 114)
ListScroll.BackgroundTransparency = 1
ListScroll.BorderSizePixel = 0
ListScroll.ScrollBarThickness = 4
ListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ListScroll.Parent = MainFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 6)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = ListScroll

ListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	ListScroll.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y + 10)
end)

-- ตรวจจับบอสแบบไม่สแกนลึกจนค้าง
local function scanBossState(bossInfo)
	local foundPos = nil
	local isAlive = false

	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") or obj:IsA("BasePart") then
			local lower = obj.Name:lower()
			for _, kw in ipairs(bossInfo.Keywords) do
				if lower:find(kw:lower(), 1, true) then
					local part = obj:IsA("BasePart") and obj or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
					if part then
						foundPos = part.Position
						isAlive = true
						break
					end
				end
			end
			if isAlive then break end
		end
	end

	local baseTime = customResetOffsets[bossInfo.Name] or 0
	local elapsed = (workspace.DistributedGameTime - baseTime) % bossInfo.RespawnSec
	local remainSec = bossInfo.RespawnSec - elapsed
	local isNearSpawn = (not isAlive) and (remainSec <= NEAR_SPAWN_THRESHOLD_SEC)

	return isAlive, foundPos or bossInfo.DefaultPos, remainSec, isNearSpawn
end

local function serializeSelectedIds()
	local ids = {}
	for id, enabled in pairs(selectedHopBosses) do
		if enabled then table.insert(ids, id) end
	end
	return table.concat(ids, ",")
end

local function stopAllHop(reasonText)
	isHopActive = false
	env.ChaiKerAutoMultiHop = false
	StartMultiHopBtn.Text = "เริ่ม Hop บอสที่เลือก"
	StartMultiHopBtn.BackgroundColor3 = Theme.HopBlue
	if reasonText then
		CompStatusLabel.Text = reasonText
	end
end

local function executeServerJump()
	visitedServers[game.JobId] = true
	local qFn = (type(queue_on_teleport) == "function" and queue_on_teleport) or (syn and syn.queue_on_teleport)
	if qFn then
		pcall(function()
			qFn(string.format('getgenv().ChaiKerAutoMultiHop = true; getgenv().ChaiKerSelectedIdsStr = %q', serializeSelectedIds()))
		end)
	end

	local placeId = game.PlaceId
	local targetServerId = nil
	pcall(function()
		local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", placeId)
		local decoded = HttpService:JSONDecode(game:HttpGet(url))
		if decoded and type(decoded.data) == "table" then
			for _, srv in ipairs(decoded.data) do
				if srv.id ~= game.JobId and not visitedServers[srv.id] and (srv.playing or 0) < (srv.maxPlayers or 1) then
					targetServerId = srv.id
					break
				end
			end
		end
	end)

	while isHopActive do
		pcall(function()
			if targetServerId then
				TeleportService:TeleportToPlaceInstance(placeId, targetServerId, LocalPlayer)
			else
				TeleportService:Teleport(placeId, LocalPlayer)
			end
		end)
		task.wait(3)
	end
end

local function checkAnySelectedBossReady()
	local hasAnySelected = false
	for _, worldList in pairs(BossDatabase) do
		for _, boss in ipairs(worldList) do
			if selectedHopBosses[boss.Id] then
				hasAnySelected = true
				local isAlive, _, remainSec, isNearSpawn = scanBossState(boss)
				if isAlive or isNearSpawn then
					return true, boss, isAlive, remainSec
				end
			end
		end
	end
	return false, nil, false, 0, hasAnySelected
end

local function startMultiBossHop()
	local ready, matchedBoss, isAlive, remainSec, hasAnySelected = checkAnySelectedBossReady()
	if not ready and hasAnySelected == false then
		StartMultiHopBtn.Text = "เลือกบอสอย่างน้อย 1 ตัว"
		task.delay(1.5, function()
			if not isHopActive then StartMultiHopBtn.Text = "เริ่ม Hop บอสที่เลือก" end
		end)
		return
	end

	isHopActive = true
	StartMultiHopBtn.Text = "กำลัง Hop..."
	StartMultiHopBtn.BackgroundColor3 = Theme.Warning

	task.spawn(function()
		while isHopActive do
			local foundReady, targetBoss, aliveNow, remSec = checkAnySelectedBossReady()
			if foundReady and targetBoss then
				trackedBoss = targetBoss
				CompassFrame.Visible = true
				CompTargetName.Text = targetBoss.Name
				if aliveNow then
					stopAllHop("บอสเกิดแล้ว! หยุดรอและชี้เข็มทิศ")
				else
					stopAllHop("ใกล้เกิดใน " .. formatTime(remSec) .. " (≤ 20 นาที) หยุดรอ!")
				end
				break
			else
				CompassFrame.Visible = true
				CompTargetName.Text = "กำลังหาเซิร์ฟ..."
				CompStatusLabel.Text = "ไม่พบบอสใกล้เกิด (≤ 20 นาที) กำลัง Hop..."
				executeServerJump()
				break
			end
		end
	end)
end

StartMultiHopBtn.MouseButton1Click:Connect(function()
	if not isHopActive then startMultiBossHop() end
end)

StopHopBtn.MouseButton1Click:Connect(function()
	stopAllHop("กดหยุด Hop แล้ว")
end)

if type(env.ChaiKerSelectedIdsStr) == "string" and env.ChaiKerSelectedIdsStr ~= "" then
	for id in pairs(selectedHopBosses) do selectedHopBosses[id] = false end
	for id in string.gmatch(env.ChaiKerSelectedIdsStr, "([^,]+)") do selectedHopBosses[id] = true end
end

local activeCards = {}

local function renderWorldList(worldKey)
	for _, child in ipairs(ListScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	table.clear(activeCards)

	for i, boss in ipairs(BossDatabase[worldKey] or {}) do
		local card = Instance.new("Frame")
		card.LayoutOrder = i
		card.Size = UDim2.new(1, -6, 0, 64)
		card.BackgroundColor3 = Theme.Card
		card.Parent = ListScroll
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.55, 0, 0, 20)
		nameLbl.Position = UDim2.new(0, 10, 0, 5)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = boss.Name
		nameLbl.TextColor3 = Theme.TextMain
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.TextSize = 12
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nameLbl.Parent = card

		local catLbl = Instance.new("TextLabel")
		catLbl.Size = UDim2.new(0.55, 0, 0, 15)
		catLbl.Position = UDim2.new(0, 10, 0, 24)
		catLbl.BackgroundTransparency = 1
		catLbl.Text = "[" .. boss.Category .. "]"
		catLbl.TextColor3 = Theme.TextMuted
		catLbl.Font = Enum.Font.GothamMedium
		catLbl.TextSize = 10
		catLbl.TextXAlignment = Enum.TextXAlignment.Left
		catLbl.Parent = card

		local infoLbl = Instance.new("TextLabel")
		infoLbl.Size = UDim2.new(0.55, 0, 0, 18)
		infoLbl.Position = UDim2.new(0, 10, 0, 41)
		infoLbl.BackgroundTransparency = 1
		infoLbl.Text = "เวลา: --:-- | ระยะ: -- m"
		infoLbl.TextColor3 = Theme.Warning
		infoLbl.Font = Enum.Font.GothamBold
		infoLbl.TextSize = 11
		infoLbl.TextXAlignment = Enum.TextXAlignment.Left
		infoLbl.Parent = card

		local selectHopBtn = Instance.new("TextButton")
		selectHopBtn.Size = UDim2.new(0, 72, 0, 24)
		selectHopBtn.Position = UDim2.new(1, -148, 0, 8)
		selectHopBtn.BackgroundColor3 = selectedHopBosses[boss.Id] and Theme.Success or Theme.MutedBtn
		selectHopBtn.Text = selectedHopBosses[boss.Id] and "Hop: ON" or "Hop: OFF"
		selectHopBtn.TextColor3 = Theme.TextMain
		selectHopBtn.Font = Enum.Font.GothamBold
		selectHopBtn.TextSize = 10
		selectHopBtn.Parent = card
		Instance.new("UICorner", selectHopBtn).CornerRadius = UDim.new(0, 6)

		local compassB
