---
name: retouche
description: Fait une retouche Lnclass — un petit changement sans règle métier (libellé, espacement, icône, faute, classe CSS, clé I18n) en une PR directe, sans memo ni UDR. Utilise-la quand l'utilisateur tape /retouche <slug>, ou demande un changement d'une vue ou d'un fichier qui ne touche ni règle, ni droit, ni use case, ni route, ni migration.
---

# Cycle Retouche

Tu exécutes `docs/workflows/retouche.md`. **Lis-le maintenant.** Argument : un `<slug>` kebab-case ; s'il manque, déduis-le de la demande.

## Étape 0 — Est-ce une retouche ?

Vérifie toi-même les quatre conditions du tableau (≤ 3 fichiers hors tests ; aucune règle ni droit ; aucun use case, policy, route, migration, port ou téléversement ; aucun motif d'interface nouveau). Ne les pose pas au porteur. Une seule est fausse : dis-le en une ligne et bascule vers le cycle qui convient (`/feature`, `/bugfix`, `/refactor`).

## Étape 1 — Faire

1. Branche `fix/retouche-<slug>` depuis `Develop` à jour.
2. Le changement, et le test qui couvre le fichier touché (adapte-le s'il vérifie l'ancien rendu). En-tête HITL et I18n comme partout.
3. Une ligne dans `## Retouches` du journal du chantier parent, sinon dans `docs/chantiers/retouches/journal.md` : `- AAAA-MM-JJ · #<PR> · <ce qui change>` (numéro de PR ajouté après ouverture, dans le même commit amendé avant le push ou au commit suivant).
4. Un seul commit : `fix(retouche-<slug>): <ce qui change>`.

## Étape 2 — Prouver et livrer

- `bin/ci-quiet` sur le head final ; sa ligne de preuve va dans la PR.
- Une vue touchée : captures 390 px et ordinateur, envoyées au porteur, jamais commitées.
- PR prête vers `Develop`. Contrat de session : tu la surveilles, tu ne finis pas sur une question.
