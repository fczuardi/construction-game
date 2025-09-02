A tiny, practical API for PlayerVisuals that covers your v1 slice: 
walk, run, and an upper-body “map/clipboard” pose. 

No code yet—just the contract.

## What PlayerVisuals owns (v1)

- Drives the AnimationTree for locomotion.
- Presents walk baseline, with two orthogonal toggles:
    - Run (on/off) — faster locomotion style.
    - Map (on/off) — additive upper-body pose. (Can be combined with Run.)

## Public API

### methods

- update_motion(velocity: Vector3, on_floor: bool)
- set_run_enable(on)
- set_map_enable(on)
