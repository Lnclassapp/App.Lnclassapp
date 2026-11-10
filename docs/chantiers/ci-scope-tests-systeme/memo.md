# Memo — Le niveau pr joue les tests système qui exécutent le code touché

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-10 |
| **Branche** | `fix/ci-scope-tests-systeme` |
| **Programme** | — |

---

## Symptôme

Une PR change une vue, une query ou une feuille de style ; `bin/ci-quiet` niveau `pr` la dit verte ; le test système qui rend cet écran casse, et on ne le voit qu'au train.

- PR médailles #529, #530, #531, #532, #534 : 6 tests système (`session_result`, `departed_students`, `direction_home`, `remediation_handed_in`, `teacher_first_path_desktop` — ce dernier par B-046) rouges sur `Develop` jusqu'au train de #465, réparés par #535 ([`develop-rouge-medailles`](../develop-rouge-medailles/journal.md)).
- PR #492 (CSS de la feuille Seyès) : `bin/system-changed` ne choisit que `design_system` et `role_homes` ; `sheet_cards_test.rb:60` (« Commencer » décalé à 390 px) casse, réparé par #495.

## Reproduction

`bin/system-changed` d'avant, rejoué sur la PR : `SYSTEM_SCOPE=former HEAD_REF=<tête de la PR> BASE=<Develop avant fusion> bin/system-changed --list` ; la nouvelle sélection, sans `SYSTEM_SCOPE`.

| PR fautive | Test qui a cassé | Choisi avant ? | Choisi après ? |
|---|---|---|---|
| #492 | `catalog/sheet_cards_test.rb` | non | oui |
| #524 (B-046) | `classroom/teacher_first_path_desktop_test.rb` | non | oui |
| #530 | `school_admin/departed_students`, `direction_home`, `remediation_handed_in` | non | oui |
| #529 | `assessment/session_result_test.rb` | non | oui |

PR fautive établie en rejouant chaque test sur `Develop` après chaque fusion ; détail et coût dans `journal.md` §Mesure.

## Portée

- Depuis l'ADR-0107 (2026-10-20) : toute PR de code au niveau `pr`.
- Acteurs : les sessions d'agent et le porteur (preuve de PR), aucun utilisateur de l'application.
- Données : aucune.

## Source du comportement attendu

ADR-0107 §2, moteur 1 : « Ne prouver dans une PR que ce qu'elle peut casser ». Un test système qui exécute le code changé est ce que la PR peut casser.

## Hors périmètre

- Les tests unitaires hors du miroir (FAQ `help_controller_test`, empreinte `standard_activity_test` de #534) : sélection de `CiScope.tests_for`, chantier de suivi (journal, dette).
- Tracer la carte à chaque train sur GitHub (coût des 6 parts sous 5 min) : `À trancher`.
- Changer le niveau train ou le découpage des parts système.

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** (rejeu de `bin/system-changed` d'avant sur #529-#534 et #492)
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [x] Correctif appliqué dans la couche de la **cause** (`script/ci/system_scope.rb`, la sélection)
- [x] Test au vert · `test/config/ci_scope_test.rb` au vert
- [x] Cas symétrique vérifié : un test système modifié et la route d'une vue sont toujours choisis
- [x] Données déjà corrompues : sans objet
- [x] Challenger a rejoué la sélection sur l'historique (journal §Mesure)
- [x] Commit `fix(ci): …` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés
