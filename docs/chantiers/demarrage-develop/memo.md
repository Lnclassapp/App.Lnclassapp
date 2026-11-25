# Memo — Démarrage de Develop et Staging en moins de 2 minutes

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-21 |
| **Branche** | `perf/demarrage-develop` |
| **Programme** | — |

---

## Le problème

Chaque fusion vers `Develop` redéploie le site (ADR-0144). Le conteneur d'application de Develop et de Staging
(`deploy/hostinger/test.yaml`) jouait `db:prepare db:seed` **avant** Puma, puis `bin/docker-entrypoint` rejouait
`db:prepare`. Le semis (leçons du dépôt, jeu standard, activité simulée) dure selon ce qui a changé : quelques secondes
quand tout est « unchanged », un quart d'heure quand des leçons sont à recharger ou des jours d'activité à rattraper.
Pendant ce temps, le site répond 502.

## Pour qui

L'équipe et les testeurs qui ouvrent develop.lnclass.com ou staging.lnclass.com juste après une fusion.

## Pourquoi maintenant

Le déploiement continu (ADR-0144, 2026-11-21) fait d'un démarrage long une coupure à chaque fusion.

## Hors périmètre

- La production (`deploy/hostinger/compose.yaml`) : elle garde `PREPARE_DATABASE=1`, semis avant Puma (prouvé par
  `test/config/hostinger_demarrage_test.rb`).
- Les plafonds CPU de `test.yaml` : PR à part (`fix/retouche-plafonds-cpu-develop-staging`).
- La vitesse du semis lui-même (chargement des leçons, activité simulée) : il ne bloque plus le service.

## Mesure avant

| Métrique | Contexte / volume | Valeur avant | Cible | Comment mesurée |
|---|---|---|---|---|
| Démarrage du conteneur → première réponse 200 de `/up` (502 pendant ce temps) | Develop, déploiement du 2026-11-21 à 18:02 (leçons et activité à mettre à jour), plafonds 0,1 / 0,4 CPU | **16 min 36 s** (18:02:57 → Puma 18:19:33) | **< 2 min**, quel que soit le semis | journaux `lnclass-develop`, API Hostinger (chantier pages-sous-600ms) |
| Même mesure, rien à recharger | Develop, déploiement de `f8f2700` à 19:05:33, 463 leçons « unchanged », 0 séance ajoutée | **42 s** (dont ~26 s de semis et ~5 s de second `db:prepare`) | < 2 min | journaux `lnclass-develop` : « Container … app-1 Started » → `/up` 200 de Thruster (19:06:15) |

Protocole après : `python3 -I script/mesure/demarrage lnclass-develop` (puis `lnclass-staging`) après chaque
déploiement ; le script lit le repère `[démarrage] conteneur démarré` et la première `/up` 200. Médiane de 3 déploiements.
**À lancer dans l'heure qui suit le déploiement** : l'API ne garde que les 300 dernières lignes par service, et la
sonde `/up` de toutes les 15 s les remplit en ~75 min.

## Mesure après

| Déploiement | `/up` 200 après le repère | Semis fini après | Source |
|---|---|---|---|
| `0ffd82b` (fusion de #673), conteneur démarré 2026-11-21 19:26:19 UTC | non lu : lignes sorties de la fenêtre de l'API à la lecture (22:54) ; conteneur `healthy` | — | `script/mesure/demarrage`, conteneurs Hostinger |
| `f5ce2c8` (fusion de #671, plafonds relevés à 0,5 / 1,0 CPU), conteneur démarré 23:01:28 UTC | **≤ 16 s** : le semis ne part qu'après `/up` 200 et finit à 23:01:44 ; repère de départ chassé de la fenêtre par les ~470 lignes du semis | **16 s** | ligne « [build] … app-1 Started » (heure du VPS, UTC+1) et `[démarrage] semis terminé` |
| `345c946` (fusion de #675), conteneur démarré 2026-11-21 23:23:25 UTC | **5 s** | **16 s** | `script/mesure/demarrage` (dernière ligne `[démarrage]`) |
| déploiement de Staging (train) | à lire dans l'heure | | |

## Cause

Le temps de 502 = `db:prepare` + **semis complet** + second `db:prepare` + démarrage de Puma, tout en série. Seul le
semis varie (de 26 s à un quart d'heure) : c'est lui qui porte le coût, et il n'a aucune raison de bloquer `/up`.

## Décision

Un seul levier, qui borne le pire cas au lieu de raboter le cas moyen : **semer en tâche de fond une fois que `/up`
répond**, et laisser `bin/docker-entrypoint` faire seul le `db:prepare` (migrations avant Puma, et semis d'une base
neuve). Pas d'ADR : aucun port, contrat ni invariant applicatif ne change ; seul l'ordre de démarrage de deux
environnements de test change. Leviers écartés : voir le journal.
