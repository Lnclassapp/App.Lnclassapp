# Journal — Héberger la production sur Cloudflare

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-17 | Production seule sur Cloudflare ; base PlanetScale via Cloudflare ; Synape-ci et N8N intouchés | Choix du porteur | ADR-0139 |
| 2026-11-17 | Politique `durable_object` (bêta) pour une instance de 1/4 vCPU et 1,5 Gio | La politique `default` impose 1 vCPU et 3 Gio au moins par instance sur mesure, environ 20 $ de mémoire par mois | idem |
| 2026-11-17 | **Revirement** : la production va sur un VPS Hostinger KVM 2 (Paris, Ubuntu 26.04 avec Docker), Rails, Postgres 18 et Caddy dans un projet Docker (`deploy/hostinger/compose.yaml`) ; Cloudflare reste devant (DNS, proxy, HTTPS) et R2 garde les fichiers et les sauvegardes de la base | PlanetScale refuse les cartes prépayées (17 $/mois) ; choix du porteur : Hostinger, KVM 2, Ubuntu 26.04 | ADR-XXXX-hebergement-hostinger |
| 2026-11-17 | Configuration du VPS par l'API Hostinger seulement (script d'installation, pare-feu, gestionnaire Docker) | La session d'agent ne sort qu'en HTTPS : pas de SSH | idem |
| 2026-11-17 | Les secrets passent de Railway (variables du service et variables partagées) au `.env` du projet par un script qui n'en affiche aucun ; le mot de passe Postgres est tiré sur le serveur et n'en sort pas | Règle « jamais de secret dans le chat » | idem |

## À trancher

- [ ] 2026-11-17 · hebergement-cloudflare · Activer l'offre Workers Paid, R2 et créer la base PlanetScale PS-5 (europe-west4) — engagent un paiement : réservé au porteur, dans le tableau de bord. Rien appliqué.
- [ ] 2026-11-17 · hebergement-cloudflare · Enregistrements DNS d'avant l'incident autres que ceux de Railway (MX de contact@lnclass.com, SPF, vérifications) — appliqué : aucun, faute de trace ; à remettre par le porteur s'ils existaient.
- [ ] 2026-11-17 · hebergement-cloudflare · Échec de `db:prepare` ou `db:seed` au démarrage du conteneur — appliqué : le Worker répond 503 (« Service indisponible », `Retry-After: 30`) et relance au prochain appel ; sur Railway, le `preDeploy` refusait le déploiement et l'ancienne version servait. Autre : migrations lancées par Workers Builds avant `wrangler deploy` (accès base depuis la construction). Recommandé : garder tel quel, migrations rétrocompatibles comme aujourd'hui.
- [ ] 2026-11-17 · hebergement-cloudflare · Branche de production de Workers Builds pour `app-lnclassapp` — appliqué : aucune, la PR ne la change pas ; autres : `main` (comme Railway), `Develop` ; recommandé : `main`. Sans objet depuis le passage à Hostinger : le Worker et l'offre Workers Paid (5 $/mois) peuvent être retirés par le porteur.
- [ ] 2026-11-17 · hebergement-cloudflare · Où tourne Rails avec le VPS — appliqué : tout sur le VPS (la base n'est publiée sur aucun port) ; autre : base seule sur le VPS, Rails dans un conteneur Cloudflare (base ouverte sur Internet, Workers Paid en plus). Recommandé : tel quel.
- [ ] 2026-11-17 · hebergement-cloudflare · Accès SSH au VPS — appliqué : port 22 ouvert, mot de passe root aléatoire tiré par Hostinger (réinitialisable dans hPanel), fail2ban (5 essais, banni un jour) ; autre : clé SSH du porteur et mots de passe refusés. Recommandé : ajouter la clé du porteur puis couper les mots de passe.
- [ ] 2026-11-17 · hebergement-cloudflare · Enregistrements DNS de Staging et Develop (`staging`, `app-staging`, `develop`, `app-develop`, CNAME proxifiés vers Railway) supprimés par le porteur pendant la bascule — appliqué : rien, le jeton de la session ne peut pas écrire ; à remettre par le porteur (valeurs dans la PR).
- [ ] 2026-11-17 · hebergement-cloudflare · Règle de cycle de vie R2 (**7 jours** sur `backups/postgres/`, durée tranchée par le porteur le 2026-11-17) — appliqué : aucune, pas de droit d'écriture R2 sur la configuration du bucket ; à poser par le porteur (R2, lnclass-production, Settings, Object lifecycle rules). Sans elle, les sauvegardes s'accumulent.
- [ ] 2026-11-17 · hebergement-cloudflare · Develop et Staging (le porteur veut tout supprimer sur Railway) — appliqué : rien, ils restent sur Railway ; autres : les migrer sur le VPS en projets à part, mémoire et CPU plafonnés, base neuve du jeu standard (recommandé, 0 € de plus) ; les migrer avec leurs données ; les supprimer et ne tester qu'en local (`bin/tester-pr`). **Ne pas supprimer Railway avant d'avoir tranché ce point et le suivant.**
- [ ] 2026-11-17 · hebergement-cloudflare · Secrets de déploiement (clé maître Rails, clés R2 `CIBLE_*`, `GH_DEPLOY_TOKEN`) lus dans Railway par `script/hostinger/deployer.py` — appliqué : rien ; supprimer Railway empêcherait tout redéploiement de la production. Autres : variables de l'environnement Claude Code (recommandé, le porteur les saisit) ; relire le `.env` du VPS (une seule copie de la clé maître).
- [ ] 2026-11-17 · hebergement-cloudflare · Suites de la revue de sécurité de la PR #658 — appliqué : IP du client réelle derrière Caddy (bloquant corrigé), confirmation explicite et copie de base unique, projets ponctuels supprimés du VPS après usage, secrets hors des arguments de `curl`, révision limitée à un SHA de `main`, sauvegarde réduite à ses variables. Reste, à décider par le porteur : bucket R2 dédié aux sauvegardes avec son propre jeton et verrou de rétention, dumps chiffrés (`age`, clé privée gardée hors du VPS), rôle Postgres applicatif non superutilisateur, images épinglées par empreinte.
- [ ] 2026-11-17 · hebergement-cloudflare · Arrêt définitif de Railway production (application et base) — appliqué : application arrêtée, base gardée ; à supprimer par le porteur le 2026-11-24 si rien n'a manqué.
- [x] 2026-11-17 · hebergement-cloudflare · Proxy TCP du Postgres de Staging (ouvert pour la répétition de la copie de la base) — fermé le 2026-11-17 à la demande du porteur (« ferme-le »).

## Ce qui a dérapé

- 2026-11-17 : **bascule faite**. Railway arrêté à 21 h 27 UTC ; base de production copiée et vérifiée (BASE OK), fichiers à jour (466, 0 écart) ; `lnclass.com` et `www` en A proxifié vers 2.25.12.132 (posés par le porteur : le jeton Cloudflare de la session est en lecture seule, et un jeton enregistré ensuite reste masqué par celui du connecteur) ; site rendu à 21 h 45 UTC, 18 minutes de coupure au lieu de 10. Le porteur a supprimé toute la zone DNS en route : Staging et Develop coupés jusqu'à ce que leurs 4 CNAME soient remis. Pare-feu 80/443 limité aux plages Cloudflare, proxy TCP de la base de production supprimé. Railway (application arrêtée, base intacte) gardé 7 jours pour revenir en arrière.

- 2026-11-17 : un premier déploiement a rattaché lnclass.com au Worker de démarrage (« Hello world ») et retiré les domaines de Railway. Production coupée. Domaines remis sur Railway par l'agent.
- 2026-11-17 (16 h 35 UTC) : la zone lnclass.com s'est retrouvée sans aucun enregistrement DNS ; production, Staging et Develop injoignables. L'agent a recréé par l'API Cloudflare les CNAME (proxifiés) vers Railway de `lnclass.com`, `www`, `staging`, `app-staging`, `develop`, `app-develop` et les deux TXT `_railway-verify`, puis mis le port cible des domaines de production à 8080, comme Staging et Develop. `/up` répond 200 partout à 16 h 41 UTC. Les journaux d'audit ne sont pas lisibles avec le jeton : tout autre enregistrement d'avant (MX, SPF, vérifications de services) est perdu et doit être remis par le porteur s'il existait.
- 2026-11-17 : la construction Workers Builds de la PR a échoué sans journal lisible avec le jeton. Les constructions hors branche de production lancent `wrangler preview` ou `versions upload`, qui ne prennent pas en charge les conteneurs gérés par Durable Object : rien à corriger dans le code ; seule la branche de production déploie.
- 2026-11-17 : revues sécurité et pannes silencieuses : redirection HTTP → HTTPS dans le Worker (Rails fait confiance à `X-Forwarded-Proto`), conteneur bloqué remplacé, démarrage raté en 503 au lieu d'une attente de 3 minutes, cron en échec visible ; script de bascule sans identifiants en argument, dump en 0600 hors du dépôt et supprimé, restauration en une transaction.
- 2026-11-17 : Workers Builds a échoué (« Could not detect a directory containing static files ») : le dépôt n'avait pas de `wrangler.jsonc`, Wrangler cherchait un site statique.

- 2026-11-17 : le gestionnaire Docker de Hostinger ne construit pas les images (il tire tout, puis « up » sans construction) : premier déploiement en échec. L'image est construite sur le serveur par un projet à part (`deploy/hostinger/construction.yaml`), environ 10 minutes.

## Ce qu'on a appris sur la codebase

- Répétition de la bascule (2026-11-17) : fichiers Railway → R2, 466 objets, 0 écart ; base de Staging → Postgres du VPS en une minute, comptage identique table par table ; application `main` démarrée sur `srv2172236.hstgr.cloud` (`/up`, `/`, `/login` en 200).
- Créer le proxy TCP du Postgres de production redémarre la base de production : on le fait dans le créneau de bascule, l'application déjà arrêtée.
- Seules sorties de l'application vers l'extérieur : OpenRouter (CRM, à la demande) ; les tâches récurrentes restent internes. Pas de SMTP.

- Railway prépare la base par son `preDeploy` ; Cloudflare n'a pas d'équivalent : `bin/docker-entrypoint` le fait quand `PREPARE_DATABASE=1`.
- Solid Queue tourne dans Puma et une tâche récurrente passe toutes les 5 minutes : le conteneur doit rester allumé (cron du Worker).
- `config.hosts` vérifie l'en-tête `Host` : le Worker garde l'hôte public dans l'URL transmise au conteneur.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Service de stockage nommé `railway` alors qu'il pointera vers R2 | Renommer touche Staging et Develop, restés sur Railway | à ouvrir après la bascule |
| Scripts et skills qui citent Railway (`bin/jeu-standard`, `prod-agent`, `publier-prod`…) | Hors périmètre de la bascule | à ouvrir après la bascule |
| Workers Builds installe Ruby (7 min) avant `wrangler deploy` | Détection automatique de l'outil, sans effet sur l'image | — |
