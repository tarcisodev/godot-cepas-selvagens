---
type: block
status: active
created: 2026-10-25
updated: 2026-10-25
tags:
  - bloco
  - godot
  - culinaria
  - cozinha
  - buffs
  - espeto
  - urubus
  - ecologia
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B25 — Culinária, Minigame de Assar Carne na Fogueira & Urubus Carniceiros

## Objetivo
Implementar o sistema completo de **Gastronomia e Sobrevivência** ([[03-Projects/Cepa-Selvagem/notas/GDD-13-Cozinha-e-culinaria|GDD-13]]) e o comportamento de **Cadeia Alimentar com Urubus Carniceiros** ([[03-Projects/Cepa-Selvagem/notas/GDD-10-Ciclo-natural#11-cadeia-alimentar-e-carniceiros-urubus|GDD-10 §11]]).
Permitir que o jogador asse carnes na fogueira com minigame tátil estilo *Monster Hunter*, combine bases e acompanhamentos no Caldeirão para gerar pratos com buffs de longa duração, e encontre caças pelo horizonte através de bandos de urubus sobrevoando carcaças.

---

## Pilares Técnicos e Arquitetura

### 1. Minigame do Espeto na Fogueira (`RoastSpitMinigame`)
- Integrado diretamente à `Campfire`: ao interagir com `[E] Assar Carne (Espeto)` com carnes cruas ou peixes na mochila, abre a interface tátil do assado.
- **Mecânica de Timing (GDD-13 §2):**
  - **Crua / Malpassada (0.0s – 3.5s):** Retirar antes resulta em `carne_mal_passada` (pouca recuperação).
  - **No Ponto Perfeito (3.6s – 4.8s):** Brilho dourado, carne chiando e fanfarra. Pressionar `[Espaço]` ou `[E]` concede `carne_bem_passada` (3★) e aplica imediatamente o buff **Bem Alimentado** (+15% de regeneração de Vigor por 10 min).
  - **Queimada (4.9s+):** Fumaça preta e escurecimento; resulta em `carne_torrada`.

### 2. Caldeirão Culinário & Banco de Receitas (`CookingSystem` & `CookingScreen`)
- **Combinação de Insumos:** 1 Base (Carnes ou Peixes) + 1 a 3 Acompanhamentos (Ervas, Frutas, Pinhões, Mel, Cogumelos, Ossos).
- **Receitas Canônicas:**
  - **Gisado do Caçador:** Carne + Erva + Frutinha → Buff *Vigor Inabalável* (+20 Vigor máx. e -15% de custo de esquiva por 20 min).
  - **Peixe Dourado ao Mel do Vale:** Peixe + Mel + Erva → Buff *Foco Místico* (+30 Éter máx. e +25% de regeneração de Éter por 20 min).
  - **Assado do Ermo:** Carne + Pinhão-Lume + Folha → Buff *Garras Afiadas* (+10% de dano e +5% de velocidade de corrida por 20 min).
  - **Caldo Revigorante de Rinolito:** Carne + Ossos + Erva → Buff *Postura de Pedra* (+25 de Postura máx. e +15% de recuperação de postura por 20 min).
  - **Banquete de Viagem com Pinhão:** Pinhão-Lume + Mel + Frutinha → Buff *Passo Leve* (+15 kg de carga sem lentidão e +10% de velocidade por 20 min).
  - **Ensopado Campeiro (Improvisado):** Qualquer base comestível + acompanhamentos válidos → Buff *Nutrição Básica* (+10 Vigor máx. e +10% de regeneração de Vigor por 15 min).
- **Qualidade Derivada & Traits:**
  - A qualidade final (1★ a 5★) é a média ponderada (40% base, 60% acompanhamentos).
  - Herança de traits especiais (`mutante`, `iridescente`, `integro`) com bônus na magnitude dos buffs.

### 3. Componente de Buffs de Comida (`FoodBuffComponent`)
- Respeita rigorosamente **ADR-0001** (sem atributos primários) e **ADR-0003** (modificadores com origem e fonte rastreáveis via `ModifierData`).
- Conforme **GDD-13 §5**: Uma refeição substitui a anterior (não há acúmulo desbalanceado de múltiplos banquetes simultâneos).
- Indicador visual em tempo real no HUD com ícone, nome do buff e temporizador regressivo.

### 4. Estações de Cozinha no Mundo e Construção Modular
- `CookingStation`: Estação 3D procedural (tripé de ferro, caldeirão com caldo borbulhante e fogo de chão) adicionada ao acampamento da vila (`CityHub`).
- Adicionado ao catálogo de construção (`BuildablePiece.PieceType.CALDEIRAO`), permitindo que jogadores forjem e instalem seus próprios caldeirões dentro dos Ranchos.

### 5. Urubus Carniceiros & Cadeia Alimentar (`VultureFlock3D` — GDD-10 §11)
- Carcaças de animais abatidos no vale geram automaticamente bandos de urubus procedurais voando em círculos a 18–25 m de altura.
- Atuam como farol visual no horizonte para os jogadores localizarem locais de caça e carcaças.
- Ao esfolar ou ao final da decomposição, os urubus dispersam para o alto e a célula de solo é enriquecida com **+0.80 de Nutrientes** (conforme GDD-10 §11.3), elevando a chance de mutação botânica para 12%.

---

## Critérios de Pronto
- [x] Documento do Bloco B25 registrado no repositório.
- [x] Novos materiais e itens culinários criados com categoria consumível e buffs em `resources/materials/`.
- [x] `FoodBuffComponent` implementado no jogador com modificadores matemáticos no `StatsComponent`.
- [x] `CookingSystem` com avaliação de receitas, fallback improvisado, cálculo de estrelas e traits.
- [x] `RoastSpitMinigame` com 3 janelas de timing, feedback visual/áudio e concessão do buff *Bem Alimentado*.
- [x] `CookingScreen` interativo com prévia do prato, auto-preenchimento e slots de ingredientes.
- [x] `CookingStation` 3D posicionado na praça da vila e peça construível `CALDEIRAO` no `BuildablePiece`.
- [x] Fogueira pública e construída (`Campfire`) com suporte a interação `[E] Assar Carne`.
- [x] `VultureFlock3D` sinalizando carcaças à distância no horizonte e fertilizando solo com +0.8 de nutriente.
- [x] Exibição do buff gastronômico ativo no HUD com ícone e tempo restante.
- [x] Suíte de testes headless `tests/test_cooking_and_roast.gd` aprovada com 100% de sucesso.
