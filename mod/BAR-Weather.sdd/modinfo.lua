-- Dependent game archive: everything not in this archive comes from Beyond All Reason.
return {
	name = "BAR Weather",
	description = "Dynamic weather and day/night for Beyond All Reason",
	shortName = "BARW",
	version = "0.1.0",
	game = "BAR Weather",
	shortGame = "BARW",
	mutator = "Community",
	modtype = 1,
	-- Exact BAR game archive name we test against (engine: Recoil 2026.07.04). A wrong name
	-- means the engine cannot resolve the dependency and the game will not load. Update this
	-- when BAR updates: the launcher downloads new test-NNNNN versions often.
	depend = {
		"Beyond All Reason test-31536-188afa8",
	},
}
