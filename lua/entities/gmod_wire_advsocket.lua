AddCSLuaFile()
DEFINE_BASECLASS( "base_wire_entity" )
ENT.PrintName       = "Wire Adv Socket"
ENT.Author          = "DaDamRival"
ENT.Purpose         = "Links with a adv plug"
ENT.Instructions    = "Move a adv plug close to a adv socket to link them, and data will be transferred through the link."
ENT.WireDebugName	= "Adv Socket"

local PositionOffsets = {
	["models/wingf0x/isasocket.mdl"] = Vector(0,0,0),
	["models/wingf0x/altisasocket.mdl"] = Vector(0,0,2.6),
	["models/wingf0x/ethernetsocket.mdl"] = Vector(0,0,0),
	["models/wingf0x/hdmisocket.mdl"] = Vector(0,0,0),
	["models/props_lab/tpplugholder_single.mdl"] = Vector(5, 13, 10),
	["models/bull/various/usb_socket.mdl"] = Vector(8,0,0),
	["models/hammy/pci_slot.mdl"] = Vector(0,0,0),
	["models//hammy/pci_slot.mdl"] = Vector(0,0,0), -- For some reason, GetModel on this model has two / on the client... Bug?
}
local AngleOffsets = {
	["models/wingf0x/isasocket.mdl"] = Angle(0,0,0),
	["models/wingf0x/altisasocket.mdl"] = Angle(0,0,0),
	["models/wingf0x/ethernetsocket.mdl"] = Angle(0,0,0),
	["models/wingf0x/hdmisocket.mdl"] = Angle(0,0,0),
	["models/props_lab/tpplugholder_single.mdl"] = Angle(0,0,0),
	["models/bull/various/usb_socket.mdl"] = Angle(0,0,0),
	["models/hammy/pci_slot.mdl"] = Angle(0,0,0),
	["models//hammy/pci_slot.mdl"] = Angle(0,0,0), -- For some reason, GetModel on this model has two / on the client... Bug?
}
local SocketModels = {
	["models/wingf0x/isasocket.mdl"] = "models/wingf0x/isaplug.mdl",
	["models/wingf0x/altisasocket.mdl"] = "models/wingf0x/isaplug.mdl",
	["models/wingf0x/ethernetsocket.mdl"] = "models/wingf0x/ethernetplug.mdl",
	["models/wingf0x/hdmisocket.mdl"] = "models/wingf0x/hdmiplug.mdl",
	["models/props_lab/tpplugholder_single.mdl"] = "models/props_lab/tpplug.mdl",
	["models/bull/various/usb_socket.mdl"] = "models/bull/various/usb_stick.mdl",
	["models/hammy/pci_slot.mdl"] = "models/hammy/pci_card.mdl",
	["models//hammy/pci_slot.mdl"] = "models//hammy/pci_card.mdl", -- For some reason, GetModel on this model has two / on the client... Bug?
}

function ENT:GetLinkPos()
	return self:LocalToWorld(PositionOffsets[self:GetModel()] or Vector(0,0,0)), self:LocalToWorldAngles(AngleOffsets[self:GetModel()] or Angle(0,0,0))
end

function ENT:CanLink( Target )
	if (Target.Socket and Target.Socket:IsValid()) then return false end
	if (SocketModels[self:GetModel()] != Target:GetModel()) then return false end
	return true
end

function ENT:GetClosestPlug()
	local Pos, _ = self:GetLinkPos()

	local plugs = ents.FindInSphere( Pos, (CLIENT and self:GetNWInt( "AttachRange", 5 ) or self.AttachRange) )

	local ClosestDist
	local Closest

	for k,v in pairs( plugs ) do
		if (v:GetClass() == "gmod_wire_advplug" and !v:GetNWBool( "Linked", false )) then
			local Dist = v:GetPos():Distance( Pos )
			if (ClosestDist == nil or ClosestDist > Dist) then
				ClosestDist = Dist
				Closest = v
			end
		end
	end

	return Closest
end

if CLIENT then 
	function ENT:DrawEntityOutline()
		if (GetConVar("wire_advplug_drawoutline"):GetBool()) then
			self.BaseClass.DrawEntityOutline( self )
		end
	end

	hook.Add("HUDPaint","Wire_AdvSocket_DrawLinkHelperLine",function()
		local sockets = ents.FindByClass("gmod_advwire_socket")
		for k,self in pairs( sockets ) do
			local Pos, _ = self:GetLinkPos()

			local Closest = self:GetClosestPlug()

			if IsValid(Closest) and self:CanLink(Closest) and Closest:GetNWBool( "PlayerHolding", false ) and Closest:GetClosestSocket() == self then
				local plugpos = Closest:GetPos():ToScreen()
				local socketpos = Pos:ToScreen()
				surface.SetDrawColor(255,255,100,255)
				surface.DrawLine(plugpos.x, plugpos.y, socketpos.x, socketpos.y)
			end
		end
	end)
	
	return  -- No more client
end


local NEW_PLUG_WAIT_TIME = 2
local LETTERS = { "A", "B", "C", "D", "E", "F", "G", "H" }
local LETTERS_INV = {}
for k,v in pairs( LETTERS ) do
	LETTERS_INV[v] = k
end

function ENT:Initialize()
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )

	self:SetNWBool( "Linked", false )

	self.Memory = {}
end

function ENT:Setup( InputType, WeldForce, AttachRange )
	local old = self.InputType
	self.InputType = InputType or "NORMAL"

	if (!self.Inputs or !self.Outputs or self.InputType != old) then
		if InputType != "NORMAL" then
			self.Inputs = WireLib.CreateInputs( self, { "In ["..InputType.."]" } )
			self.Outputs = WireLib.CreateOutputs( self, { "Out ["..InputType.."]" } )
		else
			self.Inputs = WireLib.CreateInputs( self, LETTERS )
			self.Outputs = WireLib.CreateOutputs( self, LETTERS )
		end
	end

	self.WeldForce = WeldForce or 5000
	self.AttachRange = AttachRange or 5
	self:SetNWInt( "AttachRange", self.AttachRange )

	self:ShowOutput()
end

function ENT:TriggerInput( name, value )
	if (self.Plug and self.Plug:IsValid()) then
		self.Plug:SetValue( name, value )
	end
	self:ShowOutput()
end

function ENT:SetValue( name, value )
	if (!self.Plug or !self.Plug:IsValid()) then return end
	if (name == "In") then
		if InputType != "NORMAL" then
			WireLib.TriggerOutput( self, "Out", value )
		else
			for i = 1, #LETTERS do
				local val = (value or {})[i]
				
				WireLib.TriggerOutput( self, LETTERS[i], val )
			end
		end
	else
		if value != nil then
			if InputType != "NORMAL" then
				local data = table.Copy( self.Outputs.Out.Value )
				data[LETTERS_INV[name]] = value
				WireLib.TriggerOutput( self, "Out", data )
			else
				WireLib.TriggerOutput( self, name, value )
			end
		end
	end
	self:ShowOutput()
end

------------------------------------------------------------
-- WriteCell
-- Hi-speed support
------------------------------------------------------------
function ENT:WriteCell( Address, Value, WriteToMe )
	if (WriteToMe) then
		self.Memory[Address or 1] = Value or 0
		return true
	else
		if (self.Plug and self.Plug:IsValid()) then
			self.Plug:WriteCell( Address, Value, true )
			return true
		else
			return false
		end
	end
end

------------------------------------------------------------
-- ReadCell
-- Hi-speed support
------------------------------------------------------------
function ENT:ReadCell( Address )
	return self.Memory[Address or 1] or 0
end

function ENT:ResetValues()
	if self.InputType != "NORMAL" then
		local value
		
		if self.InputType == "STRING" then
			value = ""
		elseif self.InputType == "VECTOR" then
			value = Vector(0, 0, 0)
		elseif self.InputType == "ANGLE" then
			value = Angle(0, 0, 0)
		elseif self.InputType == "ENTITY" then
			value = nil
		elseif self.InputType == "NORMAL" then
			value = 0
		else
			value = {}
		end
		
		WireLib.TriggerOutput( self, "Out", value )
	else
		for i = 1, #LETTERS do
			WireLib.TriggerOutput( self, LETTERS[i], 0 )
		end
	end
		
	self.Memory = {}
	self:ShowOutput()
end

------------------------------------------------------------
-- ResendValues
-- Resends the values when plugging in
------------------------------------------------------------
function ENT:ResendValues()
	if (!self.Plug) then return end
	if InputType != "NORMAL" then
		self.Plug:SetValue( "In", self.Inputs.In.Value )
	else
		for i = 1, #LETTERS do
			self.Plug:SetValue( LETTERS[i], self.Inputs[LETTERS[i]].Value )
		end
	end
end

------------------------------------------------------------
-- Think
-- Find nearby plugs and connect to them
------------------------------------------------------------
function ENT:Think()
	self.BaseClass.Think(self)

	if (!self.Plug or !self.Plug:IsValid()) then -- Has not been linked or plug was deleted
		local Pos, Ang = self:GetLinkPos()

		local Closest = self:GetClosestPlug()

		self:SetNWBool( "Linked", false )

		if (Closest and Closest:IsValid() and self:CanLink( Closest ) and !Closest:IsPlayerHolding() and Closest:GetClosestSocket() == self) then
			self.Plug = Closest
			Closest.Socket = self

			-- Move
			Closest:SetPos( Pos )
			Closest:SetAngles( Ang )

			-- Weld
			local weld = constraint.Weld( self, Closest, 0, 0, self.WeldForce, true )
			if (weld and weld:IsValid()) then
				Closest:DeleteOnRemove( weld )
				self:DeleteOnRemove( weld )
				self.Weld = weld
			end

			-- Resend all values
			Closest:ResendValues()
			self:ResendValues()

			Closest:SetNWBool( "Linked", true )
			self:SetNWBool( "Linked", true )
		end

		self:NextThink( CurTime() + 0.05 )
		return true
	else
		if (self.Weld and !self.Weld:IsValid()) then -- Plug was unplugged
			self.Weld = nil

			self.Plug:SetNWBool( "Linked", false )
			self:SetNWBool( "Linked", false )

			self.Plug.Socket = nil
			self.Plug:ResetValues()

			self.Plug = nil
			self:ResetValues()

			self:NextThink( CurTime() + NEW_PLUG_WAIT_TIME )
			return true
		end
	end
end

function ENT:ShowOutput()
	local OutText = "Socket [" .. self:EntIndex() .. "]\n"
	
	if self.InputType == "STRING" then
		OutText = OutText .. "String input/outputs."
	elseif self.InputType == "VECTOR" then
		OutText = OutText .. "Vector input/outputs."
	elseif self.InputType == "ANGLE" then
		OutText = OutText .. "Angle input/outputs."
	elseif self.InputType == "ENTITY" then
		OutText = OutText .. "Entity input/outputs."
	elseif self.InputType == "NORMAL" then
		OutText = OutText .. "Number input/outputs."
	elseif self.InputType == "WIRELINK" then
		OutText = OutText .. "Wirelink input/outputs."
	elseif self.InputType == "VECTOR2" then
		OutText = OutText .. "2D Vector input/outputs."
	elseif self.InputType == "VECTOR4" then
		OutText = OutText .. "4D Vector input/outputs."
	elseif self.InputType == "ARRAY" then
		OutText = OutText .. "Array input/outputs."
	end
	
	if (self.Socket and self.Socket:IsValid()) then
		OutText = OutText .. "\nLinked to socket [" .. self.Socket:EntIndex() .. "]"
	end
	self:SetOverlayText(OutText)
end

duplicator.RegisterEntityClass( "gmod_wire_advsocket", WireLib.MakeWireEnt, "Data", "InputType", "WeldForce", "AttachRange" )

------------------------------------------------------------
-- Adv Duplicator Support
------------------------------------------------------------
function ENT:BuildDupeInfo()
	local info = self.BaseClass.BuildDupeInfo(self) or {}

	info.Socket = {}
	info.Socket.InputType = self.InputType
	info.Socket.WeldForce = self.WeldForce
	info.Socket.AttachRange = self.AttachRange
	if (self.Plug) then info.Socket.Plug = self.Plug:EntIndex() end

	return info
end

local function FindConstraint( ent, plug )
	timer.Simple(0.5,function()
		if IsValid(ent) and IsValid(plug) then
			local welds = constraint.FindConstraints( ent, "Weld" )
			for k,v in pairs( welds ) do
				if (v.Ent2 == plug) then
					ent.Weld = v.Constraint
					return
				end
			end
			local welds = constraint.FindConstraints( plug, "Weld" )
			for k,v in pairs( welds ) do
				if (v.Ent2 == ent) then
					ent.Weld = v.Constraint
					return
				end
			end
		end
	end)
end

function ENT:ApplyDupeInfo(ply, ent, info, GetEntByID, GetConstByID)
	self.BaseClass.ApplyDupeInfo(self, ply, ent, info, GetEntByID)

	if (info.Socket) then
		ent:Setup( info.Socket.InputType, info.Socket.WeldForce, info.Socket.AttachRange )
		local plug = GetEntByID( info.Socket.Plug )
		if IsValid(plug) then
			ent.Plug = plug
			plug.Socket = ent
			ent.Weld = { ["IsValid"] = function() return true end }

			plug:SetNWBool( "Linked", true )
			ent:SetNWBool( "Linked", true )

			if GetConstByID then
				if info.Socket.Weld then
					ent.Weld = GetConstByID( info.Socket.Weld )
				end
			else
				FindConstraint( ent, plug )
			end
		end
	else -- OLD DUPES COMPATIBILITY
		ent:Setup() -- default values

		-- Attempt to find connected plug
		timer.Simple(0.5,function()
			local welds = constraint.FindConstraints( ent, "Weld" )
			for k,v in pairs( welds ) do
				if (v.Ent2:GetClass() == "gmod_wire_advplug") then
					ent.Plug = v.Ent2
					v.Ent2.Socket = ent
					ent.Weld = v.Constraint
					ent.Plug:SetNWBool( "Linked", true )
					ent:SetNWBool( "Linked", true )
				end
			end
		end)
	end -- /OLD DUPES COMPATIBILITY
end
