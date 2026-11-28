# Sonic Runners interface

Prototype uses the original Sonic Runners title illustration, character faces, glossy controls, Ring counter, pause button and Special gauge. The title combines the two English word marks with lettering for Spinball. The shared Godot theme also styles Endless, the Act Geometry Editor and the in-game labs.

| Play | Between Acts | Tools |
| --- | --- | --- |
| [Run setup](run-setup.jpg) | [Buddy draft](buddies.jpg) | [Act Geometry Editor](act-editor.jpg) |
| [Prototype HUD](gameplay.jpg) | [Run results](results.jpg) | [Atmosphere Lab](atmosphere-lab.jpg) |
| [Pause](pause.jpg) | | [Endless](endless.jpg) |

These Windows Forward+ captures use Godot 4.7.2 and D3D12. The Green Hill Challenge uses one Zone and three disk-baked Acts. A scripted review awards the targets and enters each Goal to exercise the draft and Results screens. The displayed score and time belong to that test.

## Artwork

The UI sprites are SEGA artwork from the project's local Sonic Runners reference set. The texture and prefab pairs under `RunnersDecomp/Assets/Texture2D` and `PrefabInstance` provide the original sprite rectangles and button borders.

| Original atlas | Sprites used |
| --- | --- |
| `ui_title_Atlas` | `ui_cmn_bg_sky4`, the English Sonic and Runners marks, and the title star trail |
| `ui_cmn_btn_bg_Atlas` | Blue, green and orange small buttons, including their hover, pressed and disabled artwork |
| `ui_mainmenu_Atlas` | Sky, corner decoration, challenge flag, gift, trophy, settings gear and Play triangle |
| `ui_gameplay_Atlas` | Ring, three pause-button states and the normal gauge |
| `ui_result_Atlas` | Results pattern and the nine playable Runners character faces |

The draft keeps the eleven [Sonic Runners Adventure Buddy portraits](../../assets/ui/buddies/sra/sources.json). Sage uses her existing HUD initial. The interface theme and sprites live in [assets/ui/runners](../../assets/ui/runners).
