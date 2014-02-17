
function gace.OpenSession(id, content, data)
	if content == "" then -- Using base64encode on empty string returns nil, thus this
		content = ""
	else
		content = util.Base64Encode(content):Replace("\n", "")
	end

	local defens = false
	if data then
		defens = data.defens or defens
	end

	gace.Editor:RunJavascript([[gaceSessions.open("]] .. id ..
		[[", {contentb: "]] .. content ..
		[[", defens: ]] .. tostring(defens) .. [[});]])
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
	if gace.OpenedSessionId == id then
		gace.OpenedSessionId = nil
		gace.SendRequest("colsetfile", {path=""})
	end
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
	CloseTab = function(self, force)
		if not force and self.EditedNotSaved then
			local menu = DermaMenu()
			menu:AddOption("Unsaved changes. Are you sure you want to close the tab?", function()
				self:CloseTab(true)
			end):SetIcon("icon16/stop.png")
			menu:Open()
			return
		end
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
local gaceclosewithesc = CreateConVar("g-ace-closewithesc", "1", FCVAR_ARCHIVE)

concommand.Add("g-ace", function()

	if IsValid(gace.Frame) then
		if gace.Frame:IsVisible() then return end
		gace.Frame:Show()
		gace.SendRequest("colsetfile", {path=gace.OpenedSessionId})
		return
	end

	-- Clear some session variables that might've gotten cached

	gace.OpenedSessionId = nil
	gace.FileNodeTree = nil

	local frame = vgui.Create("DFrame")
	frame:SetDeleteOnClose(false)
	frame:SetSizable(true)
	frame:SetTitle("")
	frame.OnClose = function()
		gace.SendRequest("colsetfile", {path=""})
	end
	frame.Paint = function(self, w, h)
		surface.SetDrawColor(22, 31, 50)
		surface.DrawRect(0, 0, w, h)
	end

	local oldthink = frame.Think
	function frame:Think()
		if input.IsKeyDown(KEY_ESCAPE) and gaceclosewithesc:GetBool() then
			self:SetVisible(false)

			if gui.IsGameUIVisible () then
				gui.HideGameUI ()
			else
				gui.ActivateGameUI ()
			end
		end
		oldthink(self)
	end

	local c_x, c_y, c_w, c_h = cookie.GetNumber("gace-frame-x"),
							   cookie.GetNumber("gace-frame-y"),
							   cookie.GetNumber("gace-frame-w"),
							   cookie.GetNumber("gace-frame-h")
	
	if c_w == 0 then c_w = 900 end
	if c_h == 0 then c_h = 600 end

	frame:SetSize(c_w, c_h)
	if c_x == 0 and c_y == 0 then
		frame:Center()
	else
		frame:SetPos(c_x, c_y)
	end

	timer.Create("gace-frame-cookies", 1, 0, function()
		if not IsValid(frame) then return end

		local x, y = frame:GetPos()
		local w, h = frame:GetSize()

		cookie.Set("gace-frame-x", x)
		cookie.Set("gace-frame-y", y)
		cookie.Set("gace-frame-w", w)
		cookie.Set("gace-frame-h", h)
	end)

	gace.Frame = frame

	local tabs = vgui.Create("DHorizontalScroller", frame)
	tabs:Dock(TOP)

	gace.Tabs = tabs

	local filetree = vgui.Create("DTree", frame)
	filetree:Dock(LEFT)
	filetree:SetWide(200)

	local function ConstructPath(node, skip_first_node)
		local t = {}

		if not skip_first_node then
			t[1] = node:GetText()
		end

		local p = node:GetParentNode()
		while p do
			if p:GetText() == "" then break end

			table.insert(t, p:GetText())
			p = p.GetParentNode and p:GetParentNode()
		end
		return table.concat(table.Reverse(t), "/")
	end

	-- Returns table that is same to large except has no values in sub
	-- Instead of an indexes list, this returns a table with same key-value pairs as the "large" table
	local function SubtractTable(large, sub)
		local ret = {}
		for k,v in pairs(large) do
			if not table.HasValue(sub, v) then
				ret[k] = v
			end
		end
		return ret
	end

	local function ListPath(path, tree)
		local root = gace.FileNodeTree
		local replace_everything = false

		if path == "" then
			root = {node=filetree, fol={}, fil={}}
			gace.FileNodeTree = root

			local rootnode = filetree:Root()
			if rootnode.ChildNodes then rootnode.ChildNodes:Remove() rootnode.ChildNodes=nil end
			replace_everything = true
		else
			local pathcomps = path:Split("/")
			for _,pc in ipairs(pathcomps) do
				root = root.fol[pc]
			end
		end

		local function RefreshFolder(path)
			gace.List(path, function(_, _, payload)
				ListPath(path, payload.tree)
			end, true)
		end

		local function AddFolderOptions(node)
			node.DoRightClick = function()
				local menu = DermaMenu()

				menu:AddOption("Refresh", function()
					RefreshFolder(ConstructPath(node))
				end):SetIcon("icon16/arrow_refresh.png")

				menu:AddOption("Create File", function()
					gace.AskForInput("Filename? Needs to end in .txt", function(nm)
						local filname = ConstructPath(node) .. "/" .. nm
						gace.OpenSession(filname, "", {defens = true})
					end)
				end):SetIcon("icon16/page.png")

				menu:Open()
			end

			local oldthink = node.Think
			node.Think = function(self)
				-- Used to retain expanded status if the node is recreated
				self.treetable.expanded = self.m_bExpanded
				oldthink(self)
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
						RefreshFolder(mypath)
						RefreshFolder(ConstructPath(fp, true))
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
					gace.AskForInput("Filename? Needs to end in .txt", function(nm)
						local filname = ConstructPath(node, true) .. "/" .. nm
						gace.Fetch(ConstructPath(node), function(_, _, payload)
							if payload.err then return MsgN("Failed to fetch: ", payload.err) end
							gace.OpenSession(filname, payload.content, {defens=true})
						end)
					end)
				end):SetIcon("icon16/page_copy.png")

				local csubmenu, csmpnl = menu:AddSubMenu("Delete", function() end)
				csmpnl:SetIcon( "icon16/cross.png" )

				csubmenu:AddOption("Are you sure?", function()
					gace.Delete(ConstructPath(node))
					RefreshFolder(ConstructPath(node, true))
				end):SetIcon("icon16/stop.png")

				menu:Open()
			end
			node:Droppable("gacefile")
			node.Icon:SetImage("icon16/page.png")
		end

		local function AddTreeNode(node, par)
			local parnode = par.node
			if parnode.ChildNodes then parnode.ChildNodes:Remove() parnode.ChildNodes=nil end

			if node.fol then
				for foldnm,fold in pairs(node.fol) do
					local node = parnode:AddNode(foldnm)
					AddFolderOptions(node)

					local oldnodetable = par.fol[foldnm]
					if oldnodetable then -- Old node table entry was expanded
						node:SetExpanded(oldnodetable.expanded or false)
					elseif par == gace.FileNodeTree then -- We're top level
						node:SetExpanded(true)
					end

					local mytbl = {fol={}, fil={}, node=node}
					node.treetable = mytbl
					par.fol[foldnm] = mytbl

					AddTreeNode(fold, mytbl)

					-- We're top level
				end
			end
			if node.fil then
				for _,fil in pairs(node.fil) do
					local filnode = parnode:AddNode(fil)
					filnode.Path = ConstructPath(filnode)
					filnode.Paint = function(self, w, h)
						if self.Path == gace.OpenedSessionId then
							surface.SetDrawColor(127, 255, 127, 140)
							surface.DrawRect(0, 0, w, h)
						end

						-- Collaborators in this file
						local collabs = {}
						for k,v in pairs(gace.CollabPositions) do
							if IsValid(k) and v == self.Path then
								table.insert(collabs, k)
							end
						end

						for idx,c in pairs(collabs) do
							if not IsValid(c.CollabAvatar) then
								c.CollabAvatar = vgui.Create("AvatarImage")
								c.CollabAvatar:SetPlayer(c, 16)
								c.CollabAvatar:SetToolTip(c:Nick())
								c.CollabAvatar.Think = function(self)
									if not IsValid(c) or self:GetParent().Path ~= gace.CollabPositions[c] then
										self:SetParent(nil)
										self:SetVisible(false)
									end
								end
							end
							c.CollabAvatar:SetVisible(true)
							c.CollabAvatar:SetParent(self)
							c.CollabAvatar:SetPos(w-idx*16, 0)
							c.CollabAvatar:SetSize(16, 16)
							--draw.SimpleText(c:Nick():sub(1,1), "DermaDefaultBold", w-idx*10, 2, Color(0, 0, 0))
						end
					end
					par.fil[fil] = filnode
					AddFileOptions(filnode)
				end
			end
		end

		AddTreeNode(tree, root)
	end

	gace.List("", function(_, _, payload)
		ListPath("", payload.tree)
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
		gace.SendRequest("colsetfile", {path=id})
	end)
	html:AddFunction("gace", "ReportLatestContent", function(content)
		gace.OpenedSessionContent = content
	end)
	html:AddFunction("gace", "SaveSession", function(content)
		gace.Save(gace.OpenedSessionId, content, function()
			local t = gace.GetTabFor(gace.OpenedSessionId)
			if t then t.EditedNotSaved = false end

			local tb = gace.OpenedSessionId:Split("/")
			local par = table.concat(tb, "/", 1, #tb-1)

			gace.List(par, function(_, _, payload)
				ListPath(par, payload.tree)
			end, true)
		end)
	end)
	html:AddFunction("gace", "SetEditedNotSaved", function(b)
		local t = gace.GetTabFor(gace.OpenedSessionId)
		if t then t.EditedNotSaved = b end
	end)
	html:AddFunction("gace", "CallLDFunc", function(ldf, content)
		luadev[ldf](content)
	end)
	html:AddFunction("gace", "NewSession", function(name)
		gace.OpenSession(name, "")
	end)

	local oldpaint = html.Paint
	html.Paint = function(self, w, h)
		if self:IsLoading() then
			surface.SetDrawColor(0, 0, 0)
			surface.DrawRect(0, 0, w, h)
			draw.SimpleText("Loading", "Trebuchet24", 10, 10)

			filetree:SetEnabled(false)
		else
			filetree:SetEnabled(true)
			html.Paint = oldpaint
		end
	end

	gace.Editor = html

	-- Input panel that can ask for input

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

	-- Action buttons that are in the title bar

	do
		local btns = {
			{ text = "Run on", width = 40 },
			{	text = "Self",
				fn = function()
					luadev.RunOnSelf(gace.OpenedSessionContent)
				end,
				enabled = function() return luadev ~= nil end,
				tt = "Hotkey in editor: F5"},
			{	text = "Server",
				fn = function()
					luadev.RunOnServer(gace.OpenedSessionContent)
				end,
				enabled = function() return luadev ~= nil end,
				tt = "Hotkey in editor: F6"},
			{	text = "Shared",
				fn = function()
					luadev.RunOnShared(gace.OpenedSessionContent)
				end,
				enabled = function() return luadev ~= nil end,
				tt = "Hotkey in editor: F7"},
			{ text = "", width = 10},
		}

		local x = 10
		for _,v in pairs(btns) do
			local btn = vgui.Create(v.fn and "DButton" or "DLabel", frame)
			btn:SetPos(x, 2)
			btn:SetSize(v.width or 60, 20)
			x = x + (v.width or 62)
			btn:SetText(v.text)

			if v.tt then btn:SetToolTip(v.tt) end

			if v.enabled and not v.enabled() then
				btn:SetEnabled(false)
			elseif v.fn then
				btn.DoClick = v.fn
			end
		end
	end

	frame:MakePopup()
end)

concommand.Add("g-ace-refresh", function()
	if IsValid(gace.Frame) then gace.Frame:Remove() end
	cookie.Set("gace-frame-x", "0")
	cookie.Set("gace-frame-y", "0")
	cookie.Set("gace-frame-w", "900")
	cookie.Set("gace-frame-h", "600")
end)