---
type: resource
status: draft
created: 2026-10-21
updated: 2026-10-21
tags:
  - gdd
  - combate
  - magia
  - godot
owner: labu
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# GDD-01 — Combate e magia (Pilar 1)

> Ação pura: sem auto-ataque, sem target travado. A mobilidade durante o cast depende do tipo de magia e do peso do equipamento.
> Volta para o [[03-Projects/Cepa-Selvagem/notas/GDD-00-Visao-e-pilares|índice do GDD]].

## 1. Camadas

```
DADOS (Resources .tres)   AbilityData · ItemData · ModifierData · MobilityProfile · DamagePacket
COMPONENTES (Nodes)       Stats · Pools · Equipment · Mastery · Caster · Aim · Locomotion · StatusEffects · Hurtbox
SERVIÇOS (Autoload/serv.) CombatResolver · MasteryService · LootService · EventBus
```

Designer mexe só em `.tres`. Componentes têm estado e regras. Serviços cruzam entidades.

## 2. Árvore da entidade (jogador e criatura usam a mesma base)

```
Player (CharacterBody3D)
├── StatsComponent          # valores finais a partir da pilha de modificadores
├── PoolsComponent          # Vida, Éter, Vigor, Postura
├── EquipmentComponent      # slots → injeta modificadores + calcula Carga
├── MasteryComponent        # XP por tag de uso → ver GDD-02
├── LocomotionComponent     # consulta o Caster para saber quanto pode se mover
├── CasterComponent         # executa habilidades em fases
├── AimComponent            # direção/ponto de mira (sem lock)
├── StatusEffectComponent   # buffs/debuffs = modificadores com duração
├── HurtboxComponent        # jogador: 1–3 zonas
└── Skeleton3D / AnimationTree

Creature (CharacterBody3D)
├── Stats / Pools / StatusEffects
├── AnatomyComponent        # partes → ver GDD-03
├── GenomeComponent         # → ver GDD-04
├── BrainComponent          # IA reage a quebra de partes
└── CasterComponent         # mesmo sistema de habilidades do jogador
```

## 3. Stats = pilha de modificadores
Ver [[08-Knowledge/decisions/ADR-0003-cepa-dano-como-evento|ADR-0003]].

```gdscript
class_name ModifierData extends Resource
enum Op { FLAT, PCT_ADD, PCT_MULT }
@export var stat: StringName
@export var op: Op
@export var value: float
var source: Object   # item/buff/nó de maestria que aplicou — para remover depois
```

Cálculo: `final = (base + Σflat) × (1 + Σpct_add) × Π(1 + pct_mult)`, recalculado só quando a pilha daquele stat muda (cache + sinal `stat_changed`).

### Lista inicial de stats (enxuta)

| Grupo | Stats |
|---|---|
| Pools | `max_health`, `max_ether`, `max_vigor`, `max_poise` + regenerações |
| Mobilidade | `move_speed`, `dodge_cost`, `cast_mobility`, `load_capacity` |
| Ofensiva | `power_<tipo>`, `poise_damage`, `part_break_power` |
| Defensiva | `resist_<tipo>`, `poise_resist` |
| Coleta | `harvest_precision`, `gather_yield` |

Tipos de dano: os 7 decididos na seção 8 (cortante, impacto, perfurante, fogo, gelo, tempestade, natureza). Éter é recurso, não tipo de dano.

## 4. Habilidades em fases + perfil de mobilidade
Toda habilidade (golpe, magia, mordida de monstro) é uma sequência de fases.

```gdscript
class_name MobilityProfile extends Resource
@export_range(0, 1) var move_mult := 1.0       # 0 = enraizado
@export var can_rotate := true
@export var can_dodge_cancel := false
@export var can_jump := false
@export_range(0, 1) var load_sensitivity := 1.0

class_name AbilityPhase extends Resource
enum Kind { WINDUP, CHANNEL, RELEASE, RECOVERY }
@export var kind: Kind
@export var duration := 0.3
@export var mobility: MobilityProfile
@export var interruptible_by_poise := true
@export var animation: StringName

class_name AbilityData extends Resource
@export var id: StringName
@export var phases: Array[AbilityPhase]
@export var delivery: DeliveryData           # projétil, cone, área no reticle, arco melee
@export var costs := { &"ether": 20.0 }
@export var mastery_tags: Array[StringName]  # [&"staff", &"fire"]
@export var damage: Array[DamagePacket]
```

### Fórmula de mobilidade (Locomotion consulta todo frame)
```
load_ratio   = carga_equipada / load_capacity
peso_penalty = lerp(1.0, 0.3, clamp(load_ratio, 0, 1)) ^ fase.load_sensitivity
move_final   = move_speed × fase.move_mult × peso_penalty × (1 + cast_mobility)
```

### Arquétipos (saem só de dados)

| Tipo | WINDUP | CHANNEL | RECOVERY | Sensação |
|---|---|---|---|---|
| Instantânea (dardo de éter) | 0.9 | — | 0.8 | kite livre |
| Conjuração móvel (bola de fogo) | 0.5 | — | 0.6 | anda devagar mirando |
| Ritual (meteoro) | 0.0 | 0.0, sem cancel | 0.2 | compromisso total |
| Canalização (raio contínuo) | 0.3 | 0.25, giro lento | 0.7 | torreta |

Mesmo cajado: túnica leve (`load_ratio 0.2`) quase não perde mobilidade; placa (`0.9`) vira torreta. **A classe sai do equipamento.**

## 5. Mira sem target travado
`AimComponent` entrega `AimContext { origin, direction, hit_point }` a partir do raycast da câmera. A habilidade não sabe quem é o alvo, só para onde foi lançada. Assistência de mira só para controle, como opção, nunca lock.

## 6. Pipeline de dano
Ver [[08-Knowledge/decisions/ADR-0003-cepa-dano-como-evento|ADR-0003]].

```gdscript
class_name HitEvent extends RefCounted
var attacker: Node
var ability: AbilityData
var packets: Array[DamagePacket]
var poise_damage: float
var break_power: float
var impact_point: Vector3
var part: BodyPart          # null se o alvo não tem anatomia
var tags: Array[StringName]
```

Ordem no servidor (`CombatResolver`):
1. Hitbox toca Hurtbox → identifica `BodyPart`.
2. Multiplicador da parte (ex.: ventre ×1.5; carapaça ×0.4 contra cortante).
3. Resistências + armadura.
4. Aplica: Vida global ← dano final · HP da parte ← dano × `break_power` · Postura ← `poise_damage`.
5. Sinais: `damage_dealt` → maestria da arma · `damage_mitigated` → maestria da armadura · `part_broken` → anatomia, IA, loot · `poise_broken` → interrompe a fase atual.

**XP de armadura vem do dano mitigado**, não de "apanhar" (evita farm AFK). Detalhes em [[03-Projects/Cepa-Selvagem/notas/GDD-02-Progressao-por-uso|GDD-02]].

## 7. Notas de Godot e rede
- Hurtboxes: formas primitivas em `BoneAttachment3D`, nunca trimesh. LOD de colisão: longe da câmera, hurtbox única.
- Lag compensation: servidor guarda ~200 ms de histórico das partes e rebobina para validar o acerto.
- `AnimationTree` acompanha; quem avança as fases é o timer do servidor.
- Tudo que é número em `.tres`.

## 8. Decisões do B01 (2026-10-21, aceitas pelo Tarciso)

### Câmera
- **Fora de combate:** órbita livre + 1ª pessoa (contemplação, Modo Foto) — como o protótipo.
- **Em combate** (arma sacada ou conjurando): 3ª pessoa *over-the-shoulder*, retículo fixo no centro. **1ª pessoa bloqueada em combate.**
- Motivo: mira sem lock precisa de retículo estável; mirar em partes exige ver o corpo do monstro; 1ª pessoa distorce o PvP e dobra o custo de animação.
- Descartado: isométrica estilo Albion (mata Modo Foto e sensação de ação).

### Controle
- Teclado e mouse como alvo principal; **gamepad suportado desde o vertical slice**.
- Todo input via actions do `InputMap`, nunca tecla fixa no código.
- Assistência de mira só no gamepad, só como **fricção** (retículo desacelera perto da hurtbox). Sem magnetismo. Mais fraca no PvP.

### Recursos

| Barra | Gasta com | Regenera |
|---|---|---|
| Vida | dano recebido | devagar, ou consumíveis |
| Éter | magias e habilidades de arma mágica | média; mais rápida fora de combate |
| Vigor | esquiva, corrida, bloqueio, golpes pesados | rápida; pausa ao gastar |
| Postura (não se gasta) | quebrada por `poise_damage`; zerada = interrompido/atordoado | rápida se não apanhar |

- **Regra:** Éter paga *o que você lança*; Vigor paga *como você se move e se defende*. Magia gasta só Éter.
- Peso da armadura aumenta o custo de Vigor da esquiva (via `dodge_cost`).
- Gancho Pilar 4: barra de Postura e partes de um monstro só aparecem para quem **catalogou** a espécie.

### Esquiva (depende da carga)

| Carga | Esquiva | I-frames | Compensação |
|---|---|---|---|
| Leve (< 40%) | rolamento longo | ~0,20 s | pouca Postura |
| Média (40–70%) | passo lateral | ~0,12 s | equilíbrio |
| Pesada (> 70%) | passo curto | nenhum | super armor: Postura muito alta durante o passo |

- Tanque não esquiva, aguenta. I-frames validados no servidor com o mesmo rewind do lag compensation (B06).

### Barra de habilidades (o equipamento define a barra)

| Origem | Slots | Escolha |
|---|---|---|
| Arma — clique esq./dir. | 2 básicos | fixos da arma; mirados, sem auto-ataque |
| Arma | 3 | cada slot com 2–4 opções, desbloqueadas pela maestria da arma |
| Peito | 1 | defensiva/utilitária |
| Cabeça | 1 | utilitária |
| Botas | 1 | mobilidade |
| Consumíveis | 2 | poções, comida, bombas |

- ~6 ativas + 2 básicos. Item forjado com parte de criatura pode **dar a habilidade** (capacete do chifre do Rinolito → investida). Ponte direta com o [[03-Projects/Cepa-Selvagem/notas/GDD-03-Caca-anatomica|GDD-03]].

### Fogo amigo
- **Sem dano direto em aliados**, em nenhum modo. Projéteis atravessam aliados.
- **Efeitos de terreno afetam todos** (grama incendiada, chão congelado, raízes, empurrões) — "o mundo não escolhe lados".

### PvP: quando e onde
- **Duelo consensual** (convite aceito) — o modo de PvP base.
- **PvP aberto** só em **mapas/zonas específicos** e em **momentos liberados** (janelas de tempo/eventos, ex.: disputa territorial).
- Regras de zona, perda de item e full loot ficam no [[03-Projects/Cepa-Selvagem/notas/GDD-05-Economia|GDD-05]].
- O combate precisa de um estado **Caído** (morte para monstro na Zona Selvagem) e de **crédito de abate** por jogador; regras no GDD-05.

### Tipos de dano (cada um tem papel no combate e consequência no material)

| Tipo | No combate | Na caça/material |
|---|---|---|
| Cortante | sangramento | **único que decepa** partes `severable` |
| Impacto | muito dano de Postura | **melhor para quebrar** chifre e carapaça |
| Perfurante | ignora parte da armadura | bônus em ponto fraco; pouco dano ao material |
| Fogo | dano contínuo, incendeia terreno | **queima o material** (qualidade −1, "Chamuscado") |
| Gelo | lentidão, chão escorregadio | **preserva o material** (pode dar qualidade +1) |
| Tempestade | salta entre alvos, forte na água | trait "Carregado" no material |
| Natureza | veneno, raízes que prendem | envenenado: alguns materiais perdem valor, outros viram reagente |

- O elemento usado para matar é uma decisão econômica: fogo mata rápido, mas estraga o couro.
