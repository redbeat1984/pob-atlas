-- Path of Building (pob-atlas fork)
--
-- Class: Atlas Loadout List
-- List of named atlas trees in the Manage Atlas Trees popup: new, copy, rename, delete,
-- drag to reorder, double-click to make one active.
--
local t_insert = table.insert
local t_remove = table.remove
local m_max = math.max

---@class AtlasLoadoutListControl: ListControl
local AtlasLoadoutListClass = newClass("AtlasLoadoutListControl", "ListControl")

function AtlasLoadoutListClass:AtlasLoadoutListControl(anchor, rect, atlasTab)
	self:ListControl(anchor, rect, 16, "VERTICAL", true, atlasTab.loadouts)
	self.atlasTab = atlasTab
	self.controls.copy = new("ButtonControl"):ButtonControl({"BOTTOMLEFT",self,"TOP"}, {2, -4, 60, 18}, "Copy", function()
		self:RenameLoadout(self.selValue:Copy(self.selValue.title), "Copy Atlas Tree", true)
	end)
	self.controls.copy.enabled = function()
		return self.selValue ~= nil
	end
	self.controls.delete = new("ButtonControl"):ButtonControl({"LEFT",self.controls.copy,"RIGHT"}, {4, 0, 60, 18}, "Delete", function()
		self:OnSelDelete(self.selIndex, self.selValue)
	end)
	self.controls.delete.enabled = function()
		return self.selValue ~= nil and #self.list > 1
	end
	self.controls.rename = new("ButtonControl"):ButtonControl({"BOTTOMRIGHT",self,"TOP"}, {-2, -4, 60, 18}, "Rename", function()
		self:RenameLoadout(self.selValue, "Rename Atlas Tree")
	end)
	self.controls.rename.enabled = function()
		return self.selValue ~= nil
	end
	self.controls.new = new("ButtonControl"):ButtonControl({"RIGHT",self.controls.rename,"LEFT"}, {-4, 0, 60, 18}, "New", function()
		self:RenameLoadout(new("AtlasSpec"):AtlasSpec(atlasTab.tree, ""), "New Atlas Tree", true)
	end)
	return self
end

function AtlasLoadoutListClass:RenameLoadout(loadout, title, addOnName)
	local controls = { }
	controls.label = new("LabelControl"):LabelControl(nil, {0, 20, 0, 16}, "^7Enter name for this atlas tree:")
	controls.edit = new("EditControl"):EditControl(nil, {0, 40, 350, 20}, loadout.title, nil, nil, 100, function(buf)
		controls.save.enabled = buf:match("%S")
	end)
	controls.save = new("ButtonControl"):ButtonControl(nil, {-45, 70, 80, 20}, "Save", function()
		loadout.title = controls.edit.buf
		self.atlasTab.modFlag = true
		if addOnName then
			t_insert(self.list, loadout)
			self.selIndex = #self.list
			self.selValue = loadout
			self.atlasTab:SetActiveLoadout(#self.list)
		end
		self.atlasTab:RefreshLoadoutList()
		main:ClosePopup()
	end)
	controls.save.enabled = (loadout.title or ""):match("%S") ~= nil
	controls.cancel = new("ButtonControl"):ButtonControl(nil, {45, 70, 80, 20}, "Cancel", function()
		main:ClosePopup()
	end)
	main:OpenPopup(370, 100, title, controls, "save", "edit")
end

function AtlasLoadoutListClass:GetRowValue(column, index, loadout)
	if column == 1 then
		return (loadout.title or "Default").." ("..loadout:CountAllocNodes().." points)"
			..(index == self.atlasTab.activeLoadout and "  ^9(Current)" or "")
	end
end

function AtlasLoadoutListClass:OnOrderChange()
	self.atlasTab.activeLoadout = isValueInArray(self.list, self.atlasTab.spec)
	self.atlasTab.modFlag = true
	self.atlasTab:RefreshLoadoutList()
end

function AtlasLoadoutListClass:OnSelClick(index, loadout, doubleClick)
	if doubleClick and index ~= self.atlasTab.activeLoadout then
		self.atlasTab:SetActiveLoadout(index)
		self.atlasTab.modFlag = true
	end
end

function AtlasLoadoutListClass:OnSelDelete(index, loadout)
	if #self.list > 1 then
		main:OpenConfirmPopup("Delete Atlas Tree", "Are you sure you want to delete '"..(loadout.title or "Default").."'?", "Delete", function()
			t_remove(self.list, index)
			self.selIndex = nil
			self.selValue = nil
			if index == self.atlasTab.activeLoadout then
				self.atlasTab:SetActiveLoadout(m_max(1, index - 1))
			else
				self.atlasTab.activeLoadout = isValueInArray(self.list, self.atlasTab.spec)
				self.atlasTab:RefreshLoadoutList()
			end
			self.atlasTab.modFlag = true
		end)
	end
end

function AtlasLoadoutListClass:OnSelKeyDown(index, loadout, key)
	if key == "F2" then
		self:RenameLoadout(loadout, "Rename Atlas Tree")
	end
end
