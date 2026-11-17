# ADR-0140 : La production tourne sur un VPS Hostinger, derrière Cloudflare
<!-- index
titre: Production sur un VPS Hostinger (Docker), Cloudflare devant, fichiers et sauvegardes sur R2
statut: Accepté
problematique: PlanetScale refuse les cartes prépayées ; il faut un hébergement bon marché payable par le porteur.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-17 |
| **Chantier** | `docs/chantiers/hebergement-cloudflare` |
| **Remplace** | ADR-0139 (production sur Cloudflare Containers et PlanetScale) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0139 mettait l'application dans un conteneur Cloudflare et la base sur PlanetScale (17 $ par mois). PlanetScale refuse la carte prépayée du porteur. Il faut un hébergement payable par cette carte, au coût le plus bas, sans réécrire l'application (`Dockerfile` inchangé).

## 2. Moteurs de décision

- Le coût mensuel, payable par carte prépayée.
- La base jamais exposée sur Internet.
- Une session d'agent ne sort qu'en HTTPS : tout doit se piloter par API, sans SSH.
- Pouvoir revenir sur Railway pendant 7 jours.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — ADR-0139 (Cloudflare Containers, PlanetScale) | Rien à administrer | PlanetScale refuse la carte du porteur |
| B — Base seule sur un VPS, Rails dans un conteneur Cloudflare | Rails géré par Cloudflare | Base ouverte sur Internet, Workers Paid en plus |
| C — Tout sur un VPS Hostinger KVM 2 (Paris), Cloudflare devant | Un seul prix fixe, base sur aucun port public | Retenue ; serveur à entretenir |

## 4. Décision

- VPS Hostinger KVM 2 (2 vCPU, 8 Go, Paris), Ubuntu 26.04 avec Docker ; mises à jour de sécurité automatiques, fail2ban, pare-feu Hostinger : SSH ouvert, 80 et 443 aux seules plages de Cloudflare.
- Projet Docker `lnclass` (`deploy/hostinger/compose.yaml`) : Rails (Thruster, Puma, Solid Queue), Postgres 18 sur aucun port publié (mot de passe tiré sur le serveur), Caddy pour HTTPS (Let's Encrypt, IP réelle lue dans `CF-Connecting-IP`), sauvegarde `pg_dump` chaque nuit à 3 h 15 vers R2 (`backups/postgres/`).
- Le gestionnaire Docker de Hostinger ne construit pas d'image : `deploy/hostinger/construction.yaml` construit `lnclass-app:<sha>` sur le serveur depuis l'archive GitHub (jeton en lecture seule), puis `lnclass` démarre cette image.
- Les secrets vont dans le `.env` de chaque projet par `script/hostinger/deployer.py`, qui n'en affiche aucun. Un redéploiement garde le `.env` du VPS (relu par l'API Hostinger) ; les secrets de reconstruction sont aussi dans les variables de l'environnement Claude Code (`LNCLASS_RAILS_MASTER_KEY`, `LNCLASS_R2_ACCESS_KEY_ID`, `LNCLASS_R2_SECRET_ACCESS_KEY`, `LNCLASS_CLAUDE_AGENTAI_SECRET`, `GH_DEPLOY_TOKEN`), qui priment. Railway ne sert plus qu'à créer un projet absent, tant qu'il existe.
- Les fichiers sont sur R2 (`lnclass-production`). La bascule (`deploy/hostinger/bascule.yaml`) copie fichiers et base, puis compare les deux côtés.
- **Amendement du 2026-11-17 (décision du porteur, « 1A 2A ») :** Staging et Develop quittent Railway pour le même VPS, projets `lnclass-staging` et `lnclass-develop` (`deploy/hostinger/test.yaml`) : base neuve remplie du jeu standard, fichiers sur un volume Docker (`ACTIVE_STORAGE_SERVICE=local`), mémoire et CPU plafonnés, application seule sur le réseau `lnclass_web`, servie par le Caddy de la production sous ses noms. Les environnements de PR disparaissent avec Railway : une PR se teste en local (`bin/tester-pr`).

## 5. Conséquences

### 🟢 Positives

- Un prix fixe, sans facture à l'usage pour la production.
- La base n'est joignable que depuis le réseau Docker du serveur.

### 🔴 Coûts consentis

- Le serveur est à nous : mises à jour, disque et sauvegardes à surveiller.
- Déployer demande deux appels (construction, puis démarrage) : pas encore de déploiement automatique à la fusion sur `main`, `Staging` ou `Develop`.
- Staging et Develop partagent le serveur de la production : plafonnés, ils ne peuvent pas la priver de mémoire, mais une construction d'image prend du CPU au serveur.
- Les scripts et skills qui citent Railway pour la production sont à reprendre.
