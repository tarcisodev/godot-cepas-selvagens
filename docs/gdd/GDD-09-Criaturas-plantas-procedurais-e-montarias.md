---
type: resource
status: active
created: 2026-10-22
updated: 2026-10-22
tags:
  - gdd
  - fauna
  - flora
  - procedural
  - montarias
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# GDD-09 — Criaturas e plantas procedurais, e montarias

> Pedido do Tarciso (2026-10-22): plantas e animais gerados por código, como os humanoides do [[08-Knowledge/decisions/ADR-0004-cepa-personagens-procedurais|ADR-0004]], e pelo menos uma montaria **terrestre**, uma **voadora** e uma **aquática**. Decisões tomadas pelo Claude como game designer; o Tarciso revisa jogando.
> Base genética: [[03-Projects/Cepa-Selvagem/notas/GDD-04-Ecologia-e-genetica|GDD-04 §1]] (alelos, dominância, mutação 3%).

---

## 1. Por que procedural

- O genoma do GDD-04 só faz sentido se **dá para ver** o gene: porte, cor, chifre, padrão da pelagem, cor da flor. Modelo pronto não muda com o gene.
- Mesmo caminho dos humanoides (B09): **um DNA pequeno e serializável** gera o mesmo bicho no cliente e no servidor (ADR-0002), sem asset novo por variação.
- Estilo: low-poly de primitivas (cápsulas, esferas, cones), coerente com o resto do jogo. Arte final fica para depois.

## 2. DNA de criatura (`CreatureDNA`)

- **Plano de corpo** (fixo por espécie): **Quadrúpede**, **Ave** ou **Peixe**.
- **Genes visíveis** (alelos do GDD-04, sorteados pela seed):
  - `porte` — dominância incompleta: TT 100% · Tt 75% · tt 50% do tamanho máximo da espécie.
  - `chifre` — dominante: C_ tem chifres/crista; cc não.
  - `padrao` — P_ listrado, pp liso (pintas aparecem só com mutação `*`).
  - Cor da pelagem/pena/escama: variação contínua em volta da cor da espécie.
- **Mutação `*`** (3%): cor iridescente e pintas — o "raro" que o jogador vai querer capturar e criar.
- **Animação procedural**: sem esqueleto; pernas balançam pela velocidade, cabeça e cauda oscilam, asas batem e planam, nadadeiras ondulam. Bicho parado respira.

## 3. DNA de planta (`PlantDNA`)

- Tipos do slice: **Árvore**, **Arbusto florido**, **Cepa Selvagem** (a planta-título: folhas recortadas em leque) e **Cogumelo-lume** (brilha à noite).
- Genes: altura, número de galhos, cor da folha, cor e número de pétalas; `porte` igual ao das criaturas.
- Plantas do mundo nascem fora da vila ([[03-Projects/Cepa-Selvagem/notas/GDD-08-Territorio-construcao-e-coleta|GDD-08]]); cultivo no canteiro usa o mesmo DNA depois (GDD-04 §3).

## 4. Espécies do slice

| Espécie | Plano | Onde vive | Comportamento | Montaria? |
|---|---|---|---|---|
| **Trotador** | Quadrúpede de chifres (cervo-cavalo) | campos do vale | rebanho, pasta, foge se você corre perto | **terrestre** |
| **Planador-de-Penacho** | Ave grande | céu e copas | voa em círculos, pousa | **voadora** |
| **Raia-do-Rio** | Peixe largo | rio | nada rio acima e abaixo | **aquática** |
| Saltarelo | Quadrúpede pequeno (coelho) | bordas da mata | pula em zigue-zague | não |
| Lambari-Brilho | Peixe pequeno | rio | cardume | não |

## 5. Montarias

- **No slice:** três montarias de teste no **Estábulo** a noroeste da vila (−15, −5) (como o Mestre de Armas no B10). A Raia fica na margem do rio. Domar de verdade vem depois: captura (GDD-03) + criadouro (GDD-04 §2).
- **Montar leva 1,5 s parado** e dano cancela — sem "moleza" que não existiria no online. **[E]** monta e desmonta.
- Montado não se ataca nem usa magia (por enquanto). Levar golpe de Postura forte derruba da montaria.

| Montaria | Passeio | Corrida (gasta fôlego) | Controles | Limite |
|---|---|---|---|---|
| Trotador | 9 m/s | 15 m/s | WASD, Shift corre, Espaço pula | só terra; não entra em água funda |
| Planador | 11 m/s | 17 m/s | WASD, Espaço sobe, Ctrl desce | teto de 40 m acima do chão; pousa ao parar perto do chão |
| Raia-do-Rio | 7 m/s | 11 m/s | WASD, Shift acelera | só na água; ao sair do rio você desmonta na margem |

- **Fôlego da montaria:** 100; corrida gasta 18/s, recupera 12/s andando ou parado. Sem fôlego, volta ao passeio.
- **Depois do slice:** montaria com genoma (porte = velocidade/carga), comida, Carga (peso do inventário) e morte da montaria na Zona Selvagem.

## 6. Perguntas para depois (não bloqueiam o slice)

1. Montaria pode lutar (investida do Trotador, mergulho do Planador)?
2. Voar sobre a Zona Selvagem expõe a quem? (risco de ser abatido do céu)
3. Montaria é item (guarda no "bolso") ou bicho que fica no estábulo/rancho?

## Log
- 2026-10-22 — Nota criada pelo Claude a pedido do Tarciso; vira o bloco [[03-Projects/Cepa-Selvagem/blocos/B13-fauna-flora-procedurais-e-montarias|B13]].
- 2026-10-22 — Implementado no B13. Planador ficou maior que o rascunho (2,2 m de corpo, 4,2 m de asa) para carregar o cavaleiro.
