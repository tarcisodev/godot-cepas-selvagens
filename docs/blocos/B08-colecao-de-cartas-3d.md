---
type: block
status: done
created: 2026-10-21
updated: 2026-10-21
tags:
  - bloco
  - godot
  - cartas-3d
  - minigame
owner: labu
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
agent: atlas
---

# B08 — Coleção de cartas 3D e base do mini-game

## Objetivo
Implementar o sistema de **Cartas 3D Colecionáveis** (GDD-07) utilizando os assets do 3D Card Kit: inspeção tridimensional interativa (tilt holográfico com o mouse e flip de 180°), componente de inventário/álbum (`CardCollectionComponent`), interface de álbum no HUD e modelo de dados pronto para o futuro mini-game tático de tavernas.

## Critérios de pronto
- [x] Importação e montagem da carta 3D (`scenes/card_3d.tscn`): container/moldura, frente, verso e diorama 3D central.
- [x] Estrutura de dados `CardData` com identificadores, categoria, raridade, modelo e atributos de mini-game (Éter, Poder, Postura, Elemento, Trait).
- [x] `CardCollectionComponent` integrado ao `Player`, gerenciando catálogo descoberto e sinais de desbloqueio.
- [x] Desbloqueio contextual no combate: derrotar criaturas ou quebrar partes anatômicas desbloqueia novas cartas colecionáveis no mundo.
- [x] Interface de Álbum / Catálogo 3D (`scenes/card_album.tscn`): visualização em grade, contagem de progresso, filtro e palco de inspeção 3D com rotação e flip.
- [x] Tecla de atalho `K` e botão no HUD/Menu de ações para abrir e fechar o álbum de cartas.
- [x] Testes unitários automatizados headless (`tests/test_card_collection.gd`) com 100% de aprovação.
- [x] Vault atualizado e sincronizado.

## Contexto
- Documentação no [[03-Projects/Cepa-Selvagem/notas/GDD-07-Cartas-colecionaveis-e-minigame|GDD-07]].
- Assets importados em `assets/cards_3d/card_kit/` (glTF e Renders).
- Código em `E:\dev\game-ia\godot-cepas-selvagens`.

## Próximo passo (uma frase)
Sistema de cartas 3D e álbum concluídos e testados; pronto para os próximos passos de gameplay, regras de duelo do mini-game de taverna ou expansão de criaturas.

## Log
- 2026-10-21 — Bloco B08 criado e ativado; GDD-07 documentado; assets do 3D Card Kit extraídos e importados no Godot com sucesso.
- 2026-10-21 — Sistema completo de cartas 3D implementado e validado headless (5/5 suites em `test_card_collection.gd`): CardData/Database, CardCollectionComponent com desbloqueio contextual no combate (quebra do chifre e abate), cena tridimensional Card3D com tilt de mouse e flip 180°, interface de Álbum de Cartas (tecla K e menu de ações) com filtro por categoria e palco de inspeção 3D. Bloco concluído!
