require("bromsock")

if client then client:Close() end
client = BromSock()

if server then server:Close() end
server = BromSock()

local funcs = {}
local dataqueue = {}
local sendqueue = {}
local propstosync = {}
local syncedprops = {}
local sendbuffer = {}
local receivebuf = {}
local flipflop = false
local g_clientsock

if (not server:Listen(27057)) then
	print("[BS:S] Failed to listen!")
else
	print("[BS:S] Server listening...")
end

local function generateInitialPacket(packet)
	local plys = {}
	local props = {}
	for k,v in pairs(player.GetAll()) do
		if not v:IsBot() then
			plys[v:GetCreationID()] = {
				name = v:Name(),
				steamid = v:SteamID(),
				pos = v:GetPos(),
				ang = v:GetAngles(),
				vel = v:GetVelocity(),
				alive = v:Alive()
			}
		end
	end
	
	for k,v in pairs(ents.GetAll()) do
		if IsValid(v) && IsValid(v:GetNWEntity("Owner", NULL)) then
			props[v:GetCreationID()] = {
				model = v:GetModel(),
				owner = v:GetNWEntity("Owner"),
				pos = v:GetPos(),
				ang = v:GetAngles(),
				vel = v:GetVelocity()
			}
		end
	end
	
	packet:WriteString(util.TableToJSON({{addplayers = plys, spawnprops = props}}))
	return packet
end

local function processFuncs(tbl)
	for k,v in pairs(tbl) do
		if funcs[k] then
			funcs[k](v)
		end
	end
end

local function removenil(tbl)
	local old = table.Copy(tbl)
	table.Empty(tbl)
	for k,v in pairs(old) do
		if v != nil then
			table.insert(tbl, v)
		end
	end
end

client:SetCallbackConnect(function(sock, ret, ip, port)
	if (not ret) then
		print("[BS:C] Failed to connect to: ", ret, ip, port)
		return
	end
	
	if sock:SetOption(0x6, 0x0001, 1) == -1 then
		print("[BS:S] Setting flags failed")
	end

	print("[BS:C] Connected to server:", sock, ret, ip, port)
	
	sendqueue = {} //empty the old data from the queue since the hooks are running since server start
	
	local packet = BromPacket(client)
	packet = generateInitialPacket(packet)
	client:Send(packet)
	
	client:Receive()
end)

client:SetCallbackReceive(function(sock, packet)
	//print("[BS:C] Received:", sock, packet, packet and packet:InSize() or -1)
	//print("[BS:C] R_Str:", packet:ReadString())

	local data = util.JSONToTable(packet:ReadString())
	table.Add(receivebuf, data)
	
	client:Receive()
end)

client:SetCallbackDisconnect(function(sock)
	print("[BS:S] Disconnected:", sock)
	for k,v in pairs(player.GetBots()) do
		if v.SyncedPlayer then
			v:Kick()
		end
	end
	for k,v in pairs(syncedprops) do
		if IsValid(v) then
			v:Remove()
			v = nil
		end
	end
end)

server:SetCallbackAccept(function(serversock, clientsock)
	print("[BS:S] Accepted:", serversock, clientsock)
	g_clientsock = clientsock
	// empty sendqueue to not send dated shit
	sendqueue = {}
	
	
	if clientsock:SetOption(0x6, 0x0001, 1) == -1 then
		print("[BS:S] Setting flags failed2")
	end	

	
	//send initial update packet
	local packet = BromPacket(clientsock)
	packet = generateInitialPacket(packet)
	clientsock:Send(packet)
	
	clientsock:SetCallbackReceive(function(sock, packet)
		//print("[BS:S] R_Num:", packet:ReadString())

		local data = util.JSONToTable(packet:ReadString())
		table.Add(receivebuf, data)
		
		sock:Receive()
	end)
	
	clientsock:SetCallbackDisconnect(function(sock)
		print("[BS:S] Disconnected:", sock)
		for k,v in pairs(player.GetBots()) do
			if v.SyncedPlayer then
				v:Kick()
			end
		end
		for k,v in pairs(syncedprops) do
			if IsValid(v) then
				v:Remove()
			end
		end
	end)
	
	clientsock:SetTimeout(5000)
	clientsock:Receive()
	serversock:Accept()
end)

server:Accept()

hook.Add("Think", "testshitfuckcunt", function()
	if flipflop then
		table.Add(sendbuffer, {sendqueue})
		local packet = BromPacket()
		packet:WriteString(util.TableToJSON(sendbuffer))
		local packet2 = packet:Copy()
		
		client:Send(packet)
		if g_clientsock then
			g_clientsock:Send(packet2)
		end
		sendbuffer = {}
	else
		table.Add(sendbuffer, {sendqueue})
	end
	
	sendqueue = {}
	flipflop = !flipflop
	
	
	
	if #receivebuf > 3 then
		for i=1, #receivebuf - 1 do
			if not receivebuf[i] then continue end
			
			processFuncs(receivebuf[i])
			receivebuf[i] = nil
		end
	else
		if receivebuf[1] != nil then 
			processFuncs(receivebuf[1])
			receivebuf[1] = nil
		end
	end

	removenil(receivebuf)
end)

concommand.Add("sync_connect", function(ply, cmd, args)
	if not args[1] and IsValid(ply) then
		ply:PrintMessage(HUD_PRINTCONSOLE, "No IP given.")
		ply:PrintMessage(HUD_PRINTCONSOLE, "	Usage: sync_connect ip:port")
		ply:PrintMessage(HUD_PRINTCONSOLE, "	dedi.icedd.coffee:27057 (AU), eu.icedd.coffee:27057 (EU), la.icedd.coffee:27057 (LA)")
		return
	end
	sendqueue = {}
	client:Connect(args[1], tonumber(args[3] or 27057))
end)

concommand.Add("sync_disconnect", function()
	client:Disconnect()
end)

function GetPlayerByCreationID(id)
	for k,v in pairs(player.GetAll()) do
		if v:GetCreationID() == id then
			return v
		elseif v.SyncedPlayer and v.SyncedPlayer == id then
			return v
		end
	end
	return NULL
end

function GetBotByCreationID(id)
	for k,v in pairs(player.GetBots()) do
		if v.SyncedPlayer == id then
			return v
		end
	end
	return NULL
end

function GetPropByCreationID(id)
	for k,v in pairs(syncedprops) do
		if k == id then
			return v
		end
	end
	for k,v in pairs(propstosync) do
		if k == id then
			return v
		end
	end
	return NULL
end

// packet proccessing funcs

funcs.addplayers = function(data)
	for k,v in pairs(data) do
		RunConsoleCommand("bot")
		timer.Simple(1, function()
			for k2,v2 in pairs(player.GetBots()) do
				if not v2.SyncedPlayer then
					v2.SyncedPlayer = k
					dataqueue[k] = v
					v2:SelectWeapon("weapon_physgun")
					v2:SetWeaponColor(Vector(1,0,0))
					v2:SetNW2String("name", v.name)
					
					if v2:Alive() and !v.alive then
						v2:KillSilent()
					end
					break
				end
			end
		end)
	end
end

funcs.playerspawn = function(data)
	for k,v in pairs(data) do
		local ply = GetBotByCreationID(k)
		if IsValid(ply) then
			ply:Spawn()
			ply:SetWeaponColor(Vector(1,0,0))
		end
	end
end

funcs.playerdisconnect = function(data)
	for k,v in pairs(data) do
		for k2,v2 in pairs(player.GetBots()) do
			if v2.SyncedPlayer == k then
				v2:Kick()
			end
		end
	end
end

funcs.playerupdate = function(data)
	for k,v in pairs(data) do
		if dataqueue[k] then
			dataqueue[k] = v
		end
	end
end

funcs.playerkill = function(data)
	for k,v in pairs(data) do
		local ply = GetPlayerByCreationID(k)
		local att = GetPlayerByCreationID(v[1])
		local prop = GetPropByCreationID(v[2])
		
		if not IsValid(att) and IsValid(prop) and prop.Owner and IsValid(prop.Owner) then
			att = prop.Owner
		end
		
		print("kill:", ply, att, prop)
		if IsValid(ply) and IsValid(prop) and ply:Alive() then
			local dmg = DamageInfo()
			dmg:SetDamage(ply:Health()*1000)
			if IsValid(att) then
				dmg:SetAttacker(att)
			end
			if IsValid(prop) then
				dmg:SetInflictor(prop)
			end
			dmg:SetDamageType(DMG_CRUSH)
			
			ply:TakeDamageInfo(dmg)
			
			if ply:Alive() then
				ply:TakePhysicsDamage(dmg)
			end
			
			if ply:Alive() then
				ply:TakeDamage(ply:Health()*1000, att, IsValid(prop) and prop or att)
			end
			
			if ply:Alive() then
				print("oops they still alive")
				ply:Kill()
			end
		elseif IsValid(ply) and ply:Alive() then
			ply:Kill()
		end
	end
end

funcs.spawnprops = function(data)
	for k,v in pairs(data) do
		local prop = ents.Create("prop_physics")
		if not IsValid(prop) then continue end
		prop:SetModel(v.model or "")
		prop:SetPos(v.pos or Vector())
		prop:SetAngles(v.ang or Angle())
		prop.SyncedProp = true
		prop:Spawn()
		prop.Owner = GetPlayerByCreationID(v.owner)
		syncedprops[k] = prop
		if IsValid(prop.Owner) then
			hook.Run("PlayerSpawnedProp", prop.Owner, v.model or "", prop)
		end
	end
end

funcs.propupdate = function(data)
	for k,v in pairs(data) do
		local prop = syncedprops[k]
		
		if not IsValid(prop) then continue end
		local phys = prop:GetPhysicsObject()
		if not IsValid(phys) then continue end
		phys:EnableMotion(v.freeze)
		if not v.freeze then continue end
		phys:SetPos(v.pos)
		phys:SetAngles(v.ang)
		phys:SetVelocity(v.vel)
		phys:SetInertia(v.inr)
	end
end

funcs.removeprops = function(data)
	for k,v in pairs(data) do
		if syncedprops[k] and IsValid(syncedprops[k]) then
			syncedprops[k]:Remove()
			syncedprops[k] = nil
		end
	end
end

funcs.chatmessage = function(data)
	for k,v in pairs(data) do
		for k2,v2 in pairs(player.GetAll()) do
			v2:ChatPrint(v)
		end
	end
end

// sync hooks

hook.Add("SetupMove", "setsyncedbotpositions", function(ply, mv, cmd)
	if ply.SyncedPlayer and dataqueue[ply.SyncedPlayer] then
		local data = dataqueue[ply.SyncedPlayer]
		mv:SetOrigin(data.pos)
		ply:SetEyeAngles(Angle(data.ang))
		mv:SetVelocity(data.vel)
		mv:SetForwardSpeed(data.fws or 0)
		mv:SetSideSpeed(data.sis or 0)
		mv:SetUpSpeed(data.ups or 0)
	end
end)

hook.Add("PlayerTick", "queueplayerpositions", function(ply, mv, cmd)
	if not ply:IsBot() then
		if not sendqueue["playerupdate"] then sendqueue["playerupdate"] = {} end
		
		sendqueue.playerupdate[ply:GetCreationID()] = {
			pos = mv:GetOrigin(),
			ang = mv:GetAngles(),
			vel = mv:GetVelocity(),
			fws = mv:GetForwardSpeed(),
			sis = mv:GetSideSpeed(),
			ups = mv:GetUpSpeed()
		}
	end
end)

hook.Add("Think", "syncpropmove", function()
	if not sendqueue["propupdate"] then sendqueue["propupdate"] = {} end
	
	for k,v in pairs(propstosync) do
		local phys = v:GetPhysicsObject()
		sendqueue["propupdate"][k] = {
			pos = v:GetPos(),
			ang = v:GetAngles(),
			vel = v:GetVelocity(),
			inr = phys:GetInertia(),
			freeze = phys:IsMotionEnabled()
		}
	end
end)

hook.Add("PlayerInitialSpawn", "syncplayerspawn", function(ply)
	if not ply:IsBot() then
		if not sendqueue["addplayers"] then sendqueue["addplayers"] = {} end
		
		sendqueue["addplayers"][ply:GetCreationID()] = {
			name = ply:Name(),
			steamid = ply:SteamID(),
			pos = ply:GetPos(),
			ang = ply:GetAngles(),
			vel = ply:GetVelocity()
		}
		
		// dis be ugly af but fuk making entire script shared for 1 function
		ply:SendLua([[local p = FindMetaTable("Player")
local of = p.Name
function p:Name()
if self:IsBot() then
local name = self:GetNW2String("name", false)
if not name then
return of(self)
end
return name.."/sync"
end
return of(self)
end
p.Nick = p.Name
p.GetName = p.Name
]])
	end
end)

hook.Add("PlayerDisconnected", "syncplayerdisconnect", function(ply)
	if not sendqueue["playerdisconnect"] then sendqueue["playerdisconnect"] = {} end
	
	sendqueue["playerdisconnect"][ply:GetCreationID()] = true
end)

hook.Add("PlayerSpawnedProp", "syncpropspawns", function(ply, model, ent)
	if not sendqueue["spawnprops"] then sendqueue["spawnprops"] = {} end
	if not IsValid(ply) then return end
	if ply.SyncedPlayer then return end
	
	sendqueue["spawnprops"][ent:GetCreationID()] = {
		model = model,
		pos = ent:GetPos(),
		ang = ent:GetAngles(),
		vel = ent:GetVelocity(),
		owner = ply:GetCreationID()
	}
	
	propstosync[ent:GetCreationID()] = ent
end)

hook.Add("EntityRemoved", "syncpropremove", function(ent)
	if not sendqueue["removeprops"] then sendqueue["removeprops"] = {} end
	
	if propstosync[ent:GetCreationID()] then
		propstosync[ent:GetCreationID()] = nil
	end
	if sendqueue["spawnprops"] and sendqueue["spawnprops"][ent:GetCreationID()] then
		sendqueue["spawnprops"][ent:GetCreationID()] = nil
	end
	
	sendqueue["removeprops"][ent:GetCreationID()] = true
end)

hook.Add("PlayerSay", "syncchat", function(ply, msg)
	if not sendqueue["chatmessage"] then sendqueue["chatmessage"] = {} end
	
	table.insert(sendqueue["chatmessage"], ply:Name() .. ": " .. msg)
end)

hook.Add("PlayerDeath", "syncplayerdeath", function(vic, inf, att)
	if not sendqueue["playerkill"] then sendqueue["playerkill"] = {} end
	
	sendqueue["playerkill"][vic.SyncedPlayer and vic.SyncedPlayer or vic:GetCreationID()] = {IsValid(att) and att:GetCreationID() or NULL, IsValid(inf) and inf:GetCreationID() or NULL}
end)

hook.Add("PlayerDeathThink", "syncrespawn", function(ply)
	if ply.SyncedPlayer then
		return false
	end
end)

hook.Add("PlayerSpawn", "syncplayerspawn", function(ply)
	if not sendqueue["playerspawn"] then sendqueue["playerspawn"] = {} end
	
	if not ply.SyncedPlayer then
		sendqueue["playerspawn"][ply:GetCreationID()] = true
	else
		ply:SelectWeapon("weapon_physgun")
	end
end)

hook.Add("PlayerShouldTakeDamage", "000stopsyncedpropsdamaging", function(ply, ent)
	if IsValid(ent) then
		if ent:IsPlayer() and ent:IsBot() and ply == ent then
			return false
		end
		if ent.SyncedProp then
			return false
		end
	end
end)

hook.Add("EntityTakeDamage", "1800 STOP DYING", function(ent, dmg)
	local inflictor = dmg:GetInflictor()
	local attacker = dmg:GetAttacker()
	if inflictor.SyncedProp and not attacker.SyncedPlayer then
		return true
	end
end)

local pmeta = FindMetaTable("Player")
if originalNameFunc then return end
originalNameFunc = pmeta.Name

function pmeta:Name()
	if self:IsBot() and self.SyncedPlayer then
		local name = self:GetNW2String("name", nil)
		if not name then
			return originalNameFunc(self)
		end
		return name .. "/sync"
	end
	return originalNameFunc(self)
end

pmeta.Nick = pmeta.Name
pmeta.GetName = pmeta.Name

