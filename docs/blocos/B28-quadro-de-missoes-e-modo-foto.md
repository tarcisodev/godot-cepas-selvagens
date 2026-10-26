---
type: block
status: active
created: 2026-10-25
updated: 2026-10-25
tags:
  - bloco
  - godot
  - missoes
  - contratos
  - caca
  - forja
  - culinaria
  - modo-foto
  - economia
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B28 — Quadro de Missões, Contratos Dinâmicos & Modo Foto [P]

## Objetivo
Implementar o sistema de **Quadro de Missões e Contratos Dinâmicos da Vila da Esperança** integrando todas as frentes do jogo — **Caça Anatômica** (partes íntegras), **Mineração & Forja** (materiais e peças forjadas), **Culinária & Taverna** (refeições de caldeirão e espeto) e **Reconhecimento & Modo Foto** (enquadramento fotográfico e catálogo de espécimes selvagens com [P]), atendendo integralmente ao item 2 do [[03-Projects/Cepa-Selvagem/notas/Ideias-pendentes|backlog do Tarciso]], [[03-Projects/Cepa-Selvagem/notas/GDD-05-Economia-e-mercado-negro|GDD-05 §5]], [[03-Projects/Cepa-Selvagem/notas/GDD-03-Combate-e-caca|GDD-03]], [[03-Projects/Cepa-Selvagem/notas/GDD-04-Ecologia-e-genetica|GDD-04]] e [[03-Projects/Cepa-Selvagem/notas/GDD-13-Cozinha-e-culinaria|GDD-13]].

---

## Pilares Técnicos e Arquitetura

### 1. Sistema Central de Contratos Dinâmicos (`MissionBoardSystem`)
- **4 Categorias de Contratos:**
  1. `Category.HUNT` (**Caça Anatômica**): Pedidos do curtume e vigias por peças anatômicas específicas (`chifre_galhado`, `placa_carapaca`, `pena_penacho`, `presa_lobo`, `chifre_rinolito`). Recompensa em $S, Reputação da Vila e XP de Esfola.
  2. `Category.FORGE` (**Mineração & Forja**): Reforço das paliçadas e armaria da vila (`barra_ferro`, `minerio_ferro`, `quartzo_lume`). Recompensa em $S, Reputação da Vila e XP de Forja/Mineração.
  3. `Category.COOK` (**Culinária & Taverna**): Abastecimento da taverna com refeições substanciais (`carne_bem_passada 3★`, `gisado_cacador`, `peixe_ao_mel`, `assado_ermo`). Recompensa em $S, Reputação da Vila e XP de Culinária.
  4. `Category.PHOTO` (**Reconhecimento Ecológico**): Levantamento botânico e zoológico para naturalistas (`trotador`, `lobo`, `planador`, `rinolito`, `peixe`, `pinheira`). Recompensa em $S e Reputação da Vila.
- **Ciclo Dinâmico:** O quadro mantém 6 contratos abertos simultaneamente. Ao cumprir uma tarefa, o jogador recebe as recompensas, o contrato é arquivado e um novo pedido emerge para suprir a demanda da comunidade.

### 2. Modo Foto & Câmera de Reconhecimento (`PhotoModeScreen`)
- **Acionamento Imediato:** Tecla de atalho dedicada **[P]** ou clique no botão de atalho do HUD.
- **Visor Fotográfico Profissional:**
  - Grade com linhas dos terços fotográficos e marcações de enquadramento `⌜  ⌝`.
  - Zoom óptico contínuo na roda do mouse (`1.0×` a `4.0×`).
- **Scanner e Identificação de Espécimes:**
  - Varredura em tempo real no cone de visão (alcance até 40 m).
  - Identifica nome da criatura, gênero (Macho/Fêmea), fase da vida (Filhote, Jovem, Adulto, Ancião) e distância.
  - Detecta botânica nativa (Pinheira-Lume, Cepa).
- **Disparo do Obturador (`[Espaço]` ou clique):**
  - Efeito visual de flash e som de clique.
  - Notifica o `MissionBoardSystem` para avançar contratos fotográficos.
  - Desbloqueia espécime no Álbum de Cartas do Jogador (`CardCollectionComponent`).
  - Toast de notificação: *"Foto Registrada no Diário de Campo!"*.

### 3. Estação 3D do Quadro de Missões (`MissionBoard`)
- **Mural Físico na Praça:** Estrutura rústica de madeira com telhado de proteção, cortiça com pergaminhos afixados por tachas de ferro e lampião iluminando os avisos à noite.
- **Interação:** Prompt tridimensional `📋 [E] Quadro de Missões & Contratos`.
- **Interface Gráfica (`MissionBoardScreen`):**
  - Abas por categoria para filtrar contratos rapidamente.
  - Cards detalhados com brasão/ícone, cliente contratante, descrição, barra de objetivo (Você tem X / Y) e recompensas destacadas.
  - Botão de entrega com feedback sonoro e visual.

### 4. Integração Econômica e com o Ciclo Natural (`CityHub`)
- Integrado ao loop de save/load do `CityHub` (ADR-0002).
- As recompensas em Dólares de Sucata depositam diretamente no `WalletComponent`.
- A Reputação adquirida fortalece o status do jogador com o assentamento.

---

## Verificação e Testes
- Suíte automatizada em `tests/test_mission_board_and_photo_mode.gd`:
  1. `test_mission_system_generation()`: Valida geração determinística dos contratos nas 4 categorias e serialização.
  2. `test_contract_delivery_rewards()`: Valida dedução de itens da mochila, ganho de $S, Reputação da Vila e subida de nível de Maestria.
  3. `test_photo_mode_and_recognition()`: Valida scanner do visor, disparo fotográfico e avanço de contratos de reconhecimento.
  4. `test_mission_board_station_and_ui()`: Valida grupos talkable da estação 3D, abertura e filtragem de categorias da interface.
- 100% dos testes aprovados na suíte unificada `run_all.gd`.
