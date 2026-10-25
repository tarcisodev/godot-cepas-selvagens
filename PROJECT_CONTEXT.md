# Contexto do Projeto: Cepas Selvagens (Godot 4.7)

> **Documento de Contexto Universal para IAs e Desenvolvedores**
> Leia este documento antes de iniciar qualquer alteração no código.

---

## 1. Visão Geral e Pilares

**Cepas Selvagens** é um Sandbox Action RPG / MMORPG em desenvolvimento no **Godot 4.7** (Forward Plus, GDScript).

### Os 5 Pilares de Design:
1. **Combate de Ação e Caça Anatômica:** A classe é definida pelo estilo de arma e armadura equipada. Criaturas possuem partes quebráveis (`AnatomyComponent`, `HitEvent`) que dropam materiais específicos.
2. **Forja Modular com Qualidade:** Itens não têm atributos estáticos; são forjados combinando **Núcleo + Revestimento + Tempero**, gerando peças (`ForgedItem`) com atributos derivados, traits e estrelas (1★ a 5★).
3. **Progressão por Uso:** Sem atributos primários (FOR, AGI, INT). O personagem evolui maestrias ao praticar (espada, forja, corrida, culinária).
4. **Ecologia Viva e Genética:** Fauna e flora procedurais com ciclos dia/noite, chuva, estações, comportamento animal e montarias domáveis.
5. **Economia Guiada pelos Jogadores:** Dólares de Sucata (`WalletComponent`), mercado da vila (`VillageMarket`) e trocas diretas.

---

## 2. Decisões Arquiteturais Fundamentais (ADRs)

- **ADR-0001 (Sem Atributos Primários):** Status são derivados exclusivamente de equipamentos, modificadores temporários (`ModifierData`) e maestria.
- **ADR-0002 (Servidor Autoritativo):** `NetworkManager` suporta tanto single-player offline como sessões coop LAN / servidor dedicado para até 16 jogadores com sincronização de avatares, céu e dano autoritativo.
- **ADR-0003 (Dano como Evento):** Todo dano transita como uma instância de `HitEvent` processada pelo `CombatResolver` centralizado, evitando espalhar cálculos de defesa e resistências nos scripts dos atores.
- **ADR-0004 (Personagens Procedurais sobre Rig UAL):** O modelo base utiliza esqueleto universal de 65 ossos (Quaternius UAL1/UAL2), permitindo que qualquer animação funcione em avatares procedurais (`CharacterDNA`).
- **ADR-0005 (Estoque em Pilhas por Id, Qualidade e Traits):** Materiais são empilhados estritamente quando `id`, `quality` e `traits` coincidem.
- **ADR-0006 (Relógio Único do Mundo):** O tempo avança de forma contínua e compartilhada; descansar em fogueiras acelera regeneração, mas não pula o horário do mundo.
- **ADR-0007 (Encaixes Estilo Albion):** 7 encaixes de equipamento (`Cabeça`, `Peito`, `Botas`, `Mão Principal`, `Mão Secundária`, `Capa`, `Mochila`). Famílias definidas pelo material de revestimento (`Pano`, `Couro`, `Ferro`), sem bônus artificiais de conjunto.

---

## 3. Diretrizes Técnicas Críticas para Godot 4.7

### 3.1. Resolução de Tipos e "Could not find type" (Padrão de Preload)
O Godot 4.x pode apresentar erros de análise sintática (`Parse Error: Could not find type "X"`) ao carregar scripts interdependentes antes da indexação do editor ou em autoloads.

**Regra obrigatória:**
Sempre que um script referenciar classes customizadas em tipagens de variáveis ou exports (`StyleAttack`, `EquipmentPiece`, `CharacterDNA`, `CharacterVisual`, `PoolsComponent`, `HitEvent`, `DamageType`, `CombatResolver`), declare explicitamente a constante de preload no topo do script:

```gdscript
# Exemplo no topo de scripts de dados ou controladores:
const _DamageType = preload("res://scripts/data/damage_type.gd")
const _EquipmentPiece = preload("res://scripts/data/equipment_piece.gd")
const _StyleAttack = preload("res://scripts/data/style_attack.gd")
const _CharacterDNA = preload("res://scripts/data/character_dna.gd")
```

### 3.2. Importação de Assets 3D (.gltf / .glb)
Arquivos `.gltf` e `.glb` em `assets/` são convertidos para o cache `.godot/imported/*.scn`.
Se o diretório `.godot/` for limpo ou se o repositório for recém-clonado:
- Execute `.\setup_project.ps1` (Windows) ou `godot --headless --editor --quit` para disparar a importação em lote e geração do cache de classes globais.
- Nunca commite a pasta `.godot/` (ela está no `.gitignore`).

---

## 4. Fluxo de Trabalho de Colaboração (Git & GitHub)

1. **Master é Intocável:** Nunca desenvolva diretamente na `master`. A branch `master` deve permanecer compilando e com 100% dos testes passando.
2. **Branch por Feature / Bloco:**
   - Crie uma nova branch a partir de `master`:
     `git checkout -b feature/nome-da-feature`
3. **Issues e Epics:**
   - Todo trabalho deve estar atrelado a uma Issue ou Epic no GitHub.
4. **Pull Requests (PR):**
   - Ao finalizar a implementação e validar os testes locais, abra um PR para a `master`.
   - Adicione no corpo do PR a menção à issue (ex.: `Closes #12`).
5. **Critério de Aceitação:**
   - Executar `tests/run_all.gd` e garantir `33/33 testes passaram`.

---

## 5. Como Executar Testes

O projeto possui um test runner unificado em headless:
```powershell
# No PowerShell (usando o console Godot):
$godot = (Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "*godot*console.exe").FullName
& $godot --path . --headless -s res://tests/run_all.gd
```
Ou simplesmente execute:
```powershell
.\setup_project.ps1
```

---

## 6. Mapeamento de Arquivos Principais

- `scripts/player.gd`: Controlador principal do jogador (movimentação, posturas, combate, esquiva com i-frames, berrante, pesca, tocha).
- `scripts/core/network_manager.gd`: Autoload de rede autoritativa e coop LAN.
- `scripts/systems/combat_resolver.gd`: Resolução matemática de acertos, quebra de partes e postura.
- `scripts/systems/forge.gd`: Lógica de receitas e crafting modular.
- `scripts/components/gear_visual.gd`: Montagem visual procedural das peças de armadura no esqueleto UAL.
- `scripts/ui/equipment_panel.gd`: Painel de boneco 3D interativo e 7 slots de equipamento.
- `scripts/ui/inventory_screen.gd`: Inventário com grade de pilhas, ordenação e filtros.
- `scripts/ui/forge_screen.gd`: Interface interativa da bigorna.
- `docs/gdd/`: Documentos de design completos do jogo.
- `docs/blocos/`: Roadmap e blocos de execução técnica (B01 a B23).
- `docs/decisions/`: ADRs com justificativas de design.
