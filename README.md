# Cepas Selvagens 🌿⚔️

> **Sandbox Action RPG / MMORPG de Alta Magia em Godot 4.7**
> Focado em exploração contemplativa, ecologia viva, caça anatômica e economia guiada pelos jogadores.

---

## 🧭 Visão do Projeto

- **Design antes de código:** Cada sistema é concebido no GDD (`docs/gdd/`), registrado em ADRs estruturais (`docs/decisions/`) e executado em blocos verticais testados (`docs/blocos/`).
- **Sem atributos primários:** Não há FOR/INT/AGI ou níveis de classe fixos (ADR-0001). A classe sai dos 7 encaixes de equipamento e da maestria por uso.
- **Dano como evento:** Todo impacto é um `HitEvent` avaliado pelo `CombatResolver` com partes quebráveis anatômicas (ADR-0003).
- **Servidor autoritativo:** Arquitetura desacoplada pronta para multiplayer Coop LAN / dedicado (ADR-0002).
- **Economia e Estoque:** Materiais empilháveis por `(id, qualidade, traits)` (ADR-0005) e forja modular com núcleo, revestimento e tempero (GDD-06 / GDD-12).

---

## 🚀 Setup Rápido (Novos Colaboradores & IAs)

### Pré-requisitos
- **Godot 4.7+** (com Forward Plus). Se estiver no Windows:
  ```powershell
  winget install GodotEngine.GodotEngine
  ```

### 1. Inicialização do Projeto e Importação de Assets
Ao clonar o repositório pela primeira vez, os arquivos `.gltf`, modelos 3D e texturas precisam ser importados pelo Godot para gerar o cache em `.godot/imported/` e o índice de classes:

- **Windows (PowerShell):**
  ```powershell
  .\setup_project.ps1
  ```
- **Linux / macOS:**
  ```bash
  chmod +x ./setup_project.sh
  ./setup_project.sh
  ```

Ou manualmente pelo terminal:
```bash
godot --headless --editor --quit
godot --path . --headless -s res://tests/run_all.gd
```

### 2. Rodar a Suíte Completa de Testes
O projeto conta com mais de 30 suítes de testes automatizados cobrindo combate, montarias, forja, inventário, biomas, rede e UI:
```bash
godot --path . --headless -s res://tests/run_all.gd
```
*Critério de aprovação: 33/33 arquivos de teste passando.*

---

## 🌳 Fluxo de Trabalho (Git, Branches, Issues e PRs)

Para manter a `master` estável e funcional para todas as IAs e desenvolvedores:

1. **Master sempre verde:** A branch `master` contém código validado que passa 100% nos testes.
2. **Branch por Tarefa / Bloco:**
   - Crie uma branch para sua atividade a partir de `master`:
     ```bash
     git checkout -b feature/b24-nome-do-bloco
     # ou
     git checkout -b fix/ajuste-colisao-montaria
     ```
3. **Epics & Issues no GitHub:**
   - Toda funcionalidade ou bloco do roadmap deve ter uma **Issue** ou **Epic** no GitHub vinculada.
4. **Pull Requests (PR):**
   - Ao finalizar e testar, abra um PR para a `master`.
   - Referencie a issue no PR (ex: `Resolves #42` ou `Closes #15`).
   - O PR só é mergeado após validação de testes (`run_all.gd`).

Consulte [CONTRIBUTING.md](CONTRIBUTING.md) para detalhes completos de convenções de código e arquitetura.

---

## 📚 Documentação e Contexto

Toda a documentação vinda do design original (Obsidian) está centralizada na pasta `docs/`:

- **[docs/project_overview.md](docs/project_overview.md)**: Panorama geral do projeto, escopo, pessoas e roadmap.
- **[docs/gdd/](docs/gdd/)**: Game Design Documents detalhados (`GDD-00` a `GDD-15`), incluindo combate, ecologia, forja, culinária e guilds.
- **[docs/decisions/](docs/decisions/)**: Architecture Decision Records (`ADR-0001` a `ADR-0007`).
- **[docs/blocos/](docs/blocos/)**: Especificações dos blocos executáveis de desenvolvimento (`B01` a `B23`).
- **[PROJECT_CONTEXT.md](PROJECT_CONTEXT.md)**: Contexto universal para agentes de IA e copilots.

---

## 🛠️ Estrutura de Pastas

```
godot-cepas-selvagens/
├── assets/          # Modelos 3D (Quaternius), sons, texturas e animações
├── docs/            # GDDs, ADRs, Blocos de execução e Ideias
├── resources/       # Recursos Godot (.tres) de armas, UI, cosméticos
├── scenes/          # Cenas (.tscn): player, mundo, HUD, interfaces
├── scripts/
│   ├── components/  # Componentes modulares (Stats, Pools, GearVisual, etc.)
│   ├── core/        # Autoloads, eventos, rede autoritativa e limites
│   ├── creatures/   # IA de monstros, fauna, montarias e chefes
│   ├── data/        # Modelos de dados puros (DNA, HitEvent, ForgedItem)
│   ├── ecology/     # Ciclo dia/noite, clima, céu celestial, frutos
│   ├── systems/     # Forja, combate, cartas, proceduralismo
│   ├── town/        # NPCs, estações da vila, taverna, fogueira
│   ├── ui/          # Telas de inventário, forja, mapa, HUD, cursores
│   └── world/       # Loot jogado no chão, trilhas, santuários
├── tests/           # 33+ suítes de testes unitários e de integração
└── setup_project.ps1 # Script de bootstrap para reimportar e validar
```
