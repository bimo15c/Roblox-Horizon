Usage

To use Blood Engine, you need to require the module in your script and create a new instance of it. You can pass some arguments to the constructor to change the default settings of the system. For example:

```lua
-- You can leave any of these values as nil, it'll use the default values
local DripSettings = {
	500, -- Limit: The maximum number of blood drips that can be active at once
	true, -- RandomOffset: Whether to use random positions for the blood drips
	0.5, -- Speed: The speed or velocity at which the blood drips fall
	0.01, -- DripDelay: The delay between emitting blood drips,
	false, -- DripVisibile: Determines if the blood drip is visibile when emitted
	{} -- Filter: An array used to make the drips ignore certain parts (go through them, not interact with them)
}

-- MODULES
local BloodEngine = require(PathToModule)
local BloodInstance = BloodEngine.new(table.unpack(DripSettings)) -- customize to whatever you want
```

Then, you can use the Emit method to create blood drips from a base part in a given direction with a given amount. For example:

```lua
-- TARGET
local Part = workspace.Part

-- Emits drips from a part in the workspace, emits 10 blood drips only in the front direction
-- Leave the direction nil if you want it to go in a random direction
BloodInstance:Emit(Part, Part.CFrame.LookVector, 10) -- also customize to whatever you want
```

You can also change the settings of the system after creating an instance by accessing its properties. For example:

```lua
BloodInstance.Speed = 0
BloodInstance.DripDelay = 5
```

Now if you’d want to make a fully fledged system that makes blood appear in all clients, you can make a remote event, from server to client. When drips are needed, you can pass off the settings (BasePart, Direction, Amount) and the client will do the rest. Its recommended to have only one script manage the blood engine and let the server use its Emit method using the remote event.
