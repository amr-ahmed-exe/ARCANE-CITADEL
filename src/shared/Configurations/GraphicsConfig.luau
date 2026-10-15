--!strict
-- Arcane Citadel: graphics scalability (perf pass).
-- ParticleRateScale multiplies every static ParticleEmitter rate
-- (braziers, beacons, altar, anvil, heart, chest, staff). Set to 0.5 on
-- low-end targets: identical look, just sparser. Applied at build time.

local GraphicsConfig = {
	ParticleRateScale = 1.0,
	-- Wraith render distance (studs, XZ): farther wraiths hold their last
	-- pose instead of updating 6 parts every frame. Map is ~600 studs wide.
	WraithCullDistance = 450,

	-- Blueprint §4.1 atmosphere. These were hardcoded in WorldBuilder while
	-- the Cursed Woods comment in MeshConfig quoted different numbers, so
	-- the ring and the docs disagreed about the spawn area.
	FogStart = 170,
	FogEnd = 300,
	-- Cursed Woods spawn ring (blueprint: "Radius 200 to 260 studs").
	WoodsRadiusMin = 200,
	WoodsRadiusSpan = 60,
}

-- Whole-number rate, never below 1 (an emitter with Rate 0 still costs).
function GraphicsConfig.ScaledRate(base: number): number
	return math.max(1, math.round(base * GraphicsConfig.ParticleRateScale))
end

return GraphicsConfig
