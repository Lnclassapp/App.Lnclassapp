# ADR-0060 : La photo de profil est recadrée par le navigateur, vérifiée sans bibliothèque par le serveur, et servie seulement après la règle de lecture d'un compte

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-28 |
| **Chantier** | `docs/chantiers/photo-de-profil` |
| **Remplace** | — |
| **Remplacé par** | — |

> Numérotation : plus haut numéro existant au 2026-09-28 (0056) **+ 4**, pour éviter les collisions avec les chantiers ouverts en parallèle.

---

## 1. Contexte et problématique

Le porteur demande une photo de profil pour tous les comptes (2026-09-28). Active Storage existe (imports, ADR-0047 : un bucket S3 par environnement) mais ni `image_processing` ni libvips ne sont dans l'image de production : les variants serveur sont impossibles, et ajouter `ruby-vips` a déjà cassé la construction Docker. Le public est sur téléphone d'entrée de gamme et réseau lent. La photo d'un élève est une donnée personnelle d'un mineur : elle ne doit être vue que de lui, de ses enseignants et de l'équipe. La CSP est stricte (ADR-0049).

## 2. Moteurs de décision

1. Aucune dépendance native nouvelle en production.
2. Poids minimal sur le réseau, à l'envoi comme à l'affichage.
3. Aucune adresse publique permanente de l'image ; la lecture passe par une règle de domaine testée.
4. Le domaine ne voit pas Active Storage (comme `ImportFileStorePort`, ADR-0039).
5. Aucune métadonnée de prise de vue (position GPS) stockée.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Variants Active Storage (libvips) | Standard Rails ; plusieurs tailles | libvips absent en production ; construction Docker déjà cassée par `ruby-vips` ; envoi de 3 à 8 Mo sur réseau lent |
| B — Recadrage dans le navigateur (canvas), vérification serveur en Ruby pur, lecture par un contrôleur authentifié | Aucune dépendance ; quelques dizaines de Ko envoyés ; le canvas ne recopie pas l'Exif ; la règle de lecture est celle du domaine | **Retenue** |
| C — Recadrage navigateur, puis URL `rails_storage_proxy` signée à durée courte | Moins de code serveur | L'URL est un laissez-passer sans session : qui la reçoit voit l'image jusqu'à l'expiration ; le contrôleur proxy d'Active Storage répond `Cache-Control: public` pour toujours ; une URL qui expire change à chaque page et ruine le cache sur réseau lent |
| D — URL présignée du bucket (redirection) | Décharge le serveur | Même laissez-passer sans session ; `img-src` devrait autoriser l'hôte du bucket |

## 4. Décision

> **Le navigateur recadre au centre en carré de 512 px et compresse (WebP, sinon JPEG, 80 %) avant l'envoi ; le serveur identifie le format par le contenu, sans bibliothèque, et refuse au-delà de 1 Mo, de 1024 px de côté, hors JPEG/PNG/WebP ou avec des métadonnées ; l'image est lue par `GET /accounts/:user_public_id/photo`, sous session et sous `ReadUserPolicy`, en `Cache-Control: private`, l'adresse portant une version tirée de l'empreinte du fichier.**

- **Domaine (`identity`)** :
  - `Entities::Identity::ImageHeader.read(bytes)` → `Facts(format, width, height, metadata)` | nil : lecture des en-têtes JPEG (segments SOFn ; APP1 Exif/XMP, APP13 IPTC), PNG (IHDR ; `eXIf`, `iTXt`) et WebP (`VP8 `, `VP8L`, `VP8X` ; `EXIF`, `XMP `). Ruby pur.
  - `Entities::Identity::ProfilePhoto` : `CONTENT_TYPES` (jpeg, png, webp), `MAX_BYTES` = 1 Mo, `MAX_SIDE` = 1024.
  - `Dtos::Identity::ProfilePhotoInput(io:)` : présence, poids **avant** lecture, puis format, dimensions et métadonnées.
  - Port `Ports::Identity::ProfilePhotoStorePort` : `attach(user_id:, data:, content_type:)` → true (remplace), `attached?(user_id:)` → Boolean, `remove(user_id:)` → Boolean (efface le fichier), `read(user_id:)` → `StoredPhoto(content_type, data)` | nil.
  - Use cases `ChangeOwnPhoto` et `RemoveOwnPhoto` sous `UpdateSelfPolicy` (ADR-0028), `Shared::Result` (ADR-0026), audit `profile.photo_changed` (format, poids, dimensions) et `profile.photo_removed` ; `ReadAccountPhoto` sous `ReadUserPolicy`, où « enseigne » = la classe principale de l'élève (active ou archivée, comme la liste nominative) est déclarée par l'enseignant.
- **Infrastructure** : `Orm::User has_one_attached :photo` (aucune migration : les tables Active Storage existent) ; `Repositories::Identity::ProfilePhotoStore` ; le blob est créé `analyzed: true` pour qu'aucun `AnalyzeJob` ne cherche libvips. `Queries::Identity::PhotoVersions` donne la version (empreinte MD5 du blob, en base64 URL) aux requêtes du shell, du profil, de la liste de classe et du compte retrouvé.
- **Delivery** : `Identity::ProfilePhotosController` (`edit`, `update`, `destroy` sur `/profile/photo`) et `Identity::AccountPhotosController#show`, `send_data` en `inline`, `Cache-Control: private, max-age=86400` ; une nouvelle photo change l'adresse, donc le cache ne sert jamais une photo périmée.
- **CSP** : inchangée. L'image vient de la même origine (`img-src 'self'`) ; l'aperçu local est un `blob:` (déjà permis). Aucun script en ligne : le recadrage est le contrôleur Stimulus `identity--photo-picker`.
- **Aucune adresse Active Storage** (`/rails/active_storage/...`) n'est émise pour une photo : aucun `signed_id` de photo ne sort du serveur.

## 5. Conséquences

### 🟢 Positives

- Aucune dépendance nouvelle, aucune migration ; la construction Docker ne change pas.
- Envoi typique de 20 à 60 Ko au lieu de plusieurs Mo ; affichage mis en cache par le navigateur jusqu'au changement de photo.
- La lecture d'une photo applique la même règle que la lecture d'un compte : une seule règle, testée dans le domaine.
- La position GPS d'une photo de téléphone ne peut pas être stockée : soit le canvas l'a retirée, soit le serveur refuse.

### 🔴 Coûts consentis

- Chaque image affichée repasse par Rails (session, règle, lecture du bucket) : une liste de quarante élèves coûte quarante requêtes au premier affichage, puis zéro grâce au cache privé.
- Un navigateur sans canvas ni `DataTransfer` envoie le fichier brut : une photo de téléphone y sera refusée (trop lourde ou avec Exif). Le message dit quoi faire, mais l'utilisateur n'a pas d'autre recours.
- Une seule taille (512 px) sert tous les avatars, y compris ceux de 32 px.
- Le cache privé du navigateur garde la photo sur un téléphone partagé après la déconnexion (au plus un jour).
- Le lecteur d'en-têtes est du code maison : il ne valide pas l'image entière, seulement son format, ses dimensions et ses métadonnées. Une image corrompue au-delà de l'en-tête s'affiche cassée ; elle n'est jamais décodée par le serveur.

## 6. Notes d'implémentation

```ruby
# app/domain/use_cases/identity/change_own_photo.rb (extrait)
allowed = @policy.call(actor:, target: user)
return allowed if allowed.failure?
return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

@transaction.call { store(user, dto, ip) }
```

```js
// app/javascript/controllers/identity/photo_picker_controller.js (extrait)
const side = Math.min(image.naturalWidth, image.naturalHeight)
const size = Math.min(SIZE, side)
canvas.getContext("2d").drawImage(image, (image.naturalWidth - side) / 2, (image.naturalHeight - side) / 2, side, side, 0, 0, size, size)
```

## 7. Comment vérifier que la décision est respectée

- Tests du domaine : `ImageHeader` sur de vrais en-têtes JPEG, PNG et WebP (lossy, lossless, étendu), avec et sans métadonnées ; `ProfilePhotoInput` sur chaque refus ; les trois use cases (refus de la policy, invalide, succès, audit).
- Test de l'adaptateur : attache, remplace (l'ancien blob est purgé), relit, retire (le fichier disparaît du service).
- Tests des contrôleurs : 422 par cas, aucun identifiant pris, `Cache-Control: private`, 403 pour un autre élève.
- Test système : ajout depuis un fichier, aperçu, menu du compte, retrait ; image lourde allégée par le navigateur ; refus d'un PDF ; 390 px.
- `grep -rn "rails_blob\|rails_storage\|signed_id" app` ne trouve rien pour les photos.
