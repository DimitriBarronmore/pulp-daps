# Welcome to Dimitri's Awesome Pulp Switcher.

## Basic Concepts

Pulp runs on the normal Lua SDK as a pre-made engine.
This means with a small minimum of trickery, any SDK code can be called from inside of the Pulp runtime.

It is my belief that it is better to configure complex behavior on the Lua side, where the tooling is better,
and that you are smart enough to do so. It is additionally my belief that the best thing a tool
like this can do is allow you to write your own tools. As such, more than merely switching games, this template
is built around near-full Pulp > Lua interoperability.

At the same time, it is my belief that if you never want to touch Lua you shouldn't need to do so.
As such, if you drag and drop your files into the pre-built template in the right way they'll simply work,
and any additional configuration can be done using very simple Pulp-side commands.

## Basic Usage

Download each individual Pulp game and add their decompressed PDX bundles to the pre-compiled release.
By default, the game you want to enter at launch should be named *'main.pdx/'*.
Copy all relevant .pdi and pdxinfo files into the template.

In order to load the other games added to the bundle, simply call the following command from
inside Pulp:

```lua
log "$loadPDX('pdxname')"
```

Where `pdxname` is the name of the PDX bundle you wish to enter, without the .pdx extension.

In order to enable the "reset" menu option, run the following in your game's `load` event:

```lua
log "$setReturnMenu()"
```

See [setReturnMenu()](#setreturnmenuname-pdx-always) for more information about how to customize
the menu item.

### Configuration

Some settings can be changed without the use of Lua by modifying the file *'config.json'*.
By default, this is limited to the directory name of the default game. More advanced templates may use this config for other useful information.

## Advanced Usage

This switcher enables Pulp games to trigger arbitrary Lua code at any time.

If the `log` command is used to print a string which begins with the magic character `$`, the
string will be treated as Lua code to execute. Due to the Playdate's inability to compile Lua
code at runtime, this is limited to running a single global function at a given time.
For example:

```lua
log "$hello_world('john')"
```

Whitespace between the magic character, function name, and arguments list is ignored.
For technical reasons, the arguments are treated as the contents of a JSON array. For convenience
string literals can be single or double-quoted, and the literal `nil` aliases to `null`. Normal lua
indexing can be used to run functions inside global tables.


```lua
log "$ module.func ('string', 1.0, true, null, [1, [2, 3], 4], {'key': 'val'})"
```

Using this and the information detailed in the next heading, you can defer all kinds of un-pulp-like
behaviors to Lua code.

### Achievement Example

You can find an example of how to use this switcher to integrate https://github.com/PlaydateSquad/pd-achievements
into a Pulp game in the examples/achievements subdirectory.

### Technical Details for Power Users

#### defaultPDX
A string value telling the switcher which PDX to load into first, without the extension. Defaults to `'main'`

#### currentPDX
A string value containing the name of the currently loaded PDX.

#### setReturnMenu([name], [pdx], [always])
Enables the "return menu" functionality introduced in the original Pulp AutoSwitcher.

- `name`: The name of the menu item which will be added. Defaults to `'reset'`
- `pdx`: The PDX folder to switch to when the menu item is selected. Defaults to `defaultPDX`
- `always`: If true, the menu item is always visible. Otherwise, the menu item only appears when not already in the configured PDX. 

#### loadStore()
An internal function used by Pulp to load variables from on-disk storage at game start.
Dumps the contents of `store.json` directly into Pulp's temporary variable store, deleting whatever's
already there. Don't use this manually unless you know what you're doing.

#### saveStore()
An internal function used by Pulp to save variables from permanent storage into `store.json`, called when
the user runs the `store` command with no arguments, when reaching an ending, and when changing rooms.

#### mergeStore( a, [b] )
Sets the value of `a` in Pulp's permanent storage to `b`.

This function force-saves Pulp's permanent storage to disk, alters it, and then force-loads Pulp's
permanent storage from disk again. Doing this allows you to set Pulp runtime variables from Lua code.
Keep in mind that Pulp variables can only be numbers or strings.

If `a` is instead a table, the contents of that table will be merged into Pulp's storage.
This is more efficient than merging many variables one at a time.

The variable must be refreshed from storage with the `restore` command before the change is reflected in the Pulp runtime.

#### pulp
A convenience table afforded to the user for Lua > Pulp interop.

Indexing this table will return variables from Pulp's permanent storage, as of the last write.
Writing into this table will merge into permanent storage. If writing many variables at
once, this is substantially less efficient than using the table version of `mergeStore()`.

#### addHook(f)
Adds the function `f` as a hook to be run immediately after any PDX is loaded. For example, this is used
internally to keep the `pulp` table synchronized and to manage the return menu.

