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

function AtlasSpecClass:AtlasSpec(tree, title)
	self.tree = tree
	self.title = title
	self:ResetNodes()
	self.modFlag = false
	return self
end

function AtlasSpecClass:ResetNodes()
	self.allocNodes = { }
	self.modFlag = true
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
			-- With `noGateways`, the link between the two ends of a gateway is not walked
			if isPathable(other) and dist[linkId] == nil and not (self.blockedNodes and self.blockedNodes[linkId])
				and not (self.noGateways and node.type == "Wormhole" and other.type == "Wormhole") then
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
	self.modFlag = true
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
	self.modFlag = true
	self:BuildPaths()
	return true
end

-- Allocated node ids, sorted, for saving
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

-- Replace the allocation with these node ids. Ids missing from the tree are skipped
-- and counted, so a loadout from another tree version still loads what it can.
function AtlasSpecClass:SetAllocIds(ids)
	self.allocNodes = { }
	local start = self.tree.nodes[self.tree.startNodeId]
	if start then
		self.allocNodes[start.id] = start
	end
	local skipped = 0
	for _, id in ipairs(ids) do
		local node = self.tree.nodes[id]
		if node and node.type ~= "Mastery" then
			self.allocNodes[id] = node
		else
			skipped = skipped + 1
		end
	end
	self:BuildPaths()
	return skipped
end

function AtlasSpecClass:Copy(title)
	local copy = new("AtlasSpec"):AtlasSpec(self.tree, title)
	copy:SetAllocIds(self:GetAllocIds())
	copy.modFlag = false
	return copy
end

-- Tree link in the official tree format (same layout as PassiveSpec:EncodeURL, version 6,
-- class and ascendancy 0, no cluster or mastery entries)
function AtlasSpecClass:EncodeURL(prefix)
	local a = { 0, 0, 0, 6, 0, 0 }
	local count = 0
	for _, id in ipairs(self:GetAllocIds()) do
		if id < 65536 and count < 255 then
			t_insert(a, math.floor(id / 256))
			t_insert(a, id % 256)
			count = count + 1
		end
	end
	t_insert(a, 7, count)
	t_insert(a, 0)
	t_insert(a, 0)
	return (prefix or "")..common.base64.encode(string.char(unpack(a))):gsub("+", "-"):gsub("/", "_")
end

-- The tree code inside a link or a bare code. Links put it in different places: the official site at
-- the end (.../fullscreen-atlas-skill-tree/<code>), poe.ninja after /tree/ with an optional /full
-- after it (.../atlas-trees/<league>/tree/<code>/full), poeplanner.com after /atlas-tree/.
-- Query and fragment are dropped, then the longest path part made of base64url characters is the code.
local function treeCode(url)
	local path = url:gsub("%s", ""):gsub("[?#].*$", "")
	local code = ""
	for part in path:gmatch("[^/]+") do
		if #part > #code and part:match("^[%w%-_]+=*$") then
			code = part
		end
	end
	return code
end

-- Read a tree link. Returns an error message, or nil and the number of skipped ids.
function AtlasSpecClass:DecodeURL(url)
	local code = treeCode(url)
	local b = common.base64.decode(code:gsub("-", "+"):gsub("_", "/"))
	if not b or #b < 6 then
		return "Invalid atlas tree link (unrecognised format)"
	end
	local ids = { }
	local ver = b:byte(1) * 16777216 + b:byte(2) * 65536 + b:byte(3) * 256 + b:byte(4)
	-- poeplanner.com: a 5 byte header, the node count as a little endian 16 bit number, then
	-- little endian 16 bit node ids, then extra sections that are not read here.
	local ppCount = #b >= 7 and (b:byte(6) + b:byte(7) * 256)
	if (url:match("poeplanner%.com") or ver > 6) and ppCount and 7 + ppCount * 2 <= #b then
		for i = 8, 7 + ppCount * 2, 2 do
			t_insert(ids, b:byte(i) + b:byte(i + 1) * 256)
		end
	elseif ver > 6 then
		return "Invalid atlas tree link (unknown version number '"..ver.."')"
	else
		local nodesStart = ver >= 4 and 8 or 7
		local nodesEnd = ver >= 5 and 7 + (b:byte(7) * 2) or #b
		for i = nodesStart, nodesEnd - 1, 2 do
			t_insert(ids, b:byte(i) * 256 + b:byte(i + 1))
		end
	end
	local skipped = self:SetAllocIds(ids)
	self.modFlag = true
	return nil, skipped
end

-- Allocate every node in `nodes`, nearest first: each round takes the unallocated target with
-- the shortest path from the current tree, allocates that path, and measures again, so later
-- targets can route through nodes taken for earlier ones.
-- `blocked` (optional, id set): nodes the paths must not pass through.
-- `noGateways` (optional): paths may not jump from one end of a gateway to the other.
-- Returns the points added and the number of targets that have no path.
function AtlasSpecClass:FillNodes(nodes, blocked, noGateways)
	local limited = (blocked and next(blocked)) or noGateways
	if limited then
		self.blockedNodes = (blocked and next(blocked)) and blocked or nil
		self.noGateways = noGateways or nil
		self:BuildPaths()
	end
	local pending = { }
	for _, node in ipairs(nodes) do
		if not self.allocNodes[node.id] then
			pending[node.id] = node
		end
	end
	local before = self:CountAllocNodes()
	while true do
		local best, bestDist
		for id, node in pairs(pending) do
			if self.allocNodes[id] then
				pending[id] = nil
			else
				local dist = self.dist[id]
				if dist and (not bestDist or dist < bestDist or (dist == bestDist and id < best.id)) then
					best, bestDist = node, dist
				end
			end
		end
		if not best then
			break
		end
		self:AllocNode(best)
		pending[best.id] = nil
	end
	if limited then
		self.blockedNodes, self.noGateways = nil, nil
		self:BuildPaths()
	end
	local unreachable = 0
	for id in pairs(pending) do
		if not self.allocNodes[id] then
			unreachable = unreachable + 1
		end
	end
	return self:CountAllocNodes() - before, unreachable
end

-- Remove every node in `nodes` with the nodes that hang off it, as removing it on the tree does.
-- With `trim`, also remove the dead-end path that only led to it: walk back while the next node
-- is a plain node left with one allocated neighbour, stopping at the start, a Notable or
-- Keystone, or a node in `keep` (id set).
-- Returns the points freed.
function AtlasSpecClass:RemoveNodes(nodes, keep, trim)
	keep = keep or { }
	local nodeMap = self.tree.nodes
	local startId = self.tree.startNodeId
	local before = self:CountAllocNodes()
	local function allocatedNeighbours(node)
		local list = { }
		for _, linkId in ipairs(node.linkedId) do
			if self.allocNodes[linkId] then
				t_insert(list, nodeMap[linkId])
			end
		end
		return list
	end
	local function trimmable(node)
		return node.id ~= startId and not keep[node.id] and node.type ~= "Notable" and node.type ~= "Keystone"
			and #allocatedNeighbours(node) <= 1
	end
	for _, node in ipairs(nodes) do
		if self.allocNodes[node.id] and node.id ~= startId then
			local edge = allocatedNeighbours(node)
			for _, dep in ipairs(self:GetDependents(node)) do
				self.allocNodes[dep.id] = nil
			end
			for _, other in ipairs(trim and edge or { }) do
				local cur = other
				while cur and self.allocNodes[cur.id] and trimmable(cur) do
					local nextList = allocatedNeighbours(cur)
					self.allocNodes[cur.id] = nil
					cur = nextList[1]
				end
			end
			self:BuildPaths()
		end
	end
	local freed = before - self:CountAllocNodes()
	if freed > 0 then
		self.modFlag = true
	end
	return freed
end
