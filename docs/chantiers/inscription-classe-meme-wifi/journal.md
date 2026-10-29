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
