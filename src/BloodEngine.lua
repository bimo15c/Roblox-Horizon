-- Written By: @Smileeiles
-- Description: A blood engine system, can be used for anything other than a blood system if thats what you want.
-- Version: V0.0.6
-- *^ Please don't use the source-code as it doesn't include all the assets, the rewrite hopefully wont have this issue.

--[[
	HOW TO USE:
	```lua
		-- You can leave any of these values as nil, it'll use the default values
		local DripSettings = {
			IgnorePlayers = false, -- Ignores any player characters in the workspace.
			Decals = false, -- Use if you want to have your pools be decals instead of cylinders.
			RandomOffset = true, -- Whether to randomly offset the starting position of the droplets or not.
			DripVisible = false, -- Whether to show the droplets before they become a pool or not.
			DripDelay = 0.01, -- The delay between each droplet.
			DecayDelay = { 10, 15 }, -- Each pool will start to fade away randomly between min and max seconds after it’s created.
			Speed = 0.5, -- Determines the speed/velocity of the droplets.
			Limit = 500, -- The maximum number of droplets/pools.
			SplashAmount = 10, -- The amount of splash particles to emit, 0 to fully disable it.
			DefaultSize = { 0.4, 0.7 }, -- Minimum and Maximum. Both determine the default size of a pool.
			Filter = {}, -- An array that stores instances that don't interfere with the droplets raycast process.
		}

		-- MODULES
		local BloodEngine = require(PathToModule)
		local BloodInstance = BloodEngine.new(DripSettings) -- customize to whatever you want

		-- TARGET
		local Part = workspace.Part

		-- Emits drips from a part in the workspace, emits 10 blood drips only in the front direction
		-- Leave the direction nil if you want it to go in a random direction `BloodInstance:Emit(Part, nil, 10)`
		-- EXAMPLE: BloodInstance:Emit(Part, nil, 10)
		BloodInstance:Emit(Part, Part.CFrame.LookVector, 10) -- also customize to whatever you want
	```

	BRIEF EXPLANATION:
	-- The main class:
	The blood engine is a module that can emit blood drips from a base part and make them fall and form pools on the ground. 
	The system uses some predefined constants, variables, and functions to control the behavior and appearance of the blood drips.

	-- The emit method:
	The system defines a method for the BloodEngine class called Emit.
	This method takes some arguments, such as BasePart, Direction, and Amount,
	and creates blood drips positioned from the base part in the given direction with the given amount.

	It also clones some instances from the sounds folders provided, such as Start and End,
	which are used to represent and play sounds for the blood drips.

	It also applies a random velocity to the blood drips using a VectorForce object based on the given direction.

	OTHER:
	If you prefer, do not run/require this on every script you need blood drips in.
	Just make a script that specifically is used to use methods and such from the Blood Engine.

	You can change the config after applying it into a new instance of the system by doing this:
	```lua
		BloodInstance:UpdateSettings({
			Speed = 0
			DripDelay = 5
		})
	```
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Folders
local Terrain = workspace.Terrain
local Sounds = script.Sounds

-- Gore Instances
local DripPart = script.Drip
local DecalPart = script.DripDecal

local End = Sounds.End:GetChildren()
local Start = Sounds.Start:GetChildren()
local Decals = script.Decals:GetChildren()

-- Globals
local Unpack = table.unpack
local IsServer = RunService:IsServer()
local ServerWarn = "Do not run the module on the server"

-- Essentials
local FastCast = require(script.FastCast)

-- Events
local PlayerAdded = Players.PlayerAdded

-- Class
local BloodEngine = {}
BloodEngine.__index = BloodEngine

-- Custom made warn function, functions like the warn method but with extra unneccesary symbols
local function Warn(...)
	warn(("BLOOD ENGINE ▶ %s"):format(...))
end

-- Welds Part0 to Part1, parents the weld to Part1
local function Weld(Part0, Part1)
	local WeldInstance = Instance.new("WeldConstraint")

	WeldInstance.Parent = Part1
	WeldInstance.Part0 = Part0
	WeldInstance.Part1 = Part1

	return WeldInstance
end

-- Removes the provided droplet with a transition
local function TransitionRemoveDroplet(Index: number, Drips: {}, Delay: number)
	-- Assign array
	local Array = table.remove(Drips, Index)
	local Droplet = Array.Identifier

	task.delay(Delay, function()
		-- Setup tween
		local Goal = { Transparency = 1, Size = Vector3.new(0, 0, 0) }
		local Info = TweenInfo.new(1, Enum.EasingStyle.Quad)
		local Tween = TweenService:Create(
			Droplet,
			Info,
			Goal
		)

		-- Destroy drip upon completion
		Tween.Completed:Connect(function()
			Droplet:Destroy()
		end)

		-- Start transition
		Tween:Play()
	end)
end

-- Used when making a new instance of the BloodEngine.
-- Used to initialize and assign variables/values
function BloodEngine.new(Options: {})
	local self = setmetatable({}, BloodEngine)

	-- Assign class variables
	self.Settings = {
		IgnorePlayers = false, -- Ignores any player characters in the workspace.
		Decals = false, -- Use if you want to have your pools be decals instead of cylinders.
		RandomOffset = true, -- Whether to randomly offset the starting position of the droplets or not.
		DripVisible = false, -- Whether to show the droplets before they become a pool or not.
		DripDelay = 0.01, -- The delay between each droplet.
		DecayDelay = { 10, 15 }, -- Each pool will start to fade away randomly between min and max seconds after it’s created.
		Speed = 0.5, -- Determines the speed/velocity of the droplets.
		Limit = 500, -- The maximum number of droplets/pools.
		SplashAmount = 10, -- The amount of splash particles to emit, 0 to fully disable it.
		DefaultSize = { 0.4, 0.7 }, -- Minimum and Maximum. Both determine the default size of a pool.
		Filter = {}, -- An array that stores instances that don't interfere with the droplets raycast process.
	}

	-- Assign values from options onto keys in self.Settings
	for Key, Value in Options do
		self.Settings[Key] = Value
	end

	-- Assign variables
	local Filter = self.Settings.Filter

	-- Creates a folder for drips if necessary
	local DripsFolder = Terrain:FindFirstChild("DripsFolder") or Instance.new("Folder", Terrain)
	DripsFolder.Name = DripsFolder.Name == "DripsFolder" and DripsFolder.Name or "DripsFolder"

	-- Assign a filter list
	local FilterList = self.Settings.PoolExpansion and { Unpack(Filter) }
		or { DripsFolder, Unpack(Filter) }

	-- Create and initialize the RaycastParams object outside of the function
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = FilterList
	Params.IgnoreWater = true

	-- Creates a brand new caster with its behavior
	self.Caster = FastCast.new()
	self.CasterBehavior = FastCast.newBehavior()

	-- Assign behavior properties
	self.CasterBehavior.CosmeticBulletTemplate  = self.Settings.Decals and DecalPart or DripPart
	self.CasterBehavior.CosmeticBulletContainer = DripsFolder
	self.CasterBehavior.Acceleration  					= Vector3.new(0, -workspace.Gravity, 0)
	self.CasterBehavior.MaxDistance   					= 500
	self.CasterBehavior.RaycastParams 					= Params

	-- Add new/old players to the filter list
	for _, Player in Players:GetPlayers() do
		if not self.Settings.IgnorePlayers then
			break
		end

		-- Assign variables
		local FilterInstances = Params.FilterDescendantsInstances

		-- Add characters to the filter list
		Params.FilterDescendantsInstances = {Player.Character, Unpack(FilterInstances)}

		-- Add any new characters to the filter list
		Player.CharacterAdded:Connect(function()
			Params.FilterDescendantsInstances = {Player.Character, Unpack(FilterInstances)}
		end)
	end

	PlayerAdded:Connect(function(Player)
		Player.CharacterAdded:Connect(function()
			-- Assign variables
			local FilterInstances = Params.FilterDescendantsInstances

			-- Add player character to filterlist
			Params.FilterDescendantsInstances = {Player.Character, Unpack(FilterInstances)}
		end)
	end)

	self.Drips = {}
	self.DripsFolder = DripsFolder

	-- Assign other variables
	self._Random = Random.new()
	self.RaycastParams = Params
	self.Emitting = false

	-- Gradually fades out a droplet over time and then destroys it.
	local function DecayDroplet(Droplet: BasePart, YLevel: number)
		local DefaultTweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad)
		local DefaultTween = TweenService:Create(
			Droplet,
			DefaultTweenInfo,
			{ Transparency = 1, Size = Vector3.new(0.01, YLevel, 0.01) }
		)

		task.delay(self._Random:NextNumber(Unpack(self.Settings.DecayDelay)), function()
			-- Destroy droplet when the tween completes
			DefaultTween.Completed:Connect(function()
				Droplet:Destroy()
			end)

			-- Play tween
			DefaultTween:Play()
		end)
	end

	-- Returns a droplet array using its identifier
	local function GetArray(Droplet: BasePart)
		local Array

		-- Find matching identifier
		for _, DropletArray in self.Drips do
			if (DropletArray.Identifier == Droplet) then
				Array = DropletArray
			end
		end

		return Array
	end

	-- Initiates the splashing sequence
	local function Splash(Droplet: BasePart, SplashAmount: number)
		-- Assign droplet children
		local ImpactAttachment: Attachment = Droplet.Impact
		local Particles = ImpactAttachment:GetChildren()

		-- Emit particles
		for _, Particle: ParticleEmitter in Particles do
			if (not Particle:IsA("ParticleEmitter")) then
				continue
			end

			Particle:Emit(SplashAmount)
		end
	end

	-- Connect the handler to the RenderStepped event
	--RenderStepped:Connect(Handler)

	self.Caster.RayHit:Connect(function(_, Result: RaycastResult, _, Droplet: BasePart)
		-- Assign variables
		local Settings = self.Settings

		-- Assign required position variables
		local YLevel = Settings.Decals and 0.001 or 0.01
		local SizeYLevel = self._Random:NextNumber(1, 10) / 100
		local GoalYLevel = Settings.Decals and 0.002 or SizeYLevel
		local PositionYLevel = Settings.Decals and (Result.Normal / 76) or Vector3.zero

		-- Assign outcome position
		local FinalPosition = Result.Position - Vector3.new(0, 0, 0.1)
		local Position = CFrame.new(FinalPosition + PositionYLevel, FinalPosition + Result.Normal)
		local Angles = self.Settings.Decals and CFrame.Angles(-math.pi / 2, math.random(0, 180), 0)
			or CFrame.Angles(math.pi / 2, 0, 0)

		-- Assign droplet-array properties
		local DropletArray = GetArray(Droplet)
		local EndSound = DropletArray.EndSound

		-- Update droplet properties
		Droplet.Anchored     = false
		Droplet.CanCollide   = false
		Droplet.CFrame 	     = Position * Angles
		Droplet.Transparency = DripPart.Transparency

		-- Weld the pool to the result's instance
		Weld(Result.Instance, Droplet)

		-- Grow the size of the part over time to create a blood pool
		local Info = TweenInfo.new(0.5, Enum.EasingStyle.Cubic)
		local RandomTweenIncrement = self._Random:NextNumber(Unpack(self.Settings.DefaultSize))
		local SizeGoal = Vector3.new(RandomTweenIncrement, GoalYLevel, RandomTweenIncrement)
		local Tween = TweenService:Create(Droplet, Info, { Size = SizeGoal })

		-- Call functions
		EndSound:Play()
		Tween:Play()
		Splash(
			Droplet,
			Settings.SplashAmount
		)

		-- Handles the decaying of the droplet/pool
		DecayDroplet(
			Droplet,
			YLevel
		)
	end)

	self.Caster.LengthChanged:Connect(function(_, Origin, Direction, Length, _, Droplet)
		if Droplet then
			local DropletLength = Droplet.Size.Z/2
			local Offset = CFrame.new(0,0, -(Length - DropletLength))

			Droplet.CFrame = CFrame.new(Origin, Origin + Direction):ToWorldSpace(Offset)
		end
	end)

	return self
end

-- Emits droplets using provided options: Point of origin (perferably a part), a Direction, and an Amount
function BloodEngine:Emit(BasePart: BasePart, Direction: Vector3, Amount: number)
	-- Enable emitting
	self.Emitting = true

	-- Emit droplets
	for _ = 1, Amount do
		-- Assign self variables
		local Settings = self.Settings

		-- Assign caster variables
		local Offset = BasePart.Position +
			Vector3.new(
				self._Random:NextNumber(-5, 5),
				 0,
				self._Random:NextNumber(-5, 5)
			) / 5

		local FinalPosition = Settings.RandomOffset and Offset or BasePart.Position

		local FinalDirection = Direction
			or Vector3.new(
				self._Random:NextNumber(-10, 10),
				-10,
				self._Random:NextNumber(-10, 10)
			) * 2

		local ActiveDroplet = self.Caster:Fire(
			FinalPosition,
			FinalDirection,
			Settings.Speed * 10,
			self.CasterBehavior
		)

		-- Remove any existing pool if the amount of droplets is above limit
		if #self.Drips > self.Settings.Limit then
			TransitionRemoveDroplet(
				2,
				self.Drips,
				1
			)
		end

		-- Assign active-droplet's information
		local RayInfo = ActiveDroplet.RayInfo
		local Droplet: BasePart = RayInfo.CosmeticBulletObject

		-- Assign droplet effects
		local RandomDecal = Settings.Decals and Decals[math.random(1, #Decals)]:Clone()
		local RandomStart = Start[math.random(1, #Start)]:Clone()
		local RandomEnd = End[math.random(1, #End)]:Clone()

		-- Update effect properties
		RandomStart.Parent, _ = Droplet, RandomStart:Play()
		RandomEnd.Parent      = Droplet

		-- Parent the random decal if its not null
		if (RandomDecal) then
			RandomDecal.Parent = Droplet
		end

		-- Update droplet properties
		Droplet.Transparency = self.Settings.DripVisible and 0 or 1
		table.insert(self.Drips, {
			Identifier = Droplet,
			EndSound = RandomEnd
		})

		-- Emitting delay
		task.wait(self.Settings.DripDelay)
	end

	-- Disable emitting
	self.Emitting = false
end

-- Updates the settings of the module efficiently
function BloodEngine:UpdateSettings(Options: {})
	-- Assign variables
	local Settings = self.Settings
	local Filter = Settings.Filter

	-- Assign values from options onto keys in self.Settings
	for Key, Value in Options do
		self.Settings[Key] = Value
	end

	-- Assign a filter list
	local FilterList = self.Settings.PoolExpansion and { Unpack(Filter) }
	or { self.DripsFolder, Unpack(Filter) }

	-- Add players characters to filter list
	for _, Player in Players:GetPlayers() do
		if not Settings.IgnorePlayers then
			break
		end

		-- Reset filterlist and readd characters
		table.insert(FilterList, Player.Character)
	end

	-- Update behavior properties
	self.RaycastParams.FilterDescendantsInstances = FilterList
	self.CasterBehavior.CosmeticBulletTemplate  = Settings.Decals and DecalPart or DripPart
end

-- Warns the current runtime if it is a server
if IsServer then
	Warn(ServerWarn)
end

-- Return module if the runtime is client, else, return a warning.
return BloodEngine
