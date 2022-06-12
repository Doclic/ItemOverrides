# ItemOverrides
A simple TF2 SourceMod plugin used on Shounic Conflict 1972 for custom loadouts.  
This is a modified version of [Gimme](https://forums.alliedmods.net/showthread.php?t=335644)

Depends on [TF2 Utils](https://github.com/nosoop/SM-TFUtils/releases/)  

---
## Command syntax
For any class: `!loadout <primary> <secondary> <melee>`  
For Spy: `!loadout <revolver> <sapper> <knife> <watch>`  
To reset: `!loadout reset`  

Those commands use item definition indexes, which can be found [here](https://wiki.alliedmods.net/Team_fortress_2_item_definition_indexes)

## Convars
`sm_item_overrides_enabled`: Disables the entire plugin if set to 0  
`sm_item_overrides_loadout_enabled`: Prevents user from modifying their loadout  
