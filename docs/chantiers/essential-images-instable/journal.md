# Journal — Le test des images d'une fiche juge l'image avant qu'elle soit chargée

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-27 | Attendre `decode()` plutôt que réessayer `naturalWidth` | `decode()` répond une fois l'image décodée, ou échoue si elle ne l'est pas : un 404 échoue tout de suite au lieu d'attendre la fin du délai | non |

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

**Rapport de root cause.**

1. **Chaîne** : l'élève ouvre la fiche → `assert_selector "figure img[…][loading=lazy]"` voit la balise dès que le HTML est là → la ligne 64 lit **une seule fois** `naturalWidth` → l'image, chargée en différé par `Catalog::EssentialImagesController#show`, n'est peut-être pas encore arrivée : `naturalWidth` vaut 0.
2. **Cause** : `test/system/catalog/essential_images_test.rb:64`, une lecture unique (`evaluate_script`) d'un état qui arrive plus tard, sans attente.
3. **Pourquoi rien ne l'a vu** : l'image locale arrive d'habitude avant la lecture ; sous charge, rarement non.

En une phrase sans les mots du symptôme : le test lit une seule fois une valeur que le navigateur ne fixe qu'après un chargement asynchrone.

**Trou de test comblé** : le test attend `decode()` (délai `UPLOAD_WAIT`) ; une image servie en retard passe, une image refusée échoue toujours (vérifié avec un 404).

**Effets de bord écartés** : seul ce test lisait l'état de l'image d'un coup ; `profile_photo_test` et `question_image_test` réessaient déjà.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |
