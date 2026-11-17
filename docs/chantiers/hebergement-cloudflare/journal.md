# Journal — Héberger la production sur Cloudflare

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-17 | Production seule sur Cloudflare ; base PlanetScale via Cloudflare ; Synape-ci et N8N intouchés | Choix du porteur | ADR-XXXX-hebergement-cloudflare |
| 2026-11-17 | Politique `durable_object` (bêta) pour une instance de 1/4 vCPU et 1,5 Gio | La politique `default` impose 1 vCPU et 3 Gio au moins par instance sur mesure, environ 20 $ de mémoire par mois | idem |

## À trancher

- [ ] 2026-11-17 · hebergement-cloudflare · Branche de production de Workers Builds pour `app-lnclassapp` — appliqué : aucune, la PR ne la change pas ; autres : `main` (comme Railway), `Develop` ; recommandé : `main`.

## Ce qui a dérapé

- 2026-11-17 : un premier déploiement a rattaché lnclass.com au Worker de démarrage (« Hello world ») et retiré les domaines de Railway. Production coupée. Domaines remis sur Railway par l'agent ; les enregistrements DNS (CNAME vers Railway, TXT de vérification) et le retrait du domaine du Worker restent à faire dans le tableau de bord (jeton de la session en lecture seule sur les Workers).
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
