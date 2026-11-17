# Journal — Héberger la production sur Cloudflare

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-17 | Production seule sur Cloudflare ; base PlanetScale via Cloudflare ; Synape-ci et N8N intouchés | Choix du porteur | ADR-0139 |
| 2026-11-17 | Politique `durable_object` (bêta) pour une instance de 1/4 vCPU et 1,5 Gio | La politique `default` impose 1 vCPU et 3 Gio au moins par instance sur mesure, environ 20 $ de mémoire par mois | idem |
| 2026-11-17 | **Revirement** : la production va sur un VPS Hostinger KVM 2 (Paris, Ubuntu 26.04 avec Docker), Rails, Postgres 18 et Caddy dans un projet Docker (`deploy/hostinger/compose.yaml`) ; Cloudflare reste devant (DNS, proxy, HTTPS) et R2 garde les fichiers et les sauvegardes de la base | PlanetScale refuse les cartes prépayées (17 $/mois) ; choix du porteur : Hostinger, KVM 2, Ubuntu 26.04 | ADR à écrire (remplace en partie l'ADR-0139) |
| 2026-11-17 | Configuration du VPS par l'API Hostinger seulement (script d'installation, pare-feu, gestionnaire Docker) | La session d'agent ne sort qu'en HTTPS : pas de SSH | idem |
| 2026-11-17 | Les secrets passent de Railway (variables du service et variables partagées) au `.env` du projet par un script qui n'en affiche aucun ; le mot de passe Postgres est tiré sur le serveur et n'en sort pas | Règle « jamais de secret dans le chat » | idem |

## À trancher

- [ ] 2026-11-17 · hebergement-cloudflare · Activer l'offre Workers Paid, R2 et créer la base PlanetScale PS-5 (europe-west4) — engagent un paiement : réservé au porteur, dans le tableau de bord. Rien appliqué.
- [ ] 2026-11-17 · hebergement-cloudflare · Enregistrements DNS d'avant l'incident autres que ceux de Railway (MX de contact@lnclass.com, SPF, vérifications) — appliqué : aucun, faute de trace ; à remettre par le porteur s'ils existaient.
- [ ] 2026-11-17 · hebergement-cloudflare · Échec de `db:prepare` ou `db:seed` au démarrage du conteneur — appliqué : le Worker répond 503 (« Service indisponible », `Retry-After: 30`) et relance au prochain appel ; sur Railway, le `preDeploy` refusait le déploiement et l'ancienne version servait. Autre : migrations lancées par Workers Builds avant `wrangler deploy` (accès base depuis la construction). Recommandé : garder tel quel, migrations rétrocompatibles comme aujourd'hui.
- [ ] 2026-11-17 · hebergement-cloudflare · Branche de production de Workers Builds pour `app-lnclassapp` — appliqué : aucune, la PR ne la change pas ; autres : `main` (comme Railway), `Develop` ; recommandé : `main`. Sans objet depuis le passage à Hostinger : le Worker et l'offre Workers Paid (5 $/mois) peuvent être retirés par le porteur.
- [ ] 2026-11-17 · hebergement-cloudflare · Où tourne Rails avec le VPS — appliqué : tout sur le VPS (la base n'est publiée sur aucun port) ; autre : base seule sur le VPS, Rails dans un conteneur Cloudflare (base ouverte sur Internet, Workers Paid en plus). Recommandé : tel quel.
- [ ] 2026-11-17 · hebergement-cloudflare · Accès SSH au VPS — appliqué : port 22 ouvert, mot de passe root aléatoire tiré par Hostinger (réinitialisable dans hPanel), fail2ban (5 essais, banni un jour) ; autre : clé SSH du porteur et mots de passe refusés. Recommandé : ajouter la clé du porteur puis couper les mots de passe.
- [ ] 2026-11-17 · hebergement-cloudflare · Proxy TCP du Postgres de Staging (ouvert pour la répétition de la copie de la base) — appliqué : laissé ouvert, le porteur a refusé deux fois sa suppression (demande mal comprise) ; mot de passe fort, SSL. Recommandé : le supprimer (Railway, Staging, Postgres, Settings, TCP Proxy), 30 s de redémarrage de la base de Staging.

## Ce qui a dérapé

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
