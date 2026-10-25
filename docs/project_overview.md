---
type: project
status: active
created: 2026-10-21
updated: 2026-10-25
tags:
  - projeto
  - jogo
  - godot
  - gdd
owner: tarciso
client: "interno (Tarciso.Dev)"
brief: ""
repo: "https://github.com/tarcisodev/godot-cepas-selvagens (privado)"
---

# Cepa Selvagem

## Objetivo
Sandbox MMORPG / Action RPG de alta magia, feito em Godot, focado em **exploração, ecologia viva e economia guiada pelos jogadores**. Primeiro o GDD fecha como os sistemas se encaixam; só depois sobem estrutura e código.

## Princípio de trabalho
**Design antes de código.** Cada sistema é desenhado em nota de GDD, as decisões viram ADR, e só então entra num bloco de execução. Objetivo: sistemas que conversam entre si e um jogo que não infla.

Índice do GDD → [[03-Projects/Cepa-Selvagem/notas/GDD-00-Visao-e-pilares|GDD-00 — Visão e pilares]]

## Escopo (fase atual: GDD + vertical slice)
- GDD dos 5 pilares, um por nota, com perguntas em aberto explícitas.
- ADRs das decisões estruturais (atributos, autoridade de rede, dano como evento).
- Vertical slice jogável: combate de ação + 1 criatura com partes quebráveis + forja de 1 item com o material dela.

## Fora de escopo (por enquanto)
- Servidor MMO real, persistência, contas, ZvZ/GvG.
- Mercado de jogadores funcional (só desenho no GDD).
- Arte final, lore completa, monetização.

## Bloco ativo
[[03-Projects/Cepa-Selvagem/blocos/B23-equipamento-boss-e-minerio|B23 — Equipamento estilo Albion, boss, minério e golpes com peso]]

## Blocos

```dataview
TABLE status, owner, updated
FROM ""
WHERE type = "block" AND contains(file.folder, this.file.folder)
SORT file.name ASC
```

Fallback (sem Dataview):
- [x] [[03-Projects/Cepa-Selvagem/blocos/B01-gdd-combate-e-caca|B01 — GDD: combate e caça anatômica (Pilares 1+3)]] — **done**
- [x] [[03-Projects/Cepa-Selvagem/blocos/B02-gdd-materiais-e-forja|B02 — GDD: material → receita → forja]] — **done**
- [x] [[03-Projects/Cepa-Selvagem/blocos/B03-gdd-progressao-por-uso|B03 — GDD: progressão por uso (maestria)]] — **done**
- [x] [[03-Projects/Cepa-Selvagem/blocos/B04-gdd-ecologia-e-genetica|B04 — GDD: ecologia, genética e botânica]] — **done**
- [x] [[03-Projects/Cepa-Selvagem/blocos/B05-gdd-economia-e-mercado-negro|B05 — GDD: economia e Mercado Negro]] — **done**
- [x] [[03-Projects/Cepa-Selvagem/blocos/B06-arquitetura-tecnica-godot|B06 — Arquitetura técnica no Godot (pastas, rede, dados)]] — **done**
- [x] [[03-Projects/Cepa-Selvagem/blocos/B07-vertical-slice|B07 — Vertical slice: caçar, quebrar, forjar]] — **done**
- [x] [[03-Projects/Cepa-Selvagem/blocos/B08-colecao-de-cartas-3d|B08 — Coleção de cartas 3D e base do mini-game]] — **done**
- [x] [[03-Projects/Cepa-Selvagem/blocos/B09-gerador-procedural-de-personagens|B09 — Gerador procedural de personagens]] — **done**
- [ ] [[03-Projects/Cepa-Selvagem/blocos/B10-estilos-de-batalha-e-arena-de-teste|B10 — Estilos de batalha, armeiro e monstros de teste]] — **pending**
- [x] [[03-Projects/Cepa-Selvagem/blocos/B11-cidade-construcao-e-coleta|B11 — Cidade, construção e coleta]] — **done**
- [x] [[03-Projects/Cepa-Selvagem/blocos/B12-estoque-com-qualidade|B12 — Estoque de materiais com qualidade]] — **done**
- [x] [[03-Projects/Cepa-Selvagem/blocos/B13-fauna-flora-procedurais-e-montarias|B13 — Fauna e flora procedurais, e montarias]] — **done**
- [x] [[03-Projects/Cepa-Selvagem/blocos/B14-captura-e-montaria-propria|B14 — Captura e montaria própria]] — **done**
- [x] [[03-Projects/Cepa-Selvagem/blocos/B15-ciclo-natural|B15 — Rio de verdade e ciclo natural]] — **done**
- [x] [[03-Projects/Cepa-Selvagem/blocos/B16-forja-modular|B16 — Forja modular com materiais de caça]] — **done**
- [x] [[03-Projects/Cepa-Selvagem/blocos/B17-cenario-carga-e-save-da-natureza|B17 — Cenário, carga do mundo e save da natureza]] — **done**
- [x] [[03-Projects/Cepa-Selvagem/blocos/B18-taverna-e-mercado|B18 — Funções da Taverna e do Mercado]] — **done**
- [x] [[03-Projects/Cepa-Selvagem/blocos/B19-nado-peixes-e-pesca|B19 — Nado, mergulho, peixes procedurais e pesca]] — **done**
- [x] [[03-Projects/Cepa-Selvagem/blocos/B20-pinheira-lume|B20 — Pinheira-Lume]] — **done**
- [ ] [[03-Projects/Cepa-Selvagem/blocos/B21-mapa|B21 — Mapa [M]]] — **pending**
- [x] [[03-Projects/Cepa-Selvagem/blocos/B22-relogio-unico-e-descansar|B22 — Relógio único e Descansar]] — **done**
- [ ] [[03-Projects/Cepa-Selvagem/blocos/B23-equipamento-boss-e-minerio|B23 — Equipamento estilo Albion, boss, minério e golpes com peso]] — **active**

## Stack e repositórios
- Repositório: [tarcisodev/godot-cepas-selvagens](https://github.com/tarcisodev/godot-cepas-selvagens) (GitHub, **privado**, branch `master`) · local `E:\dev\game-ia\godot-cepas-selvagens`.
- Engine: **Godot 4.7**, Forward Plus, GDScript.
- Protótipo existente (até 2026-10-21): mundo procedural (`landscape_generator`, rios, grama, arbustos, cardume, fauna ambiente), ciclo dia/noite, áudio de natureza, player "andarilho contemplativo" (andar/correr/agachar/sentar), câmera híbrida 3ª/1ª pessoa (`camera_rig.gd`), HUD e menus. Autoload: `GameSettings`. ~2.4k linhas de GDScript.
- Ambientes: só local.

## Infra e credenciais (só ponteiros)
- Infra: PC do Tarciso. Sem servidor.
- Credenciais: nenhuma.

## Decisões (ADR)
- [[08-Knowledge/decisions/ADR-0001-cepa-sem-atributos-primarios|ADR-0001 — Sem atributos primários]] (accepted)
- [[08-Knowledge/decisions/ADR-0002-cepa-servidor-autoritativo|ADR-0002 — Servidor autoritativo desde o slice]] (accepted)
- [[08-Knowledge/decisions/ADR-0003-cepa-dano-como-evento|ADR-0003 — Dano como evento + pilha única de modificadores]] (accepted)
- [[08-Knowledge/decisions/ADR-0004-cepa-personagens-procedurais|ADR-0004 — Personagens procedurais sobre o rig UAL]] (accepted)
- [[08-Knowledge/decisions/ADR-0005-cepa-estoque-por-pilha|ADR-0005 — Materiais em pilhas por (id, qualidade, traits)]] (accepted)
- [[08-Knowledge/decisions/ADR-0006-cepa-relogio-unico-sem-pulo|ADR-0006 — Um relógio do mundo, que nenhum jogador pula]] (accepted)
- [[08-Knowledge/decisions/ADR-0007-cepa-encaixes-e-familias|ADR-0007 — 8 encaixes estilo Albion; família pelo revestimento, sem bônus de set]] (accepted)

## Pessoas
- Decisor: [[09-Agents/team/Tarciso|Tarciso]] — visão do jogo, decide as perguntas em aberto, roda a execução.
- [[09-Agents/team/Labu|Labu]] — organiza GDD, blocos, ADRs e prompts.
- Ainda **sem agente de jogo** no time (game design / Godot). Candidato a card quando entrar em execução (B06/B07).

## Riscos e dúvidas
- **Escopo de MMO** é o maior risco. Mitigação: vertical slice single-player com arquitetura que já separa servidor/cliente (ADR-0002).
- Nome: o jogo é "Cepa Selvagem", mas `project.godot` diz "Cepas Selvagens" e a pasta é `godot-cepas-selvagens`. Definir o nome oficial.
- Câmera: decidido no [[03-Projects/Cepa-Selvagem/notas/GDD-01-Combate-e-magia|GDD-01 §8]] — o `camera_rig.gd` do protótipo vai precisar de um modo de combate over-the-shoulder que bloqueia a 1ª pessoa.
- Repo sem git: criar repositório antes de B06.

## Log
- 2026-10-21 — projeto criado pelo Labu a partir da análise dos Pilares 1 e 3; GDD-00/01/03 escritos, GDD-02/04/05 como esboço; 3 ADRs propostas; B01 ativo.
- 2026-10-21 — GDD-01 fechado: câmera de combate over-the-shoulder, gamepad desde o slice, Vida/Éter/Vigor + Postura, esquiva por carga, barra definida pelo equipamento, sem fogo amigo direto, 7 tipos de dano com consequência no material. PvP: duelo consensual + PvP aberto só em mapas/momentos liberados.
- 2026-10-21 — Economia do PvP: duelo com aposta em dinheiro (quem morre perde o valor apostado; sem perda de item); zonas de PvP aberto = full loot. Registrado no GDD-05.
- 2026-10-21 — Aposta sem taxa, até 10% do dinheiro do personagem. Zona Selvagem (full loot): tudo equipado cai, parte destruída, perda de durabilidade, 1 min de prioridade de saque para quem matou.
- 2026-10-21 — Full loot = equipado + inventário; saco até 3 h; morte para monstro na Zona Selvagem = Caído (sem perda de item). Propostas de destruição e durabilidade no GDD-05, aguardando confirmação.
- 2026-10-21 — Propostas aceitas: destruição 20% + 40% × desgaste, pilhas −15%, −10% durabilidade por morte, Caído 30 s / 25% Vida, crédito de abate 30 s.
- 2026-10-21 — GDD-03 fechado: captura (< 20% Vida, armadilha e sedativo) como única fonte de partes Íntegras; esfola manual; reserva de loot única (combate + 1 min); partes por porte (1/3–4/5–6/8); criaturas que fogem regeneram como veteranas Cicatrizadas. B01 só espera as ADRs.
- 2026-10-21 — ADR-0001, ADR-0002 e ADR-0003 aceitas pelo Tarciso; B01 concluído; B02 ativado para desenhar o sistema de materiais, receitas e forja.
- 2026-10-21 — GDD-06 fechado: MaterialData, receita modular (núcleo/fixação/tempero), herança de traits (Cicatrizado/genoma), desgaste permanente no reparo e 3 receitas ponta a ponta. B02 concluído; B03 ativado (progressão por uso / maestria).
- 2026-10-21 — GDD-02 fechado: maestria por uso em 11 tags focadas, XP por dano e mitigação ativos, curva ilimitada 1–100, marcos a cada 25 níveis e travas anti-macro. B03 concluído; B04 ativado (ecologia, genética e botânica).
- 2026-10-21 — GDD-04 fechado: genoma mendeliano unificado (alelos + mutação 3%), breeding no rancho, compostagem de restos de monstros para adubo, tanques aquáticos produtores de solventes e Modo Foto com pesquisa de campo tática. B04 concluído; B05 ativado (economia e Mercado Negro).
- 2026-10-21 — GDD-05 fechado: tabela mestra de torneiras e ralos, mercados locais por cidade com ordens de compra/venda, Mercado Negro sistêmico com precificação dinâmica por escassez, e morte em áreas seguras sem perda de itens. B05 concluído; GDD dos 5 pilares 100% fechado!
- 2026-10-21 — Execução técnica Godot (B06): repositório Git inicializado; arquitetura base em `scripts/{core, data, components, systems}`; `StatsComponent`, `PoolsComponent`, `CombatResolver` e `EventBus` criados e testados headless com 100% de sucesso; Player integrado com Esquiva (tecla C), consumo de Vigor em sprint/pulo e barras de Vida/Vigor/Postura no HUD.
- 2026-10-21 — Rede e Anatomia (B06): `NetworkManager` autoritativo (ADR-0002) e `AnatomyComponent` (GDD-03) implementados e validados em testes unitários headless com 100% de aprovação. B06 concluído; B07 ativado (Vertical slice: caçar, quebrar, forjar).
- 2026-10-21 — Vertical slice jogável (B07): loop ponta a ponta implementado e validado headless com 100% de aprovação (machete vs magia de terra com cajado, quebra de anatomia com feedback sonoro/visual, drops condicionais Íntegro/Lascado, forja com herança de traits e progressão por uso com subida de nível). B07 concluído com sucesso!
- 2026-10-21 — Cartas 3D e Mini-game (B08): GDD-07 documentado; assets do 3D Card Kit extraídos e importados no Godot; bloco B08 ativado para criar a coleção interativa de cartas 3D (tilt/flip), catálogo no HUD e base tática de mini-game.
- 2026-10-21 — Execução B08: `CardData`, `CardDatabase`, `CardCollectionComponent`, `scenes/card_3d.tscn` (com tilt holográfico e flip 180°), `scenes/card_album.tscn` (com palco de inspeção 3D e filtros) e desbloqueio de cartas em combate implementados e validados em testes headless com 100% de sucesso. B08 concluído!
- 2026-10-21 — Polimento visual (Claude): player trocado do boneco de primitivas pelo Male_Ranger animado com a biblioteca UAL1 (`CharacterVisual`, mesmo esqueleto de 65 ossos; machado preso em `hand_r`); Besta de Sucata (Puglin) saiu da T-pose e reage a golpe/morte; removidos os props sci-fi FBX importados em centímetros (antena de 220 m e barril de 100 m que sombreavam o vale inteiro — origem do chão azulado); grama/flores trocadas pelos modelos do Stylized Nature Kit; terreno com `vertex_color_is_srgb`; acampamento reescalado e afastado do rio; bug do `card_album.gd` (tecla K não abria o álbum) corrigido. Testes headless 4/4 passando. Ferramenta `tools/screenshot.gd` para prints automáticos.
- 2026-10-21 — Animações e fauna (Claude): `CharacterVisual` passa a carregar UAL1 + UAL2 (combo de golpe Sword_Regular_A → B; UAL2 também traz Farm_Harvest, TreeChopping, Consume, Chest_Open para esfola/coleta/forja futuras); nova `AnimatedFauna` com 19 animais animados do Farm Animals (cavalos, zebras e vacas caminham pelo pasto; ovelhas, porcos e lhamas pastam) com escala automática; shaders de rio e cachoeira com fluxo e espuma; margem do rio menos saturada. Ainda sem uso: monstros animados Quaternius (Slime, Esqueleto, Morcego, Dragão) e o Imp — candidatos a novas criaturas de caça.
- 2026-10-21 — Repositório publicado no GitHub como privado: tarcisodev/godot-cepas-selvagens (`master`).
- 2026-10-21 — B09 ativado: gerador procedural de humanoides sobre o rig UAL (malha por código, CharacterDNA com seed + parâmetros); ADR-0004 proposta.
- 2026-10-21 — Esfola manual (GDD-03 §8) no jogo: loot do corpo não cai mais na morte; segurar [E] perto do corpo toca `Farm_Harvest` (UAL2) e esfola uma parte a cada 3 s (2,5 / 1,5 / 0,5 s nos marcos 10/50/100 de `esfola`, GDD-02); andar, soltar, atacar ou levar dano interrompe; corpo dura 5 min e o resto se perde; esfolar dá XP de esfola. Fragmentos de partes quebradas em luta continuam caindo na hora. Testes atualizados (4/4). Achado: os testes headless saem com código 0 mesmo quando um `assert` falha — conferir pela mensagem 🎉 ou trocar por `quit(1)` em falha.
- 2026-10-21 — Testes e loop de treino (Claude): `tests/run_all.gd` roda cada `tests/test_*.gd` num processo separado e **sai com código 1** se houver erro de script/asserção ou se faltar a linha final de sucesso (com `--quit-after` para teste travado); verificado com um teste que falha de propósito. Rodar: `godot --path . --headless -s res://tests/run_all.gd`. A Besta de Sucata agora renasce inteira 20 s depois de esfolada ou decomposta. Obs.: outro agente estava trabalhando no mesmo checkout (B09, personagem procedural: `character_visual.gd`, `fish_school.gd`, `character_lab`, `character_dna`…); essas mudanças não são do Claude e ficaram fora dos commits dele.
- 2026-10-21 — Moldura do MVP (Claude): **tela de título** (`scenes/main_menu.tscn`, cena principal do projeto) com Continuar / Novo jogo / Configurações / Sair sobre captura do vale (`assets/ui/menu_background.png`); **SaveGame** (autoload, `user://savegame.json`: posição, hora, materiais, elmo reaplicado, maestrias, cartas, objetivos; autosave a cada 2 min; salvar ao voltar ao título ou sair pelo menu de pausa); **Objectives** (autoload) com painel de 5 etapas do loop: encontrar a besta → quebrar/derrotar → esfolar → forjar o elmo → abrir o álbum. `tests/test_save_and_objectives.gd` (ida e volta por JSON) passa; fluxo título → novo jogo → salvar → título → continuar conferido no jogo. Falta para o MVP: build Windows (sem `export_presets.cfg` e sem templates de exportação instalados). Na mesma hora o B10 (outro agente) estava com `test_vertical_slice.gd` quebrado pelo refactor do Player.
- 2026-10-21 — B10 (Claude): 3 estilos de batalha (espada e escudo, arma pesada, cajado arcano) com armas KayKit e ombreiras visíveis; Mestre de Armas no acampamento ([E] cura e troca o estilo); Arena de Teste a oeste com Slimes, Esqueletos e Morcego que patrulham, avisam antes do golpe e renascem; bloqueio, i-frames, Caído. Suíte 7/7. Aguardando o Tarciso jogar e ajustar números.
- 2026-10-21 — Controles de combate e mira refinados (Antigravity): Cajado arcano com ataque físico corpo a corpo no botão esquerdo (Vigor) e mira pelo ombro no botão direito (zoom tático, offset no ombro direito, retícula no HUD e dardo arcano teleguiado pelo visor com raycast 3D em hurtboxes); Martelo com balanço rápido no botão esquerdo e investida demolidora no direito; Espada e escudo com bloqueio frontal no botão direito e pancada com escudo (contra-ataque com alto dano de postura) no esquerdo durante bloqueio; Sistema anti-limbo com paredes invisíveis e resgate automático do abismo; 9/9 testes passando 100% no runner headless.
- 2026-10-21 — Build Windows do MVP (Claude): templates oficiais do Godot 4.7.2 instalados (SHA-512 conferido contra o SHA512-SUMS do release); `export_presets.cfg` com preset "Windows Desktop" (exe único com pck embutido; exclui tests/, tools/, zips e kit sci-fi). Build gerado de um worktree limpo no commit `60224e2` (10/10 testes verdes ali), conferido: título roda no .exe de release e o mundo carrega do pacote exportado sem recurso faltando. Entregável: `build/CepaSelvagem-MVP-windows.zip` (222 MB: exe 329 MB + LEIA-ME com controles), fora do git. Obs.: o save do build e o do editor usam a mesma pasta de user data.
- 2026-10-22 — B11 registrado (Claude): protótipo de coleta (10 recursos, maestrias `lenharia`/`mineracao`/`coleta`), zonas (cidade sem combate, perigo, água, natureza), Totem de Território, modo construção [B] com 7 peças e a Vila da Esperança com 2 NPCs — feito por outro agente em 2026-10-21 sem bloco nem GDD. Testes 12/12; commitado. Em **review**: falta GDD, save das construções e decidir as tags novas de maestria.
- 2026-10-22 — GDD-08 (rascunho, Claude): território, construção, cidade e coleta. Propõe Totem = rancho do GDD-04, coleta comum como material barato (qualidade ≤ 2), só uma tag nova (`coleta`, sem `lenharia`), zonas encaixadas no GDD-05 e manutenção do totem como ralo de moeda. 10 perguntas em aberto no §8 para o Tarciso.
- 2026-10-22 — GDD-08 fechado (Claude como game designer, a pedido do Tarciso): totem = rancho; só a tag `coleta` (sem `lenharia`, adicionada ao GDD-02); coleta comum até 2★; só mãos no slice; duelo liberado na cidade; 1 totem por personagem a ≥ 20 m da cidade e ≥ 6 m de outro território; manutenção semanal em moeda e abandono após 14 dias reais; base indestrutível fora da Zona Selvagem; reembolso de 50% (100% nos 2 primeiros minutos); sem construção na Zona Selvagem por enquanto. Próximo: aplicar no código do B11.
- 2026-10-22 — B11 alinhado ao GDD-08 (Claude): construções entram no save, catálogo único com a Bancada, [X] desmonta (50% / 100% em 2 min), regras de totem e duelo na cidade, `lenharia` removida. Suíte 12/12. Pendente: qualidade 1★/2★ da coleta, que depende de um inventário com qualidade (`MaterialData`, GDD-06).
- 2026-10-22 — B12 criado (pending, Claude): estoque de materiais com qualidade e traits, para destravar o 1★/2★ da coleta e a forja do GDD-06. ADR-0005 proposta (pilha por id + qualidade + traits; pedido genérico gasta a pior qualidade primeiro). ADR-0004, que faltava na lista de decisões, foi listada como proposed.
- 2026-10-22 — B12 implementado (Claude), ainda sem commit: materiais em pilhas com qualidade e traits, coleta 1★/2★, chifre único com Íntegro como trait, e tela de inventário nova ([I]) com organizador por raridade/quantidade/peso/cor/nome, filtro por grupo e borda por raridade ou grupo. Runner 13/13. A sessão de consumíveis mexe nos mesmos arquivos ao mesmo tempo.
- 2026-10-22 — Commit `22a4284` (Claude): B12 (inventário com qualidade e tela [I]) + consumíveis (baú de suprimentos, atalhos 1/2/3, Vigor e respawn ajustados como valores de teste, ainda fora do GDD). Suíte 14/14. Ainda não enviado ao GitHub.
- 2026-10-22 — Vila da Esperança em obras (Claude, GDD-08 §6.1): 5 obras comunitárias em 3 etapas com Quadro de Obras para doar materiais e Reputação da Vila; NPCs com corpo procedural animado; besta assentada no chão e covil fora da vila (antes não dava para atacá-la); arena movida para oeste. Runner 15/15. Commit `5fab617`, enviado ao GitHub.
- 2026-10-22 — Pedidos do Tarciso (Claude): ADR-0004 aceita e B09 concluído. Correções: Esc não fechava o inventário (a pausa pegava o Esc antes), painel de objetivos por cima dos menus, clique no álbum de cartas capturava o mouse (álbum fora do grupo de menus), prévia do modo construção sempre do mesmo lado (seguia o corpo, que não gira; agora segue a câmera e mostra o motivo do vermelho). Roda rápida de consumíveis ([F] segura a roda sem desacelerar o tempo, [G] usa, [Z]/[X] trocam). Moeda Dólares de Sucata (GDD-05 §5): carteira com 50 $S, Contratos da Vila como torneira, Loja da Alquimista como ralo, desconto por Reputação. B13: fauna e flora procedurais e montarias terrestre, voadora e aquática (GDD-09). Runner 17/17. Commit `4abf68d`, enviado ao GitHub.
- 2026-10-22 — Status dos blocos dentro da convenção (B10 pending, B11 e B12 done, B13 active). Desempenho (Claude): o ecossistema derrubava de 163 para 94 FPS (RTX 3060); partes de cada bicho agora viram uma malha por pivô e peixes/plantas baixas não fazem sombra: 127 FPS, chamadas de desenho 2.707 → 1.856.
- 2026-10-22 — B14 criado (pending): proposta de captura no GDD-03 §9 (bichos do vale viram caça; cansar → Laço de Fibra → Sedativo de Erva; abate Íntegro ou montaria própria com o DNA do bicho). Aguardando o Tarciso.
- 2026-10-22 — B14 concluído (Claude): caça e captura dos bichos procedurais (cansar → Laço de Fibra → Sedativo de Erva), escolha pós-captura (abate Íntegro, estábulo até 3, soltar), montaria própria com o DNA do bicho e no save. Runner 18/18. Commit junto com a otimização de desempenho e o dono das construções.
- 2026-10-22 — B15 concluído (Claude, pedidos do Tarciso): rio com profundidade, mapa 360 m, clima com chuva, cheia e vazão, lua de 28 dias, plantas e bichos com ciclo de vida (GDD-10). Runner 19/19. O Tarciso autorizou seguir para a próxima tarefa sem decisão dele.
- 2026-10-22 — B16 concluído (Claude, seguindo sem decisão do Tarciso): forja modular na bigorna com 4 receitas de caça (elmo, gibão, capuz, braçadeiras), qualidade e traits herdados, durabilidade, reparo e desmanche, peças visíveis no corpo. Runner 20/20.
- 2026-10-22 — B17 concluído (Claude, seguindo sem decisão do Tarciso): mundo abre em metade do tempo (terreno e corpos montados por arrays, colisão por mapa de alturas), nuvens macias, névoa de distância, rio escuro à noite e save da natureza (plantas, bichos, solo, clima). Runner 21/21.
- 2026-10-23 — B18 concluído (Claude, pedido do Tarciso): Taverna pronta abre a mesa do Duelo de Cepas contra a Taverneira (aposta com corte da casa, carta de prêmio); Mercado pronto abre encomendas e vendas atendidas pela caravana às 8h e 17h, com taxas de 2% e 4%. Regras no GDD-07 §7 e GDD-05 §6. Runner 23/23.
- 2026-10-23 — Ideias novas do Tarciso registradas em [[03-Projects/Cepa-Selvagem/notas/Ideias-pendentes|Ideias pendentes]]: guilda construída pelos membros com níveis, quadro de missões (caça, reconhecimento/pesquisa), mapa [M] que mostra o que os jogadores constroem, predadores caçando herbívoros e urubu sobre carcaças. A montaria aquática (Raia-do-Rio) já existe; o problema é achá-la.
- 2026-10-23 — B19 concluído (Claude, pedido do Tarciso): nado com correnteza, mergulho com fôlego de 30 s e afogamento; Raia montável na margem; cardume antigo trocado por Lambari, Traíra e Dourado procedurais; pesca com Vara (boia atrai peixe real, fisgar no clique, briga com tensão da linha). GDD-10 §7 e §8. Runner 24/24.
- 2026-10-23 — B20 Pinheira-Lume (Claude, pedido do Tarciso): araucária que brilha à noite, genoma no pinhão (copa, cor da luz, pinha Fibonacci/mandala), pólen da vizinha, pinha que brota, bichos espalham a semente no esterco, plantio com [G] (canteiro na vila). GDD-10 §9; runner 26/26.
- 2026-10-24 — GDD-11 Mapa [M] em rascunho (Claude, pedido do Tarciso): pergaminho sobre o relevo real, mapa inteiro visível, totens/peças/obras dos jogadores como camada pública, suas montarias e 20 marcadores pessoais; sem outros jogadores, bichos ou minimapa. 5 perguntas no §9 antes do B21.
- 2026-10-24 — GDD-10 §10 em rascunho (Claude, decisões do Tarciso): o "Esperar" só mexia no sol. Agora o relógio é único e nunca pula; Descansar (chão, fogueira, banco, cama) faz a Vida voltar, dá o buff Descansado e a cama vira o lugar de renascer. A duração do dia no online fica em aberto. ADR-0006 proposed.
- 2026-10-24 — O Tarciso aceitou a ADR-0006 e os números do GDD-10 §10. B22 criado e ativo (Claude): relógio único, fim do Esperar, Descansar com Vida por lugar, buff Descansado, Fogueira/Banco/Cama, cama como renascer. B21 continua reservado para o Mapa.
- 2026-10-25 — O Tarciso fechou o GDD-11 (Mapa [M]) com as 5 recomendações: pergaminho, ninguém além de você, personagem parado, sem minimapa, nada vivo. B21 criado como `pending` (Claude); entra depois do B22.
- 2026-10-25 — GDD-12 Equipamento em rascunho (Claude, pedido do Tarciso): 8 encaixes estilo Albion (arma primária/secundária, cabeça, peito, botas, capa, mochila, consumíveis), famílias pano/couro/ferro pelo revestimento, sem bônus de set, armas forjadas, sai o encaixe mãos. ADR-0007 accepted; 6 perguntas no §6 antes do bloco.
- 2026-10-25 — O Tarciso aceitou o GDD-12 §6 e pediu boss, minério, peso dos golpes e fim do aviso. B23 feito (Claude): 7 encaixes com família pelo revestimento, armas forjadas, 9 habilidades de armadura, mochila e capa, veios de ferro e quartzo com fundição, CombatFeel (hitstop local, empurrão, tranco), monstros sem aviso e o Rinolito Ancião na Clareira do Ancião. Runner 28/28. Próximo: Lobo-do-Ermo e Tatu-Espinho (GDD-12 §12).
- 2026-10-25 — Lobo-do-Ermo (bando noturno) e Tatu-Espinho (guarda os veios) no mapa, com Couro e Presa de Lobo e Garra de Tatu na forja (GDD-12 §12). Capa nova da tela de título. Runner 29/29 (Claude).
- 2026-10-25 — Tocha na mão secundária, sono de distância dos bichos (41 → 61 FPS no acampamento) e tela de equipamento no [I] com boneco 3D, equipar e desequipar (GDD-12 §13). Runner 31/31 (Claude).
- 2026-10-25 — B22 concluído (Claude, pedido do Tarciso): relógio único (bichos, fruta e esterco leem o sol), Esperar removido, Descansar com Vida por lugar e bloqueio de combate, buff Descansado, Fogueira/Banco/Cama, fogueira pública no acampamento e cama como renascer. Runner 27/27. B21 (Mapa) vira o bloco ativo.
