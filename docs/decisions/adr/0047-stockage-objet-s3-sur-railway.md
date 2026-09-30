# ADR-0047 : Fichiers en production sur un bucket Railway compatible S3, servis par l'application en mode proxy

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-25**, bloque la V0 |
| **Complète** | [ADR-0010](./0010-stack-ops-solid-suite-postgresql-railway.md) (hébergement Railway) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ancien dépôt stocke les fichiers avec Active Storage en `:local`, sur le disque du conteneur. Chaque déploiement Railway efface donc avatars, couvertures de cours et de fiches, images et audio des annonces. Le registre prévoit un stockage objet « dès qu'un téléversement existe ». Le porteur exclut tout fournisseur payant externe.

Railway propose des *Storage Buckets*, dans le projet même :

- **privés**, sans bucket public ;
- compatibles S3 (lecture, écriture, URL présignées, envoi en plusieurs parties) ;
- un bucket isolé par environnement ;
- chiffrés au repos ;
- sans sauvegarde automatique ;
- facturés 0,015 $ par Go et par mois, egress du bucket gratuit.

La CSP de l'[ADR-0049](./0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) limite `img-src`, `media-src` et `connect-src` à `'self'`.

## 2. Moteurs de décision

1. Aucun fichier perdu au déploiement.
2. Aucun nouveau fournisseur ni domaine tiers dans la CSP.
3. Recette et production ne partagent aucun fichier.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Volume Railway monté | Aucun changement de code | Lié à une instance, sauvegarde et multi-instance délicates |
| B — Fournisseur S3 externe (AWS, R2) | Mûr | Fournisseur payant externe, exclu par le porteur |
| C — **Bucket Railway, fichiers servis par l'application** | Même fournisseur, CSP inchangée | Le trafic des fichiers passe par Puma |

## 4. Décision

> **Nous stockons les fichiers de recette et de production sur un bucket Railway par environnement, via le service S3 d'Active Storage, et nous les servons par l'application en mode proxy, sans URL présignée ni envoi direct.**

**Quand** : dès la V0. Le bucket coûte presque rien, et un seul téléversement sur disque suffit à perdre un fichier.

**Configuration** :

- `config/storage.yml`, service `railway` ;
- variables de service référencées depuis le bucket (`ENDPOINT`, `BUCKET`, `ACCESS_KEY_ID`, `SECRET_ACCESS_KEY`, `REGION`), déclarées dans `railway.json` ou dans l'environnement Railway, jamais dans le dépôt ;
- `config.active_storage.service = :railway` en `production`, le même fichier servant la recette ;
- `:local` en développement, `:test` en test ;
- gemme `aws-sdk-s3`, sans service externe.

**Service des fichiers** : `config.active_storage.resolve_model_to_route = :rails_storage_proxy`. Les URL restent sur l'origine de l'application, et la CSP n'est pas élargie.

- Les pièces jointes sensibles (celles d'une annonce d'école) passent par un contrôleur qui applique la policy de lecture (ADR-0045) avant `send_blob_stream`. Les routes génériques d'Active Storage ne sont utilisées que pour les fichiers publics du catalogue.
- En-tête `Cache-Control: private` pour les premières, `public, max-age=31536000, immutable` pour les secondes.

**Envoi** : toujours par le serveur, avec un formulaire classique. Pas de `direct_upload` : il exigerait d'ajouter le domaine du bucket à `connect-src`.

**Variantes d'image** : aucune en V1, pas de `libvips` dans l'image Docker. Les tailles sont bornées à l'envoi (ADR-0045 pour les annonces : 2 Mo par image).

**Purge** : `purge_later` au remplacement ou à la suppression d'une pièce jointe. Le job récurrent `Shared::PurgeUnattachedBlobsJob` supprime chaque jour les blobs non rattachés depuis plus de 48 h.

## 5. Conséquences

### 🟢 Positives

- Les fichiers survivent aux déploiements, sans nouveau fournisseur.
- La CSP reste `'self'` : aucune exception de domaine.
- La recette ne peut pas écraser un fichier de production.

### 🔴 Coûts consentis

- **Aucune sauvegarde automatique** : un fichier supprimé du bucket est perdu. Aucune production d'élève n'est stockée en fichier en V1 ; le contenu se réimporte (ADR-0039).
- Le mode proxy fait passer chaque octet par Puma. Ce trafic sortant du service est facturé, contrairement à l'egress du bucket.
- Pas de redimensionnement : une image lourde est servie telle quelle, dans la limite de taille.

## 6. Notes d'implémentation

```yaml
# config/storage.yml
railway:
  service: S3
  endpoint: <%= ENV["BUCKET_ENDPOINT"] %>
  bucket: <%= ENV["BUCKET_NAME"] %>
  access_key_id: <%= ENV["BUCKET_ACCESS_KEY_ID"] %>
  secret_access_key: <%= ENV["BUCKET_SECRET_ACCESS_KEY"] %>
  region: <%= ENV.fetch("BUCKET_REGION", "auto") %>
  force_path_style: <%= ENV["BUCKET_FORCE_PATH_STYLE"] == "true" %>
```

Les variables `BUCKET_*` du service web référencent celles du bucket (`${{Bucket.ENDPOINT}}`…).

## 7. Comment vérifier que la décision est respectée

- `test/config/storage_test.rb` : en `production`, `ActiveStorage::Blob.service.name == :railway` et `resolve_model_to_route == :rails_storage_proxy`.
- Le test de CSP de l'ADR-0049 échoue si `img-src` ou `connect-src` contient un domaine.
- Recette : un fichier envoyé survit à un redéploiement (vérification manuelle de la V0, consignée dans le journal).

## 8. Remplace, complète, amende

- **Complète** l'ADR-0010 : le stockage de fichiers reste chez Railway, sur un bucket et non sur le disque du conteneur.

## 9. Points à confirmer par le porteur

- Bucket créé dès la V0, même si la V1 ne téléverse rien.
- Mode proxy plutôt que des URL présignées.
- Absence de sauvegarde des fichiers acceptée en V1.

## Amendement du 2026-09-30 — plusieurs fichiers par rapport d'import

*[ADR-0068](./0068-import-de-plusieurs-fichiers-de-cours-et-ecriture-acceleree.md). Un rapport d'import porte désormais ses fichiers en `has_many_attached :sources`, au lieu de `has_one_attached :source`. Ils sont stockés sur le même service, avec la même règle : des clés aléatoires, et le nom du client en métadonnée seulement.*
