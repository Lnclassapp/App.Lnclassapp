# Plan — Corriger le texte d'une leçon à l'écran

Un lot, une PR. Suite du chantier `edition-lecon-equipe` (#598, menu ⋮), dont il reprend le Lot B prévu.

## Périmètre

- **Notion** : nom, « À retenir », étapes de « La méthode », énoncé et étapes de l'exemple corrigé, « Le piège à éviter ». Le nombre d'étapes ne change pas ; l'entraînement et la figure restent à l'import.
- **Exercice** : titre, sujet, indice ; par question : énoncé, corrigé, indice ; par proposition : texte, texte relié, et laquelle est juste (types à choix et liste).
- **Structure à l'import** (ADR-0116) : les identifiants envoyés sont exactement ceux qui existent, sinon `structure_changed`.
- **Bonne réponse changée** : permis ; tentatives passées inchangées, rien n'est recalculé.
- `ManageContentPolicy` ; journal `content.corrected`.

## Contrat d'exécution

1. Tests d'abord : use cases, repository (tentative ancienne inchangée, nouvelle jugée avec la nouvelle clé), contrôleurs (403, 422, succès), menu.
2. Les voir rouges, puis le code couche par couche.
3. Revues `security-reviewer` et `silent-failure-hunter`, puis `bin/ci-quiet` ; `test/integration/{catalog,classroom}` et `test/controllers/{teams,catalog}` joués avant la PR.

## Portes de sortie

- [x] Tests rouges vus, puis verts
- [x] Refus : hors équipe (403), structure changée (422), texte vide ou trop long (422)
- [x] Tentative ancienne inchangée après changement de la bonne réponse ; nouvelle tentative jugée avec la nouvelle
- [x] ADR-0113 amendé (§4.6, coûts consentis) ; UDR-0042 amendée (entrée « Modifier le texte »)
- [x] Captures 390 px et ordinateur envoyées
- [x] Revues sécurité et pannes silencieuses rendues et traitées (journal)
