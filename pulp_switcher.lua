
--[[
	INTERNAL DOCUMENTATION
	
	saveStore() - A function called by Pulp whenever the user runs 'store' with no arguments, when reaching an ending, and when changing rooms.
		Saves current internal storage to 'store.json'. Even if called from Lua, this has the same effect as running 'store'.

	loadStore() - A function called by Pulp only when the game begins. Loads all information from store.json into internal storage.
		Note that the user must run 'restore' in order to get these values, and that this pummels internal storage.

	relativePath - An important internal Pulp variable which makes switchers possible. This must always be the path of the loaded PDX.
--]]

local getargs = import "argparser"
local fs = playdate.file
local ds = playdate.datastore

local orig_print = print

-- Our new custom printing function, for use after the game begins.
local execute = function(str)
	if type(str) ~= 'string' then -- Irrelevant in pulp, useful for Lua-side testing.
		orig_print(str)
		return
	end
	local name, args = str:match("^$%s*([a-zA-Z0-9_.]+)%s*(%b())")
	if name then
		local f = _G
		local log = {}
		for sub in name:gmatch("[a-zA-Z0-9_]+") do
			log[#log+1] = sub
			if f == nil or type(f) ~= 'table' then
				error(string.format([[
could not find function '%s'
	global '%s' is of type %s]], name, table.concat(log, ".", 1, math.max(1, #log-1)), type(f)))
			end
			f = f[sub]
		end
		if type(f) ~= "function" then
			error(string.format("could not find function '%s'\n\t global '%s' is of type %s", name, name, type(f)))
		end
		local targs
		if string.len(args) > 2 then
			targs = getargs(args:sub(2, -2))
			f(table.unpack(targs))
		else
			f()
		end
	else
		orig_print(str)
	end
end
print = execute

-- Hooks, for adding post-load functionality.

local hooks = {}
---@param f function
---Add a hook function to be run after a PDX is initialized.
function addHook(f)
	assert(type(f) == "function", "expected function, got " .. type(f))
	table.insert(hooks, f)
end

-- Implementation of mergeStore and the 'pulp' table

local pulpstore = ds.read('store') or {}

addHook(function()
	local orig_savestore = saveStore
	saveStore = function()
		orig_savestore()
		pulpstore = ds.read('store') or {}
	end
end)

local function mergeStore(a, b)
	if not saveStore then
		error("cannot run mergeStore until pulp has initialized", 2)
	end
	saveStore()
	if type(a) == "table" then
		for k, v in pairs(a) do
			assert(type(k) == "string", "variable name must be a string")
			local vt = type(v)
			assert(vt == "string" or vt == "number" or v == nil, "can only store variables of types 'string', 'number', and 'nil'")
			pulpstore[k] = v
		end
	elseif type(a) == "string" then
		local bt = type(b)
		assert(bt == "string" or bt == "number" or b == nil, "an only store variables of types 'string', 'number', and 'nil'")
		pulpstore[a] = b
	else
		error("variable name must be a string")
	end
	ds.write(pulpstore, 'store', true)
	loadStore()
end

pulp = setmetatable({}, {
	__index = function (t, k)
		return pulpstore[k]
	end,
	__newindex = function (t, k, v)
		mergeStore(k, v)
	end
})

-- PDX loading.

currentPDX = false
defaultPDX = "main"
---@param filename string The PDX to load into.
---Initializes a new PDX.
function loadPDX(filename)
	assert(type(filename) == "string", "expected string")
	relativePath = filename..'.pdx/'
	if fs.exists(relativePath) then
		if saveStore then saveStore() end
		fs.run(relativePath .. "main")
		currentPDX = filename
		-- pulpStore = ds.read("store") or {}
		for _, f in ipairs(hooks) do
			f()
		end
	else
		error("could not find file '" .. relativePath .. "'")
	end
end

-- The "menu item" functionality of the original automatic pulp switcher, reimplemented.

local menu_item, item_name, do_always
local to_pdx = defaultPDX
local sysmenu = playdate.getSystemMenu()
local function return_to_default()
	loadPDX(to_pdx)
end
local function handleMenuItem()
	if (to_pdx ~= currentPDX) or do_always then
		if not menu_item and item_name then
			menu_item = sysmenu:addMenuItem(item_name, return_to_default)
		end
	else
		if menu_item then
			sysmenu:removeMenuItem(menu_item)
			menu_item = nil
		end
	end
end
addHook(handleMenuItem)

---@param name string? The name of the menu item. Defaults to "reset"
---@param pdx string? The PDX this menu item should enter. Defaults to the value of defaultPDX.
---@param always boolean? If false, this menu item is only shown when in a different PDX. If true, this menu item will always be shown, even while currently in the same PDX. Defaults to false.
--- Enables the "enableMenu" option introduced in the original automatic switcher.
function setReturnMenu(name, pdx, always)
	assert(type(name) == "string" or name == nil, "expected arg[1] to be type string")
	assert(type(pdx) == "string" or pdx == nil, "expected arg[2] to be type string")
	if pdx == nil then pdx = defaultPDX end
	assert(fs.exists(pdx .. ".pdx/"), "pdx file '".. pdx .. ".pdx/' does not exist")
	assert(type(always) == "boolean" or always == nil, "expected arg[3] to be boolean")
	item_name = name or "reset"
	to_pdx = pdx
	do_always = always or false
	handleMenuItem()
end

-- So that anything that wants to know the display scale does so accurately.
playdate.display.setScale(2)

-- Automatically load into the default game.
function playdate.update()
	loadPDX(defaultPDX)
end