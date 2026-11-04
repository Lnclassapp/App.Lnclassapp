# Memo — Un QCM à plusieurs bonnes réponses refuse tout l'exercice sans dire pourquoi

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | planifié |
| **Ouvert le** | 2026-11-04 |
| **Branche** | `fix/qcm-plusieurs-reponses` |
| **Programme** | — |

---

## Symptôme

Sur la feuille « Prépare interros » de Thalès (notion 1, exercice 1), l'élève coche une seule proposition à la question e, puis touche « Vérifier ma réponse ». Il obtient « Une réponse n'est pas lisible : vérifie-la (un nombre est attendu pour un calcul), puis réessaie. » au lieu de sa correction. Rien sur la feuille ne dit que la question e a deux bonnes réponses ; le message parle d'un nombre alors que l'exercice n'a que des QCM.

## Reproduction

- Acteur : élève de 3ème (compte de Touré, « 3ème 1 · College Prive Mixte Union Tiassalé »), sur Develop (`develop.lnclass.com`), le 2026-11-04, capture envoyée.
- Étapes : leçon « Propriétés de Thalès dans un triangle » → « Prépare interros » notion 1 → exercice 1 → cocher une réponse à chaque question, une seule à la question e (QCM à deux bonnes réponses) → « Vérifier ma réponse ».
- Attendu : la feuille dit à la question e qu'il faut cocher 2 réponses ; si l'élève en coche une seule, la vérification est bloquée par un message qui nomme la question : « Question e : coche 2 réponses. » (choix du pilote, 2026-11-04 : prévenir et bloquer).
- Source du comportement attendu : le lecteur d'exercice (`exercise_sessions`) affiche déjà « Coche 2 propositions. » sous un QCM multiple et refuse une mauvaise sélection par « Coche le nombre de propositions demandé, parmi celles de la question. », à la question ; la feuille de l'UDR-0149 a perdu les deux.

## Portée

- Depuis la feuille de cahier (UDR-0149, Lnclassapp/App.Lnclassapp#416, 2026-10-30) : tous les QCM à 2 ou 3 bonnes réponses de toutes les feuilles (Thalès : 9 questions) et des devoirs reçus.
- Acteurs : élève (leçon et « Ma classe »). Le visiteur ne vérifie pas. Enseignant, équipe, parent, personnel : pas de champ, rien à vérifier.
- Le même message trompeur couvre toute réponse mal formée d'une feuille (nombre illisible, case vide d'une phrase à trous…) : la question fautive n'est jamais nommée.
- **Données** : aucune. La copie refusée n'est pas enregistrée.

## Hors périmètre

- Compter une mauvaise sélection comme fausse au lieu de bloquer : écarté par le pilote.
- Les fractions (« 3/5 ») dans une réponse en nombre.
- Le lecteur d'exercice (`exercise_sessions`) : il marche déjà.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Une mauvaise sélection : compter faux ou bloquer ? | Prévenir et bloquer | La règle du domaine (nombre exact de propositions) ne change pas ; la feuille l'annonce et le refus nomme la question. |
| D'où vient l'erreur, fraction ou QCM ? | QCM : une seule case cochée à la question e, qui en attend deux | Ce n'est pas la lecture des nombres : c'est l'annonce du nombre de propositions et le message du refus. |

## Cas limites identifiés

- Deux questions fautives dans le même exercice : un message par question, dans l'ordre.
- QCM à 3 bonnes réponses : « coche 3 réponses ».
- Une réponse en nombre illisible : « Question c : écris un nombre, par exemple -3,5. »
- Une copie illisible dans sa forme (identifiants inconnus) : le message général d'aujourd'hui reste.

## Questions encore ouvertes

- Aucune.

## Portes de sortie

- [ ] Symptôme et étapes de reproduction écrits dans `memo.md`
- [ ] Bug reproduit **à la main** dans l'application avant toute ligne de code
- [ ] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [ ] Test de reproduction écrit **avant** le correctif
- [ ] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [ ] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [ ] Test au vert · suite du contexte borné au vert
- [ ] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [ ] Données déjà corrompues : réparées, ou dette explicitement notée au journal
- [ ] Challenger a rejoué les étapes de reproduction dans l'application
- [ ] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [ ] `journal.md` : cause, trou de test comblé, effets de bord écartés

## Lot unique — contrat d'exécution

- **UDR** : UDR-XXXX-qcm-plusieurs-reponses-sur-la-feuille.
- **Fichiers** : `app/infrastructure/queries/catalog/prepare_sheets_query.rb` (le nombre de propositions attendues d'un QCM, à côté de `multiple`) · `app/views/catalog/courses/sheets/_question.html.erb` (« Coche 2 réponses. » sous un QCM multiple) · `app/controllers/assessment/sheet_checks_controller.rb` (garder les erreurs par question) · `app/views/assessment/sheet_checks/_error.html.erb` · `config/locales/assessment/sheet_checks.fr.yml` · `config/locales/catalog/courses.fr.yml` · `app/assets/stylesheets/prepare_sheet.css` (`.ps-instruction`)
- **Tests** : `test/controllers/assessment/sheet_checks_controller_test.rb` (reproduction : une seule proposition à un QCM à deux bonnes réponses → 422 et « Question e : coche 2 réponses. », rouge d'abord) · `test/infrastructure/queries/catalog/prepare_sheets_query_test.rb` · `test/system/assessment/sheet_check_test.rb` (la feuille affiche « Coche 2 réponses. »)
- **Séquence** : test de reproduction → rouge pour la bonne raison → correctif → vert → suite `assessment` et `catalog` → `bin/system-changed`.
