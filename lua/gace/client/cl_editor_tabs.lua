function gace.CreateTabPanel()
	local tabs = vgui.Create("DHorizontalScroller")
	tabs.Paint = function(self, w, h)
		surface.SetDrawColor(gace.UIColors.tab_border)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
	tabs:SetOverlap(-1)

	local tabsel = vgui.Create("GAceTabSelector", tabs)
	tabs:AddPanel(tabsel)

	return tabs
end

gace.tab = {}
function gace.tab.GetById(id)
	return _u.detect(gace.GetPanel("Tabs").Panels, function(pnl)
		return pnl.SessionId == id
	end)
end
gace.GetTabFor = gace.tab.GetById -- alias

function gace.tab.GetFilenameCount(fname)
	return _u.reduce(gace.GetPanel("Tabs").Panels, 0, function(old, pnl)
		if pnl.FileName == fname then return old + 1 end
		return old
	end)
end

function gace.tab.Create(id)
	if gace.GetTabFor(id) then return end

	local btn = vgui.Create("GAceTab", gace.Tabs)
	btn:Setup(id)

	local tabs = gace.GetPanel("Tabs")
	tabs:AddPanel(btn)

	-- In case there are duplicate filenames
	tabs:InvalidateChildren()
end
gace.CreateTab = gace.tab.Create -- alias

function gace.tab.Remove(id)
	local tabs = gace.GetPanel("Tabs")

	local tab = gace.GetTabFor(id)
	if tab then
		local prev_tab = table.FindPrev(tabs.Panels, tab)
		local set_session
		if prev_tab and prev_tab.SessionId then
			set_session = prev_tab.SessionId
		end

		tab:Remove()
		table.RemoveByValue(tabs.Panels, tab) -- uhh, a hack

		tabs:InvalidateLayout()

		-- In case there were duplicate filenames
		tabs:InvalidateChildren()

		if set_session then
			gace.OpenSession(set_session)
		end
	end
end

gace.AddHook("OnSessionOpened", "Editor_KeepTabsUpdated", function(id)
	gace.tab.Create(id)
end)

gace.AddHook("OnSessionClosed", "Editor_KeepTabsUpdated", function(id)
	gace.tab.Remove(id)
end)
