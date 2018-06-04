
local function needs_testing()
	return error("function needs testing")
end

local function steamid()
	return LocalPlayer():SteamID64()
end

/*
    Item Slots
*/

function MOAT_INV:GetSlotForItem(id, fn)
	needs_testing()
	local query = self.SQL:CreateQuery("SELECT slotid FROM mg_slots WHERE c = ? AND steamid = ?!;", id, steamid())
	self.SQL:Query(query, function(succ)
		return fn(succ)
	end)
end

function MOAT_INV:Item(slot, fn)
	local query = self.SQL:CreateQuery("SELECT c FROM mg_slots WHERE slotid = ? AND steamid = ?!;", slot, steamid())
	self.SQL:Query(query, function(succ)
		return fn(succ and tonumber(succ.c) or nil)
	end)
end

function MOAT_INV:ItemL(slot, fn)
	assert(slot < 0, "Loadout slot incorrect value")
	self:Item(slot, fn)
end

function MOAT_INV:SaveItemLSlot(id, slot, fn)
	assert(slot < 0, "Loadout slot incorrect value")
	self:SaveItemSlot(id, slot, fn)
end


function MOAT_INV:SaveItemSlot(id, slot, fn)
	local query = self.SQL:CreateQuery("REPLACE INTO mg_slots (slotid, c, steamid) values (?, ?, ?!)", slot, id, steamid())
	self.SQL:Query(query, fn)
end

function MOAT_INV:SwapItemSlot(id, id2, fn)
	self:GetOurItems(function(sn, cache)
		self:SwapSlotItem(cache.c[id], cache.c[id2])
	end)
end

function MOAT_INV:ClearItemSlot(id, fn)
	needs_testing()
	local query = self.SQL:CreateQuery("DELETE FROM mg_slots WHERE c = ? AND steamid = ?!;", id, steamid())
	self.SQL:Query(query, fn)
end

function MOAT_INV:GetItemForSlot(slot, fn)
	local query = self.SQL:CreateQuery("SELECT c FROM mg_slots WHERE slotid = ? AND steamid = ?!;", slot, steamid())
	self.SQL:Query(query, function(d)
		return fn(d and tonumber(d.c) or 0)
	end)
end

function MOAT_INV:SlotExists(slot, fn)
	local query = self.SQL:CreateQuery("SELECT c FROM mg_slots WHERE slotid = ? AND steamid = ?!;", slot, steamid())
	self.SQL:Query(query, function(d)
		local function Internal()
			return fn(d and d[1] and d[1].c ~= "0" or false)
		end
		if (d and d[1] and d[1].c == "0") then
			self.SQL:Query("DELETE FROM mg_slots WHERE c = 0;", Internal)
		else
			Internal()
		end
	end)
end

function MOAT_INV:SaveSlotItem(slot, id, fn)
	return self:SlotExists(slot, function(exists)
		assert(not exists, "slot already exists!")
		local query = self.SQL:CreateQuery([[
			INSERT INTO mg_slots (c, slotid, steamid) VALUES (?, ?, ?!);
		]], id, slot, steamid())
		return self.SQL:Query(query, function()
			if (not M_INV_SLOT[slot]) then
				return self:GetOurSlots(function(max)
					return self:CreateNewSlots_CompleteRows(slot - max, fn)
				end)
			else
				return fn()
			end
		end)
	end)
end

function MOAT_INV:MassSwapInventory(new_slots, fn)
	return self:GetOurSlots(function(max, cache)
		for k in pairs(cache.s) do
			cache.s[k] = new_slots[k] or 0
		end
		for slot, id in pairs(new_slots) do
			cache.c[id] = slot
		end

		local query = "DELETE FROM mg_slots;\n"
		local template = "INSERT INTO mg_slots (c, slotid, steamid) VALUES "
		local values_template = "(?, ?, ?!)"
		local cur_values = {}
		for slotid, weaponid in pairs(new_slots) do
			table.insert(cur_values, self.SQL:CreateQuery(values_template, weaponid, slotid, steamid()))
			if (#cur_values == 500) then
				query = query..template..table.concat(cur_values, ",\n")..";\n"
				cur_values = {}
			end
		end
		query = query..template..table.concat(cur_values, ",\n")..";\n"

		self.SQL:Query(query, fn)
	end)
end

function MOAT_INV:SwapSlotItem(slot, slot2, fn)
	return self:GetOurSlots(function(max, cache)
		local item1, item2 = cache.s[slot], cache.s[slot2]
		if (item1 == 0) then
			assert(item2 ~= 0, "never should happen")
			return self:SwapSlotItem(slot2, slot, fn)
		end
		assert(item1 ~= 0, "item1 is 0")
		local query = self.SQL:CreateQuery(item2 ~= 0 and [[
			UPDATE mg_slots SET c = ?item2 WHERE slotid = ?slot1 AND steamid = ?!steamid;
			UPDATE mg_slots SET c = ?item1 WHERE slotid = ?slot2 AND steamid = ?!steamid;
		]] or [[
			DELETE FROM mg_slots WHERE slotid = ?slot1 and steamid = ?steamid!;
			REPLACE INTO mg_slots (c, slotid, steamid) VALUES (?item1, ?slot2, ?!steamid);
		]], {
			slot1 = slot,
			slot2 = slot2,
			item1 = item1,
			item2 = item2,
			steamid = steamid()
		})

		return self.SQL:Query(query, function()
			cache.s[slot], cache.s[slot2] = item2, item1
			cache.c[item1], cache.c[item2] = slot2, slot
			return fn and fn(max, cache) or nil
		end)
	end)
end

function MOAT_INV:ClearSlotItem(slot, fn)
	local query = self.SQL:CreateQuery("DELETE FROM mg_slots WHERE slotid = ? AND steamid = ?!;", slot, steamid())
	self.SQL:Query(query, fn)
end

function MOAT_INV:AddSlotItem(slot, id, fn)
	self:SaveSlotItem(slot, id, fn)
end

function MOAT_INV:SaveSlotItemL(slot, id, fn)
	assert(slot < 0)
	self:SaveSlotItem(slot, id, fn)
end


function MOAT_INV:AddLocked(id, fn)
	local query = self.SQL:CreateQuery("UPDATE mg_slots SET locked = 1 WHERE c = ? AND steamid = ?!;", id, steamid())
	self.SQL:Query(query, fn)
end

function MOAT_INV:RemoveLocked(id, fn)
	local query = self.SQL:CreateQuery("UPDATE mg_slots SET locked = 0 WHERE c = ? AND steamid = ?!;", id, steamid())
	self.SQL:Query(query, fn)
end

function MOAT_INV:IsLocked(id, fn)
	local query = self.SQL:CreateQuery("SELECT locked FROM mg_slots WHERE c = ? AND steamid = ?!;", id, steamid())
	self.SQL:Query(query, function(d)
		fn(d and d[1] and d[1].locked == "1" or false)
	end)
end
local m_SlotToLoadout = {}
hook.Add("Initialize", "MOAT_INV.Swap", function()
	m_SlotToLoadout[WEAPON_MELEE] = 3
	m_SlotToLoadout[WEAPON_PISTOL] = 2
	m_SlotToLoadout[WEAPON_HEAVY] = 1
end)
if (WEAPON_MELEE) then
	m_SlotToLoadout[WEAPON_MELEE] = 3
	m_SlotToLoadout[WEAPON_PISTOL] = 2
	m_SlotToLoadout[WEAPON_HEAVY] = 1
end

local function m_GetLoadoutSlot(ITEM_TBL)
	local item = ITEM_TBL.item

	if (ITEM_TBL.c == nil) then return end
	if (item.Kind == "Power-Up") then return 4 end
	if (item.Kind == "Other") then return 5 end
	if (item.Kind == "Hat") then return 6 end
	if (item.Kind == "Mask") then return 7 end
	if (item.Kind == "Body") then return 8 end
	if (item.Kind == "Effect") then return 9 end
	if (item.Kind == "Model") then return 10 end
	if (not ITEM_TBL.w) then return end

	return m_SlotToLoadout[weapons.Get(ITEM_TBL.w).Kind]
end

function MOAT_INV:SortSlots(sort, callback)
	self:GetOurSlots(function(_, items)
		local sorting_table = {}

		for slotid, weaponid in pairs(items.s) do
			-- skip loadout
			if (slotid < 0) then
				continue
			end

			local wpn = m_ItemCache[weaponid]

			if (not wpn) then
				continue
			end

			local friendly = {}
			friendly.id = weaponid

			--[[ -- Do people need stats?
			if (wpn.s) then
				friendly.Stats = {}
				for statid, statval in pairs(wpn.s) do
					friendly.Stats[self:GetStatName(statid)] = statval
				end
			end
			]]

			friendly.itemid = wpn.u
			friendly.w = wpn.w

			assert(wpn.item, "No item for weapon")

			friendly.tier = wpn.item.Rarity or 0
			friendly.slot = m_GetLoadoutSlot(wpn) or 0

			friendly.slotid = slotid
			friendly.rand = math.random()

			table.insert(sorting_table, friendly)
		end
		local empty = setmetatable({}, {__newindex = {}, __index  = {id = 0}})
		sort(sorting_table, empty)

		callback(sorting_table)
	end)
end

function MOAT_INV:GetOurSlots(fn)
	if (self.CachedSlots and self.CachedSlots[1] and self.CachedSlots[2]) then
		return fn(self.CachedSlots[1], self.CachedSlots[2])
	end

	if (self.SlotCache) then
		table.insert(self.SlotCache, fn)
		return
	end

	self.SlotCache = {fn}

	local query = self.SQL:CreateQuery("SELECT slotid, c FROM mg_slots WHERE steamid = ?!;", steamid())

	local function Internal()
		self.SQL:Query(query, function(data)
			if (not data) then
				data = {}
			end
			local cache = {
				c = {}, -- id -> slot
				s = {}, -- slot -> id
			}
			local max = self.Config.MinSlots
			for _, dat in pairs(data) do
				local slotid = tonumber(dat.slotid)
				local id = tonumber(dat.c)
				if (not m_ItemCache[id]) then
					continue
				end
				max = math.max(slotid, max)
				cache.c[id] = slotid
				cache.s[slotid] = id
			end

			for i = -10, max do
				if (not cache.s[i]) then
					cache.s[i] = 0
				end
			end

			self.CachedSlots = {
				max,
				cache
			}

			for i = 1, #self.SlotCache do
				self:GetOurSlots(self.SlotCache[i])
			end
		end)
	end
	if (self.AllowSlotLoad) then
		return Internal()
	else
		self.AllowSlotLoad = Internal
	end
end

-- c = id -> slot
-- s = slot -> id

MOAT_INV.ColumnCount = 5

function MOAT_INV:CreateNewSlots_CompleteRows(num, fn)
	return self:GetOurSlots(function(max)
		local needed = math.ceil((max + num) / 5) * 5 - max
		for i = 1, needed do
			self:CreateNewSlot()
		end
		return fn()
	end)
end

function MOAT_INV:CreateNewSlot()
	return self:GetOurSlots(function(max, cache)
		local new = max + 1
		self:ClearSlotItem(num)
		self.CachedSlots[1] = math.max(max, new)
		cache.s[new] = 0

		m_Inventory[new] = {}
		if (IsValid(MOAT_INV_BG)) then
			m_CreateNewInvSlot(new)
		end
	end)
end

function MOAT_INV:GetEmptySlot(sn, st, r, fn)
	local function Internal(sn, st)
		local starts, ends, step = 1, sn, 1
		if (r) then
			starts, ends, step = sn, 1, -1
		end

		for i = starts, ends, step do
			if (st.s[i] == 0) then
				return fn(i)
			end
		end

		local new_max = sn + 1
		st.s[new_max] = 0

		if (not M_INV_SLOT[new_max]) then
			self:GetOurSlots(function(max)
				self:CreateNewSlots_CompleteRows(new_max - max, function()
					return fn(new_max)
				end)
			end)
		else
			return fn(new_max)
		end
	end
	if (not sn or not st) then
		return self:GetOurSlots(Internal)
	else
		return Internal(sn, st)
	end
end

function MOAT_INV:GetSlotForID(id, fn)
	assert(id ~= 0, "id is 0")
	self:GetOurSlots(function(sn, st)
		if (st.c[id]) then return fn(st.c[id]) end

		self:GetEmptySlot(sn, st, false, function(ns)
			st.c[id] = ns
			st.s[ns] = id

			self:AddSlotItem(ns, id, function()
				return fn(ns)
			end)
		end)
	end)
end

function MOAT_INV:RemoveItemSlot(slot, fn)
	self:GetOurSlots(function(max, cache)
		local query = self.SQL:CreateQuery("DELETE FROM mg_slots WHERE slotid = ? AND steamid = ?!", slot, steamid())
		self.SQL:Query(query, function()
			cache.c[cache.s[slot]] = nil
			cache.s[slot] = 0

			m_Inventory[slot] = {}

			if (m_isUsingInv() and M_INV_SLOT[slot] and M_INV_SLOT[slot].VGUI) then
				M_INV_SLOT[slot].VGUI.Item = nil
				M_INV_SLOT[slot].VGUI.WModel = nil
				M_INV_SLOT[slot].VGUI.MSkin = nil
				M_INV_SLOT[slot].VGUI.SIcon:SetVisible(false)
				M_INV_SLOT[slot].VGUI.SIcon:SetModel("")
			end
			return fn()
		end)
	end)
end