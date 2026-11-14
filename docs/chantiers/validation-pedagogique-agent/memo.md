# Memo — Validateur pédagogique des leçons

| | |
|---|---|
| **Type de cycle** | refactoring (processus des contenus) |
| **Statut** | livré (PR) |
| **Ouvert le** | 2026-11-14 |
| **Branche** | `validation-pedagogique-agent` |
| **Programme** | — |

---

## Le problème

Le processus des leçons renvoyait à « un enseignant » tout ce que le rédacteur et le relecteur IA ne tranchaient pas. Aucun enseignant ne relit : plus de 400 lignes de points restaient ouvertes dans une trentaine de journaux, et les leçons étaient livrées avec « Aucun enseignant ne les a relues ».

## Pour qui

- **L'élève**, qui lit les leçons : il a besoin d'un contenu juste, pas d'un brouillon.
- **L'équipe contenus**, qui ne relit plus le fond avant publication.

## Pourquoi maintenant

Décision du porteur du 2026-11-14 : l'étape « à faire valider par un enseignant » est supprimée et remplacée par un agent, dans le processus, avant la PR.

## Hors périmètre

- La production : l'agent ne la touche pas ; les corrections des leçons déjà publiées sont listées pour l'équipe ([`a-reporter-en-production.md`](a-reporter-en-production.md)).
- Les leçons de `docs/contenus/a-reprendre/` : rien ne les charge ; le validateur passera à leur retour.
- Les tests : aucun n'est assoupli.

## Décision

[ADR-XXXX-validateur-pedagogique-agent](../../decisions/adr/XXXX-validateur-pedagogique-agent.md).

## Lots

| Lot | Contenu |
|---|---|
| A | Agent `validateur-pedagogique`, processus (README des contenus, prompts, prompt de vague, plan de test, feuille de route, table des modèles, CLAUDE.md), ADR |
| B | Points en attente tranchés, une part par matière en parallèle (`decisions/`), leçons de `lecons-traitees/` corrigées, liste Avant / Après des leçons du train de production |
