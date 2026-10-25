---
type: resource
status: active
created: 2026-10-25
updated: 2026-10-25
tags:
  - gdd
  - culinaria
  - cozinha
  - buffs
  - sobrevivencia
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# GDD-13 — Cozinha, Culinária e Minigame de Assar Carne

> Pedido do Tarciso (2026-10-25): minigame de assar carne na fogueira estilo Monster Hunter (timing certo para não queimar), sistema de culinária combinando ingredientes do mundo (carnes, ovos, peixes, frutas, cogumelos, leite, mel, ervas) para gerar pratos que dão buffs de longa duração aos jogadores.
> Liga: [[03-Projects/Cepa-Selvagem/notas/GDD-01-Combate-e-magia|GDD-01]] (buffs de Vigor e Éter), [[03-Projects/Cepa-Selvagem/notas/GDD-03-Caca-anatomica|GDD-03]] (carnes de monstros), [[03-Projects/Cepa-Selvagem/notas/GDD-04-Ecologia-e-genetica|GDD-04]] (ervas e frutas), [[03-Projects/Cepa-Selvagem/notas/GDD-10-Ciclo-natural|GDD-10]] (fogueira e descanso), [[03-Projects/Cepa-Selvagem/notas/GDD-12-Equipamento-e-encaixes|GDD-12]] (modificadores de atributos).

---

## 1. Visão geral

A culinária no Cepa Selvagem cumpre dois papéis fundamentais:
1. **No acampamento/selva (Espeto na Fogueira):** Sustento rápido e minigame tátil de assar carne crua colhida de caça ou pesca, com risco de queimar.
2. **No Rancho ou na Taverna (Caldeirão de Culinária):** Gastronomia refinada onde 2 a 4 ingredientes combinados geram pratos com **buffs potentes e duradouros** (15 a 45 minutos reais).

---

## 2. Minigame do Espeto na Fogueira (Estilo Monster Hunter)

Sentado ao lado de uma **Fogueira** ([[03-Projects/Cepa-Selvagem/notas/GDD-10-Ciclo-natural|GDD-10 §10]]), o jogador pode sacar o *Espeto de Churrasco* com carne crua na mão.

### Mecânica de Timing
- O personagem começa a girar o espeto sobre as chamas.
- Uma melodia rítmica curta toca (ou uma animação de faíscas e mudança de cor da carne avança).
- A carne passa por **3 estágios sucessivos**:
  1. **Crua (0.0s – 3.5s):** Se puxar antes da hora, continua crua ou malpassada. Recupera pouca Vida e pode dar debuff leve de digestão lenta.
  2. **No Ponto / Perfeita (3.6s – 4.8s):** A carne chia forte, doura e uma faísca brilha. Se o jogador apertar **[Espaço]** ou **[E]** nessa janela:
     - Toca a fanfarra clássica (*"Tã-tã-tã-tããã!"*).
     - Gera **Bife Suculento / Espeto Perfeito**.
     - Efeito: Restaura 40% da Vida imediatamente e concede o buff *Bem Alimentado* (+15% de regeneração de Vigor por 10 min).
  3. **Queimada (4.9s+):** A carne escurece e solta fumaça preta.
     - Vira **Carne Queimada** (cinzas).
     - Recupera quase nada de Vida e reduz a estamina máxima temporariamente.

---

## 3. Ingredientes do Mundo

A comida vem das atividades vivas do ecossistema:

| Categoria | Fontes | Exemplos de Ingredientes |
|---|---|---|
| **Carnes** | Caça anatômica ([[03-Projects/Cepa-Selvagem/notas/GDD-03-Caca-anatomica|GDD-03]]) | Carne de Rinolito, Bife de Trotador, Coxa de Lobo |
| **Peixes** | Pesca com vara no rio ([[03-Projects/Cepa-Selvagem/blocos/B19-nado-peixes-e-pesca|B19]]) | Filé de Lambari, Posta de Dourado, Traíra Espinhosa |
| **Aves & Ovos** | Ninhos em árvores / arbustos | Ovo Selvagem, Ovo de Pássaro-Trovoada |
| **Laticínios** | Ordenha no cercado de fêmeas ([[03-Projects/Cepa-Selvagem/notas/GDD-14-Reproducao-ciclo-de-vida-e-familia|GDD-14]]) | Leite de Trotadora, Manteiga Batida |
| **Doces & Resinas** | Colmeias e flores silvestres | Mel de Abelha-Zumbidora, Pinhão de Pinheira-Lume |
| **Vegetais & Fungos** | Coleta pelo vale e canteiros ([[03-Projects/Cepa-Selvagem/notas/GDD-04-Ecologia-e-genetica|GDD-04]]) | Cogumelo-da-Sombra, Erva-Cítrica, Raiz-Amarga, Frutinha Silvestre |

---

## 4. O Caldeirão do Rancho e Combinações de Pratos

Na bancada culinária ou caldeirão, o jogador insere uma **Base** (Carne ou Peixe) + **Acompanhamentos** (Vegetais, Cogumelos, Ovos, Laticínios ou Mel).

### Exemplos de Receitas & Buffs

1. **Gisado do Caçador:**
   - *Ingredientes:* Carne de Trotador + Raiz-Amarga + Cogumelo-da-Sombra.
   - *Buff:* **Vigor Inabalável** (+20 Vigor máximo e -15% de custo ao esquivar por 20 min).

2. **Peixe Dourado ao Mel do Vale:**
   - *Ingredientes:* Posta de Dourado + Mel + Erva-Cítrica.
   - *Buff:* **Foco Místico** (+30 Éter máximo e +25% de regeneração de Éter por 20 min).

3. **Assado do Ermo:**
   - *Ingredientes:* Bife de Lobo + Pinhão de Pinheira-Lume + Pimenta Silvestre.
   - *Buff:* **Garras Afiadas** (+10% de dano de sangramento / corte e +5% de velocidade de corrida à noite).

4. **Caldo Revigorante de Rinolito:**
   - *Ingredientes:* Carne de Rinolito + Osso com Tutano + Erva-Cítrica.
   - *Buff:* **Postura de Pedra** (+25 de Postura máxima e +15% de resistência a impacto por 30 min).

5. **Pão de Viagem com Queijo e Pinhão:**
   - *Ingredientes:* Farinha de Cepa + Leite + Pinhões tostados.
   - *Buff:* **Passo Leve** (+10 kg na capacidade de carga sem lentidão por 25 min).

---

## 5. Qualidade dos Ingredientes e Sinergia com Genoma

- Ingredientes possuem **Qualidade (1★ a 5★)** e **Traits** herdados do genoma da planta ou criatura ([[03-Projects/Cepa-Selvagem/notas/GDD-04-Ecologia-e-genetica|GDD-04]]).
- Um peixe 4★ com trait *Eletrizado* ou uma fruta com trait *Refrescante* transferem bônus especiais para a refeição pronta.
- Uma refeição completa substitui a anterior (não acumula 10 buffs de comida ao mesmo tempo, mantendo o equilíbrio estilo MH).

---

## 6. Próximos Passos de Implementação
- [ ] Modelo procedural do espeto de fogueira com animação de giro.
- [ ] Minigame de timing (barra de progresso com zona ideal verde e zona preta queimada).
- [ ] Tabela de receitas culinárias (`recipes_cooking.gd`) e integração com o inventário.
