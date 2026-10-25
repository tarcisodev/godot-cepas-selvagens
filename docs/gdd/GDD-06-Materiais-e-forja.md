---
type: resource
status: draft
created: 2026-10-21
updated: 2026-10-21
tags:
  - gdd
  - crafting
  - forja
  - materiais
owner: labu
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# GDD-06 — Materiais e forja (Pilar 3b)

> Equipamento não cai pronto: é forjado pelo jogador a partir de partes anatômicas de criaturas, minérios e botânica.
> Volta para o [[03-Projects/Cepa-Selvagem/notas/GDD-00-Visao-e-pilares|índice do GDD]]. Entrada de materiais da caça em [[03-Projects/Cepa-Selvagem/notas/GDD-03-Caca-anatomica|GDD-03]]. Destruição e ralos em [[03-Projects/Cepa-Selvagem/notas/GDD-05-Economia|GDD-05]].

## 1. Dados de um material (`MaterialData`)

O material não é apenas um ID numérico com quantidade; ele carrega o histórico de sua obtenção e o genoma da criatura ou planta.

```gdscript
class_name MaterialData extends Resource
@export var id: StringName                 # ex: &"rhinolith_horn"
@export var category: StringName           # &"horn", &"hide", &"plate", &"fiber", &"sap", &"metal"
@export var quality: int = 1               # 1 a 5 estrelas
@export var traits: Array[StringName]      # ex: [&"cicatrizado", &"denso", &"mirceno"]
@export var origin_species: StringName     # ex: &"rinolito"
```

### Qualidade (1 a 5)
Calculada no momento do abate ou coleta com base no tier da fonte e na técnica do jogador:
- **Íntegro** (captura com < 20% Vida, via armadilha e sedativo botânico) → **+1 de qualidade garantido**. É a única forma de obter materiais de qualidade máxima absoluta.
- **Chamuscado** (criatura abatida com dano predominante de fogo) → **−1 de qualidade**.
- **Preservado por Gelo** (abatida com frio/gelo) → impede degradação de fragmentos.
- **Fragmento/Quebrado** (parte quebrada durante a luta que caiu no chão) → qualidade base.

### Traits
- **Genéticos:** herdados do `GenomeComponent` da criatura ou da cepa botânica (ex.: *Denso*, *Fibroso*, *Condutor de Terra*, *Limoneno*).
- **Veterano (Mundo Vivo):** *Cicatrizado* — gerado quando a criatura sobreviveu a caçadas anteriores e regenerou no ninho.

---

## 2. Regra de combinação na forja

### Qualidade do item final
```
qualidade_base = round(média_ponderada(qualidade_materiais_obrigatorios))
qualidade_final = qualidade_base + critico_forja(maestria_ferreiro)  # max 5
```
A qualidade multiplica os modificadores numéricos base do item (`StatsComponent`):
- **Q1:** 100% (base)
- **Q2:** 110%
- **Q3:** 125%
- **Q4:** 140%
- **Q5:** 160%

### Slots de traits e herança
Todo equipamento forjado possui de **1 a 3 slots de traits** (definido pelo tier da receita):
1. **Slot 1 (Origem Estrutural):** recebe com 100% de prioridade o trait principal do material colocado no *Slot Estrutural (Núcleo)*.
2. **Slot 2 (Origem Tempero):** recebe o trait do material inserido no *Slot de Reforço/Tempero*.
3. **Traits Antagônicos:** se dois materiais inseridos possuírem traits opostos (ex.: *Inflamável* vs *Resistente ao Fogo*), eles se anulam na fusão, ocupando o slot com resíduo neutro.
4. **Trait Cicatrizado:** confere ao equipamento +15% de resistência a quebra de postura (*Poise Resist*) e +15% de durabilidade máxima base.

---

## 3. Estrutura de uma receita modular

As receitas não pedem ingredientes genéricos fixos ("10x ferro"), mas sim papéis funcionais:

```
Receita: Elmo / Lança / Peitoral
├── Slot 1: Estrutural / Núcleo (Obrigatório)
│   └── Chifre, fêmur, lâmina bruta, lingote metálico principal.
│       Define o tipo de dano (Corte/Perfuração/Concussão) ou a base de armadura.
├── Slot 2: Revestimento / Fixação (Obrigatório)
│   └── Placas de carapaça, couro curtido, tiras de tendão.
│       Define o perfil de peso (Carga leve/média/pesada) e mitigações secundárias.
└── Slot 3: Reforço / Tempero (Livre / Opcional)
    └── Seiva botânica terpênica, cristal elemental, pó mineral raro.
        Adiciona afinidade elemental, regeneração de atributos ou traits utilitários.
```

### Papel da maestria do ferreiro ([[03-Projects/Cepa-Selvagem/notas/GDD-02-Progressao-por-uso|GDD-02]])
- **Nível Inicial:** apenas forja itens usando slots obrigatórios.
- **Nível Intermediário:** desbloqueia o *Slot de Reforço/Tempero*; chance de economizar insumos.
- **Nível Mestre:** chance ampliada de *Crítico de Forja* (+1 qualidade) e redução da taxa de desgaste permanente no reparo.

---

## 4. Durabilidade, reparo e desmanche

Integrado ao ciclo econômico e aos ralos da Zona Selvagem ([[03-Projects/Cepa-Selvagem/notas/GDD-05-Economia|GDD-05]]):

### Desgaste e Reparo
- Equipamentos perdem durabilidade com o uso em combate e **−10% da durabilidade máxima por morte**.
- Em 0%, o item torna-se **inutilizável** até ser reparado em bancada.
- **Desgaste estrutural de reparo:** cada ciclo de reparo consome moeda + fração do material de revestimento e reduz em **3% a 5% a durabilidade máxima permanente** do item.
  - *Consequência:* nenhum item é eterno. Itens antigos perdem teto de vida e ficam progressivamente mais propensos à destruição na Zona Selvagem (`20% + 40% × desgaste`), sustentando a demanda de forja.

### Desmanche (Reciclagem)
- Itens obsoletos ou capturados de saques podem ser desmanchados na forja.
- Retorna **30% a 50% dos materiais originais**, rebaixados para a categoria de **Sucata** (qualidade −1), ideais para reparos ou ligas econômicas.

---

## 5. Três receitas de exemplo ponta a ponta

### 1. Elmo Chifre-de-Pedra (Armadura Pesada - Cabeça)
- **Origem dos materiais:** Caça ao Rinolito (porte Grande).
- **Slot 1 (Estrutural):** 1x Chifre de Rinolito. Se obtido de monstro veterano, carrega o trait *Cicatrizado* (+15% Poise).
- **Slot 2 (Revestimento):** 2x Placa de Carapaça de Rinolito (mitigação pesada de Concussão e Corte).
- **Slot 3 (Tempero - Livre):** 1x Fibra Vegetal Flexível (Botânica: reduz o peso do elmo em 10%).
- **Resultado:** Elmo protetor de alta estabilidade e peso aliviado, excelente para combatentes de linha de frente.

### 2. Lança Perfurante de Sucata (Arma de Duas Mãos)
- **Origem dos materiais:** Caça ao Tatu-Sucata (porte Médio) + mineração em carcaças.
- **Slot 1 (Estrutural):** 1x Garra/Espigão Perfurante de Tatu (dano perfurante primário + efeito de sangramento).
- **Slot 2 (Revestimento):** 2x Barra de Metal Reciclado (estrutura de haste reforçada).
- **Slot 3 (Tempero - Livre):** 1x Resina de Terpeno Limoneno (Genética vegetal: acelera a animação de estocada em 8%).
- **Resultado:** Lança de grande alcance com ataque ágil e aplicação de sangramento.

### 3. Gibão do Andarilho dos Ermos (Armadura Leve - Peito)
- **Origem dos materiais:** Caça ao Lobo Selvagem (porte Médio) + cultivo de ervas.
- **Slot 1 (Estrutural):** 3x Couro de Lobo Íntegro (obtido exclusivamente por captura: Qualidade 4).
- **Slot 2 (Revestimento):** 1x Tendão Elástico de Predador (reduz penalidade de vigor na esquiva).
- **Slot 3 (Tempero - Livre):** 1x Óleo de Mirceno Concentrado (trait *Calma Fria*: +8% regeneração passiva de vigor).
- **Resultado:** Colete leve voltado para arqueiros ou usuários de magia que dependem de mobilidade e vigor constante.

---

## 6. Forja no slice com materiais de caça (2026-10-22)

Decidido pelo Claude como game designer: o Tarciso autorizou seguir sem a decisão dele e revisa jogando. Aplica os §2–§4 aos materiais que a caça e a captura já rendem ([[03-Projects/Cepa-Selvagem/notas/GDD-03-Caca-anatomica|GDD-03 §9]]). Bloco: [[03-Projects/Cepa-Selvagem/blocos/B16-forja-modular|B16]].

- **Onde:** na **bigorna do acampamento** ([E]); o botão de forja do [Tab] só abre perto dela. Com a **Forja Pública** pronta (GDD-08 §6.1), o crítico de forja ganha +10%.
- **Itens forjados** têm qualidade (1–5★), traits, durabilidade e Carga. Cada um ocupa um encaixe: **cabeça**, **peito** ou **mãos**.

| Receita | Encaixe | Núcleo (obrigatório) | Revestimento (obrigatório) | Tempero (forja ≥ 10) | Efeito base |
|---|---|---|---|---|---|
| Elmo Chifre-de-Pedra | cabeça · pesada | 1 Chifre de Rinolito | 2 Placas de Carapaça | 1 Fibra: −10% peso | +10% corte, +12% impacto, +15% Postura · Carga 14 |
| Gibão do Andarilho | peito · leve | 3 Couros de Trotador | 1 Tendão **ou** 4 Fibras | 2 Ervas: *Calma Fria* (+2 regen. de Vigor) | +8% corte, esquiva −3 Vigor · Carga 5 |
| Capuz de Penacho | cabeça · leve | 3 Penas de Penacho | 1 Pele de Saltarelo | 1 Mel: *Doce Foco* (+1 regen. de Éter) | +1,5 regen. de Éter, esquiva −1 · Carga 2 |
| Braçadeiras de Galhada | mãos · média | 1 Chifre-Galhado | 1 Couro de Trotador | 2 Ossos: *Ossudo* (+5% impacto) | +6% impacto, +6% Postura · Carga 4 |

- **Qualidade:** média ponderada das ★ dos materiais obrigatórios + chance de crítico (+1★) de 0,4% por nível de `forja` (+10% com a Forja Pública). Multiplica os efeitos (Q1 100% … Q5 160%; a Carga não muda).
- **Traits (§2):** o slot 1 herda o trait do núcleo (*Íntegro*: +15% durabilidade; *Cicatrizado*: +15% Postura e durabilidade; *Iridescente*: brilho); o slot 2 vem do tempero.
- **Durabilidade:** 100 (×1,15 com Íntegro/Cicatrizado). Perde 1 por golpe recebido e −10% do máximo quando você cai. Em 0, o item não protege até ser reparado.
- **Reparo** na bigorna: 5 $S + 1 unidade do revestimento; volta a 100% do máximo atual, mas o máximo cai 4% (§4: nenhum item é eterno).
- **Desmanche:** devolve 40% dos materiais, com −1★.
- **Visível no corpo:** cada peça aparece no personagem (elmo com chifre, capuz de penas, gibão de couro, braçadeiras).
