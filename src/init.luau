--[==[
	Author: 8ch99
	File: PartCache.luau
	Date written: 20th November 2025
	Last edited: 20th November 2025

	PartCache module that uses LinkedLists and has method parity with Xan_TheDragon's PartCache module
	The only different method is :Destroy() instead of :Dispose(), but that shouldn't be an issue
]==]

--[==[

MIT License

Copyright (c) 2025 8ch99

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

local CACHED_PART_CFRAME: CFrame = CFrame.new(0, 1e7, 0)

--// @class PartCache

local PartCache = {}
PartCache.__index = PartCache
PartCache.__type = "PartCache"

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
	Parent: Instance,
	ExpansionSize: number
}, PartCache))

--[==[
	Creates a new PartCache with the given template part, part count, and parent container for the cache to use.

	@param Template BasePart - The template base part to use, this is the part that will be used in the cache
	@param PresetParts number? - The amount of parts you want to pre-create in the cache
	@param Parent Instance? - The parent container you want to use for the cache

	@return PartCache
]==]
function PartCache.new(Template: BasePart, PresetParts: number?, Parent: Instance?): PartCache
	assert(Template and typeof(Template) == "Instance" and Template:IsA("BasePart"), "Template part is not a BasePart instance!")

	local RealPresetParts: number = 5
	local RealParent: Instance = workspace

	if PresetParts ~= nil then
		assert(type(PresetParts) == "number", "PresetParts must be provided!")
		assert(tostring(math.floor(PresetParts)) == tostring(PresetParts), "PresetParts must be an int!")
		RealPresetParts = PresetParts
	end

	if Parent ~= nil then
		assert(typeof(Parent) == "Instance", "Valid parent must be provided!")
		RealParent = Parent
	end

	local self: PartCache = setmetatable({
		Cache = nil,
		InUse = {} :: { [BasePart]: boolean },
		CacheSize = 0,
		InUseSize = 0,
		TotalSize = 0,

		Template = Template:Clone(),
		Parent = RealParent,
		ExpansionSize = 10,
	}, PartCache)

	for _ = 1, RealPresetParts do
		self:_createPart()
	end

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
	for Part: BasePart in self.InUse do
		Part:Destroy()
	end

	table.clear(self.InUse)

	--// Destroy parts in cache
	local CurrentCachedNode: PartCacheLinkNode? = self.Cache
	self.Cache = nil --// Remove from object

	while CurrentCachedNode ~= nil do
		CurrentCachedNode.Value:Destroy()
		CurrentCachedNode = CurrentCachedNode.Next
	end

	--// Destroy the rest of the object
	table.clear(self :: any)
	setmetatable(self :: any, nil)
end

--// Private methods

function PartCache._createPart(self: PartCache)
	local CurrentNode: PartCacheLinkNode? = self.Cache
	local Part: BasePart = self.Template:Clone()

	self.TotalSize += 1

	--// Insert node
	self.CacheSize += 1
	self.Cache = {
		Value = Part,
		Next = CurrentNode,
	}

	Part.CFrame = CACHED_PART_CFRAME
	Part.Parent = self.Parent

	return Part
end

--// Public methods

--[==[
	Fetches a part from the part cache, and expands the part cache by 10 if the cache does not have any available parts.

	@return BasePart
]==]
function PartCache.GetPart(self: PartCache): BasePart
	--// Make sure parts are available
	if self.CacheSize == 0 then
		--// Otherwise, Expand the cache, since we are above demand for parts needed
		warn(`No parts available in the cache! Creating {self.ExpansionSize} new part instance(s)... New size: {self.TotalSize + self.ExpansionSize} parts.`)

		for _ = 1, self.ExpansionSize do
			self:_createPart()
		end
	end

	--// Now fetch the latest node + part from the cache
	local CurrentNode: PartCacheLinkNode = self.Cache :: PartCacheLinkNode
	local Part: BasePart = CurrentNode.Value

	--// Remove node
	self.CacheSize -= 1
	self.Cache = CurrentNode.Next

	self.InUseSize += 1
	self.InUse[Part] = true

	return Part
end

--[==[
	Returns a part that is in use to the cache. Parts that are not in the cache, or are not in use, will throw an error.

	@param Part BasePart - The part to return to the cache
]==]
function PartCache.ReturnPart(self: PartCache, Part: BasePart)
	--// Make sure the part is in use
	if not self.InUse[Part] then
		--// Otherwise, throw an error
		--// I would use an assertion but i dont wanna call :GetFullName() every call
		--// I care too much sometimes about optimization lol
		error(`Part {Part:GetFullName()} is not in use! Part was not returned to the cache.`)
		return
	end

	--// Insert node
	self.CacheSize += 1
	self.Cache = {
		Value = Part,
		Next = self.Cache,
	}

	self.InUseSize -= 1
	self.InUse[Part] = nil

	Part.CFrame = CACHED_PART_CFRAME
end

--[==[
	Sets a new parent for the cache to use, also moving all the existing parts in the cache under that new instance.

	@param Parent Instance - The new parent instance to use
]==]
function PartCache.SetCacheParent(self: PartCache, Parent: Instance)
	self.Parent = Parent

	--// Move parts in use
	for Part: BasePart in self.InUse do
		Part.Parent = Parent
	end

	--// Move parts in cache
	local CurrentCachedNode: PartCacheLinkNode? = self.Cache

	while CurrentCachedNode ~= nil do
		CurrentCachedNode.Value.Parent = Parent
		CurrentCachedNode = CurrentCachedNode.Next
	end
end

--[==[
	Expands the size of the part cache by the given amount.

	@param Amount number - The amount of new parts to add to the cache
]==]
function PartCache.Expand(self: PartCache, Amount: number)
	for _ = 1, Amount do
		self:_createPart()
	end
end

return PartCache