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
	self.spec = new("AtlasSpec"):AtlasSpec(self.tree)
	self.viewer = new("AtlasTreeView"):AtlasTreeView()

	self.anchorControls = new("Control"):Control(nil, {0, 0, 0, 20})
	self.controls.reset = new("ButtonControl"):ButtonControl({"LEFT", self.anchorControls, "RIGHT"}, {0, 0, 110, 20}, "Reset Atlas Tree", function()
		main:OpenConfirmPopup("Reset Atlas Tree", "Remove every allocated atlas passive?", "Reset", function()
			self.spec:ResetNodes()
			self.viewer.tooltip.updateParams = nil
		end)
	end)
	self.controls.search = new("EditControl"):EditControl({"LEFT", self.controls.reset, "RIGHT"}, {8, 0, 300, 20}, "", "Search", "%c", 100, function(buf)
		self.viewer.searchStr = buf
	end)
	self.controls.points = new("LabelControl"):LabelControl({"LEFT", self.controls.search, "RIGHT"}, {12, 0, 0, 16}, function()
		local used = self.spec:CountAllocNodes()
		local total = self.tree.totalPoints
		local color = used > total and colorCodes.NEGATIVE or "^7"
		return color..used.." / "..total.." atlas points  ^8(atlas tree "..self.tree.treeVersion:gsub("^atlas_", ""):gsub("_", ".")..")"
	end)
	return self
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
	if self.summaryList and self.summaryListVersion == self.spec.summaryVersion and self.summaryListWidth == width then
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
	self.summaryList, self.summaryListVersion, self.summaryListWidth = list, self.spec.summaryVersion, width
	return list
end
