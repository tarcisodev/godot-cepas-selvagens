# Guia de Contribuição — Cepas Selvagens

Obrigado por colaborar no **Cepas Selvagens**! Este guia define o fluxo oficial de desenvolvimento para desenvolvedores humanos e agentes de IA.

---

## 🎯 Princípios de Colaboração

1. **Design Antes de Código:** Antes de codificar um novo sistema, consulte `docs/gdd/` e `docs/decisions/`. Dúvidas conceituais devem ser alinhadas antes da implementação.
2. **Master Estável:** A branch `master` é a fonte da verdade e deve estar sempre verde (compilando e com todos os testes passando).
3. **Desenvolvimento em Branches Separadas:** Ninguém commita diretamente na `master`.

---

## 🌿 Ciclo de Vida de uma Tarefa

### 1. Issue / Epic no GitHub
- Toda nova mecânica, correção de bug ou bloco de desenvolvimento deve corresponder a uma **Issue** ou **Epic** no repositório GitHub.
- Exemplo de título de Issue: `[B24] Implementar colheita de plantas selvagens com foice`

### 2. Criando sua Branch
- Atualize a sua `master` local:
  ```bash
  git checkout master
  git pull origin master
  ```
- Crie uma branch específica:
  ```bash
  git checkout -b feature/b24-colheita-plantas
  # ou para bugs:
  git checkout -b fix/camera-offset-primeira-pessoa
  ```

### 3. Implementando e Testando
- Escreva seu código seguindo as convenções de GDScript do projeto.
- Crie ou atualize os testes em `tests/` para cobrir sua funcionalidade.
- Rode a suíte de testes:
  ```bash
  # Windows
  .\setup_project.ps1
  # Linux/macOS
  ./setup_project.sh
  ```
- **Certifique-se de que todos os testes passaram.**

### 4. Abrindo o Pull Request (PR)
- Suba sua branch para o repositório remoto:
  ```bash
  git push -u origin feature/b24-colheita-plantas
  ```
- Abra o Pull Request direcionado para a branch `master`.
- No texto do PR:
  - Descreva brevemente o que foi feito.
  - Vincule à Issue correspondente utilizando as palavras-chave do GitHub (ex: `Resolves #15` ou `Closes #22`).
  - Confirme que a suíte de testes foi executada com sucesso.

---

## 💻 Padrões de Código e Boas Práticas

### 1. Tipagem Estrita e Preload de Classes
Para evitar o erro clássico do Godot 4.x `Could not find type "X"`:
- Declare preloads explícitos no topo do script para classes referenciadas em tipos de variáveis ou parâmetros.
- Exemplo:
  ```gdscript
  const _CharacterDNA = preload("res://scripts/data/character_dna.gd")
  const _EquipmentPiece = preload("res://scripts/data/equipment_piece.gd")
  ```

### 2. Tratamento Seguro de Assets
- Ao instanciar cenas 3D (`PackedScene.instantiate()`), sempre cheque se o retorno não é nulo antes de acessar propriedades ou aplicar transforms.

### 3. Arquitetura Desacoplada
- Utilize `EventBus` (`scripts/core/event_bus.gd`) para desacoplar sistemas globais.
- Modificações de atributos devem usar a pilha de modificadores (`StatsComponent` e `ModifierData`), nunca atribuir valores brutos diretos em atributos primários inexistentes (ADR-0001).
- Toda interação física de dano deve gerar um `HitEvent` e ser resolvida via `CombatResolver` (ADR-0003).
