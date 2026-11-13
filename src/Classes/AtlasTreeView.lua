-- Path of Building (pob-atlas fork)
--
-- Class: Atlas Tree View
-- Draws the atlas passive tree and handles pan, zoom, hover and click allocation.
-- Modelled on PassiveTreeView (same coordinate transform, connector quads and asset drawing).
--
local pairs = pairs
local ipairs = ipairs
local m_min = math.min
local m_max = math.max
local m_floor = math.floor
local m_abs = math.abs

---@class AtlasTreeView
local AtlasTreeViewClass = newClass("AtlasTreeView")

function AtlasTreeViewClass:AtlasTreeView()
	self.zoomLevel = 3
	self.zoom = 1.2 ^ self.zoomLevel
	self.zoomX = 0
	self.zoomY = 0
	self.searchStr = ""
	self.tooltip = new("Tooltip"):Tooltip()
	self.highlightRing = NewImageHandle()
	self.highlightRing:Load("Assets/small_ring.png", "CLAMP")
	return self
end

-- Same asset drawing as PassiveTreeView:DrawAsset
function AtlasTreeViewClass:DrawAsset(data, x, y, scale, isHalf)
	if not data or not data.handle then
		return
	end
	if data.width == 0 then
		data.width, data.height = data.handle:ImageSize()
		if data.width == 0 then
			return
		end
	end
	local width = data.width * scale * 1.33
	local height = data.height * scale * 1.33
	if isHalf then
		DrawImage(data.handle, x - width, y - height * 2, width * 2, height * 2, data[1], data[2], data[3], data[4])
		DrawImage(data.handle, x - width, y, width * 2, height * 2, data[1], data[4], data[3], data[2])
	else
		DrawImage(data.handle, x - width, y - height, width * 2, height * 2, data[1], data[2], data[3], data[4])
	end
end

function AtlasTreeViewClass:Zoom(level, viewPort)
	self.zoomLevel = m_max(0, m_min(12, self.zoomLevel + level))
	local oldZoom = self.zoom
	self.zoom = 1.2 ^ self.zoomLevel
	local factor = self.zoom / oldZoom
	local cursorX, cursorY = GetCursorPos()
	local relX = cursorX - viewPort.x - viewPort.width/2
	local relY = cursorY - viewPort.y - viewPort.height/2
	self.zoomX = relX + (self.zoomX - relX) * factor
	self.zoomY = relY + (self.zoomY - relY) * factor
end

function AtlasTreeViewClass:DoesNodeMatchSearch(node)
	local search = self.searchStr:lower()
	if search == "" or not node.dn then
		return false
	end
	if node.dn:lower():find(search, 1, true) then
		return true
	end
	for _, line in ipairs(node.sd or { }) do
		if line:lower():find(search, 1, true) then
			return true
		end
	end
	for _, effect in ipairs(node.variantEffects or { }) do
		for _, line in ipairs(effect.stats or { }) do
			if line:lower():find(search, 1, true) then
				return true
			end
		end
	end
	return false
end

function AtlasTreeViewClass:AddNodeTooltip(tooltip, node, spec)
	tooltip:Clear()
	local nameColor = node.type == "Keystone" and colorCodes.UNIQUE or node.type == "Notable" and colorCodes.RARE or node.type == "Wormhole" and colorCodes.CRAFTED or colorCodes.NORMAL
	tooltip:AddLine(20, nameColor..node.dn)
	tooltip:AddSeparator(10)
	for _, line in ipairs(node.sd or { }) do
		for subLine in line:gmatch("[^\n]+") do
			tooltip:AddLine(16, colorCodes.MAGIC..subLine)
		end
	end
	if node.variantEffects and #node.variantEffects > 0 then
		tooltip:AddLine(16, "^7Choose one effect:")
		for i, effect in ipairs(node.variantEffects) do
			for _, line in ipairs(effect.stats or { }) do
				local text = line:gsub("\n", " ")
				tooltip:AddLine(16, colorCodes.MAGIC..i..": "..text)
			end
		end
	end
	for _, line in ipairs(node.reminderText or { }) do
		tooltip:AddLine(14, colorCodes.TIP..line:gsub("\n", " "))
	end
	if node.flavourText and #node.flavourText > 0 then
		tooltip:AddSeparator(10)
		for _, line in ipairs(node.flavourText) do
			tooltip:AddLine(14, colorCodes.UNIQUE..line)
		end
	end
	if node.type ~= "Mastery" and node.type ~= "Start" then
		tooltip:AddSeparator(10)
		if spec.allocNodes[node.id] then
			local deps = spec:GetDependents(node)
			tooltip:AddLine(14, "^7Click to remove: frees "..#deps.." point"..(#deps == 1 and "" or "s"))
		else
			local path = spec:GetPath(node)
			if path then
				tooltip:AddLine(14, "^7Click to allocate: uses "..#path.." point"..(#path == 1 and "" or "s"))
			end
		end
	end
end

function AtlasTreeViewClass:Draw(spec, viewPort, inputEvents)
	local tree = spec.tree
	local cursorX, cursorY = GetCursorPos()
	local mOver = cursorX >= viewPort.x and cursorX < viewPort.x + viewPort.width and cursorY >= viewPort.y and cursorY < viewPort.y + viewPort.height

	-- Input
	local treeClick
	for id, event in ipairs(inputEvents) do
		if event.type == "KeyDown" then
			if event.key == "LEFTBUTTON" and mOver then
				self.dragX, self.dragY = cursorX, cursorY
			elseif event.key == "PAGEUP" then
				self:Zoom(IsKeyDown("SHIFT") and 3 or 1, viewPort)
			elseif event.key == "PAGEDOWN" then
				self:Zoom(IsKeyDown("SHIFT") and -3 or -1, viewPort)
			end
		elseif event.type == "KeyUp" then
			if event.key == "LEFTBUTTON" then
				if self.dragX and not self.dragging then
					treeClick = "LEFT"
				end
			elseif mOver then
				if event.key == "RIGHTBUTTON" then
					treeClick = "RIGHT"
				elseif event.key == "WHEELUP" then
					self:Zoom(IsKeyDown("SHIFT") and 3 or 1, viewPort)
				elseif event.key == "WHEELDOWN" then
					self:Zoom(IsKeyDown("SHIFT") and -3 or -1, viewPort)
				end
			end
		end
	end
	if not IsKeyDown("LEFTBUTTON") then
		self.dragging = false
		self.dragX, self.dragY = nil, nil
	end
	if self.dragX then
		if not self.dragging and (m_abs(cursorX - self.dragX) > 5 or m_abs(cursorY - self.dragY) > 5) then
			self.dragging = true
		end
		if self.dragging then
			self.zoomX = self.zoomX + cursorX - self.dragX
			self.zoomY = self.zoomY + cursorY - self.dragY
			self.dragX, self.dragY = cursorX, cursorY
		end
	end
	if treeClick and IsKeyDown("CTRL") then
		self:Zoom(treeClick == "RIGHT" and -2 or 2, viewPort)
		treeClick = nil
	end
	local clampFactor = self.zoom * 2 / 3
	self.zoomX = m_min(m_max(self.zoomX, -viewPort.width * clampFactor), viewPort.width * clampFactor)
	self.zoomY = m_min(m_max(self.zoomY, -viewPort.height * clampFactor), viewPort.height * clampFactor)

	-- Tree space <-> screen space (centred on the middle of the atlas tree)
	local scale = m_min(viewPort.width, viewPort.height) / tree.size * self.zoom
	local offsetX = self.zoomX + viewPort.x + viewPort.width/2 - tree.centerX * scale
	local offsetY = self.zoomY + viewPort.y + viewPort.height/2 - tree.centerY * scale
	local function treeToScreen(x, y)
		return x * scale + offsetX, y * scale + offsetY
	end
	local function screenToTree(x, y)
		return (x - offsetX) / scale, (y - offsetY) / scale
	end

	-- Hover
	local hoverNode
	if mOver and not main.popups[1] then
		local curX, curY = screenToTree(cursorX, cursorY)
		for _, node in pairs(tree.nodes) do
			if node.x and node.type ~= "Mastery" and node.type ~= "Start" then
				local vX, vY = curX - node.x, curY - node.y
				if vX * vX + vY * vY <= node.rsq then
					hoverNode = node
					break
				end
			end
		end
	end
	self.hoverNode = hoverNode
	local hoverPath, hoverDep = { }, { }
	if hoverNode then
		if spec.allocNodes[hoverNode.id] then
			for _, dep in ipairs(spec:GetDependents(hoverNode)) do
				hoverDep[dep.id] = true
			end
		else
			for _, pathNode in ipairs(spec:GetPath(hoverNode) or { }) do
				hoverPath[pathNode.id] = true
			end
		end
	end

	-- Click
	if treeClick == "LEFT" and hoverNode then
		if spec.allocNodes[hoverNode.id] then
			spec:DeallocNode(hoverNode)
		else
			spec:AllocNode(hoverNode)
		end
		self.tooltip.updateParams = nil
		if self.onChange then
			self.onChange()
		end
	end

	-- Background
	SetDrawLayer(nil, 0)
	SetDrawColor(0.02, 0.02, 0.03)
	DrawImage(nil, viewPort.x, viewPort.y, viewPort.width, viewPort.height)
	SetDrawColor(1, 1, 1)
	local start = tree.nodes[tree.startNodeId]
	if tree.assets.AtlasPassiveBackground and start then
		local bgX, bgY = treeToScreen(start.x, start.y)
		self:DrawAsset(tree.assets.AtlasPassiveBackground, bgX, bgY, scale)
	end

	-- Group backgrounds
	SetDrawLayer(nil, 10)
	for _, group in pairs(tree.groups) do
		local bg = group.background
		if bg and bg.image then
			local scrX, scrY = treeToScreen(group.x + (bg.offsetX or 0), group.y + (bg.offsetY or 0))
			local art = tree.assets[bg.image]
			self:DrawAsset(art, scrX, scrY, scale, bg.image == "PSGroupBackground3" or bg.isHalfImage)
		end
	end

	-- Connector lines
	local function isActive(id)
		return spec.allocNodes[id] ~= nil
	end
	local function isOnPath(id)
		return spec.allocNodes[id] ~= nil or hoverPath[id]
	end
	SetDrawLayer(nil, 20)
	for _, connector in ipairs(tree.connectors) do
		local id1, id2 = connector.nodeId1, connector.nodeId2
		local state = "Normal"
		if isActive(id1) and isActive(id2) then
			state = "Active"
		elseif isOnPath(id1) and isOnPath(id2) then
			state = "Intermediate"
		end
		if hoverDep[id1] and hoverDep[id2] then
			SetDrawColor(1, 0, 0)
		else
			SetDrawColor(1, 1, 1)
		end
		local vert = connector.vert[state]
		local c = connector.c
		c[1], c[2] = treeToScreen(vert[1], vert[2])
		c[3], c[4] = treeToScreen(vert[3], vert[4])
		c[5], c[6] = treeToScreen(vert[5], vert[6])
		c[7], c[8] = treeToScreen(vert[7], vert[8])
		local asset = tree.assets[connector.type..state]
		if asset then
			local left, top = asset[1] or 0, asset[2] or 0
			local width, height = (asset[3] or 1) - left, (asset[4] or 1) - top
			DrawImageQuad(asset.handle,
				c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8],
				left + c[9] * width, top + c[10] * height,
				left + c[11] * width, top + c[12] * height,
				left + c[13] * width, top + c[14] * height,
				left + c[15] * width, top + c[16] * height)
		end
	end
	SetDrawColor(1, 1, 1)

	-- Nodes
	for _, node in pairs(tree.nodes) do
		if node.x then
			local scrX, scrY = treeToScreen(node.x, node.y)
			local isAlloc = spec.allocNodes[node.id] ~= nil
			local onPath = hoverPath[node.id]
			local canAlloc = spec.dist[node.id] == 1
			if node.type == "Mastery" then
				SetDrawLayer(nil, 15)
				SetDrawColor(0.7, 0.7, 0.7)
				self:DrawAsset(node.iconArt.unalloc, scrX, scrY, scale)
			elseif node.type == "Start" then
				SetDrawLayer(nil, 25)
				SetDrawColor(1, 1, 1)
				self:DrawAsset(node.iconArt.alloc, scrX, scrY, scale)
			else
				SetDrawLayer(nil, 25)
				if hoverDep[node.id] then
					SetDrawColor(1, 0.4, 0.4)
				else
					SetDrawColor(1, 1, 1)
				end
				self:DrawAsset(isAlloc and node.iconArt.alloc or node.iconArt.unalloc, scrX, scrY, scale)
				local overlay = node.overlay
				if overlay then
					local frame = isAlloc and overlay.alloc or (onPath or canAlloc) and overlay.path or overlay.unalloc
					SetDrawLayer(nil, 26)
					self:DrawAsset(tree.assets[frame], scrX, scrY, scale)
				end
				if self:DoesNodeMatchSearch(node) then
					SetDrawLayer(nil, 30)
					-- Golden ring around search matches, like the red ring on the passive tree
					SetDrawColor(1, 0.78, 0.25)
					local size = m_max(node.size * scale * 1.8, 10)
					DrawImage(self.highlightRing, scrX - size, scrY - size, size * 2, size * 2)
				end
			end
			SetDrawColor(1, 1, 1)
			if node == hoverNode and not IsKeyDown("CTRL") then
				SetDrawLayer(nil, 100)
				if self.tooltip:CheckForUpdate(node, spec:CountAllocNodes()) then
					self:AddNodeTooltip(self.tooltip, node, spec)
				end
				local size = m_floor(node.size * scale)
				self.tooltip.center = true
				self.tooltip:Draw(m_floor(scrX - size), m_floor(scrY - size), size * 2, size * 2, viewPort)
			end
		end
	end
	SetDrawLayer(nil, 0)
end
