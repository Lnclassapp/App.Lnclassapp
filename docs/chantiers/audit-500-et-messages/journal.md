# Journal — audit-500-et-messages

## Ce qu'on a appris sur la codebase

Cause commune des « 500 » : un `rescue` trop large ou absent à la frontière repository / contrôleur. Aucun test n'envoyait de paramètre forgé ni ne forçait la course ; les tests de repository vérifiaient le chemin nominal.

| Constat | Cause | Correction | Test |
|---|---|---|---|
| B-008 | `params.dig` sur un nœud chaîne → `TypeError` | `ApplicationController#nested_param` rend nil si le nœud n'est pas un hash | contrôleurs photo, matières, imports |
| B-020 | `regenerate_link_and_code` sans nouveau tirage du code | `retrying_join_code_collision`, code retiré à chaque essai | `classroom_repository_test` |
| B-021 | `InvalidForeignKey` si l'enseignant a quitté la classe entre la policy et l'écriture | `replace` rend `false` (savepoint) ; les deux use cases répondent `:forbidden` | repository + 2 use cases |
| B-022 | tout `RecordNotUnique` devenait `already_assigned` | seul l'index « une active » le devient | `assignment_repository_test` |
| B-040 | **Reporté** : `ExerciseRepository#update` n'a aucun appelant dans `app/` (code mort), la course est inatteignable | — | — |

### Lot « messages trompeurs »

| Constat | Cause | Correction | Test |
|---|---|---|---|
| B-010 | `RemoveOwnPhoto` rend `success(false)` sans photo, valeur ignorée | le contrôleur teste la valeur ; toast d'information « Tu n'as pas de photo à retirer. » | `profile_photos_controller_test` |
| B-014 | `RecordNotUnique` à l'approbation → `:conflict` sans motif → « déjà traitée » | motif `already_attached` + message dédié (fiche de l'équipe) | repository + contrôleur |
| B-038 | tout `:conflict` hors `exercise_archived` → « session remplacée » | `already_answered` (double envoi) renvoie au résultat | `exercise_copies_controller_test` |
| B-039 | résultat d'une copie en cours : redirection vers la page de session, 403 pour l'enseignant/l'équipe | 404 pour qui n'est pas l'élève | `session_results_controller_test` |
| B-029 | **Reporté** : le test existant (AN-16) dit que le brouillon peut être retiré ; changer cela est une décision de droit | — | — |

Suite : le garant (`join_request_vouches`) affiche encore « déjà traitée » pour un enseignant déjà rattaché (même cause que B-014) ; `Identity::SecondFactorsController#form_input` garde un `params.dig` (même cause que B-008).

## À trancher

- **B-029** : un brouillon d'un autre auteur doit-il rester retirable par l'équipe / la direction ? Option prudente appliquée : rien ne change.
