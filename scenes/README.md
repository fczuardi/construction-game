# Contractor Hero Scenes

Components for my upcoming game "Contractor Hero".

## How to navigate this repo

Directories are organized as follows:

- `/lib/`: reusable components
- `/demos/`: one demo per component, demonstrates usage
- `/slice/`: vertical slice scenes, demonstrates some particular aspect of the game
- `/materials/`: external `.tres` materials to keep scene files small 
- `/doc/devlog/`: small daily status updates (mirrored on itch)

## Work Principles/Guidelines

- Components are Unstable until first game is released
    - I am the only consumer
- Build around a vertical slice, not the library
    - API procrastination is dangerous, I should value my limited time
- Keep the public surface tiny (API budget)
    - <= 5 exports, <= 3 public methods
        - everything else is internal (prefixed `_`) or a resource input
- Prefer resource inputs over many scalar exports
- Prefer one toggle with sane defaults over 3-4 knobs
- No Backlog keeping
    - if an idea was really good it will return
    - the "TODO" list should be "Ongoing Work" really
- Limited/Timeboxed Polish
    - not more than 2 hours/day total
- Demos > Docs
    - I love to write, that's true, but no one will ever read it
- Blog helps organization
    - a minimal devlog everyday, no review, quick stream-of-consciouness text with no review
- editor-first components
    - @tool with small, actionable warnings
- demos double as smoke tests
    - open → tweak a couple of exports → hit Play
    - Keep a “Test Checklist” per component (5–8 bullets) at the top of the script (comment)
- signal vs public methods
    - try to follow the rule of thumb: "commands in, events out"

### TL;DR

Drive work by a vertical slice; only generalize on the second use-case.
Use Prototype → Beta → Stable labels and a tiny API budget.
Demo scenes > long docs. Time-box polish.
Decouple aggressively via resources
