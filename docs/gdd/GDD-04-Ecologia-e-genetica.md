---
type: resource
status: draft
created: 2026-10-21
updated: 2026-10-21
tags:
  - gdd
  - ecologia
  - genetica
  - botanica
owner: labu
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# GDD-04 — Ecologia, genética e exploração (Pilar 4)

> O mundo é vivo, persistente e interconectado. Animais e plantas compartilham um modelo biológico comum: cruzam, herdam características, sofrem mutações e alimentam o ciclo de caça ([[03-Projects/Cepa-Selvagem/notas/GDD-03-Caca-anatomica|GDD-03]]) e forja ([[03-Projects/Cepa-Selvagem/notas/GDD-06-Materiais-e-forja|GDD-06]]).
> Volta para o [[03-Projects/Cepa-Selvagem/notas/GDD-00-Visao-e-pilares|índice do GDD]].

---

## 1. Modelo de genoma unificado (Mendeliano Discreto)

Todas as entidades vivas (criaturas, plantas cultivadas e peixes) operam sobre o mesmo componente de genoma (`GenomeComponent`):

```gdscript
class_name GenomeComponent extends Node
# Pares de alelos por loco gênico
@export var alleles: Dictionary = {
    &"power": ["T", "t"],      # dominância incompleta (potência/porte)
    &"terpene_m": ["M", "m"],  # dominância completa (mirceno / densidade)
    &"terpene_l": ["l", "l"]   # dominância completa (limoneno / agilidade)
}
@export var is_mutant: bool = false
```

### Regras de Herança e Expressão
- **Dois alelos por gene:** um materno e um paterno. Segregação independente (50% de chance de herdar cada um).
- **Dominância Completa vs. Incompleta:**
  - *Incompleta (ex.: Gene T de Porte/Potência):* `TT` = Grande/Máximo (100%), `Tt` = Médio (75%), `tt` = Pequeno/Base (50%).
  - *Completa (ex.: Genes de Terpenos M e L):* `M_` expressa *Mirceno*; `L_` expressa *Limoneno*; `M_L_` expressa equilíbrio *Cariofileno*.
- **Taxa de Mutação (`*`):**
  - Todo alelo transmitido tem **~3% de chance de mutar** para a forma especial `*`.
  - Mutações geram traits lendários: *Super-Pineno* em plantas, *Carapaça Espelhada* em criaturas, *Escama Prisma* em peixes.
- **Ponte direta com a Forja:** o genoma gera os traits que são extraídos nas partes anatômicas e aplicados no item forjado ([[03-Projects/Cepa-Selvagem/notas/GDD-06-Materiais-e-forja|GDD-06]]).

---

## 2. Criadouro e breeding de animais (Rancho)

O jogador pode domesticar e reproduzir fauna nos cercados do seu rancho:

### Entrada no Criadouro
- **Apenas via Captura Cuidadosa:** animal enfraquecido (< 20% Vida) capturado com armadilha e sedativo botânico ([[03-Projects/Cepa-Selvagem/notas/GDD-03-Caca-anatomica|GDD-03]]).
- **Restrição de Porte:** permitido para portes **Pequeno** (coelhos, roedores), **Médio** (lobos, javalis, tatus) e montarias pacíficas. Criaturas colossais e chefes mundiais não são domesticáveis.

### Ciclo Reprodutivo
- **Gestação e Choca:** 1 macho e 1 fêmea compatíveis no cercado. A gestação dura entre **1 e 3 dias de jogo** (2 a 6 horas reais).
- **Sustento Obrigatório:** o cercado consome ração vegetal (da botânica) ou carnes de caça. A falta de comida paralisa o ciclo reprodutivo sem matar as matrizes.
- **Destino do Filhote:**
  1. *Matriz Reprodutiva:* mantido no cercado para fixar mutações e traits raros ao longo das gerações.
  2. *Abate Cuidadoso:* abatido no rancho sem combate, garantindo 100% de partes **Íntegras** (+1 qualidade) com a pureza dos traits genéticos cultivados.

---

## 3. Botânica profunda: cultivo, consórcio e adubação

O cultivo no rancho vai além do plantio básico, operando como o motor químico do jogo:

### Cruza e Polinização
- Canteiros adjacentes durante o estágio de floração realizam polinização cruzada com auxílio do vento ou polinizadores, gerando sementes híbridas que fundem os genomas das matrizes vizinhas.

### Consórcio de Culturas (Plantio Companheiro)
Plantar espécies complementares em canteiros vizinhos confere sinergias diretas:
- **Leguminosas / Fixadoras de Nitrogênio:** aceleram em **+20%** a velocidade de maturação das cepas medicinais vizinhas.
- **Ervas Aromáticas / Repelentes:** reduzem a incidência de pragas e fungos, garantindo 100% de rendimento na colheita.

### Adubação Orgânica (Loop Ecológico com a Caça)
- Restos de monstros, ossos triturados e carcaças que sobram da forja são levados à **Composteira**.
- O adubo de monstro mineraliza a terra:
  - Adubo rico em cálcio (de chifres/ossos) → fibras vegetais mais resistentes.
  - Adubo de monstros elementais (ex.: criatura de fogo ou terra) → eleva a concentração de resina terpênica e a chance de mutação.
- **O ciclo biológico:** A caça alimenta a composteira → o adubo melhora a cepa → a cepa vira o sedativo que permite capturar criaturas mais fortes.

---

## 4. Tanques aquáticos e aquicultura

Simulação aquática focada em utilidade e contemplação:
- **Modelo Abstrato Eficiente:** não há física volumétrica pesada. O tanque é regido por dois parâmetros: **Tipo de Água** (doce, salobra, termal) e **Biomassa Suportada**.
- **Utilidade Química:**
  - *Óleo de Peixe Purificado:* solvente industrial obrigatório para a extração de resinas vegetais e polimento de ligas metálicas na bancada de forja.
  - *Extrato Bioluminescente:* obtido de algas e peixes das profundezas; ingrediente para poções de visão no escuro e sinalizadores de caça.
- **Modo Aquário:** tanques de vidro na sede do rancho exibem as espécies marinhas raras capturadas pelo jogador com rede ou armadilha de rio.

---

## 5. Catalogação de espécies e Modo Foto

A exploração e observação contemplativa convertem-se em vantagens táticas diretas de gameplay:

### Mecânica da Lente de Campo (Modo Foto)
- O jogador ativa a lente de observação à distância. Fotografar ou registrar espécimes vivos em seu comportamento natural sem assustá-los (alimentando-se, bebendo água, dormindo) gera **Pontos de Pesquisa Ecológica**.

### Níveis de Conhecimento no Catálogo
Conforme a pontuação de pesquisa daquela espécie sobe, o jogador desbloqueia camadas táticas no HUD:
1. **Nível 1 (Identificação de Espécie):** revela fraquezas elementais, resistências a dano (corte/perfuração/impacto) e tabela de partes anatômicas.
2. **Nível 2 (Anatomia em Tempo Real):** a mira e a câmera de combate destacam com um contorno translúcido as *hurtboxes* das partes quebráveis e sua barra de integridade individual.
3. **Nível 3 (Diagnóstico Genético de Campo):** através da lente de observação, o caçador consegue ler o genótipo do monstro selvagem à distância, identificando se ele possui mutações raras antes de iniciar a perseguição.
4. **Acervo Pessoal:** fotos tiradas em campo podem ser exportadas ou emolduradas em quadros decorativos na cabana do jogador.
