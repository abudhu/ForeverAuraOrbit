# Forever Aura Orbit

A standalone paladin addon for World of Warcraft Forever (Interface `16001`).

`main` starts from version **0.1.2**, the restored portrait-orbit baseline. The `v0.1.2` tag identifies it. Later bottom-fan experiments are not part of this baseline.

## Usage

### Frame-clearance experiment

On `fix/arc-frame-clearance`, version `0.1.2-frame-clearance.1` fits the arc around the left/top of the portrait. It reserves space for the level badge and aura outlines, and caps the endpoint before the live health/name-bar bounds. The radius is only enlarged as needed for clearance and usable icon spacing; this is not the bottom-fan layout.

Opening begins at the safe outer slot instead of drawing over the level number. Layout changes remain outside combat, and the existing secure hover/cast behavior is retained. If bar geometry is unavailable, a conservative portrait-edge bound is used. In-game appearance still needs visual acceptance; `main` and `v0.1.2` are unchanged.

Hover the level badge on the default player unit frame to unfold your learned auras clockwise around the portrait. Click an icon to activate the aura.

- Gold outlines identify the active aura.
- A confirmed new activation briefly pulses a gold halo.
- Hover an icon for its spell tooltip.
- The menu uses secure hover/cast controls. In combat it opens at fixed positions without the opening movement; the cosmetic selection pulse remains available.
- Changes to learned spells that require rebuilding protected buttons are deferred until after combat.

Commands:

- `/fao`: list discovered aura names and spell IDs.
- `/fao refresh`: rebuild and re-anchor outside combat.
- `/auraorbit`: alias for `/fao`.

The addon has no other addon dependencies and does not change keybindings, CVars, or action bars. Entirely replacement unit frames are not supported by this baseline.

## Installation

Create `_forever_/Interface/AddOns/ForeverAuraOrbit/` in your WoW installation and copy these files into it, preserving the `Media` folder:

- `ForeverAuraOrbit.toc`
- `Core.lua`
- `ForeverAuraOrbit.lua`
- `Media/Ring.tga`

When safe, use `/reload`. A running client may need a full restart to discover a newly added addon folder. Never reload or restart while fighting.

## Development

Install the development dependency and run the compatibility suite:

```sh
python -m pip install -r requirements-dev.txt
python tests/test_addon.py
```

If your Python environment uses `uv` instead of pip:

```sh
uv pip install -r requirements-dev.txt
```

Tests execute the actual addon Lua using Lua 5.1, replacing only the WoW API boundary. They cover aura/rank discovery, portrait-arc geometry, opening animation, active markers, selection pulses, secure combat transitions, and deferred rebuilds. They do not certify actual in-client rendering, input delivery, taint safety, or casting.

To regenerate the original circular border texture:

```sh
python tools/generate_assets.py
```

Spell artwork is supplied by WoW. The generated ring is included in this repository.

## Change workflow

Keep `main` on the accepted baseline. Make layout experiments on separate branches, test outside WoW first, then validate in-game before merging. Tag accepted versions so rollback is unambiguous.

Local backup folders and abandoned experimental test fixtures are intentionally excluded from Git. No GitHub Actions workflow is configured yet.
