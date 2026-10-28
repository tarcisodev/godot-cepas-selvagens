---
type: block
status: active
created: 2026-10-25
updated: 2026-10-25
tags:
  - bloco
  - godot
  - guilda
  - territorio
  - heraldica
  - uniformes
  - multiplayer
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B26 — Guildas, Território Expandido (40 a 80m), Heráldica e Uniformes de Clã

## Objetivo
Implementar o sistema de **Guildas construídas no mundo pelos próprios jogadores**, **Território Comunitário Expandido** (40 m no Nível 1 a 80 m no Nível 3), **Heráldica Personalizada** (cores primária/secundária e brasão) e **Uniformes por Ocasião** (Set de Gala, Set de Batalha e Equipamento Pessoal), atendendo integralmente ao [[03-Projects/Cepa-Selvagem/notas/GDD-15-Guildas-territorio-e-uniformes|GDD-15]].

---

## Pilares Técnicos e Arquitetura

### 1. Dados e Heráldica da Guilda (`GuildData` & `GuildSystem`)
- **Identidade e Símbolos:**
  - `name`: Nome do clã.
  - `tag`: Sigla de 3 a 4 caracteres exibida no mundo e chat.
  - `motto`: Lema da organização.
  - `primary_color` & `secondary_color`: Paleta heráldica aplicada em estandartes, capas e totens.
  - `emblem_id`: Ícones heráldicos canônicos (`lobo`, `rinolito`, `pinheira`, `espadas`, `ancora`, `falcao`).
- **Hierarquia:** Cargos bem demarcados (`LEADER`, `OFFICER`, `MEMBER`, `RECRUIT`). Membros e superiores possuem permissão de construção e uso comunitário no território.
- **Persistência Completa:** Métodos de ida e volta por JSON/Dictionary (`to_dict()`, `from_dict()`, `to_array()`, `load_from_array()`), compatíveis com servidor dedicado e saves locais.

### 2. Totem de Guilda & Território Expandido (`GuildTotem` & `ZoneManager`)
- **Raio de Posse Escalonado (GDD-15 §1):**
  - **Nível 1 (Acampamento Pioneiro):** 40 metros de raio.
  - **Nível 2 (Forte de Madeira):** 60 metros de raio.
  - **Nível 3 (Cidadela de Pedra & Ferro):** 80 metros de raio.
- **Integração com `ZoneManager`:** Ao registrar o `GuildTotem` nos `active_totems`, o `ZoneManager` verifica a permissão de guilda (`can_member_build(player_name)`) antes de autorizar ou bloquear qualquer peça de construção no perímetro.
- **Estandarte 3D Integrado:** Mastro monumental com flâmula animada ao vento exibindo o brasão e cores da guilda.

### 3. Evolução da Sede por Contribuição Comunitária (`GuildScreen`)
- Assim como no Quadro de Obras da Vila, os integrantes do clã doam materiais para a evolução da sede:
  - Do Nível 1 para o 2: Madeira (40), Pedra (30), Barra de Ferro (10).
  - Do Nível 2 para o 3: Pedra (80), Barra de Ferro (40), Quartzo-Lume (15).
- A interface `GuildScreen` exibe barras de progresso coletivas com botões de doação direta da mochila.

### 4. Uniformes de Clã por Ocasião (`GuildComponent` & `GearVisual`)
- Conforme **GDD-15 §4**, o jogador alterna com 1 clique no armário da guilda:
  - 🎒 **Equipamento Pessoal:** Conjuntos forjados normais com cores livres.
  - 🎩 **Set de Gala do Clã:** Traje cerimonial nas cores primária e secundária da guilda para eventos sociais, banquetes e casamentos na capela.
  - ⚔️ **Set de Guerra do Clã:** Armadura completa com o **Brasão bordado na Capa** e cores corporativas para incursões territoriais e combate em grupo.
- `GearVisual` renderiza dinamicamente as cores e o emblema do clã na capa do personagem ao entrar em modo Gala ou Guerra.

---

## Critérios de Pronto
- [x] Documento do Bloco B26 registrado no repositório.
- [x] `GuildData` criado com suporte a heráldica, cargos, níveis de sede e persistência.
- [x] `GuildSystem` gerenciando criação, consulta e serialização de clãs no mundo.
- [x] `GuildTotem` procedural implementado com raio de 40m a 80m e prompt interativo `[E] Sede da Guilda`.
- [x] `ZoneManager` integrado permitindo construção de membros autorizados no território da guilda.
- [x] `GuildBanner3D` com mastro, tecido animado ao vento e projeção do brasão.
- [x] `GuildComponent` no `Player` com seleção de ocasião (`PERSONAL`, `GALA`, `WAR`).
- [x] `GearVisual` adaptado para exibir capa tingida nas cores da guilda com o brasão do clã.
- [x] `GuildScreen` interativa com 4 abas (Visão Geral, Contribuição, Membros e Armário de Uniformes).
- [x] Peça de construção `PieceType.TOTEM_GUILDA` no `BuildablePiece`.
- [x] Suíte de testes headless `tests/test_guilds_and_heraldry.gd` aprovada com 100% de sucesso.
