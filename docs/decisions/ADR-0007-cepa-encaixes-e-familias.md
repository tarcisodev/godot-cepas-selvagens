---
type: adr
status: accepted
created: 2026-10-25
updated: 2026-10-25
tags:
  - adr
  - decisao
  - cepa-selvagem
  - equipamento
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
deciders: tarciso
supersedes: ""
superseded_by: ""
---

# ADR-0007 — 8 encaixes no estilo Albion; família pelo revestimento, sem bônus de set

## Contexto
Hoje o jogo tem 3 encaixes forjados (cabeça, peito, mãos) e as armas são estilos fixos do Mestre de Armas (B10). O Tarciso quer um equipamento como o do Albion: arma primária e secundária, capacete, armadura, botas, capa, mochila, e as famílias ferro, couro e pano. O GDD-02 já tem `armadura_leve/media/pesada`, e o GDD-06 já diz que o revestimento define o peso.

## Opções consideradas
1. **Mãos:** manter como 9º encaixe / fundir no peito / virar arma secundária.
2. **Set:** bônus por 3+ peças da mesma família / sem bônus.
3. **Família:** vem do material do revestimento / vem de cada receita.
4. **Armas:** forjadas como as armaduras / estilos fixos.

## Decisão
Escolhas do Tarciso em 2026-10-25, todas as recomendadas:
- 8 encaixes: arma primária, arma secundária, cabeça, peito, botas, capa, mochila, e os consumíveis. O encaixe **mãos sai** e as braçadeiras viram visual do peito.
- **Sem bônus de set.** A família vale por peça e misturar é a build (um eixo só de balanceamento, como na [[08-Knowledge/decisions/ADR-0001-cepa-sem-atributos-primarios|ADR-0001]]).
- **Família pelo revestimento:** pano = `armadura_leve`, couro = `armadura_media`, ferro = `armadura_pesada`.
- **Armas forjadas** com os mesmos 3 slots. Arma de duas mãos trava a secundária.

## Consequências
- Positivas: nenhuma tag nova de maestria; uma receita rende 3 famílias; a caça alimenta também as armas; a mochila dá um alvo claro para o full loot.
- Negativas / riscos: 9 listas de habilidades (família × encaixe) para desenhar; as receitas atuais mudam de peso (GDD-12 §5); quem já tem braçadeiras salvas precisa migrar.
- O que muda: `ForgedItem.Slot` (sai `HANDS`; entram `MAIN_HAND`, `OFF_HAND`, `FEET`, `CAPE`, `BAG`), `InventoryComponent`, `Forge` (família vinda do revestimento, receitas de arma), `WeaponStyle` passa a sair da arma primária equipada, `GearVisual`, save.

## Referências
- [[03-Projects/Cepa-Selvagem/notas/GDD-12-Equipamento-e-encaixes|GDD-12]]
- [[03-Projects/Cepa-Selvagem/notas/GDD-06-Materiais-e-forja|GDD-06]] · [[03-Projects/Cepa-Selvagem/notas/GDD-01-Combate-e-magia|GDD-01]] · [[03-Projects/Cepa-Selvagem/notas/GDD-02-Progressao-por-uso|GDD-02]]
