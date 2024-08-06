--[[
  @ Description:
    This is the operator of the base system/class,
    it manages the functionality of the droplets,
    the events of the casts, the limit and such.
]]

-- Variable definitions
local ParentClass = script.Parent
local Assets = ParentClass.Assets

-- Asset definitions
local Sounds = Assets.Sounds
local Essentials = Assets.Essentials

-- Sound definitions
local EndFolder = Sounds.End:GetChildren()
local StartFolder = Sounds.Start:GetChildren()

-- Essential definitions
local Functions = require(ParentClass.Functions)
local PartCache = require(Essentials.PartCache)
local Settings = require(ParentClass.Settings)
local FastCast = require(Essentials.FastCast)

-- Globals
local Unpack = table.unpack

-- Class definition
local Operator = {}
Operator.__index = Operator

--[[
  Class constructor, constructs the class
  including other properties/variables.
]]
function Operator.new(Class)
	local self = setmetatable({
		Handler = Class.ActiveHandler,
		Types = Class.Types,
	}, Operator)

	return self, self:Initialize(), self:InitializeCast()
end

--[[
  Immediately called after the construction of the class,
  defines properties/variables for after-construction
]]
function Operator:Initialize()
	-- Variable definitions
	local Handler: Settings.Class = self.Handler
	local FolderName: string = Handler.FolderName
	local Types: {} = self.Types

	-- Essential definitions
	local Type = Handler.Type
	local Limit = Handler.Limit
	local CastParams = Handler.RaycastParams

	local Folder = Functions.GetFolder(FolderName)
	local Object = Types[Type]:Clone()

	-- Class definitions
	local Cache = PartCache.new(Object, Limit, Folder)

	-- Insert variables
	Functions.MultiInsert(self, {
		Droplet = Object,
		Cache = Cache,
		Container = Folder,
		Caster = FastCast.new(),
		Behavior = function()
			return Functions.SetupBehavior(Cache, CastParams)
		end,
	})
end

--[[
  The Cast-Setup, which is executed immediately
  following the Initialization of the class.

  It efficiently manages events
  associated with the Caster.
]]
function Operator:InitializeCast()
	-- Self definitions
	local Caster: FastCast.Class = self.Caster
	local Handler: Settings.Class = self.Handler
	local Container: Folder = self.Container

	-- Event definitions
	local LengthChanged = Caster.LengthChanged
	local RayHit = Caster.RayHit

	-- Info definitions
	local Tweens = Handler.Tweens
	local Landed = Tweens.Landed

	-- Caster Listeners
	LengthChanged:Connect(function(_, Origin, Direction, Length, _, Object: BasePart)
		if not Object then
			return
		end

		-- 3D Definition
		local ObjectSize = Object.Size
		local ObjectLength = ObjectSize.Z / 2

		local Offset = CFrame.new(0, 0, -(Length - ObjectLength))

		local GoalCFrame = CFrame.new(Origin, Origin + Direction):ToWorldSpace(Offset)

		-- Update properties
		Object.CFrame = GoalCFrame
	end)

	RayHit:Connect(function(_, RaycastResult: RaycastResult, Velocity, Object: BasePart?)
		if not Object then
			return nil
		end

		-- Options definitions
		local Size = Handler.StartingSize
		local SizeRange = Handler.DefaultSize
		local Distance = Handler.Distance
		local Expansion = Handler.Expansion
		local IsDecal = Handler.Type == "Decal"

		-- Variable definitions
		local CastInstance = RaycastResult.Instance
		local Position = RaycastResult.Position
		local Normal = RaycastResult.Normal

		local VectorSize = Functions.GetVector(SizeRange)
		local GoalSize = Functions.RefineVectors(IsDecal, Vector3.new(VectorSize.X, VectorSize.Y / 4, VectorSize.X))

		local GoalAngles = Functions.GetAngles(IsDecal)
		local GoalCFrame = Functions.GetCFrame(Position, Normal, IsDecal) * GoalAngles

		local ClosestPart = Functions.GetClosest(Object, Distance, Container)

		local ExpansionLogic = (
			Expansion
			and ClosestPart
			and (not ClosestPart:GetAttribute("Decaying") and not ClosestPart:GetAttribute("Expanding"))
		)

		-- Evaluates if the droplet is close to another pool
		if ExpansionLogic then
			self:Expanse(Object, ClosestPart, Velocity, GoalSize)
			return nil
		end

		-- Update properties
		Object.Anchored = true
		Object.Size = Size
		Object.CFrame = GoalCFrame
		Object.Transparency = Functions.NextNumber(Unpack(Handler.DefaultTransparency))

		--[[
      Transitions the droplet into a pool,
      then handles its later functionality.
       (Decay, Sounds, etc...)
    ]]
		Functions.CreateTween(Object, Landed, { Size = GoalSize }):Play()

		self:HandleDroplet(Object)
		self:HitEffects(Object, Velocity)
		Functions.Weld(CastInstance, Object)

		return nil
	end)
end

--[[
  Emitter, emits a certain amount of droplets,
  at a certain point of origin, with a certain given direction.
]]
function Operator:Emit(Origin: Vector3, Direction: Vector3)
	-- Class definitions
	local Caster: FastCast.Class = self.Caster
	local Behavior: FastCast.Behavior = self.Behavior
	local Cache: PartCache.Class = self.Cache
	local Handler: Settings.Class = self.Handler

	-- Variable definitions
	local DropletVelocity = Handler.DropletVelocity
	local Velocity = Functions.NextNumber(Unpack(DropletVelocity)) * 10

	local RandomOffset = Handler.RandomOffset
	local OffsetRange = Handler.OffsetRange
	local Position = Functions.GetVector(OffsetRange) / 10

	-- Final definitions
	local FinalPosition = Origin + Vector3.new(Position.X, 0, Position.Z)

	local FinalStart = (RandomOffset and FinalPosition or Origin)

	if #Cache.Open <= 0 then
		return
	end

	-- Caster definitions, fire the caster with given arguments
	local ActiveDroplet = Caster:Fire(FinalStart, Direction, Velocity, Behavior)

	local RayInfo = ActiveDroplet.RayInfo
	local Droplet: Instance = RayInfo.CosmeticBulletObject

	-- Execute essential functions
	self:UpdateDroplet(Droplet)
	Functions.PlaySound(Functions.GetRandom(StartFolder), Droplet)
end

--[[
  A small function, designed to update the properties
  of a recently emitted droplet.
]]
function Operator:UpdateDroplet(Object: BasePart)
	-- Class definitions
	local Handler: Settings.Class = self.Handler

	-- Variable definitions
	local DropletTrail = Handler.Trail
	local DropletVisible = Handler.DropletVisible
	local IsDecal = Handler.Type == "Decal"

	-- Object definitions
	local Trail = Object:FindFirstChildOfClass("Trail")

	-- Update Object properties
	Object.Transparency = DropletVisible and 0 or 1
	Trail.Enabled = DropletTrail

	-- Execute essential functions
	Functions.ApplyDecal(Object, IsDecal)
end

--[[
  Handles the given droplet/object after
  it landed on a surface.
]]
function Operator:HandleDroplet(Object: BasePart)
	-- Class definitions
	local Handler: Settings.Class = self.Handler

	-- Object definitions
	local Trail = Object:FindFirstChildOfClass("Trail")

	-- Variable definitions
	local Tweens = Handler.Tweens
	local DecayDelay = Handler.DecayDelay

	local DecayInfo = Tweens.Decay
	local DecayTime = Functions.NextNumber(Unpack(DecayDelay))

	local ScaleDown = Handler.ScaleDown
	local FinalSize = ScaleDown and Vector3.new(0.01, 0.01, 0.01) or Object.Size

	-- Tween definitions
	local DecayTween = Functions.CreateTween(Object, DecayInfo, { Transparency = 1, Size = FinalSize })

	-- Update Droplet properties
	Trail.Enabled = false

	-- Listeners
	DecayTween.Completed:Connect(function()
		DecayTween:Destroy()
		Object:SetAttribute("Decaying", nil)
		self:ReturnDroplet(Object)
	end)

	-- Reset the droplet after the given DecayDelay has passed
	task.delay(DecayTime, function()
		DecayTween:Play()
		Object:SetAttribute("Decaying", true)
	end)
end

--[[
  HitEffects, a sequence of effects to enhance
  the visuals of the droplet->pool
]]
function Operator:HitEffects(Object, Velocity: Vector3)
	-- Class definitions
	local Handler: Settings.Class = self.Handler

	-- Variable definitions
	local SplashName = Handler.SplashName
	local SplashAmount = Handler.SplashAmount
	local SplashByVelocity = Handler.SplashByVelocity
	local Divider = Handler.VelocityDivider

	local Magnitude = Velocity.Magnitude
	local FinalVelocity = Magnitude / Divider
	local FinalAmount = (SplashByVelocity and FinalVelocity or Functions.NextNumber(Unpack(SplashAmount)))
	local Splash = Object:FindFirstChild(SplashName)

	-- Execute essential functions
	Functions.PlaySound(Functions.GetRandom(EndFolder), Object)
	Functions.EmitParticles(Splash, FinalAmount)
end

--[[
	Simulates the pool expansion
	effect when a droplet is near
	a pool.

	It checks the distance between
	a threshold, then triggers changes
	on the droplet & pool.
]]
function Operator:Expanse(Object: BasePart, ClosestPart: BasePart, Velocity: Vector3, Size: Vector3)
	-- Self definitions
	local Handler: Settings.Class = self.Handler

	-- Variable definitions
	local Divider = Handler.ExpanseDivider
	local MaximumSize = Handler.MaximumSize
	local IsDecal = Handler.Type == "Decal"

	-- Info definitions
	local Tweens = Handler.Tweens
	local Expand = Tweens.Expand

	-- Value definitions
	local PoolSize = ClosestPart.Size
	local FinalVelocity = Velocity / 20
	local GoalSize = Vector3.new(Size.X, Size.Y / Divider, Size.Z) / Divider

	local FirstSize = Functions.RefineVectors(
		IsDecal,
		Vector3.new(PoolSize.X - FinalVelocity.Z, PoolSize.Y + FinalVelocity.Y, PoolSize.Z - FinalVelocity.Z)
	)

	local LastSize = Vector3.new(PoolSize.X, PoolSize.Y, PoolSize.Z) + GoalSize

	local FinalSize = (LastSize.X < MaximumSize and LastSize or PoolSize)

	-- Update properties
	ClosestPart:SetAttribute("Expanding", true)
	ClosestPart.Size = FirstSize

	-- Transition to Expanded size
	local Tween = Functions.CreateTween(ClosestPart, Expand, { Size = FinalSize })

	Tween:Play()
	Tween.Completed:Connect(function()
		ClosestPart:SetAttribute("Expanding", nil)
		Tween:Destroy()
	end)

	-- Execute essential functions
	Functions.PlaySound(Functions.GetRandom(EndFolder), ClosestPart)
	self:ReturnDroplet(Object)
end

--[[
  Resets the given droplet/pool,
  then returns it to the Cache.
]]
function Operator:ReturnDroplet(Object: Instance)
	-- Self definitions
	local Cache: PartCache.Class = self.Cache
	local Template: Instance = self.Droplet

	-- Execute essential functions
	Functions.ResetDroplet(Object, Template)
	Cache:ReturnPart(Object) -- Ignore, ReturnPart exists
end

-- Exports the class
export type Class = typeof(Operator.new(...))

return Operator
