# Memo — Le toast « Article créé » arrive parfois après la fin de l'attente du test

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | preuve |
| **Ouvert le** | 2026-10-27 |
| **Branche** | `fix/blog-toast-instable` |
| **Programme** | — |

---

## Symptôme

Pendant la mesure avant de `ci-rejeu-cible` (train complet, 2026-10-27), sans changement de code :

```
Teams::BlogManagementTest#test_path_A… [test/system/teams/blog_management_test.rb:71]:
expected to find visible css "#toasts" with text "Article « Réviser le BEPC en quatre semaines » créé (brouillon)." but there were no matches. Also found "", …
```

1 échec sur 18 passages de ce test dans les journaux du bench. Le passage suivant est vert.

## Ce qui est attendu, et où c'est écrit

Le test lui-même (l. 126-148) : « Créer le brouillon » pendant un envoi d'image attend l'envoi, puis l'article part avec ses deux images et le toast le confirme.

## Reproduction

1. `source ~/.lnclass-ci-env`
2. Dans `hold_uploads` (l. 444), faire attendre l'envoi libéré 2,5 s : `answer == :pass ? (sleep 2.5; original.bind_call(self)) : …` (une machine chargée, simulée).
3. `COVERAGE=0 bin/rails test test/system/teams/blog_management_test.rb:47`

Résultat : **le même échec, au même endroit, mot pour mot**. Sans l'étape 2, vert.

## Portée

- Le test attend le toast 2 s (attente par défaut de Capybara), alors qu'il suit l'envoi de l'image **puis** l'enregistrement de l'article. Sous la charge de la suite parallèle, cela dépasse 2 s.
- **Même défaut** dans `test/system/assessment/question_image_test.rb:66` (toast « Exercice mis à jour » après `release.call`) : même cause, corrigé dans ce chantier.
- **Aucun acteur touché** : l'application fait ce qu'il faut, plus lentement. Faux rouge qui coûte un train.
- **Données corrompues : non.**

## Hors périmètre

- `essential_images_test` (autre échec instable, cause non cherchée) : chantier à part.
- L'application : aucune ligne de `app/` ne change.

## Questions encore ouvertes

- —

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code (navigateur piloté, envoi ralenti)
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [x] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [x] Test au vert · suite du contexte borné au vert
- [x] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [x] Données déjà corrompues : réparées, ou dette explicitement notée au journal (aucune)
- [x] Challenger a rejoué les étapes de reproduction dans l'application
- [x] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés

## Contrat d'exécution (lot unique)

1. **Reproduction** : l'envoi libéré ralenti de 2,5 s dans les deux fichiers ; rouges avec le message du symptôme.
2. **Correctif dans le test** : le toast qui suit un envoi libéré s'attend `UPLOAD_WAIT` (20 s, la constante déjà utilisée pour tout ce qui suit un envoi), comme les autres assertions d'après envoi.
3. Avec le ralentissement : vert. Sans : vert, plusieurs fois.
4. **Cas symétrique** : une vraie absence de toast fait toujours échouer (toast retiré de la réponse, le temps d'un essai).

## Résultat (2026-10-27)

| Vérification | Avant le correctif | Après |
|---|---|---|
| Envoi libéré ralenti de 2,5 s (`blog_management_test.rb:47`) | rouge : toast « Article … créé » introuvable (le message du symptôme) | vert |
| Même ralentissement (`question_image_test.rb`) | rouge : toast « Exercice « Circuits » modifié » introuvable | vert |
| **Seconde instabilité trouvée en route** : processeur du navigateur ralenti ×8 (CDP `Emulation.setCPUThrottlingRate`) pendant le dépôt d'une image 2000×1500 | rouge : `Selenium::WebDriver::Error::ScriptTimeoutError` dans `drop_generated_image` | vert |
| Les deux fichiers entiers, sans ralentissement | — | 3 runs verts, deux fois |
| Cas symétrique : toast retiré de `teams/articles/create.turbo_stream.erb` | — | rouge (vue remise en état) |
| Challenger (indépendant) | Reproduction sur le code d'avant : envoi ralenti → 2 toasts introuvables ; processeur ×8 → `ScriptTimeoutError` 2/2. Branche : verte sous les mêmes ralentissements, et 2 fois sans ; toast retiré → rouge ; aucune autre attente de 2 s après un envoi. **Validé** |
