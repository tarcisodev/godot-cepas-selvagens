---
type: resource
status: active
created: 2026-10-22
updated: 2026-10-22
tags:
  - gdd
  - construcao
  - territorio
  - coleta
  - cidade
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# GDD-08 — Território, construção, cidade e coleta

> Onde o jogador mora, o que ele constrói e de onde vem o material comum. Esta nota nasceu **depois** do protótipo do [[03-Projects/Cepa-Selvagem/blocos/B11-cidade-construcao-e-coleta|B11]]; serve para decidir o que do protótipo fica. As propostas P1–P11 foram fechadas no §8 (com ajustes de número).

---

## 1. Por que isso existe (ligação com os pilares)

O GDD já pede um lugar para o jogador, mas não diz onde ele fica:
- **[[03-Projects/Cepa-Selvagem/notas/GDD-04-Ecologia-e-genetica|GDD-04]]** — cercados de breeding, canteiros de botânica, composteira e tanques precisam de um **rancho**.
- **[[03-Projects/Cepa-Selvagem/notas/GDD-05-Economia|GDD-05]]** — "expansão territorial e melhorias do rancho" já está na tabela como **ralo de moeda**; mercados são **locais por cidade**; Caído pode "reviver no acampamento/rancho".
- **[[03-Projects/Cepa-Selvagem/notas/GDD-06-Materiais-e-forja|GDD-06]]** — receitas têm *fixação* (madeira, fibra, couro); hoje esses insumos não têm fonte.

**Proposta central:** o Totem de Território **é** o rancho do GDD-04. Construção não é um sistema de casa decorativa: cada peça útil liga um sistema que já existe (canteiro → botânica, cercado → breeding, bancada → reparo/forja, composteira → adubo).

```
 Coleta comum ──madeira/pedra/fibra──▶ Construção ──canteiro/cercado/bancada──▶ Botânica · Breeding · Forja
      │                                     ▲                                          │
      └──fixação e tempero──▶ Forja (GDD-06) │                                          ▼
                                   Totem = Rancho ◀── manutenção em moeda (ralo, GDD-05) ── Mercado
```

---

## 2. Coleta comum

Coleta comum é a **base barata** da economia: o que se pega no chão do mundo sem combate. Material raro e com genoma continua vindo de caça (GDD-03) e cultivo (GDD-04).

| Recurso | Uso principal proposto | Onde nasce (protótipo) |
|---|---|---|
| Madeira | construção; cabo/haste em receitas | espalhado |
| Galho | cerca; combustível da forja | espalhado |
| Folha | telhado; ração vegetal | espalhado |
| Fibra | amarração (fixação) em receitas e construção | beira de rio |
| Pedra | totem, bancada; afiação/reparo | encostas |
| Frutinha | consumível leve (Vigor); ração | espalhado |
| Besouro | isca de armadilha (captura do GDD-03) | espalhado |
| Ossos | fixação de receitas; adubo | áreas de risco |
| Erva | sedativo botânico (captura); canteiro | beira de rio |
| Mel | tempero de receitas; poção | áreas de risco (abelhas: −4 Vida, −8 Vigor) |

- **Proposta P1 — vira `MaterialData`:** cada recurso ganha `MaterialData` com `category` (`wood`, `fiber`, `stone`, `bone`, `sap`…) e **qualidade 1–2** no máximo. Qualidade 3+ só via cultivo, caça ou genoma — mantém o Pilar 3 ("como você faz importa") e impede que coleta comum substitua caça.
- **Proposta P2 — sem ferramenta no slice:** coleta com as mãos; ferramentas (machado, picareta) entram depois como item forjado que reduz tempo, seguindo "o item é a classe" (ADR-0001).
- **Proposta P3 — renascimento por nó** (25–60 s, como no protótipo) só vale no slice. No servidor real o nó renasce por **ecologia** (bioma, estação), não por timer fixo — a decidir no GDD-04.

### Maestria (choque com o GDD-02)
O GDD-02 já tem `mineracao` e `botanica`. O protótipo criou `lenharia` e `coleta`.
- **Proposta P4:** **apagar `lenharia`** e criar **uma** tag nova, `coleta` (madeira, galho, folha, fibra, frutinha, besouro, ossos, mel). Pedra fica em `mineracao`; erva **colhida no mundo** fica em `coleta`, erva **cultivada** fica em `botanica`. Lista oficial passa de 11 para 12 tags.
- XP como o GDD-02 §3: só ciclo concluído; anti-macro do §6 vale igual (nó repetido rende menos).

---

## 3. Zonas do mundo

Encaixe das zonas do protótipo nas regras do GDD-05 §4:

| Zona | Combate | Construção | Morte | Exemplo no protótipo |
|---|---|---|---|---|
| **Cidade** | sem ataque (exceto duelo consensual) | proibida | Caído, sem perda | Vila da Esperança (r 16,5 m) |
| **Exploração** | PvE livre; PvP só duelo | só dentro de totem | Caído, sem perda | o resto do vale |
| **Covil** | PvE livre | proibida | Caído, sem perda | Arena de Teste, Covil da Besta |
| **Água profunda** | — | proibida | — | leito do rio |
| **Zona Selvagem** | PvP aberto, full loot | a decidir (§4) | full loot (GDD-05) | ainda não existe |

- **Proposta P5:** duelo consensual **é permitido** na cidade (o GDD-05 diz "em qualquer lugar fora de combate ativo"); o bloqueio de ataque vale só para golpe sem duelo aceito.
- Fronteira de zona com aviso no HUD (o protótipo já mostra o nome); na Zona Selvagem o aviso é obrigatório (GDD-05).

---

## 4. Território (Totem = Rancho)

- **Proposta P6 — um totem por personagem**, raio 14 m, só em zona de Exploração, sem sobrepor outro totem nem chegar a menos de X m da cidade.
- **Proposta P7 — manutenção:** o totem cobra uma taxa em Dólares de Sucata por semana de jogo (ralo do GDD-05). Sem pagamento, depois de N dias o totem fica **abandonado**: as peças viram ruína que qualquer um desmonta por parte do material.
- **Proposta P8 — segurança:** em zona de Exploração a base é **indestrutível** e só o dono (e quem ele autorizar) constrói, abre portas e usa bancadas. Cerco/invasão só existe na Zona Selvagem e fica para o ZvZ/GvG (fora de escopo).
- Caído pode reviver no totem em vez do acampamento (GDD-05 §4).

---

## 5. Construção

- [B] abre o modo; grade de 1 m; prévia verde/vermelha com o motivo do bloqueio (já no protótipo).
- Peças do protótipo e o sistema que cada uma liga:

| Peça | Custo (protótipo) | Liga em |
|---|---|---|
| Totem de Território | 4 madeira + 4 pedra | rancho (§4) |
| Piso | 2 madeira | — |
| Parede | 3 madeira + 1 fibra | — |
| Parede com porta | 4 madeira + 1 fibra | permissão de dono (§4) |
| Telhado | 2 madeira + 2 folha | — |
| Cerca | 2 galho + 1 fibra | **cercado de breeding** (GDD-04 §2) |
| Canteiro | 2 madeira + 2 erva | **botânica** (GDD-04 §3) |
| Bancada do Rancho | 4 madeira + 2 pedra | **reparo / forja** (GDD-06 §4) |

- **Proposta P9 — reembolso de 50%** ao desmontar (o protótipo devolve tudo). Desmontar vira ralo de material, como o desmanche do GDD-06.
- **Proposta P10 — peças estruturais (piso, parede, telhado) não dão bônus**; servem para proteger e organizar. Só as peças funcionais (cerca, canteiro, bancada, futura composteira e tanque) ligam sistemas.
- Faltam no catálogo: **composteira** (GDD-04 §3) e **tanque** (GDD-04 §4).
- Propostas no [[03-Projects/Cepa-Selvagem/notas/GDD-10-Ciclo-natural|GDD-10 §10]]: **Fogueira** e **Banco** (descanso público) e **Cama** (descanso do dono e ponto de renascer, ligando o §4).

---

## 6. Cidade

- A **Vila da Esperança** é a primeira cidade e o hub do slice: mercado local (GDD-05 §2), Mestre de Armas, Barbeiro, Alquimista e Mestre Construtor.
- **Proposta P11 — papel dos NPCs novos:** Alquimista compra/vende ervas e ensina o sedativo da captura; Mestre Construtor vende o Totem como "escritura" e explica as regras de território. Sem quests longas.
- NPCs da cidade usam `CharacterDNA` sorteado pela seed (próximo passo do [[03-Projects/Cepa-Selvagem/blocos/B09-gerador-procedural-de-personagens|B09]], depende da ADR-0004).
- Jogador **não constrói** na cidade.

### 6.1 Obras da Vila (decidido em 2026-10-22, pedido do Tarciso)
A vila **começa em obras** e cresce com o material que os jogadores doam. É o primeiro ralo coletivo de material comum e dá motivo para coletar além do próprio rancho.

- **Projetos da vila**, todos abertos ao mesmo tempo; cada um tem 3 etapas — **Fundação → Estrutura → Acabamento**. Cada etapa pede uma lista de materiais comuns da coleta.
- **Doação:** no **Quadro de Obras**, ao lado do Mestre Construtor ([E]). Doa-se por material ou "tudo o que falta e eu tenho". Qualidade não pesa: 1 unidade = 1 unidade, e a doação gasta a **pior** qualidade primeiro (ADR-0005).
- **Etapa completa = a vila muda na hora:** sai o canteiro (estacas, caixotes) → piso de pedra → paredes com andaime → prédio pronto (telhado, porta, chaminé). No servidor real a etapa pode levar horas de jogo; no slice é imediato.
- **Recompensa:** a função do prédio é o prêmio de todos. Quem doa ganha **Reputação da Vila** (1 por unidade), guardada para descontos e títulos no futuro; o quadro mostra quanto você já doou.
- **Projetos do slice e para que servem:**

| Projeto | Fundação | Estrutura | Acabamento | Destrava (quando houver) |
|---|---|---|---|---|
| Poço da Praça | 8 pedra | 10 pedra · 2 madeira | 4 madeira · 4 fibra | água para cultivo e cura |
| Paliçada | 10 galho · 6 fibra | 8 madeira · 10 galho | 6 madeira · 6 pedra · 6 fibra | defesa da vila |
| Mercado | 6 pedra · 4 madeira | 10 madeira · 4 fibra | 10 folha · 6 fibra · 4 madeira | ordens de compra e venda (GDD-05 §2) |
| Forja Pública | 10 pedra | 8 pedra · 6 madeira | 4 ossos · 6 madeira | forja e reparo na cidade (GDD-06) |
| Taverna | 10 pedra · 6 madeira | 14 madeira · 6 fibra | 12 folha · 2 mel · 6 frutinha | mesa do jogo de cartas (GDD-07) |

- **Rede (ADR-0002):** o progresso das obras é **um só para o servidor inteiro**; o servidor valida a doação. No slice fica no save local.
- **NPCs:** Alquimista, Mestre Construtor e trabalhadores usam `CharacterDNA` com animação (sem modelo pronto em T-pose); trabalhadores aparecem nas obras em andamento.

---

## 7. Persistência e rede

- No slice: totem e peças entram no `SaveGame` local (hoje somem ao recarregar).
- Com servidor (ADR-0002): o servidor valida custo, zona e dono antes de criar a peça; o cliente só mostra a prévia.

---

## 8. Decisões (2026-10-22)

Respondidas pelo Claude no papel de game designer, **a pedido do Tarciso** ("responda por mim"). O Tarciso pode revogar qualquer uma; até lá valem como fechadas.

| # | Pergunta | Decisão | Por quê |
|---|---|---|---|
| 1 | Totem = rancho? | **Sim.** O totem é o rancho do GDD-04; um só lugar para cercado, canteiro, bancada, composteira e tanque. | Evita dois sistemas de "casa". Construção ganha propósito em vez de virar decoração que infla o jogo. |
| 2 | Tags de maestria | **Apagar `lenharia`; criar só `coleta`.** Pedra em `mineracao`; erva do mundo em `coleta`, erva cultivada em `botanica`. Lista oficial: 12 tags. | O GDD-02 escolheu poucas tags fortes. Cortar madeira não pede identidade própria. |
| 3 | Qualidade da coleta comum | **Teto de 2 estrelas.** Sai 1★; chance de 2★ a partir de `coleta`/`mineracao` 25. | Mantém o Pilar 3: material bom vem de caçar e cultivar bem, não de catar no chão. |
| 4 | Ferramentas | **Só mãos no slice.** Machado e picareta entram depois como itens forjados que cortam o tempo de coleta (sem ganho de qualidade). | Uma coisa por vez. Ferramenta forjada encaixa no "o item é a classe" quando a forja crescer. |
| 5 | Duelo na cidade | **Permitido.** Fora de duelo aceito, ninguém ataca na cidade. A aposta segue o GDD-05 (até 10%). | O GDD-05 já diz "em qualquer lugar"; a praça vira palco social. |
| 6 | Quantos totens | **1 por personagem**, raio 14 m. Precisa ficar a **≥ 20 m da borda da cidade** e a **≥ 6 m da borda de outro território**. Mudar de lugar = desmontar o totem. | No mapa de 180 m, 20 m guarda a entrada da vila livre e 6 m impede bases coladas. |
| 7 | Manutenção | **Sim, em Dólares de Sucata, cobrada a cada 7 dias reais**, com a 1ª semana grátis. Sem pagar por **14 dias reais**, o totem fica abandonado e as peças viram ruína que qualquer um desmonta por 25% do material. Só entra quando houver moeda no jogo. | Ralo de moeda previsto no GDD-05 que também limpa bases mortas. Dias reais e não de jogo, porque a duração do dia de jogo ainda vai mudar no online (GDD-10 §10). |
| 8 | Base indestrutível fora da Zona Selvagem | **Sim.** Só o dono (e quem ele autorizar) constrói, desmonta, abre portas e usa bancadas e baús. | Zona de exploração é segura no GDD-05. Cerco é conteúdo de ZvZ, fora de escopo. |
| 9 | Reembolso ao desmontar | **50%.** Mas desmontar até **2 min depois de colocar** devolve **100%**. | O 50% é ralo de material; a janela de 2 min perdoa erro de posição, sem punir quem está aprendendo. |
| 10 | Construção na Zona Selvagem | **Proibida por enquanto.** Volta à mesa junto com o ZvZ/GvG. | Construção cercável exige regras de cerco e de rede que ainda não existem. |

### O que muda no código do B11
- [x] `MasteryComponent`: tirar `lenharia`; madeira passa a dar XP de `coleta`.
- [ ] Coleta gera material 1★ (2★ por chance com maestria ≥ 25) — exige `MaterialData` e um inventário com qualidade (hoje é só contagem por id).
- [x] `ZoneManager`: permitir golpe em duelo aceito na cidade; totem a ≥ 20 m da borda da cidade e ≥ 6 m de outro território; limite de 1 totem por dono; proibir construção na Zona Selvagem quando ela existir.
- [x] `BuildingSystem`: reembolso de 50% com janela de 100% nos 2 primeiros minutos; um só catálogo de peças (tirar a duplicação com `BuildablePiece`).
- [x] `SaveGame`: salvar totem e peças.
- [ ] Manutenção (P7) fica só no papel até existir moeda.

---

## Log
- 2026-10-22 — Rascunho criado pelo Claude a partir do protótipo do B11 e dos GDD-02/04/05/06; 11 propostas e 10 perguntas aguardando o Tarciso.
- 2026-10-22 — As 10 perguntas foram respondidas pelo Claude como game designer, a pedido do Tarciso; decisões e mudanças de código no §8. Nota passa a `active`.
