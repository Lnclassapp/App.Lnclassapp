# Memo — Entonnoir AARRR des élèves

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-11-16 |
| **Branche** | `feature/entonnoir-aarrr` |
| **Programme** | — |

---

## Le problème

Les élèves s'inscrivent sur Lnclass, mais, selon le porteur, « l'activation et la rétention sont à 0 : aucun élève n'a fait plus de 2 exercices ». Personne ne sait **où** les élèves décrochent : entre l'inscription et la première notion lue ? entre la notion et le premier exercice ? entre l'exercice commencé et l'exercice réussi ? après le premier jour ? L'équipe n'a aucun chiffre de parcours individuel agrégé ; la page « Croissance » ne parle que des enseignants et du parrainage.

Le porteur veut piloter le produit avec le cadre AARRR (Acquisition, Activation, Rétention, Referral, Revenu). Le moment « aha » est fixé : **le premier exercice réussi** par l'élève.

## Pour qui

L'**équipe Lnclass** (rôle `team`), au moment où elle décide quoi corriger dans le parcours de l'élève. En particulier le chantier parallèle `activation-eleve`, qui refond l'onboarding le même jour et a besoin d'un chiffre « avant » pour juger son effet.

## Pourquoi maintenant

L'onboarding est refondu aujourd'hui même. Sans mesure posée maintenant, on ne saura jamais si la refonte a fait monter l'activation : la seule ligne de base possible est celle des données déjà en base, lue avant que la refonte ne soit en production.

## Hors périmètre

- **Aucune nouvelle table, aucun événement, aucun traceur, aucun cookie** (ADR-0049, ADR-0062). Si une table devient indispensable, c'est une décision non réversible : écrite dans `## À trancher`, pas codée.
- **Aucun écran de l'élève** : ni `student_homes`, ni `student_registrations`, ni `catalog/courses` (chantier `activation-eleve`).
- Ce qui n'est **pas** en base et qu'on n'invente pas : cours commencé / terminé, nombre et date de première connexion, visites d'écran, temps passé, première ouverture de l'app, temps de réponse par question. L'écran le **dit**.
- Le contexte `crm` (suivi commercial des écoles) : rien n'y va, rien n'en vient.
- Les enseignants, la direction (`SchoolStaff`) et les parents : ils ne voient rien de cet écran. Le parent n'a pas de compte ; l'entonnoir d'un enseignant est déjà la page « Croissance ».
- Un entonnoir par établissement, par DRENA ou par classe : pas maintenant (le volume ne le justifie pas, cf. le premier lot).
- Un export CSV, un graphique tracé, une alerte : pas maintenant.

## Ce que le grill a révélé

> Grill adverse mené par la session à partir des décisions non rediscutables du porteur (brief du 2026-11-16) et de l'état des lieux du même jour ; les réponses viennent de la doc (ADR-0049, ADR-0062, ADR-0085, ADR-0106, ADR-0126) ou appliquent l'option prudente, écrite dans `journal.md` § À trancher.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| « Réussi », c'est quoi exactement ? 50 % brut ? La médaille Bronze ? | Le seuil « réussi » du domaine : `PASS_THRESHOLD` lu sur la note sur 20 (ADR-0106), soit 48 % et plus. Pas la médaille : « tout exercice traité donne au moins Bronze ». | La requête reçoit le seuil calculé par `Grading.reaches?`, jamais un 50 codé en dur. Un test fixe 47 % (échec) et 48 % (réussi). |
| Un élève qui refait trois fois le même exercice a-t-il « réussi deux exercices » ? | Non : on compte des **exercices distincts** réussis, pas des sessions. | « au moins 2 / au moins 5 » = `COUNT(DISTINCT exercise_id)` des sessions terminées et réussies. |
| Une session de remédiation (lacune) est-elle un exercice ? | Oui, c'est un exercice que l'élève fait et peut réussir. | Pas de filtre sur `kind`. |
| « Élève seul » ou « amené par sa classe » : un élève a plusieurs adhésions, laquelle fait foi ? | La **première** adhésion créée (la voie d'arrivée réelle). `standard` = seul (cascade) ; `link` et `code` = amené par sa classe. Un élève sans adhésion est compté à part (« sans classe »). | Une 3ᵉ colonne « sans classe » quand elle n'est pas vide ; le brut garde les trois voies séparées. Limite connue : un retour par lien après un retrait réécrit `joined_via` (ADR-0085). |
| Un élève anonymisé compte-t-il ? | Non, comme partout au pilotage (compte actif = non anonymisé, ADR-0062). | Filtre `anonymized_at IS NULL`, écrit dans le PRD. |
| « Actif à J7 » : actif le 7ᵉ jour pile, ou revenu à partir du 7ᵉ jour ? | **Revenu à partir de J+n** (rétention « non bornée »). Les traces `essential_reads.last_read_at` sont écrasées : seule la dernière date est sûre, ce qui ne permet pas de dire « actif le jour 7 pile ». | Définition écrite dans le PRD ; l'option « jour pile » est dans `## À trancher`. |
| Un élève dont l'inscription a 3 jours a-t-il une rétention J7 nulle ? | Non : la cohorte n'est **pas encore mesurable** à J7. | « — » plutôt que 0 %, et le dénominateur ne compte que les élèves dont J+n est passé. |
| Volumes trop faibles pour un pourcentage ? | Probable (c'est la raison du premier lot). | Chaque taux s'affiche avec son effectif (« 2 / 3 ») ; le brut en production d'abord. |
| Revenu : il n'y a peut-être aucun abonné. Zéro ou « pas de donnée » ? | La donnée existe (`activation_cards` activées). Zéro carte activée est un vrai zéro. Mais la bêta est ouverte (`BETA_ENDS_ON` vide) : aucun élève n'est invité à payer. | On affiche le compte et la phrase « bêta ouverte » tant que la bêta court, pour que zéro ne se lise pas comme un échec. |
| La tâche de production peut-elle écrire par accident ? | Elle ne doit pas pouvoir. | Elle s'exécute dans une transaction `READ ONLY` : une écriture lèverait une erreur PostgreSQL. Testé. |
| Une requête par semaine × voie, est-ce un N+1 ? | Oui si on boucle en Ruby. | Une requête groupée par (semaine, voie) ; nombre de requêtes fixe, testé. |
| Acteurs oubliés : direction, enseignant, parent ? | Rien à voir ici : un taux d'activation national n'est pas leur information, et le parent n'a pas de compte. | Écrit dans `Hors périmètre`. Accès : la politique de la page Croissance (équipe). |

## Cas limites identifiés

- Aucun élève inscrit dans la période : chaque étage montre 0 et les taux « — ».
- Élève inscrit sans aucune adhésion (classe archivée, inscription interrompue) : colonne « sans classe ».
- Élève multi-classes : compté une fois, sur sa première voie.
- Exercice réussi **avant** l'inscription (données de reprise) : le délai médian prend `GREATEST(0, …)`.
- Session `completed` sans `completed_at` : impossible par contrainte (`completed_has_score` garantit le score ; `completed_at` est écrit par la clôture) ; une session sans date est ignorée du délai.
- Cohorte trop récente pour J30 : « — ».
- Tâche lancée sur une base vide : une ligne « aucun élève », code de sortie 0.

## Questions encore ouvertes

- Voir `journal.md` § À trancher : définition de « actif » (non bornée ou jour pile), classement de `code` avec « amené par sa classe », besoin éventuel d'une table d'événements (connexions, visites).
