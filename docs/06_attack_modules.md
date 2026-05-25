# Burial Protocol - Treasure Chest 1�� ���� ��ȹ��

�ۼ���: 2026-05-01
����: ä�� Ȯ��� �������� �ý����� �� ���� �������� �ʰ�, �����ϰ� �ܰ躰�� �����ϱ� ���� �۾� ��ȹ����.

---

## 0. ���� ����

�� ������ **���� ���ÿ� ��ȹ��**��.

�̹� ��ȹ�� ��ǥ�� �Ʒ��� ����.

1. �������� 1�� ���� ������ ��Ȯ�� �Ѵ�.
2. �� subcell ��� �������� marker ������ Ȯ���Ѵ�.
3. partial reveal, fully reveal, E ��ȣ�ۿ�, reward popup, reward grant�� �ܰ躰�� ������.
4. Codex �۾��� Phase ������ �ɰ� �� �ְ� �Ѵ�.
5. ���� �ھ� ����, v1 ��� ����, v2 �ùķ��̼�, ���ݸ�� �뷱���� ������ �ʰ� �Ѵ�.

�̹� ��ȹ�� ��ü�� �ڵ� ����, �� ����, `.tres` ����, TSV ����, �뷱�� ��ġ ������ �䱸���� �ʴ´�.

---

## 1. ���� ���� ����

�������ڴ� ���� `docs/02_systems_spec.md`�� Mining Ȯ�� �׸� �̹� ���⼺�� �ִ�.

���� ����:

- �¿� �� ���� Ư�� ��ü�� `Treasure Chest`�� `Creep` �� �迭�� ������.
- `Treasure Chest`�� ������ Ư�� ��ü��.
- ä���� ����� �� `E` ��ȣ�ۿ����� ȹ���Ѵ�.
- `Creep`�� ����ũ�� Ư�� ��ü�̸�, 1�� ���� ���������� �����Ѵ�.
- �������ڴ� �� ������ ������ ��������� ����ȴ�.
- ä�� �� ���� ������Ʈ�� ����ȴ�.
- ���� �˾� �� ������ �Ͻ������ȴ�.
- ������ `D~S` ��� ���� ������ ü�踦 ������.

���� ������ `Normal / Silver / Gold / Platinum` �������� ��Ī�� �̹� 1�� �������� `Bronze / Silver / Gold / Platinum`���� �����Ѵ�.

---

## 2. 1�� ���� ����

### ����

- �������ڸ� �����Ѵ�.
- �� ���� treasure marker ������ �����.
- �� reset ������ treasure marker�� �����Ѵ�.
- �������ڴ� 1U ũ���̸�, �¿� ���� 1U wall cell �ϳ��� ��Ȯ�� ���� ��ġ�� �����Ѵ�.
- ����� 1U�� ������ ä���Ǹ� �ش� ��ġ�� �������ڰ� �����Ѵ�.
- 2 x 2 �� ĭ�� ��� ä���Ǿ�� fully revealed ���°� �ȴ�.
- fully revealed ���¿����� `E` ��ȣ�ۿ� �����ϴ�.
- ��ȣ�ۿ� �� `TreasureRewardPopup`�� ����.
- ���� �������� `ȹ��`�ϰų� `�Ǹ�`�� �� �ִ�.
- �ǸŰ��� �ش� ������ ��ȿ ���Ű��� 60%��.
- ��� ���� ���� �������� �����ϴ� helper�� �߰��Ѵ�.
- �ּ� ȸ�� �׽�Ʈ �Ǵ� snapshot �׽�Ʈ�� �߰��Ѵ�.

### ����

- ũ�� ����
- ������ ���� ����
- �������� ���� �ϼ� ��Ʈ
- �������� ��޺� ������ ��ġ bias
- �������� ���� �ű� ������ �뷮 �߰�
- �𷡻��� ����/XP ����/����ָӴ� ���� �ű� ����
- wall reset ������ ����
- ���� v1 ��� ���� ����
- v2 Spawn Pool live ��ȯ
- StageTable ��ġ ����
- ���ݸ�� �뷱�� ����

---

## 3. Ȯ�� ��ȹ

### 3-1. Treasure wall cell alignment

���� ����:

```text
Treasure marker size = 1U wall cell
```

�ǹ�:

```text
1U �� ���� = 1 treasure marker ��ġ
```

���� ĳ���Ͱ� �� ������ ������ ������ �ּ� 2 x 2 = 4�� subcell�� ä���ؾ� �Ѵ�.

�������ڵ� 1U ũ���̹Ƿ�, �������� �ϳ��� ��Ȯ�� 1U wall cell �ϳ��� �����Ѵ�.

### 3-2. �������� ũ��

```text
Treasure Chest world size = 1U x 1U
Treasure marker size = 1 x 1 wall cell
```

�������ڴ� �ݵ�� wall cell grid�� ���ĵǾ� ��ġ�Ǿ�� �Ѵ�.

### 3-3. Partial reveal

2 x 2 marker �� ä���� ĭ��ŭ �������� �Ϻΰ� ������ �Ѵ�.

��:

```text
1ĭ ä��: �������� 1/4 ǥ��
2ĭ ä��: �������� 2/4 ǥ��
3ĭ ä��: �������� 3/4 ǥ��
4ĭ ä��: �������� ��ü ǥ�� + fully revealed
```

fully revealed ������ `E` ��ȣ�ۿ��� �Ұ����ϴ�.

### 3-4. Fully revealed

�Ʒ� ������ �����ϸ� fully revealed��.

```text
marker�� ��ġ�� 1U wall cell�� ������ ä����
```

fully revealed ��:

- ��ȣ�ۿ� �ȳ��� ��� �� �ִ�.
- `E` �Է����� ���� �˾��� �� �� �ִ�.
- ȹ�� �Ǵ� �Ǹ� �� consumed ó���Ѵ�.

---

## 4. �������� rarity

���� `Normal` ��Ī�� ������� �ʰ� `Bronze`�� ����Ѵ�.

�������� rarity:

| Rarity | ID |
|---|---|
| Bronze | `bronze` |
| Silver | `silver` |
| Gold | `gold` |
| Platinum | `platinum` |

### 4-1. �������� rarity ���� Ȯ��

�ʱⰪ�� ������ ī�� ��͵� Ȯ���� �����ϰ� ����Ѵ�.

| Chest Rarity | Chance |
|---|---:|
| Bronze | 70% |
| Silver | 22% |
| Gold | 7% |
| Platinum | 1% |

����:

- �ʱⰪ�� ������ ī�� ��͵��� �����ϴ�.
- �ڵ� ������ ������ ī��� �������� rarity�� �����յǸ� �� �ȴ�.
- ���߿� �������� ���� Ȯ���� �и� ���� �����ؾ� �Ѵ�.

---

## 5. ���� rank Ȯ��

�������� rarity�� ���� roll�ϰ�, �ش� rarity�� ���� reward rank�� roll�Ѵ�.

### 5-1. Bronze chest

| Reward Rank | Chance |
|---|---:|
| D | 80% |
| C | 10% |
| B | 6% |
| A | 4% |
| S | 0% |

### 5-2. Silver chest

| Reward Rank | Chance |
|---|---:|
| D | 70% |
| C | 15% |
| B | 10% |
| A | 5% |
| S | 0% |

### 5-3. Gold chest

| Reward Rank | Chance |
|---|---:|
| D | 55% |
| C | 20% |
| B | 10% |
| A | 10% |
| S | 5% |

### 5-4. Platinum chest

| Reward Rank | Chance |
|---|---:|
| D | 40% |
| C | 25% |
| B | 15% |
| A | 10% |
| S | 10% |

---

## 6. ���� �ĺ�

1�� ���������� ���� `ShopItemCatalog`�� �����ϴ� �����۸� ���� �ĺ��� ����Ѵ�.

���� ī�װ��:

- `attack_module`
- `function_module`
- `enhance_module`

��Ģ:

1. chest rarity roll
2. reward rank roll
3. `ShopItemCatalog`���� �ش� rank�� ��ġ�ϴ� ������ �ĺ� ����
4. �������� ���� �������� �ĺ��� �������� ����
5. �ĺ� �� �ϳ��� weighted �Ǵ� uniform roll
6. reward popup�� ǥ��

�ĺ��� ���� �� fallback:

- 1�� ���������� ���� rank �Ǵ� ���� rank fallback�� ����Ѵ�.
- fallback �߻� �� warning�� �����.
- fallback ��Ģ�� ���� �� ��Ȯ�� �ּ� ó���Ѵ�.

��õ fallback ����:

```text
roll_rank �ĺ� ����
�� ���� chest rarity���� ���� rank �������� �˻�
�� �׷��� ������ ���� rank ���� �˻�
�� �׷��� ������ reward ���� ó�� + warning
```

---

## 7. �ǸŰ� ����

�ǸŰ��� �ش� �������� ��ȿ ���Ű��� 60%��.

```text
sell_price = floor(GameState.get_effective_shop_item_price(item_id) * 0.6)
```

����:

- `price_gold > 0`�� �������� �ش� ���� �������� �Ѵ�.
- `price_gold == 0`�̸� rank fallback ������ �������� �Ѵ�.
- item lookup ���� �Ǵ� ��ȿ ���� 0�� ��� rank fallback ������ �ٽ� Ȯ���Ѵ�.

���� rank fallback ���� ���� ����:

| Rank | Buy Fallback | Sell 60% |
|---|---:|---:|
| D | 15G | 9G |
| C | 30G | 18G |
| B | 60G | 36G |
| A | 120G | 72G |
| S | 240G | 144G |

---

## 8. ���� ������ ���� helper

�������� ������ ���� ���Ű� �ƴϹǷ� ��带 �����ϸ� �� �ȴ�.

���� �Լ�:

```gdscript
GameState.grant_shop_item_reward(item_id: String, source: String = "treasure_chest") -> Dictionary
```

����:

- ��� ���� ���� ���� ������ ȿ���� �����Ѵ�.
- ���� `purchase_shop_item()`�� �������� ���롱 ������ �����Ѵ�.
- ���� ��� ����, reroll, lock ���� ������ ���� �ʴ´�.
- ����� Dictionary�� ��ȯ�Ѵ�.

���� ��ȯ ����:

```gdscript
{
    "success": true,
    "reason": "",
    "item_id": item_id,
    "category": item_category,
    "applied": true,
    "auto_sold": false,
    "gold_gained": 0
}
```

ī�װ���� ó��:

| Category | ó�� |
|---|---|
| `attack_module` | ���� ���ſ� ���� ����/�ռ� ��Ģ ����. ��� ���� ���� |
| `function_module` | ���� �� ȿ�� ��� |
| `enhance_module` | ��� ���� ���� �Ǵ� stack ���� |

����:

- ���� `purchase_shop_item()`�� �����ؼ� �б� �ø��� ����� ���Ѵ�.
- �����ϸ� ���� ���� helper�� �������� ���롱 �κ��� �и��Ѵ�.
- ���� ���� ���� ������ �ٲ�� �� �ȴ�.

---

## 9. Treasure marker ���� ����

### 9-1. ����

Treasure marker�� ���� ���忡 ������� ���� ���� ���� ���� ��������.

�������� object�� marker�� �ٸ���.

| ���� | �ǹ� |
|---|---|
| Treasure Marker | �� �ȿ� ������ 2 x 2 subcell ���� |
| Treasure Visual | ä���� quadrant��ŭ ���̴� partial visual |
| Treasure Chest / Popup | fully revealed �� ��ȣ�ۿ� ������ ���� UI �帧 |

### 9-2. ���� marker �ʵ�

```gdscript
{
    "marker_id": "treasure_0001",
    "chest_rarity": "silver",
    "wall_side": "left",
    "origin_cell_x": 0,
    "origin_cell_y": 12,
    "width_cells": 1,
    "height_cells": 1,
    "revealed_cells": {
        "0,0": false,
        "1,0": false,
        "0,1": false,
        "1,1": false
    },
    "is_fully_revealed": false,
    "reward_item_id": "",
    "reward_seed": 12345,
    "consumed": false
}
```

### 9-3. ��ǥ ����

- `origin_cell_x`, `origin_cell_y`�� marker�� ��ġ�� 1U wall cell ��ǥ��.
- marker�� `2 x 2` ������ �����Ѵ�.
- `origin_cell_y`�� row 0�� ��ġ�� ��ġ�� �����Ѵ�.
- �� �����ϰԴ� `2 x 2` ��� subcell�� wall bounds �ȿ� ���������� �˻��Ѵ�.

---

## 10. Marker ���� ��ġ �ĺ�

### �ĺ� A. `Main.gd`�� ����

����:

- ������ ������.
- Day/run �帧�� �����ϱ� ����.
- popup, interaction, reward ���ޱ��� �� ������ �����ϱ� ����.

����:

- `Main.gd`�� �̹� ���̴�.
- �� ��ǥ/ä�� ���¿� ���õ� å���� `Main.gd`�� �� �����.
- ũ������ Ȯ���ϸ� ������ ����������.

### �ĺ� B. `WorldGrid.gd`�� ����

����:

- �� subcell ���¿� ���� ������.
- ä�� �Ϸ� �� marker ������ ����.
- ��ǥ�� �ϰ����� ���.

����:

- `WorldGrid.gd`�� treasure reward, popup, item grant���� �˸� å���� ��������.
- UI/����� ����Ǹ� world simulation ������ �������.

### �ĺ� C. ���� `TreasureChestManager.gd` �Ǵ� `WallTreasureManager.gd`

����:

- å�� �и��� ���� ����.
- marker ����, reveal, consumed ����, reward roll�� ���� ������ �� �ִ�.
- ���� Creep���� `WallHiddenObjectManager` ���·� Ȯ���ϱ� ����.
- `Main.gd`�� `WorldGrid.gd`�� ���ȭ�� ���δ�.

����:

- �ʹ� ���� ������ �þ��.
- `Main.gd`, `WorldGrid.gd`, UI�� ���� ������ �ʿ��ϴ�.

### ���� ��õ

1�� ���� ��õ�� **���� Manager ����**�̴�.

���� �̸�:

```text
scenes/world/WallTreasureManager.gd
```

�Ǵ�:

```text
scripts/systems/WallTreasureManager.gd
```

����:

- wall reset �� marker ����
- marker bounds/overlap �˻�
- mined subcell �Է��� �޾� partial reveal ����
- fully revealed ���� ���
- ��ȣ�ۿ� ������ marker ��ȸ
- reward roll ��û
- consumed ó��

`WorldGrid.gd`�� �� subcell ä�� ���¸� �����ϰ�, `Main.gd`�� Manager�� UI/interaction�� �����ϴ� ���Ҹ� ���� ���� ����.

---

## 11. Marker ��ġ ��Ģ

�� reset �� treasure marker�� �����Ѵ�.

����� ���� ���� �� wall reset�� �߻��ϹǷ� �� ���� �� �����ȴ�.
���� ��/ä�� ��Ȳ reset �������� ����� ���� marker ���� �Լ��� �����ؾ� �Ѵ�.

### 11-1. �⺻ ��ġ ����

- �¿� ������ �����Ѵ�.
- �߾� ���忡�� �������� �ʴ´�.
- marker�� `1 x 1 wall cell`�̴�.
- `2 x 2` ������ ��� wall bounds �ȿ� �־�� �Ѵ�.
- row 0�� ��ġ�� ��ġ�� �����Ѵ�.
- �̹� ä���� subcell���� ��ġ���� �ʴ´�.
- �ٸ� marker�� ��ġ�� �� �ȴ�.
- �� subcell grid�� ���ĵǾ�� �Ѵ�.

### 11-2. 1�� ���� ����

�׽�Ʈ�� �⺻��:

```text
�� ���� �� �¿� �� �ջ� �� 6�� ����
```

��õ �й�:

```text
left wall: 3��
right wall: 3��
```

�� ���� 1�� �׽�Ʈ���̸�, ���� Day/difficulty/����/���� bias�� �ݿ��� �����Ѵ�.

### 11-3. rarity roll

�� marker ���� �� chest rarity�� roll�Ѵ�.

```text
bronze 70%
silver 22%
gold 7%
platinum 1%
```

---

## 12. Partial reveal visual ��ȹ

### �ĺ� A. 1U chest texture�� 2 x 2 �������� ������

����:

- ���� ��Ʈ�� ���� �� �´´�.
- ���� �������ڰ� ���� �巯���� ������ ����.

����:

- 1������ texture atlas/region ������ ���ŷӴ�.
- ���� ��Ʈ�� ������ ������ �ӽ�ȭ�ȴ�.

### �ĺ� B. quadrant sprite 4�� ǥ��

����:

- ��Ʈ ��ü�� ����.
- �� subcell�� visual quadrant�� 1:1�� �����ϱ� ����.
- 1��/���� ��� �� �� �ִ� ������.

����:

- �ӽ� sprite�� �ʿ��ϴ�.

### �ĺ� C. �ӽ� ColorRect 4�� ǥ��

����:

- ���� ������ ���� �����ϴ�.
- ��Ʈ ���̵� partial reveal ������ �׽�Ʈ�� �� �ִ�.

����:

- ���� ���� ������ �����ϴ�.
- ���� sprite ��ü�� �ʿ��ϴ�.

### ���� ��õ

**Phase 2������ C �Ǵ� B�� ����**�Ѵ�.

����:

```text
������ Bó�� quadrant 4�� Node�� �����,
�ʱ� ǥ�ø� ColorRect �Ǵ� �ӽ� TextureRect�� ó���Ѵ�.
```

��, ���߿� ���� 1U �������� sprite�� 4 quadrant�� ��ü�� �� �ְ� �����.

---

## 13. Fully revealed ����

���� ����:

```text
is_fully_revealed = revealed_subcell_count == 4
```

�Ǵ�:

```text
for each local cell in 2 x 2:
  if not revealed:
    return false
return true
```

���� ��ȭ:

```text
hidden / partial
�� fully_revealed
�� popup_opened
�� consumed
```

��Ģ:

- fully revealed ������ interaction �ȳ� ����.
- fully revealed ������ E �Է� ����.
- consumed �Ŀ��� visual ���� �Ǵ� ��Ȱ�� ǥ��.
- consumed �� ���ȣ�ۿ� ����.

---

## 14. E ��ȣ�ۿ� ��ȹ

### 14-1. ���� �Է°� �浹

���� `E`�� Ű����ũ ��ȣ�ۿ뿡 ���ȴ�.

�������ڵ� `E`�� ����ϹǷ�, interaction �켱������ �ʿ��ϴ�.

���� �켱����:

```text
1. fully revealed treasure chest
2. Day kiosk
```

��, ���� interaction �������� Ű����ũ �켱�� �� �����ϸ� ���� ������ �켱�ϰ�, �������ڴ� ���� nearest-interactable ������� ���δ�.

### 14-2. Interaction range

����:

```text
TREASURE_INTERACTION_RANGE = 1.5U ~ 2U
```

1�������� Ű����ũ interaction range `2U`�� �����ص� �ȴ�.

### 14-3. �帧

```text
Player presses E
�� Main checks nearest fully revealed unconsumed treasure
�� if found: open TreasureRewardPopup
�� else: existing kiosk interaction flow
```

---

## 15. TreasureRewardPopup ��ȹ

�� UI �ĺ�:

```text
scenes/ui/TreasureRewardPopup.tscn
scenes/ui/TreasureRewardPopup.gd
```

### 15-1. �ּ� ǥ�� �׸�

- �������� rarity
- reward item �̸�
- reward item rank
- reward item category
- reward item short_desc �Ǵ� desc
- �ǸŰ�
- `ȹ��` ��ư
- `�Ǹ�` ��ư

### 15-2. ����

�˾� open:

- ���� pause
- reward item ǥ��
- ȹ��/�Ǹ� ���� ���

ȹ��:

- `GameState.grant_shop_item_reward(item_id, "treasure_chest")` ȣ��
- ���� �� marker consumed
- popup close
- pause ����

�Ǹ�:

- item ���� ����
- `sell_price`��ŭ gold ����
- marker consumed
- popup close
- pause ����

����:

- LevelUpUI, DayShopUI, PauseMenu�� pause ó���� �浹���� �ʾƾ� �Ѵ�.
- popup �� �ߺ� �Է� ����.

---

## 16. Reward roll ��ȹ

### 16-1. Reward roll ����

�� ���� ����� �ִ�.

A. marker ���� �� reward���� �̸� roll
B. popup open �� reward roll

��õ�� **B. popup open �� reward roll**�̴�.

����:

- ���� ShopItemCatalog ���¸� �ֽ����� �ݿ��ϱ� ����.
- marker���� reward seed�� �����ص� �ȴ�.
- ������ �ܼ��ϴ�.

�ٸ� deterministic �׽�Ʈ�� �ʿ��ϸ� marker ���� �� `reward_seed`�� �����Ѵ�.

### 16-2. Roll ����

```text
1. marker.chest_rarity Ȯ��
2. rarity�� reward rank Ȯ���� rank roll
3. ShopItemCatalog���� �ش� rank �ĺ� ����
4. �ĺ� �� item roll
5. popup ǥ��
```

---

## 17. Phase�� ���� ��ȹ

## Phase 1. Marker ������ ������ ����

��ǥ:

- �������� marker�� �����ϰ� ������ �� �ְ� �Ѵ�.
- ���� wall mining, partial visual, popup�� �������� �ʴ´�.

����/�߰� ���� ����:

- `scenes/world/WallTreasureManager.gd` �Ǵ� ������ manager ����
- `scenes/main/Main.gd` ���� �ּ�ȭ
- �ʿ� �� `GameConstants.gd`�� treasure ���� ��� �߰�
- `scripts/tests/treasure_chest_snapshot.gd`

���� ����:

- rarity table ����
- marker ���� ����
- marker ���� �Լ�
- bounds �˻�
- overlap �˻�
- �¿� �� �� 6�� ����
- snapshot���� marker ��� ���

����:

- marker�� 2 x 2����
- wall bounds �ۿ� �������� �ʴ���
- row 0�� ��ġ�� �ʴ���
- marker���� ��ġ�� �ʴ���
- rarity roll table ������ 100����

���� ����:

- ���� ä�� ���� ����
- UI �߰�
- reward ���� ����
- ���� shop ���� ���� ����

---

## Phase 2. Mining ������ partial reveal

��ǥ:

- 1U wall cell ä�� �Ϸ� �� marker reveal ���¸� �����Ѵ�.
- ä���� quadrant�� ǥ���Ѵ�.
- 4ĭ ��� ä���Ǹ� fully revealed ó���Ѵ�.

����/�߰� ���� ����:

- `WallTreasureManager.gd`
- `WorldGrid.gd` �Ǵ� ���� �� ä�� �Ϸ� ó�� ����
- `Main.gd` �����
- �ӽ� visual Node �Ǵ� overlay ���� ����
- `treasure_chest_snapshot.gd` Ȯ��

���� ����:

- mined subcell �̺�Ʈ �Ǵ� callback ����
- marker ���� ���� ���� Ȯ��
- revealed_cells ����
- partial visual ǥ��
- fully revealed ����

����:

- 1ĭ ä�� �� 1/4 ǥ��
- 2ĭ ä�� �� 2/4 ǥ��
- 4ĭ ä�� �� fully revealed
- fully revealed �� interaction �Ұ� ���� ����

���� ����:

- reward popup ����
- ������ ���� ����
- StageTable/BlockCatalog ����

---

## Phase 3. E ��ȣ�ۿ�� TreasureRewardPopup �ּ� UI

��ǥ:

- fully revealed marker ��ó���� E ��ȣ�ۿ����� popup�� ����.
- popup�� ���� reward ���� ������ ���ų� mock reward�� �����ص� �ȴ�.

����/�߰� ���� ����:

- `scenes/ui/TreasureRewardPopup.tscn`
- `scenes/ui/TreasureRewardPopup.gd`
- `Main.gd`
- `WallTreasureManager.gd`

���� ����:

- nearest fully revealed treasure ��ȸ
- E interaction ����
- popup open/close
- pause ó��
- consumed ó�� �غ�

����:

- fully revealed �� E ����
- fully revealed �� E popup open
- Ű����ũ�� E �浹 ����
- popup close �� pause ����

���� ����:

- reward ����/�Ǹ� ���� ó������ �����ϰ� ���� ����
- ���� DayShopUI ���� ���� ����

---

## Phase 4. Reward roll, ȹ��/�Ǹ�, grant helper

��ǥ:

- ���� ShopItemCatalog �������� reward�� roll�Ѵ�.
- ȹ��/�Ǹ� ������ �����Ѵ�.
- ��� ���� ���� item grant helper�� �߰��Ѵ�.

����/�߰� ���� ����:

- `GameState.gd`
- `ShopItemCatalog.gd` �ʿ� �� helper �߰�
- `TreasureRewardPopup.gd`
- `WallTreasureManager.gd`
- `treasure_chest_snapshot.gd` Ȯ��

���� ����:

- reward rank roll
- item candidate ��ȸ
- sell price ���
- `grant_shop_item_reward()` ����
- ȹ�� ��ư ó��
- �Ǹ� ��ư ó��
- consumed ó��

����:

- sell price = effective price x 0.6 floor
- ȹ�� �� ��� ���� ����
- �Ǹ� �� item ���� ����, gold ����
- attack_module/function_module/enhance_module ó�� ����
- ���� purchase_shop_item ȸ�� ���

���� ����:

- ���� ���� ���� ���/lock/reroll ���� ����
- ���ݸ�� ��ġ ����

---

## Phase 5. ���� ���Ű� ȸ�� �׽�Ʈ

��ǥ:

- ���� ����� canonical ������ �ݿ��Ѵ�.
- snapshot�� ȸ�� �׽�Ʈ�� �����Ѵ�.

���� ���:

- `docs/02_systems_spec.md`
- `docs/03_data_and_state_spec.md`
- `docs/04_roadmap.md`

�ݿ� ����:

- Normal chest �� Bronze chest
- 1U / 1 x 1 wall cell ����
- partial reveal ��Ģ
- fully revealed �� E ��ȣ�ۿ�
- reward popup
- ȹ��/�Ǹ� ����
- �ǸŰ� 60%
- ũ���� �̱���/TODO ����

����:

- `scripts/tests/balance_snapshot.gd`
- `scripts/tests/attack_module_dps_snapshot.gd`
- `scripts/tests/day_pressure_snapshot.gd`
- `scripts/tests/treasure_chest_snapshot.gd`
- Godot headless load
- `git diff --check`

---

## 18. �׽�Ʈ ��ȹ ��

### Marker �׽�Ʈ

- marker count�� �������� ��ġ�ϴ���
- marker size�� �׻� 2 x 2����
- marker origin�� wall bounds ������
- marker 2 x 2 ��ü�� wall bounds ������
- row 0�� ��ġ�� �ʴ���
- marker���� ��ġ�� �ʴ���

### Reveal �׽�Ʈ

- Ư�� marker�� 1�� subcell reveal �� partial count 1
- 2�� reveal �� partial count 2
- 3�� reveal �� partial count 3
- 4�� reveal �� fully revealed true
- �̹� revealed�� cell�� �ٽ� reveal�ص� count �ߺ� ���� ����

### Interaction �׽�Ʈ

- hidden/partial ���¿����� interaction �Ұ�
- fully revealed ���¿����� interaction ����
- consumed ���¿����� interaction �Ұ�
- Ű����ũ interaction�� �浹���� ����

### Reward �׽�Ʈ

- chest rarity table ���� ����
- reward rank table ���� ����
- reward rank S�� 0%�� chest���� S�� ������ ����
- Gold/Platinum������ S �ĺ��� Ȯ�������� ����
- �ĺ� item�� ���� ShopItemCatalog���� ��ȸ��
- sell price�� ��ȿ ���Ű��� 60%
- grant helper�� ��� ���� ���� ����

### Regression �׽�Ʈ

- ���� ���� ���� ����
- ���ݸ�� ����/�ռ� ����
- function/enhance module ���� ����
- v1 ��� ���� ���� ����
- v2 �ùķ��̼� ���� ����
- day pressure snapshot ���� ���� �Ǵ� ���� ���� ��Ȯ

---

## 19. �ֿ� ����ũ

| ����ũ | ���� | ���� |
|---|---|---|
| �� ��ǥ�� ȥ�� | wall column, subcell, world position ��ȯ�� �򰥸� �� ���� | Phase 1���� ��ǥ ��ȯ helper�� snapshot ���� �ۼ� |
| Main.gd ���ȭ | ��� ����� Main�� ������ �������� ����� | WallTreasureManager �и� |
| WorldGrid å�� ���� | reward/popup���� WorldGrid�� �˸� ������ ����� | WorldGrid�� ä�� ����� ���� |
| Partial visual �浹 | wall tile draw�� treasure overlay�� ��ĥ �� ���� | overlay layer�� ���� ���� |
| E interaction �浹 | Ű����ũ�� treasure�� ���� E�� ��� | �켱������ range ��Ȯȭ |
| Pause �浹 | LevelUpUI/DayShopUI/PauseMenu�� pause �浹 ���� | popup ���� flag�� close path ��Ȯȭ |
| Attack module ���� ���� | reward�� attack_module�ε� ������ ���� �� �� ���� | �ռ� ���� �켱, �Ұ� �� �Ǹ� ����/�ڵ� �Ǹ� ��å |
| Shop ���� ȸ�� | grant helper�� purchase_shop_item�� �ǵ帮�� ���� ���Ű� ���� �� ���� | ���� apply helper �и� �� purchase regression �׽�Ʈ |

---

## 20. ù ���� Phase ����

�ٷ� �����ص� �Ǵ� ������ **Phase 1**�̴�.

Phase 1 ���� ���� ���:

```text
Treasure Chest 1�� ���� ��ȹ���� Phase 1�� ��������.
��ǥ�� marker ������ ������ marker ����/snapshot������.
ä�� ����, partial visual, interaction, reward popup, item ������ ���� �������� ����.
```

Phase 1�� ���������� ���� �� Phase 2�� �Ѿ��.

---

## 21. Codex Phase 1 ���� �ʾ�

```text
Burial Protocol ������Ʈ���� docs/reports/treasure_chest_implementation_plan.md�� Phase 1�� ��������.

��ǥ:
- �������� marker ������ ���� �߰�
- wall reset/�� ���� �� marker ���� �Լ� �߰�
- 1 x 1 wall cell bounds/overlap ����
- bronze/silver/gold/platinum rarity roll table �߰�
- marker snapshot �׽�Ʈ �߰�

����:
- ä�� ���� ����
- partial visual ����
- E interaction ����
- TreasureRewardPopup ����
- reward roll/item grant ����
- ���� shop ���� ���� ���� ����
- v1 ��� ���� ���� ����
- v2 �ùķ��̼� ���� ����
- StageTable/BlockCatalog/ShopItemCatalog ��ġ ���� ����

�Ϸ� �� ����:
1. �߰�/���� ����
2. marker ���� ��ġ
3. marker ����
4. marker ���� ������ rarity Ȯ��
5. bounds/overlap ���� ���
6. snapshot �׽�Ʈ ���
7. ���� balance/attack/day snapshot ���
8. Godot headless ���
9. git diff --check ���
```

---

## 22. ���� ���

�������� 1�� ������ �� ���� �������� �ʴ´�.

���� ���� ����:

```text
Phase 1: marker ����/snapshot
Phase 2: mining reveal + partial visual
Phase 3: E interaction + popup
Phase 4: reward roll + grant/sell
Phase 5: ���� ���� + ȸ�� �׽�Ʈ
```

���� ���� ������ ���� �۾��� **Phase 1�� ����**�ϴ� ���̴�.
---

## 22. ���� �Ϸ� ���

������: `2026-05-17`

Phase 1~5�� ���� ���� �� ���� �ݿ����� �Ϸ�Ǿ���.

�Ϸ�� ����:

- Phase 1: treasure marker ������ ����, 1 x 1 wall cell marker ����, bounds/overlap/rarity snapshot
- Phase 2: wall mining ����, ä�� �� preview visual, ä���� quadrant partial reveal, fully revealed ����
- Phase 3: fully revealed marker `E` ��ȣ�ۿ�, prompt, `TreasureRewardPopup`, pause/close ó��
- Phase 4: reward rank roll, ShopItemCatalog reward �ĺ� roll, ȹ��/�Ǹ�, grant helper, consumed ó��
- Phase 5: canonical ���� ����, treasure snapshot Ȯ��, headless ����

���� ���� ����:

- `scripts/data/TreasureChestMarkerData.gd`
- `scripts/data/WallTreasureManager.gd`
- `scenes/ui/TreasureRewardPopup.gd`
- `scenes/ui/TreasureRewardPopup.tscn`
- `scenes/main/Main.gd`
- `scenes/world/WorldGrid.gd`
- `scripts/data/ShopItemCatalog.gd`
- `scripts/autoload/GameState.gd`
- `scripts/tests/treasure_chest_snapshot.gd`

���� ����:

- marker ���� ��, bounds, row 0 ����, overlap ����
- preview visual�� rarity palette
- partial reveal�� fully revealed
- interaction prompt ����
- reward rank table ����
- reward candidate roll�� fallback
- sell price 60%
- grant helper gold ���� ����
- consumed �� prompt/interaction/visual ����
- popup signal�� paused process mode

���� �ļ� �۾��� ���� Phase�� �ƴ϶� ���� ��ȹ���� �и��Ѵ�.

- creep ����
- sprite ��� treasure art polish
- marker ���� ���� reward Ȯ�� �뷱�� Ȯ��
- popup icon/slot full UX ����
- ���� shop regression ���� �׸� ����

## Current Source Snapshot - 2026-05-25

This section is the current canonical attack-module implementation note.

### Current Module List

| Module ID | Display Name | Type | Style | Effect |
|---|---|---|---|---|
| `sword_module` | Sword Module | `melee` | `slash` | `slash_arc` |
| `dagger_module` | Dagger Module | `melee` | `stab` | `short_stab` |
| `lance_module` | Lance Module | `melee` | `pierce` | `long_pierce` |
| `axe_module` | Axe Module | `melee` | `smash` | `blunt_smash` |
| `greatsword_module` | Greatsword Module | `melee` | `cleave` | `big_cleave` |
| `pistol_module` | Pistol Module | `ranged` | `revolver` | `revolver_projectile` |
| `shotgun_module` | Shotgun Module | `ranged` | `shotgun` | `shotgun_spread` |
| `sniper_module` | Sniper Module | `ranged` | `sniper` | `sniper_projectile` |
| `laser_module` | Laser Module | `ranged` | `laser` | `laser_beam` |
| `drone_attack_module` | Drone Attack Module | `mechanic` | `drone` | empty |

Deprecated IDs are not current data: `bow_module`, `scatter_module`, `pierce_module`.

### Gameplay Contract

- Attack hit detection, projectile behavior, cooldowns, damage, grade multipliers, synthesis, and equipment capacity are data/system driven.
- World visual sprite sizes do not affect attack hit shapes or projectile collision.
- `pistol_module` uses revolver-style ranged projectile defaults.
- `shotgun_module` keeps multi-projectile spread behavior.
- `sniper_module` keeps `pierce_count = 2`.
- `laser_module` remains hitscan.
- `drone_attack_module` remains mechanic/auto-targeting.

### World Visual Contract

Attack-module world visuals are composed in `scenes/player/modules/AttackModuleVisual.gd`.

```text
AttackModuleVisual
  SlotSprite
  WeaponSprite
```

Slot ring texture is chosen by equipped grade:

| Grade | Slot Texture |
|---|---|
| `D` | `res://assets/attack_modules/module_d.png` |
| `C` | `res://assets/attack_modules/module_c.png` |
| `B` | `res://assets/attack_modules/module_b.png` |
| `A` | `res://assets/attack_modules/module_a.png` |
| `S` | `res://assets/attack_modules/module_s.png` |

Weapon texture resolution:

1. Use `ShopItemDefinition.icon_path` if it exists and can be loaded.
2. Fall back to `res://assets/attack_modules/<module_id without _module>.png`.
3. Fall back to `res://assets/attack_modules/<module_id>.png`.
4. If no image exists, keep the old code-drawn placeholder visual.

Current visual sizing:

- All slot rings target `64 x 64`.
- Default weapon target is `56 x 56`.
- `greatsword` and `lance` target `64 x 64`.
- `dagger`, `pistol`, and `revolver` target `48 x 48`.
- Visual alpha is `70%`.
- Orbit radius around the player is `64px`.

Slot size must stay consistent across modules. Weapon size may vary by weapon silhouette.
