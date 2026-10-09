-- DIABLO TAKEOVER: Sandy Shores airfield becomes a hellish battlefield.
-- Horned, burning demons with name plates and health bars, floating damage numbers, gold and loot beams,
-- health and mana orbs, levels with a holy nova, and THE BUTCHER. The HUD is drawn with game natives.

local WHITE, BLUE, YELLOW, ORANGE, GREEN, RED = { 255, 255, 255 }, { 110, 130, 255 }, { 255, 235, 60 }, { 255, 140, 20 }, { 120, 255, 120 }, { 255, 60, 40 }

local D = {
	list = {},                 -- ped -> demon record
	loot = {},                 -- loot records
	gold = 0, level = 1, xp = 0, kills = 0,
	hp = 1.0, mp = 1.0, potions = 3,
	boss = nil,
	started = false,
}

local TYPES = {
	{ model = 'u_m_y_zombie_01',     name = 'Fallen One',  hp = 70,  weapon = 'WEAPON_BAT' },
	{ model = 'ig_skeleton_01',      name = 'Skeleton',    hp = 60,  weapon = 'WEAPON_MACHETE' },
	{ model = 'u_m_y_imporage',      name = 'Hell Imp',    hp = 90,  weapon = 'WEAPON_BATTLEAXE' },
	{ model = 'u_m_y_juggernaut_01', name = 'Doom Knight', hp = 200, weapon = 'WEAPON_HAMMER', elite = true },
}
-- models this game build does not have are swapped for the zombie (no unknown-model errors)
for i, t in ipairs(TYPES) do
	if not IsModelInCdimage(GetHashKey(t.model)) then TYPES[i] = { model = 'u_m_y_zombie_01', name = t.name, hp = t.hp, weapon = t.weapon, elite = t.elite } end
end
local PREFIX = { 'Gore', 'Blood', 'Skull', 'Bone', 'Hell', 'Doom', 'Cinder', 'Rot', 'Dread', 'Grim' }
local SUFFIX = { 'fang', 'maw', 'claw', 'breaker', 'render', 'bite', 'gnash', 'lash', 'reaver', 'howl' }
local TITLE = { 'the Burning', 'the Unclean', 'the Mighty', 'of Sandy Shores', 'the Bald', 'the Tax Collector', 'the Fashionable' }
local ITEMS = {
	'Ballas Bandana of Haste', 'Cleaver of Carnage', 'Los Santos Leather Gloves', 'Ring of Questionable Taste',
	'Helm of the Desert Sun', 'Boots of Reckless Driving', 'Amulet of Free Parking', 'Stonefist Knuckles',
	'Shotgun Shell Necklace', 'Mantle of the Airfield', 'Sandy Shores Signet', 'Belt of Many Burritos',
}

local function pick(t) return t[math.random(#t)] end

-- ---------- HUD state (drawn every frame with natives) ----------
local H = { title = nil, titleAt = 0, banner = nil, bannerAt = 0, boss = nil, bosshp = 1.0, pulseHp = 0, pulseMp = 0, msgs = {} }
local function msg(text, color) H.msgs[#H.msgs + 1] = { t = text, c = color or WHITE, at = GetGameTimer() } if #H.msgs > 4 then table.remove(H.msgs, 1) end end
local function title(text) H.title, H.titleAt = text, GetGameTimer() end
local function banner(text) H.banner, H.bannerAt = text, GetGameTimer() end

local function txt(s, x, y, scale, c, font, a, center)
	SetTextFont(font or 4)
	SetTextScale(0.0, scale)
	SetTextColour(c[1], c[2], c[3], a or 255)
	SetTextOutline()
	SetTextCentre(center ~= false)
	BeginTextCommandDisplayText('STRING')
	AddTextComponentSubstringPlayerName(s)
	EndTextCommandDisplayText(x, y)
end

local function orb(img, cx, cy, frac, pulse, label)
	local rw, rh = GetActualScreenResolution()
	local asp = rh / rw
	local h = 0.30 * (1.0 + 0.12 * pulse)
	local w = h * asp
	local dict, name = Sigf.Image(img)
	DrawSprite(dict, name, cx, cy, w, h, 0.0, 255, 255, 255, 255)
	-- empty part of the glass: dark slices that follow the circle
	local r = 0.235 * h
	local gx, gy = cx, cy - 0.01 * h
	local level = gy + r - frac * 2 * r
	local n = 24
	local dy = 2 * r / n
	for k = 0, n - 1 do
		local y0 = gy - r + k * dy
		local ym = y0 + dy / 2
		if ym < level then
			local half = math.sqrt(math.max(0.0, r * r - (ym - gy) ^ 2))
			DrawRect(gx, ym, 2 * half * asp, dy * 1.05, 12, 2, 2, 235)
		end
	end
	DrawRect(gx, level, 2 * math.sqrt(math.max(0.0, r * r - (level - gy) ^ 2)) * asp, 0.002, 255, 255, 255, 120)
	txt(label, cx, cy - 0.025, 0.7, WHITE, 4)
end

local function drawHud(now)
	-- orbs in the bottom corners
	local pH = math.max(0.0, 1.0 - (now - H.pulseHp) / 500)
	local pM = math.max(0.0, 1.0 - (now - H.pulseMp) / 500)
	orb('orb_red', 0.095, 0.865, D.hp, pH, tostring(math.floor(D.hp * 100)))
	orb('orb_blue', 0.905, 0.865, D.mp, pM, tostring(math.floor(D.mp * 100)))
	-- level, gold and xp along the bottom
	local need = 2 + D.level * 2
	txt('LEVEL ' .. D.level, 0.40, 0.935, 0.6, { 230, 200, 120 }, 4)
	txt(D.gold .. ' GOLD', 0.50, 0.935, 0.6, YELLOW, 4)
	txt(D.kills .. ' SLAIN', 0.60, 0.935, 0.6, { 230, 200, 120 }, 4)
	DrawRect(0.5, 0.985, 0.30, 0.016, 0, 0, 0, 200)
	DrawRect(0.5 - 0.15 + 0.30 * math.min(1.0, D.xp / need) / 2, 0.985, 0.30 * math.min(1.0, D.xp / need), 0.011, 240, 190, 60, 255)
	-- boss bar
	if H.boss then
		txt(H.boss, 0.5, 0.025, 0.9, RED, 7)
		DrawRect(0.5, 0.085, 0.42, 0.026, 0, 0, 0, 210)
		DrawRect(0.5 - 0.21 + 0.42 * H.bosshp / 2, 0.085, 0.42 * H.bosshp, 0.019, 210, 30, 20, 255)
	end
	-- big title and level-up banner
	if H.title then
		local age = now - H.titleAt
		if age > 4500 then H.title = nil else
			local a = age < 3500 and 255 or math.floor(255 * (1 - (age - 3500) / 1000))
			txt(H.title, 0.5, 0.17, 1.9, { 220, 30, 30 }, 7, a)
		end
	end
	if H.banner then
		local age = now - H.bannerAt
		if age > 2800 then H.banner = nil else
			local a = age < 2000 and 255 or math.floor(255 * (1 - (age - 2000) / 800))
			txt(H.banner, 0.5, 0.30, 2.4, { 255, 226, 120 }, 7, a)
		end
	end
	-- message log
	for i = #H.msgs, 1, -1 do
		local m = H.msgs[i]
		if now - m.at > 5000 then table.remove(H.msgs, i) end
	end
	for i, m in ipairs(H.msgs) do
		txt(m.t, 0.5, 0.78 + (i - 1) * 0.034, 0.55, m.c, 4, 255)
	end
end

-- ---------- hell sky (stage keeps what we ask for) ----------
local function hellSky()
	TriggerEvent('sigf:sky', 19, 'OVERCAST', 30)
	SetTimecycleModifier('REDMIST_blend')
	SetTimecycleModifierStrength(0.95)
end

-- ---------- demons ----------
local function addHorns(ped, size)
	local horns = Sigf.Prop('sigf_horns', GetEntityCoords(ped) + vector3(0, 0, 2), { frozen = false, collision = false })
	if not horns then return nil end
	Sigf.Attach(horns, ped, 31086, vector3(0.0, 0.0, 0.0), vector3(0.0, 0.0, 0.0))
	return horns
end

local function register(ped, kind, opts)
	opts = opts or {}
	if D.list[ped] then return end
	local roll = math.random()
	local rarity = opts.rarity or (roll < 0.12 and 'rare' or roll < 0.45 and 'magic' or 'normal')
	local info = {
		ped = ped, kind = kind, rarity = rarity, ally = opts.ally,
		color = rarity == 'rare' and YELLOW or rarity == 'magic' and BLUE or WHITE,
	}
	local name = kind.name
	if opts.ally then info.color = GREEN
	elseif rarity == 'rare' then name = pick(PREFIX) .. pick(SUFFIX) .. ' ' .. pick(TITLE)
	elseif rarity == 'magic' then name = pick({ 'Fiery', 'Cursed', 'Vicious', 'Frenzied', 'Armoured' }) .. ' ' .. kind.name end
	if opts.name then name = opts.name end
	info.name = name
	local extra = rarity == 'rare' and 2.2 or rarity == 'magic' and 1.4 or 1.0
	if not opts.ally then
		local hp = math.floor((kind.hp or 70) * extra * (opts.hpMul or 1.0))
		SetPedMaxHealth(ped, 100 + hp)
		SetEntityHealth(ped, 100 + hp)
		if rarity == 'rare' then SetPedArmour(ped, 40) end
		if kind.weapon and not opts.noWeapon then GiveWeaponToPed(ped, Sigf.Hash(kind.weapon), 1, false, true) end
		info.horns = addHorns(ped)
		-- every demon smoulders; magic and rare ones burn brighter
		local s = (rarity == 'rare' or opts.fire) and 0.9 or rarity == 'magic' and 0.6 or 0.4
		info.fx = Sigf.Fx('core', 'ent_amb_torch_fire', ped, { loop = true, scale = s, offset = vector3(0, 0, 0.3) })
	end
	info.max = math.max(1, GetEntityMaxHealth(ped) - 100)
	info.last = GetEntityHealth(ped)
	D.list[ped] = info
	return info
end

Sigf.OnSpawn(function(ped, side)
	if not side then return end
	if side == 'a' then register(ped, { name = 'Sanctuary Rogue' }, { ally = true })
	else register(ped, TYPES[1]) end
end)

local function hellPortal(pos)
	Sigf.Fx('core', 'exp_grd_flare', pos, { scale = 2.5 })
	Sigf.Light(pos + vector3(0, 0, 1.2), { 255, 40, 0 }, 10.0, 6.0, 2.5)
	Sigf.Sound('portal', pos, { volume = 0.45, range = 60.0 })
end

-- where new demons appear: in front of the hero (the camera's view), or around the action
local function spawnSpot()
	local c = Sigf.Front(11)
	return Sigf.Ground(c, 7)
end

local function spawnDemon(opts)
	opts = opts or {}
	local kind = opts.kind
	if not kind then
		local r = math.random()
		kind = r < 0.25 and TYPES[4] or r < 0.5 and TYPES[2] or r < 0.8 and TYPES[3] or TYPES[1]
	end
	local pos = opts.pos or spawnSpot()
	hellPortal(pos)
	local ped = Sigf.Ped(kind.model, pos + vector3(0, 0, 0.6), { enemy = true, weapon = kind.weapon, accuracy = 20 })
	if not ped then
		if kind ~= TYPES[1] then return spawnDemon({ kind = TYPES[1], pos = pos }) end
		return
	end
	SetPedCombatAttributes(ped, 46, true)
	SetBlockingOfNonTemporaryEvents(ped, true)
	return register(ped, kind, opts)
end

-- ---------- loot ----------
local function dropLoot(pos, kind, color, label, prop, value)
	local ground = vector3(pos.x, pos.y, pos.z)
	local ent
	if prop then
		ent = Sigf.Prop(prop, ground + vector3(0, 0, 0.2), { frozen = true, collision = false, ground = true, heading = math.random(0, 359) })
	end
	D.loot[#D.loot + 1] = { pos = ground, kind = kind, color = color, label = label, ent = ent, value = value, born = GetGameTimer() }
	Sigf.Sound('gold', pos, { volume = kind == 'gold' and 0.5 or 0.7, range = 50.0 })
end

local function lootFor(info, pos)
	local c = info.rarity
	local g = math.random(8, 24) * (c == 'rare' and 6 or c == 'magic' and 3 or 1) * D.level
	dropLoot(pos + vector3(math.random() * 1.2 - 0.6, math.random() * 1.2 - 0.6, 0), 'gold', YELLOW, g .. ' Gold', 'prop_cash_pile_01', g)
	if math.random() < 0.25 or c ~= 'normal' then
		dropLoot(pos + vector3(1.0, 0.8, 0), 'potion', { 255, 60, 60 }, 'Health Potion', 'prop_ld_health_pack', 1)
	end
	if c == 'rare' or (c == 'magic' and math.random() < 0.4) then
		local col = c == 'rare' and YELLOW or BLUE
		dropLoot(pos + vector3(-1.0, 0.6, 0), 'item', col, pick(ITEMS), c == 'rare' and 'sigf_chest' or 'prop_gold_bar', 1)
	end
end

local function pickup(l)
	if l.kind == 'gold' then
		D.gold = D.gold + l.value
		Sigf.Text3D('+' .. l.value .. ' GOLD', l.pos + vector3(0, 0, 1.6), 1.4, { color = YELLOW, scale = 0.9, rise = 1.2 })
		Sigf.Sound('gold', nil, { volume = 0.35 })
	elseif l.kind == 'potion' then
		D.potions = D.potions + 1
		msg('Picked up a Health Potion', { 255, 90, 90 })
		Sigf.Text3D('POTION', l.pos + vector3(0, 0, 1.6), 1.4, { color = { 255, 80, 80 }, scale = 0.9, rise = 1.2 })
	else
		msg('You found: ' .. l.label, l.color)
		Sigf.Text3D(l.label, l.pos + vector3(0, 0, 1.8), 3.0, { color = l.color, scale = 0.9 })
		Sigf.Fx('core', 'exp_grd_flare', l.pos + vector3(0, 0, 0.3), { scale = 0.8 })
		Sigf.Light(l.pos + vector3(0, 0, 1.0), l.color, 8.0, 5.0, 1.0)
		Sigf.Sound('levelup', nil, { volume = 0.35, rate = 1.4 })
	end
end

local function lootTick(now, mp)
	for i = #D.loot, 1, -1 do
		local l = D.loot[i]
		local gone = (now - l.born) > 40000
		if not gone then
			local c = l.color
			local big = l.kind == 'item'
			-- tall bright beam + glow on the ground
			DrawMarker(1, l.pos.x, l.pos.y, l.pos.z - 0.3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
				big and 0.30 or 0.16, big and 0.30 or 0.16, big and 40.0 or 14.0,
				c[1], c[2], c[3], 170, false, false, 2, false, nil, nil, false)
			DrawLightWithRange(l.pos.x, l.pos.y, l.pos.z + 0.5, c[1], c[2], c[3], big and 6.0 or 3.5, big and 3.0 or 1.8)
			local d = #(mp - l.pos)
			if d < 40.0 then
				SetDrawOrigin(l.pos.x, l.pos.y, l.pos.z + 1.1, 0)
				txt(l.label, 0.0, 0.0, big and 0.6 or 0.45, c, 4)
				ClearDrawOrigin()
			end
			-- magnet: loot flies to the hero
			if d < 11.0 then
				local dir = (mp - l.pos)
				l.pos = l.pos + dir / math.max(d, 0.01) * math.min(d, 0.24 + (11.0 - d) * 0.03)
				if l.ent and DoesEntityExist(l.ent) then SetEntityCoords(l.ent, l.pos.x, l.pos.y, l.pos.z + 0.1, false, false, false, false) end
				d = #(mp - l.pos)
			end
			if d < 1.5 then gone = true pickup(l) end
		end
		if gone then
			if l.ent then Sigf.Remove(l.ent) end
			table.remove(D.loot, i)
		end
	end
end

-- ---------- xp, levels, holy nova ----------
local function heroPos() return Sigf.Stage() == 'demo' and GetEntityCoords(Sigf.Host()) or Sigf.Action() end

local function holyNova()
	local c = heroPos()
	Sigf.Sound('levelup', nil, { volume = 0.9 })
	banner('LEVEL ' .. D.level .. '!')
	msg('HOLY NOVA: fire blasts every demon near you', { 255, 226, 120 })
	Sigf.Shake(0.6)
	Sigf.Light(c + vector3(0, 0, 1.0), { 255, 200, 80 }, 22.0, 8.0, 1.5)
	for i = 0, 15 do
		local a = i / 16 * 6.2832
		local p = c + vector3(math.cos(a) * 9.0, math.sin(a) * 9.0, 0)
		local ok, z = GetGroundZFor_3dCoord(p.x, p.y, c.z + 5.0, false)
		if ok then p = vector3(p.x, p.y, z) end
		Sigf.After(0.05 * (i % 8), function()
			Sigf.Fx('core', 'exp_grd_flare', p, { scale = 3.0 })
			Sigf.Fx('core', 'ent_sht_flame', p, { scale = 0.7 })
		end)
	end
	for ped, d in pairs(D.list) do
		if not d.ally and DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) and #(GetEntityCoords(ped) - c) < 18.0 then
			ApplyDamageToPed(ped, 120, false)
			Sigf.Fx('core', 'fire_ped_body', ped, { scale = 0.8 })
			if not IsPedDeadOrDying(ped, true) then
				local dir = GetEntityCoords(ped) - c
				SetPedToRagdoll(ped, 1500, 1500, 0, false, false, false)
				SetEntityVelocity(ped, dir.x * 0.6, dir.y * 0.6, 6.0)
			end
		end
	end
	D.hp, D.mp = 1.0, 1.0
	H.pulseHp, H.pulseMp = GetGameTimer(), GetGameTimer()
end

local function gainXp(n)
	D.xp = D.xp + n
	local need = 2 + D.level * 2
	while D.xp >= need do
		D.xp = D.xp - need
		D.level = D.level + 1
		need = 2 + D.level * 2
		holyNova()
	end
end

Sigf.OnKill(function(ped, killer, weapon)
	local d = D.list[ped]
	if not d then return end
	D.list[ped] = nil
	local pos = GetEntityCoords(ped)
	if d.fx then Sigf.StopFx(d.fx) end
	if d.horns then SetTimeout(4000, function() Sigf.Remove(d.horns) end) end
	SetTimeout(7000, function() Sigf.Remove(ped) end)
	if d.ally then return end
	D.kills = D.kills + 1
	Sigf.Fx('core', 'exp_grd_flare', pos + vector3(0, 0, 0.5), { scale = 1.2 })
	Sigf.Light(pos + vector3(0, 0, 1.0), { 255, 90, 20 }, 7.0, 4.0, 0.6)
	msg('You have slain ' .. d.name, d.color)
	lootFor(d, pos)
	gainXp(d.rarity == 'rare' and 4 or d.rarity == 'magic' and 2 or 1)
	if d.isBoss then D.onBossDead(d, pos) end
end)

-- ---------- the Butcher ----------
function D.summonButcher()
	if D.boss and DoesEntityExist(D.boss.ped) and not IsPedDeadOrDying(D.boss.ped, true) then return end
	local c = Sigf.Ground(Sigf.Front(13), 2)
	hellPortal(c)
	Sigf.Fx('core', 'exp_grd_flare', c, { scale = 5.0 })
	Sigf.Shake(0.7)
	Sigf.Sound('butcher', nil, { volume = 1.0 })
	title('THE BUTCHER')
	local model = IsModelInCdimage(GetHashKey('u_m_y_juggernaut_01')) and 'u_m_y_juggernaut_01' or 'a_m_m_genfat_01'
	local ped = Sigf.Ped(model, c + vector3(0, 0, 0.6), { enemy = true, health = 450, armor = 50, accuracy = 20 })
	if not ped then return end
	SetPedCombatAttributes(ped, 46, true)
	SetBlockingOfNonTemporaryEvents(ped, true)
	local b = register(ped, { name = 'The Butcher', hp = 450, weapon = 'WEAPON_UNARMED' }, { rarity = 'rare', name = 'THE BUTCHER', noWeapon = true, fire = true })
	b.color = { 255, 60, 30 }
	b.isBoss = true
	b.max = 450
	b.bornAt = GetGameTimer()
	local cl = Sigf.Prop('sigf_cleaver', GetEntityCoords(ped) + vector3(0, 0, 2), { frozen = false, collision = false })
	if cl then Sigf.Attach(cl, ped, 57005, vector3(0.15, 0.0, 0.0), vector3(0.0, 0.0, 0.0)) b.cleaver = cl end
	D.boss = b
	H.boss, H.bosshp = 'THE BUTCHER', 1.0
	msg('"Ahh... fresh meat!"', RED)
	Sigf.Focus(ped, 8)
	TaskCombatPed(ped, Sigf.Host(), 0, 16)
end

function D.killBoss()
	local b = D.boss
	if not b or not DoesEntityExist(b.ped) or IsPedDeadOrDying(b.ped, true) then return end
	local p = GetEntityCoords(b.ped)
	for i = 1, 3 do
		Sigf.After(0.6 * (i - 1), function()
			if DoesEntityExist(b.ped) then Sigf.Explode(GetEntityCoords(b.ped) + vector3(0, 0, 0.5), 4, { scale = 1.0, owner = Sigf.Host() }) end
		end)
	end
	Sigf.After(1.8, function()
		if DoesEntityExist(b.ped) and not IsPedDeadOrDying(b.ped, true) then
			Sigf.KillByHost(b.ped)
		end
	end)
end

function D.onBossDead(d, pos)
	H.boss = nil
	if d.cleaver then SetTimeout(5000, function() Sigf.Remove(d.cleaver) end) end
	Sigf.Slowmo(0.35, 2.5)
	Sigf.Shake(1.0)
	title('THE BUTCHER IS SLAIN')
	for i = 1, 5 do
		Sigf.After(0.3 * i, function()
			local p = pos + vector3(math.random() * 6 - 3, math.random() * 6 - 3, 1.0)
			Sigf.Fx('core', 'exp_grd_flare', p, { scale = 2.5 })
			Sigf.Light(p, { 255, 190, 60 }, 12.0, 6.0, 0.8)
			dropLoot(Sigf.Ground(pos, 3.5), 'gold', YELLOW, '250 Gold', 'prop_gold_bar', 250)
		end)
	end
	dropLoot(pos + vector3(0, 2.0, 0), 'item', ORANGE, 'The Butcher\'s Cleaver (Unique)', 'sigf_chest', 1)
	gainXp(8)
end
exports('summonButcher', function() D.summonButcher() end)

-- ---------- per-frame: HUD, name plates, health bars, damage numbers, light, loot ----------
local lastDmg = 0
Sigf.Frame(function(dt)
	if not D.started then return end
	local now = GetGameTimer()
	local me = Sigf.Host()
	local mp = heroPos()
	local near = 0
	for ped, d in pairs(D.list) do
		if not DoesEntityExist(ped) then
			if d.fx then Sigf.StopFx(d.fx) end
			if d.horns then Sigf.Remove(d.horns) end
			D.list[ped] = nil
		elseif not IsPedDeadOrDying(ped, true) then
			local p = GetEntityCoords(ped)
			local dist = #(p - GetFinalRenderedCamCoord())
			local hp = GetEntityHealth(ped)
			if hp < d.last then
				local dmg = d.last - hp
				local crit = dmg >= 30
				Sigf.Text3D(tostring(dmg), p + vector3(math.random() * 0.8 - 0.4, math.random() * 0.8 - 0.4, 1.6), 1.1,
					{ color = crit and YELLOW or WHITE, scale = crit and 1.3 or 0.85, rise = 1.6 })
				if crit then Sigf.Fx('core', 'ent_brk_sparking_wires', p + vector3(0, 0, 1.0), { scale = 0.6 }) end
			end
			d.last = hp
			if d.isBoss then H.bosshp = math.max(0, (hp - 100) / d.max) end
			if not d.ally then
				if d.rarity ~= 'normal' or d.isBoss then
					DrawLightWithRange(p.x, p.y, p.z + 1.0, d.color[1], d.color[2], d.color[3] > 200 and 120 or d.color[3], 6.0, 2.2)
				end
				DrawLightWithRange(p.x, p.y, p.z + 1.6, 255, 30, 0, 3.0, 1.8)
				if #(p - mp) < 4.5 then near = near + 1 end
			end
			if dist < 55.0 then
				local sc = math.max(0.8, math.min(1.8, 24.0 / dist))
				local ph = d.isBoss and 1.25 or 1.0
				SetDrawOrigin(p.x, p.y, p.z + ph + (d.horns and 0.3 or 0.0), 0)
				txt(d.name, 0.0, -0.045 * sc, 0.62 * sc, d.color, 4)
				local w, h = 0.095 * sc, 0.013 * sc
				local f = math.max(0.0, math.min(1.0, (hp - 100) / d.max))
				DrawRect(0.0, 0.0, w + 0.003, h + 0.004, 0, 0, 0, 230)
				DrawRect(-w / 2 + w * f / 2, 0.0, w * f, h, d.ally and 60 or 215, d.ally and 200 or 25, 20, 255)
				ClearDrawOrigin()
			end
		end
	end
	-- orbs: the hero "takes hits" from nearby demons, drinks potions, spends mana when shooting
	D.hp = math.min(1.0, D.hp + 0.01 * dt - near * 0.05 * dt)
	if near > 0 and now - lastDmg > 900 then lastDmg = now H.pulseHp = now end
	if IsPedShooting(me) then D.mp = math.max(0.1, D.mp - 0.01) H.pulseMp = now else D.mp = math.min(1.0, D.mp + 0.05 * dt) end
	if D.hp < 0.3 and D.potions > 0 then
		D.potions = D.potions - 1
		D.hp = 1.0
		H.pulseHp = now
		msg('You drink a Health Potion (' .. D.potions .. ' left)', { 255, 90, 90 })
		Sigf.Light(mp + vector3(0, 0, 1.0), { 255, 40, 40 }, 8.0, 5.0, 0.8)
		Sigf.Text3D('+HEALTH', mp + vector3(0, 0, 1.4), 1.4, { color = { 255, 70, 70 }, scale = 0.9 })
	elseif D.hp < 0.12 then D.hp = 0.12 end
	lootTick(now, mp)
	drawHud(now)
end)

-- ---------- director: a set piece every cycle, so the show never goes quiet ----------
local function demonCount()
	local n = 0
	for ped, d in pairs(D.list) do
		if not d.ally and DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then n = n + 1 end
	end
	return n
end

Sigf.Every(2.5, function()
	if D.started and demonCount() < 6 + math.min(D.level, 4) then spawnDemon() end
end)

local CYCLE, cycleAt = 50, nil
local function burst()
	title('HELL BREAKS LOOSE')
	for i = 1, 5 do Sigf.After(0.5 * (i - 1), function() spawnDemon({ rarity = i <= 2 and 'rare' or nil }) end) end
end
local function startCycle()
	cycleAt = GetGameTimer()
	burst()
	Sigf.After(7, function()
		local need = 2 + D.level * 2
		gainXp(math.max(1, need - D.xp))                     -- guaranteed level up: the holy nova
	end)
	Sigf.After(12, function() D.summonButcher() end)
	Sigf.After(34, function() D.killBoss() end)              -- a rocket volley if he is still standing
end

Sigf.Every(CYCLE, function() if D.started then startCycle() end end)

-- ---------- start ----------
Sigf.After(2, function()
	D.started = true
	Sigf.Battle({ a = 4, b = 2, modelB = 'u_m_y_zombie_01', weaponB = 'WEAPON_BAT', weaponA = 'WEAPON_SMG' })
	hellSky()
	title('DIABLO TAKEOVER')
	Sigf.Sound('portal', nil, { volume = 0.8 })
	msg('The Lord of Terror has come to Sandy Shores', { 255, 70, 40 })
	Sigf.After(1.5, startCycle)
end)

-- the demo hero cannot die: fire, melee and explosions are all ignored, and a downed hero stands up at once
CreateThread(function()
	while true do
		Wait(200)
		if D.started and Sigf.Stage() == 'demo' then
			local me = PlayerPedId()
			SetPlayerInvincible(PlayerId(), true)
			SetEntityInvincible(me, true)
			SetEntityProofs(me, true, true, true, true, true, true, true, true)
			SetPedCanRagdoll(me, false)
			if GetFollowPedCamViewMode() == 4 then SetFollowPedCamViewMode(1) end
			if IsEntityDead(me) or GetEntityHealth(me) < 120 then
				if IsEntityDead(me) then
					local c = GetEntityCoords(me)
					ResurrectPed(me) ClearPedTasksImmediately(me)
					SetEntityCoords(me, c.x, c.y, c.z + 0.3, false, false, false, false)
					Sigf.Give('WEAPON_CARBINERIFLE')
				end
				SetEntityHealth(me, 200)
			end
			if IsEntityOnFire(me) then StopEntityFire(me) end
		end
	end
end)

-- keep the sky dark even if the stage resets it
CreateThread(function()
	while true do
		Wait(250)
		if D.started then
			NetworkOverrideClockTime(19, 30, 0)
			SetWeatherTypeNowPersist('OVERCAST')
			SetTimecycleModifier('REDMIST_blend')
			SetTimecycleModifierStrength(0.95)
			if H.boss and (not D.boss or not DoesEntityExist(D.boss.ped) or IsPedDeadOrDying(D.boss.ped, true)) then H.boss = nil end
		end
	end
end)

-- shared with demo.lua
D.spawn = spawnDemon
D.gainXp = gainXp
D.TYPES = TYPES
Diablo = D
