extends RefCounted
class_name CityServices

## หน้าต่างบริการของอาคารในเมือง (เปิดเมื่อเดินไปถึงประตูแล้วกด [F])
## market / tavern / auction / clinic / intel / faction / poison / assassin / arena / palace
## สินค้า ภารกิจ ล็อตประมูล และสัญญาลอบสังหาร สุ่มใหม่ทุก REFRESH_DAYS วัน (คงที่ตลอดรอบ)

const REFRESH_DAYS = 10

var sect: SectData
var city_id: String
var city: Dictionary
## ฉากเมือง (ใช้เปลี่ยนฉากไปต่อสู้ และจำตำแหน่งตัวละคร)
var scene: Node
var say: Callable
var refresh: Callable

var _auction_bids := {}
var _lots: Array = []
var _equipment_stock: Array = []
var _quests: Array = []
var _contracts: Array = []

func _init(p_scene: Node, p_city_id: String, p_say: Callable, p_refresh: Callable) -> void:
	scene = p_scene
	city_id = p_city_id
	sect = GlobalGame.current_sect
	city = WorldDB.get_node_data(city_id)
	say = p_say
	refresh = p_refresh
	_generate_period_content()

func build(service: String, c: VBoxContainer) -> void:
	c.add_child(UIKit.label("เงินสำนัก: %d" % sect.money, 15, Color(1, 0.85, 0.4)))
	match service:
		"market": _build_market(c)
		"tavern": _build_tavern(c)
		"auction": _build_auction(c)
		"clinic": _build_clinic(c)
		"intel": _build_intel(c)
		"faction": _build_faction(c)
		"poison": _build_poison(c)
		"assassin": _build_assassin(c)
		"arena": _build_arena(c)
		"palace": _build_palace(c)
		"scripture": _build_scripture(c)
		"sparring": _build_sparring(c)

func _period() -> int:
	return int(sect.current_day / float(REFRESH_DAYS))

func _task_key(kind: String, index: int) -> String:
	return "%s:%s:%d:%d" % [kind, city_id, _period(), index]

## ศิษย์ที่ประจำอยู่ในเมืองนี้ (ใช้ต่อสู้)
func fighters() -> Array[DiscipleData]:
	var result: Array[DiscipleData] = []
	for d in ExpeditionSys.get_stationed_at(sect, city_id):
		if not d.disabled: result.append(d)
	return result

func _generate_period_content() -> void:
	seed(hash("%s:%d" % [city_id, _period()]))
	var shop_rarity: int = city.get("shop_rarity", 0)
	_equipment_stock.clear()
	for i in 3:
		_equipment_stock.append(EquipmentDB.generate(EquipmentDB.BASES.keys().pick_random(), clampi(shop_rarity + (1 if randf() < 0.25 else 0), 0, 4)))

	_quests.clear()
	var wild_nodes: Array = []
	for id in WorldDB.NODES:
		if WorldDB.NODES[id].has("enemies"): wild_nodes.append(id)
	for i in 3:
		if randf() < 0.5:
			var mat = ["spirit_grass", "iron_ore", "beast_hide", "blood_ginseng", "cold_iron", "beast_core"].pick_random()
			var amount = randi_range(3, 10) if MaterialDB.get_price(mat) < 50 else randi_range(1, 3)
			_quests.append({ "kind": "deliver", "material": mat, "amount": amount, "reward": int(MaterialDB.get_price(mat) * amount * 1.8) })
		else:
			var node_id = wild_nodes.pick_random()
			var enemy_id = WorldDB.NODES[node_id].enemies.pick_random()
			_quests.append({ "kind": "bounty", "enemy": enemy_id, "count": randi_range(1, 2), "reward": 150 + EnemyDB.ENEMIES[enemy_id].level * 60 })

	_lots.clear()
	if city.get("auction", false):
		for i in 3:
			var roll = randf()
			if roll < 0.5:
				var eq = EquipmentDB.generate_random(1.0, EquipmentData.Rarity.RARE)
				_lots.append({ "kind": "equipment", "item": eq, "value": eq.get_value() * 3 })
			elif roll < 0.8:
				var tier = SkillDB.Tier.HEAVEN if randf() < 0.85 else SkillDB.Tier.IMMORTAL
				_lots.append({ "kind": "skill", "item": SkillDB.get_random_skill_by_tier(tier), "value": 1200 * (tier - 2) * (tier - 2) + 800 })
			else:
				var mat = ["snow_lotus", "star_metal", "dragon_scale"].pick_random()
				var amount = 1 if mat == "dragon_scale" else randi_range(2, 4)
				_lots.append({ "kind": "material", "item": mat, "amount": amount, "value": MaterialDB.get_price(mat) * amount })

	# สัญญาลอบสังหาร: เป้าหมายคือยอดฝีมือหรือขุนนางของขั้วอำนาจ (ลงมือได้เฉพาะกลางคืนในเมืองนี้)
	_contracts.clear()
	var champs = sect.champions.filter(func(c): return not c.name in FactionDB.FACTIONS.values().map(func(f): return f.leader))
	for i in 2:
		if champs.is_empty(): break
		var c: Dictionary = champs.pick_random()
		_contracts.append({ "target": c.name, "faction": c.faction, "reward": 600 + int(c.power / 20.0), "risk": clampi(int(c.power / 400.0), 1, 5) })
	randomize()

# ══════════════════════════════════════════
# ตลาด
# ══════════════════════════════════════════

func owner_mult() -> float:
	var owner: String = sect.node_owner.get(city_id, "")
	if owner == "player": return 0.8
	if FactionSys.is_hostile(sect, owner): return 1.3
	return 1.0

func buy_price(mat: String) -> int:
	return int(MaterialDB.get_price(mat) * city.get("price_mult", 1.0) * owner_mult() * sect.get_city_price_factor(city_id))

func _sell_price(base: int) -> int:
	return max(1, int(base * city.get("sell_rate", 0.5)))

func _build_market(c: VBoxContainer) -> void:
	c.add_child(UIKit.section("ซื้อวัตถุดิบ"))
	for mat in city.get("shop", []):
		var price = buy_price(mat)
		c.add_child(UIKit.row("%s - %d เงิน/ชิ้น (มี %d)" % [MaterialDB.get_material_name(mat), price, sect.get_material_count(mat)], [
			UIKit.button("ซื้อ 1", func(): _buy_material(mat, 1), sect.money < price),
			UIKit.button("ซื้อ 10", func(): _buy_material(mat, 10), sect.money < price * 10),
		]))
	c.add_child(UIKit.section("อุปกรณ์วางขาย (สินค้าเปลี่ยนทุก %d วัน)" % REFRESH_DAYS))
	for i in _equipment_stock.size():
		var eq: EquipmentData = _equipment_stock[i]
		var key = _task_key("buy", i)
		var price = int(eq.get_value() * 2 * city.get("price_mult", 1.0))
		var sold = sect.completed_world_tasks.has(key)
		c.add_child(UIKit.row("[%s] %s (%s) %s - %d เงิน" % [eq.get_rarity_name(), eq.item_name, eq.get_type_name(), eq.get_stat_text().replace("\n", " "), price], [
			UIKit.button("ขายแล้ว" if sold else "ซื้อ", func():
				sect.money -= price
				sect.equipment_storage.append(eq)
				sect.completed_world_tasks.append(key)
				say.call("พ่อค้า: 'ของดีมีคุณภาพ รับรองไม่ผิดหวัง!'")
				refresh.call(), sold or sect.money < price)
		], eq.get_rarity_color()))
	c.add_child(UIKit.section("ขายวัตถุดิบ (ราคารับซื้อ %d%%)" % int(city.get("sell_rate", 0.5) * 100)))
	if sect.materials.is_empty():
		c.add_child(UIKit.label("ไม่มีวัตถุดิบในคลัง", 14, WuxiaTheme.PAPER_DIM))
	for mat in sect.materials.keys():
		var price = _sell_price(MaterialDB.get_price(mat))
		c.add_child(UIKit.row("%s x%d - รับซื้อ %d/ชิ้น" % [MaterialDB.get_material_name(mat), sect.get_material_count(mat), price], [
			UIKit.button("ขาย 1", func(): _sell_material(mat, 1)),
			UIKit.button("ขายทั้งหมด", func(): _sell_material(mat, sect.get_material_count(mat))),
		]))
	c.add_child(UIKit.section("ขายอุปกรณ์ในคลัง"))
	for eq in sect.equipment_storage.duplicate():
		var price = _sell_price(eq.get_value())
		c.add_child(UIKit.row("[%s] %s - รับซื้อ %d" % [eq.get_rarity_name(), eq.item_name, price], [
			UIKit.button("ขาย", func():
				sect.equipment_storage.erase(eq)
				sect.money += price
				refresh.call())
		], eq.get_rarity_color()))

func _buy_material(mat: String, amount: int) -> void:
	var cost = buy_price(mat) * amount
	if sect.money < cost: return
	sect.money -= cost
	sect.add_material(mat, amount)
	say.call("พ่อค้า: 'ขอบคุณที่อุดหนุน! %s %d ชิ้น'" % [MaterialDB.get_material_name(mat), amount])
	refresh.call()

func _sell_material(mat: String, amount: int) -> void:
	amount = min(amount, sect.get_material_count(mat))
	if amount <= 0: return
	sect.add_material(mat, -amount)
	sect.money += _sell_price(MaterialDB.get_price(mat)) * amount
	refresh.call()

# ══════════════════════════════════════════
# โรงเตี๊ยม: กระดานภารกิจ ข่าวลือ จ้างจอมยุทธ์ พักค้างคืน
# ══════════════════════════════════════════

func _build_tavern(c: VBoxContainer) -> void:
	say.call("เสี่ยวเอ้อ: 'กระดานภารกิจอยู่ทางนั้นขอรับ ได้ยินว่า%s'" % [
		"แดนลับบรรพกาลกำลังเปิดอยู่!" if WorldDB.is_secret_realm_open(sect.current_day) else "แดนลับบรรพกาลจะเปิดในอีก %d วัน" % WorldDB.days_until_secret_realm(sect.current_day)])
	c.add_child(UIKit.section("กระดานภารกิจ (ภารกิจใหม่ทุก %d วัน)" % REFRESH_DAYS))
	var team = fighters()
	for i in _quests.size():
		var q: Dictionary = _quests[i]
		var key = _task_key("quest", i)
		var done = sect.completed_world_tasks.has(key)
		if q.kind == "deliver":
			var have = sect.get_material_count(q.material)
			c.add_child(UIKit.row("[ส่งของ] ต้องการ %s x%d (มี %d) - รางวัล %d เงิน" % [MaterialDB.get_material_name(q.material), q.amount, have, q.reward], [
				UIKit.button("สำเร็จแล้ว" if done else "ส่งมอบ", func():
					sect.add_material(q.material, -q.amount)
					sect.money += q.reward
					sect.completed_world_tasks.append(key)
					say.call("ผู้ว่าจ้าง: 'ขอบคุณมาก! นี่คือค่าตอบแทน %d เงิน'" % q.reward)
					refresh.call(), done or have < q.amount)
			]))
		else:
			var e = EnemyDB.ENEMIES[q.enemy]
			c.add_child(UIKit.row("[ล่าค่าหัว] ปราบ %s x%d (พลัง ~%d) - รางวัล %d เงิน" % [e.name, q.count, EnemyDB.get_power(q.enemy), q.reward], [
				UIKit.button("สำเร็จแล้ว" if done else "ออกล่า", func():
					var enemies: Array[Dictionary] = []
					for n in q.count: enemies.append(EnemyDB.get_enemy(q.enemy))
					start_combat(enemies, { "type": "bounty", "node": city_id, "faction": "" }, q.reward, key), done or team.is_empty())
			], Color(1, 0.7, 0.6)))

	c.add_child(UIKit.section("ข่าวลือในโรงเตี๊ยม"))
	for t in rumors(4):
		c.add_child(UIKit.rich("[color=#b8b0a0]• %s[/color]" % t))

	c.add_child(UIKit.section("จ้างจอมยุทธ์พเนจร"))
	var key = _task_key("hire", 0)
	var cost = 500 + sect.current_day * 2
	var full = sect.get_active_disciples().size() >= sect.get_max_disciples()
	c.add_child(UIKit.row("จอมยุทธ์พเนจรนั่งดื่มสุราอยู่มุมร้าน ยินดีเข้าสำนักถ้าค่าจ้างคุ้ม (%d เงิน)" % cost, [
		UIKit.button("จ้างแล้ว" if sect.completed_world_tasks.has(key) else ("ศิษย์เต็ม" if full else "จ้าง"), func():
			sect.money -= cost
			sect.completed_world_tasks.append(key)
			var npc = NPCGenerator.generate_npc(1, randi_range(4, 10))
			npc.ambition = "ค้นหาความหมายของวิถียุทธ์"
			sect.disciples.append(npc)
			for s in npc.innate_skills: sect.add_library_skill(s)
			sect.log_event(sect.current_day, "จ้างจอมยุทธ์พเนจร %s (%s พลังรบ %d) เข้าสำนักที่%s" % [npc.disciple_name, npc.realm_name, npc.get_power_rating(), city.name])
			say.call("%s: 'ข้าจะเดินทางไปสำนักของท่านทันที'" % npc.disciple_name)
			refresh.call(), full or sect.money < cost or sect.completed_world_tasks.has(key))
	]))

	c.add_child(UIKit.section("ห้องพัก (20 เงิน)"))
	var row = HBoxContainer.new()
	row.add_child(UIKit.button("พักจนถึงกลางคืน", func(): _rest_until(2), sect.money < 20 or sect.time_phase == 2))
	row.add_child(UIKit.button("พักจนถึงเช้า", func(): _rest_until(0), sect.money < 20 or sect.time_phase == 0))
	c.add_child(row)

func _rest_until(phase: int) -> void:
	sect.money -= 20
	while sect.time_phase != phase:
		GlobalGame.advance_phase()
	say.call("เสี่ยวเอ้อ: 'ตื่นแล้วหรือขอรับ ตอนนี้เป็นยาม%sแล้ว'" % GlobalGame.PHASE_NAMES[phase])
	refresh.call()

## ข่าวลือ = เหตุการณ์ยุทธภพล่าสุดในบันทึก (การเดินหมากของขั้วอำนาจ)
func rumors(count: int) -> Array[String]:
	var result: Array[String] = []
	for i in range(sect.event_log.size() - 1, -1, -1):
		var t: String = sect.event_log[i].text
		if t.contains("[ยุทธภพ]") or t.contains("[ราชสำนัก]") or t.contains("[มณฑล") or t.contains("[ดินแดน") or t.contains("[พันธมิตร"):
			var plain = RegEx.create_from_string("\\[/?color[^\\]]*\\]").sub(t, "", true)
			result.append("วันที่ %d: %s" % [sect.event_log[i].day, plain])
			if result.size() >= count: break
	if result.is_empty(): result.append("ช่วงนี้ยุทธภพยังสงบ ไม่มีข่าวใหญ่")
	return result

# ══════════════════════════════════════════
# โรงประมูล
# ══════════════════════════════════════════

func _lot_text(lot: Dictionary) -> String:
	match lot.kind:
		"equipment": return "[%s] %s (%s) %s" % [lot.item.get_rarity_name(), lot.item.item_name, lot.item.get_type_name(), lot.item.get_stat_text().replace("\n", " ")]
		"skill":
			var s = SkillDB.get_skill(lot.item)
			return "คัมภีร์วิชาขั้น%s: %s - %s" % [SkillDB.TIER_NAMES[s.tier], lot.item, s.desc]
		"material": return "%s x%d" % [MaterialDB.get_material_name(lot.item), lot.amount]
	return ""

func _build_auction(c: VBoxContainer) -> void:
	if _lots.is_empty():
		c.add_child(UIKit.label("เมืองนี้ไม่มีการประมูลรอบนี้", 15, WuxiaTheme.PAPER_DIM))
		return
	c.add_child(UIKit.label("กติกา: กดเสนอราคา (+10%) แล้วรอดูว่าคู่แข่งจะสู้ราคาไหม ถ้าไม่มีใครสู้ต่อ คุณชนะการประมูล", 14, WuxiaTheme.PAPER_DIM))
	for i in _lots.size():
		var lot: Dictionary = _lots[i]
		var key = _task_key("lot", i)
		c.add_child(HSeparator.new())
		var color = lot.item.get_rarity_color() if lot.kind == "equipment" else Color(0.85, 0.7, 1.0)
		c.add_child(UIKit.label("ล็อตที่ %d: %s" % [i + 1, _lot_text(lot)], 16, color))
		if sect.completed_world_tasks.has(key):
			c.add_child(UIKit.label("ปิดการประมูลแล้ว", 14, WuxiaTheme.PAPER_DIM))
			continue
		var current: int = _auction_bids.get(i, int(lot.value * 0.5))
		var next_bid = int(current * 1.1) + 10
		c.add_child(UIKit.row("ราคาปัจจุบัน: %d  (ราคาประเมิน ~%d)" % [current, lot.value], [
			UIKit.button("เสนอ %d" % next_bid, func(): _place_bid(i, next_bid), sect.money < next_bid),
		]))

func _place_bid(index: int, bid: int) -> void:
	if sect.money < bid or sect.completed_world_tasks.has(_task_key("lot", index)): return
	var lot: Dictionary = _lots[index]
	var rival_chance = clamp(1.25 - float(bid) / lot.value, 0.0, 0.9)
	if randf() < rival_chance:
		var rival_bid = int(bid * randf_range(1.05, 1.2))
		_auction_bids[index] = rival_bid
		say.call("ผู้อาวุโสจาก%s: 'ข้าให้ %d!' (ทั้งห้องประมูลฮือฮา)" % [FactionDB.FACTIONS[FactionDB.FACTIONS.keys().pick_random()].name, rival_bid])
	else:
		sect.money -= bid
		sect.completed_world_tasks.append(_task_key("lot", index))
		match lot.kind:
			"equipment": sect.equipment_storage.append(lot.item)
			"skill": sect.add_library_skill(lot.item)
			"material": sect.add_material(lot.item, lot.amount)
		sect.log_event(sect.current_day, "ประมูลได้ %s ที่%s ในราคา %d" % [_lot_text(lot), city.name, bid])
		say.call("ผู้ดำเนินการประมูล: 'ปิดการประมูล! ล็อตนี้เป็นของสำนัก%s ในราคา %d!'" % [sect.sect_name, bid])
	refresh.call()

# ══════════════════════════════════════════
# โรงหมอ / ร้านยาพิษลับ
# ══════════════════════════════════════════

const CLINIC_PRICES = { "internal_injury": 120, "meridian_damage": 450 }

func _patients() -> Array:
	return sect.get_active_disciples().filter(func(d): return d.injury_days > 0 or not d.ailments.is_empty())

func _build_clinic(c: VBoxContainer) -> void:
	say.call("หมอชรา: 'บาดเจ็บภายในหรือเส้นชีพจรขาด ข้ารักษาได้ แต่พิษกู่... ต้องไปหาคนในตรอกมืด'")
	c.add_child(UIKit.label("รักษาศิษย์ของสำนักได้ทันที (ส่งข่าวไปถึงสำนัก ไม่ต้องพาตัวมา)", 13, WuxiaTheme.PAPER_DIM))
	var any = false
	for d in _patients():
		any = true
		if d.injury_days > 0:
			var cost = d.injury_days * 40
			c.add_child(UIKit.row("%s บาดเจ็บ ต้องพักอีก %d วัน" % [d.disciple_name, d.injury_days], [UIKit.button("รักษาให้หาย (%d)" % cost, func():
				sect.money -= cost
				d.injury_days = 0
				if d.status == DiscipleData.DiscipleStatus.INJURED: d.status = DiscipleData.DiscipleStatus.IDLE
				refresh.call(), sect.money < cost)]))
		for a in d.ailments:
			if not CLINIC_PRICES.has(a.id): continue
			var cost: int = CLINIC_PRICES[a.id]
			var aid: String = a.id
			c.add_child(UIKit.row("%s: %s (เป็นมา %d วัน)" % [d.disciple_name, AilmentDB.get_ailment(aid).name, a.days], [UIKit.button("ฝังเข็มรักษา (%d)" % cost, func():
				sect.money -= cost
				d.remove_ailment(aid)
				sect.log_event(sect.current_day, "หมอที่%s รักษา%sของ %s สำเร็จ" % [city.name, AilmentDB.get_ailment(aid).name, d.disciple_name])
				refresh.call(), sect.money < cost)]))
	if not any: c.add_child(UIKit.label("ศิษย์ทุกคนแข็งแรงดี", 15))

func _build_poison(c: VBoxContainer) -> void:
	say.call("หญิงชราคลุมหน้า: 'ของที่นี่ไม่มีขายในตลาด... จ่ายเงินแล้วอย่าถามมาก'")
	c.add_child(UIKit.section("ถอนพิษกู่ (หมอทั่วไปรักษาไม่ได้)"))
	var any = false
	for d in sect.get_active_disciples():
		if not d.has_ailment("gu_poison"): continue
		any = true
		var cost = 700
		c.add_child(UIKit.row("%s ติดพิษกู่" % d.disciple_name, [UIKit.button("ซื้อยาถอนพิษ (%d)" % cost, func():
			sect.money -= cost
			d.remove_ailment("gu_poison")
			sect.log_event(sect.current_day, "ซื้อยาถอนพิษกู่จากตรอกมืดที่%s ให้ %s" % [city.name, d.disciple_name])
			refresh.call(), sect.money < cost)]))
	if not any: c.add_child(UIKit.label("ไม่มีศิษย์คนไหนติดพิษกู่", 14, WuxiaTheme.PAPER_DIM))
	c.add_child(UIKit.section("สมุนไพรพิษและของเถื่อน"))
	for mat in ["blood_ginseng", "beast_core", "spirit_grass"]:
		var price = int(buy_price(mat) * 0.9)
		c.add_child(UIKit.row("%s - %d เงิน" % [MaterialDB.get_material_name(mat), price], [
			UIKit.button("ซื้อ 1", func():
				sect.money -= price
				sect.add_material(mat, 1)
				refresh.call(), sect.money < price)]))

# ══════════════════════════════════════════
# หอข่าว: ซื้อความลับของขั้วอำนาจ
# ══════════════════════════════════════════

const INTEL_DAYS = 30

func intel_cost(fid: String) -> int:
	return 150 + int(sect.factions[fid].power / 200.0)

## ซื้อความลับ: รู้จุดอ่อนของขั้วอำนาจนั้น 30 วัน (ศัตรูจากฝ่ายนั้นอ่อนลงในการต่อสู้)
func buy_intel(fid: String, cost: int) -> void:
	if sect.money < cost: return
	sect.money -= cost
	sect.intel[fid] = sect.current_day + INTEL_DAYS
	var f = FactionDB.FACTIONS[fid]
	var foes: Array = []
	for o in FactionDB.FACTIONS:
		if o != fid and FactionSys.get_rel(sect, fid, o) <= -45: foes.append(FactionDB.FACTIONS[o].name)
	var champ = ""
	for ch in sect.champions:
		if ch.faction == fid: champ = "%s '%s' (พลัง %d)" % [ch.name, ch.title, ch.power]
	sect.log_event(sect.current_day, "[color=#c0b0ff]ความลับของ%s: พลังสำนัก %d, ยอดฝีมือ %s, ศัตรูลับ: %s — รู้จุดอ่อนของพวกมัน %d วัน (ศัตรูฝ่ายนี้ป้องกันและโจมตีลดลง)[/color]" % [f.name, sect.factions[fid].power, champ if champ != "" else "-", ", ".join(foes.slice(0, 3)) if not foes.is_empty() else "-", INTEL_DAYS])
	say.call("คนขายข่าว: 'ความลับของ%s... ท่านจะไม่ผิดหวัง'" % f.name)
	refresh.call()

func _build_intel(c: VBoxContainer) -> void:
	say.call("เจ้าของหอข่าว: 'ทุกความลับในใต้หล้ามีราคา ขอเพียงท่านจ่ายไหว'")
	c.add_child(UIKit.label("ซื้อความลับ = รู้จุดอ่อน %d วัน: ศัตรูจากฝ่ายนั้นโจมตี -10%% ป้องกัน -25%% ในการต่อสู้" % INTEL_DAYS, 13, WuxiaTheme.PAPER_DIM))
	var ids = FactionDB.FACTIONS.keys()
	ids.sort_custom(func(a, b): return FactionSys.is_hostile(sect, a) and not FactionSys.is_hostile(sect, b))
	for fid in ids:
		var cost = intel_cost(fid)
		var known = sect.intel.get(fid, 0) > sect.current_day
		c.add_child(UIKit.row("%s%s" % [FactionDB.FACTIONS[fid].name, " (รู้จุดอ่อนอีก %d วัน)" % (sect.intel[fid] - sect.current_day) if known else ""], [
			UIKit.button("ซื้อความลับ (%d)" % cost, func(): buy_intel(fid, cost), sect.money < cost)
		], Color(1, 0.55, 0.5) if FactionSys.is_hostile(sect, fid) else WuxiaTheme.PAPER))

# ══════════════════════════════════════════
# สำนักงานใหญ่ของขั้วอำนาจในเมือง
# ══════════════════════════════════════════

func _build_faction(c: VBoxContainer) -> void:
	var hq = WorldDB.get_city_hq(city_id)
	if hq.is_empty():
		c.add_child(UIKit.label("ไม่มีขั้วอำนาจตั้งสำนักงานใหญ่ที่นี่", 15))
		return
	var lord = sect.city_lords.get(city_id, {})
	if not lord.is_empty():
		c.add_child(UIKit.label("เจ้าเมือง: %s (คนของ%s)" % [lord.name, FactionDB.FACTIONS[lord.faction].name], 15, WuxiaTheme.BRONZE))
	for fid in hq:
		var info = FactionDB.FACTIONS[fid]
		var f = sect.factions[fid]
		c.add_child(UIKit.section(info.name))
		c.add_child(UIKit.label("%s\nพลัง %d · ความสัมพันธ์ %+d%s" % [info.desc, f.power, f.relation, " (สงคราม!)" if f.war else ""], 14))
		var row = HFlowContainer.new()
		row.add_child(UIKit.button("ของกำนัล (%d)" % FactionSys.gift_cost(sect, fid), func():
			GlobalGame.controller.request_diplomacy.emit("gift", fid)
			refresh.call(), sect.money < FactionSys.gift_cost(sect, fid)))
		row.add_child(UIKit.button("ขอประลองฉันมิตร", func():
			start_combat(FactionSys.make_enemies(sect, fid, 2, false), { "type": "spar", "node": city_id, "faction": fid }), FactionSys.is_hostile(sect, fid) or fighters().is_empty()))
		c.add_child(row)
	if fighters().is_empty():
		c.add_child(UIKit.label("การประลองต้องมีศิษย์ประจำอยู่ในเมือง", 13, WuxiaTheme.PAPER_DIM))

# ══════════════════════════════════════════
# สมาคมนักฆ่า: สัญญาลอบสังหาร (ลงมือเองตอนกลางคืน)
# ══════════════════════════════════════════

func _build_assassin(c: VBoxContainer) -> void:
	say.call("ชายสวมหน้ากาก: 'เป้าหมายจะออกมาเดินเล่นที่ลานกลางเมืองยามวิกาล... ระวังทหารยามด้วยล่ะ'")
	c.add_child(UIKit.label("รับสัญญาแล้ว รอถึงกลางคืน เป้าหมายจะปรากฏที่ลานกลางเมืองพร้อมองครักษ์ เดินไปให้ถึงตัวโดยไม่ถูกเห็นแล้วกด [F]\nเดินในตรอกมืด/นอกแสงโคม และกด [C] ย่องเบา จะถูกมองเห็นยากขึ้น ถ้าถูกจับได้ต้องสู้กับทหารยาม", 13, WuxiaTheme.PAPER_DIM))
	var active = sect.active_contract
	if not active.is_empty():
		c.add_child(UIKit.label("สัญญาที่รับไว้: ลอบสังหาร %s แห่ง%s ที่%s (ค่าจ้าง %d)" % [active.target, FactionDB.FACTIONS[active.faction].name, WorldDB.NODES[active.city].name, active.reward], 15, Color(1, 0.5, 0.45)))
		c.add_child(UIKit.button("ยกเลิกสัญญา", func():
			sect.active_contract = {}
			refresh.call()))
		return
	for i in _contracts.size():
		var k = _contracts[i]
		var key = _task_key("contract", i)
		var done = sect.completed_world_tasks.has(key)
		c.add_child(UIKit.row("เป้าหมาย: %s แห่ง%s · ค่าจ้าง %d · ความเสี่ยง %s" % [k.target, FactionDB.FACTIONS[k.faction].name, k.reward, "★".repeat(k.risk)], [
			UIKit.button("สำเร็จแล้ว" if done else "รับสัญญา", func():
				sect.active_contract = { "city": city_id, "target": k.target, "faction": k.faction, "reward": k.reward, "risk": k.risk, "key": key }
				say.call("ชายสวมหน้ากาก: 'ดี... อย่าให้ใครเห็นหน้าเจ้า'")
				refresh.call(), done)
		], Color(1, 0.6, 0.55)))

## ลอบสังหารสำเร็จ (เรียกจากฉากเมือง)
func complete_contract() -> String:
	var k = sect.active_contract
	sect.active_contract = {}
	sect.money += k.reward
	sect.completed_world_tasks.append(k.key)
	sect.factions[k.faction].power = int(sect.factions[k.faction].power * 0.97)
	for ch in sect.champions.duplicate():
		if ch.name == k.target: sect.champions.erase(ch)
	var text = "[color=#d07070]%s แห่ง%s ถูกลอบสังหารกลางดึกที่%s ไม่มีใครรู้ว่าเป็นฝีมือใคร (ค่าจ้าง %d)[/color]" % [k.target, FactionDB.FACTIONS[k.faction].name, city.name, k.reward]
	sect.log_event(sect.current_day, text)
	return text

# ══════════════════════════════════════════
# ลานประลองยุทธ์หลวง / พระราชวัง
# ══════════════════════════════════════════

const ARENA_ROUNDS = [
	{ "name": "รอบคัดเลือก", "mult": 1.0, "reward": 300, "fame": 15 },
	{ "name": "รอบรองชนะเลิศ", "mult": 2.0, "reward": 900, "fame": 40 },
	{ "name": "ชิงจ้าวประลองหลวง", "mult": 4.0, "reward": 3000, "fame": 120 },
]

func _build_arena(c: VBoxContainer) -> void:
	if WorldMode.is_sandbox():
		say.call("ผู้ประกาศ: 'ยอดฝีมือจากทั่วแผ่นดิน! เชิญประลองฝีมือเพื่อเกียรติยศและเงินรางวัล!'")
	else:
		say.call("ผู้ประกาศ: 'ยอดฝีมือจากทั่วแผ่นดิน! ผู้ชนะจะได้รับรางวัลจากองค์จักรพรรดิ!'")
	var team = fighters()
	var base = StatSys.world_threat(sect.current_day)
	for i in ARENA_ROUNDS.size():
		var r = ARENA_ROUNDS[i]
		var key = _task_key("arena", i)
		var done = sect.completed_world_tasks.has(key)
		var locked = i > 0 and not sect.completed_world_tasks.has(_task_key("arena", i - 1))
		var foe_power = int(base * r.mult)
		c.add_child(UIKit.row("%s: คู่ต่อสู้พลัง ~%d · รางวัล %d เงิน ชื่อเสียง +%d" % [r.name, foe_power, r.reward, r.fame], [
			UIKit.button("ชนะแล้ว" if done else ("ต้องผ่านรอบก่อน" if locked else "ลงสนาม"), func():
				var foe = StatSys.build_fighter(foe_power, 4.0 + i)
				foe.merge({ "id": "arena_%d" % i, "name": "ยอดฝีมือ%s" % r.name, "art": "human", "color": Color(0.8, 0.6, 0.2), "status_attack": "", "reward_money": 0, "reward_food": 0, "reward_exp": int(foe_power * 3), "drops": {} })
				foe["hp"] = foe.max_hp
				var enemies: Array[Dictionary] = [foe]
				start_combat(enemies, { "type": "arena", "node": city_id, "faction": "", "fame": r.fame }, r.reward, key), done or locked or team.is_empty())
		], Color(1, 0.8, 0.4)))
	if team.is_empty():
		c.add_child(UIKit.label("ต้องมีศิษย์ประจำอยู่ในเมืองจึงจะลงประลองได้", 13, WuxiaTheme.PAPER_DIM))

## ขั้วอำนาจเจ้าของสำนักที่เรากำลังเดินอยู่ ("" ถ้าไม่ใช่สำนัก)
func sect_faction() -> String:
	var fid: String = city.get("faction", "")
	return fid if fid != "" and sect.factions.has(fid) else ""

## หอคัมภีร์ของสำนักอื่น: ซื้อสำเนาวิชาสายของสำนัก (ขั้นสูงสุดที่ซื้อได้ขึ้นกับความสัมพันธ์)
func _build_scripture(c: VBoxContainer) -> void:
	var fid = sect_faction()
	if fid == "":
		c.add_child(UIKit.label("ไม่มีคัมภีร์ให้ดู", 15))
		return
	var info = FactionDB.FACTIONS[fid]
	var rel: int = sect.factions[fid].relation
	var max_tier = 3 if rel >= 40 else (2 if rel >= 10 else 1)
	say.call("บรรณารักษ์: 'หอคัมภีร์ของ%s... ความสัมพันธ์ %+d ท่านดูได้ถึงขั้น%s'" % [info.name, rel, SkillDB.TIER_NAMES[max_tier]])
	c.add_child(UIKit.label("สำเนาวิชาสาย%s ของ%s (ความสัมพันธ์ยิ่งดี ซื้อวิชาขั้นสูงได้ · ได้วิชา = เข้าหอตำราของเรา ศิษย์ที่ความชำนาญถึงเกณฑ์เรียนได้)" % [SkillDB.TYPE_NAMES.get(info.style, info.style), info.name], 13, WuxiaTheme.PAPER_DIM))
	var rng = RandomNumberGenerator.new()
	rng.seed = hash([city_id, _period(), "scripture"])
	for t in range(1, max_tier + 1):
		var pool = SkillDB.SKILLS.keys().filter(func(s): return SkillDB.SKILLS[s].tier == t and SkillDB.SKILLS[s].type == info.style)
		if pool.is_empty(): continue
		var skill: String = pool[rng.randi() % pool.size()]
		var price = int(150 * t * t * (1.0 - clampf(rel, 0, 60) / 200.0))
		var owned = sect.library_skills.has(skill)
		c.add_child(UIKit.row("[%s] %s · พลัง %d — %s" % [SkillDB.TIER_NAMES[t], skill, SkillDB.SKILLS[skill].power, SkillDB.SKILLS[skill].desc], [
			UIKit.button("มีแล้ว" if owned else "ซื้อสำเนา (%d)" % price, func():
				sect.money -= price
				sect.add_library_skill(skill)
				ArchiveSys.unlock_skill(skill)
				sect.log_event(sect.current_day, "ซื้อสำเนาวิชา %s จากหอคัมภีร์ของ%s" % [skill, info.name])
				say.call("ได้สำเนาวิชา %s เข้าหอตำรา" % skill)
				refresh.call(), owned or sect.money < price)
		], SkillDB.TIER_COLORS[t]))

## ลานฝึกของสำนักอื่น: ขอประลองกับศิษย์ (ความสัมพันธ์ดีขึ้นเมื่อชนะ ศิษย์ฝ่ายศัตรูไม่ยอมประลอง)
func _build_sparring(c: VBoxContainer) -> void:
	var fid = sect_faction()
	if fid == "":
		c.add_child(UIKit.label("ไม่มีคู่ประลอง", 15))
		return
	var team = fighters()
	var hostile = FactionSys.is_hostile(sect, fid)
	say.call("ศิษย์เวรลานฝึก: '%s'" % ("ศัตรูของสำนักอย่ามาเหยียบที่นี่!" if hostile else "ยินดีต้อนรับ ท่านอยากประลองฝีมือหรือ?"))
	for i in 3:
		var count = [1, 2, 3][i]
		var key = _task_key("sparring", i)
		var done = sect.completed_world_tasks.has(key)
		c.add_child(UIKit.row("ประลองกับศิษย์ %d คน (พลังต่อคน ~%d) — ชนะ: ความสัมพันธ์ +5 ชื่อเสียงสำนัก +10" % [count, FactionSys.squad_power(sect, fid)], [
			UIKit.button("ชนะแล้ว" if done else "ขอประลอง", func():
				start_combat(FactionSys.make_enemies(sect, fid, count, i == 2), { "type": "spar", "node": city_id, "faction": fid }, 0, key), done or hostile or team.is_empty())
		]))

func _build_palace(c: VBoxContainer) -> void:
	var court_name = FactionDB.FACTIONS.get("f_court", {}).get("name", "ราชสำนัก")
	if WorldMode.is_sandbox():
		say.call("ทหารรักษาพระองค์: 'ผู้ใดจะเข้าเฝ้า %s ต้องแสดงความจงรักภักดีก่อน'" % court_name)
	else:
		say.call("ขันทีหน้าประตู: 'ผู้ใดจะเข้าเฝ้า ต้องแสดงความจงรักภักดีก่อน'")
	var t = sect.pending_tribute
	if not t.is_empty():
		c.add_child(UIKit.row("%sเรียกส่วย %d เงิน (เหลือ %d วัน)" % [FactionSys.eunuch_leader(), t.amount, t.deadline - sect.current_day], [
			UIKit.button("จ่ายส่วย", func():
				GlobalGame.controller.request_pay_tribute.emit()
				refresh.call(), sect.money < t.amount)], Color(0.8, 0.6, 1)))
	for fid in ["f_court", "f_eunuchs"]:
		var cost = FactionSys.gift_cost(sect, fid)
		c.add_child(UIKit.row("ถวายบรรณาการแก่%s (ความสัมพันธ์ %+d)" % [FactionDB.FACTIONS[fid].name, sect.factions[fid].relation], [
			UIKit.button("ถวาย (%d)" % cost, func():
				GlobalGame.controller.request_diplomacy.emit("gift", fid)
				refresh.call(), sect.money < cost)]))
	var court = sect.factions.f_court.relation
	var key = "palace_title:" + city_id
	var ok = court >= 40 and FactionSys.get_prestige(sect) >= 200 and not sect.completed_world_tasks.has(key)
	c.add_child(UIKit.row("ทูลขอพระราชทานป้ายสำนัก (ต้องการความสัมพันธ์ราชสำนัก 40 และชื่อเสียง 200)", [
		UIKit.button("ได้รับแล้ว" if sect.completed_world_tasks.has(key) else "ทูลขอ", func():
			sect.completed_world_tasks.append(key)
			sect.prestige += 80
			for m in FactionDB.members_of("eunuch"): FactionSys.change_rel(sect, "player", m, 10)
			for m in FactionDB.members_of("righteous"): FactionSys.change_rel(sect, "player", m, -5)
			var ruler_text = court_name if WorldMode.is_sandbox() else "องค์จักรพรรดิ"
			sect.log_event(sect.current_day, "[color=gold]%sพระราชทานป้าย 'สำนักผู้ภักดี' แก่สำนัก%s ชื่อเสียง +80[/color]" % [ruler_text, sect.sect_name])
			refresh.call(), not ok)]))

# ══════════════════════════════════════════
# เข้าฉากต่อสู้จากในเมือง
# ══════════════════════════════════════════

func start_combat(enemies: Array[Dictionary], context: Dictionary, bonus_money: int = 0, bonus_task: String = "") -> void:
	var team = fighters()
	if team.is_empty(): return
	GlobalGame.combat_allies.assign(team.slice(0, 4))
	GlobalGame.combat_enemies.assign(enemies)
	GlobalGame.combat_context = context
	GlobalGame.combat_bonus_money = bonus_money
	GlobalGame.combat_bonus_task = bonus_task
	GlobalGame.combat_return_scene = "res://scene/map/city_scene.tscn"
	if scene.has_method("remember_position"): scene.remember_position()
	GlobalGame.save_game()
	scene.get_tree().change_scene_to_file(GlobalGame.COMBAT_SCENE)
