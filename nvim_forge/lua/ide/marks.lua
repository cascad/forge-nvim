-- Compatibility facade; ownership lives in one controller.
local owner = require("ide.ownership")
return { setup = function() owner.setup(); owner.reconcile() end, mark_window = owner.mark }
