# Prompt สำหรับเจนตัวละครจอมยุทธ์ — ชุดที่ 1: NPC ทั่วไป

ใช้กับเครื่องมือ AI สร้างพิกเซลอาร์ต เช่น PixelLab, Retro Diffusion หรือ Stable Diffusion + LoRA พิกเซล
prompt เป็นภาษาอังกฤษเพราะเครื่องมือส่วนใหญ่เข้าใจดีกว่า (คำอธิบายภาษาไทย)

---

## 0. สเปกไฟล์ที่เกมต้องการ (ให้ตรงกันทุกตัว ระบบจะเสียบแทนภาพเดิมได้ทันที)

| หัวข้อ | ค่า |
|---|---|
| ขนาดช่องต่อเฟรม | 64 x 64 px (ตัวละครสูงประมาณ 44–48 px ยืนชิดขอบล่าง) |
| พื้นหลัง | โปร่งใส (PNG) |
| ทิศ | หน้า (ลง) · ซ้าย · หลัง (ขึ้น) — ทิศขวาเกมกลับด้านจากซ้ายเอง |
| ท่า | ยืนนิ่ง 2–4 เฟรม · เดิน 4–6 เฟรม (ขั้นต่ำ: ยืนนิ่ง 1 เฟรม หันหน้า ก็ใช้ได้ก่อน) |
| แสง | แสงมาจากซ้ายบน · มีเส้นขอบเข้ม 1 px (ถ้าไม่มี เกมเติมให้อัตโนมัติ) |
| ชื่อไฟล์ | `art/characters/npc/<role>_<variant>.png` เช่น `citizen_01.png`, `drunk_02.png` |

---

## 1. บล็อกสไตล์ (ใส่ต่อท้ายทุก prompt — ห้ามแก้ เพื่อให้ทุกตัวสไตล์เดียวกัน)

```
16-bit HD-2D pixel art game sprite, wuxia ancient China, full body, standing, 3/4 front view,
clean pixel art, limited palette (24 colors), crisp 1px dark outline, soft top-left lighting,
cel shading, chibi-realistic proportions (about 3.5 heads tall), transparent background,
centered, no shadow on ground, in the style of Octopath Traveler and Wandering Sword
```

## 2. Negative prompt (ใส่ทุกครั้ง)

```
blurry, anti-aliasing, gradient background, scenery, text, watermark, signature, frame, border,
photorealistic, 3d render, extra limbs, extra fingers, cropped, cut off feet, multiple characters,
modern clothing, japanese kimono, samurai, katana, western armor, glasses
```

## 3. Prompt สำหรับทำสไปรต์ชีต (ใช้หลังได้ตัวที่ชอบแล้ว)

```
character sprite sheet of the same character, 4 rows: walk down, walk left, walk up, idle down,
6 frames per row, 64x64 per frame, consistent design across all frames, [บล็อกสไตล์]
```
> เคล็ดลับ: ใช้ภาพตัวที่ชอบเป็น reference image + seed เดิม · ถ้าเครื่องมือทำชีตไม่ได้ ให้เจนท่าหันหน้าอย่างเดียวก่อน เกมใช้ได้แล้ว

---

## 4. ตัวละคร NPC ทั่วไป (ตรงกับบทบาทที่มีในเกม)

รูปแบบ: **[คำบรรยายตัวละคร], [บล็อกสไตล์]**
แต่ละบทบาทให้เจนอย่างน้อย 3 แบบ (เปลี่ยนเพศ/วัย/สีเสื้อตาม "ตัวแปร") เพื่อไม่ให้คนในเมืองหน้าซ้ำ

### กลางวัน — ในเมือง

| role (ชื่อไฟล์) | ในเกม | Prompt ตัวละคร |
|---|---|---|
| `citizen` | ชาวเมือง | `ordinary townsperson, plain hemp robe tied with cloth belt, cloth shoes, simple hair bun, carrying a small bundle` |
| `villager` | ชาวบ้าน | `peasant villager, rolled-up sleeves, short tunic and loose trousers, straw sandals, holding a bamboo basket` |
| `peddler` | พ่อค้าเร่ | `street peddler, shoulder pole with two baskets of goods, patched brown robe, cloth headband, friendly smile` |
| `scholar` | บัณฑิต | `young scholar, long light-blue scholar robe, black scholar cap, holding a folding fan and a scroll, slim build` |
| `gossip` | นักเล่าข่าว | `storyteller, middle-aged man, gray robe, wooden clapper in hand, thin mustache, animated pose` |
| `quest` | ผู้ว่าจ้างลับ | `wealthy mysterious client, dark crimson brocade robe, jade pendant, hidden hands in sleeves, sly expression` |
| `spy` | ชายสวมหมวกไผ่ | `mysterious man in wide conical bamboo hat covering eyes, dark gray travel cloak, face half hidden` |
| `wanderer` | จอมยุทธ์พเนจร | `wandering swordsman, worn teal travel robe, straight jian sword on back, gourd of wine at waist, messy long hair tied back` |
| `sentry` | ทหารยาม / ศิษย์เวรยาม | `city guard, red and black lamellar vest over robe, spear with red tassel, round helmet, stern face` |

### กลางคืน — ชุด NPC ยามค่ำ

| role | ในเกม | Prompt ตัวละคร |
|---|---|---|
| `drunk` | คนเมา | `drunk man, robe half open, holding a wine jar, flushed red cheeks, staggering pose, disheveled hair` |
| `musician` | นักดนตรีพเนจร | `wandering musician, plain white robe, playing a bamboo flute (dizi), calm closed eyes, long hair` |
| `beggar` | ขอทาน | `old beggar, ragged patched clothes, walking stick, chipped bowl, barefoot, long gray beard` |
| `gambler` | นักพนัน | `gambler, flashy purple robe, holding dice, gold ring, sly grin, slicked hair` |
| `night_traveler` | คนเดินทางยามค่ำ | `night traveler, dark blue cloak with hood, paper lantern in hand, travel bundle on back` |

### ตัวแปรเติมท้ายเพื่อทำหลายแบบ (สุ่มผสมได้)

- **เพศ/วัย:** `young man` · `young woman` · `middle-aged man` · `middle-aged woman` · `old man` · `old woman` · `teenage boy` · `teenage girl`
- **สีเสื้อ:** `earth brown` · `indigo blue` · `faded green` · `ash gray` · `ochre yellow` · `muted red` · `off-white`
- **ทรงผม:** `topknot` · `long hair tied back` · `twin buns` · `braided hair` · `shaved head` · `cloth headwrap`
- **ร่างกาย:** `slim` · `stocky` · `tall` · `short`

ตัวอย่างประกอบเต็ม:
```
young woman, street peddler, shoulder pole with two baskets of goods, faded green robe,
twin buns, slim, 16-bit HD-2D pixel art game sprite, wuxia ancient China, full body, standing,
3/4 front view, clean pixel art, limited palette (24 colors), crisp 1px dark outline,
soft top-left lighting, cel shading, chibi-realistic proportions (about 3.5 heads tall),
transparent background, centered, no shadow on ground, in the style of Octopath Traveler and Wandering Sword
```

---

## 5. ข้อควรระวัง

- **ความสม่ำเสมอ:** AI มักวาดแต่ละเฟรมไม่เหมือนกัน — เลือกเฟรมที่ดีที่สุดแล้วเก็บงานใน Aseprite (หรือ LibreSprite ฟรี)
- **ขนาด:** ถ้าเครื่องมือเจนภาพใหญ่ ให้ย่อด้วย "nearest neighbor" ลงเป็น 64x64 แล้วลดสีเหลือ ~24 สี
- **ลิขสิทธิ์:** อ่านเงื่อนไขการใช้งานเชิงพาณิชย์ของเครื่องมือก่อนขายเกม · ใส่ชื่อเกมอื่นใน prompt ใช้ได้เพื่ออ้างอิงสไตล์ แต่อย่าก๊อปตัวละครของเขา
- **ส่งมาแล้ว:** วางไฟล์ไว้ที่ `art/characters/npc/` ตามชื่อข้างบน แล้วบอก — ระบบจะเสียบแทนภาพจากโค้ดให้

---

## ชุดถัดไป (ยังไม่ทำ)
2. ศิษย์ในสำนัก (แยกตามสายวิชา: กระบี่ ฝ่ามือ อาวุธลับ พิษ ปราณ)
3. ศัตรู (โจรป่า องครักษ์ สำนักมาร สัตว์อสูร)
4. ยอดฝีมือมีชื่อ / ตัวเอก (portrait + sprite)
