# Instruções para Agentes de IA (AGENTS.md)

Este arquivo define o protocolo de atuação para modelos de linguagem e agentes autônomos (Claude Code, Cursor, Copilot, ChatGPT, Gemini, Windsurf, Devin) que operam no repositório **godot-cepas-selvagens**.

---

## 🤖 Protocolo do Agente

1. **Leitura Obrigatória de Contexto:**
   - Antes de propor ou implementar código, consulte `PROJECT_CONTEXT.md` e os documentos relevantes em `docs/gdd/`, `docs/decisions/` e `docs/blocos/`.
   - Se for criar uma mecânica nova, consulte o bloco correspondente em `docs/blocos/`.

2. **Padrão de Resolução de Tipos (Godot 4.7):**
   - Para evitar `Parse Error: Could not find type "NomeDaClasse"`, declare `const _Classe = preload("res://caminho/para/classe.gd")` no topo do arquivo para qualquer classe personalizada utilizada em anotações de tipo ou exports.
   - Não invente caminhos; valide a localização real do arquivo antes de criar `preload(...)`.

3. **Verificação Obrigatória via Testes:**
   - Toda alteração deve ser validada executando:
     ```bash
     godot --path . --headless -s res://tests/run_all.gd
     ```
   - Nenhum teste existente pode quebrar. Se um teste falhar, analise e corrija o problema antes de submeter a alteração.

4. **Trabalho em Branches:**
   - Sempre trabalhe em uma branch derivada de `master` (ex.: `feature/...` ou `fix/...`).
   - Não faça commits diretos na `master`. Ao concluir a tarefa, prepare o PR para `master` referenciando a Issue do GitHub correspondente.

5. **Manutenção do Design e ADRs:**
   - Respeite ADR-0001 (sem atributos primários como FOR/INT).
   - Respeite ADR-0002 (servidor autoritativo e coop em mente).
   - Respeite ADR-0003 (dano como `HitEvent` via `CombatResolver`).
   - Respeite ADR-0005 (estoque empilhável por id, qualidade e traits).
   - Respeite ADR-0007 (7 encaixes estilo Albion, sem bônus de set artificial).
