--// Author: 8ch99
--// Date written: 20th November 2025
--// PartCache module that uses LinkedLists and has method parity with Xan_TheDragon's PartCache module
--// ^ excluding :Dispose(), which is written as :Destroy() instead

--[==[

MIT License

Copyright (c) 2026 8ch99

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]==]

--!strict
--!native
--!optimize 2

local CACHED_PART_CFRAME = CFrame.new(0, 1e7, 0)

--// @class PartCache

local PartCache = {}
PartCache.__index = PartCache
PartCache.__type = "PartCache"

--// Typedefs

export type PartCacheLinkNode = {
	Value: BasePart,
	Next: PartCacheLinkNode?,
}

export type PartCache = typeof(setmetatable({} :: {
	Cache: PartCacheLinkNode?,
	InUse: { [BasePart]: boolean },
	CacheSize: number,
	InUseSize: number,
	TotalSize: number,

	Template: BasePart,
	CurrentCacheParent: Instance,
	ExpansionSize: number
}, PartCache))


--[==[
	Creates a new PartCache with the given template part, part count, and parent container for the cache to use.

	@param template BasePart - The template base part to use, this is the part that will be used in the cache
	@param presetParts number? - The amount of parts you want to pre-create in the cache
	@param parent Instance? - The parent container you want to use for the cache

	@returns PartCache
]==]
function PartCache.new(template: BasePart, presetParts: number?, parent: Instance?, expansionSize: number?): PartCache
	assert(template and typeof(template) == "Instance" and template:IsA("BasePart"), "Template part is not a BasePart instance!")
	assert(template.Archivable == true, "Template part must be archivable! It will not work with the PartCache otherwise!")

	local realPresetParts = 5
	local realParent = workspace

	if presetParts ~= nil then
		assert(type(presetParts) == "number", "PresetParts must be provided!")
		assert(tostring(math.floor(presetParts)) == tostring(presetParts), "PresetParts must be an integer!")
		realPresetParts = presetParts
	end

	if parent ~= nil then
		assert(typeof(parent) == "Instance", "Valid parent must be provided!")
		realParent = parent
	end

	local self: PartCache = setmetatable({
		Cache = nil :: PartCacheLinkNode?,
		InUse = {} :: { [BasePart]: boolean },
		CacheSize = 0,
		InUseSize = 0,
		TotalSize = 0,

		Template = template:Clone(),
		CurrentCacheParent = realParent,
		ExpansionSize = expansionSize or 10,
	}, PartCache)

	self.Template.Anchored = true
	self.Template.Parent = nil

	self:Expand(realPresetParts)

	return self
end

--[==[
	Completely disposes of the part cache, use this when you don't need it anymore.
	NOTE: This will destroy parts that are in use aswell, which may break something if you aren't careful. Beware!
]==]
function PartCache.Destroy(self: PartCache)
	--// Destroy the template
	self.Template:Destroy()

	--// Destroy parts in use
	for part in self.InUse do
		part:Destroy()
	end

	table.clear(self.InUse)

	--// Destroy parts in cache
	local currentNode = self.Cache
	self.Cache = nil --// Remove from object

	while currentNode ~= nil do
		currentNode.Value:Destroy()
		currentNode = currentNode.Next
	end

	--// Destroy the rest of the object
	table.clear(self :: any)
	setmetatable(self :: any, nil)
end

--[==[
	Expands the size of the part cache by the given amount.

	@param count number - The amount of new parts to add to the cache
]==]
function PartCache.Expand(self: PartCache, count: number)
	local currentNode = self.Cache
	local parent = self.CurrentCacheParent
	local template = self.Template

	self.TotalSize += count
	self.CacheSize += count
	
	local newParts = table.create(count) :: { BasePart }
	local cframeList = table.create(count, CACHED_PART_CFRAME)
	
	--// Insert nodes
	for _ = 1, count do
		local part = template:Clone()
		currentNode = {
			Value = part,
			Next = currentNode
		}

		--part.CFrame = CACHED_PART_CFRAME
		--part.Parent = parent
		table.insert(newParts, part)
	end
	
	--// Move parts!
	workspace:BulkMoveTo(newParts, cframeList, Enum.BulkMoveMode.FireCFrameChanged)
	
	--// Re-parent after moving the parts
	--// Can help reduce networking
	for _, part in newParts do
		part.Parent = parent
	end
	
	table.clear(newParts)
	table.clear(cframeList)

	self.Cache = currentNode
end



--[==[
	Fetches a part from the part cache, and expands the part cache by 10 if the cache does not have any available parts.

	@returns BasePart
]==]
function PartCache.GetPart(self: PartCache): BasePart
	--// Make sure parts are available
	if self.CacheSize == 0 then
		--// Otherwise, Expand the cache, since we are above demand for parts needed
		self:Expand(self.ExpansionSize)
		warn(`No parts available in the cache! Creating {self.ExpansionSize} new part instance(s)... New size: {self.TotalSize} parts.`)
	end

	--// Now fetch the latest node + part from the cache
	local currentNode = self.Cache :: PartCacheLinkNode
	local part = currentNode.Value

	--// Remove node
	self.CacheSize -= 1
	self.Cache = currentNode.Next

	self.InUseSize += 1
	self.InUse[part] = true

	return part
end

--[==[
	Returns a part that is in use to the cache. Parts that are not in the cache, or are not in use, will throw an error.

	@param part BasePart - The part to return to the cache
]==]
function PartCache.ReturnPart(self: PartCache, part: BasePart)
	if self.CacheSize == self.TotalSize then return end
	
	--// Make sure the part is in use
	if not self.InUse[part] then
		--// Otherwise, throw an error
		error(`Part '{part:GetFullName()}' is not in use! Part was not returned to the cache.`)
		return
	end

	--// Insert node
	self.CacheSize += 1
	self.Cache = {
		Value = part,
		Next = self.Cache,
	}

	self.InUseSize -= 1
	self.InUse[part] = nil

	part.CFrame = CACHED_PART_CFRAME
	if not part.Anchored then
		part.Anchored = true
	end
end


--[==[
	Bulk fetches a amount of parts from the part cache.

	@param amount number - The amount of new parts to add to the cache
	
	@returns {BasePart}
]==]
function PartCache.GetParts(self: PartCache, amount: number): { BasePart }
	--// Make sure parts are available
	local partsAvailable = self.CacheSize - amount

	if partsAvailable < 0 then
		self:Expand(-partsAvailable)
		warn(`No parts available in the cache! Creating {-partsAvailable} new part instance(s)... New size: {self.TotalSize} parts.`)
	end

	local parts = {} :: { BasePart }

	local currentNode = self.Cache :: PartCacheLinkNode
	local inUse = self.InUse

	if currentNode then
		self.CacheSize -= amount
		self.InUseSize += amount

		for i = 1, amount do
			local nextNode = currentNode.Next
			local part = currentNode.Value

			--// Remove node
			self.Cache = nextNode
			inUse[part] = true

			table.insert(parts, part)

			currentNode = nextNode :: PartCacheLinkNode
		end
	end

	return parts
end

--[==[
	Bulk returns a list of parts that are in use to the cache.

	@param parts {BasePart} - The parts to return to the cache
]==]
function PartCache.ReturnParts(self: PartCache, parts: { BasePart })
	if self.CacheSize == self.TotalSize then return end
	
	local amount = #parts
	if amount == 0 then return end
	
	local returningParts = {} :: { BasePart }
	local partsNotInUse = {} :: { BasePart }
	local inUse = self.InUse
	local parent = self.CurrentCacheParent

	self.CacheSize += amount
	self.InUseSize -= amount

	for _, part in parts do
		--// Make sure the part is in use
		if not inUse[part] then
			table.insert(partsNotInUse, part)
			continue
		end

		--// Insert node
		self.Cache = {
			Value = part,
			Next = self.Cache,
		}

		inUse[part] = nil
		
		table.insert(returningParts, part)
		--part.CFrame = CACHED_PART_CFRAME
		--if not part.Anchored then
		--	part.Anchored = true
		--end
	end
	
	--// Move parts!
	workspace:BulkMoveTo(returningParts, table.create(#returningParts, CACHED_PART_CFRAME), Enum.BulkMoveMode.FireCFrameChanged)

	for _, part in returningParts do
		if part.Parent ~= parent then
			part.Parent = parent
		end
		if not part.Anchored then
			part.Anchored = true
		end
	end
	
	--// Warn about the unused parts!
	for _, part in partsNotInUse do
		warn(`Part '{part:GetFullName()}' is not in use! Part was not returned to the cache.`)
	end
	
	table.clear(returningParts)
	table.clear(partsNotInUse)
end


--[==[
	Sets a new parent for the cache to use, also moving all the existing parts in the cache under that new instance.

	@param Parent Instance - The new parent instance to use
]==]
function PartCache.SetCacheParent(self: PartCache, parent: Instance)
	self.CurrentCacheParent = parent

	--// Move parts in use
	for part in self.InUse do
		part.Parent = parent
	end

	--// Move parts in cache
	local currentNode = self.Cache
	while currentNode ~= nil do
		currentNode.Value.Parent = parent
		currentNode = currentNode.Next
	end
end

return PartCache