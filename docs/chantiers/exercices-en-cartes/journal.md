# Journal — Les exercices en cartes

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Un partial rendu sans `index:` ni `extra:` plante sur ces noms (« undefined local variable ») : un local facultatif se lit par `local_assigns[:nom]`.
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
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
