---
type: resource
status: active
created: 2026-10-22
updated: 2026-10-25
tags:
  - gdd
  - ecologia
  - clima
  - simulacao
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# GDD-10 — Ciclo natural: água, clima, solo, plantas e bichos

> Pedido do Tarciso (2026-10-22): "chegar mais perto do ciclo natural da vida" — o sol esquenta rio e mar, a umidade sobe, vira nuvem e depois chuva; plantas crescem quando têm nutriente (e isso pode indicar mutação); tudo nasce, cresce, reproduz e morre; árvores dão flor, fruto e semente; bichos comem capim e frutinha e bebem no rio. Decisões do Claude como game designer; o Tarciso revisa jogando.
> Liga: [[03-Projects/Cepa-Selvagem/notas/GDD-04-Ecologia-e-genetica|GDD-04]] (genoma, adubo), [[03-Projects/Cepa-Selvagem/notas/GDD-09-Criaturas-plantas-procedurais-e-montarias|GDD-09]] (DNA procedural).

---

## 1. Princípio

Simulação **barata e legível**, não científica: poucos números por região, atualizados devagar (a cada 2 s de jogo), que o jogador **vê** (nuvem, chuva, broto, flor, fruto, bicho bebendo). Roda no servidor (ADR-0002); o cliente só desenha. Relógio: o dia do jogo (5 min reais).

## 2. Água e clima (o ciclo da água)

| Grandeza | Sobe com | Desce com |
|---|---|---|
| **Calor** | sol (pico ao meio-dia) | noite, nuvens (−60% com céu fechado) |
| **Umidade do ar** | calor × área de água (rio, lagoa) — evaporação | condensação em nuvem |
| **Nuvens** (0–1) | umidade acima de 60% condensa | chuva, vento (dissipa devagar) |
| **Chuva** (0–1) | nuvem acima de 70% chove | esvazia a nuvem |

- O jogador vê: céu e luz escurecendo com as nuvens, camada de nuvens que se move com o vento, chuva caindo, névoa leve na chuva.
- Chuva **molha o solo** de todo o vale; perto do rio o solo fica sempre úmido.
- **Cheia e vazão** (pedido do Tarciso): a chuva escorre para o rio e sobe o nível até 1,4 m; acima de 0,45 m a água passa do barranco e alaga a várzea; a vazão esvazia ~1,5% a cada 2 s (cheia some em ~1,5 dia). Na cheia a correnteza acelera, a espuma aumenta e a água fica barrenta.

### 2.1 Lua (pedido do Tarciso)
- Ciclo de **28 dias de jogo** (nova → crescente → quarto → gibosa → cheia → …). A lua fica no céu na posição da fase (nova junto do sol, cheia oposta), então a fase visível sai certa.
- O **luar** clareia a noite conforme a fase: lua nova quase escuro, lua cheia azul-claro.
- Na lua cheia as plantas também crescem de noite, a 30% da taxa do dia.
- A fase aparece no HUD ao lado da hora.
- Ciclo típico: manhãs claras → à tarde o calor sobe a umidade → nuvens no fim da tarde → chuva à noite ou no dia seguinte. Não é roteirizado: sai dos números.

## 3. Solo (grade de 6 m)

Cada célula guarda **Umidade** (0–1) e **Nutrientes** (0–1).
- Umidade: + chuva, + vizinhança do rio; − calor (evapora), − plantas que bebem.
- Nutrientes: − plantas que crescem; **+ planta ou bicho que morre e apodrece ali**; + adubo (GDD-04 §3, depois).
- A célula tem **lotação**: nascem no máximo N plantas por célula (evita tapete infinito).

## 4. Plantas: nasce, cresce, reproduz, morre

```
Semente → Broto → Jovem → Adulta → Florida → Com fruto → (fruto cai: semente) → … → Velha → Morre → nutriente
```
- **Crescer** pede umidade e nutriente da célula (e luz: só de dia). Faltou água ou nutriente: para de crescer e definha; muito tempo assim, morre.
- **Árvore e arbusto:** florescem, dão fruto (aparece na planta), o fruto **cai** e vira **Frutinha coletável** no chão; parte das sementes brota em volta se a célula tiver lugar.
- **Cepa e ervas:** florescem e soltam semente direto.
- **Mutação (pedido do Tarciso):** a semente herda o DNA da mãe; a chance de mutação sobe com o **excesso de nutriente** onde ela brota — solo muito rico (adubado, onde morreu bicho) é berço de cepa rara. Base 3% (GDD-04), até **12%** em solo saturado.
- Ciclo de referência: erva/Cepa adulta em ~1 dia de jogo; arbusto em ~3; árvore em ~6, vive ~20.

## 5. Bichos: comer, beber, reproduzir, morrer

- **Fome** e **Sede** sobem com o tempo. Com fome, o bicho procura comida: quadrúpede pasta (capim está em toda parte) ou come **fruto caído/arbusto** (gasta a planta); ave come fruto nas árvores. Com sede, vai até a **margem do rio** e bebe (animação de cabeça baixa).
- **Reprodução:** dois adultos da mesma espécie, alimentados, perto um do outro → filhote com `CreatureDNA.cross` (mutação 3%, GDD-04). Filhote cresce até adulto em ~2 dias.
- **Morte natural:** velhice (~15 dias) ou fome/sede sem achar recurso. O corpo apodrece e **devolve nutriente** ao solo (e pode ser esfolado enquanto fresco).
- **Lotação por espécie** no vale para não explodir a população.

## 6. Fora do slice (depois)
- Estações do ano, temperatura por altitude, neve no pico.
- Mar e marés (o mapa ainda não tem mar; a evaporação vem do rio e da lagoa).
- Predadores comendo herbívoros; doenças.
- Salvar o ecossistema inteiro (no slice, plantas e bichos novos não entram no save; o vale renasce ao carregar).

## 7. Nado e mergulho (B19, pedido do Tarciso)
- Água mais funda que **1,2 m** faz o personagem **nadar**: o corpo boia na linha d'água com a cabeça para fora. No raso continua andando.
- **Correnteza:** 0,45 m/s rio abaixo, dobra na cheia. Parado na água, você é levado.
- **Shift** nada mais rápido gastando **Vigor**. Na água não há golpe, bloqueio nem esquiva; a arma e o escudo ficam guardados.
- **Mergulho:** Ctrl desce, Espaço sobe; parado embaixo d'água, o corpo sobe devagar.
- **Fôlego:** 30 s com a boca embaixo d'água (barra azul que só aparece quando não está cheia). Zerado, **afoga**: perde 8 de Vida por segundo até subir. Com a cabeça fora, recupera 10 s de fôlego por segundo.
- Câmera embaixo d'água ganha um véu azul; a superfície do rio aparece vista de baixo.
- A Raia-do-Rio montável fica encostada na margem do lado da vila: dá para montar da beira ou nadando até ela.

## 8. Peixes e pesca (B19, pedido do Tarciso)
**Peixes procedurais** (mesmo `CreatureDNA` dos outros bichos; o cardume antigo de enfeite saiu):

| Peixe | Tamanho (TT) | Onde | Comportamento |
|---|---|---|---|
| Lambari-Brilho | 0,32 m | rio de baixo, em cardumes de 4 | perto da superfície, rabo laranja e faixa prateada |
| Traíra-do-Remanso | 0,62 m | remansos do rio de baixo e da serra | quieta no fundo |
| Dourado-da-Cachoeira | 0,95 m | poço da cachoeira | meia-água, rápido |

Todos fogem de quem chega perto (nadando ou pisando no raso), não passam pela cachoeira e o vale repõe a população mínima 90 s depois que um sai.

**Pesca:**
- **Vara de Pesca** = 3 Galho + 4 Fibra (menu de ações). É ferramenta da roda rápida e não gasta.
- Com a vara selecionada, **[G] lança** a boia até 7 m à frente, na água. Só com os pés no chão (margem ou raso).
- A boia **atrai um peixe de verdade** do rio num raio de 9 m. Sem peixe por perto, nada morde: mude de ponto.
- Espera de 6–14 s. **Besouro** na mochila vira isca (gasta 1, espera −40%); alvorada e entardecer −30%; chuva −20%.
- A boia afunda: **clique em até 1 s** para fisgar, senão o peixe leva a isca.
- **Briga:** segurar o clique recolhe e estica a linha; soltar afrouxa. O peixe dá puxões que esticam de repente (Dourado puxa mais forte). Tensão cheia **arrebenta a linha**; frouxa por 2,5 s **o peixe escapa**.
- Pescou: o peixe sai do rio e vira item. Qualidade pelo porte: tt 1★, Tt 2★, TT 3★, mutante +1★ com o trait `mutante`. XP em `coleta` (sem tag nova, como no GDD-08).
- Peixes são comida: Lambari +8 Vigor, Traíra +20, Dourado +35. Valem 2 / 6 / 18 $S.
- Andar, nadar, montar ou levar dano recolhe a linha. Nada desacelera o tempo.

## 9. Pinheira-Lume (B20, pedido do Tarciso)
Árvore parecida com a araucária, que **brilha no escuro** e dá **Pinhas-Lume** cheias de **Pinhões-Lume** (a semente). Cada pinhão leva o genoma da árvore que vai nascer: a cor da luz, o formato da copa e o desenho da pinha mudam de uma árvore para outra.

**Genes** (mesmo esquema de alelos do GDD-04):

| Gene | Alelos | O que se vê |
|---|---|---|
| `porte` | T/t (já existe) | altura de 9 a 14 m |
| `copa` | T taça > C cone > H chorona; `*` espiral (só por mutação) | taça = araucária adulta (galhos só no alto, pontas para cima); cone = verticilos ao longo do tronco; chorona = pontas caídas; espiral = verticilos girando no ângulo de ouro |
| `brilho` | B/b, dominância incompleta | BB forte, Bb médio, bb fraco (luz e emissivo) |
| `lume` | matiz contínuo 0–1 | cor da luz; o filho mistura os pais (±0,03); mutação sorteia uma cor nova |
| `forma` | F > f | F_ pinha **Fibonacci** (escamas em espiral no ângulo de ouro, 137,5°) · ff pinha **mandala** (anéis com simetria radial) |
| `simetria` | 5–12 | número de pétalas/escamas por anel da mandala |
| `escamas` | 21 / 34 / 55 | quantas escamas a pinha Fibonacci tem (números de Fibonacci) |
| `verticilos` | 3–7 | andares de galhos |

**Ciclo** (dias de jogo, 1 dia = 5 min):
- Pinhão plantado → **broto aparece depois de 2 dias** → broto 1,5 → jovem 3 → adulta 1,5 → florida 1 → com pinhas 1,5. Primeira safra em ~9 dias; depois uma a cada ~4 dias. Vive 40 dias.
- Precisa de água, nutriente e luz como as outras plantas (§4).
- **Pólen pelo vento:** na hora da safra, o pai é a Pinheira adulta mais perto num raio de 30 m; sem nenhuma, autopolinização. Por isso duas árvores diferentes lado a lado dão filhos que misturam as duas.
- Cada safra solta **2 a 4 pinhas** a 2–6 m do tronco. Os pinhões de uma mesma pinha são gêmeos (mesmo genoma); pinhas diferentes da mesma safra podem ter pais e genes diferentes.
- **Pinha esquecida no chão brota:** depois de 1,5 dia parada, planta um pinhão ali (se a célula de solo tiver lugar) e o resto apodrece em nutriente.
- A mutação continua sendo sorteada **onde a semente brota** (3% a 12% pelo nutriente, §4).
- Máximo de **36 Pinheiras** no vale (cada uma acende uma luz à noite).

**Bichos espalham as sementes:**
- Trotador e Saltarelo comem pinha caída; o Planador come pinha no pé (a árvore perde a safra).
- O pinhão fica na barriga **0,4 dia** e sai onde o bicho estiver: um **montinho de esterco** (some em 1 dia, +0,1 nutriente na célula) e, com 70% de chance, a semente cai ali. Solo adubado pelo esterco puxa a chance de mutação para cima.
- O Planador solta a semente voando: ela cai no chão embaixo dele. Assim nascem Pinheiras longe da mãe.

**Jogador:**
- **[E] na pinha caída:** abre e dá **3 a 5 Pinhões-Lume** (XP de coleta).
- **[E] no tronco de uma Pinheira com pinhas:** sacode e derruba 2 pinhas; a árvore volta a adulta.
- **Plantar:** o Pinhão-Lume é ferramenta da roda rápida; **[G] planta** 1,5 m à frente, em terra firme e fora d'água. Dentro da vila só num **Canteiro de Cultivo** (solo regado e adubado: umidade e nutriente fixos em 0,7). A tela de inventário escolhe qual pinhão (qual genoma) a roda planta.
- O inventário mostra o genoma no lugar dos traits (ex.: "Copa taça · Lume azul · Pinha Fibonacci 34 · Brilho forte"). Pinhões com o mesmo genoma empilham (ADR-0005). Mutante é 3★, comum 1★. Vale 3 $S.

**Crescer à vista (2026-10-24, pedido do Tarciso):** a Pinheira cresce aos poucos dentro de cada etapa, sem pular. O broto sobe de 13 cm a 60 cm, e a jovem sai do chão com ~75 cm e chega aos 12 m da adulta. Na troca de etapa, a malha velha encolhe enquanto a nova cresce (0,7 s) e sobem faíscas na cor do lume; quando o tamanho não muda (adulta → florida → pinhas), a árvore só "respira". Ela só cresce de dia, então do pinhão às pinhas levam ~1h30 reais. O servidor manda etapa e progresso; o cliente desenha o meio-termo.

**Brilho:** à noite (e com céu fechado) as pontas dos galhos e as pinhas acendem na cor do `lume`; a árvore adulta lança uma luz de até 8 m. Jovem brilha fraco; o broto é um botãozinho aceso.

## 10. Relógio do mundo e Descansar (aceito pelo Tarciso em 2026-10-24; execução no [[03-Projects/Cepa-Selvagem/blocos/B22-relogio-unico-e-descansar|B22]])
> Pergunta do Tarciso: o "Esperar" avança o jogo inteiro ou só o sol? Hoje só o sol (e anda para trás depois da meia-noite). Decisão: **o tempo do mundo nunca pula**; Esperar sai e vira **Descansar**, que mexe só no personagem. Ver [[08-Knowledge/decisions/ADR-0006-cepa-relogio-unico-sem-pulo|ADR-0006]] (accepted).

### 10.1 Relógio único
- Um relógio só, no servidor (ADR-0002): hora, dia corrido e fase da lua. **Nenhuma ação de jogador adianta, pausa ou desacelera esse relógio**, nem no host local. O solo e o servidor seguem a mesma regra (sem moleza de single-player).
- Tudo que conta tempo de natureza lê **esse** relógio, nunca uma constante própria: sol, solo, plantas, bichos (fome, sede, idade), pinha brotando, fruta e esterco apodrecendo, clima, caravana do Mercado. Assim, mudar a duração do dia muda tudo junto.
- Os tempos do GDD ficam escritos em **dias de jogo** (árvore adulta em ~6 dias, bicho vive ~15). O que é cobrança ou compromisso do jogador fica em **dias reais** (manutenção do totem, GDD-08 §7).
- A noite não se pula: ela é curta e tem o que fazer (tocha, Pinheira-Lume acesa, peixe que morde no entardecer, lua cheia fazendo planta crescer).

### 10.2 Descansar
Substitui o botão **Esperar** do menu de ações. **Sentar** (já existe) e **deitar na cama** são descansar.

| Onde | Vida volta | Dá "Descansado"? |
|---|---|---|
| Chão, em qualquer lugar | 0,5% da Vida máx./s (~3 min do zero ao cheio) | Não |
| A até 4 m de uma **Fogueira** acesa ou sentado num **Banco** | 2%/s (~50 s) | Sim, depois de 60 s |
| Deitado na sua **Cama** | 3%/s (~35 s) | Sim, depois de 60 s |

- **Fora de descanso a Vida não volta sozinha** (como hoje). Só Vigor, Éter e Postura voltam em pé. Por isso descansar e comer importam.
- **Interrompe:** andar, atacar, lançar magia, levar dano, montar, entrar na água. Não começa se você deu ou levou dano há menos de 10 s.
- O mundo segue rodando: bicho pode chegar, outro jogador pode passar. Descansar no mato é um risco; num abrigo é mais seguro.
- Fogueira e banco são **de uso público**: qualquer jogador descansa na fogueira de outro. É um ponto de encontro. A cama é só do dono.
- A vila (acampamento) tem uma fogueira pública.

### 10.3 Descansado (buff)
- Depois de **60 s** descansando em fogueira, banco ou cama, você ganha **Descansado** por **15 min reais**: **+25% na volta de Vigor e Éter**.
- É um modificador na pilha única (fonte `descanso`, ADR-0003). Não acumula; descansar de novo renova o tempo.
- Some se você ficar Caído.

### 10.4 Cama = ponto de renascer
- Deitar na **sua** cama (dentro do seu totem, GDD-08) marca ela como lugar de renascer. Só uma cama marcada por personagem.
- Caído volta para a cama marcada. Se ela foi desmontada ou o totem foi abandonado, volta ao acampamento da vila.

### 10.5 Peças novas (catálogo do GDD-08)
| Peça | Custo (proposta) | Onde |
|---|---|---|
| Fogueira | 4 Pedra + 3 Galho | dentro do totem |
| Banco | 3 Madeira | dentro do totem |
| Cama | 4 Madeira + 4 Fibra | dentro do totem; 1 por personagem |

### 10.6 Perguntas em aberto
1. **Duração do dia no online** (escolha do Tarciso: "mais longo no online"). Hoje 1 dia = 5 min reais, bom para testar. No servidor pode ir a 1–2 h. Com 2 h, árvore adulta leva ~12 h reais e bicho vive ~30 h; plantas e bichos podem precisar de taxas próprias para não ficarem lentos demais. Decidir num playtest com o servidor.
2. **Fogueira fora do totem** (fogueira de viagem, que some sozinha depois de um tempo)? Hoje as peças funcionais são pensadas dentro do totem (GDD-08 §4–§5).
3. Descansado deve dar também XP ou "descanso" de maestria? Proposta: não, só Vigor e Éter, para não inflar.

### 10.7 O que muda no código (B22)
- Tirar o **Esperar** do menu de ações (`actions_menu.gd`); o botão vira Descansar (sentar).
- Relógio único: `WildCreature.DAY_SECONDS` e os timers de fruta e esterco passam a ler a duração do dia do relógio, como a `Ecology` já faz.
- `PoolsComponent`: volta de Vida quando descansando, com a taxa do lugar.
- Buff Descansado no `StatsComponent`.
- Peças Fogueira, Banco e Cama no `BuildablePiece`; `spawn_point` do jogador vem da cama marcada (save).
- Fogueira pública na vila.

## 11. Cadeia Alimentar e Carniceiros (Urubus)

> Pedido do Tarciso (2026-10-25): predadores caçam herbívoros de verdade; carcaças no chão atraem urubus sobrevoando em círculos como farol orgânico no horizonte; carcaças decompõem nutrindo o solo.

### 11.1 Predação Real no Ecossistema
- Predadores carnívoros (como o [[03-Projects/Cepa-Selvagem/notas/GDD-12-Equipamento-e-encaixes|Lobo-do-Ermo]]) monitoram herbívoros próximos quando sua Fome atinge nível crítico.
- O ataque do predador é uma caçada real: persegue a presa, causa dano e a abate.
- Ao matar a presa, o predador alimenta-se no local até saciar a fome, deixando o restante como **Carcaça Fresca**.

### 11.2 Urubus como "Farol Natural" no Horizonte
- Enquanto houver uma carcaça com carne ou restos no chão, o sistema atrai **2 a 4 Urubus procedurais** no céu diretamente acima do ponto da carcaça.
- **Voo em Círculos:** Os urubus voam em espiral contínua a 15–25 m de altura.
- **Sinalizador Visual:** O jogador que olha o horizonte vê os urubus circulando de longe e sabe: ali aconteceu uma caçada, há carcaça para esfolar ou predadores rondando.
- Se nenhum jogador ou predador estiver a menos de 10 m, os urubus pousam para bicar a carcaça.

### 11.3 Ciclo de Decomposição e Adubo do Solo
- **Estágio 1 — Fresca (0 a 3 min de jogo):** Esfolável para carnes, couros e ossos nobres com qualidade total.
- **Estágio 2 — Consumida / Carniceiros (3 a 8 min):** Carne quase toda consumida pelos urubus; ainda rende ossos e carapaças.
- **Estágio 3 — Ossadas / Solo Nutrido (8 min+):** A carcaça desaparece e transfere **+0.8 de Nutrientes** para a célula de 6 m do solo ([[03-Projects/Cepa-Selvagem/notas/GDD-10-Ciclo-natural#3-solo-grade-de-6-m|§3]]). É o local perfeito onde a chance de mutações de sementes atinge o ápice de 12%.

## Log
- 2026-10-22 — Nota criada pelo Claude a pedido do Tarciso; vira o bloco [[03-Projects/Cepa-Selvagem/blocos/B15-ciclo-natural|B15]].
- 2026-10-22 — Implementado no B15 com cheia/vazão, lua de 28 dias e mapa de 360 m (pedidos do Tarciso durante o trabalho).
- 2026-10-23 — §7 (nado, mergulho e fôlego) e §8 (peixes e pesca) adicionados no B19, a pedido do Tarciso.
- 2026-10-23 — §9 (Pinheira-Lume) adicionada e implementada no [[03-Projects/Cepa-Selvagem/blocos/B20-pinheira-lume|B20]], a pedido do Tarciso.
- 2026-10-24 — §10 (relógio único e Descansar) em rascunho. O Tarciso decidiu: o tempo nunca pula; descansar dá Vida, buff Descansado e cama como renascer; em qualquer lugar, melhor em abrigo; dia mais longo no online. Os números são do Claude. ADR-0006 proposed.
- 2026-10-24 — O Tarciso aceitou a ADR-0006 e os números do §10. A execução fica no B22; as perguntas do §10.6 continuam em aberto e não travam o bloco.
- 2026-10-24 — §9: crescimento contínuo e troca de etapa suave da Pinheira (Claude, pedido do Tarciso).
- 2026-10-25 — §10 implementado no B22 (Claude): relógio único, fim do Esperar, Descansar, buff Descansado, Fogueira/Banco/Cama e cama como renascer.
- 2026-10-25 — §11 (cadeia alimentar, predação, urubus carniceiros como farol visual e decomposição nutritiva) adicionado a pedido do Tarciso.
