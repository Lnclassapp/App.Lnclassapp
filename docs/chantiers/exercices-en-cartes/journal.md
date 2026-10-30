# Journal — Les exercices en cartes

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-30 | Les cartes d'exercice et de question restent dans la marge au téléphone (`data-bleed-keep`) | Bord à bord (UDR-0005), une liste de cartes se relit comme des lignes ; vu sur les captures à 390 px | Non (UDR-0145 §3.1, §3.3) |
| 2026-10-30 | Un type d'exercice manquant lève, une matière inconnue prend l'illustration de repli | Revue « échecs silencieux » : un défaut de câblage ne doit pas effacer une information sans bruit | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Un partial rendu sans `index:` ni `extra:` plante sur ces noms (« undefined local variable ») : un local facultatif se lit par `local_assigns[:nom]`.
- La numérotation de l'UDR a été posée avant de fusionner `Develop` : la session parallèle venait de prendre 0143 et 0144. Annulée, `Develop` fusionné, relancée : UDR-0145. Fusionner `Develop` **avant** `build_index --number`.
- `whitespace-pre-line` sur un `<p>` dont l'ERB est indenté rend l'indentation : un grand blanc avant l'énoncé de chaque question, vu seulement sur capture.
- Le test système `catalog/course_catalog_test.rb:92` (« la page n'a pas été rafraîchie par morphing ») échoue sans notre code aussi (vérifié sur l'arbre propre) : hors lot.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `grade_class` (BadgesHelper) donne déjà vert dès 14/20 / encre sinon : la carte le réutilise ; « sous 10/20 » est `!Grading.reaches?(score, PASS_THRESHOLD)`.
- Les lignes de lecture n'avaient ni `exercise_type` (Ma classe, suivi) ni `material_slug` (suivi de classe, leçon) : ajoutés aux queries, la carte ne lit rien d'autre.
- Le bloc facultatif de la carte passe par le local `extra:` (HTML capturé), plus sûr que `yield`, qui lirait le gabarit englobant dans un partial sans bloc.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Clés de locale devenues mortes (`classroom.student_classrooms.treated_exercise.best`, `classroom.classrooms.assigned_exercises.pending`, `catalog.courses.show.to_review` / `due` / `due_today` / `question_count` si plus lues) | Fichiers de locale d'autres écrans, partagés avec la session parallèle | Nettoyage i18n au prochain chantier qui touche ces écrans |
| `test/system/catalog/course_catalog_test.rb` (morphing) rouge sans ce chantier | Hors périmètre, déjà rouge sur `Develop` | À signaler au porteur |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-30 |
| **PR** | vers `Develop` |
| **ADR produits** | aucun |
| **UDR produits** | UDR-0145 |
