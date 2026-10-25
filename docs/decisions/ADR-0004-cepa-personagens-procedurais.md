---
type: adr
status: accepted
created: 2026-10-21
updated: 2026-10-22
tags:
  - adr
  - decisao
  - cepa-selvagem
  - personagens
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
deciders: tarciso
supersedes: ""
superseded_by: ""
---

# ADR-0004 — Personagens humanoides gerados por código sobre o rig UAL

## Contexto
O visual dos personagens depende de modelos prontos (Quaternius: Male/Female Ranger e Peasant). Cada variação nova pede outro asset, e o jogo quer muitos NPCs e jogadores distintos. As animações UAL1/UAL2 (~86 clipes) já servem como base de movimento, e o esqueleto delas tem 65 ossos. Só a pelve tem trilha de posição; os outros ossos só giram.

## Opções consideradas
1. **Variar o modelo existente** (escala de osso, cor, acessório): rápido, mas continua preso ao asset.
2. **Malha procedural com skin no rig UAL**: o corpo é gerado por código e as animações UAL continuam valendo sem ajuste.
3. **100% procedural** (esqueleto e animação procedurais): independência total, mas perde os golpes, a esquiva e o cast prontos.

## Decisão
**Opção 2** (aceita pelo Tarciso em 2026-10-22; "depois melhoramos"). Um Resource `CharacterDNA` (seed + parâmetros) define o personagem de forma determinística. O gerador:
- copia o esqueleto do UAL e ajusta os comprimentos dos ossos (perna, tronco, braço, pescoço) conforme o DNA;
- gera a malha (tronco, membros, cabeça, mãos, pés, cabelo, roupa por cor de vértice) já com skin nesses ossos;
- corrige a altura da pelve animada pela razão da perna (`SkeletonModifier3D`), para o pé não flutuar nem afundar.

## Consequências
- Positivas: variedade infinita sem asset; o DNA é pequeno e serializável (rede e save); o mesmo DNA gera o mesmo personagem no cliente e no servidor.
- Negativas / riscos: o visual fica estilizado e simples (low-poly) e não chega à arte final; dedos ficam em "luva" (mão em bloco e polegar).
- O que muda: `CharacterVisual` aceita `dna` como alternativa a `model_scene`. O escopo agora é só humanoide; as criaturas ficam para depois, ligadas ao genoma do [[03-Projects/Cepa-Selvagem/notas/GDD-04-Ecologia-e-genetica|GDD-04]].

## Referências
- [[03-Projects/Cepa-Selvagem/blocos/B09-gerador-procedural-de-personagens|B09]]
