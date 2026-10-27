# Memo — Le test des images d'une fiche juge l'image avant qu'elle soit chargée

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | exécution |
| **Ouvert le** | 2026-10-27 |
| **Branche** | `fix/essential-images-instable` |
| **Programme** | — |

---

## Symptôme

Pendant les bench de `ci-rejeu-cible` (2026-10-27), sans changement de code, 1 échec sur 18 passages :

```
Catalog::EssentialImagesTest#test_the_team_inserts_an_image_in_place_of_a_slot… [test/system/catalog/essential_images_test.rb:64]:
l'image est servie
```

## Ce qui est attendu, et où c'est écrit

Le test lui-même : l'élève du niveau voit l'image insérée par l'équipe, chargée en différé (`loading=lazy`), et le navigateur la reçoit vraiment.

## Reproduction

1. `source ~/.lnclass-ci-env`
2. Avant `using_session(:student)`, faire répondre `Catalog::EssentialImagesController#show` 0,5 s plus tard (`sleep 0.5`, puis l'action d'origine).
3. `COVERAGE=0 bin/rails test test/system/catalog/essential_images_test.rb:32`

Résultat : **rouge, « l'image est servie »**, le message du symptôme. Sans l'étape 2, vert.

## Portée

- Depuis l'ajout de ce test. Rouge seulement quand l'image arrive après la lecture du test.
- **Aucun acteur touché** : l'image est servie, plus tard. Faux rouge qui coûte un train.
- **Données corrompues : non.**
- Les autres vérifications d'image chargée (`profile_photo_test`, `question_image_test`) réessaient déjà jusqu'au chargement : non touchées.

## Hors périmètre

- L'application : aucune ligne de `app/` ne change.

## Questions encore ouvertes

- —

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code (navigateur piloté, image servie 0,5 s plus tard)
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [x] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [x] Test au vert · suite du contexte borné au vert
- [x] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [x] Données déjà corrompues : réparées, ou dette explicitement notée au journal (aucune)
- [ ] Challenger a rejoué les étapes de reproduction dans l'application
- [x] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés

## Contrat d'exécution (lot unique)

1. **Reproduction** : l'image servie 0,5 s plus tard ; rouge, « l'image est servie ».
2. **Correctif dans le test** (l. 64) : attendre que le navigateur ait décodé l'image (`image.decode()`), ou échoué, avec `UPLOAD_WAIT` pour délai, au lieu d'une lecture unique de `naturalWidth`.
3. Vert avec le ralentissement, puis le fichier entier plusieurs fois.
4. **Cas symétrique** : une image refusée par le serveur (404) fait toujours échouer.

## Résultat (2026-10-27)

| Vérification | Résultat |
|---|---|
| Image servie 0,5 s plus tard, test d'avant | rouge : « l'image est servie » (le message du symptôme) |
| Même ralentissement, test corrigé | vert |
| Fichier entier, sans ralentissement | vert, trois fois |
| Cas symétrique : image refusée (404) | rouge : « l'image est servie » |
