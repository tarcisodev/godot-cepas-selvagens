# B29: Composteira de Monstros, Tanque de Aquicultura & Conhecimento Ecológico

## Visão Geral
Implementação da infraestrutura de rancho para decomposição e processamento biológico de biomassa e fauna aquática (GDD-04, GDD-08 §5, GDD-10 §9), aliada ao sistema de Conhecimento e Pesquisa Ecológica em 3 níveis (GDD-04 §5) integrado ao visor do Modo Foto.

---

## 1. Peças Modulares de Rancho (GDD-08 §5)

### 1.1 Composteira de Monstros (`PieceType.COMPOSTEIRA`)
- **Custo:** `{ &"madeira": 4, &"pedra": 2, &"ossos": 2 }`
- **Tamanho:** `Vector3(1.4, 0.9, 1.4)`
- **Visual:** Caixa rústica de ripas de madeira com leito orgânico decomposto escuro e prompt `[E] Composteira (Adubar)`.
- **Mecânica de Compostagem:**
  - Consome 2x `ossos`, 1x `visceras`, 1x `carne_pequena`, 1x `carne_media` ou 4x `folha`.
  - Produz 1x `adubo_organico` (Qualidade 3, Trait `mineralizado`).
  - Fornece método `compost(player, specific_mat)`.

### 1.2 Tanque de Aquicultura (`PieceType.TANQUE_PEIXE`)
- **Custo:** `{ &"madeira": 4, &"pedra": 4, &"quartzo_lume": 2 }`
- **Tamanho:** `Vector3(1.8, 1.1, 1.8)`
- **Visual:** Tanque de alvenaria de pedra com leito aquífero translúcido de quartzo e prompt `[E] Tanque de Peixes (Aquicultura)`.
- **Mecânica de Processamento de Peixes:**
  - Aceita peixes obtidos pela pesca (`peixe_lambari`, `peixe_traira`, `peixe_dourado`).
  - Extrai 1x `oleo_peixe` (Qualidade 3, Trait `purificado`).
  - Peixes de qualidade >= 3 ou espécimes lendários como o `peixe_dourado` rendem 2x `oleo_peixe`.
  - Fornece método `process_fish(player)`.

---

## 2. Novos Materiais (`MaterialData`)

1. **Adubo de Monstro (`adubo_organico.tres`):**
   - Categoria: `PLANTA` (Fertilizante mineralizado).
   - Descrição: Enriquecido com cálcio de ossos e minerais de monstros. Acelera em +50% o crescimento vegetal e dobra a chance de mutações.
   - Peso unitário: 0.5 kg | Valor base: 8 $S.

2. **Óleo de Peixe Purificado (`oleo_peixe.tres`):**
   - Categoria: `MINERAL` (Solvente purificado).
   - Descrição: Óleo biológico refinado nos tanques de aquicultura. Solvente essencial para resinas e têmpera metalúrgica.
   - Peso unitário: 0.4 kg | Valor base: 12 $S.

---

## 3. Botânica e Adubação (`PlantBody` & `Ecology`)

- **Propriedade `is_fertilized: bool`:** Registra estado adubado da planta.
- **Método `fertilize() -> bool`:** Aplica adubo, emite faíscas brilhantes e bloqueia re-adubação redundante.
- **Ciclo de Vida:** Em `life_tick()`, plantas adubadas progridem a uma velocidade de 1.5× (+50%).
- **Interação no Vale (`Ecology.fertilize_plant(plant, player)`):**
  - Verifica e consome 1x `adubo_organico` do inventário do jogador.
  - Acelera o espécime e eleva a probabilidade de sementes mutantes.

---

## 4. Componente de Conhecimento Ecológico (`EcologyKnowledgeComponent`)

Rastreia pontos de pesquisa ecológica para cada espécie do Vale das Cepas (`trotador`, `planador`, `saltarelo`, `rinolito`, `lobo`, `tatu`, `lambari`, `traira`, `dourado`, `pinheira`).

### Tiers de Pesquisa (GDD-04 §5):
1. **Nível 1 (25 pts) — Análise Fisiológica:**
   - Revela fraquezas elementais/físicas da criatura (ex.: Corte, Fogo, Impacto).
   - Desbloqueia o mapa de partes anatômicas quebráveis (chifres, carapaça, cauda).
2. **Nível 2 (60 pts) — Diagnóstico em Tempo Real:**
   - Permite monitoramento contínuo da integridade anatômica das partes em combate.
3. **Nível 3 (120 pts) — Genética de Campo:**
   - Desbloqueia o scanner genético no visor do Modo Foto, revelando os pares de alelos exatos (`TT/Tt/tt`, `CC/Cc/cc`, `PP/Pp/pp`) e mutações ativas (`*`) antes da caça.

### Fontes de Pontos de Pesquisa:
- **Fotografia no Modo Foto:** +15 pts por foto focada.
- **Esfola e Coleta Anatômica:** +10 pts por parte colhida.
- **Captura com Laço/Sedativo:** +20 pts.

---

## 5. Integração com Modo Foto & Jogador

- O leitor ótico da câmera fotográfica (`PhotoModeScreen`) consulta dinamicamente `player.ecology`:
  - Se Nível >= 1: exibe `⚔️ Fraquezas: [fraquezas]`.
  - Se Nível >= 3: exibe `🧬 Genótipo: [P:TT C:Cc S:pp] ★ MUTANTE`.
  - Ao bater a foto (`take_photo`), incrementa +15 pontos no compêndio do jogador.
- O jogador (`Player`) possui instância integrada de `_EcologyKnowledgeComponent`, persistida no ciclo de save do jogo.

---

## 6. Testes Automatizados
- Arquivo: `tests/test_ecology_and_aquaculture.gd`
- Total de asserções cobrindo compostagem com múltiplos materiais, extração de óleo simples e duplicado, adubação de canteiros, curva de níveis de ecologia e scanner genético da câmera.
