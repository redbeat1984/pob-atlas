-- Path of Building (pob-atlas fork)
--
-- Class: Atlas Fill List
-- Rows of the fill panel: one atlas node per row with a tick box. Clicking a row ticks or
-- unticks it; hovering shows the node's stats.
--

---@class AtlasFillListControl: ListControl
local AtlasFillListClass = newClass("AtlasFillListControl", "ListControl")

function AtlasFillListClass:AtlasFillListControl(anchor, rect, atlasTab)
	self:ListControl(anchor, rect, 18, "VERTICAL", false, atlasTab.fillList)
	self.atlasTab = atlasTab
	self.showRowSeparators = true
	return self
end

function AtlasFillListClass:GetRowValue(column, index, node)
	if column == 1 then
		local ticked = self.atlasTab.fillTicks[node.id] ~= false
		local box = ticked and "^7[^2x^7] " or "^7[   ] "
		local typeColor = (node.type == "Keystone" and colorCodes.UNIQUE) or (node.type == "Notable" and colorCodes.RARE) or "^7"
		local dist = self.atlasTab.spec.dist[node.id]
		local cost = dist and ("  ^8("..dist..")") or "  ^8(no path)"
		local stat = node.sd and node.sd[1] and ("  ^8"..node.sd[1]:gsub("%s*\n%s*", " ")) or ""
		return box..typeColor..node.dn..cost..stat
	end
end

function AtlasFillListClass:AddValueTooltip(tooltip, index, node)
	tooltip:Clear()
	tooltip:AddLine(18, "^7"..node.dn)
	for _, line in ipairs(node.sd or { }) do
		for subLine in line:gmatch("[^\n]+") do
			tooltip:AddLine(16, colorCodes.MAGIC..subLine)
		end
	end
	local dist = self.atlasTab.spec.dist[node.id]
	tooltip:AddLine(14, dist and ("^8"..dist.." point(s) from the current tree") or "^8No path from the current tree")
	tooltip:AddLine(14, "^8Click to tick or untick")
end

function AtlasFillListClass:OnSelClick(index, node, doubleClick)
	local ticks = self.atlasTab.fillTicks
	ticks[node.id] = ticks[node.id] == false
	self.atlasTab:UpdateFillEstimate()
end
