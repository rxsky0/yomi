--[[
	COIN RUSH
	A small obby (obstacle course) where you collect coins and race to the finish.

	HOW TO USE
	  1. Open Roblox Studio and create a new "Baseplate" place.
	  2. In the Explorer, right-click ServerScriptService > Insert Object > Script.
	  3. Delete the default code, paste this whole file, and press Play.

	This one script builds the whole game when the server starts:
	  - a course of jumping platforms over lava, in two stages
	  - spinning coins that come back after a few seconds
	  - green speed pads, a checkpoint and a gold finish platform
	  - a leaderboard (Coins, Wins, Best time) and an on-screen timer
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

-- Settings you can change ---------------------------------------------------

local CONFIG = {
	Seed = 2026, -- change this number to get a different course layout
	PlatformsPerStage = 8,
	CoinValue = 1,
	CoinRespawnSeconds = 8,
	FinishBonus = 25, -- coins for reaching the finish
	NormalSpeed = 16,
	BoostSpeed = 30,
	BoostSeconds = 3,
}

local COLORS = {
	Start = Color3.fromRGB(90, 170, 255),
	Stage1 = Color3.fromRGB(120, 210, 120),
	Stage2 = Color3.fromRGB(255, 165, 70),
	Checkpoint = Color3.fromRGB(80, 120, 255),
	Finish = Color3.fromRGB(255, 215, 50),
	Lava = Color3.fromRGB(255, 70, 30),
	Coin = Color3.fromRGB(255, 200, 40),
	Speed = Color3.fromRGB(60, 255, 120),
}

-- Helpers --------------------------------------------------------------------

local map = Instance.new("Folder")
map.Name = "CoinRushMap"

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Parent = map
	return part
end

local function addLabel(part: BasePart, text: string, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(360, 90)
	billboard.StudsOffset = Vector3.new(0, 7, 0)
	billboard.MaxDistance = 200
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = billboard
end

-- Returns the player and humanoid for whatever part touched something,
-- but only if that character is alive.
local function getPlayerFromHit(hit: BasePart): (Player?, Humanoid?)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return Players:GetPlayerFromCharacter(character), humanoid
end

-- Player state and HUD -------------------------------------------------------

type PlayerState = {
	checkpoint: CFrame?,
	runStart: number,
	finished: boolean,
	bestTime: number?,
	timerLabel: TextLabel?,
	messageLabel: TextLabel?,
	messageId: number,
}

local states: { [Player]: PlayerState } = {}

local function notify(player: Player, text: string, seconds: number?)
	local state = states[player]
	if not state or not state.messageLabel then
		return
	end
	state.messageId += 1
	local id = state.messageId
	state.messageLabel.Text = text
	task.delay(seconds or 2.5, function()
		if state.messageId == id and state.messageLabel then
			state.messageLabel.Text = ""
		end
	end)
end

local function addCoins(player: Player, amount: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		coins.Value += amount
	end
end

local function buildHud(player: Player, state: PlayerState)
	local gui = Instance.new("ScreenGui")
	gui.Name = "CoinRushHUD"
	gui.ResetOnSpawn = false

	local timer = Instance.new("TextLabel")
	timer.AnchorPoint = Vector2.new(0.5, 0)
	timer.Position = UDim2.new(0.5, 0, 0, 12)
	timer.Size = UDim2.fromOffset(200, 44)
	timer.BackgroundColor3 = Color3.new(0, 0, 0)
	timer.BackgroundTransparency = 0.4
	timer.Font = Enum.Font.FredokaOne
	timer.TextScaled = true
	timer.TextColor3 = Color3.new(1, 1, 1)
	timer.Text = "0.0s"
	timer.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = timer

	local message = Instance.new("TextLabel")
	message.AnchorPoint = Vector2.new(0.5, 0.5)
	message.Position = UDim2.fromScale(0.5, 0.3)
	message.Size = UDim2.new(0.8, 0, 0, 56)
	message.BackgroundTransparency = 1
	message.Font = Enum.Font.FredokaOne
	message.TextScaled = true
	message.TextColor3 = Color3.fromRGB(255, 230, 90)
	message.TextStrokeTransparency = 0
	message.Text = ""
	message.Parent = gui

	state.timerLabel = timer
	state.messageLabel = message
	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Build the world -------------------------------------------------------------

-- Remove the template's default spawn so everyone starts on our course.
for _, descendant in workspace:GetDescendants() do
	if descendant:IsA("SpawnLocation") then
		descendant:Destroy()
	end
end

Lighting.ClockTime = 14

-- Lava under the whole course: falling in sends you back.
local lava = makePart(
	"Lava",
	Vector3.new(400, 1, 400),
	CFrame.new(0, 0.5, 130),
	COLORS.Lava,
	Enum.Material.Neon
)
lava.Touched:Connect(function(hit)
	local _, humanoid = getPlayerFromHit(hit)
	if humanoid then
		humanoid.Health = 0
	end
end)

-- Start area.
local startPlatform = makePart(
	"Start",
	Vector3.new(24, 2, 24),
	CFrame.new(0, 4, 0),
	COLORS.Start,
	Enum.Material.SmoothPlastic
)
addLabel(startPlatform, "COIN RUSH\nGrab coins, dodge lava, reach the gold!", Color3.new(1, 1, 1))

local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Name = "CoinRushSpawn"
spawnLocation.Anchored = true
spawnLocation.Size = Vector3.new(8, 1, 8)
spawnLocation.CFrame = CFrame.new(0, 5.5, -6)
spawnLocation.Color = Color3.new(1, 1, 1)
spawnLocation.Material = Enum.Material.SmoothPlastic
spawnLocation.Neutral = true
spawnLocation.Duration = 0 -- no force field
spawnLocation.Parent = map

local startCFrame = spawnLocation.CFrame + Vector3.new(0, 4, 0)

-- The course is built forward along +Z, one platform after another.
local rng = Random.new(CONFIG.Seed)
local frontEdgeZ = 12 -- front edge of the start platform
local topY = 5 -- height of the top of the last platform
local x = 0

local coinSpots: { Vector3 } = {}

local function addPlatform(name: string, size: number, gap: number, rise: number, color: Color3): Part
	topY += rise
	local z = frontEdgeZ + gap + size / 2
	local platform =
		makePart(name, Vector3.new(size, 2, size), CFrame.new(x, topY - 1, z), color, Enum.Material.SmoothPlastic)
	frontEdgeZ = z + size / 2
	return platform
end

local function addSpeedPad(platform: Part)
	local pad = makePart(
		"SpeedPad",
		Vector3.new(6, 0.4, 6),
		platform.CFrame + Vector3.new(0, 1.2, 0),
		COLORS.Speed,
		Enum.Material.Neon
	)
	pad.Touched:Connect(function(hit)
		local player, humanoid = getPlayerFromHit(hit)
		if not player or not humanoid or humanoid.WalkSpeed == CONFIG.BoostSpeed then
			return
		end
		humanoid.WalkSpeed = CONFIG.BoostSpeed
		notify(player, "SPEED BOOST!", 1.5)
		task.delay(CONFIG.BoostSeconds, function()
			if humanoid.Parent then
				humanoid.WalkSpeed = CONFIG.NormalSpeed
			end
		end)
	end)
end

-- Stage 1: big platforms, small gaps.
for i = 1, CONFIG.PlatformsPerStage do
	x = math.clamp(x + rng:NextInteger(-4, 4), -16, 16)
	local platform = addPlatform("Stage1_" .. i, 10, 4, rng:NextNumber(0, 1.5), COLORS.Stage1)
	table.insert(coinSpots, platform.Position + Vector3.new(0, 4, 0))
	if i % 4 == 2 then
		addSpeedPad(platform)
	end
end

-- Checkpoint halfway through.
local checkpoint = addPlatform("Checkpoint", 16, 4, 1, COLORS.Checkpoint)
addLabel(checkpoint, "CHECKPOINT", Color3.fromRGB(170, 200, 255))
local checkpointCFrame = checkpoint.CFrame + Vector3.new(0, 4, 0)
for _, offset in { Vector3.new(-5, 4, -5), Vector3.new(5, 4, -5), Vector3.new(-5, 4, 5), Vector3.new(5, 4, 5) } do
	table.insert(coinSpots, checkpoint.Position + offset)
end

-- Stage 2: smaller platforms, wider gaps.
for i = 1, CONFIG.PlatformsPerStage do
	x = math.clamp(x + rng:NextInteger(-4, 4), -16, 16)
	local platform = addPlatform("Stage2_" .. i, 7, 5, rng:NextNumber(0, 1.5), COLORS.Stage2)
	table.insert(coinSpots, platform.Position + Vector3.new(0, 4, 0))
end

-- Finish.
local finish = addPlatform("Finish", 20, 4, 1, COLORS.Finish)
finish.Material = Enum.Material.Neon
addLabel(finish, "FINISH", Color3.fromRGB(255, 240, 120))

-- Coins ------------------------------------------------------------------------

local spinInfo = TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)

local function makeCoin(position: Vector3)
	-- A cylinder's round faces point along its X axis, so this is a standing disc.
	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.5, 3, 3)
	coin.CFrame = CFrame.new(position)
	coin.Anchored = true
	coin.CanCollide = false
	coin.Color = COLORS.Coin
	coin.Material = Enum.Material.Neon
	coin.Parent = map

	local light = Instance.new("PointLight")
	light.Color = COLORS.Coin
	light.Range = 8
	light.Brightness = 1
	light.Parent = coin

	-- A half turn looks identical to the start, so the loop is seamless.
	TweenService:Create(coin, spinInfo, { CFrame = coin.CFrame * CFrame.Angles(0, math.pi, 0) }):Play()

	local taken = false
	coin.Touched:Connect(function(hit)
		if taken then
			return
		end
		local player = getPlayerFromHit(hit)
		if not player then
			return
		end
		taken = true
		coin.Transparency = 1
		light.Enabled = false
		addCoins(player, CONFIG.CoinValue)
		task.delay(CONFIG.CoinRespawnSeconds, function()
			coin.Transparency = 0
			light.Enabled = true
			taken = false
		end)
	end)
end

for _, position in coinSpots do
	makeCoin(position)
end

map.Parent = workspace

-- Checkpoint and finish ----------------------------------------------------------

checkpoint.Touched:Connect(function(hit)
	local player = getPlayerFromHit(hit)
	local state = player and states[player]
	if not player or not state or state.checkpoint then
		return
	end
	state.checkpoint = checkpointCFrame
	notify(player, "Checkpoint reached!")
end)

local function formatTime(seconds: number): string
	return string.format("%.1fs", seconds)
end

finish.Touched:Connect(function(hit)
	local player = getPlayerFromHit(hit)
	local state = player and states[player]
	if not player or not state or state.finished then
		return
	end
	state.finished = true

	local runTime = os.clock() - state.runStart
	local leaderstats = player:FindFirstChild("leaderstats")
	local wins = leaderstats and leaderstats:FindFirstChild("Wins")
	local best = leaderstats and leaderstats:FindFirstChild("Best")
	if wins and wins:IsA("IntValue") then
		wins.Value += 1
	end
	addCoins(player, CONFIG.FinishBonus)

	local newBest = state.bestTime == nil or runTime < state.bestTime
	if newBest then
		state.bestTime = runTime
		if best and best:IsA("StringValue") then
			best.Value = formatTime(runTime)
		end
	end
	if state.timerLabel then
		state.timerLabel.Text = formatTime(runTime)
	end
	notify(
		player,
		string.format("You finished in %s! +%d coins%s", formatTime(runTime), CONFIG.FinishBonus, newBest and "  NEW BEST!" or ""),
		3
	)

	-- Send them back to the start for another run.
	task.delay(4, function()
		if not states[player] then
			return
		end
		state.checkpoint = nil
		state.finished = false
		state.runStart = os.clock()
		local character = player.Character
		if character then
			character:PivotTo(startCFrame)
		end
	end)
end)

-- Players ------------------------------------------------------------------------

local function onCharacterAdded(player: Player, character: Model)
	local state = states[player]
	if not state then
		return
	end
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	character:WaitForChild("HumanoidRootPart")
	humanoid.WalkSpeed = CONFIG.NormalSpeed

	if state.checkpoint then
		-- Respawn at the checkpoint and keep the timer running.
		task.wait()
		character:PivotTo(state.checkpoint)
	else
		-- Dying before the checkpoint restarts the run.
		state.runStart = os.clock()
	end
end

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats

	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = leaderstats

	local best = Instance.new("StringValue")
	best.Name = "Best"
	best.Value = "-"
	best.Parent = leaderstats

	leaderstats.Parent = player

	local state: PlayerState = {
		checkpoint = nil,
		runStart = os.clock(),
		finished = false,
		bestTime = nil,
		timerLabel = nil,
		messageLabel = nil,
		messageId = 0,
	}
	states[player] = state

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end

	buildHud(player, state)
	notify(player, "Welcome to Coin Rush!", 3)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

-- Update every player's timer a few times a second.
while true do
	for _, state in states do
		if not state.finished and state.timerLabel then
			state.timerLabel.Text = formatTime(os.clock() - state.runStart)
		end
	end
	task.wait(0.1)
end
