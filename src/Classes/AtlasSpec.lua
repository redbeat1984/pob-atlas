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
