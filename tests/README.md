# Tests

These are regression tests for the aura sandbox. They load real addon files
outside of World of Warcraft, with the WoW globals they need stubbed, and check
that the escape routes we have found and closed stay closed:

- `aura_environment_test.lua` checks that custom aura code compiled through
  `WeakAuras.LoadFunction` cannot reach the real global table, the blocked WoW
  functions, or the data-changing WeakAuras API, and that legitimate lookups
  such as anchoring to a child frame without a name keep working.
- `forever_trigger_options_test.lua` builds the real Trigger-tab option tables
  through the Forever provider and shared helper functions. It covers title
  dispatch, new triggers, source edits and reordering without emulating AceGUI.
- `forever_spell_cache_test.lua` checks the options cache's Forever branch using
  bounded spellbook fixtures. General metadata queries and background sweeps
  fail the test. It also verifies the original Classic worker still runs.
- `forever_hunter_test.lua` checks the explicit Hunter preset against spellbook
  metadata, rank selection, geometry, group membership and preservation of user
  edits/deletions. Native mana sink recorders check that opaque inputs are only
  forwarded to Blizzard setters; they do not emulate secret values or rendering.
- `forever_saved_variables_test.lua` checks WAF's save-selection boundary:
  first migration, fresh installs, new saves taking precedence and preservation
  of deletions. It does not emulate WoW's dependency or SavedVariables loader.
- `forever_spinbox_test.lua` exercises the actual number-control hover callbacks
  with the retired `MouseIsOver` global absent. Region-query and drawing recorders
  cover entering/leaving, handle colors and release behavior; they do not
  construct frames or emulate AceGUI or native hit testing.
- `common_options_test.lua` checks that the options panel evaluates stored
  custom code only inside the sandbox when it renders the error label under a
  code box.

A passing run is not a security proof. The tests only probe the routes they
name. They cannot show that the block lists are complete, that no other route
exists, or that an allowed WoW function is harmless. They do not emulate the
WoW API, taint, or secure execution. When a new escape is found, add it here so
it cannot come back.

## Running

The sandbox is built on `loadstring` and `setfenv`, which Lua 5.2 removed, so
the tests need Lua 5.1 or LuaJIT:

```sh
lua5.1 tests/run.lua
```

or

```sh
luajit tests/run.lua
```

Each test file also runs on its own, for example
`luajit tests/aura_environment_test.lua`. A failing expectation prints `FAIL`
and the process exits with a non-zero status.

## Adding a test

Put shared WoW stubs in `wow_stubs.lua`. Keep them to what the loaded files
touch. Write a new `*_test.lua` that requires `helpers` and `wow_stubs`, loads
the addon file with `T.loadAddonFile`, states expectations with `T.expect`,
and ends with `T.finish()`. Then add the file name to the list in `run.lua`.

Forever source expansion tests use narrow API fixtures and the real registered
provider lifecycle. They cover unknown/inverse behavior, restriction transitions,
public flags with protected-time sentinels, range nil, effect sets, numeric
boundaries, event timers, rename/unload and event-versus-poll routing. Options
tests build real flattened panels, exercise category/source/picker setters and
evaluate each source's visible controls. They do not emulate native WoW frames,
AceGUI drawing, restrictions or rendering; these still need client verification.
