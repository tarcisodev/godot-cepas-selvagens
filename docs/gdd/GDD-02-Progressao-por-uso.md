---
type: resource
status: draft
created: 2026-10-21
updated: 2026-10-21
tags:
  - gdd
  - progressao
  - maestria
owner: labu
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# GDD-02 — Progressão por uso (Pilar 2)

> Sem nível de personagem nem classe fixa. O poder pessoal cresce pelo que se pratica. O equipamento define o papel do momento ([[08-Knowledge/decisions/ADR-0001-cepa-sem-atributos-primarios|ADR-0001]]) e a maestria aprofunda a eficiência daquele papel.
> Volta para o [[03-Projects/Cepa-Selvagem/notas/GDD-00-Visao-e-pilares|índice do GDD]]. Combate em [[03-Projects/Cepa-Selvagem/notas/GDD-01-Combate-e-magia|GDD-01]]. Forja em [[03-Projects/Cepa-Selvagem/notas/GDD-06-Materiais-e-forja|GDD-06]].

---

## 1. Arquitetura da maestria

- **Sem atributos primários:** o personagem não distribui pontos de FOR, AGI ou INT.
- **Modificadores na pilha única:** a maestria é uma fonte de `ModifierData` aplicada ao `StatsComponent` (ex.: `lança` nível 40 → `thrust_speed +8%`, `stamina_cost -5%`).
- **Resolução via eventos:** o serviço de maestria (`MasteryService`) roda no servidor ([[08-Knowledge/decisions/ADR-0002-cepa-servidor-autoritativo|ADR-0002]]) e reage aos sinais emitidos pelo pipeline de combate ([[08-Knowledge/decisions/ADR-0003-cepa-dano-como-evento|ADR-0003]]) e pelos sistemas de coleta/craft.

```gdscript
class_name MasteryComponent extends Node
# Dicionário de tags -> nível e XP atual
var masteries: Dictionary = {} # { &"lança": { "level": 25, "xp": 450.0 } }

func add_xp(tag: StringName, amount: float) -> void:
    # processado autoritativamente pelo MasteryService
```

---

## 2. Lista oficial de tags de maestria

A lista é enxuta para manter o balanceamento claro e evitar fragmentação:

### Combate e Magia
- `lança`: armas de haste, estocadas de longo alcance, combate montado.
- `lâmina`: espadas curtas/médias e adagas; foco em corte ágil e mobilidade durante o golpe.
- `concussão`: maças e martelos pesados; dano em partes anatômicas duras, quebra de carapaça e dano de postura (*poise*).
- `disparo`: arcos e bestas; ataques perfurantes à distância com mira preditiva.
- `canalização`: cajados e focos arcanos; escolas elementais (terpênica, ígnea e geotérmica).

### Defesa e Armaduras (Perfis de Carga)
- `armadura_leve`: minimiza custo de vigor na esquiva e concede recuperação passiva acelerada.
- `armadura_media`: equilíbrio flexível entre mitigação de dano e mobilidade de combate.
- `armadura_pesada`: mitigação bruta de impacto físico e alta resistência a interrupção (*poise resist*).

### Ofícios e Coleta
- `esfola`: caça anatômica; reduz o tempo canalizado de extração e eleva a pureza do material.
- `mineracao`: extração de rochas e carcaças fossilizadas; previne esfarelamento de minérios raros.
- `coleta`: coleta comum no mundo (madeira, galho, folha, fibra, frutinha, besouro, ossos, mel, erva silvestre); reduz o tempo e libera material 2★. Incluída em 2026-10-22 pelo [[03-Projects/Cepa-Selvagem/notas/GDD-08-Territorio-construcao-e-coleta|GDD-08]].
- `botanica`: cultivo no rancho, manejo de cepas de cannabis/ervas medicinais, taxa de germinação e mutação.
- `forja`: ferraria e armaria; desbloqueio de slots de tempero, economia de insumos e chance de acerto crítico de qualidade.

---

## 3. Fontes de XP ativas

O XP é conquistado estritamente por ações ativas bem-sucedidas:
- **Armas e Magias:** baseado em `damage_dealt` efetivo contra alvos válidos (ponderado pelo tier do monstro).
- **Armaduras:** baseado em `damage_mitigated` (absorver ou bloquear dano com equipamento; **não** por receber surra passiva).
- **Ofícios e Coleta:** conclusão bem-sucedida de um ciclo (extrair parte anatômica, colher planta madura, forjar item funcional), escalado pela qualidade dos insumos.

---

## 4. Curva de progressão e teto aberto

- **Maestria Ilimitada (estilo Albion/Runescape):** o personagem pode evoluir todas as tags de maestria sem limite global de pontos de classe.
  - O jogador pode alternar de lanceiro para mago terpênico simplesmente trocando o equipamento e treinando.
- **Níveis de 1 a 100 com curva exponencial:**
  - **Nível 1 a 30 (Iniciação rápida):** evolução fluida, permitindo ao jogador experimentar diversos estilos de jogo sem atrito.
  - **Nível 31 a 70 (Competência avançada):** ritmo padrão de dedicação.
  - **Nível 71 a 100 (Especialização de mestre):** curva íngreme que exige dedicação pesada, valorizando ferreiros e caçadores veteranos no mercado.

---

## 5. Recompensas: passivas contínuas e marcos mecânicos

A progressão combina ganhos quantitativos contínuos com saltos qualitativos de capacidade:

### Ganhos por nível (Passivos)
A cada nível regular, a tag injeta modificadores acumulativos sutis:
- Armas: `+0,3%` dano base, `-0,2%` consumo de vigor/éter.
- Armaduras: `+0,2%` mitigação efetiva, `+0,2%` velocidade de recuperação de postura.
- Forja: `+0,2%` chance de crítico de forja, `-0,1%` desgaste permanente por reparo.

### Marcos Chave (Milestones: Níveis 10, 25, 50, 75, 100)
Desbloqueiam **novas habilidades (`AbilityData`)** ou **permissões de sistema**:

| Nível | Exemplo em Armas (Lança) | Exemplo em Ofício (Forja) | Exemplo em Coleta (Esfola) |
|---|---|---|---|
| **10** | Habilidade: *Estocada Rápida* | Redução de 10% no custo de moedas de reparo | Tempo de esfola cai de 3,0 s para 2,5 s |
| **25** | Habilidade: *Fenda Perfurante* (atravessa armadura) | **Desbloqueia Slot de Tempero/Reforço** nas receitas | Permite extrair glândulas e seivas raras sem romper |
| **50** | Habilidade: *Salto de Bote* (gap close de alcance) | 15% de chance de recuperar 1 insumo na forja | Tempo de esfola cai para 1,5 s por parte |
| **75** | Passiva: *Empalação Crítica* (+dano em partes quebradas) | Acesso a receitas de ligas exóticas e armas de chefes | Chance dobrada de material vir com qualidade máxima |
| **100** | Habilidade Suprema: *Perfurador de Titãs* | **Mestre Forjador:** +10% de chance fixa de Qualidade 5 | Esfola instantânea (0,5 s) e imunidade a interrupção leve |

---

## 6. Regras anti-macro e anti-exploit

Para proteger a economia e coibir automações predatórias:
1. **Retorno Decrescente por Disparidade de Tier:**
   - Atacar criaturas com tier muito inferior ao nível do equipamento do jogador sofre penalidade brutal:
     - 1 tier abaixo: 70% XP.
     - 2 tiers abaixo: 10% XP.
     - 3 ou mais tiers abaixo: **0% XP**.
2. **Sem Evento = Sem XP:**
   - Golpes no ar, em paredes ou em alvos mortos não disparam `HitEvent` e rendem zero de XP.
3. **Fadiga de Spawn Estático:**
   - Eliminar repetidamente monstros no mesmo raio geográfico em curto período aplica um decaimento temporário de ganho de XP na área.
4. **Sem Loop Infinito de Crafting:**
   - Forjar sucata barata ou itens repetitivos de tier baixo não concede XP para ferreiros avançados. O XP de ofício exige receitas compatíveis com a faixa de nível do artífice.
