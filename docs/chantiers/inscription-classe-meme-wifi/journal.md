# Journal — Une classe s'inscrit ensemble depuis le wifi de l'école

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

- **Root cause** : `app/controllers/classroom/joins_controller.rb:9-10` (`LINK_RATE_LIMIT`, 10/min, `by: request.remote_ip`) appliqué à `GET /c/:token` et, par `student_registrations_controller.rb:18-21`, à `POST /student-signup` avec en plus 5/min « signup ». Chaîne : élève ouvre `/c/<jeton>` → JoinsController (compteur partagé) → formulaire → `POST /student-signup` (deux compteurs). Tous les élèves d'une classe partagent l'adresse : le débit pensé par attaquant est un débit par école.
- **Trou de test** : les tests du débit (`student_registrations_controller_test.rb:269, 608, 625`) prouvent que l'attaquant est arrêté, aucun ne joue une classe entière derrière une adresse.
- **Badge (constat de la simulation, écarté)** : la liste enseignant montre le badge **de classe**, calculé sur la moyenne des exercices assignés faits (UDR-0134 §3.2, `Grading.class_badge_for`) ; l'élève fête le badge **d'un exercice**. Daniel Tanoh : 13/20 à Thalès (Bronze), moyenne 7/20 → « Pas encore » ; sa fiche affiche « Moyenne 7/20 · Pas encore » et « Bronze 1 ». Conforme, pas de correctif.

- **Correctif** : `CLASS_LINK_RATE_LIMIT` (60/min/adresse, scope `classroom/links`) sur `JoinsController` (GET et POST), sur `StudentRegistrationsController#create` quand le jeton posté est de forme valide (`link_send?`, `normalize_link_token`) à la place des deux débits (10 et 5), et sur la confirmation par lien de `StudentClassroomChangesController`. Inchangés : `classroom_codes`, `student_classroom_choices`, voie standard, 10 et 5.
- **Trou de test comblé** : 4 tests de contrôleur (45 ouvertures, 45 inscriptions par lien, 61e ouverture et 61e envoi en 429). Rouges avant le correctif : « opening 11 was refused (429) » et « sign-up 6 was refused (429) ».
- **Effets de bord** : 4 tests qui figeaient le compteur partagé à 10 pour le lien (joins §4.2, registrations CA-B4 et IL-23 lien, changes §4.1) et 1 test d'intégration (classroom_codes CA-B4) passent à 60 ou séparent les compteurs, conformément à l'ADR-0085 §4.7. Pas de données corrompues : un 429 n'écrit rien.
- **Relecture** : `RegisterStudent` retombe sur le code quand le jeton ne résout rien ; `link_send?` est donc faux dès qu'un `join_code` est posté (un faux jeton ne desserre pas la devinette de codes). Test ajouté, rouge avant (422 au 11e envoi au lieu de 429).
- **Hors lot** : les échecs de `test/integration/assessment` (appariement, ordre, texte à trous, numérique) existent sans ce correctif.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
