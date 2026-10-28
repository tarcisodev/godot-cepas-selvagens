---
type: resource
status: active
created: 2026-10-25
updated: 2026-10-25
tags:
  - gdd
  - guilda
  - territorio
  - customizacao
  - pvp
  - cooperativo
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# GDD-15 — Guildas, Território, Heráldica e Uniformes de Clã

> Pedido do Tarciso (2026-10-25): guilda construída pelos próprios jogadores conquistando e marcando território; customização de cores e emblema/brasão da guilda; criação de conjuntos/roupas personalizadas por ocasião (set de gala para eventos sociais/cerimoniais, set de guerra para combate territorial/confrontos e opção de vestimenta normal).
> Liga: [[03-Projects/Cepa-Selvagem/notas/GDD-08-Territorio-construcao-e-coleta|GDD-08]] (totem e regras de território), [[03-Projects/Cepa-Selvagem/notas/GDD-12-Equipamento-e-encaixes|GDD-12]] (encaixes de capa, cabeça e peito), [[03-Projects/Cepa-Selvagem/notas/GDD-14-Reproducao-ciclo-de-vida-e-familia|GDD-14]] (casamentos e celebrações na capela).

---

## 1. Conquista de Espaço: O Totem da Guilda

A guilda não é um menu abstrato nem um prédio pronto da vila: ela é uma **sede erguida no mundo compartilhado pelos próprios membros**.

### Regras de Implantação
1. **O Totem de Guilda:** Uma peça colossal de madeira entalhada e ferro batido, cravada na Zona Selvagem ou áreas abertas de colonização ([[03-Projects/Cepa-Selvagem/notas/GDD-08-Territorio-construcao-e-coleta|GDD-08]]).
2. **Raio de Território Expandido:** Enquanto um totem individual cobre 14 metros, o Totem de Guilda delimita uma área protegida de **40 a 80 metros** (cresce conforme o nível da sede).
3. **Segurança do Território:** Apenas membros autorizados podem construir, abrir baús comunitários ou colher recursos dentro dos limites da guilda.

---

## 2. Construção Comunitária e Níveis da Sede

A evolução da sede segue o modelo consagrado do *Quadro de Obras da Vila da Esperança*:

```
Nível 1 (Acampamento Pioneiro) ──► Nível 2 (Forte de Madeira) ──► Nível 3 (Cidadela de Pedra & Ferro)
```

- **Quadro de Contribuição do Clã:** Os membros depositam madeira nobre, barras de ferro, couro e pedras talhadas.
- Cada nível concluído desbloqueia:
  - **Nível 1:** Totem ativo, paliçada defensiva, baú comunitário compartilhado (30 slots).
  - **Nível 2:** Salão Nobre com mesa de banquete, forja própria da guilda, canteiros botânicos ampliados.
  - **Nível 3:** Capela/Altar interno da guilda, muralhas reforçadas e estandarte gigante visível no mapa de longe ([[03-Projects/Cepa-Selvagem/notas/GDD-11-Mapa|GDD-11]]).

---

## 3. Heráldica: Cores e Emblema da Guilda

O líder ou conselho do clã define a identidade visual única da organização:
- **Cor Primária & Cor Secundária:** Paleta heráldica (ex.: Vinho e Ouro, Ciano e Preto Cyber, Verde Musgo e Cobre).
- **Emblema / Brasão:** Ícones vetoriais combináveis (Cabeça de Lobo, Chifre de Rinolito, Pinheira Flamejante, Espadas Cruzadas, Âncora do Rio).
- **Projeção no Mundo:** As cores e o brasão decoram automaticamente os estandartes fincados nas muralhas da sede, as bandeiras do território e o Totem principal.

---

## 4. Uniformes de Clã Personalizados por Ocasião

O sistema de vestuário da guilda permite que os membros alternem rapidamente entre trajes predefinidos para expressar união e disciplina:

| Ocasião | Tipo de Conjunto | Características & Uso |
|---|---|---|
| 🎩 **Evento de Gala / Social** | **Set de Gala do Clã** | Roupas nobres, túnicas de seda, coletes alinhados e vestidos formais nas cores da guilda. Usado em casamentos na Capela ([[03-Projects/Cepa-Selvagem/notas/GDD-14-Reproducao-ciclo-de-vida-e-familia|GDD-14]]), banquetes no Salão Nobre e recepções diplomáticas. Foco em estética e carisma social. |
| ⚔️ **Set de Guerra / Confronto** | **Set de Batalha do Clã** | Armaduras completas (ferro, couro reforçado ou pano de combate) ostentando o **Brasão bordado na Capa** e gravado no **Escudo** e no peitoral. Usado em caçadas de monstros colossais, incursões na Zona Selvagem e defesas territoriais. |
| 🎒 **Uso Normal / Livre** | **Equipamento Pessoal** | Os jogadores usam seus conjuntos individuais forjados ([[03-Projects/Cepa-Selvagem/notas/GDD-12-Equipamento-e-encaixes|GDD-12]]) sem imposição de cores corporativas, ideal para exploração solo e coleta no rancho. |

---

## 5. Armário de Trajes da Guilda
Na sede da guilda há o **Armário de Trajes**:
- O mestre da guilda configura os modelos de uniforme de Gala e Guerra autorizados.
- Os membros com os materiais necessários forjam ou sincronizam o uniforme com um clique.
- Tecla rápida no menu ou vestiário permite alternar entre o traje normal e o traje da guilda instantaneamente.

---

## 6. Implementação (Bloco B26)
- [x] Peça `BuildablePiece.TOTEM_GUILDA` com estandarte e território circular de 40m a 80m.
- [x] Estandarte 3D procedural com flâmula animada ao vento, cores heráldicas e brasão (`GuildBanner3D`).
- [x] Sistema de heráldica e cargos (`GuildData` e `GuildSystem`).
- [x] Armário de trajes com alternância de ocasiões (`PERSONAL`, `GALA`, `WAR`) e overlay de brasão na Capa (`GearVisual`).
- [x] Interface completa da guilda (`GuildScreen`) com doações comunitárias e gestão de membros.
