---
type: block
status: done
created: 2026-10-25
updated: 2026-10-25
tags:
  - bloco
  - rancho
  - breeding
  - genetica
  - criadouro
  - montarias
owner: labu
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
agent: labu
---

# B31 — Rancho dos Jogadores, Cercado de Reprodução & Genética de Criadouro

## Objetivo
Implementar o sistema de criadouro doméstico e domesticação seletiva no rancho dos jogadores (GDD-04 §2, GDD-08 §4-§5, GDD-09 §5):
1. **Peça Modular de Construção (`PieceType.CERCADO_BREEDING`):**
   - Cercado rústico de madeira 4m × 4m com portão de acesso, mourões reforçados, cocho de alimentação e cama de palha de choca;
   - Interação `[E]` que abre a interface completa de reprodução (`BreedingPenScreen`).
2. **Criadouro e Sistema de Reprodução (`BreedingPen`):**
   - Gerencia 1 Reprodutor Macho (Sire ♂) e 1 Matriz Fêmea (Dam ♀) da mesma espécie com dimorfismo e compatibilidade biológica;
   - Valida fertilidade (apenas adultos) e restringe colossos indomáveis (Rinolito);
   - Alimentação no cocho com queima contínua durante a gestação ativa (`feed_burn_rate`);
   - Paralisação segura do ciclo caso o alimento acabe, sem matar nem abortar as matrizes (GDD-04 §2);
   - Adubo de monstro mineralizado (`adubo_organico`) amplia a fertilidade e eleva a chance de mutações genéticas de 3% para 10%.
3. **Quadro de Punnett & Previsão Genética:**
   - Calcula em tempo real as probabilidades fenotípicas e genotípicas dos filhotes:
     - Gene Porte (T/t, dominância incompleta): TT (Grande 100%), Tt (Médio 75%), tt (Pequeno 50%);
     - Gene Chifre (C/c, dominante);
     - Gene Padrão de Pelagem (P/p, dominante);
     - Chance de alelos especiais mutantes (`*`).
4. **Os 3 Destinos do Filhote Cultivado (GDD-04 §2):**
   - **Abate Cuidadoso (`harvest_offspring`):** Abate limpo sem combate no próprio rancho, garantindo 100% de partes anatômicas com qualidade máxima (3★), trait obrigatório `integro` (+1★ na forja) e traits genéticos raros cultivados (`denso`, `veloz`, `chifre_macico`, `camuflado`, `iridescente`). Concede XP de maestria de Esfola.
   - **Promover a Montaria Própria (`promote_offspring_to_mount`):** O filhote amadurece para a vida adulta e passa a integrar a tropa de montarias próprias do jogador (`add_owned_mount`).
   - **Nova Matriz / Reprodutor da Próxima Geração (`promote_offspring_to_breeder`):** Substitui o progenitor do mesmo gênero no cercado, amadurece e avança o contador de linhagem (`generation += 1`), viabilizando a fixação de mutações e características desejadas.
5. **Integração com Captura & Mochila de Matrizes:**
   - Diálogo pós-captura (`CaptureDialog`) inclui opção direta `🏡 Enviar ao Rancho — matriz reprodutiva`;
   - O jogador armazena até 12 matrizes vivas em `player.livestock: Array[CreatureDNA]`.
6. **Interface Gráfica Dedicada (`BreedingPenScreen`):**
   - Painel com design estilizado escuro e dourado/natureza;
   - Status visual do cocho (barra de comida e badge de adubo);
   - Cards dos reprodutores com alelos, porte e botão de alocação/remoção da mochila do rancho;
   - Barra de progresso e contagem regressiva da gestação;
   - Berço do filhote nascido com botões de ação para os 3 destinos.
7. **Persistência Completa (`to_dict` / `from_dict`):**
   - Cercado, geração, nível do cocho, gestação, reprodutores e filhote são salvos e restaurados sem perdas.

---

## Critérios de Pronto
- [x] `scripts/data/creature_dna.gd`:
  - `CreatureDNA.cross(a, b, p_seed, p_mutation_chance)` suporta taxa customizada de mutação (0.03 padrão, 0.10 com adubo);
- [x] `scripts/player.gd`:
  - Lista de matrizes `livestock: Array[_CreatureDNA]` com capacidade máxima de 12;
  - Métodos `add_livestock(dna)` e `remove_livestock(index)`.
- [x] `scripts/ui/capture_dialog.gd`:
  - Quarta opção `&"rancho"` para envio imediato de animais capturados ao Rancho;
  - Validação para desabilitar o botão caso a criatura seja um colosso indomável.
- [x] `scripts/creatures/ecosystem_spawner.gd`:
  - Roteamento da escolha `&"rancho"` para `player.add_livestock(c.dna)` e remoção suave do mundo.
- [x] `scripts/systems/breeding_pen.gd`:
  - Sistema completo `BreedingPen` com roster (sire, dam, offspring);
  - Cocho de alimento (`feed_level`, `max_feed`, `feed_burn_rate`);
  - Suporte a rações vegetais e adubo mineralizado com impulso de mutação (`mutation_boost`);
  - Cálculo de probabilidades via `punnett_square()`;
  - Temporizador de gestação (`advance_time`, `finish_gestation`);
  - Abate cuidadoso com partes 100% Íntegras e traits cultivados;
  - Promoção a montaria própria e a reprodutor da próxima geração;
  - Serialização completa (`to_dict` / `from_dict`).
- [x] `scripts/buildable_piece.gd`:
  - Adicionado `PieceType.CERCADO_BREEDING` ao enum e `PIECE_CONFIG` (4×1.4×4m);
  - Geração procedural 3D de mourões, travessas de cerca, portão, cocho e cama de palha;
  - Instanciação de `BreedingPen` na peça;
  - Interação via `talk_to(player)` abrindo a tela `BreedingPenScreen`.
- [x] `scripts/ui/breeding_pen_screen.gd`:
  - Interface gráfica completa com status do cocho, visualizador dos reprodutores, previsão genética, barra de gestação e ações para filhotes.
- [x] `tests/test_rancho_and_breeding.gd`:
  - 9 suítes de testes unitários cobrindo todos os fluxos com 100% de sucesso.
- [x] Execução global do runner `res://tests/run_all.gd`:
  - **46/46 arquivos de teste passando (100% verde).**
