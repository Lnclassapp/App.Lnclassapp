# Plan d'exécution — Sujets de devoir Thalès, titres numérotés des feuilles, correction en bloc

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot 0 — memo, plan (fait)
  ├─► Lot A — contenu : 4 sujets Thalès, figures   ┐ en parallèle
  └─► Lot B — écran : titres numérotés, correction  ┘
```

### Lot A — Quatre sujets de devoir Thalès, avec les figures de la maquette

- **Couche**      : contenu (+ test d'intégration du pilote)
- **Fichiers**    : docs/contenus/lecons-traitees/3eme/mathematiques/proprietes-de-thales-dans-un-triangle.json
                    docs/contenus/README.md
                    test/integration/catalog/pilot_lessons_test.rb
                    (si une figure exige un nouveau type : le fichier du type de figure et son test, à signaler)
- **Dépend de**   : Lot 0
- **Test associé**: test/integration/catalog/pilot_lessons_test.rb ; import réel par `UseCases::Catalog::RunImport`
- **Done quand**  : l'import du fichier crée 4 sujets de 4 exercices, avec figures, et la leçon montre 4 feuilles « Prépare devoirs »

### Lot B — Titres « Prépare interros n°N » / « Prépare devoirs n°N », correction en un bloc par exercice

- **Couche**      : ui (+ query si besoin)
- **Fichiers**    : app/views/catalog/courses/sheets/_sheet.html.erb
                    app/views/assessment/session_results/ (vue de résultat d'une copie)
                    config/locales/fr.yml
                    docs/decisions/udr/0149-feuilles-prepare-interros-et-devoirs.md (amendement daté)
                    tests de contrôleur et système correspondants
- **Dépend de**   : Lot 0
- **Test associé**: test/controllers/catalog/courses_controller_test.rb ; tests de session_results
- **Done quand**  : chaque feuille s'intitule « Prépare interros n°N » ou « Prépare devoirs n°N » ; après vérification ou rendu, la correction d'un exercice s'affiche en un seul bloc « a. … b. … »

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/locales/fr.yml` | Lot B |
| `docs/contenus/…/proprietes-de-thales-dans-un-triangle.json` | Lot A |

## Portes de sortie

`bin/ci-quiet` vert sur le head final, ligne de preuve dans la PR ; captures 390 px et ordinateur envoyées à Touré ; challenger empirique : un rôle distinct de l'auteur importe le fichier, ouvre la leçon, refait « Vérifier ma réponse » et lit la correction en bloc.
