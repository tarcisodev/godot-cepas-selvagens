---
type: block
status: done
created: 2026-10-22
updated: 2026-10-22
tags:
  - bloco
  - godot
  - desempenho
  - cenario
  - save
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B17 — Cenário, carga do mundo e save da natureza

## Objetivo
Polir o que o B15 deixou: o mundo maior demorava para abrir, as nuvens eram discos achatados, a borda do mapa aparecia como uma faixa cinza e a natureza (plantas, bichos, solo, clima) se perdia ao sair do jogo. O Tarciso autorizou seguir sem decisão dele.

## Critérios de pronto
- [x] Carga do mundo medida por nó e os laços vértice a vértice trocados por arrays.
- [x] Nuvens macias (cúmulos) que escurecem com a chuva e à noite.
- [x] Névoa de distância: a borda do mapa some no horizonte; rio sem brilho à noite.
- [x] Save das plantas, bichos selvagens, solo e clima/cheia ([[03-Projects/Cepa-Selvagem/notas/GDD-10-Ciclo-natural|GDD-10]]).
- [x] Testes, prints e medição de FPS.

## Números
| Medida | Antes | Depois |
|---|---|---|
| Nós do mundo (_ready) | 5,3 s | 2,5 s |
| Terreno | 2,7 s | 0,8 s |
| Plantas e bichos | 1,35 s | 0,4 s |
| Carga total (com shaders) | 7,5 s | 6,3 s |
| FPS médio | 94 | 93 |

## Próximo passo (uma frase)
Tarciso jogar uma noite inteira com chuva e ver se o céu, as nuvens e a névoa convencem; depois funções dos prédios da vila (mesa de cartas na Taverna, encomendas no Mercado) ou armas forjadas ligadas aos estilos do B10.

## Log
- 2026-10-22 — Bloco criado e feito (Claude, sem decisão do Tarciso, como autorizado). Terreno: grade indexada com altura e cor uma vez por ponto, normais pelas alturas vizinhas, colisão `HeightMapShape3D` em vez de malha de triângulos. `MeshBatch` (novo): plantas e bichos somam primitivas transformando os arrays inteiros, com as formas fixas em cache. Nuvens: `materials/cloud.gdshader`, 30 cúmulos de pufes virados para a câmera com borda de ruído, topo claro e base cinza; acompanham chuva e noite e andam pelo mapa inteiro. Névoa de profundidade sempre ligada (fecha com chuva) e chão do céu na cor do horizonte. Rio: brilho próprio cai à noite. Save: `nature` com plantas (DNA, estágio, idade), bichos (DNA, idade, fome, sede, casa), solo (base64) e clima/cheia; ao continuar, o spawner não semeia de novo. Teste `tests/test_nature_save.gd`; runner 21/21.
