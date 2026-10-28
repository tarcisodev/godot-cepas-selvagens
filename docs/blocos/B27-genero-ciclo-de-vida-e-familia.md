---
type: block
status: active
created: 2026-10-25
updated: 2026-10-25
tags:
  - bloco
  - godot
  - reproducao
  - ciclo-de-vida
  - familia
  - casamento
  - capela
  - bercario
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B27 — Gênero, Ciclo de Vida 4 Fases, Capela da Esperança, Gravidez e Berçário

## Objetivo
Implementar o sistema biológico completo de **Gênero (Macho e Fêmea)** para fauna e humanoides, as **4 Fases do Ciclo de Vida** (Filhote/Criança, Jovem, Adulto e Idoso), **Gestação e Parto da Fauna**, a **Capela da Vila da Esperança** com Altar de Votos (casamentos, divórcios e Aliança de Votos com buff *Laço de Votos* +10% regen), a **Gravidez Canônica de 9 Meses (27 dias)** para a jogadora, **Parto Gratuito com a Parteira Mestra Clara** e o acolhimento seguro dos recém-nascidos no **Berçário da Cidade**, atendendo integralmente ao [[03-Projects/Cepa-Selvagem/notas/GDD-14-Reproducao-ciclo-de-vida-e-familia|GDD-14]].

---

## Pilares Técnicos e Arquitetura

### 1. Gênero Biológico e 4 Fases da Vida (`CreatureDNA` & `CharacterDNA`)
- **Enums Compartilhados:**
  ```gdscript
  enum Gender { MALE, FEMALE }
  enum LifeStage { BABY, JUVENILE, ADULT, ELDER }
  ```
- **Escalação Procedural por Estágio (`stage_scale()`):**
  - `BABY`: Escala 0.45× (proporções fofas, filhote/criança protegida).
  - `JUVENILE`: Escala 0.75× (jovem ágil, aprendiz de ofícios).
  - `ADULT`: Escala 1.00× (maturidade plena e fertilidade reprodutiva).
  - `ELDER`: Escala 0.95× (indivíduo experiente).
- **Dimorfismo Sexual:** Machos possuem porte ligeiramente superior (+5% a +10%), e fêmeas são fisiologicamente aptas para a gestação.
- **Herança Genética Familiar (`cross`):** Cruzamento de pais gera filhotes no estágio `BABY` com recombinação determinística de fenótipo (pele, olhos, cabelos, estatura, formato do queixo/nariz).

### 2. Reprodução e Gestação da Fauna Selvagem (`WildCreature` & `EcosystemSpawner`)
- **Acasalamento Biológico:** 1 Macho Adulto + 1 Fêmea Adulta alimentados e próximos iniciam o processo reprodutivo.
- **Gestação Animal (`start_pregnancy`):** Fêmea entra em gestação (`is_pregnant = true`, `mate_dna`), durando 0.8 a 1.0 dias de jogo.
- **Parto Procedural (`give_birth`):** Ao concluir o período, gera o filhote no estágio `BABY` escalonado a 0.45×, que acompanha a fauna e cresce organicamente pelos dias até se tornar adulto.

### 3. Capela da Vila da Esperança e Matrimônio (`VillageChapel` & `MarriageScreen`)
- **Edificação Sagrada Comunitária:** Prédio 3D com torre sineira móvel, base de pedra, pilares rústicos de madeira e Altar de Votos com iluminação de velas.
- **Interface Interativa do Altar (`MarriageScreen`):**
  - Lista de cidadãos e pretendentes da comunidade (`Ayla`, `Breno`, `Elena`, `Dario`, `Mirela`, `Cassio`) ou inscrição personalizada de outros jogadores.
  - Votos Sagrados concedem a **Aliança de Votos** (`resources/materials/alianca_votos.tres`).
  - Divórcio Amigável a qualquer momento sem penalidades, dissolvendo os laços e liberando o jogador para novos matrimônios.

### 4. Aliança de Votos & Buff "Laço de Votos" (`FamilyComponent`)
- **Componente Familiar do Jogador (`FamilyComponent`):** Gerencia estado civil, árvore genealógica de filhos, parceiro e progresso gestacional.
- **Buff de Proximidade (ADR-0001 / ADR-0003):** Quando o casal explora junto ou está no mesmo perímetro com a aliança no inventário, ativa via `ModifierData`:
  - `+10% Regeneração de Vida` (`health_regen`)
  - `+10% Regeneração de Vigor` (`vigor_regen`)
- Ao se afastar, o modificador é removido automaticamente do `StatsComponent`.

### 5. Gestação da Jogadora e Parto Gratuito da Parteira (`TownNursery` & `NurseryScreen`)
- **Gestação de 9 Meses (27 Dias de Sol):**
  - Concebida ao descansar com o cônjuge em cama ou acampamento.
  - A jogadora grávida pode continuar suas explorações normalmente sem travar o gameplay.
  - Acompanhamento pelo painel com barra de progresso dos 9 meses.
- **Casa da Parteira (Mestra Clara):**
  - Atendimento **100% gratuito** como serviço público da Vila da Esperança.
  - Ao atingir 27 dias (`is_labor_ready`), o parto é realizado com segurança.
- **Berçário da Cidade (Acolhimento da Criança):**
  - O bebê não precisa ir para zonas perigosas de caça; ele fica protegido no berçário comunitário com berços e brinquedos.
  - Registro de linhagem (Nome, Pai, Mãe, DNA herdado).
  - Com o passar do tempo (`advance_children_days`), a criança evolui para **Jovem Aprendiz** (ajudando em ofícios de horta, forja, culinária e pesca) e depois **Cidadão Pleno Adulto**.

---

## Verificação e Testes
- Suíte dedicada em `tests/test_life_cycle_and_family.gd`:
  1. `test_creature_dna_stages()`: Valida escalas de 0.45 a 1.0, dimorfismo e fertilidade por estágio.
  2. `test_character_dna_stages_and_cross()`: Valida cruzamento humanoide e herança de pais.
  3. `test_wild_creature_pregnancy_and_birth()`: Valida acasalamento macho/fêmea, gestação animal e nascimento de filhotes.
  4. `test_vows_ring_and_marriage()`: Valida casamento, entrega da aliança e ativação do buff Laço de Votos (+10% regen).
  5. `test_player_pregnancy_and_nursery()`: Valida 9 meses (27 dias), parto com Mestra Clara e progressão de idade no berçário.
  6. `test_town_chapel_and_nursery_stations()`: Valida instanciação 3D e grupos talkable da Capela e Berçário.
- Todos os 40 testes automatizados passam com sucesso no test runner headless unificado.
