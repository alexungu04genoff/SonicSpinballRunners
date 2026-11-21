# Loop Workshop

Open `data/acts/Experiments/Loop Workshop.tres` in the Act Geometry Editor and choose **Play**. Press Launch and leave steering neutral. The yellow spring carries the Ball over the first hill into an upright Loop. The left flipper feeds the climbing return ramp. A tip shot with the right flipper enters the angled, counter-clockwise Loop. The blue and red springs near the small mouth demonstrate misses on speed and angle.

## Authoring

Choose **Loop-de-loop** from the gameplay palette. Set X, Y and rotation in the inspector. **Scale** accepts exact values from 0.5× to 2.5×. Shift-wheel resizes the selected Loop around its mouth. The centerline, entry width, upright height and exit lane scale together. Changing direction reverses the required approach. The canvas displays the mouth, approach cone, travel and exit arrows, scale, entry speed and completion score.

**Completion Score** sets whole base points per successful pass, from 0 to 1,000,000. Existing Loops default to 1,000. Workshop examples pay 500 at 0.5×, 1,000 at 1× and 2,500 at 1.65×. Authors can assign those values independently of size. The 0–10 Ring reward pays once per Loop per Act visit and survives a soft retry. The three optional Ring markers are decorative. A blocked exit rolls the Ball back without paying. A blocked return mouth sends it to serve.

The Ball must cross the mouth from the entry side within 30 degrees, with enough lateral clearance for its radius. The default minimum forward speed is 240 px/s. A valid pass uses the incoming forward speed clamped to 420–900 px/s. At a nominal 550 px/s, the 120 Hz Workshop recorded 57, 115 and 190 ticks for the small, standard and tall Loops. The same 2D Ball exits along the authored tangent.

Choose **Elevated Ramp / Rail**, then enable **Terrain ramp** for a hill. Place the first two path points along the intended entry and the last two along the exit. Width and height use Act pixels. The tread follows a smooth crest with a level tangent at both mouths. The stage supplies the tread, verge and banks. The character follows the running surface and rolls with signed speed, including on a weak uphill shot that returns to the entrance. The existing rail style remains available for bridge and underpass shots.

## Stage surfaces

| Stage | What to look for |
| --- | --- |
| Green Hill | Grass wraps the track above checker soil. The Loop uses the same materials as the turf-loop landmark. |
| Casino Night | A crimson cabinet on brass feet carries four printed aces. The ivory faces retain a 5:7 proportion on the hill, elevated rail and Loop. Each lane starts with the ace of hearts. A short, wide ramp fits one smaller ace at its center. |
| Ice Cap | Snow follows the tread and caps an asymmetric ice arch. Blue crystal courses run level across its shoulders. |
| Rooftop Run | Terracotta roof tiles cross a limestone arch with radial joints, a crown keystone and two piers. Ramp banks use the adjacent terrain masonry. |
| Aquarium Park | Blue glazed tile sits on vermilion-edged timber stringers. Bridge feet leave openings below the climbing ramp, and three brass ties secure the Loop. |

The references informed the silhouettes, material choices and transitions. The stage surfaces use existing project art and an original four-ace print for Casino Night. [Green Hill in Generations](https://www.digitallydownloaded.net/2011/10/sonic-generations-demo-now-available.html), [Casino Night in Sonic 2](https://outof.games/news/6403-sonic-the-hedgehog-2-how-the-sequel-put-the-blue-furball-on-the-map/), [Ice Cap snowboarding tiles](https://www.spriters-resource.com/sega_genesis/sonicth3/asset/116010/), [Rooftop Run in Unleashed](https://www.italyformovies.com/film-serie-tv-games/detail/6393/sonic-unleashed-game), [Aquarium Park in Colors](https://spong.com/article/images/22544/Sonic-Colours-Aquarium-Park-Screens/335124).

[Casino Night card faces in play](loop-workshop/casino-cards.webp) · [Five-stage ramp and Loop comparison](loop-workshop/theme-comparison.webp) · [Green Hill opening and right-flipper shots](loop-workshop/green-hill-shots.mp4)

## Verification and cost

The authoring regression passed 67 checks and the Workshop passed 96 in the Vulkan player. Both flipper shots made their intended mouths. The Workshop also exercised upside-down character orientation, weak-ramp rollback, zero-point traversal, a blocked Loop exit, soft retry, Act and Zone retirement, and teardown. The active traversal owner was released. Godot reported two unidentified RefCounted instances at process exit. The 35 Prototype and 35 Endless Act/theme variants passed the disk audit. All five Workshop skins completed the opening shot with the Ball in frame.

The Green Hill comparison used the same Act, both ramps, the production preset and four alternating warmed passes. Each view sampled 120 rendered frames. With four Loops placed, the follow view went from 43 to 48 draws and the overview from 64 to 79. Follow-view GPU medians were 0.383–0.384 ms for the control and 0.389–0.450 ms for the Workshop. Overview medians were 0.310–0.313 ms and 0.305–0.348 ms respectively. These measurements describe this machine and camera position. The flipper timing and small mouth are still feel decisions for playtesting.

## Sky Sanctuary restore prompt

> Start from current main. Restore Sky Sanctuary as optional DLC using commit `6dd6578d8b5e92f7030980bb6feb92acae45e2d0` as the source for its art, theme, scenery, atmosphere, motion and tests. Port its registration and bake hooks to the current code. Keep the five-stage base roster as the default and preserve later ramp, Loop, physics and renderer changes. Verify DLC-off and DLC-on setup, bake and play the Workshop in Sky Sanctuary, capture the result, then commit and push.
