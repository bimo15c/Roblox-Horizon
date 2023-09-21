-- Written By: @Smileeiles
-- Description: A blood engine system, can be used for anything other than a blood system if thats what you want.
-- Version: V0.0.4

-- *This is the source code, use the file in the releases or the model on roblox if you want a fully functioning version as this does not contain all assets.


--[[
	HOW TO USE:
	```lua
		-- You can leave any of these values as nil, it'll use the default values
		self.Settings = {
			Decals = false, -- Use if you want to have your pools be decals instead of cylinders.
			RandomOffset = true, -- Whether to randomly offset the starting position of the droplets or not.
			DripVisible = false, -- Whether to show the droplets before they become a pool or not.
			DripDelay = 0.01, -- The delay between each droplet.
			DecayDelay = {10, 15}, -- Each pool will start to fade away randomly between min and max seconds after it’s created.
			Speed = 0.5, -- Determines the speed/velocity of the droplets.
			Limit = 500, -- The maximum amount of droplets/pools.
			PoolExpansion = false, -- Whether to expand the pool or not when a droplet lands on it.
			MaximumSize = 0.7, -- The maximum X size of the droplets.
			DefaultSize = {0.4, 0.7}, -- Minimum and Maximum. Both determine the default size of a pool.
			ExpansionSize = {0.1, 0.5}, -- Minimum and Maximum. Both determine the expansion size range of the pools.
			Filter = {} -- An array that stores instances that don't interfere with the droplets raycast process.
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
		BloodInstance.Settings.Speed = 0
		BloodInstance.Settings.DripDelay = 5
	```
]]

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

-- Events
local RenderStepped = RunService.RenderStepped

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

-- Used when making a new instance of the BloodEngine.
-- Used to initialize and assign variables/values
function BloodEngine.new(Options: {})
	local self = setmetatable({}, BloodEngine)

	-- Assign class variables
	self.Settings = {
		Decals = false, -- Use if you want to have your pools be decals instead of cylinders.
		RandomOffset = true, -- Whether to randomly offset the starting position of the droplets or not.
		DripVisible = false, -- Whether to show the droplets before they become a pool or not.
		DripDelay = 0.01, -- The delay between each droplet.
		DecayDelay = { 10, 15 }, -- Each pool will start to fade away randomly between min and max seconds after it’s created.
		Speed = 0.5, -- Determines the speed/velocity of the droplets.
		Limit = 500, -- The maximum number of droplets/pools.
		PoolExpansion = false, -- Whether to expand the pool or not when a droplet lands on it.
		MaximumSize = 0.7, -- The maximum X size of the droplets.
		DefaultSize = { 0.4, 0.7 }, -- Minimum and Maximum. Both determine the default size of a pool.
		ExpansionSize = { 0.1, 0.5 }, -- Minimum and Maximum. Both determine the expansion size range of the pools.
		Filter = {}, -- An array that stores instances that don't interfere with the droplets raycast process.
	}

	-- Assign values from options onto keys in self.Settings
	for Key, Value in Options do
		self.Settings[Key] = Value
	end

	-- Assign variables
	local Filter = self.Settings.Filter
	local Speed = self.Settings.Speed

	-- Update speed if decals are enabled
	self.Settings.Speed = self.Settings.Decals and Speed * 10 or Speed

	-- Creates a folder for drips if necessary
	local DripsFolder = Terrain:FindFirstChild("DripsFolder") or Instance.new("Folder", Terrain)
	DripsFolder.Name = DripsFolder.Name == "DripsFolder" and DripsFolder.Name or "DripsFolder"

	-- Create and initialize the RaycastParams object outside of the function
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = self.Settings.PoolExpansion and { Unpack(Filter) }
		or { DripsFolder, Unpack(Filter) }
	raycastParams.IgnoreWater = true

	self.Drips = {}
	self.DripsFolder = DripsFolder
	self.RaycastParams = raycastParams

	-- Assign other variables
	self._Random = Random.new()

	-- The function that handles each droplet/pool. Needs to be constantly running
	local function Handler(DeltaTime: number)
		DeltaTime = math.max(DeltaTime * 60, 1)

		-- If no drips exist, stop managing. Saves Performance.
		if #self.Drips <= 0 then
			return
		end

		-- Iterate over all drips in the drips table
		for Index, DripArray in self.Drips do
			-- Retreive information
			local -- Unpack information
				DripInstance: MeshPart,
				EndSound: Sound,
				BasePart: BasePart,
				IsPool: boolean,
				OldPosition: Vector3 = Unpack(DripArray)

			-- Perform a raycast from the position of the part in the direction of its velocity and find the closest part to the drip
			local Result = workspace:Raycast(
				DripInstance.Position,
				(DripInstance.Position - OldPosition).Unit * 1.5 * DeltaTime,
				self.RaycastParams
			)

			-- Update old position
			DripArray[5] = DripInstance.Position

			-- Check if the result is not nil and if the hit object is not the basePart
			if
				DripInstance
				and Result
				and Result.Instance ~= BasePart
				and not IsPool
				and not Result.Instance:IsDescendantOf(DripsFolder)
			then
				-- Assign variables
				local YLevel = self.Settings.Decals and 0.001 or 0.01
				local SizeYLevel = self._Random:NextNumber(1, 10) / 100
				local GoalYLevel = self.Settings.Decals and 0.002 or SizeYLevel
				local PositionYLevel = self.Settings.Decals and (Result.Normal / 76) or Vector3.zero

				local Position = CFrame.new(Result.Position + PositionYLevel, Result.Position + Result.Normal)
				local Angles = self.Settings.Decals and CFrame.Angles(-math.pi / 2, math.random(0, 180), 0)
					or CFrame.Angles(math.pi / 2, 0, 0)

				-- Move the part to the hit position
				DripArray[4] = true
				DripInstance.Anchored = false
				DripInstance.CanCollide = false
				DripInstance.CFrame = Position * Angles
				DripInstance.Transparency = DripPart.Transparency

				-- Weld the pool to the result's instance
				Weld(Result.Instance, DripInstance)

				-- Grow the size of the part over time to create a blood pool
				local Info = TweenInfo.new(0.5, Enum.EasingStyle.Cubic)
				local RandomTweenIncrement = self._Random:NextNumber(Unpack(self.Settings.DefaultSize))
				local SizeGoal = Vector3.new(RandomTweenIncrement, GoalYLevel, RandomTweenIncrement)
				local Tween = TweenService:Create(DripInstance, Info, { Size = SizeGoal })

				-- Play size tween and start the ending sound
				EndSound:Play()
				Tween:Play()

				-- Decrease the size and transparency of the part after a few seconds have passed
				-- Then destroy and delete it from the blood parts dataset
				local DefaultTweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad)
				local DefaultTween = TweenService:Create(
					DripInstance,
					DefaultTweenInfo,
					{ Transparency = 1, Size = Vector3.new(0.01, YLevel, 0.01) }
				)

				task.delay(self._Random:NextNumber(Unpack(self.Settings.DecayDelay)), function()
					DefaultTween:Play()

					DefaultTween.Completed:Connect(function()
						-- Remove the drip instance from existance and from the Drips dataset
						table.remove(self.Drips, Index)
						DripInstance:Destroy()
					end)
				end)
			end

			-- Does the same thing as making the drip a pool, but instead if it lands on a pool, it increases the pool's size
			if
				Result
				and Result.Instance ~= BasePart
				and not IsPool
				and Result.Instance:IsDescendantOf(DripsFolder)
			then
				-- Assign variables
				local FoundDrip: MeshPart? = Result.Instance
				local Size = FoundDrip.Size

				local RandomNumber = self._Random:NextNumber(Unpack(self.Settings.ExpansionSize))
				local SizeGoal = Size + Vector3.new(RandomNumber, 0, RandomNumber)

				local Logic = (
					FoundDrip.Size.X > self.Settings.MaximumSize
					or FoundDrip.Transparency < DripPart.Transparency
					or FoundDrip.Size.X < self.Settings.DefaultSize[1]
				)

				-- Pool & Size check
				if Logic then
					continue
				end

				-- Assign tweens
				local GoalInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad)
				local Tween = TweenService:Create(FoundDrip, GoalInfo, { Size = SizeGoal })

				-- Destroy the base drip
				table.remove(self.Drips, Index)
				DripInstance:Destroy()

				-- Apply sizing to the drip that got landed on and play the end sound
				Tween:Play()
				EndSound:Play()
			end

			-- Checks if the drip is in the void, if it is, destroy it.
			if DripInstance.Position.Y <= -80 then
				DripInstance:Destroy()
				table.remove(self.Drips, Index)
			end
		end

		-- Check if the number of blood parts exceeds the bloodLimit
		if #self.Drips > self.Settings.Limit then
			-- Decrease the size and transparency of the part after a few seconds have passed
			-- Then destroy and delete it from the blood parts dataset
			local OldestDrip: MeshPart? = table.remove(self.Drips, #self.Drips)

			local DefaultTweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad)
			local DefaultTween = TweenService:Create(
				OldestDrip,
				DefaultTweenInfo,
				{ Transparency = 1, Size = Vector3.new(0.01, 0.01, 0.01) }
			)

			DefaultTween:Play()

			DefaultTween.Completed:Connect(function()
				OldestDrip:Destroy()
			end)
		end
	end

	-- Connect the handler to the RenderStepped event
	RenderStepped:Connect(Handler)

	return self
end

-- Emits droplets using provided options: Point of origin (perferably a part), a Direction, and an Amount
function BloodEngine:Emit(BasePart: BasePart, Direction: Vector3, Amount: number)
	for _ = 1, Amount do
		-- Assign variables
		local IsPool = false

		-- Create a new part
		local Drip = self.Settings.Decals and DecalPart:Clone() or DripPart:Clone()
		local RandomDecal = self.Settings.Decals and Decals[math.random(1, #Decals)]:Clone()
		local RandomStart = Start[math.random(1, #Start)]:Clone()
		local RandomEnd = End[math.random(1, #End)]:Clone()

		Drip.CFrame = self.Settings.RandomOffset
				and CFrame.new(
					BasePart.Position
						+ Vector3.new(self._Random:NextNumber(-5, 5), -1, self._Random:NextNumber(-5, 5)) / 10
				)
			or BasePart.CFrame

		Drip.Parent = self.DripsFolder
		Drip.Transparency = self.Settings.DripVisible and 0 or 1
		RandomStart.Parent, RandomEnd.Parent = Drip, Drip

		-- Apply decal
		if RandomDecal then
			RandomDecal.Parent = Drip
		end

		-- Play starting sound
		RandomStart:Play()

		-- Assign direction
		local FinalDirection = Direction
			or Vector3.new(
					self._Random:NextNumber(-10, 10),
					self._Random:NextNumber(-10, 10),
					self._Random:NextNumber(-10, 10)
				) / 11

		-- Apply a random velocity to the part
		local LinearVelocity = Instance.new("VectorForce")
		LinearVelocity.Attachment0 = Instance.new("Attachment", Drip)
		LinearVelocity.Force = FinalDirection * self.Settings.Speed
		LinearVelocity.Parent = Drip

		-- Remove and Update stuff after a few seconds
		task.delay(0.01, function()
			Drip.CanCollide = false
			LinearVelocity:Destroy()
		end)

		-- Add the part to the bloodParts table
		table.insert(self.Drips, {
			Drip,
			RandomEnd,
			BasePart,
			IsPool,
			Drip.Position,
		})

		-- Delay
		task.wait(self.Settings.DripDelay)
	end
end

-- Return module if the runtime is client, else, return a warning.
return IsServer and {
	new = function(...)
		Warn(ServerWarn)
	end,
} or BloodEngine
