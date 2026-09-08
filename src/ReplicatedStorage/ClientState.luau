--!strict
-- Shared table for client-only state handed between LocalScripts on the same client.
-- (Every LocalScript that require()s this module gets the same table.)
return {
	stamina = 1, -- 0..1, written by MoveController, read by the HUD
}
