---
type: resource
status: draft
created: 2026-10-21
updated: 2026-10-22
tags:
  - gdd
  - economia
  - multiplayer
  - mercado
owner: labu
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# GDD-05 — Economia e multiplayer (Pilar 5)

> Economia 100% orientada por jogadores, equilibrada por torneiras e ralos severos e pelo Mercado Negro sistêmico. Zonas com perfis de risco distintos (Segura, Disputada e Selvagem com full loot).
> Volta para o [[03-Projects/Cepa-Selvagem/notas/GDD-00-Visao-e-pilares|índice do GDD]]. Caça em [[03-Projects/Cepa-Selvagem/notas/GDD-03-Caca-anatomica|GDD-03]]. Forja em [[03-Projects/Cepa-Selvagem/notas/GDD-06-Materiais-e-forja|GDD-06]].

---

## 1. Tabela mestra de torneiras e ralos

Para assegurar estabilidade monetária e manter a demanda por matérias-primas e equipamentos sempre ativa no servidor ([[08-Knowledge/decisions/ADR-0002-cepa-servidor-autoritativo|ADR-0002]]):

| Recurso | Torneiras (Entradas no Mundo) | Ralos (Destruição / Saídas) |
|---|---|---|
| **Moeda (Dólares de Sucata)** | • Venda de equipamentos manufaturados ao Mercado Negro.<br>• Recompensas de contratos/bounties de caça e escolta de caravanas. | • Taxa de listagem (2%) e venda (4%) no mercado local de jogadores.<br>• Custo de reparo em bancadas e fusão de ligas na forja.<br>• Expansão territorial e melhorias do rancho (cercados e canteiros). |
| **Equipamentos** | • Forja exclusiva de jogadores a partir de receitas e materiais ([[03-Projects/Cepa-Selvagem/notas/GDD-06-Materiais-e-forja|GDD-06]]). | • Destruição imediata no abate PvP na Zona Selvagem (`20% + 40% × desgaste`).<br>• Desgaste permanente da durabilidade máxima em reparos (−3% a 5% por ciclo).<br>• Desmanche para sucata e reciclagem.<br>• Destruição sistêmica de excesso de estoque no Mercado Negro. |
| **Materiais e Consumíveis** | • Esfola anatômica de carcaças ([[03-Projects/Cepa-Selvagem/notas/GDD-03-Caca-anatomica|GDD-03]]).<br>• Colheita botânica e solventes de aquicultura ([[03-Projects/Cepa-Selvagem/notas/GDD-04-Ecologia-e-genetica|GDD-04]]). | • Perda de 15% de pilhas no abate da Zona Selvagem.<br>• Consumo obrigatório em receitas de forja e armaria.<br>• Restos de monstros transformados em adubo na composteira orgânica.<br>• Consumo contínuo de sedativos, armadilhas, munições e poções. |

---

## 2. Mercado de jogadores: entrepostos locais e rotas comerciais

- **Mercados Locais por Cidade/Entreposto (estilo Albion Online):**
  - Não existe uma casa de leilões global instantânea. O mercado de um Entreposto do Deserto é fisicamente isolado do mercado da Cidade Fluvial.
  - O preço das mercadorias flutua conforme a oferta e demanda daquela região.
- **Mecânica de Ordens:**
  - **Ordens de Venda:** o vendedor estipula o preço de suas mercadorias e aguarda compradores.
  - **Ordens de Compra:** o comprador trava o dinheiro no mercado e define quanto paga por X quantidade de um recurso (ex.: *Chifre de Rinolito Íntegro*); qualquer caçador que chegar pode vender instantaneamente.
- **Taxas Regulatórias:**
  - **Taxa de Listagem:** 2% paga no ato de criação da ordem (não reembolsável se cancelar; ralo de moeda).
  - **Taxa de Transação:** 4% retida sobre o valor final liquidado da venda.
- **Gameplay de Caravanas e Logística:**
  - O isolamento entre cidades cria oportunidades para mercadores comprarem insumos baratos em pólos produtores e transportarem em montarias até centros de consumo, gerando risco e demanda por escoltas armadas ao cruzar áreas perigosas.

---

## 3. O Mercado Negro (O Regulador Sistêmico)

O Mercado Negro opera como a ponte entre o artesanato dos jogadores e os baús de tesouro dos ermos, situado em um entreposto oculto na Zona Selvagem:

- **Ordens de Compra Sistêmicas:**
  - O servidor monitora a taxa de itens dropados em masmorras, chefes e eventos.
  - Se o mundo necessita de espadas ou capacetes de determinado tier, o Mercado Negro cria e eleva gradualmente as ordens de compra por esses itens com ouro gerado pelo sistema.
- **Destino dos Itens Comprados (Loot Orgânico):**
  - Todo equipamento raro que um jogador encontra em baús de masmorras, chefes mundiais ou eventos de mapa **veio do Mercado Negro**.
  - O jogo não cria equipamentos prontos do vácuo; o conteúdo dropado é fruto da produção de algum jogador que vendeu ao Mercado Negro.
- **Triturador de Excesso (Ralo):**
  - Se a oferta de um item superar a taxa de entrega em masmorras, o Mercado Negro consome e destrói o item permanentemente para drenar a saturação do mercado.

---

## 4. Modos de PvP, zonas de risco e perdas

### Duelo Consensual (PvP Base)
- Convite aceito em qualquer lugar fora de combate ativo.
- **Aposta em dinheiro opcional:** sem taxa da casa (transferência direta entre duelistas).
- **Limite:** ninguém aposta mais de **10% do dinheiro que possui no personagem**. Teto definido pelo menor saldo entre os dois.
- **Sem perda de itens:** a aposta é a única consequência da derrota.

### Zonas Seguras e Morte para Monstro
- Nas zonas de exploração inicial e cidades, a morte para monstros não acarreta perda de inventário nem de equipamento.
- O jogador entra no estado **Caído** (30 s com recuperação de 25% Vida) ou pode optar por reviver no acampamento/rancho.
- Aplica-se apenas o desgaste padrão de **−10% da durabilidade máxima equipada**.

### Zona Selvagem (PvP Aberto e Full Loot)
- **Aviso Obrigatório de Fronteira:** transição com alerta visual e sonoro claro na interface antes de cruzar a fronteira.
- **Morte por Jogador = Full Loot:**
  - Todo o inventário e equipamentos equipados caem no chão dentro de um saco de restos.
  - **Prioridade de Saque:** 1 minuto exclusivo para o jogador (ou grupo) que desferiu o golpe de abate. Após 1 minuto, o saco torna-se público para qualquer andarilho. O saco desaparece em até 3 horas.
- **Fórmula de Destruição no Abate:**
  - Cada item equipado e do inventário rola chance independente de destruição imediata:
    ```
    chance_destruir = 20% + 40% × (1 − durabilidade_atual / durabilidade_max)
    ```
  - Pilhas de consumíveis e materiais perdem **15% da quantidade** fixa no abate.
- **Crédito de Abate:** se um jogador causou dano à vítima nos últimos 30 segundos, a morte é categorizada como PvP (full loot) mesmo que um monstro desfira o golpe de misericórdia.
- **Janelas de Risco e Eventos:**
  - A Zona Selvagem possui rotas fixas de alto perigo e **Eventos Dinâmicos** (ex.: *Tempestade Terpênica*, *Migração de Colossos*), durante os quais o rendimento de recursos aumenta em 50%, com liberação de conflito total entre facções.

---

## 5. Moeda no slice: Dólares de Sucata (decidido em 2026-10-22, pedido do Tarciso)

Enquanto não há outros jogadores para negociar, o slice precisa de **uma torneira e um ralo** de moeda que respeitem a tabela do §1 e funcionem igual no online.

- **Nome e símbolo:** Dólares de Sucata, **$S**. Inteiro, sem centavos. Personagem novo começa com **50 $S**.
- **Carteira:** fica no personagem (`WalletComponent`), entra no save e, no online, só o servidor altera (ADR-0002). Aparece no HUD e no inventário.
- **Torneira — Contratos da Vila** (o "contratos/bounties" do §1): o Quadro de Obras ganha a aba **Contratos**. Sempre há **3 pedidos** abertos do tipo "entregue N de um material comum"; ao entregar, paga em $S e um pedido novo entra no lugar. Paga só o valor-base (qualidade não muda o preço: a ★ alta vale mais na forja e no mercado de jogadores).
- **Valor-base por material** (referência para contratos e, depois, para o Mercado Negro): madeira 2 · galho 1 · folha 1 · fibra 1 · pedra 2 · frutinha 1 · besouro 3 · ossos 3 · erva 2 · mel 6 · tendão 12 · placa 15 · chifre 40. Contrato paga **valor-base × quantidade × 1,5** (o prêmio por ir buscar).
- **Ralo — Loja da Alquimista:** vende consumíveis. Poção de Cura 15 · Mega Poção 40 · Carne Bem Passada 8 · Cannabis Sativa 12 · Cannabis Indica 14. **Não compra nada de volta** (vender para NPC seria torneira infinita).
- **Reputação da Vila → desconto:** −1% no preço da loja a cada 25 de Reputação (GDD-08 §6.1), até −10%.
- **Depois do slice:** taxas do mercado de jogadores (2% e 4%), manutenção do totem (GDD-08 P7), reparo, aposta de duelo e Mercado Negro comprando equipamento forjado.
- **Implementado em 2026-10-22:** `WalletComponent` no player, dinheiro no HUD, abas Obras/Contratos no Quadro, loja na Alquimista; teste `tests/test_money.gd`.

## 6. Mercado da Vila no slice: ordens e caravana (decidido em 2026-10-23, Claude como game designer, pedido do Tarciso)

O §2 é de jogadores para jogadores. Enquanto o slice não tem outros jogadores, a **caravana mercante** faz o papel deles: passa pelo Mercado **duas vezes por dia (8h e 17h)** e atende as ordens abertas. No online ela some e quem atende são os jogadores (e, depois, o Mercado Negro).

- **Abre quando a obra Mercado fica pronta** (GDD-08 §6.1). A Mercadora fica no pavilhão.
- **Encomenda (ordem de compra):** escolha material, quantidade (1 a 20) e preço por unidade. O dinheiro fica **travado** no Mercado. A caravana traz o material se o seu preço cobrir o que ela pede (valor-base × 0,9 a 1,5), até 2 a 8 unidades por visita, com qualidade 1★ a 3★. Você paga o **seu** preço.
- **Ordem de venda:** escolha material, quantidade e preço. Os itens saem do inventário (pior ★ primeiro) e ficam no Mercado. A caravana compra se o seu preço estiver dentro do que ela paga (valor-base × 0,7 a 1,3), até 1 a 6 unidades por visita. A procura limitada segura a torneira.
- **Taxas do §2:** listagem de 2% (mínimo 1 $S, perdida se cancelar) e transação de 4% sobre cada venda. As duas são ralo.
- **Retirada:** o que a caravana entrega e o dinheiro das vendas ficam **a receber** no Mercado; você retira na Mercadora. Cancelar devolve o que sobrou (dinheiro travado ou itens com a mesma ★).
- **Limite:** 6 ordens abertas por personagem. Ordens e o "a receber" entram no save (no online, no servidor).
- **Implementado em 2026-10-23 (B18):** `VillageMarket` (ordens, caravana, taxas, a receber, save no estado da vila), Mercadora no pavilhão, `MarketScreen`; teste `tests/test_market.gd`.
