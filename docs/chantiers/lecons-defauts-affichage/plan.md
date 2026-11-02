# Plan d'exécution — Leçons v3 en défaut d'affichage

## Graphe

```
Lot A (gras)   ┐
Lot B (cadre)  ├─ indépendants, en parallèle
Lot C (figure) ┘
```

Vérification commune : copier en local (sans le commiter) `test/system/catalog/lesson_rendering_test.rb` et ses pièges depuis
`feature/standard-de-test-lot-d`, puis `LECONS=<fichiers du lot> bin/rails test test/system/catalog/lesson_rendering_test.rb`.

---

## Lot A — `**` : gras autour et après une formule

- **Couche**       : UI (helper)
- **Fichiers**     : `app/helpers/catalog/sheet_text_helper.rb`
- **Dépend de**    : —
- **Test associé** : `test/helpers/catalog/sheet_text_helper_test.rb` — gras contenant `$a$` ; `$$x$$` suivi de `**mot**` ; `$` isolés inchangés
- **Done quand**   : test rouge puis vert ; les 27 leçons `**` vertes au test d'affichage

## Lot B — débordement du bloc exercice à 390 px

- **Couche**       : UI (CSS, vues si besoin)
- **Fichiers**     : `app/assets/stylesheets/prepare_sheet.css`, `app/views/assessment/exercise_sessions/kinds/_matching.html.erb`
- **Dépend de**    : —
- **Test associé** : `test/system/catalog/long_formulas_test.rb` — formule longue dans une proposition, une association, un tableau
- **Done quand**   : test rouge puis vert ; les 15 leçons en débordement vertes au test d'affichage

## Lot C — figure EDHC trop haute

- **Couche**       : contenu
- **Fichiers**     : `docs/contenus/lecons-traitees/3eme/edhc/les-institutions-juridictionnelles.json`
- **Dépend de**    : —
- **Test associé** : test d'affichage (rouge « figure absente » d'abord) ; `valider.rb` vert
- **Done quand**   : figure dessinée à 390 px et sur ordinateur

## Contrat d'exécution

1. Test de reproduction écrit d'abord, au plus bas niveau ; lancé, **rouge pour la bonne raison**.
2. Correctif dans la couche de la cause ; vert ; suite du contexte `catalog` au vert.
3. Un test vert du premier coup ne reproduit rien : à réécrire.

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [x] Test de reproduction écrit **avant** le correctif (Lot A)
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié) (Lot A)
- [ ] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [ ] Test au vert · suite du contexte borné au vert
- [ ] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [x] Données déjà corrompues : aucune (rendu seulement)
- [ ] Challenger a rejoué les étapes de reproduction dans l'application
- [ ] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [ ] `journal.md` : cause, trou de test comblé, effets de bord écartés
