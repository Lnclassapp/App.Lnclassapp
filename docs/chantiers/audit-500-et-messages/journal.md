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

## À trancher

— (rien d'ouvert)
