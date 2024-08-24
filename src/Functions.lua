--[[
  @Description: Contains a list of useful functions.
]]

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- Variable definitions
local ParentClass = script.Parent
local Assets = ParentClass.Assets

-- Asset definitions
local Images = Assets.Images
local Essentials = Assets.Essentials
local Effects = Assets.Effects

-- Effect definitions
local TrailEffects = Effects.Trail
local ImpactEffects = Effects.Impact

-- Essential definitions
local FastCast = require(Essentials.FastCast)
local Random = Random.new()

-- Globals
local Unpack = table.unpack
local Decals = Images:GetChildren()

-- Module definition
local Functions = {}

-- Variable definitions
local Properties = {
	"Size",
	"Transparency",
	"Anchored",
}

--[[
  A shorter way of doing:
  ```lua
    typeof(Variable) == "Type"
  ```
]]
function Functions.IsOfType(Any, Type: string)
	return typeof(Any) == Type
end

--[[
  Allows the ability to insert an array of
   variables efficently onto a table.
]]
function Functions.MultiInsert(List: {}, Variables: {})
	for Key, Variable in Variables do
		--[[
      Executes the variable if it's a function,
      It is expected to return a variable to later assign.
    ]]
		if Functions.IsOfType(Variable, "function") then
			Variable = Variable()
		end

		-- Adds in the variable with a key
		if Functions.IsOfType(Key, "string") then
			List[Key] = Variable
		end

		-- Adds in the variable without a key
		table.insert(List, Variable)
	end
end

--[[
  Returns the name of the specified function
  within the class’s metatable.
]]
function Functions.GetFunctionName(Function, Table)
	for Name, AltFunction in Table do
		return AltFunction == Function and Name
	end

	return nil
end

--[[
  Sets up a `CastBehavior` for later use,
  then returns it.
]]
function Functions.SetupBehavior(Cache, CastParams): FastCast.Behavior
	-- Define Variables
	local Behavior = FastCast.newBehavior()
	local Gravity = Workspace.Gravity

	-- Update Behavior properties
	Behavior.Acceleration = Vector3.new(0, -Gravity, 0)
	Behavior.MaxDistance = 500
	Behavior.RaycastParams = CastParams
	Behavior.CosmeticBulletProvider = Cache

	-- Export behavior
	return Behavior
end

--[[
	Clones and parents Droplet effects from a template part.
]]
function Functions.CreateEffects(Parent: MeshPart, ImpactName: string)
	-- Variable definitions
	local Trail = TrailEffects:Clone()
	
	local Attachment0 = Instance.new("Attachment")
	local Attachment1 = Instance.new("Attachment")
	local ImpactAttachment = Instance.new("Attachment")
	
	-- Update Trail-related properties
	Trail.Attachment0 = Attachment0
	Trail.Attachment1 = Attachment1
	
	Attachment1.Position = Vector3.new(0.037, 0, 0)
	Attachment0.Name = "Attachment0"
	Attachment1.Name = "Attachment1"
	
	Attachment0.Parent = Parent
	Attachment1.Parent = Parent
	Trail.Parent = Parent

	-- Update Impact-related properties
	for _, Effect in ipairs(ImpactEffects:GetChildren()) do
		local Clone = Effect:Clone()
		Clone.Parent = ImpactAttachment
	end
	
	ImpactAttachment.Name = ImpactName
	ImpactAttachment.Parent = Parent
	ImpactAttachment.Orientation = Vector3.new(0, 0, 0)
end

--[[
	Returns an empty object template that's going to be used as a droplet.
]]
function Functions.GetDroplet(ImpactName: string, IsDecal: boolean): {}
	-- Variable definitions
	local Droplet = Instance.new("MeshPart")
	
	-- Update properties
	Droplet.Size = Vector3.new(0.1, 0.1, 0.1)
	Droplet.Transparency = 0.25
	Droplet.Material = Enum.Material.Glass
	
	Droplet.Anchored = false
	Droplet.CanCollide = false
	Droplet.CanQuery = false
	Droplet.CanTouch = false
	
	-- Export droplet
	Functions.CreateEffects(Droplet, ImpactName)
	return Droplet
end

--[[
  Returns a folder that handles droplets; If it doesn't exist,
  make a new one in Workspace.Terrain.
]]
function Functions.GetFolder(Name: string): Folder
	-- Variable definitons
	local Terrain = Workspace.Terrain
	local DropletsFolder = (Terrain:FindFirstChild(Name) or Instance.new("Folder"))

	-- Update properties
	DropletsFolder.Name = Name
	DropletsFolder.Parent = Terrain

	-- Export folder
	return DropletsFolder
end

--[[
  Returns a Vector3, given the array range.
]]
function Functions.GetVector(Range: {})
	-- Vector definition
	local Vector = Vector3.new(
		Random:NextNumber(Unpack(Range)),
		Random:NextNumber(Unpack(Range)),
		Random:NextNumber(Unpack(Range))
	)

	-- Export position with applied offset
	return Vector
end

--[[
  NextNumber; Uses a global Random class,
  this is done for efficency.
]]
function Functions.NextNumber(Minimum, Maximum): number
	return Random:NextNumber(Minimum, Maximum)
end

--[[
  An efficent way of doing TweenService:Create(...)
]]
function Functions.CreateTween(Object: Instance, Info: TweenInfo, Goal: {}): Tween
	-- Export tween
	return TweenService:Create(Object, Info, Goal)
end

--[[
  Plays a sound in the given parent,
  used to play `End` & `Start` sounds.
]]
function Functions.PlaySound(Sound: Sound, Parent: Instance)
	if not Sound then
		return
	end

	local SoundClone = Sound:Clone()
	SoundClone.Parent = Parent

	SoundClone.Ended:Connect(function()
		SoundClone:Destroy()
	end)

	SoundClone:Play()
end

--[[
  Returns a random value/object from the
  given table.
]]
function Functions.GetRandom(Table: {})
	return #Table > 0 and Table[math.random(1, #Table)]
end

--[[
  Resets the properties of the given droplet,
  used to return pools to be recycled.
]]
function Functions.ResetDroplet(Object: Instance, Original: Instance)
	-- Variable definitions
	local Decal = Object:FindFirstChildOfClass("SurfaceAppearance")
	local Weld = Object:FindFirstChildOfClass("WeldConstraint")
	local Trail = Object:FindFirstChildOfClass("Trail")

	-- Reset all properties
	for _, Property: string in Properties do
		Object[Property] = Original[Property]
	end

	-- Update outsider properties
	if Trail then
		Trail.Enabled = false
	end

	if Weld then
		Weld:Destroy()
	end

	if Decal then
		Decal:Destroy()
	end

	-- Export object
	return Object
end

--[[
	Manages the sequence of decals;
	initiates only when the Type is designated as Decals.
]]
function Functions.ApplyDecal(Object: Instance, IsDecal: boolean)
	if not IsDecal then
		return
	end

	-- Variable definitions
	local Decal: SurfaceAppearance = Functions.GetRandom(Decals):Clone()

	-- Update Decal properties
	Decal.Parent = Object
end

--[[
	Emits particles by looping
	through an attachment's children; emitting a specific
	amount of them using the given amount.
]]
function Functions.EmitParticles(Attachment: Attachment, Amount: number)
	-- Variable definitions
	local Particles = Attachment:GetChildren()

	-- Emits particles
	for _, Particle: ParticleEmitter in Particles do
		if not Particle:IsA("ParticleEmitter") then
			continue
		end

		Particle:Emit(Amount)
	end
end

--[[
	Returns the closest part within a given distance.
]]
function Functions.GetClosest(Origin: BasePart, Magnitude: number, Ancestor): BasePart
	-- Variable definitions
	local Children = Ancestor:GetChildren()
	local ClosestPart = nil
	local MinimumDistance = math.huge

	for _, Part: BasePart in Children do
		local Distance = (Origin.Position - Part.Position).Magnitude

		local Logic = (not Part.Anchored and Origin ~= Part and Distance < Magnitude and Distance < MinimumDistance)

		if not Logic then
			continue
		end

		MinimumDistance = Distance
		ClosestPart = Part
	end

	-- Export closest part
	return ClosestPart
end

--[[
	Provides the target angles; utilized to
	assign the orientation to base position or CFrame.
]]
function Functions.GetAngles(IsDecal: boolean, RandomAngles: boolean): CFrame
	-- Variable definitions
	local RandomAngle = Functions.NextNumber(0, 180)
	local AngleX = (IsDecal and -math.pi / 2 or math.pi / 2)
	local AngleY = (RandomAngles and RandomAngle or 0)

	-- Export angles
	return CFrame.Angles(AngleX, AngleY, 0)
end

--[[
	Delievers the target position; serves
	as a foundation that is subsequently
	applied with an orientation.
]]
function Functions.GetCFrame(Position: Vector3, Normal: Vector3, IsDecal: boolean): CFrame
	-- Variable definitions
	local DecalOffset = (IsDecal and (Normal / 76) or Vector3.zero)

	local Base = (Position + DecalOffset)

	local Target = (Position + Normal)

	-- Export cframe
	return CFrame.new(Base, Target)
end

--[[
	Refines the components of the given
	Vector3; utilized to implement modifications
	based on factors.
]]
function Functions.RefineVectors(IsDecal: boolean, VectorData: Vector3)
	local YVector = (IsDecal and 0 or VectorData.Y)

	return Vector3.new(VectorData.X, YVector, VectorData.Z)
end

--[[
  Weld, creates a WeldConstraint between two parts
   (Part0 and Part1).
]]
function Functions.Weld(Part0: BasePart, Part1: BasePart): WeldConstraint
	-- Variable definitions
	local Weld = Instance.new("WeldConstraint")

	-- Update Part properties
	Part1.Anchored = false

	-- Update Weld properties
	Weld.Parent = Part1
	Weld.Part0 = Part0
	Weld.Part1 = Part1

	-- Export weld
	return Weld
end

--[[
	Adds a connection to a table that holds connections.
]]
function Functions.Connect(Connection: RBXScriptConnection, Holder: { RBXScriptConnection })
	-- Update table
	table.insert(Holder, Connection)
end

--[[
	Destroys and disconnects all the connections 
	in a table that holds connections.
]]
function Functions.DisconnectAll(Holder: { RBXScriptConnection })
	-- Disconnect and destroy connections in Holder
	for Index, Connection: RBXScriptConnection in Holder do
		Connection:Disconnect()
		Holder[Index] = nil
	end
end

--[[
	Basic function used to replace the initial module methods,
	therefore avoiding errors after deletion of the module.
]]
function Functions.Replacement()
	warn("BLOOD-ENGINE - Attempt to call a deleted function.")
end

return Functions
