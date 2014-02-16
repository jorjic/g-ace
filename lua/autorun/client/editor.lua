
function gace.OpenSession(id, content)
	if content == "" then -- Using base64encode on empty string returns nil, thus this
		content = ""
	else
		content = util.Base64Encode(content):Replace("\n", "")
	end

	gace.Editor:RunJavascript([[gaceSessions.open("]] .. id ..
		[[", {contentb: "]] .. content ..
		[["});]])
end
function gace.ReOpenSession(id)
	gace.Editor:RunJavascript([[
		gaceSessions.reopen("]] .. id .. [[");
	]])
end
function gace.CloseSession(id)
	gace.Editor:RunJavascript([[
		gaceSessions.close("]] .. id .. [[");
	]])
end

function gace.AskForInput(query, callback)
	gace.InputPanel.QueryString = query
	gace.InputPanel.InputCallback = callback

	gace.InputPanel.Input:RequestFocus()

	gace.InputPanel:Show()
end

surface.CreateFont("EditorTabFont", {
	font = "Roboto",
	size = 14
})

local VGUI_EDITOR_TAB = {
	Init = function(self)
		self.CloseButton = vgui.Create("DImageButton", self)
		self.CloseButton:SetIcon("icon16/cancel.png")
		self.CloseButton.DoClick = function()
			self:CloseTab()
		end
	end,
	CloseTab = function(self)
		gace.CloseSession(self.SessionId)
		self:Remove()
		table.RemoveByValue(gace.Tabs.Panels, self) -- uhh
		gace.Tabs:InvalidateLayout()
	end,
	PerformLayout = function(self)
		self.CloseButton:SetPos(self:GetWide() - 18, self:GetTall()/2-16/2)
		self.CloseButton:SetSize(16, 16)
	end,
	Paint = function(self, w, h)
		if self.Hovered then
			surface.SetDrawColor(52, 152, 219)
		elseif self.SessionId == gace.OpenedSessionId then
			surface.SetDrawColor(44, 62, 80)
		else
			surface.SetDrawColor(127, 140, 141)
		end
		surface.DrawRect(0, 0, w, h)

		draw.SimpleText(self.SessionId, "EditorTabFont", w-22, h/2, Color(255, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	
		if self.EditedNotSaved then
			surface.SetDrawColor(HSVToColor(CurTime()*3, 0.5, 0.95))
			local lx, ly
			for x=0,w,5 do
				local y = h-2-math.sin(CurTime()*2+x)*2
				if lx then
					surface.DrawLine(lx, ly, x, y)
				end
				lx, ly = x, y
			end
		end

	end,
	Setup = function(self, id)
		self:SetText("")
		self.SessionId = id
		self:SetToolTip(id)

		surface.SetFont("EditorTabFont")
		local w = surface.GetTextSize(self.SessionId)

		self:SetWide(140)--math.min(w+34, 160))
	end,
	DoClick = function(self)
		gace.ReOpenSession(self.SessionId)
	end,
	DoRightClick = function(self)
		local menu = DermaMenu()
		menu:AddOption("Close", function() self:CloseTab() end)
		menu:Open()
	end,
}
VGUI_EDITOR_TAB = vgui.RegisterTable(VGUI_EDITOR_TAB, "DButton") 

function gace.GetTabFor(id)
	local thepanel
	for _,pnl in pairs(gace.Tabs.Panels) do
		if pnl.SessionId == id then thepanel = pnl end
	end
	return thepanel
end

function gace.CreateTab(id)
	if gace.GetTabFor(id) then return end

	local btn = vgui.CreateFromTable(VGUI_EDITOR_TAB, gace.Tabs)
	btn:Setup(id)
	gace.Tabs:AddPanel(btn)
end

local gacedevurl = CreateConVar("g-ace-devurl", "", FCVAR_ARCHIVE)

concommand.Add("g-ace", function()

	if IsValid(gace.Frame) then gace.Frame:Show() return end

	local frame = vgui.Create("DFrame")
	frame:SetSize(900, 500)
	frame:Center()
	frame:SetDeleteOnClose(false)

	gace.Frame = frame

	local tabs = vgui.Create("DHorizontalScroller", frame)
	tabs:Dock(TOP)

	gace.Tabs = tabs

	local filetree = vgui.Create("DTree", frame)
	filetree:Dock(LEFT)
	filetree:SetWide(200)

	local function ConstructPath(node)
		local t = {node:GetText()}
		local p = node:GetParentNode()
		while p do
			if p:GetText() == "" then break end

			table.insert(t, p:GetText())
			p = p.GetParentNode and p:GetParentNode()
		end
		return table.concat(table.Reverse(t), "/")
	end

	gace.List("", function(_, _, payload)
		local function AddFolderOptions(node)
			node.DoRightClick = function()
				local menu = DermaMenu()
				menu:AddOption("Create File", function()
					gace.AskForInput("Filename? Needs to end in .txt", function(nm)
						local filname = ConstructPath(node) .. "/" .. nm
						gace.OpenSession(filname, "")

						-- TODO Fix
						
						--local t = gace.GetTabFor(filname)
						--if t then t.EditedNotSaved = true end
					end)
				end):SetIcon("icon16/page.png")
				menu:Open()
			end
			node:Receiver("gacefile", function(self, filepanels, dropped)
				if not dropped then return end

				local mypath = ConstructPath(self)

				for _,fp in pairs(filepanels) do
					local path = ConstructPath(fp)
					gace.Fetch(path, function(_, _, payload)
						if payload.err then return MsgN("Fail to fetch: ", payload.err) end
						gace.Delete(path)
						gace.Save(mypath .. "/" .. fp:GetText(), payload.content)
					end)
				end
			end)
		end
		local function AddFileOptions(node)
			node.DoClick = function()
				local id = ConstructPath(node)
				gace.Fetch(id, function(_, _, payload)
					gace.OpenSession(id, payload.content)
				end)
			end
			node.DoRightClick = function()
				local menu = DermaMenu()

				menu:AddOption("Duplicate", function()

				end):SetIcon("icon16/page_copy.png")

				local csubmenu, csmpnl = menu:AddSubMenu("Delete", function() end)
				csmpnl:SetIcon( "icon16/cross.png" )

				csubmenu:AddOption("Are you sure?", function()
					gace.Delete(ConstructPath(node))
				end):SetIcon("icon16/stop.png")

				menu:Open()
			end
			node:Droppable("gacefile")
			node.Icon:SetImage("icon16/page.png")
		end

		local function AddTreeNode(node, par)
			par = par or filetree
			if node.fol then
				for foldnm,fold in pairs(node.fol) do
					local node = par:AddNode(foldnm)
					AddFolderOptions(node)
					AddTreeNode(fold, node)
				end
			end
			if node.fil then
				for _,fil in pairs(node.fil) do
					local filnode = par:AddNode(fil)
					AddFileOptions(filnode)
				end
			end
		end

		for vfolder,vnode in pairs(payload.tree) do
			local vfolnode = filetree:AddNode(vfolder)
			AddFolderOptions(vfolnode)
			AddTreeNode(vnode, vfolnode)
			vfolnode:SetExpanded(true)
		end

	end, true)

	local html = vgui.Create("DHTML", frame)
	html:Dock(FILL)

	local url = "http://wyozi.github.io/g-ace/editor.html"
	if gacedevurl:GetString() ~= "" then
		url = gacedevurl:GetString()
	end
	
	html:OpenURL(url)

	html:AddFunction("gace", "SetOpenedSession", function(id)
		gace.OpenedSessionId = id
		gace.CreateTab(id)
	end)
	html:AddFunction("gace", "SaveSession", function(content)
		gace.Save(gace.OpenedSessionId, content, function()
			local t = gace.GetTabFor(gace.OpenedSessionId)
			if t then t.EditedNotSaved = false end
		end)
	end)
	html:AddFunction("gace", "SetEditedNotSaved", function(b)
		local t = gace.GetTabFor(gace.OpenedSessionId)
		if t then t.EditedNotSaved = b end
	end)

	gace.Editor = html

	local inputpanel = vgui.Create("DPanel", frame)
	inputpanel:Dock(BOTTOM)
	inputpanel:Hide()

	gace.InputPanel = inputpanel

	do
		local input = vgui.Create("DTextEntry", inputpanel)
		input:Dock(FILL)
		inputpanel.Input = input

		input.PaintOver = function(self, w, h)
			if self:GetText() == "" then
				draw.SimpleText(inputpanel.QueryString or "bla bla bla", "DermaDefault", 4, h/2, Color(0, 0, 0, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end

		input.OnEnter = function(self)
			inputpanel.InputCallback(self:GetText())
			inputpanel:Hide()
			gace.Frame:InvalidateLayout()
		end
	end

	frame:MakePopup()
end)

concommand.Add("g-ace-refresh", function()
	if IsValid(gace.Frame) then gace.Frame:Remove() end
end)