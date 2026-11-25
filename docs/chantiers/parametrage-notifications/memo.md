# Memo — Paramétrage et confirmation des notifications par l’équipe

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-11-25 |
| **Branche** | `claude/happy-newton-rj5i1c` (branche imposée par la session ; `feature/parametrage-notifications` dans la convention) |
| **Programme** | — (suite du chantier `notifications-push`, PR #652) |

---

## Le problème

Le chantier `notifications-push` a livré l'envoi de notifications aux élèves. Une tâche lit six motifs toutes les 15 minutes (interro, devoir, annonce de l'équipe, exercice commencé, résultat ou médaille, élève inactif) et envoie **seule** dès que l'interrupteur d'envoi est ouvert. Personne ne voit ce qui va partir, personne ne décide. Un élève peut recevoir deux notifications le même jour (le garde-fou laisse 4 h entre deux envois).

Le porteur a décidé le 2026-11-25 : **aucun envoi automatique**. Tant que l'équipe ne peut pas confirmer les envois, l'interrupteur reste fermé sur les trois environnements et aucune notification ne part.

## Pour qui

**L'équipe** (Team), qui décide chaque jour de ce qui part, depuis son espace. **L'élève** (Student) en reçoit au plus une par jour.

## Pourquoi maintenant

Les abonnements s'enregistrent depuis la fusion de #652, mais rien ne part : la fonctionnalité est construite et muette. Chaque jour sans envoi est un jour sans relance, alors que la rétention est le problème que le chantier précédent devait traiter.

## Hors périmètre

- *(rempli par le grill)*

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| 1. L'équipe confirme quoi : un motif, un plan du jour, un réglage permanent ? | **Un plan du jour** (porteur, 2026-11-25) : l'équipe coche les motifs du jour et valide d'un seul geste | Un objet nouveau « plan d'envoi du jour » (date, motifs cochés, qui a validé, quand). Sans plan validé pour la date du jour, rien ne part. Le réglage permanent est refusé : ce serait l'envoi automatique |
| 2. Faut-il un seul régime pour les six motifs ? (le porteur a demandé les pratiques recommandées) | **Non : chaque motif a un mode, Automatique, À valider ou Coupé, que l'équipe règle.** Tous les motifs démarrent « À valider » (porteur, 2026-11-25) | Remplace la réponse 1 pour les motifs « à valider », qui gardent le plan du jour : l'écran montre ce qui partirait, l'équipe valide. Le passage d'un motif en « Automatique » est un geste explicite de l'équipe, tracé (qui, quand). L'interrupteur d'environnement reste un coupe-tout au-dessus des modes |
| 2 bis. Un élève visé par deux motifs le même jour ? | Une notification par jour et par élève au maximum, tous modes confondus ; le plus urgent gagne (ordre actuel des motifs) | La règle « 4 h entre deux envois » devient « une par jour d'Abidjan ». Un motif perdu ce jour-là reste candidat le lendemain s'il n'a pas expiré |
| 2 ter. Une annonce de l'équipe doit-elle attendre le plan du jour ? | Non : l'équipe choisit « Prévenir les élèves » en publiant l'annonce ; cette case vaut validation | Le motif « annonce » est validé annonce par annonce, à la publication, et non dans le plan. Il garde la limite d'une par jour |
| 3. Qui règle, qui valide ? (rôles admin, contenu, terrain) | Seul un **admin** change le mode d'un motif ; **les trois rôles** valident le plan du jour. Chaque geste est tracé (qui, quand) | Deux règles d'accès distinctes : régler (admin) et valider (toute l'équipe). Un historique des réglages et des validations est conservé et visible sur l'écran |
| 4. Personne ne valide le plan du jour : que deviennent les motifs « à valider » ? | ~~Ils partent seuls à 17 h~~ (porteur, 2026-11-25) — **annulée par la réponse 6** | Revient sur la décision « aucun envoi automatique » du 2026-11-25 : « À valider » devient « envoi à 17 h sauf retrait par l'équipe ». L'équipe doit donc pouvoir **retirer** un motif du plan avant 17 h, pas seulement valider. La fenêtre de 12 h–14 h ne sert qu'aux motifs validés ou automatiques. Seul le mode « Coupé » garantit qu'un motif ne part pas |
| 5. Avec « partent seuls à 17 h », qu'est-ce qui distingue « À valider » d'« Automatique » ? | **Un motif est automatique tant que sa case est cochée dans l'administration** (porteur, 2026-11-25) ; décochée, il ne part plus seul | Le réglage d'un motif se réduit à une case « Automatique », réservée aux admins (réponse 3). Le sort d'un motif décoché reste à concilier avec la réponse 4 (« partent seuls à 17 h ») : question 6 |
| 6. Motif décoché dans l'administration : que se passe-t-il chaque jour ? | **Il apparaît dans le plan du jour et ne part que si l'équipe le valide ; sans validation, rien ne part** (porteur, 2026-11-25) | **Annule la réponse 4** : plus aucun départ seul à 17 h. Deux états seulement par motif : coché (automatique) ou décoché (à valider chaque jour). Au démarrage, toutes les cases sont décochées (réponse 2) : la décision « aucun envoi automatique » tient tant qu'un admin ne coche rien |

## Cas limites identifiés

- …

## Questions encore ouvertes

- Grill à poursuivre : multi-appartenance de l'élève (plusieurs classes, un seul compteur par jour ?), écoles et enseignants (voient-ils quelque chose ?), ce que montre le plan (nombre d'élèves, texte exact, exemples), réglage par établissement ou global.
