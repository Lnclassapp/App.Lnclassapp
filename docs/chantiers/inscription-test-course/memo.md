# Memo — Le test d'inscription enseignant rouge sous charge

| | |
|---|---|
| **Type de cycle** | bugfix (tests) |
| **Statut** | livré, clos |
| **Ouvert le** | 2026-10-30 |
| **Branche** | `fix/inscription-test-course` |
| **Programme** | — |

---

## Symptôme

Suite complète jouée pour la PR de dépendances #361 : `teacher_signup_test.rb:75` (« CA-J1, CA-J3, CA-J4 ») échoue, « expected to find visible field "teacher_registration[contact]" … there were no matches ». Seul, le fichier passe.

## Cause

Choisir la matière complète l'étape 2 ; l'étape 3 vient 100 ms plus tard en test, et masque l'étape 2. Le test vérifie le numéro gardé dans l'étape 2 juste après ce choix : si plus de 100 ms passent (suite chargée), le champ est déjà masqué. Reproduit en ajoutant 0,5 s avant la vérification : même erreur. Le code est conforme.

## Correctif retenu

Lire le numéro gardé que l'étape 2 soit encore montrée ou déjà masquée (`visible: :all`). Avec 0,5 s de retard, la nouvelle vérification passe. Aucun code applicatif touché.

## Portes de sortie

- [x] Rouge reproduit avant (retard de 0,5 s), vert après ; le fichier entier vert
- [x] `bin/ci-quiet` vert, ligne de preuve dans la PR
