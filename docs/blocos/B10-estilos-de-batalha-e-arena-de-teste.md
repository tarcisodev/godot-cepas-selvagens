---
type: block
status: pending
created: 2026-10-21
updated: 2026-10-22
tags:
  - bloco
  - godot
  - combate
  - teste
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B10 — Estilos de batalha, armeiro de treino e monstros de teste

## Objetivo
Testar o combate do [[03-Projects/Cepa-Selvagem/notas/GDD-01-Combate-e-magia|GDD-01]] com mais de uma arma: o jogador troca de estilo num NPC do acampamento e enfrenta monstros que revidam.

## Decisões fechadas com o Tarciso (2026-10-21)
- **Personagem:** melhora pelo equipamento visível — arma e escudo do estilo na mão, peças de armadura presas aos ossos (ombreiras, cinto) que mudam com o estilo. A malha do B09 não muda.
- **Estilos (3):** Espada e escudo · Arma pesada · Cajado arcano. Cada um define os 2 básicos (clique esq./dir.), como no GDD-01 §8 ("o equipamento define a barra").
- **NPC:** armeiro de treino no acampamento; [E] abre um menu e troca o estilo na hora, de graça. Só para teste — a regra real (inventário/forja/Carga) fica para depois.
- **Monstros:** IA simples que patrulha, persegue e ataca com aviso (telegrafia); renascem. Slime, Esqueleto e Morcego (Quaternius), além da Besta de Sucata.

## Proposta de números (ajustar jogando)

| Estilo | Esq. (básico 1) | Dir. (básico 2) | Peso |
|---|---|---|---|
| Espada e escudo | combo A→B→C, cortante 22, Postura 12, Vigor 12 | segurar = bloqueio frontal: −80% dano, −70% Postura, Vigor paga o golpe | 14 |
| Arma pesada | golpe lento, impacto 45, Postura 40, quebra ×2, Vigor 22 | investida com golpe, impacto 35, Vigor 28 | 30 |
| Cajado arcano | dardo arcano (projétil), tempestade 20, Éter 8 | explosão telúrica em área, terra 40, Éter 20, enraizado | 8 |

- Jogador ganha hurtbox; Postura zerada = atordoado; Vida zerada = **Caído** por 5 s (valor de teste; o GDD-05 fala em 30 s) e volta no acampamento.

## Critérios de pronto
- [x] `WeaponStyle` (Resource) + 3 `.tres` em `resources/weapons/`.
- [x] Player usa o estilo atual nos 2 básicos; bloqueio; hurtbox; atordoado e Caído.
- [x] Equipamento visível troca junto com o estilo.
- [x] Armeiro de treino com menu de troca.
- [x] 3 monstros com IA (patrulha → persegue → ataca com aviso → morre → renasce).
- [x] Testes headless e render no `world.tscn`.

## Próximo passo (uma frase)
Tarciso jogar a arena e ajustar os números da tabela; depois decidir se o B10 vira a base do `CasterComponent`/`AbilityData` do GDD-01 §4.

## Log
- 2026-10-21 — Bloco criado; decisões fechadas com o Tarciso.
- 2026-10-21 — Implementado (Claude). Dados: `StyleAttack` (MELEE/LUNGE/PROJECTILE/AREA/BLOCK, preparação → golpe ativo → recuperação), `EquipmentPiece` (peça presa a osso, medida na pose de descanso, então serve para qualquer DNA) e `WeaponStyle`. Armas do KayKit Weapons (`assets/models/weapons/`): espada `sword_A` + escudo `shield_A`, mangual `hammer_B`, cajado `staff_B`; ombreiras de couro/ferro na clavícula. Player: mira pela câmera no início do golpe, combo A→B→C, bloqueio frontal (−80% dano, Vigor paga 0,6 por ponto segurado, guarda quebra sem Vigor), i-frames nos primeiros 0,2 s da esquiva, reação a golpe, Postura quebrada trava o combate, Caído 5 s e volta ao spawn. `CombatResolver` chama `filter_incoming_hit` no alvo antes da mitigação; `HitboxComponent.ignore_group` impede monstros de se ferirem. Maestria: impacto → `concussão`, tempestade → `canalização`. Mestre de Armas (`scenes/weapon_trainer.tscn`) ao lado do acampamento: [E] cura e abre o menu. `TestMonster` + `MonsterArena` em (−17, 6): 2 Slimes (resistem a corte), 2 Esqueletos (fracos a impacto, resistem a perfurante), 1 Morcego voador (fraco a tempestade); aviso = pisca vermelho + "!". `tests/test_battle_styles.gd` (5 grupos) e suíte 7/7. Luta real no mundo conferida (esqueleto tirou 48 de Vida e morreu na espada). Obs.: a arena divide o pasto com cavalos e porcos da fauna.
- 2026-10-22 — Status `review` (fora da convenção) → `pending`: espera o Tarciso jogar a arena (agora em −27, 3, fora da vila) e ajustar os números.
