local nametags = {}
local tag_settings = {}
local ATTACH_POSITION = minetest.rgba and {x=0,y=20,z=0} or {x=0,y=10,z=0}

local TYPE_BUILTIN = 0
local TYPE_ENTITY = 1

playertag = {
	TYPE_BUILTIN = TYPE_BUILTIN,
	TYPE_ENTITY  = TYPE_ENTITY,
}

-- char widths
local width = {
	a=10,b=9,c=8,d=9,e=9,f=6,g=9,h=9,i=3,j=4,k=9,l=3,m=13,
	n=9,o=9,p=9,q=9,r=6,s=8,t=6,u=9,v=9,w=13,x=8,y=10,z=7,A=12,B=11,
	C=12,D=12,E=11,F=10,G=13,H=12,I=3,J=9,K=11,L=9,M=14,N=12,O=13,P=11,
	Q=13,R=12,S=11,T=13,U=12,V=11,W=18,X=10,Y=11,Z=10
}
width["0"] = 9; width["1"] = 9; width["2"] = 9; width["3"] = 9
width["4"] = 10; width["5"] = 9; width["6"] = 9; width["7"] = 9
width["8"] = 9; width["9"] = 9; width["-"] = 5; width["_"] = 7

local function add_entity_tag(player, color)
	local ent = minetest.add_entity(player:get_pos(), "playertag:tag")

	-- Build name from font texture
	local name = player:get_player_name()
	local texture = "npcf_tag_bg.png"
	local l = 0
	name:gsub(".", function(char)
		if char == 'j' then l = l - 1 end
		l = l + width[char]
	end)
	local x = math.floor(134 - (l / 2)) - 1
	local i = 0
	name:gsub(".", function(char)
		if char:byte() > 64 and char:byte() < 91 then
			char = "U"..char
		end
		if i > 0 and char == 'j' then i = i - 1 end
		texture = texture.."^[combine:84x16:"..(x+i)..",0=W_"..char..".png"
		i = i + width[char]
	end)

	color = color or "#FFFFFFFF" -- init if reqd
	texture = texture .. "^[colorize:" .. color
	ent:set_properties({ textures={texture} })

	-- Attach to player
	ent:set_attach(player, "", ATTACH_POSITION, {x=0,y=0,z=0})
	ent:get_luaentity().wielder = name

	-- Store
	nametags[name] = ent

	-- Hide fixed nametag
	player:set_nametag_attributes({
		color = {a = 0, r = 0, g = 0, b = 0}
	})
end

local function remove_entity_tag(player)
	tag_settings[player:get_player_name()] = nil
	local tag = nametags[player:get_player_name()]
	if tag then
		tag:remove()
		nametags[player:get_player_name()] = nil
	end
end

local function update(player, settings)
	tag_settings[player:get_player_name()] = settings

	if settings.type == TYPE_BUILTIN then
		remove_entity_tag(player)
		player:set_nametag_attributes({
			color = settings.color
		})
	elseif settings.type == TYPE_ENTITY then
		add_entity_tag(player, settings.color)
	end
end

function playertag.set(player, type, color)
	local oldset = tag_settings[player:get_player_name()]
	color = color or { a=255, r=255, g=255, b=255 }
	if not oldset or oldset.type ~= type or oldset.color ~= color then
		update(player, { type = type, color = color })
	end
end

function playertag.get(player)
	return tag_settings[player:get_player_by_name()]
end

function playertag.get_all()
	return tag_settings
end

minetest.register_entity("playertag:tag", {
	initial_properties = {
		npcf_id = "nametag",
		physical = false,
		collisionbox = {x=0, y=0, z=0},
		visual = "sprite",
		textures = {"default_dirt.png"},--{"npcf_tag_bg.png"},
		visual_size = {x=2.16, y=0.18, z=2.16},--{x=1.44, y=0.12, z=1.44},
	},
	on_activate = function(self, staticdata)
		if staticdata == "expired" then
			local name = self.wielder and self.wielder:get_player_name()
			if name and nametags[name] == self.object then
				nametags[name] = nil
			end

			self.object:remove()
		end
	end,
	on_step = function(self, dtime, ...)
		local name = self.wielder
		local wielder = name and minetest.get_player_by_name(name)
		if not wielder then
			self.object:remove()
		elseif not tag_settings[name]
		or tag_settings[name].type ~= TYPE_ENTITY then
			if name and nametags[name] == self.object then
				nametags[name] = nil
			end

			self.object:remove()
		end
	end,
	get_staticdata = function(self)
		return "expired"
	end
})

local function step()
	-- Periodically loop through connected players checking
	--	a) entity is valid
	--	b) it's attached
	for _, player in pairs(minetest.get_connected_players()) do
		local settings = tag_settings[player:get_player_name()]
		if settings and settings.type == TYPE_ENTITY then
			local ent = nametags[player:get_player_name()]
			if not ent or ent:get_luaentity() == nil then
				add_entity_tag(player)
			else
				ent:set_attach(player, "", ATTACH_POSITION, {x=0,y=0,z=0})
			end
		end
	end

	minetest.after(10, step)
end
minetest.after(10, step)

minetest.register_on_joinplayer(function(player)
	-- use alpha channel to make default nametag invisible
	playertag.set(player, TYPE_BUILTIN, {a = 0, r = 255, g = 255, b = 255})
	-- Initiate timer to add entity nametag
	minetest.after(2, function(name)
		player = minetest.get_player_by_name(name)
		if player then
			playertag.set(player, TYPE_ENTITY, "#FFFFFFFF")
		end
	end, player:get_player_name())
end)

minetest.register_on_leaveplayer(function(player)
	remove_entity_tag(player)
end)
