# Archives

Documents gelés. **Ils ne font plus foi.** Ils sont conservés parce qu'ils expliquent des intentions passées, pas parce qu'ils décrivent le fonctionnement actuel.

Si tu cherches comment on travaille aujourd'hui : [`../README.md`](../README.md).

## Pourquoi ces documents sont ici

La v1 de la documentation contenait **trois workflows concurrents et divergents** — l'un plaçant les décisions avant le code, l'autre après, le troisième ignorant entièrement les UDR. `CLAUDE.md` désignait le moins instancié des trois. C'est la cause directe de deux des trois problèmes que la v2 corrige : « personne ne suit la doc » et « qualité inégale ».

Un processus qui existe en trois versions n'existe pas.

## Contenu

| Document | Ce qu'il était | Remplacé par |
|---|---|---|
| `WORKFLOW.md` | Workflow agentique en 4 phases (ADR+UDR avant le code) | [`../workflows/README.md`](../workflows/README.md) |
| `STANDARD/workflow.md` | Workflow en 5 étapes (MEMO → PRD → Plan → Code → ADR) | idem — sa phase « Loter les tâches » a été reprise et durcie |
| `STANDARD/CHEATSHEET.md` | Workflow en 3 phases + section « Maximiser Gemini » | idem |
| `STANDARD/hitl_docstrings.md` | Norme des en-têtes HITL, 9 templates + micro-documentation obligatoire | [`../guide/conventions.md`](../guide/conventions.md#5-en-tête-hitl) — allégé à 3 lignes |
| `STANDARD/ai_skills_guide.md` | Catalogue de ~23 skills, ciblant Antigravity | `.claude/skills/` |
| `MIGRATION_MAP.md` | Carte de la migration hexagonale (Strangler Fig) | Migration achevée ; les chantiers vivent dans [`../chantiers/`](../chantiers/) |
| `tickets/` | 3 tickets, dont les cases à cocher contredisaient le statut déclaré | [`../chantiers/`](../chantiers/) |
| `README.md` (ancien) | Index décrivant une arborescence à 6 piliers qui n'a jamais existé ici | [`../README.md`](../README.md) |
