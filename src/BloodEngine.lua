-- Written By: @Smileeiles
-- Description: A blood engine system, can be used for anything other than a blood system if thats what you want.

--[[
	HOW TO USE:
	```lua
		-- You can leave any of these values as nil, it'll use the default values
		local DripSettings = {
			500, -- Limit: The maximum number of blood drips that can be active at once
			true, -- RandomOffset: Whether to use random positions for the blood drips
			0.5, -- Speed: The speed or velocity at which the blood drips fall
			0.01 -- DripDelay: The delay between emitting blood drips,
			false, -- DripVisibile: Determines if the blood drip is visibile when emitted
			true -- Bouncing: Whether to make the drip bounce sometimes or never
		}
	
		local BloodEngine = require(PathToModule)
		local BloodInstance = BloodEngine.new(table.unpack(DripSettings)) -- customize to whatever you want
		
		local _Random = Random.new()
		local Part = workspace.Part
		
		local Divider = 10
		local Sprayed = Vector3.new(
			_Random:NextNumber(-5, 10), 
			_Random:NextNumber(-5, 10), 
			_Random:NextNumber(-5, 10)
		) / Divider
		
		-- Emits drips from a part in the workspace, emits 10 blood drips only in the front direction
		BloodInstance:Emit(Part, Part.CFrame.LookVector, 10) -- also customize to whatever you want
		
		-- Emits drips from a part in the workspace, emits 10 blood drips around the part
		BloodInstance:Emit(Part, Sprayed, 10)
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
		BloodInstance.Speed = 0
		BloodInstance.DripDelay = 5
	```
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Folders
local Terrain = workspace.Terrain
local GoreFolder = ReplicatedStorage.Assets
local Sounds = GoreFolder.Sounds

-- Gore Instances
local DripPart = GoreFolder.Drip
local End = Sounds.End:GetChildren()
local Start = Sounds.Start:GetChildren()

-- Globals
local Unpack = table.unpack
local IsServer = RunService:IsServer()

-- Class
local BloodEngine = {}
BloodEngine.__index = BloodEngine

-- Base settings/constants
local Constants = {
	ServerRestriction = true, -- Disables the restriction from running the module on the server
	RandomOffset = true, -- Makes the drip start from a random position based of the part's position
	Bouncing = true, -- Enables bouncing, when the drip touches the ground, it may have a chance to bounce
	DripVisible = false, -- Determines if the drip is visible when first emitted (NOT THE BLOOD POOL!!!!)
	DripDelay = 0.01, -- The delay between each drip creation
	Speed = 5, -- The minimum speed of the drip before it becomes a pool
	Limit = 500, -- The limit of the blood drips
	Distance = 1, -- The distance at which a blood drip will activate and become into a pool
	BouncingDistance = 0.3 -- The distance used if the bouncing value was set to true
}

-- Custom made warn function, functions like the warn method but with extra unneccesary symbols
local function Warn(...)
	warn(("BLOOD ENGINE ▶ %s"):format(...))
end

-- USE ONLY IN CLIENTS, IT IS MUCH SMOOTHER THAN RUNNING IT ON SERVER
if (IsServer and not Constants.ServerRestriction) then
	Warn("Do not run the module on the server, if you wish to do so you can disable the ServerRestriction setting in the Constants table.")
	
	return
end

-- Used when making a new instance of the BloodEngine.
-- Use to initialize and assign variables/values
function BloodEngine.new(Limit: number, RandomOffset: boolean, Speed: number, DripDelay: number, DripVisible: boolean, Bouncing: boolean)
	local self = setmetatable({}, BloodEngine)
	
	-- Creates a folder for drips if necessary
	local DripsFolder = Terrain:FindFirstChild("DripsFolder") or Instance.new("Folder", Terrain)
	DripsFolder.Name = DripsFolder.Name == "DripsFolder" and DripsFolder.Name or "DripsFolder"
	
	-- Create and initialize the RaycastParams object outside of the function
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {DripsFolder}
	raycastParams.IgnoreWater = true
	
	-- Assign class variables
	self.Settings = {
		DripLimit = Limit or Constants.Limit,
		Speed = Speed or Constants.Speed,
		DripDelay = DripDelay or Constants.DripDelay,
		RandomOffset = RandomOffset or Constants.RandomOffset,
		Bouncing = Bouncing or Constants.Bouncing,
		DripVisible = DripVisible or Constants.DripVisible
	}
		
	self.Drips = {}
	self.DripsFolder = DripsFolder
	self.RaycastParams = raycastParams
	
	-- Assign other variables
	local Distance = Constants.Distance
	local BouncingDistance = Constants.BouncingDistance
	self._Random = Random.new()
	
	-- Connect a single function to the Heartbeat event of the RunService
	RunService.Heartbeat:Connect(function()
		-- Iterate over all drips in the drips table
		for Index, DripArray in self.Drips do
			-- Retreive information
			local -- Unpack information
				DripInstance: MeshPart,
				EndSound: Sound,
				BasePart: BasePart,
				IsPool: boolean = Unpack(DripArray)
			
			local FinalDistance = Bouncing and BouncingDistance or Distance
			
			
			-- Perform a raycast from the position of the part in the direction of its velocity and find the closest part to the drip
			local result = workspace:Raycast(DripInstance.Position, Vector3.new(0, -FinalDistance, 0), self.RaycastParams)

			-- Check if the result is not nil and if the hit object is not the basePart
			if DripInstance and result and result.Instance ~= BasePart and not IsPool then
				-- Move the part to the hit position
				DripArray.IsPool = true
				DripInstance.Anchored = true
				DripInstance.CanCollide = false
				DripInstance.Transparency = DripPart.Transparency
				DripInstance.CFrame = CFrame.new(result.Position) * CFrame.Angles(0, 0, 0)

				-- Grow the size of the part over time to create a blood pool
				local Info = TweenInfo.new(0.5, Enum.EasingStyle.Cubic)
				local RandomTweenIncrement = self._Random:NextNumber(3, 5) / 5
				local CurrentSize = DripInstance.Size
				local SizeGoal = Vector3.new(RandomTweenIncrement, self._Random:NextNumber(1, 10) / 100, RandomTweenIncrement)
				local Tween = TweenService:Create(DripInstance, Info, {Size = SizeGoal})

				-- Play size tween and start the ending sound
				EndSound:Play()
				Tween:Play()

				-- Decrease the size and transparency of the part after a few seconds have passed
				-- Then destroy and delete it from the blood parts dataset
				local DefaultTweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad)
				local DefaultTween = TweenService:Create(DripInstance, DefaultTweenInfo, {Transparency = 1, Size = Vector3.new(0.01, 0.01, 0.01)})

				task.delay(self._Random:NextNumber(10, 15), function()
					DefaultTween:Play()

					DefaultTween.Completed:Connect(function()
						-- Remove the drip instance from existance and from the Drips dataset
						table.remove(self.Drips, Index)
						DripInstance:Destroy()
					end)
				end)
			end
		end

		-- Check if the number of blood parts exceeds the bloodLimit
		if #self.Drips > self.Settings.DripLimit then
			-- Decrease the size and transparency of the part after a few seconds have passed
			-- Then destroy and delete it from the blood parts dataset
			local OldestDrip: MeshPart = table.remove(self.Drips, #self.Drips)
			
			local DefaultTweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad)
			local DefaultTween = TweenService:Create(OldestDrip, DefaultTweenInfo, {Transparency = 1, Size = Vector3.new(0.01, 0.01, 0.01)})
			
			DefaultTween:Play()
			
			DefaultTween.Completed:Connect(function()
				OldestDrip:Destroy()
			end)
		end
	end)
	
	return self
end

function BloodEngine:Emit(BasePart: BasePart, Direction: Vector3, Amount: number)
	-- Emit Blood
	for i = 1, Amount do
		-- Assign variables
		local IsPool = false
		
		-- Create a new part
		local Drip = DripPart:Clone()
		local RandomStart = Start[math.random(1, #Start)]:Clone()
		local RandomEnd = End[math.random(1, #End)]:Clone()
		
		Drip.CFrame = self.Settings.RandomOffset and CFrame.new(BasePart.Position + 
			Vector3.new(
				self._Random:NextNumber(-5, 5),
				-1,
				self._Random:NextNumber(-5, 5)
			) / 10
		) or BasePart.CFrame
		
		Drip.Parent = self.DripsFolder
		Drip.Transparency = self.Settings.DripVisible and 0 or 1
		RandomStart.Parent = Drip
		RandomEnd.Parent = Drip
		
		-- Play starting sound
		RandomStart:Play()

		-- Apply a random velocity to the part
		local LinearVelocity = Instance.new("VectorForce")
		LinearVelocity.Attachment0 = Instance.new("Attachment", Drip)
		LinearVelocity.Force = Direction * self.Settings.Speed
		LinearVelocity.Parent = Drip
		
		-- Remove and Update stuff after a few seconds
		task.delay(0.01, function()
			Drip.CanCollide = true
			LinearVelocity:Destroy()
		end)
		
		-- Add the part to the bloodParts table
		table.insert(self.Drips, 
			{ 
				Drip;
				RandomEnd;
				BasePart;
				IsPool; 
			}
		)
		
		-- Delay
		task.wait(self.Settings.DripDelay)
	end
end



return BloodEngine
