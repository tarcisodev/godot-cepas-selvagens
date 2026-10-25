---
type: resource
status: active
created: 2026-10-25
updated: 2026-10-25
tags:
  - gdd
  - reproducao
  - genetica
  - familia
  - casamento
  - ecologia
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# GDD-14 — Gênero, Ciclo de Vida, Reprodução e Família

> Pedido do Tarciso (2026-10-25): sistema de gênero biológico (macho e fêmea) para todos os animais e jogadores; 4 fases da vida (criança/filhote, jovem, adulto, idoso); fêmeas engravidam e dão à luz; Capela da Vila para casamentos e divórcios de jogadores; gravidez de 9 meses da jogadora com parteira gratuita da vila; bebê acolhido na creche/cidade para crescer, trabalhar e perpetuar a árvore genealógica; substituição de assets antigos e não procedurais por modelos procedurais originais.
> Liga: [[03-Projects/Cepa-Selvagem/notas/GDD-04-Ecologia-e-genetica|GDD-04]] (genoma mendeliano), [[03-Projects/Cepa-Selvagem/notas/GDD-09-Criaturas-plantas-procedurais-e-montarias|GDD-09]] (fauna procedural), [[03-Projects/Cepa-Selvagem/notas/GDD-10-Ciclo-natural|GDD-10]] (ciclo de dias e tempo), [[08-Knowledge/decisions/ADR-0004-cepa-personagens-procedurais|ADR-0004]] (rig procedural UAL).

---

## 1. Gênero e Dimorfismo Sexual (Fauna)

Toda criatura selvagem ou domesticada (Trotador, Lobo, Tatu, Pássaro, Sapo, Peixe, Planador) nasce com um **sexo biológico**:

```gdscript
enum Gender { MALE, FEMALE }
```

- **Macho:** Geralmente porte ligeiramente maior (+5% a +10% no gene `power`), cores mais vibrantes ou chifres/cristas mais proeminentes gerados pelo shader procedural.
- **Fêmea:** Corpo adaptado à gestação; pode produzir laticínios/ovos quando alimentada ([[03-Projects/Cepa-Selvagem/notas/GDD-13-Cozinha-e-culinaria|GDD-13]]); capaz de engravidar após atingir a idade adulta.

---

## 2. As 4 Etapas do Ciclo de Vida

Tanto criaturas quanto os descendentes passam por quatro fases bem demarcadas:

```
Filhote / Criança ──► Jovem ──► Adulto ──► Idoso ──► Morte Natural
```

| Estágio | Características Físicas | Comportamento & Função |
|---|---|---|
| **1. Filhote / Criança** | Escala 0.4× a 0.5×, proporções fofas (cabeça maior, pernas curtas). | Não luta; segue a mãe; imune a dano de jogadores na vila; consome menos comida. |
| **2. Jovem** | Escala 0.75×, começa a expressar os traços e cores definitivas. | Rápido e curioso; ainda não é fértil para reprodução; no rancho pode ser adestrado. |
| **3. Adulto** | Escala 1.0×, pleno desenvolvimento muscular e genético. | **Fértil** (pode cruzar e engravidar); apto para montaria, guarda ou combate pleno. |
| **4. Idoso** | Escala 0.95×, pelos/escamas grisalhos, passos mais lentos. | Fertilidade reduzida; ao morrer de velhice devolve nutrientes e sementes ao solo ([[03-Projects/Cepa-Selvagem/notas/GDD-10-Ciclo-natural|GDD-10]]). |

---

## 3. Reprodução e Gestação da Fauna

- **Acasalamento Selvagem:** Dois adultos da mesma espécie (1 Macho + 1 Fêmea), alimentados e com nível de estresse baixo, realizam ritual de acasalamento.
- **Gestação:** A fêmea exibe o estado *Prenha/Grávida*. A gestação dura de **1 a 3 dias de jogo**.
- **Parto no Ninho/Toca:** A fêmea procura uma área segura ou ninho e dá à luz de 1 a 3 filhotes.
- **Controle Populacional:** Se a região atingir a capacidade de suporte (teto de lotação por bioma), a fertilidade entra em pausa para evitar colapso ecológico.

---

## 4. Família e Casamento de Jogadores

### 4.1 A Capela da Vila da Esperança
Um prédio sagrado/social erguido na vila:
- **Casamento:** Dois jogadores (personagem masculino e feminino) podem ir até o altar da Capela. Ambos concordam e recebem a *Aliança de Votos* (item de adorno que dá buff leve de proximidade: +5% de regeneração quando jogam juntos).
- **Divórcio:** A qualquer momento, na Capela, é possível solicitar o divórcio. As alianças são desfeitas e ambos ficam livres para novos casamentos futuros.

### 4.2 Relação Íntima e Gravidez
- Jogadores casados, descansando na mesma cama privativa ([[03-Projects/Cepa-Selvagem/notas/GDD-10-Ciclo-natural|GDD-10 §10.5]]), podem conceber um filho.
- A personagem feminina entra no estado de **Gravidez**.
- **Duração da Gestação:** **9 meses no tempo do jogo**.
  - No ciclo de dias do Cepa Selvagem, cada lunação/mês equivale a 3 dias de sol (totalizando ~27 dias de jogo / tempo real calibrado), garantindo que a gestação seja um evento memorável sem travar a jogabilidade.
  - A jogadora grávida pode continuar explorando, sem penalidades severas, com visual sutil de gestante no modelo procedural.

### 4.3 A Parteira Gratuita da Vila
- Ao completar o 9º mês de gestação, a jogadora recebe o aviso de parto iminente.
- Ela se dirige à **Casa da Parteira** na Vila da Esperança.
- O atendimento da parteira é **100% gratuito** (serviço público da vila).
- O parto é realizado com segurança em uma transição suave de cena.

### 4.4 O Berçário / Casa de Acolhimento da Cidade (Fase 1)
Para manter o foco no Action RPG e não sobrecarregar a jogadora com mecânicas pesadas de carregar bebê no meio de caçadas arriscadas:
1. O bebê recém-nascido é recebido com carinho no **Berçário da Cidade**.
2. Ele herda a combinação genética dos pais (cor de cabelo, olhos, formato do rosto via `CharacterDNA`).
3. O bebê cresce seguro na vila: passa por **Criança** (brincando na praça), **Jovem** (ajudando em pequenas tarefas de aprendiz na forja, horta ou mercado) e **Adulto** (trabalhando formalmente pela vila).
4. O jovem/adulto gerado possui sexo biológico definido, nome escolhido pelos pais e, caso seja fêmea, tem chance futura de se casar e ter seus próprios descendentes!

---

## 5. Modernização de Assets: 100% Procedurais e Originais

- **Substituição de Assets Antigos:** Todos os modelos estáticos, não otimizados ou importados de bibliotecas genéricas estão sendo progressivamente substituídos pelo motor procedural da casa:
  - Personagens humanos utilizam o **Rig UAL procedural** com meshes geradas por código ([[08-Knowledge/decisions/ADR-0004-cepa-personagens-procedurais|ADR-0004]]).
  - Fauna utiliza **Instanced Primitives + Deformers** e materiais em shaders leves (mantendo 60 fps em qualquer plataforma).
  - Árvores e vegetação utilizam os nós modulares da **Pinheira-Lume** e flora nativa do bioma.

---

## 6. Próximos Passos
- [ ] Adicionar flag `gender: Gender` e `life_stage: LifeStage` no `CreatureDNA` e no `CharacterDNA`.
- [ ] Criar a cena e NPC da **Parteira da Cidade** na Vila da Esperança.
- [ ] Adicionar o prédio da **Capela** na praça da vila com interação de casamento/divórcio.
