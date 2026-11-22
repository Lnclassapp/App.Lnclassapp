# ADR-0139 : La production tourne sur Cloudflare Containers, la base sur PlanetScale
<!-- index
titre: Production sur Cloudflare Containers, base PlanetScale, fichiers R2
statut: Remplacé
problematique: La facture Railway monte alors que la production ne consomme presque rien.
-->

| | |
|---|---|
| **Statut** | Remplacé |
| **Date** | 2026-11-17 |
| **Chantier** | `docs/chantiers/hebergement-cloudflare` |
| **Remplace** | — *(amende ADR-0052 pour la production seule)* |
| **Remplacé par** | ADR-0140 |

---

## 1. Contexte et problématique

La production tournait sur Railway (ADR-0052) : l'app Rails, un Postgres et un bucket, en europe-west4. Elle consomme 0,63 Go de mémoire en moyenne, 1,13 Go au pic et presque aucun processeur ; sa base pèse 0,5 Go. La facture monte quand même. Le domaine lnclass.com est déjà servi par Cloudflare.

## 2. Moteurs de décision

- Le coût mensuel, à comportement identique.
- Garder le `Dockerfile` tel quel : pas de réécriture de l'app.
- Pouvoir revenir sur Railway en quelques minutes pendant la bascule.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Rester sur Railway et réduire | Aucun travail | Choix du porteur : migrer la production |
| B — Cloudflare Containers, politique `default` | Configuration la plus simple | Instance sur mesure d'au moins 1 vCPU et 3 Gio, environ 20 $ de mémoire par mois ; `basic` (1 Gio) sous le pic mesuré |
| C — Cloudflare Containers, politique `durable_object` | Instance de 1/4 vCPU et 1,5 Gio, environ 10 $ par mois | Retenue ; politique encore en bêta |

## 4. Décision

- Un Worker `app-lnclassapp` (`wrangler.jsonc`, `cloudflare/worker.js`) démarre une seule instance du conteneur Rails, nommée `production`, placée en Europe de l'Ouest, et lui transmet chaque requête en gardant l'hôte public.
- Le Worker passe au conteneur toutes ses variables et secrets texte, plus `PORT=8080` et `PREPARE_DATABASE=1` ; `bin/docker-entrypoint` lance alors `db:prepare db:seed`, ce que fait le `preDeploy` de Railway.
- Un cron toutes les 5 minutes garde le conteneur allumé pour Solid Queue.
- La base passe sur PlanetScale Postgres (PS-5, europe-west4), facturée via Cloudflare ; les fichiers sur R2, par le service S3 existant.
- Staging, Develop et les environnements de PR restent sur Railway.

## 5. Conséquences

- Coût visé : 20 à 30 $ par mois pour la production.
- Deux hébergeurs à suivre tant que Staging et Develop restent sur Railway.
- Dépendance à une fonction en bêta (`durable_object`) : si elle change, repli sur l'option B.
- Tout redémarrage du conteneur rejoue `db:prepare db:seed`, qui est idempotent (test `RailwayDeploymentTest`).
