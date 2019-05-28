local storage = minetest.get_mod_storage()

local death_timer = {}
local players
local player_objs = {}

local initial_timeout = tonumber(minetest.settings:get("death_timer.initial_timeout")) or 8
local timeout = tonumber(minetest.settings:get("death_timer.timeout")) or 1
local timeout_reduce_loop = tonumber(minetest.settings:get("death_timer.timeout_reduce_loop")) or 3600
local timeout_reduce_rate = tonumber(minetest.settings:get("death_timer.timeout_reduce_rate")) or 1
local ekey = minetest.get_us_time()

players = minetest.deserialize(storage:get_string("players"))

if not players then
	players = {}
	storage:set_string("players", minetest.serialize(players))
end

function death_timer.create_deathholder(player, name)
	local obj = player_objs[name]
	if player and obj then
		local pos = player:get_pos()
		player:set_attach(obj, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
		obj:set_pos(pos)
		player_objs[name] = obj
	elseif player and not obj then
		local pos = player:get_pos()
		obj = minetest.add_entity(pos, "death_timer:death")
		player:set_attach(obj, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
		obj:set_pos(pos)
		player_objs[name] = obj
	end
end

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local p = players[name]
	if p and p.time > 1 then
		death_timer.create_deathholder(player, name)
		
		if not cloaking.hide_player then
			if not players[name].properties then
				players[name].properties = player:get_properties()
			end
	
			player:set_properties({
				visual_size    = {x = 0, y = 0},
				["selectionbox"] = {0, 0, 0, 0, 0, 0},
			})
		else
			cloaking.hide_player(player)
		end

		death_timer.loop(name)
	end
end)

minetest.register_entity("death_timer:death", {
	is_visible = false,
	key = 0,
	get_staticdata = function(self)
		return minetest.serialize({key = self.key})
	end,
	on_activate = function(self, staticdata)
		local ds = minetest.deserialize(staticdata)
		if not (ds and ds.key and ds.key == ekey) then
			self.object:remove()
		end
	end
})

function death_timer.reduce_loop()
	for k, v in pairs(players) do
		if players[k].longtime > 0 then
			players[k].longtime = players[k].longtime - timeout_reduce_rate
			if players[k].longtime < 0 then
				minetest.after(0, function(k) players[k] = nil end, k)
			end
		else
			minetest.after(0, function(k) players[k] = nil end, k)
		end
	end

	minetest.after(1, function() storage:set_string("players", minetest.serialize(players)) end)
	
	minetest.after(timeout_reduce_loop, death_timer.reduce_loop)
end

function death_timer.loop(name)
	local p = players[name]
	p.time = p.time - 1
	if p.time < 1 then
		local formspec = "size[11,5.5]bgcolor[#320000b4;true]" ..
		"label[4.85,1.35;Wait" ..
		"]button_exit[4,3;3,0.5;death_button;Play" .."]"

		minetest.show_formspec(name, "death_timer:death_screen", formspec)

		minetest.after(0, function(players, name) 
			local p = minetest.get_player_by_name(name)
			if p then
				p:set_detach()
				player_objs[name]:remove()
				player_objs[name] = nil
			end
		end, players, name)

		if p.interact ~= nil then
			local privs = minetest.get_player_privs(name)
			privs.interact = p.interact
			p.interact = nil
			minetest.set_player_privs(name, privs)
		end
		if not cloaking.unhide_player then
			if p.properties then
				local player = minetest.get_player_by_name(name)
				player:set_properties(p.properties)
				p.properties = nil
			end
		else
			local player = minetest.get_player_by_name(name)
			cloaking.unhide_player(player)
		end

		p.time = nil

		players[name] = p

		storage:set_string("players", minetest.serialize(players))
	else
		local formspec = "size[11,5.5]bgcolor[#320000b4;true]" ..
			"label[4.85,1.35;Wait" ..
			"]button[4,3;3,0.5;death_button;" .. p.time .."]"
		minetest.show_formspec(name, "death_timer:death_screen", formspec)
		minetest.after(1, death_timer.loop, name)
	end
end

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()

	if player_objs[name] then
		player:set_detach()
		player_objs[name]:remove()
		player_objs[name] = nil
	end
end)

minetest.register_on_dieplayer(function(player)
	local name = player:get_player_name()
	local privs = minetest.get_player_privs(name)
	local pos = player:get_pos()

	if not players[name] then
		players[name] = {}
		players[name].longtime = initial_timeout
	end

	players[name].interact = privs.interact
	players[name].time = players[name].longtime + timeout
	players[name].longtime = players[name].time
	
	if not cloaking.hide_player then
		if not players[name].properties then
			players[name].properties = player:get_properties()
		end

		player:set_properties({
			visual_size    = {x = 0, y = 0},
			["selectionbox"] = {0, 0, 0, 0, 0, 0},
		})
	else
		cloaking.hide_player(player)
	end

	privs.interact = false

	minetest.set_player_privs(name, privs)

	storage:set_string("players", minetest.serialize(players))
end)

minetest.register_on_respawnplayer(function(player)
	local name = player:get_player_name()

	minetest.after(0, function(name)
		local player = minetest.get_player_by_name(name)
		death_timer.create_deathholder(player, name)
	end, name)

	local formspec

	if players[name] and players[name].time then
		formspec = "size[11,5.5]bgcolor[#320000b4;true]" ..
		"label[4.85,1.35;Wait" ..
		"]button[4,3;3,0.5;death_button;" .. players[name].time .."]"
	else
		formspec = "size[11,5.5]bgcolor[#320000b4;true]" ..
		"label[4.85,1.35;Wait" ..
		"]button_exit[4,3;3,0.5;death_button;Play" .."]"
	end

	minetest.after(1, minetest.show_formspec, name, "death_timer:death_screen", formspec)
	minetest.after(2, death_timer.loop, name)
end)

minetest.after(timeout_reduce_loop, death_timer.reduce_loop)
