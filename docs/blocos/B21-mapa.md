---
type: block
status: active
created: 2026-10-25
updated: 2026-10-25
tags:
  - bloco
  - godot
  - mapa
  - ui
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B21 — Mapa [M]

## Objetivo
Pedido do Tarciso (backlog, item 3): [M] abre o mapa do vale inteiro, sem névoa, e o que os jogadores constroem aparece nele. Design fechado em [[03-Projects/Cepa-Selvagem/notas/GDD-11-Mapa|GDD-11]] (decisões do Tarciso em 2026-10-25): pergaminho sobre o relevo real, ninguém além de você, personagem parado com o mapa aberto, sem minimapa, nada vivo.

## Critérios de pronto
- [x] **`MapImageBaker`:** textura ~512 × 512 de pergaminho gerada uma vez ao carregar, a partir de `get_height_at` e do rio: relevo com sombreado, curvas de nível a cada 4 m, rio e água profunda em tinta azul, borda e rosa dos ventos.
- [x] **`WorldMapScreen` ([M]):** abre e fecha com [M], fecha com [Esc]; zoom 1×–4× na roda, arrastar move, [Espaço] centraliza no jogador. O mundo não pausa; o personagem fica parado; **tomar dano fecha o mapa**.
- [x] **Camadas fixas:** zonas do `ZoneManager` (Cidade verde, Covil vermelho tracejado, Arena laranja) e nomes dos lugares (Vila da Esperança, Arena de Teste, Covil da Besta de Sucata, Taverna, Mercado, Forja Pública).
- [x] **Camada dos jogadores:** círculo de cada totem (14 m) com o dono no hover; peças como traços pequenos (piso, parede, cerca) e ícones (canteiro, bancada); totem abandonado em cinza. Obras da Vila com o ícone da etapa. Redesenha só quando o `BuildingSystem` ou o `TownProject` avisam uma mudança (sinal), nunca por frame.
- [x] **Você e suas montarias:** seta na sua posição virada para a câmera; ícone de cada montaria sua, atualizado a cada 1 s com o mapa aberto.
- [x] **Fora do mapa:** outros jogadores, bichos, plantas, peixes e recursos (nada disso é lido pelo mapa).
- [x] **Marcadores pessoais:** clique direito põe (6 ícones e nome curto opcional); clique direito em cima apaga; até 20; clique esquerdo ativa um, que aparece no HUD como setinha na borda da tela com a distância. Entram no `SaveGame`.
- [x] **Testes headless:** bake com o tamanho certo e o rio em azul; peça nova e totem aparecem na camada pelo sinal; limite de 20 marcadores e save/load; dano fecha o mapa; nenhum nó de bicho ou jogador alheio nas camadas. Runner inteiro passando.
- [x] **Prints:** mapa do vale inteiro e com zoom num território com peças e marcadores.

## Fora deste bloco
- Grupo/guilda no mapa, compartilhar marcadores, sede de guilda com brasão (backlog itens 1 e 2).

## Próximo passo (uma frase)
Bloco concluído e verificado com 43/43 testes passando.

## Log
- 2026-10-25 — Bloco criado (Claude) a partir do GDD-11, com o §9 fechado pelo Tarciso.
- 2026-10-25 — B21 concluído e verificado com `MapImageBaker` (512x512 hillshading + 4m contour lines), `WorldMapScreen` interativo com zoom 1x-4x, pan drag, centralização [Espaço], dano fechando mapa, 20 marcadores pessoais persistidos no SaveGame e guia de bússola. Teste `test_world_map_and_markers.gd` 100% aprovado.
