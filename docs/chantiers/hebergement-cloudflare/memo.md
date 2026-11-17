# Memo — Héberger la production sur Cloudflare

| | |
|---|---|
| **Type de cycle** | refactoring (comportement identique, hébergeur changé) |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-17 |
| **Branche** | `feature/hebergement-cloudflare` |
| **Programme** | — |

---

## Le problème

La facture Railway monte (estimée entre 25 et 45 $ par mois, la facture elle-même n'est pas lisible par l'agent). La production ne consomme presque rien : 0,63 Go de mémoire en moyenne, 1,13 Go au pic, processeur presque nul, base de 0,5 Go (mesure Railway sur 7 jours, 2026-11-17).

## Pour qui

Le porteur, qui paie. Aucun acteur de l'application ne doit voir de différence.

## Pourquoi maintenant

Décision du porteur du 2026-11-17 : migrer la production seule, base sur PlanetScale facturée via Cloudflare.

## Hors périmètre

- Staging, Develop et les environnements de PR restent sur Railway (`.railway/railway.ts`).
- Les projets Railway « Synape-ci » et « Lnclass N8N » ne sont pas touchés.
- Renommer le service de stockage `railway` de `config/storage.yml` : R2 parle S3, seules les variables `BUCKET_*` changent.

## Cible

| Élément | Offre | Coût estimé par mois |
|---|---|---|
| Socle | Workers Paid | 5 $ |
| App | Cloudflare Containers, instance 1/4 vCPU, 1,5 Gio, toujours allumée | environ 10 $ |
| Base | PlanetScale Postgres PS-5, région europe-west4 | 5 $ + stockage |
| Fichiers | R2 | 0 $ (10 Go gratuits) |

## Bascule (une fois la PR fusionnée et déployée)

1. Variables et secrets du Worker (`app-lnclassapp` → Settings → Variables and Secrets) : `DATABASE_URL` (PlanetScale), `RAILS_MASTER_KEY`, `BUCKET_ENDPOINT` (`https://<compte>.r2.cloudflarestorage.com`), `BUCKET_NAME`, `BUCKET_ACCESS_KEY_ID`, `BUCKET_SECRET_ACCESS_KEY`, `BUCKET_REGION=auto`, `APP_HOSTS`, `CANONICAL_HOST`, `OPENROUTER_*`, `ANDROID_*`, `TEAM_BOOTSTRAP_CONTACT`, comme sur Railway.
2. Vérifier l'app sur l'adresse `*.workers.dev` (ajoutée à `APP_HOSTS` le temps de la vérification).
3. Coupure : `script/cloudflare/bascule base` (`pg_dump` Railway → `pg_restore` PlanetScale, refuse une cible non vide), `script/cloudflare/bascule fichiers` (bucket Railway → R2), puis `script/cloudflare/bascule verifier` (lignes par table et objets identiques des deux côtés). Les accès passent par l'environnement (`SOURCE_*`, `CIBLE_*`, en tête du script).
4. Rattacher lnclass.com et www.lnclass.com au Worker ; garder Railway arrêté mais intact 7 jours.
