# PartCache
A linked list based part cache class written in strict Luau.
This can be used for when you are constantly creating parts, especially parts that only need to be there temporarily, such as:

- Particle/sound emitting parts
- Projectiles
- Lightning effects

Creating new parts and destroying them constantly, especially when rapid, is a very laggy process, and the part cache module will just CFrame the part when you pull a part from it. When the part is not needed anymore, you can return it to the cache, which will CFrame it further away again.

> The linked list emphasis helps because a linked list is similar to an array, except its structured differently. A linked list is comprised of nodes, which each contains a value, and a pointer to the next node in the list. The list traverses down until the last node, which has no next node. This is useful for performance in this case, because when we are removing values from arrays, we have to shift every value above it down by one for each value removed. Linked lists allow you to extract the node, and just change the references, and save lots of CPU usage. While slightly more memory costly, the tradeoff is worth it

This module is compatible with FastCast, and is compatible with --!strict typechecking.

## Installation

You can either install via wally, or by just grabbing the `init.luau` file from the repo.

## Usage Example

```luau
--!strict

--// This is a dumb usage example, but it will show you how it can be used.
--// Get part cache module
local PartCacheClass = require(path_to_module)

--// Create a part cache
local partCache = PartCacheClass.new(path_to_template_part_here, 50, path_to_storage_here)

--// Pull 30 parts from the cache
local partsInUse = partCache:GetParts(30)

--// We now have pulled 30 parts from the cache that we can use
--// Lets unanchor them and just throw them somewhere random from above

local RNG = Random.new()

for _, part in PartsInUse do
	part.Position = RNG:NextUnitVector() * RNG:NextNumber(0.5, 7.5)
	part.Anchored = false
end

--// Wait a bit
task.wait(6)

--// Return them to the cache
--// Returning parts will also re-anchor them, so we don't have to do that here
partCache:ReturnParts(partsInUse)

--// We don't need the part cache anymore, we can destroy it now, save some memory!
--// NOTE: This will also destroy parts in use. Beware!
partCache:Destroy()

--// You can use this in so many different ways, for re-using parts and not having to constantly clone and destroy them
```
