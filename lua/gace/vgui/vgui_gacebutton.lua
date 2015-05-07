local function HSVMod(clr, h, s, v)
	local _h, _s, _v = ColorToHSV(clr)
	return HSVToColor((_h+h)%360, math.Clamp(_s+s, 0, 1), math.Clamp(_v+v, 0, 1))
end

local VGUI_BUTTON = {
	QueryColor = function(self, clrid)
		local colors = self.Colors
		local clr = colors and colors[clrid]
		return clr or gace.UIColors[clrid]
	end,
	SetColorOverride = function(self, clrid, clr)
		self.Colors = self.Colors or {}
		self.Colors[clrid] = clr
	end,
	IsColorOverridden = function(self, clrid)
		return self.Colors ~= nil and self.Colors[clrid] ~= nil
	end,

	GetBGColor = function(self)
		if self:GetDisabled() then
			return Color(127, 110, 110)
		end

		local bg_overridden = self:IsColorOverridden("tab_bg")
		if self.Depressed then
			if bg_overridden then return HSVMod(self:QueryColor("tab_bg"), 0, 0, 0.25) end
			return (self:QueryColor("tab_bg_active"))
		elseif self.Hovered then
			if bg_overridden then return HSVMod(self:QueryColor("tab_bg"), 0, 0, 0.15) end
			return (self:QueryColor("tab_bg_hover"))
		elseif self.ToggleMode and self.Toggled then
			if bg_overridden then return HSVMod(self:QueryColor("tab_bg"), 0, 0, 0.25) end
			return (self:QueryColor("tab_bg_active"))
		end

		return (self:QueryColor("tab_bg"))
	end,
	Paint = function(self, w, h)
		local clr = self:GetBGColor()
		surface.SetDrawColor(clr)
		surface.DrawRect(0, 0, w, h)

		local fg = self:QueryColor("tab_fg")
		if self:GetDisabled() then
			fg = Color(150, 150, 150)
		end

		draw.SimpleText(self:GetText(), "EditorTabFont", w/2, h/2, fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	
		return true
	end,
}

derma.DefineControl( "GAceButton", "Button for GAce", VGUI_BUTTON, "DButton" )