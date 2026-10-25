---
type: block
status: active
created: 2026-10-25
updated: 2026-10-25
tags:
  - bloco
  - godot
  - mundo-aberto
  - chunks
  - multimesh
  - multiplayer
  - persistencia
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B24 — Mundo Aberto em Chunks, MultiMesh & Servidor Beta com Persistência

## Objetivo
Expandir o mundo de *Cepas Selvagens* do vale inicial (360 m) para **escala de quilômetros**, viabilizando a necessidade e o prazer da **montaria** para travessias longas.
Implementar uma arquitetura de **streaming de terreno em chunks com MultiMesh** para vegetação, além de preparar o **servidor dedicado headless com persistência** para rodar localmente no PC e conectar amigos no Beta.

## Pilares e Arquitetura Técnica

### 1. Sistema de Terreno em Chunks (`TerrainChunkManager`)
- O mapa deixa de ser uma malha estática única de 360×360 m e passa a ser particionado em **chunks** (ex.: 64×64 m ou 128×128 m).
- Cada chunk avalia a função contínua de altura `get_height_at(x, z)` (expandindo ruído Simplex e relevo procedural para além das fronteiras antigas).
- Chunks próximos ao jogador (ou aos jogadores no multiplayer) geram malha visual (`ArrayMesh`) e colisão física (`HeightMapShape3D`).
- Chunks fora do raio de visão são descarregados da memória ou simplificados.

### 2. Vegetação Otimizada via MultiMesh por Chunk
- Cada chunk ativo hospeda suas próprias instâncias de `MultiMeshInstance3D` para grama, trevos, flores e rochas pequenas.
- Permite frustum culling real por GPU (apenas os chunks visíveis na tela têm suas draw calls processadas).

### 3. Remoção do Gargalo de Fronteira e Integração da Montaria
- `WorldBounds` passa a suportar raio ampliado de quilômetros (ou modo streaming ilimitado).
- O resgate de limbo do `Player` e da `Mount` se ajusta dinamicamente à posição atual, sem limites artificiais de 180 m.
- Travessia suave de montarias (terrestre, voadora e aquática) entre fronteiras de chunks.

### 4. Servidor Headless Autoritativo e Persistência de Jogadores
- Suporte a inicialização headless com argumento `--server` ou `--port <porta>`.
- O servidor atua como fonte da verdade para inventário, equipamentos, posição e montarias.
- Módulo de persistência que salva o estado dos jogadores em arquivos individuais no servidor ao desconectar e recarrega na reconexão.

## Critérios de Pronto
- [ ] Documento do Bloco B24 registrado no repositório.
- [ ] `TerrainChunkManager` funcional gerando relevo contínuo sem frestas entre chunks adjacentes.
- [ ] MultiMesh populado dinamicamente por chunk de terreno.
- [ ] `WorldBounds` e limites de limbo do jogador adaptados para escala de quilômetros.
- [ ] Persistência do servidor gravando dados do jogador ao desconectar e restaurando na entrada.
- [ ] Suíte de testes headless validando geração de chunks, MultiMesh e persistência de dados.
- [ ] `33/33` (ou novos testes adicionados) passando com 100% de sucesso no `run_all.gd`.
