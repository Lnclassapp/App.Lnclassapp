# PRD — Environnements de PR sur Railway

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Railway crée un environnement par PR, à partir de Develop, et le supprime à la fusion : le porteur y essaie une PR depuis n'importe quel appareil, sur des données fictives, derrière un mot de passe commun. Pour qu'il serve et coûte peu, l'application doit s'y reconnaître, y semer les données de test, y exécuter les tâches de fond sans traitement continu (pour la mise en veille) et refuser tout visiteur sans mot de passe. Railway cesse de lire `railway.json` le 2026-12-01 : sa configuration passe dans Railway, à l'identique ([memo](memo.md)).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Porteur (Team) | ouvrir l'adresse d'une PR, saisir le mot de passe commun, se connecter avec tout compte de test | — |
| Personne à qui le porteur montre la PR | la même chose, avec le mot de passe qu'il lui donne | — |
| Visiteur sans le mot de passe | rien : chaque page lui est refusée | voir une page, même publique |
| Contrôle de santé de Railway | interroger `/up` sans mot de passe | — |

Règle : un **environnement de PR** est un environnement Railway dont la variable `PR_BASE_ENVIRONMENT` est posée et diffère de `RAILWAY_ENVIRONMENT_NAME`. Develop porte `PR_BASE_ENVIRONMENT=Develop` ; ses PR la reçoivent par copie, avec un autre nom d'environnement. Staging, production, développement et test n'ont pas la variable. Une fois la variable reconnue, l'accès est fermé par un mot de passe (Basic HTTP), lu dans `PR_ACCESS_PASSWORD`, et tout est refusé si cette variable est absente.

## 3. Parcours utilisateur

### Chemin nominal

1. Le porteur ouvre une PR vers Develop. Railway crée l'environnement, joue les migrations et sème : référentiel, DRENA, comptes fictifs (dont l'équipe et son code TOTP dans le journal du pré-déploiement), trois établissements de test.
2. Il ouvre l'adresse Railway de la PR, saisit le mot de passe commun, puis se connecte avec un compte de test, PIN 2468.
3. Il lance un import : la tâche s'exécute dans le processus web, le résultat arrive.
4. Sans visite pendant 5 à 10 minutes, l'environnement se met en veille ; la visite suivante le réveille.
5. À la fusion ou à la fermeture de la PR, Railway supprime l'environnement.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Mot de passe absent ou faux | 401, demande de mot de passe du navigateur, aucune page servie |
| `PR_ACCESS_PASSWORD` absente dans un environnement de PR | 401 sur toute page : un oubli ferme l'accès |
| `/up` dans un environnement de PR | 200 sans mot de passe |
| Nouveau commit sur la PR | redéploiement ; les seeds rejoués ne créent rien de plus |
| Develop, Staging, production | ni mot de passe, ni données de test, worker Solid Queue dans Puma comme aujourd'hui (ADR-0052) |
| PR de promotion (Develop → Staging, Staging → main) ou ouverte par un robot | pas d'environnement (réglage Railway pour les robots ; lot D conditionnel pour les promotions) |
| Message programmé dans une PR | jamais publié à son heure : les tâches planifiées n'y tournent pas |

## 4. Critères d'acceptation

```gherkin
Scénario: Develop porte la variable, ses PR sont reconnues
  Étant donné PR_BASE_ENVIRONMENT vaut "Develop"
  Quand RAILWAY_ENVIRONMENT_NAME vaut "Develop"
  Alors l'environnement n'est pas un environnement de PR
  Quand RAILWAY_ENVIRONMENT_NAME vaut un autre nom
  Alors l'environnement est un environnement de PR

Scénario: sans la variable, jamais un environnement de PR
  Étant donné PR_BASE_ENVIRONMENT est absente ou vide
  Alors l'environnement n'est pas un environnement de PR, quel que soit RAILWAY_ENVIRONMENT_NAME

Scénario: le mot de passe ferme tout l'environnement de PR
  Étant donné un environnement de PR dont le mot de passe est "secret"
  Quand on demande une page sans mot de passe, ou avec un mauvais
  Alors la réponse est 401 et demande un mot de passe
  Quand on la demande avec le mot de passe "secret"
  Alors la page est servie
  Et /up répond 200 sans mot de passe

Scénario: un mot de passe oublié ferme l'accès
  Étant donné un environnement de PR sans PR_ACCESS_PASSWORD
  Quand on demande une page, avec n'importe quel mot de passe
  Alors la réponse est 401

Scénario: hors environnement de PR, rien ne change
  Étant donné la production sans PR_BASE_ENVIRONMENT
  Alors aucune page ne demande de mot de passe
  Et les tâches de fond passent par Solid Queue, le worker tourne dans Puma
  Et les mises à jour en direct passent par Solid Cable

Scénario: dans un environnement de PR, rien n'interroge la base en continu
  Étant donné un environnement de PR en production
  Alors les tâches de fond s'exécutent dans le processus web (adaptateur async)
  Et Puma ne charge pas le worker Solid Queue
  Et les mises à jour en direct passent par le processus web (adaptateur async)

Scénario: un environnement de PR reçoit les données de test
  Étant donné un environnement de PR à la base vide
  Quand le pré-déploiement sème la base
  Alors le référentiel, les DRENA, les comptes fictifs et les trois établissements de test existent
  Et on se connecte au compte enseignant 0531000001 avec le PIN 2468
  Quand le pré-déploiement sème une seconde fois
  Alors rien de plus n'est créé

Scénario: la production ne reçoit jamais les données de test
  Étant donné la production sans PR_BASE_ENVIRONMENT
  Quand le pré-déploiement sème la base
  Alors seule l'identité est semée, comme aujourd'hui (ADR-0034)
  Et lancer à la main un seed de test y est refusé
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | aucun : le chantier est de la configuration |
| Infrastructure | un module Ruby pur de détection (lu par Puma avant Rails, puis par l'application et les seeds) ; un middleware Rack de mot de passe ; adaptateurs Active Job et Action Cable choisis selon l'environnement ; seeds autorisés en environnement de PR |
| Delivery | aucun contrôleur ; le middleware passe avant le routeur |
| UI | aucune vue : la demande de mot de passe est celle du navigateur |
| Railway | `railway.json` migré par `railway config migrate` (Lot A) ; réglages du tableau de bord tenus par le porteur (« Actions du porteur » du plan) |

## 6. Décisions rattachées

- ADR-XXXX-environnements-de-pr-reconnus-par-l-application — reconnaissance, mot de passe, tâches et mises à jour en direct dans le processus web, seeds ; amende ADR-0052 (worker toujours dans Puma) et ADR-0034 (seeds par environnement).
- Pas d'UDR : aucune vue créée ni modifiée (la demande de mot de passe est celle du navigateur).

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Environnement de PR sans visite | n'existe pas | en veille 10 minutes après la dernière visite | à constater par le porteur |
| Semis d'un environnement de PR | n'existe pas | moins de 30 secondes | |
