-- Path of Building (pob-atlas fork)
--
-- Class: Atlas Spec
-- One allocation of the atlas passive tree: allocated nodes, shortest paths from the
-- allocated set, allocation along a path and removal of nodes cut off from the start.
--
local pairs = pairs
local ipairs = ipairs
local t_insert = table.insert

---@class AtlasSpec
local AtlasSpecClass = newClass("AtlasSpec")

function AtlasSpecClass:AtlasSpec(tree)
	self.tree = tree
	self:ResetNodes()
	return self
end

function AtlasSpecClass:ResetNodes()
	self.allocNodes = { }
	local start = self.tree.nodes[self.tree.startNodeId]
	if start then
		self.allocNodes[start.id] = start
	end
	self:BuildPaths()
end

-- Nodes that can be walked through when allocating
local function isPathable(node)
	return node and node.type ~= "Mastery"
end

-- Multi-source breadth-first search from every allocated node
function AtlasSpecClass:BuildPaths()
	local nodes = self.tree.nodes
	local dist, prev = { }, { }
	local queue, head = { }, 1
	for id, node in pairs(self.allocNodes) do
		dist[id] = 0
		t_insert(queue, node)
	end
	while queue[head] do
		local node = queue[head]
		head = head + 1
		for _, linkId in ipairs(node.linkedId) do
			local other = nodes[linkId]
			if isPathable(other) and dist[linkId] == nil then
				dist[linkId] = dist[node.id] + 1
				prev[linkId] = node.id
				t_insert(queue, other)
			end
		end
	end
	self.dist, self.prev = dist, prev
	self.depCache = { }
	self.summary = nil
	self.summaryVersion = (self.summaryVersion or 0) + 1
end

-- Unallocated nodes that allocating this node would take, from the node back towards the tree
function AtlasSpecClass:GetPath(node)
	if not node or self.allocNodes[node.id] or not self.dist[node.id] then
		return nil
	end
	local path = { }
	local id = node.id
	while id and not self.allocNodes[id] do
		t_insert(path, self.tree.nodes[id])
		id = self.prev[id]
	end
	return path
end

function AtlasSpecClass:CountAllocNodes()
	local count = 0
	for id in pairs(self.allocNodes) do
		if id ~= self.tree.startNodeId then
			count = count + 1
		end
	end
	return count
end

function AtlasSpecClass:AllocNode(node)
	local path = self:GetPath(node)
	if not path then
		return false
	end
	for _, pathNode in ipairs(path) do
		self.allocNodes[pathNode.id] = pathNode
	end
	self:BuildPaths()
	return true
end

-- Allocated nodes still reachable from the start when `without` is removed
function AtlasSpecClass:ReachableWithout(without)
	local nodes = self.tree.nodes
	local reached = { }
	local startId = self.tree.startNodeId
	if not self.allocNodes[startId] or startId == without then
		return reached
	end
	local queue, head = { nodes[startId] }, 1
	reached[startId] = true
	while queue[head] do
		local node = queue[head]
		head = head + 1
		for _, linkId in ipairs(node.linkedId) do
			if linkId ~= without and self.allocNodes[linkId] and not reached[linkId] then
				reached[linkId] = true
				t_insert(queue, nodes[linkId])
			end
		end
	end
	return reached
end

-- Allocated nodes that would be removed along with this node (the node itself included)
function AtlasSpecClass:GetDependents(node)
	if not node or not self.allocNodes[node.id] or node.id == self.tree.startNodeId then
		return { }
	end
	if self.depCache[node.id] then
		return self.depCache[node.id]
	end
	local reached = self:ReachableWithout(node.id)
	local deps = { }
	for id, allocNode in pairs(self.allocNodes) do
		if not reached[id] then
			t_insert(deps, allocNode)
		end
	end
	self.depCache[node.id] = deps
	return deps
end

function AtlasSpecClass:DeallocNode(node)
	if not node or not self.allocNodes[node.id] or node.id == self.tree.startNodeId then
		return false
	end
	for _, dep in ipairs(self:GetDependents(node)) do
		self.allocNodes[dep.id] = nil
	end
	self:BuildPaths()
	return true
end

-- Allocated node ids, sorted, for saving (phase 3)
function AtlasSpecClass:GetAllocIds()
	local ids = { }
	for id in pairs(self.allocNodes) do
		if id ~= self.tree.startNodeId then
			t_insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

-- Sum of every stat line on the allocated nodes. Lines that differ only by their numbers
-- are merged and their numbers added; a line with no number shows a count when repeated.
-- Returns { { text = "...", count = n }, ... } sorted by text, and the keystone names.
function AtlasSpecClass:GetStatSummary()
	if self.summary then
		return self.summary, self.summaryKeystones
	end
	local byKey, order, keystones = { }, { }, { }
	local ids = self:GetAllocIds()
	for _, id in ipairs(ids) do
		local node = self.tree.nodes[id]
		if node.type == "Keystone" then
			t_insert(keystones, node.dn)
		end
		for _, line in ipairs(node.sd or { }) do
			line = line:gsub("%s*\n%s*", " ")
			local nums = { }
			local key = line:gsub("%d+%.?%d*", function(num)
				t_insert(nums, tonumber(num))
				return "#"
			end)
			local entry = byKey[key]
			if not entry then
				entry = { key = key, nums = { }, count = 0 }
				byKey[key] = entry
				t_insert(order, entry)
			end
			entry.count = entry.count + 1
			for i, num in ipairs(nums) do
				entry.nums[i] = (entry.nums[i] or 0) + num
			end
		end
	end
	local summary = { }
	for _, entry in ipairs(order) do
		local i = 0
		local text = entry.key:gsub("#", function()
			i = i + 1
			local num = entry.nums[i]
			return num == math.floor(num) and string.format("%d", num) or string.format("%g", num)
		end)
		t_insert(summary, { text = text, count = (#entry.nums == 0 and entry.count > 1) and entry.count or nil })
	end
	table.sort(summary, function(a, b) return a.text:lower() < b.text:lower() end)
	table.sort(keystones)
	self.summary, self.summaryKeystones = summary, keystones
	return summary, keystones
end
