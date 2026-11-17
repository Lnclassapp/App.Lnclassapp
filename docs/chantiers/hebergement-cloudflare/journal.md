# Journal — Héberger la production sur Cloudflare

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-17 | Production seule sur Cloudflare ; base PlanetScale via Cloudflare ; Synape-ci et N8N intouchés | Choix du porteur | ADR-XXXX-hebergement-cloudflare |
| 2026-11-17 | Politique `durable_object` (bêta) pour une instance de 1/4 vCPU et 1,5 Gio | La politique `default` impose 1 vCPU et 3 Gio au moins par instance sur mesure, environ 20 $ de mémoire par mois | idem |

## À trancher

- [ ] 2026-11-17 · hebergement-cloudflare · Activer l'offre Workers Paid, R2 et créer la base PlanetScale PS-5 (europe-west4) — engagent un paiement : réservé au porteur, dans le tableau de bord. Rien appliqué.
- [ ] 2026-11-17 · hebergement-cloudflare · Enregistrements DNS d'avant l'incident autres que ceux de Railway (MX de contact@lnclass.com, SPF, vérifications) — appliqué : aucun, faute de trace ; à remettre par le porteur s'ils existaient.
- [ ] 2026-11-17 · hebergement-cloudflare · Branche de production de Workers Builds pour `app-lnclassapp` — appliqué : aucune, la PR ne la change pas ; autres : `main` (comme Railway), `Develop` ; recommandé : `main`.

## Ce qui a dérapé

- 2026-11-17 : un premier déploiement a rattaché lnclass.com au Worker de démarrage (« Hello world ») et retiré les domaines de Railway. Production coupée. Domaines remis sur Railway par l'agent.
- 2026-11-17 (16 h 35 UTC) : la zone lnclass.com s'est retrouvée sans aucun enregistrement DNS ; production, Staging et Develop injoignables. L'agent a recréé par l'API Cloudflare les CNAME (proxifiés) vers Railway de `lnclass.com`, `www`, `staging`, `app-staging`, `develop`, `app-develop` et les deux TXT `_railway-verify`, puis mis le port cible des domaines de production à 8080, comme Staging et Develop. `/up` répond 200 partout à 16 h 41 UTC. Les journaux d'audit ne sont pas lisibles avec le jeton : tout autre enregistrement d'avant (MX, SPF, vérifications de services) est perdu et doit être remis par le porteur s'il existait.
- 2026-11-17 : Workers Builds a échoué (« Could not detect a directory containing static files ») : le dépôt n'avait pas de `wrangler.jsonc`, Wrangler cherchait un site statique.

## Ce qu'on a appris sur la codebase

- Railway prépare la base par son `preDeploy` ; Cloudflare n'a pas d'équivalent : `bin/docker-entrypoint` le fait quand `PREPARE_DATABASE=1`.
- Solid Queue tourne dans Puma et une tâche récurrente passe toutes les 5 minutes : le conteneur doit rester allumé (cron du Worker).
- `config.hosts` vérifie l'en-tête `Host` : le Worker garde l'hôte public dans l'URL transmise au conteneur.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Service de stockage nommé `railway` alors qu'il pointera vers R2 | Renommer touche Staging et Develop, restés sur Railway | à ouvrir après la bascule |
| Scripts et skills qui citent Railway (`bin/jeu-standard`, `prod-agent`, `publier-prod`…) | Hors périmètre de la bascule | à ouvrir après la bascule |
| Workers Builds installe Ruby (7 min) avant `wrangler deploy` | Détection automatique de l'outil, sans effet sur l'image | — |
