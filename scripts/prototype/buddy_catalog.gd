extends RefCounted
## Adventure identities; all effects and rarity here are adaptations for our game.
const SOURCE_GAME := "Sonic Runners Adventure"
const ENTRIES := {
 "chip": {"name": "Chip", "max_level": 1, "persistent": true, "effects": [{"id": "rescue", "values": [1]}], "descriptions": ["Once per run: rescue your final lost Ball.\nGrants 1 emergency Ball in the current Act."]},
 "dark_chao": {"name": "Dark Chao", "max_level": 2, "persistent": true, "effects": [{"id": "score_percent", "kinds": ["enemy"], "values": [0.25, 0.50]}, {"id": "enemy_rings", "values": [1, 2]}], "descriptions": ["+25% enemy score; +1 virtual Ring per enemy.", "+50% enemy score; +2 virtual Rings per enemy."]},
 "dark_chaos": {"name": "Dark Chaos", "max_level": 2, "persistent": true, "effects": [{"id": "score_percent", "kinds": ["*"], "values": [0.08, 0.16]}, {"id": "starting_balls", "values": [-1, -1]}], "descriptions": ["+8% all score. −1 starting Ball per Act.\nMinimum 1; Practice ignores the penalty.", "+16% all score. Still only −1 Ball per Act.\nMinimum 1; Practice ignores the penalty."]},
 "hero_chaos": {"name": "Hero Chaos", "max_level": 2, "persistent": true, "effects": [{"id": "score_percent", "kinds": ["*"], "values": [0.02, 0.04]}], "descriptions": ["+2% all score.", "+4% all score."]},
 "knuckles_omochao": {"name": "Knuckles Omochao", "max_level": 2, "persistent": true, "effects": [{"id": "score_percent", "kinds": ["bumper"], "values": [0.25, 0.50]}], "descriptions": ["+25% Bumper score, after combo and Special.", "+50% Bumper score, after combo and Special."]},
 "rc_tornado": {"name": "RC Tornado", "max_level": 1, "persistent": false, "effects": [{"id": "next_act_balls", "values": [1]}], "descriptions": ["+1 starting Ball for the next Act only.\nOne-shot reward; uses no persistent slot."]},
 "rc_ufo": {"name": "RC UFO", "max_level": 2, "persistent": true, "effects": [{"id": "physical_ring_cadence", "every": 4, "values": [1, 2]}], "descriptions": ["Every 4 physical Rings: +1 virtual Ring.\nProgress carries across Acts this run.", "Every 4 physical Rings: +2 virtual Rings.\nProgress carries across Acts this run."]},
 "sonic_omochao": {"name": "Sonic Omochao", "max_level": 2, "persistent": true, "effects": [{"id": "physics", "values": [{"rolling_acceleration": 1.10, "max_rolling_speed": 1.08, "max_downward_speed": 1.02}, {"rolling_acceleration": 1.20, "max_rolling_speed": 1.16, "max_downward_speed": 1.04}]}], "descriptions": ["Speed+: rolling acceleration +10%, rolling cap +8%.\nDownward cap +2%.", "Speed+: rolling acceleration +20%, rolling cap +16%.\nDownward cap +4%."]},
 "tails_omochao": {"name": "Tails Omochao", "max_level": 2, "persistent": true, "effects": [{"id": "physics", "values": [{"gravity_scale": 0.92, "max_downward_speed": 0.94}, {"gravity_scale": 0.84, "max_downward_speed": 0.88}]}], "descriptions": ["Float+: gravity −8%, downward cap −6%.\nBall mass stays unchanged.", "Float+: gravity −16%, downward cap −12%.\nBall mass stays unchanged."]},
 "wizard_chao": {"name": "Wizard Chao", "max_level": 2, "persistent": true, "effects": [{"id": "score_percent", "kinds": ["ring_rack", "switch_bank", "spinner_goal", "lane_set"], "values": [0.25, 0.50]}], "descriptions": ["+25% completion score: Bonus Racks, Switch Banks,\nSpinner Goals and Lane Sets.", "+50% completion score: Bonus Racks, Switch Banks,\nSpinner Goals and Lane Sets."]},
 "yacker": {"name": "Yacker", "max_level": 2, "persistent": true, "effects": [{"id": "physics", "values": [{"ring_magnet_radius": 1.25}, {"ring_magnet_radius": 1.50}]}], "descriptions": ["Magnet+: +25% Ring magnet radius.", "Magnet+: +50% Ring magnet radius."]}
}

static func definition(id: String) -> Dictionary:
 if not ENTRIES.has(id): return {}
 var item: Dictionary = ENTRIES[id].duplicate(true)
 item.merge({"id": id, "display_name": item.name, "source_game": SOURCE_GAME, "art_path": "res://assets/ui/buddies/sra/" + id + ".png", "source_art_url": "", "prototype_rarity": "unweighted", "consumable": not item.persistent})
 var path := "res://assets/ui/buddies/sra/sources.json"
 if FileAccess.file_exists(path):
  var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
  if manifest is Dictionary and manifest.has(id): item.source_art_url = manifest[id].get("asset_url", "")
 return item
