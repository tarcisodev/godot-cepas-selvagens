# Ideias de Expansão: Céu Vivo, Estrelas Procedurais e o Planeta com Anéis

> **Origem da Ideia:**
> *"Estava com o pássaro voando, e começou a chover, achei legal, e fui olhar para o céu, senti falta de estrelas e ter alguns planetas. Ao olhar para cima, desenhar algumas estrelas procedurais, um planeta com anel, dar vida ao céu."*

---

## 1. Visão Geral & Atmosfera

*Cepa Selvagem* constrói uma experiência densa no chão: o rio que sobe e desce, o vento nas folhas, pássaros voando em bandos, fogueiras crepitando e criaturas com biologia própria.

No entanto, a **abóbada celeste** é o teto que emoldura tudo isso. Quando o jogador olha para cima — seja descansando na fogueira, em cima de uma montaria alada ou vendo a chuva abrir —, o céu não deve ser um fundo estático, mas um espetáculo cósmico vivo que recompensa a contemplação e reforça o tom de um mundo selvagem, estranho e misterioso.

```
       .  *    .   +       .  *     .  +    *  .   .
    *      .     🪐 (Planeta com Anéis)       .   *   .
  .    +     .    / \     .       *    .    +      .
     *      .    /===\      *    .   🌙 (Lua com Fases)
  +     .       /=====\   .     +      .     *   .
------------------------------------------------------
        /\_/\    Nuvens de Chuva / Vento
   /\  /     \  /\      (WeatherSystem)
  /  \/       \/  \  Pássaros voando entre copas
 /                 \ Rio caudaloso / Fogueiras
```

---

## 2. Pilares do Céu Vivo

### 2.1. Estrelas Procedurais Dinâmicas (Procedural Starfield)
- **Distribuição Esférica Determinística:**
  - Geradas proceduralmente na cúpula celeste sem texturas pesadas (via algoritmo de hash esférico ou grid pseudo-randômico no shader).
  - Variação de magnitude: estrelas tênues (maioria), estrelas médias brilhantes e "superestrelas" com tons levemente azulados, dourados e avermelhados.
- **Cintilação Viva (*Twinkling*):**
  - Cada estrela possui sua própria frequência de cintilação baseada em ruído temporal (`sin(TIME * freq + offset)`), dando vida orgânica ao céu noturno.
- **Faixa de Poeira Cósmica (Nebulosa / Via Láctea):**
  - Um arco sutil de gás e poeira estelar atravessando o céu, com gradientes turquesa e violeta suaves que se intensificam no zênite.
- **Reação à Atmosfera e Clima:**
  - **Crepúsculo/Alvorada:** As estrelas mais brilhantes surgem primeiro no entardecer, enquanto o campo estelar completo floresce à meia-noite.
  - **Nuvens e Chuva:** Integrado ao `WeatherSystem` — quando nuvens carregadas cobrem o mapa ou a chuva cai, as estrelas são suavemente obscurecidas pela camada de névoa e nuvens, voltando a brilhar quando o tempo abre.

### 2.2. O Planeta com Anéis ("O Observador Anelado" / Gigante Gasoso)
- **Presença Visual Majestosa:**
  - Um corpo celeste imponente com anéis elípticos translúcidos, visível tanto ao entardecer quanto durante a noite e madrugadas limpas.
- **Iluminação Sincronizada com o Sol:**
  - Assim como a Lua do projeto já segue as fases da luz solar, o planeta e seus anéis recebem luz coerente com a direção do `Sun` (DirectionalLight3D), projetando a sombra do planeta sobre os anéis e vice-versa.
- **Lore & Significado no Mundo:**
  - *O Berço das Mutações:* No universo do jogo, este gigante gasoso ("Cepa Celeste" ou "Aro Primordial") pode ser a fonte das marés energéticas que catalisam mutações nas plantas (como a luminescência da Pinheira-Lume) e no comportamento de feras selvagens.

### 2.3. Eventos Efêmeros no Céu ("Dar Vida ao Céu")
1. **Estrelas Cadentes (Meteoros Esporádicos):**
   - De tempos em tempos (ex: a cada 40 a 90 segundos em noites limpas), um traço luminoso rápido corta o céu em ângulo aleatório e se extingue.
   - *Possibilidade de Gameplay:* Chuvas de meteoros ocasionais que aumentam a chance de encontrar fragmentos minerais raros (ex: quartzo-lume) na manhã seguinte.
2. **Bandos de Aves em Altitude:**
   - Aproveitar o sistema de `wildlife_ambient.gd`: pequenos bandos de pássaros voando em V bem alto no céu contra a luz das estrelas ou o horizonte crepuscular.
3. **Auroras / Véus Etéreos de Lume:**
   - Em noites frias ou pós-chuva perto de florestas de Pinheira-Lume, véus boreais esverdeados/azulados ondulando suavemente no alto.

---

## 3. Arquitetura Técnica Proposta (Godot 4)

Para manter a compatibilidade perfeita com o ecossistema existente (`world.tscn`, `weather_system.gd`, `day_night_cycle.gd` e `moon.gd`), a implementação mais limpa e performática divide-se em:

### Opção Recomendada: Abordagem Modular (Celestial Actors)
Seguindo o padrão de design que o projeto já adotou com `Moon` (`scripts/ecology/moon.gd`):

1. **`CelestialSkyDome` (Cúpula de Estrelas & Nebulosa):**
   - Um domo invertido ou mesh espacial posicionado centrado na câmera (`global_position = cam.global_position`) a distância fixa (~430m, atrás da Lua).
   - Shader unshaded com render_priority baixa, calculando estrelas com cintilação via `TIME` e intensidade multiplicada por `night_factor * (1.0 - overcast)`.
   - Custo de performance próximo de zero (desenhado com rasterização simples e sem colisão).

2. **`RingedPlanet` (Planeta com Anéis):**
   - Um nó `Node3D` dedicado posicionado na órbita celeste, com:
     - `SphereMesh` para o corpo planetário (com shader de bandas atmosféricas sutis).
     - `QuadMesh` ou `CylinderMesh` fino com shader de anéis (fórmula de gradientes concêntricos com transparência e iluminação direcional).
   - Acompanha o zênite em coordenada celestial angular fixa ou rotação ultra-lenta.

3. **`ShootingStarEmitter` (Estrelas Cadentes):**
   - Emitter de partículas GPU ou script leve que sorteia trajetórias rápidas em noites com `clouds < 0.3`.

---

## 4. Integração com os Sistemas Existentes

| Sistema | Como se integra |
| :--- | :--- |
| **`DayNightCycle`** | Controla o `sky_fade`: estrelas e anéis ganham força no crepúsculo (18h-19h), brilham no auge (20h-04h) e esvanecem na alvorada (05h-06h). |
| **`WeatherSystem`** | Lê `clouds` e `rain`: tempestades fecham o céu e escondem os astros; quando a chuva passa, o céu "limpa" com máxima nitidez. |
| **`Moon`** | O planeta com anel convive no mesmo espaço orbital da lua sem sobreposição, enriquecendo o panorama celeste. |
| **`Fauna / Pássaros`** | Pássaros voando em silhueta contra as estrelas e o planeta anelado criam tomadas visuais de tirar o fôlego. |

---

## 5. Próximos Passos Sugeridos

- [ ] **Fase 1:** Criar shader de estrelas procedurais com cintilação temporal e fading por luz solar/nuvens.
- [ ] **Fase 2:** Criar o modelo/shader procedural do Planeta com Anel e fixá-lo na abóbada celeste.
- [ ] **Fase 3:** Adicionar estrelas cadentes esporádicas.
- [ ] **Fase 4:** Vincular possíveis buffs cósmicos ou eventos de colheita/caça às noites de céu aberto.
