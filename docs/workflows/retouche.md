# Cycle Retouche

> Le chemin court pour un petit changement **sans règle métier** : pas de memo, pas de PRD, pas d'UDR, une PR directe.
> Processus maître : [`README.md`](README.md). Origine : proposition 8 du rapport sur la méthode de travail (2026-11-05) — depuis le 9/10, 111 memos, 42 ADR et 75 UDR, soit 4 chantiers par jour ; un carrousel ou des libellés courts passaient par le cycle complet.

Branche : `fix/retouche-<slug>` · Dossier : aucun · Trace : une ligne dans le journal du chantier parent, sinon dans [`docs/chantiers/retouches/journal.md`](../chantiers/retouches/journal.md)

## Quand c'est une retouche

**Toutes** ces conditions sont vraies :

| Condition | Exemple qui passe | Exemple qui ne passe pas |
|---|---|---|
| Une vue, un fichier, ou quelques lignes liées (≤ 3 fichiers hors tests) | un libellé, un espacement à 390 px, une icône, une faute dans une leçon | un écran nouveau |
| Aucune règle métier ni droit d'accès ne change | aligner un bouton | qui peut voir le bouton |
| Aucun use case, policy, route, migration, port ou téléversement touché | une classe Tailwind, une clé I18n | un paramètre de contrôleur en plus |
| Aucun motif d'interface nouveau | réutiliser un composant existant | un nouveau type de carte (→ UDR) |

Une seule est fausse : ce n'est pas une retouche. Règle ou droit → `/feature` ou `/bugfix`. Motif nouveau → `/feature` (UDR). En cas de doute, ce n'est pas une retouche.

## Les 5 phases, en court

| Phase | Ce qu'on fait |
|---|---|
| 1. Cadrer | Une phrase : ce qui change et pourquoi, dans la description de la PR |
| 2. Décider | Rien : la retouche applique une décision existante (UDR, design system). Elle cite l'UDR qu'elle suit, s'il y en a une |
| 3. Planifier | Rien |
| 4. Exécuter | Le test qui couvre le fichier touché, adapté si besoin ; un seul commit |
| 5. Prouver | `bin/ci-quiet` et sa ligne de preuve dans la PR ; pour une vue, captures 390 px et ordinateur envoyées au porteur, jamais commitées |

Trace : une ligne dans `## Retouches` du `journal.md` du chantier parent (celui qui a créé l'écran ou la règle), sinon dans `docs/chantiers/retouches/journal.md` :

```markdown
- 2026-11-06 · #<PR> · <ce qui change, en une phrase>
```

## Ce qu'une retouche ne fait jamais

- Changer une règle, un droit, une donnée ou un contrat, même « petit ».
- Grossir en route : dès qu'une condition tombe, la retouche s'arrête et devient un chantier.
- Sauter la preuve : la ligne `bin/ci-quiet` et, pour une vue, les captures restent obligatoires.
