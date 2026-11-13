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
	self.controls.search = new("EditControl"):EditControl({"LEFT", self.controls.reset, "RIGHT"}, {8, 0, 300, 20}, "", "Search", "%c", 100, function(buf)
		self.viewer.searchStr = buf
	end)
	self.controls.import = new("ButtonControl"):ButtonControl({"LEFT", self.controls.search, "RIGHT"}, {8, 0, 90, 20}, "Import Link", function()
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
	self:SetActiveLoadout(1)
	self.modFlag = false
	return self
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
	controls.label = new("LabelControl"):LabelControl(nil, {0, 20, 0, 16}, "^7Paste an atlas tree link (replaces '"..(self.spec.title or "Default").."'):")
	controls.edit = new("EditControl"):EditControl(nil, {0, 40, 450, 20}, "", nil, nil, nil, function(buf)
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
	main:OpenPopup(480, 115, "Import Atlas Tree", controls, "import", "edit")
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
	self:ProcessControlsInput(inputEvents, viewPort)

	local treeViewPort = { x = viewPort.x, y = viewPort.y, width = viewPort.width, height = viewPort.height - 32 }
	self.viewer:Draw(self.spec, treeViewPort, inputEvents)

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
