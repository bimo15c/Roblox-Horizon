### Installation
Put the BloodEngine module wherever you want, preferably in ReplicatedStorage.
The assets folder must be put in ReplicatedStorage, if you wish to put it anywhere else
make sure you change the path to it in the BloodEngine module to avoid errors
	
You can replace the sounds with whatever you want and add whatever you need to add.
If you can't find any good sounds, there's a folder you can download in the release tab of the repo.

### Usage
To use Blood Engine, you need to require the module in your script and create a new instance of it. You can pass some arguments to the constructor to change the default settings of the system. For example:

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
local BloodInstance = BloodEngine.new(table.unpack(DripSettings))
```

Then, you can use the Emit method to create blood drips from a base part in a given direction with a given amount. For example:

```lua
-- customize to whatever you want
local _Random = Random.new()
local Part = workspace.Part
local Divider = 10
local Sprayed = Vector3.new(
  _Random:NextNumber(-5, 10),
  _Random:NextNumber(-5, 10),
  _Random:NextNumber(-5, 10)
) / Divider

-- Emits drips from a part in the workspace, emits 10 blood drips only in the front direction
BloodInstance:Emit(Part, Part.CFrame.LookVector, 10)

-- also customize to whatever you want
-- Emits drips from a part in the workspace, emits 10 blood drips around the part
BloodInstance:Emit(Part, Sprayed, 10)
```

You can also change the settings of the system after creating an instance by accessing its properties. For example:

```lua
BloodInstance.Speed = 0
BloodInstance.DripDelay = 5
```

Now if you’d want to make a fully fledged system that makes blood appear in all clients, you can make a remote event, from server to client. When drips are needed, you can pass off the settings (BasePart, Direction, Amount) and the client will do the rest. Its recommended to have only one script manage the blood engine and let the server use its Emit method using the remote event.
