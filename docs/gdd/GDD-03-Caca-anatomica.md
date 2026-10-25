---
type: resource
status: draft
created: 2026-10-21
updated: 2026-10-22
tags:
  - gdd
  - caca
  - crafting
  - godot
owner: labu
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# GDD-03 — Caça anatômica (Pilar 3)

> Equipamento de alto nível não cai pronto: é forjado com partes de criaturas. Quebrar o chifre do monstro X rende o capacete Y.
> Volta para o [[03-Projects/Cepa-Selvagem/notas/GDD-00-Visao-e-pilares|índice do GDD]]. Dano chega pelo pipeline do [[03-Projects/Cepa-Selvagem/notas/GDD-01-Combate-e-magia|GDD-01]].

## 1. Anatomia na cena

```
Creature (CharacterBody3D)
└── AnatomyComponent
    ├── BodyPart "Chifre"    (BoneAttachment3D + Area3D)
    ├── BodyPart "Cauda"     severable
    ├── BodyPart "Carapaça"
    └── BodyPart "Ventre"    ponto fraco
```

## 2. Dados de uma parte

```gdscript
class_name BodyPartData extends Resource
@export var id: StringName                     # &"horn"
@export var max_part_hp := 300.0
@export var damage_mult := { &"slash": 0.6, &"blunt": 1.4 }
@export var break_states: Array[BreakState]    # intacto → rachado → quebrado → decepado
@export var severable := false                 # cai no chão como objeto coletável
@export var on_break_effects: Array[Resource]  # perde ataque X, enfurece, sangra…
@export var loot: PartLootTable

class_name BodyPart extends Area3D
signal state_changed(part: BodyPart, new_state: int)
@export var data: BodyPartData
var part_hp: float
var state := 0
```

- HP da parte é **separado** da vida global; recebe `dano × part_break_power`.
- Ao mudar de estado: efeitos (`on_break_effects`), troca visual (mesh/material), aviso para o `BrainComponent`.

## 3. Quebrar muda a luta
Exemplos de `on_break_effects`:
- Chifre quebrado → perde o ataque de investida; passa a usar mordida.
- Cauda decepada → perde varredura traseira; o pedaço vira coletável no chão.
- Carapaça rachada → `resist_slash` cai; ventre exposto em mais ângulos.

A quebra dá recompensa **na luta** (monstro mais fraco) e **depois** (material). Duplo incentivo para mirar.

## 4. Loot condicional: como você caçou importa

```
PartLootTable "Chifre do Rinolito"
├── state ≥ QUEBRADO            → Fragmento de Chifre (garantido)
├── state == INTACTO na morte   → Chifre Íntegro (raro; só com captura/sedação)
├── morto com dano de fogo      → qualidade −1 (material "Chamuscado")
└── qualidade = f(harvest_precision, maestria de esfola, estado da parte)
```

Caçador habilidoso produz material melhor → vale mais no mercado ([[03-Projects/Cepa-Selvagem/notas/GDD-05-Economia|GDD-05]]). Caçar vira profissão.

## 5. Ponte para o crafting (detalhe no B02)
`MaterialData` carrega **qualidade + traits**, não só tipo:
```
Chifre de Rinolito { qualidade: 4, traits: [Denso +8% poise_resist, Condutor de Terra] }
```
Os traits vêm do `GenomeComponent` da criatura ([[03-Projects/Cepa-Selvagem/notas/GDD-04-Ecologia-e-genetica|GDD-04]]). Rinolito com mutação de densidade → chifre melhor → capacete melhor. Breeding passa a ter consequência econômica.

## 6. Generalização: tudo que se coleta tem anatomia
Veio de minério, árvore e planta grande podem ser entidades com `AnatomyComponent`. Picareta com `part_break_power` alto quebra o veio "do jeito certo" e rende minério melhor. **Caça, mineração e lenhador viram um sistema só.**

| Conceito | Implementado como | Usado por |
|---|---|---|
| Parte de monstro, veio, árvore | `BodyPart` + `PartLootTable` | caça, mineração, botânica |
| Golpe, magia, ferramenta | `AbilityData` | combate e coleta |

## 7. Notas de Godot e performance
- Partes só em criaturas próximas (LOD de colisão); longe = 1 hurtbox.
- Formas primitivas (cápsula/esfera/caixa) presas a ossos.
- Estado das partes replicado só quando muda (é discreto, barato).

## 8. Decisões do B01 (2026-10-21, aceitas pelo Tarciso)

### Captura e sedação
- Existe, como alternativa a matar.
- **Como:** criatura com **< 20% da Vida** → **armadilha** → **sedativo** (feito de plantas: liga à botânica do [[03-Projects/Cepa-Selvagem/notas/GDD-04-Ecologia-e-genetica|GDD-04]]).
- **Depois da captura, escolha:**
  - **Levar ao criadouro** (breeding; só algumas espécies e portes).
  - **Abater com cuidado:** toda parte ainda não quebrada sai **Íntegra** (+1 qualidade).
- **Captura é o único jeito de ter partes Íntegras.**

### Coleta pós-morte
- **Esfolar é manual**, uma parte por vez, segurando o botão: **~3 s por parte**.
- Maestria de esfola reduz o tempo; `harvest_precision` aumenta a qualidade.
- **Levar dano interrompe** a coleta (tensão real na Zona Selvagem).
- O jogador escolhe a ordem (pegar só o chifre e fugir é válido).
- **Corpo fica no chão 5 min.**

### Reserva de loot (regra única, igual ao saque PvP)
- Criatura reservada ao **grupo que mais causou dano**.
- A reserva dura **enquanto o grupo estiver em combate com ela + 1 min**; depois fica livre para qualquer um.
- Dentro do grupo: padrão **"quem esfola leva"**; o líder pode trocar para **rodízio**.
- **Fragmento de parte quebrada cai na hora** (no meio da luta) e entra na mesma reserva.
- **Partes decepadas** seguem a mesma reserva (de quem cortou, durante a luta + 1 min). Na Zona Selvagem não há proteção extra: morreu para jogador, a cauda vai no full loot ([[03-Projects/Cepa-Selvagem/notas/GDD-05-Economia|GDD-05]]).

### Orçamento de partes por porte

| Porte | Partes | Exemplo |
|---|---|---|
| Pequeno | 1 (corpo só, sem quebra) | coelho, peixe |
| Médio | 3–4 | lobo, javali |
| Grande | 5–6 | Rinolito |
| Colossal (eventos) | até 8 | chefes de mundo |

### Regeneração e criaturas veteranas
- **Nada regenera durante a luta.**
- Criaturas grandes **fogem** com pouca Vida ou muitas partes quebradas (vão ao ninho, estilo MH).
- Criatura que sobrevive regenera em **~1 dia de jogo**; parte decepada em **~3 dias**.
- A parte volta **Cicatrizada**: mais HP de parte e material com trait **"Cicatrizado"** (+resistência).
- Surgem **criaturas veteranas** (mais duras, mais valiosas, cicatrizes visíveis). A ecologia tem memória.

### Novos estados e qualidades de material
- Estados de parte: intacto → rachado → quebrado → decepado; após regenerar: **cicatrizado**.
- Qualidades especiais: **Íntegro** (só por captura, +1), **Chamuscado** (morte por fogo, −1), **preservado por gelo** (pode dar +1), **Cicatrizado** (veterano). Regras de combinação no [[03-Projects/Cepa-Selvagem/blocos/B02-gdd-materiais-e-forja|B02]].

## 9. Captura no jogo (aceita pelo Tarciso em 2026-10-22)

Detalha o §8 para os bichos procedurais do [[03-Projects/Cepa-Selvagem/notas/GDD-09-Criaturas-plantas-procedurais-e-montarias|GDD-09]]. Proposta do Claude, aceita; implementada no [[03-Projects/Cepa-Selvagem/blocos/B14-captura-e-montaria-propria|B14]] quando aceita.

### 9.1 Os bichos do vale viram caça
| Espécie | Vida | Partes (GDD-03 §1) | Material ao esfolar |
|---|---|---|---|
| Trotador | 120 | chifre (se tiver gene C), couro | Chifre-Galhado, Couro de Trotador, Carne Crua |
| Planador | 90 | asa, couro | Pena de Penacho, Carne Crua |
| Saltarelo | 25 | — | Pele de Saltarelo, Carne Crua |

Raia e Lambari ficam para a pesca (rede/armadilha de rio, GDD-04 §4).

### 9.2 Capturar em 3 passos
1. **Cansar:** abaixo de **20% da Vida** o bicho fica **Exausto** — anda devagar, para de fugir, ícone acima dele. Em 30 s sem levar dano ele se recupera e foge.
2. **Prender:** usar um **Laço de Fibra** (4 fibra + 2 galho) a até 6 m. Prende por 20 s. Laço em bicho que não está exausto se rompe e é perdido.
3. **Sedar:** com o bicho preso, usar o **Sedativo de Erva** (3 erva + 1 mel): **3 s parado ao lado**, dano cancela (mesma regra de montar). Pronto: capturado.

- Laço e sedativo saem pela roda rápida ([F]/[G]); são feitos no menu de ofícios ([Tab]) e a Alquimista também vende o sedativo.
- **Online:** quem prendeu tem **60 s de prioridade** sobre o bicho (igual à reserva de loot do §8).

### 9.3 Depois de capturar, escolha
- **Abate cuidadoso:** todas as partes inteiras saem **Íntegras** (+1★, trait `integro`, ADR-0005).
- **Levar ao estábulo:** Trotador e Planador viram **sua montaria**, com o DNA dele. O gene **porte** muda a montaria: TT 100% da velocidade, Tt 92%, tt 85% (e TT carrega mais quando houver Carga). Mutante `*` mantém a cor iridescente — o troféu do caçador.
- Saltarelo vai para o **cercado do rancho** (GDD-04 §2) quando houver criadouro; no slice, só abate.

### 9.4 Respostas do Tarciso (2026-10-22)
1. Os bichos **só fogem**; não ficam agressivos.
2. A montaria capturada **convive** com as de teste do estábulo.
3. **Até 3 montarias próprias** por personagem.
