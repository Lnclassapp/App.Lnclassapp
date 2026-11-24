# Memo — Fiche : formules dans les listes de l'entraînement

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | prouvé |
| **Ouvert le** | 2026-11-24 |
| **Branche** | `fix/fiche-listes-formules` |
| **Programme** | — |

---

## Symptôme

Dans la fiche d'une leçon, bloc « Je m'entraîne » : le menu d'une question « choix dans une liste » montre `$e^{7}$`, `$\ln 7$` ; les menus « Étape n » d'un ordre montrent `$S = \{\ln 7\}$` ; ceux de « relier » montrent `$2$`. Attendu : des formules lisibles, comme dans le reste de la fiche (ADR-0051, UDR-0147 §3.3). Suite du chantier `premier-exercice-formules-soumission` (UDR-0183, même défaut sur la copie).

## Reproduction

- Acteur : élève, `/courses/:slug/fiche`, notion avec entraînement.
- Données : une question `select`, `ordering` ou `matching` dont une proposition contient `$…$` (3 937 `select`, 3 709 `ordering`, 4 627 `matching` dans `docs/contenus` ; formules dans 301 `ordering` et 444 `matching`, et dans les `select` de maths, ex. *Fonction exponentielle népérienne*, Tle A2).
- Reproduit en local à 390 px (test système d'exploration, non commité) : les options lues sont `["$e^{7}$", "$\ln 7$", "$S = \{\ln 7\}$", "$e^x = 7$", …, "$1$", "$2$"]`. Le texte autour (phrase, libellés de gauche de « relier ») est rendu.

## Portée

- Depuis l'entraînement dans la fiche (UDR-0147). Tous les élèves ; rendu pur, sans lecture de classe ni d'école (multi-appartenance sans objet). L'enseignant voit la même fiche.
- Données : aucune. Les valeurs postées sont des indices d'affichage, inchangés.

## Hors périmètre

- La copie d'exercice : faite (UDR-0183).
- Formule coupée par une case (`$A_7^3 = ___$`) : chantier `formule-coupee-par-une-case`.
- Le jugement de la réponse (`UseCases::Catalog::CheckPractice`) : non touché.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quel document dit que la formule doit être rendue ? | ADR-0051, UDR-0147 §3.3 ; UDR-0183 pour la règle des menus | Bug, même règle qu'UDR-0183 |
| Diffère-t-il de la copie ? | Oui : dans la fiche, ordre et relier sont des menus visibles (pas de cartes JavaScript) | Le correctif couvre les trois menus de la fiche |
| Données à réparer ? | Non | Un seul lot |

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [x] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [x] Test au vert · suite du contexte borné au vert
- [x] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [x] Données déjà corrompues : réparées, ou dette explicitement notée au journal
- [x] Challenger a rejoué les étapes de reproduction dans l'application
- [x] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés

## Contrat d'exécution (lot unique)

1. Test système `test/system/catalog/practice_formulas_in_lists_test.rb` : une notion avec `select`, `ordering`, `matching` en formules ; aucune option ne contient `$` ni `\`, les propositions se lisent rendues (`.katex`), « Vérifier » juge juste une réponse choisie par sa formule.
2. Le lancer : rouge pour la bonne raison (options en LaTeX brut).
3. Corriger `app/views/catalog/practice_checks/_question.html.erb` (la cause est dans la vue) : règle d'UDR-0183, aux styles du cahier.
4. Vert, puis `test/controllers/catalog/practice_checks_controller_test.rb` et `test/system/catalog/practice_in_sheet_test.rb`.
5. Cas symétrique : une liste de mots garde ses libellés dans le menu.
