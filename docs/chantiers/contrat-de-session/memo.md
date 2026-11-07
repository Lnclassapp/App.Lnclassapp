# Memo — Contrat de session

| | |
|---|---|
| **Type de cycle** | refactoring *(processus, aucun comportement produit)* |
| **Statut** | livré |
| **Ouvert le** | 2026-11-05 |
| **Branche** | `chore/contrat-de-session` |
| **Programme** | — |

---

## Le problème

Mesures sur les 123 sessions Claude Code du 26/09 au 5/11/2026 (rapport sur la méthode de travail, 2026-11-05) :

| Mesure | Valeur |
|---|---|
| Sessions restées bloquées sur une question | 23 (19 %) |
| Questions types | « Veux-tu que je surveille la PR ? » (lots D6, D7, E2, E4), « A ou B ? » (écrans élève), règle métier non cadrée (lot D8), libellé (cartes d'exercices), « je poste le commentaire ? » (vérif CI) |
| Identifiants de recette | redonnés et corrigés dans le chat ; recette connectée sur Staging sautée faute de compte |

L'agent `executant-lot` avait pour consigne de s'arrêter et de poser la question sur toute décision non tranchée : chaque question arrête une session jusqu'à ce que le porteur l'ouvre.

## Pour qui

Le porteur (temps, nombre de sessions à rouvrir) et les sessions enfants (moins d'arrêts).

## Ce qui change

| # | Règle | Où |
|---|---|---|
| 1 | Zéro question en fin de session : PR surveillée d'office ; décision réversible appliquée et notée dans `## À trancher` ; décision non réversible écrite au même endroit, seul ce point attend | `docs/workflows/contrat-de-session.md` §1, `CLAUDE.md`, `executant-lot`, `plan-lots` étape 5, `prompt-vague.md`, modèle de journal |
| 2 | Décisions ouvertes posées en un seul `AskUserQuestion` avant tout lancement ; boîte de décisions quotidienne à 12 h (Abidjan) | §2, modèle de plan, `script/docs/a_trancher`, tâche programmée |
| 3 | Secrets dans l'environnement Claude Code, jamais dans le chat ; comptes de recette = jeu standard | §3, `CLAUDE.md` ; comptes sur Staging : chantier `comptes-de-test-staging` |

## Hors périmètre

- Les sessions déjà bloquées : la première boîte de décisions les relève.
- Hook qui refuserait un secret collé dans un message : à reconsidérer si la règle ne suffit pas.

## Preuve

Dans 30 jours : part des sessions bloquées (cible : moins de 5 %), nombre d'entrées `## À trancher` traitées par la boîte (`script/docs/a_trancher --count`). Sans chiffre meilleur, la règle est retirée.
