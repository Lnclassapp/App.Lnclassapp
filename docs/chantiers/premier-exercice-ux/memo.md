# Memo — Premier exercice : la fenêtre qui suit partout, la réponse en nombre refusée sans le dire

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | prouvé |
| **Ouvert le** | 2026-11-25 |
| **Branche** | `fix/premier-exercice-ux` |
| **Programme** | — |

---

## Symptôme

Le porteur, en testant le premier exercice (2026-11-25) : « Il nous suit sur toutes les pages et, malgré que j'ai répondu à toutes les questions, elle me dit que j'ai une question non répondue, puis un message d'erreur s'affiche à la soumission. »

1. La fenêtre « Ton premier exercice » s'ouvre sur chaque écran de l'élève (accueil, Ma classe, historique, cours, aide) tant qu'aucune copie n'est rendue ; « Plus tard » ne vaut que pour la page.
2. Réponse en nombre, saisie « x = 8 » : le compteur dit 5/6, « Vérifier ma copie » annonce une question sans réponse, puis la bulle du navigateur « Écris un nombre, par exemple -3,5. » s'affiche cachée sous l'en-tête, loin du champ.

## Reproduction

- Jeu standard, élève 0100000086 (PIN du jeu standard), exercice « Résoudre des équations et des inéquations du premier degré ».
- 1 : se connecter, fermer la fenêtre (« Plus tard »), aller sur Ma classe, Cours, Aide : elle revient à chaque écran.
- 2 : ouvrir la copie, répondre à tout, taper « x = 8 » dans une réponse en nombre, « Vérifier ma copie » : dialogue « 1 question sans réponse », puis « Rendre quand même » : bulle native hors de vue, rien ne part.
- Reproduit en local par l'orchestrateur ; tests rouges au commit `752a30c`.

## Portée

- Tous les élèves sans copie rendue (1) ; toute copie avec une réponse en nombre (2). Rendu et navigateur seuls : aucune donnée écrite de travers, multi-appartenance sans objet.

## Hors périmètre

- Les cases multiples d'une réponse en nombre (`multi_blank?`) : pas de contrôle de lecture côté navigateur aujourd'hui, inchangé.
- La lecture serveur (`Numeric.parse`) : inchangée.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quel document dit le comportement ? | UDR-0179 §3.2 : la fenêtre sur chaque écran — c'est la règle que le porteur remet en cause | UDR `XXXX-premier-exercice-ux` amende §3.2 |
| Le refus d'une saisie illisible est-il voulu ? | Oui (UDR-0087 §3.4, ADR-0091 §4.3) ; c'est sa présentation qui est fautive | On garde le refus, on le dit sous le champ |
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

1. Tests rouges (commit `752a30c`) : `test/system/student_first_exercise_prompt_test.rb`, `test/system/assessment/question_numeric_test.rb` (2e test), contrôleurs `catalog/prepare_sheets`, `communication/help`, `classroom/student_classrooms`.
2. Fenêtre : le shell ne pose le cadre que si la vue le demande (`content_for :first_exercise_prompt`, accueil élève) ; « Plus tard » ou Échap la taisent pour la visite (`sessionStorage`).
3. Nombre illisible : message sous le champ, `aria-invalid`, l'envoi ramène au champ avant toute confirmation.
4. Vert, puis les tests système qui ouvrent la fenêtre ou remplissent une copie.
