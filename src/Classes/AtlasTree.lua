-- Path of Building (pob-atlas fork)
--
-- Class: Atlas Tree
-- Atlas passive tree data: loads GGG's atlas export (prepared by prepare_atlas_330.py into
-- TreeData/<version>/tree.lua), builds the sprite map, node positions and connector lines.
-- Reuses the geometry helpers of PassiveTree (CalcOrbitAngles, BuildConnector, BuildArc, LoadImage).
--
local pairs = pairs
local ipairs = ipairs
local t_insert = table.insert
local m_min = math.min
local m_sin = math.sin
local m_cos = math.cos

---@class AtlasTree
local AtlasTreeClass = newClass("AtlasTree")

-- Borrow the geometry helpers from PassiveTree. PoB's class system would require running the
-- PassiveTree constructor if AtlasTree inherited from it, so the methods are copied instead.
if not common.classes.PassiveTree then
	LoadModule("Classes/PassiveTree")
end
for _, method in ipairs({ "CalcOrbitAngles", "BuildConnector", "BuildArc", "LoadImage" }) do
	AtlasTreeClass[method] = common.classes.PassiveTree[method]
end

-- Sprite types per node type: { allocated, unallocated }
local nodeSpriteTypes = {
	Normal = { "normalActive", "normalInactive" },
	Notable = { "notableActive", "notableInactive" },
	Keystone = { "keystoneActive", "keystoneInactive" },
	Wormhole = { "wormholeActive", "wormholeInactive" },
}

-- Frame names per node type, from the atlas frame sheet
local frameNames = {
	Normal = { alloc = "PSSkillFrameActive", path = "PSSkillFrameHighlighted", unalloc = "PSSkillFrame" },
	Notable = { alloc = "NotableFrameAllocated", path = "NotableFrameCanAllocate", unalloc = "NotableFrameUnallocated" },
	Keystone = { alloc = "KeystoneFrameAllocated", path = "KeystoneFrameCanAllocate", unalloc = "KeystoneFrameUnallocated" },
	Wormhole = { alloc = "WormholeFrameAllocated", path = "WormholeFrameCanAllocate", unalloc = "WormholeFrameUnallocated" },
}

function AtlasTreeClass:AtlasTree(treeVersion)
	self.treeVersion = treeVersion
	ConPrintf("Loading atlas tree data for version '%s'...", treeVersion)
	local treeFile = assert(io.open("TreeData/"..treeVersion.."/tree.lua", "r"), "Missing atlas tree data: TreeData/"..treeVersion.."/tree.lua")
	local treeText = treeFile:read("*a")
	treeFile:close()
	for k, v in pairs(assert(loadstring(treeText))()) do
		self[k] = v
	end

	self.size = m_min(self.max_x - self.min_x, self.max_y - self.min_y) * 1.1
	self.centerX = (self.min_x + self.max_x) / 2
	self.centerY = (self.min_y + self.max_y) / 2
	self.totalPoints = self.points and self.points.totalPoints or 0

	self.skillsPerOrbit = self.constants.skillsPerOrbit
	self.orbitRadii = self.constants.orbitRadii
	self.orbitAnglesByOrbit = { }
	for orbit, skillsInOrbit in ipairs(self.skillsPerOrbit) do
		self.orbitAnglesByOrbit[orbit] = self:CalcOrbitAngles(skillsInOrbit)
	end

	-- Sprite sheets: each sprite type holds one sheet (one zoom level kept by the prep script)
	self.spriteMap = { }
	self.assets = { }
	local sheets = { }
	for spriteType, sheetData in pairs(self.sprites) do
		local sheet = sheets[sheetData.filename]
		if not sheet then
			sheet = { }
			self:LoadImage(sheetData.filename, sheetData.filename, sheet, "CLAMP")
			sheets[sheetData.filename] = sheet
		end
		local sheetW, sheetH = sheetData.w or sheet.width, sheetData.h or sheet.height
		for name, c in pairs(sheetData.coords) do
			local entry = {
				handle = sheet.handle,
				width = c.w,
				height = c.h,
				[1] = c.x / sheetW,
				[2] = c.y / sheetH,
				[3] = (c.x + c.w) / sheetW,
				[4] = (c.y + c.h) / sheetH,
			}
			self.spriteMap[name] = self.spriteMap[name] or { }
			self.spriteMap[name][spriteType] = entry
			if not self.assets[name] then
				self.assets[name] = entry
			end
		end
	end

	-- Node overlays: the hover radius follows the frame art size
	self.nodeOverlay = { }
	for nodeType, names in pairs(frameNames) do
		local art = self.assets[names.unalloc]
		local overlay = { alloc = names.alloc, path = names.path, unalloc = names.unalloc, artWidth = art and art.width or 40 }
		overlay.size = overlay.artWidth * 1.33
		overlay.rsq = overlay.size * overlay.size
		self.nodeOverlay[nodeType] = overlay
	end

	-- Start node: the root points at it
	local root = self.nodes.root
	self.nodes.root = nil
	for _, id in pairs(root and root.out or { }) do
		self.startNodeId = tonumber(id)
	end

	-- Nodes
	local nodeMap = { }
	for _, node in pairs(self.nodes) do
		node.id = node.skill
		node.g = node.group
		node.o = node.orbit
		node.oidx = node.orbitIndex
		node.dn = node.name
		node.sd = node.stats or { }
		node.linkedId = { }
		nodeMap[node.id] = node

		if node.id == self.startNodeId then
			node.type = "Start"
		elseif node.isMastery then
			node.type = "Mastery"
		elseif node.isWormhole then
			node.type = "Wormhole"
		elseif node.isKeystone then
			node.type = "Keystone"
		elseif node.isNotable then
			node.type = "Notable"
		else
			node.type = "Normal"
		end

		node.group = self.groups[node.g]
		if node.type == "Mastery" then
			local sprites = self.spriteMap[node.icon] or { }
			node.iconArt = { alloc = sprites.mastery, unalloc = sprites.mastery }
			local art = sprites.mastery
			node.size = art and art.width * 1.33 or 60
		elseif node.type == "Start" then
			local art = self.assets.AtlasPassiveSkillScreenStart
			node.iconArt = { alloc = art, unalloc = art }
			node.size = art and art.width * 1.33 or 100
		else
			local sprites = node.type == "Wormhole" and (self.spriteMap.Wormhole or { }) or (self.spriteMap[node.icon] or { })
			local types = nodeSpriteTypes[node.type]
			node.iconArt = { alloc = sprites[types[1]], unalloc = sprites[types[2]] or sprites[types[1]] }
			node.overlay = self.nodeOverlay[node.type]
			node.size = node.overlay.size
		end
		node.rsq = node.size * node.size

		if node.group then
			node.angle = self.orbitAnglesByOrbit[node.o + 1][node.oidx + 1]
			local orbitRadius = self.orbitRadii[node.o + 1]
			node.x = node.group.x + m_sin(node.angle) * orbitRadius
			node.y = node.group.y - m_cos(node.angle) * orbitRadius
		end
	end
	self.nodes = nodeMap

	-- Links and connector lines
	self.connectors = { }
	for _, node in pairs(self.nodes) do
		for _, otherId in pairs(node.out or { }) do
			otherId = tonumber(otherId)
			local other = nodeMap[otherId]
			if other then
				t_insert(node.linkedId, otherId)
				t_insert(other.linkedId, node.id)
				-- No line between the two ends of a gateway, or to a mastery
				if not (node.type == "Wormhole" and other.type == "Wormhole")
					and node.type ~= "Mastery" and other.type ~= "Mastery"
					and node.group and other.group then
					for _, connector in ipairs(self:BuildConnector(node, other)) do
						t_insert(self.connectors, connector)
					end
				end
			end
		end
		for _, otherId in pairs(node["in"] or { }) do
			otherId = tonumber(otherId)
			if nodeMap[otherId] then
				t_insert(node.linkedId, otherId)
				t_insert(nodeMap[otherId].linkedId, node.id)
			end
		end
	end
	-- Drop duplicate links (an edge can appear in both "out" lists)
	for _, node in pairs(self.nodes) do
		local seen, list = { }, { }
		for _, id in ipairs(node.linkedId) do
			if not seen[id] then
				seen[id] = true
				t_insert(list, id)
			end
		end
		node.linkedId = list
	end

	return self
end

-- Atlas stats are shown as text; they are not parsed into character mods
function AtlasTreeClass:ProcessStats(node)
end
