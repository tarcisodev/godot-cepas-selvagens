---
type: resource
status: active
created: 2026-10-23
updated: 2026-10-25
tags:
  - gdd
  - backlog
  - ideias
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# Ideias pendentes (backlog do Tarciso)

Ideias propostas e seu amadurecimento em notas de GDD, ADRs e blocos de execução.

---

## 1. Guilda construída pelos jogadores — Executado no [[03-Projects/Cepa-Selvagem/blocos/B26-guildas-territorio-e-heraldica|B26]] e [[03-Projects/Cepa-Selvagem/notas/GDD-15-Guildas-territorio-e-uniformes|GDD-15]]
- ✅ **Implementado (Bloco B26):** Totem de Guilda (`GuildTotem`) com raio de 40 a 80m; construção comunitária da sede Níveis 1 a 3; heráldica (cores e brasão); armário de uniformes por ocasião (Set de Gala, Set de Guerra e Equipamento Pessoal livre) com overlay de brasão na Capa (`GearVisual`); interface `GuildScreen`.

---

## 2. Quadro de missões na vila (GDD-05 §5 e GDD-03)
- Na praça da vila, um quadro de contratos dinâmicos integrados à economia e ao ecossistema:
  - **Caça Anatômica:** Abater monstros com partes específicas intactas (ligado ao GDD-03 e B23/B24).
  - **Mineração e Forja:** Encomendas de barras de ferro e quartzo-lume para a muralha da vila.
  - **Reconhecimento & Modo Foto:** Fotografar e catalogar mutações raras de plantas (GDD-04).
  - **Culinária:** Fornecer pratos e assados para o estoque da taverna ([[03-Projects/Cepa-Selvagem/notas/GDD-13-Cozinha-e-culinaria|GDD-13]]).

---

## 3. Mapa [M] — Fechado no [[03-Projects/Cepa-Selvagem/notas/GDD-11-Mapa|GDD-11]]
- Ao apertar **M**, abre mapa em estilo pergaminho baseado no relevo real do terreno (`get_height_at`).
- Sem névoa: o vale inteiro é visível; construções dos jogadores, totens e obras da vila surgem com traços leves.
- Personagem fica parado, mundo segue, tomar dano fecha o mapa.

---

## 4. Cadeia alimentar & Carniceiros — Executado no [[03-Projects/Cepa-Selvagem/blocos/B25-culinaria-espeto-e-caldeirao|B25]] e [[03-Projects/Cepa-Selvagem/notas/GDD-10-Ciclo-natural#11-cadeia-alimentar-e-carniceiros-urubus|GDD-10 §11]]
- ✅ **Implementado (Bloco B25):** Urubus voam em círculos no céu sobre carcaças no chão como farol orgânico no horizonte (`VultureFlock3D`); carcaça apodrece enriquecendo o solo com +0.80 de nutriente.

---

## 5. Montaria aquática — Resolvido no [[03-Projects/Cepa-Selvagem/blocos/B19-nado-peixes-e-pesca|B19]]
- Raia-do-Rio posicionada na margem acessível a nado.

---

## 6. Cozinha & Minigame Monster Hunter — Executado no [[03-Projects/Cepa-Selvagem/blocos/B25-culinaria-espeto-e-caldeirao|B25]] e [[03-Projects/Cepa-Selvagem/notas/GDD-13-Cozinha-e-culinaria|GDD-13]]
- ✅ **Implementado (Bloco B25):** Espeto na fogueira com minigame de timing (crua → suculenta perfeita → queimada) e buff Bem Alimentado; Caldeirão Culinário combinando bases e acompanhamentos com buffs de longa duração e qualidade derivada dos insumos.

---

## 7. Gênero, Ciclo de Vida, Casamento & Creche — Executado no [[03-Projects/Cepa-Selvagem/blocos/B27-genero-ciclo-de-vida-e-familia|B27]] e [[03-Projects/Cepa-Selvagem/notas/GDD-14-Reproducao-ciclo-de-vida-e-familia|GDD-14]]
- ✅ **Implementado (Bloco B27):**
  - Macho e fêmea com dimorfismo biológico para todos os animais e personagens (`CreatureDNA`, `CharacterDNA`).
  - 4 estágios de vida: filhote/criança (0.45×), jovem (0.75×), adulto (1.00× fértil) e idoso (0.95×).
  - Capela da Vila da Esperança (`VillageChapel`) com Altar de Votos para casamentos, divórcios e Aliança de Votos com buff *Laço de Votos* (+10% regen ao casal).
  - Gravidez canônica de 9 meses (27 dias de sol) para a jogadora, sem impedir explorações.
  - Casa da Parteira (`Mestra Clara`) com atendimento 100% gratuito.
  - Berçário da Cidade (`TownNursery`) acolhendo o recém-nascido, que cresce seguro e aprende ofícios de aprendiz pela comunidade.

---

## Log
- 2026-10-23 — Ideias registradas pelo Claude a partir de mensagem do Tarciso.
- 2026-10-23 — Item 5 resolvido no B19.
- 2026-10-24 — Item 3 virou o GDD-11 (Mapa).
- 2026-10-25 — Itens 1 (Guildas), 4 (Cadeia Alimentar & Urubus), 6 (Cozinha & Minigame) e 7 (Gênero & Família) decididos pelo Tarciso e desdobrados nos GDD-10 §11, GDD-13, GDD-14 e GDD-15.
