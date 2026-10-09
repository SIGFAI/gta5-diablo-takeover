-- Demo: the hero (invincible) fights through hell. The mod itself runs the show: horned demons close to the
-- camera, a holy nova on level-up, THE BUTCHER with a boss bar, loot beams. The demo arms the hero.
Sigf.Demo(1, function()
	Sigf.Give('WEAPON_CARBINERIFLE')
	Sigf.Text('DIABLO TAKEOVER', 4, { y = 0.12, size = 44, color = '#ff5030' })
end)

-- the hero switches to a rocket launcher whenever the Butcher is up
Sigf.Demo(20, function()
	if Diablo.boss then Sigf.Give('WEAPON_RPG') end
end)
Sigf.Demo(40, function() Sigf.Give('WEAPON_CARBINERIFLE') end)
