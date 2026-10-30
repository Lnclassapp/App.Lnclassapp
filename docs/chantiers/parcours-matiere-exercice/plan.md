# Plan d'exécution — Parcours matière → exercice

> Un seul levier mesurable : la carte « Prochain exercice ». Un lot, vertical.

## Graphe

```
Lot A — carte « Prochain exercice » (matière + leçon)
```

## Contrat d'exécution

1. Le bench `mesure_parcours.js` donne la valeur avant (memo) ; il est versionné dans ce dossier.
2. Tests de la query et des écrans écrits d'abord, rouges.
3. Le levier, puis le bench relancé : chiffres dans `prd.md` §7 (au moins 3 passages, médiane).
4. **Le chantier ne se clôt pas sans mesure après.** Sans chiffre après, la PR est rejetée.

---

## Lot A — Carte « Prochain exercice » dans la matière et la leçon

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/catalog/next_exercise_query.rb` *(nouveau)*
                     `app/controllers/catalog/courses_controller.rb`
                     `app/views/catalog/courses/_next_exercise.html.erb` *(nouveau)*
                     `app/views/catalog/courses/index.html.erb` · `app/views/catalog/courses/show.html.erb`
                     `config/locales/` (clés `catalog.courses.next_exercise.*`)
                     `test/infrastructure/queries/catalog/next_exercise_query_test.rb` *(nouveau)*
                     `test/controllers/catalog/courses_controller_test.rb` (ou un fichier dédié)
                     `test/system/` : un parcours grille → feuille en 2 clics
- **Dépend de**    : —
- **Test associé** : CA-1 à CA-7 (PRD §4)
- **Done quand**   : grille → feuille en ≤ 2 clics, ≤ 50 mots et 0 px avant chaque cible, à 390 px et 1 280 px, mesuré par `mesure_parcours.js` au même volume ; couverture des lignes ajoutées 100 %
- **Hors lot**     : `catalog/courses/_exercise_row`, `assessment/exercises/*`, `assessment/exercise_sessions/*` (session parallèle)

## Portes de sortie

- [ ] Lot A `Done`, chiffres après dans `prd.md` §7
- [ ] Un rôle distinct de l'auteur a **exécuté** le résultat (bench relancé, parcours refait)
- [ ] Pureté du domaine, rubocop, tests, parcours système : au vert (`bin/ci-quiet`)
- [ ] UDR numérotée et indexée (`script/docs/build_index --number`)
- [ ] `journal.md` complété
