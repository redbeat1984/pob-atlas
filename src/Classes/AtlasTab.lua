-- Path of Building (pob-atlas fork)
--
-- Class: Atlas Tab
-- Atlas passive tree tab: tree view, point counter, search and reset.
--

---@class AtlasTab: ControlHost
local AtlasTabClass = newClass("AtlasTab", "ControlHost")

function AtlasTabClass:AtlasTab(build)
	self:ControlHost()
	self.build = build

	self.tree = main:LoadAtlasTree(latestAtlasTreeVersion)
	self.viewer = new("AtlasTreeView"):AtlasTreeView()
	-- Named atlas trees (loadouts), saved with the build in the <Atlas> section
	self.loadouts = { new("AtlasSpec"):AtlasSpec(self.tree, "Default") }

	self.anchorControls = new("Control"):Control(nil, {0, 0, 0, 20})
	self.controls.loadoutSelect = new("DropDownControl"):DropDownControl({"LEFT", self.anchorControls, "RIGHT"}, {0, 0, 190, 20}, nil, function(index, value)
		if self.loadouts[index] then
			self:SetActiveLoadout(index)
			self.modFlag = true
		else
			self:OpenManagePopup()
			self.controls.loadoutSelect.selIndex = self.activeLoadout
		end
	end)
	self.controls.loadoutSelect.tooltipText = "Atlas trees saved in this build. Pick one, or Manage to add, copy, rename or delete."
	self.controls.reset = new("ButtonControl"):ButtonControl({"LEFT", self.controls.loadoutSelect, "RIGHT"}, {8, 0, 110, 20}, "Reset Atlas Tree", function()
		main:OpenConfirmPopup("Reset Atlas Tree", "Remove every allocated atlas passive from '"..(self.spec.title or "Default").."'?", "Reset", function()
			self.spec:ResetNodes()
			self.viewer.tooltip.updateParams = nil
		end)
	end)
	self.controls.search = new("EditControl"):EditControl({"LEFT", self.controls.reset, "RIGHT"}, {8, 0, 240, 20}, "", "Search", "%c", 100, function(buf)
		self.viewer.searchStr = buf
		if self.fillOpen then
			self.controls.fillSearchEdit:SetText(buf)
			self:SetFillSearch(buf, false)
		end
	end)
	self.controls.fill = new("ButtonControl"):ButtonControl({"LEFT", self.controls.search, "RIGHT"}, {4, 0, 50, 20}, "Fill", function()
		self:OpenFillPanel()
	end)
	self.controls.fill.tooltipText = "Open the fill panel: tick the nodes that match the search and route them into the tree"
	self.controls.import = new("ButtonControl"):ButtonControl({"LEFT", self.controls.fill, "RIGHT"}, {8, 0, 90, 20}, "Import Link", function()
		self:OpenImportPopup()
	end)
	self.controls.export = new("ButtonControl"):ButtonControl({"LEFT", self.controls.import, "RIGHT"}, {4, 0, 90, 20}, "Export Link", function()
		self:OpenExportPopup()
	end)
	self.controls.points = new("LabelControl"):LabelControl({"LEFT", self.controls.export, "RIGHT"}, {12, 0, 0, 16}, function()
		local used = self.spec:CountAllocNodes()
		local total = self.tree.totalPoints
		local color = used > total and colorCodes.NEGATIVE or "^7"
		return color..used.." / "..total.." atlas points  ^8(atlas tree "..self.tree.treeVersion:gsub("^atlas_", ""):gsub("_", ".")..")"
	end)
	-- Fill panel (right side): search, tick the nodes to take, then route them into the tree
	self.fillOpen = false
	self.fillSearch = ""
	self.fillTicks = { }
	self.fillList = { }
	self.fillEstimate = { count = 0, add = 0, remove = 0, addCount = 0, removeCount = 0, unreachable = 0 }
	self.fillWidth = 420
	local function panelShown() return self.fillOpen end
	self.fillAnchor = new("Control"):Control(nil, {0, 0, 0, 0})
	self.controls.fillTitle = new("LabelControl"):LabelControl({"TOPLEFT", self.fillAnchor, "TOPLEFT"}, {10, 8, 0, 18}, "^7Fill atlas tree")
	self.controls.fillTitle.shown = panelShown
	self.controls.fillClose = new("ButtonControl"):ButtonControl({"TOPLEFT", self.fillAnchor, "TOPLEFT"}, {self.fillWidth - 30, 6, 22, 20}, "x", function()
		self.fillOpen = false
	end)
	self.controls.fillClose.shown = panelShown
	self.controls.fillSearchEdit = new("EditControl"):EditControl({"TOPLEFT", self.fillAnchor, "TOPLEFT"}, {10, 34, self.fillWidth - 20, 20}, "", "Search stats", "%c", 100, function(buf)
		self:SetFillSearch(buf, true)
	end)
	self.controls.fillSearchEdit.shown = panelShown
	self.controls.fillAll = new("CheckBoxControl"):CheckBoxControl({"TOPLEFT", self.fillAnchor, "TOPLEFT"}, {84, 62, 20}, "Select all:", function(state)
		for _, node in ipairs(self.fillList) do
			self.fillTicks[node.id] = state
		end
		self:UpdateFillEstimate()
	end, "Tick or untick every node in the list")
	self.controls.fillAll.shown = panelShown
	self.controls.fillInfo = new("LabelControl"):LabelControl({"TOPLEFT", self.fillAnchor, "TOPLEFT"}, {112, 64, 0, 16}, function()
		local est = self.fillEstimate
		local left = self.tree.totalPoints - self.spec:CountAllocNodes()
		local color = est.add - est.remove > left and colorCodes.NEGATIVE or "^7"
		local text = "^7"..est.count.." of "..#self.fillList.." ticked, "..color.."+"..est.add.." points^7"
		if est.remove > 0 then
			text = text..", "..colorCodes.NEGATIVE.."-"..est.remove.."^7"
		end
		text = text.." ("..left.." left)"
		if est.unreachable > 0 then
			text = text.."  ^8"..est.unreachable.." no path"
		end
		return text
	end)
	self.controls.fillInfo.shown = panelShown
	self.controls.fillListCtl = new("AtlasFillListControl"):AtlasFillListControl({"TOPLEFT", self.fillAnchor, "TOPLEFT"}, {10, 90, self.fillWidth - 20, 0}, self)
	self.controls.fillListCtl.shown = panelShown
	self.controls.fillGo = new("ButtonControl"):ButtonControl({"TOPLEFT", self.fillAnchor, "TOPLEFT"}, {10, 0, 120, 22}, "Fill Tree", function()
		self:RunFill()
	end)
	self.controls.fillGo.shown = panelShown
	self.fillTrim = false
	self.controls.fillTrim = new("CheckBoxControl"):CheckBoxControl({"TOPLEFT", self.fillAnchor, "TOPLEFT"}, {200, 0, 20}, "Trim paths when removing:", function(state)
		self.fillTrim = state
		self:UpdateFillEstimate()
	end, "When a node is removed, also remove the plain travel nodes that only led to it.\nStops at a junction, a Notable or Keystone, the start, or another ticked node.", false)
	self.controls.fillTrim.shown = panelShown
	self.fillGateways = true
	self.controls.fillGateways = new("CheckBoxControl"):CheckBoxControl({"TOPLEFT", self.fillAnchor, "TOPLEFT"}, {390, 0, 20}, "Use gateways:", function(state)
		self.fillGateways = state
		self:UpdateFillEstimate()
	end, "Let paths jump from one end of a gateway to the other when that is shorter.\nUntick to route only along the tree lines.", true)
	self.controls.fillGateways.shown = panelShown
	self.controls.fillGo.enabled = function() return self.fillEstimate.addCount > 0 or self.fillEstimate.removeCount > 0 end
	self.controls.fillGo.tooltipText = "Remove every unticked node that is in the tree, then allocate every ticked node, nearest first, along the shortest paths"
	self.controls.fillMsg = new("LabelControl"):LabelControl({"LEFT", self.controls.fillGo, "RIGHT"}, {10, 0, 0, 16}, function() return self.fillMsg or "" end)
	self.controls.fillMsg.shown = panelShown
	self:SetActiveLoadout(1)
	self.modFlag = false
	return self
end

function AtlasTabClass:OpenFillPanel()
	self.fillOpen = true
	self.fillTicks = { }
	self.fillMsg = nil
	self.controls.fillSearchEdit:SetText(self.controls.search.buf)
	self:SetFillSearch(self.controls.search.buf, false)
	self:SelectControl(self.controls.fillSearchEdit)
end

-- The panel search and the tree search stay the same, so the tree rings show what the list holds
function AtlasTabClass:SetFillSearch(text, syncTreeSearch)
	self.fillSearch = text or ""
	self.viewer.searchStr = self.fillSearch
	if syncTreeSearch then
		self.controls.search:SetText(self.fillSearch)
	end
	self.fillMsg = nil
	self:RebuildFillList()
end

-- Nodes that match the panel search, those already in the tree first, then nearest first
function AtlasTabClass:RebuildFillList()
	local list = self.fillList
	for i = #list, 1, -1 do
		list[i] = nil
	end
	if self.fillSearch:match("%S") then
		for id, node in pairs(self.tree.nodes) do
			if node.type ~= "Mastery" and node.type ~= "Start" and self.viewer:NodeMatchesText(node, self.fillSearch) then
				table.insert(list, node)
			end
		end
	end
	local dist = self.spec.dist
	table.sort(list, function(a, b)
		local da, db = dist[a.id] or math.huge, dist[b.id] or math.huge
		if da ~= db then
			return da < db
		end
		if a.dn ~= b.dn then
			return a.dn < b.dn
		end
		return a.id < b.id
	end)
	self.fillListSpec, self.fillListVersion = self.spec, self.spec.summaryVersion
	self:UpdateFillEstimate()
end

-- Ticked nodes not in the tree are added; unticked nodes in the tree are removed
function AtlasTabClass:GetFillPlan()
	local toAdd, toRemove, keep, removed = { }, { }, { }, { }
	local ticked = 0
	for _, node in ipairs(self.fillList) do
		local isTicked = self.fillTicks[node.id] ~= false
		local inTree = self.spec.allocNodes[node.id]
		if isTicked then
			ticked = ticked + 1
			keep[node.id] = true
			if not inTree then
				table.insert(toAdd, node)
			end
		elseif inTree then
			table.insert(toRemove, node)
			removed[node.id] = true
		end
	end
	return toAdd, toRemove, keep, removed, ticked
end

-- Removals first, then additions that never route through a removed node
local function applyFill(spec, trim, noGateways, toAdd, toRemove, keep, removed)
	local freed = #toRemove > 0 and spec:RemoveNodes(toRemove, keep, trim) or 0
	local added, unreachable = 0, 0
	if #toAdd > 0 then
		added, unreachable = spec:FillNodes(toAdd, removed, noGateways)
	end
	return added, freed, unreachable
end

-- Points the fill would add and free, worked out on a copy of the active tree
function AtlasTabClass:UpdateFillEstimate()
	local toAdd, toRemove, keep, removed, ticked = self:GetFillPlan()
	local added, freed, unreachable = 0, 0, 0
	if #toAdd > 0 or #toRemove > 0 then
		added, freed, unreachable = applyFill(self.spec:Copy(), self.fillTrim, not self.fillGateways, toAdd, toRemove, keep, removed)
	end
	self.fillEstimate = { count = ticked, add = added, remove = freed, addCount = #toAdd, removeCount = #toRemove, unreachable = unreachable }
	self.controls.fillAll.state = ticked > 0 and ticked == #self.fillList
end

function AtlasTabClass:RunFill()
	local added, freed, unreachable = applyFill(self.spec, self.fillTrim, not self.fillGateways, self:GetFillPlan())
	self.viewer.tooltip.updateParams = nil
	local msg = "^7Added "..added..", removed "..freed.." point(s)"
	if unreachable > 0 then
		msg = msg..", ^8"..unreachable.." node(s) have no path"
	end
	self:RebuildFillList()
	self.fillMsg = msg
end

function AtlasTabClass:SetActiveLoadout(index)
	self.activeLoadout = index
	self.spec = self.loadouts[index]
	self.viewer.tooltip.updateParams = nil
	self:RefreshLoadoutList()
end

function AtlasTabClass:RefreshLoadoutList()
	if not self.controls.loadoutSelect then
		return
	end
	local list = { }
	for i, loadout in ipairs(self.loadouts) do
		list[i] = (loadout.title or "Default").." ("..loadout:CountAllocNodes()..")"
	end
	table.insert(list, "Manage atlas trees...")
	self.controls.loadoutSelect:SetList(list)
	self.controls.loadoutSelect.selIndex = self.activeLoadout
end

function AtlasTabClass:IsModified()
	if self.modFlag then
		return true
	end
	for _, loadout in ipairs(self.loadouts) do
		if loadout.modFlag then
			return true
		end
	end
	return false
end

function AtlasTabClass:ResetModFlags()
	self.modFlag = false
	for _, loadout in ipairs(self.loadouts) do
		loadout.modFlag = false
	end
end

-- <Atlas activeLoadout="2"><Loadout title="Blight" treeVersion="atlas_3_30" nodes="1,2,3"/></Atlas>
function AtlasTabClass:Load(xml, dbFileName)
	local loadouts = { }
	for _, node in ipairs(xml) do
		if node.elem == "Loadout" then
			local ids = { }
			for id in (node.attrib.nodes or ""):gmatch("%d+") do
				table.insert(ids, tonumber(id))
			end
			local loadout = new("AtlasSpec"):AtlasSpec(self.tree, node.attrib.title or "Default")
			loadout:SetAllocIds(ids)
			table.insert(loadouts, loadout)
		end
	end
	if #loadouts > 0 then
		self.loadouts = loadouts
		local active = tonumber(xml.attrib.activeLoadout) or 1
		self:SetActiveLoadout((active >= 1 and active <= #loadouts) and active or 1)
	end
	self:ResetModFlags()
end

function AtlasTabClass:Save(xml)
	xml.attrib = { activeLoadout = tostring(self.activeLoadout) }
	for _, loadout in ipairs(self.loadouts) do
		table.insert(xml, { elem = "Loadout", attrib = {
			title = loadout.title or "Default",
			treeVersion = self.tree.treeVersion,
			nodes = table.concat(loadout:GetAllocIds(), ","),
		} })
	end
end

function AtlasTabClass:OpenManagePopup()
	main:OpenPopup(370, 290, "Manage Atlas Trees", {
		new("AtlasLoadoutListControl"):AtlasLoadoutListControl(nil, {0, 50, 350, 200}, self),
		new("ButtonControl"):ButtonControl(nil, {0, 259, 90, 20}, "Done", function()
			main:ClosePopup()
			self:RefreshLoadoutList()
		end),
	})
end

function AtlasTabClass:OpenImportPopup()
	local controls = { }
	controls.label = new("LabelControl"):LabelControl(nil, {0, 20, 0, 16}, "^7Paste an atlas tree link from the official site or poe.ninja (replaces '"..(self.spec.title or "Default").."'):")
	controls.edit = new("EditControl"):EditControl(nil, {0, 40, 600, 20}, "", nil, nil, nil, function(buf)
		controls.msg.label = ""
	end)
	controls.msg = new("LabelControl"):LabelControl(nil, {0, 62, 0, 16}, "")
	controls.import = new("ButtonControl"):ButtonControl(nil, {-45, 85, 80, 20}, "Import", function()
		local errMsg, skipped = self.spec:DecodeURL(controls.edit.buf)
		if errMsg then
			controls.msg.label = colorCodes.NEGATIVE..errMsg
			return
		end
		self.viewer.tooltip.updateParams = nil
		self:RefreshLoadoutList()
		main:ClosePopup()
		if skipped and skipped > 0 then
			main:OpenMessagePopup("Import Atlas Tree", skipped.." node(s) in the link are not on this atlas tree and were skipped.")
		end
	end)
	controls.cancel = new("ButtonControl"):ButtonControl(nil, {45, 85, 80, 20}, "Cancel", function()
		main:ClosePopup()
	end)
	main:OpenPopup(630, 115, "Import Atlas Tree", controls, "import", "edit")
end

function AtlasTabClass:OpenExportPopup()
	local url = self.spec:EncodeURL("https://www.pathofexile.com/fullscreen-atlas-skill-tree/")
	local controls = { }
	controls.label = new("LabelControl"):LabelControl(nil, {0, 20, 0, 16}, "^7Atlas tree link for '"..(self.spec.title or "Default").."':")
	controls.edit = new("EditControl"):EditControl(nil, {0, 40, 450, 20}, url, nil, "%Z")
	controls.copy = new("ButtonControl"):ButtonControl(nil, {-45, 70, 80, 20}, "Copy", function()
		Copy(url)
	end)
	controls.done = new("ButtonControl"):ButtonControl(nil, {45, 70, 80, 20}, "Done", function()
		main:ClosePopup()
	end)
	main:OpenPopup(480, 100, "Export Atlas Tree", controls, "done", "edit")
end

function AtlasTabClass:Draw(viewPort, inputEvents)
	self.anchorControls.x = viewPort.x + 4
	self.anchorControls.y = viewPort.y + viewPort.height - 24

	for id, event in ipairs(inputEvents) do
		if event.type == "KeyDown" and event.key == "f" and IsKeyDown("CTRL") then
			self:SelectControl(self.controls.search)
			inputEvents[id] = nil
		end
	end
	-- Keep the point count in the loadout picker current
	if self.listVersion ~= self.spec.summaryVersion then
		self.listVersion = self.spec.summaryVersion
		self:RefreshLoadoutList()
	end
	-- Fill panel position and size, and a fresh list when the tree changes
	local panelWidth = self.fillOpen and self.fillWidth or 0
	self.fillAnchor.x = viewPort.x + viewPort.width - panelWidth
	self.fillAnchor.y = viewPort.y
	self.controls.fillListCtl.height = viewPort.height - 34 - 90 - 62
	self.controls.fillGo.y = viewPort.height - 34 - 30
	self.controls.fillTrim.y = viewPort.height - 34 - 56
	self.controls.fillGateways.y = self.controls.fillTrim.y
	if self.fillOpen and (self.fillListSpec ~= self.spec or self.fillListVersion ~= self.spec.summaryVersion) then
		self:RebuildFillList()
	end
	self:ProcessControlsInput(inputEvents, viewPort)

	local treeViewPort = { x = viewPort.x, y = viewPort.y, width = viewPort.width - panelWidth, height = viewPort.height - 32 }
	self.viewer:Draw(self.spec, treeViewPort, inputEvents)
	if self.fillOpen then
		SetDrawLayer(1)
		SetDrawColor(0.85, 0.85, 0.85)
		DrawImage(nil, self.fillAnchor.x, viewPort.y, 4, viewPort.height - 34)
		SetDrawColor(0.05, 0.05, 0.05)
		DrawImage(nil, self.fillAnchor.x + 4, viewPort.y, panelWidth - 4, viewPort.height - 34)
	end

	SetDrawLayer(1)
	SetDrawColor(0.05, 0.05, 0.05)
	DrawImage(nil, viewPort.x, viewPort.y + viewPort.height - 30, viewPort.width, 30)
	SetDrawColor(0.85, 0.85, 0.85)
	DrawImage(nil, viewPort.x, viewPort.y + viewPort.height - 34, viewPort.width, 4)
	self:DrawControls(viewPort)
end

-- Word wrap for the sidebar list
local function wrapLine(str, height, width)
	local lines, current = { }, ""
	for word in str:gmatch("%S+") do
		local try = current == "" and word or current.." "..word
		if current ~= "" and DrawStringWidth(height, "VAR", try) > width then
			table.insert(lines, current)
			current = word
		else
			current = try
		end
	end
	if current ~= "" then
		table.insert(lines, current)
	end
	return lines
end

-- Lines for the sidebar summary of the allocated atlas modifiers (TextListControl rows)
function AtlasTabClass:GetSummaryList(width)
	if self.summaryList and self.summaryListSpec == self.spec and self.summaryListVersion == self.spec.summaryVersion and self.summaryListWidth == width then
		return self.summaryList
	end
	local list = { }
	local summary, keystones = self.spec:GetStatSummary()
	local used = self.spec:CountAllocNodes()
	table.insert(list, { height = 18, "^7Atlas modifiers  ^8("..used.." / "..self.tree.totalPoints.." points)" })
	table.insert(list, { height = 6 })
	if used == 0 then
		table.insert(list, { height = 16, "^8Allocate atlas passives to see" })
		table.insert(list, { height = 16, "^8their combined modifiers here." })
	end
	if #keystones > 0 then
		table.insert(list, { height = 16, colorCodes.UNIQUE.."Keystones" })
		for _, name in ipairs(keystones) do
			table.insert(list, { height = 16, "^7  "..name })
		end
		table.insert(list, { height = 6 })
	end
	for _, entry in ipairs(summary) do
		local text = entry.text..(entry.count and "  ^8(x"..entry.count..")" or "")
		for i, line in ipairs(wrapLine(text, 16, width - 12)) do
			table.insert(list, { height = 16, colorCodes.MAGIC..(i > 1 and "  " or "")..line })
		end
		table.insert(list, { height = 4 })
	end
	self.summaryList, self.summaryListSpec, self.summaryListVersion, self.summaryListWidth = list, self.spec, self.spec.summaryVersion, width
	return list
end
