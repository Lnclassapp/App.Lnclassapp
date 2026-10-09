# ADR-0060 : La photo de profil est recadrée par le navigateur, vérifiée sans bibliothèque par le serveur, et servie seulement après la règle de lecture d'un compte
<!-- index
titre: La photo de profil est recadrée par le navigateur, vérifiée sans bibliothèque par le serveur, et servie seulement après la règle de lecture d'un compte
statut: Accepté
problematique: Pas de libvips : canvas 512 px WebP/JPEG côté navigateur ; en-têtes JPEG/PNG/WebP lus en Ruby pur (≤ 1 Mo, ≤ 1024 px, Exif retiré) ; port `ProfilePhotoStorePort` ; lecture par `GET /accounts/:id/photo` sous `ReadUserPolicy`, cache privé. Numéro = plus haut (0056) + 4.
-->

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

> **Le navigateur recadre au centre en carré de 512 px et compresse (WebP, sinon JPEG, 80 %) avant l'envoi ; le serveur identifie le format par le contenu, sans bibliothèque, refuse au-delà de 1 Mo, de 1024 px de côté ou hors JPEG/PNG/WebP, et retire les métadonnées de ce qu'il garde ; l'image est lue par `GET /accounts/:user_public_id/photo`, sous session et sous `ReadUserPolicy`, en `Cache-Control: private`, l'adresse portant une version tirée de l'empreinte du fichier.**

- **Domaine (`identity`)** :
  - `Entities::Identity::ImageHeader.read(bytes)` → `Facts(format, width, height, metadata)` | nil : lecture des en-têtes JPEG (segments SOFn ; APP1 Exif/XMP, APP13 IPTC), PNG (IHDR ; `eXIf`, `iTXt`, `tEXt`, `zTXt`) et WebP (`VP8 `, `VP8L`, `VP8X` ; `EXIF`, `XMP `). `ImageHeader.strip(bytes)` retire ces segments et chunks (et, en WebP, recalcule la longueur RIFF et les drapeaux de VP8X). Ruby pur.
  - `Entities::Identity::ProfilePhoto` : `CONTENT_TYPES` (jpeg, png, webp), `MAX_BYTES` = 1 Mo, `MAX_SIDE` = 1024.
  - **Fail closed** (amendement du 2026-09-28, contre-épreuve de la PR #50) : `ImageHeader` lit **tout** le flux, pas seulement l'en-tête. JPEG : chaque segment jusqu'à EOI, qui devait terminer le fichier (depuis le retour du challenger #65 : ce qui le suit est coupé, voir plus bas), scans compris (données entropiques parcourues jusqu'au marqueur suivant) ; octets de remplissage `0xFF` acceptés avant un marqueur (T.81 § B.1.1.2) ; tout autre octet hors segment (`0x00` égaré, TEM, RSTn, second SOI) rend le fichier illisible ; un SOF avant le premier scan est exigé. PNG : IHDR d'abord, CRC de chaque chunk vérifié, un IDAT au moins, IEND à la toute fin. WebP : longueur RIFF égale au fichier, chaque chunk dans cette longueur, une seule image `VP8 ` (image clé, première partition dans le chunk) ou `VP8L`. Tout écart → `nil` → `:unsupported`. Sans cela, un JPEG posté directement avec un octet de remplissage ou un octet égaré avant son APP1 faisait perdre le fil à la lecture, et l'Exif (GPS compris) était stocké tel quel.
  - **Liste blanche, non liste noire** (second amendement du 2026-09-28) : seules les parties qui dessinent l'image restent, où qu'elles soient, y compris entre deux scans. JPEG : SOFn, DHT, DAC, DQT, DRI, DNL (refusé depuis le troisième retour du challenger #65), SOS avec son scan, EOI ; APP0 gardé seulement s'il commence par `JFIF\0`, **réécrit** dans sa forme standard (JFIF 1.01, sans unité, 1:1, sans vignette) ; APP14 gardé seulement avec la signature `Adobe` et la longueur standard, réécrit (version 100, drapeaux nuls, transformée d'origine). Tout autre APPn (JFXX, Exif, XMP, IPTC…), COM et JPGn partent. PNG : IHDR, PLTE, IDAT, IEND, tRNS, gAMA, sRGB (cHRM retiré depuis le second retour du challenger #65 ; PLTE seulement en mode indexé ; gAMA seulement plausible). WebP : `VP8 `, `VP8L`, `VP8X` (drapeaux réduits à la transparence), `ALPH` ; une animation est refusée.
  - **Écart assumé avec la demande de la contre-épreuve : les profils ICC partent aussi** (APP2 `ICC_PROFILE`, `iCCP`, `ICCP`). Leur contenu est libre : le fichier `app2_secret.jpg` de la contre-épreuve portait `ICC_PROFILE\0` puis un texte GPS. Le coût : une photo envoyée sans recadrage et dotée d'un profil large (Display P3) peut s'afficher un peu moins saturée ; le canvas, lui, n'écrit pas de profil.
  - **Forme exacte des parties gardées** (amendement du 2026-09-28, retour du challenger #65) : une partie de la liste blanche n'est gardée que si elle a **exactement** la forme de sa norme, sans octet libre derrière ses champs ; sinon le fichier est illisible (`:unsupported`). JPEG : SOFn de `8 + 3 × Nf` octets, SOS de `6 + 2 × Ns`, DRI et DNL de 4, DAC non vide et pair, DQT et DHT découpés table par table (classe ou précision 0 ou 1, numéro 0 à 3, 64 ou 128 valeurs par DQT, 16 effectifs puis autant de codes par DHT) jusqu'à la fin exacte du segment ; un seul SOF. PNG : IHDR conforme (profondeur permise pour le type de couleur, compression et filtre 0, entrelacement 0 ou 1) ; IHDR, PLTE, tRNS, gAMA, cHRM, sRGB et IEND au plus une fois, donc **rien après le premier IEND** ; gAMA de 4 octets, cHRM de 32, sRGB d'un octet (0 à 3), IEND vide ; PLTE en triplets, de 1 à `2^profondeur` entrées en mode indexé (256 sinon), exigé en mode indexé, interdit en gris ; tRNS de 2 octets en gris, 6 en couleurs (échantillons dans la profondeur), au plus une entrée par couleur de la palette en mode indexé, interdit avec un canal alpha. WebP : octet de bourrage nul après une longueur impaire ; VP8X au plus une fois, en premier, de 10 octets exactement, **réécrit** (seul le drapeau de transparence reste, les trois octets réservés remis à zéro) ; sa taille de canevas doit égaler celle du bitstream `VP8 `/`VP8L` ; VP8L de version 0 ; ALPH au plus une fois, seulement dans un fichier étendu, avant une image `VP8 `, avec un en-tête valide (bits réservés nuls, pré-traitement 0 ou 1, filtre 0 à 3, compression 0 ou 1) et, non compressé, exactement un octet par pixel.
  - **Tables utilisées, ordre de la norme, plafonds** (même amendement, second retour du challenger #65, 2026-09-28) :
    - JPEG : chaque définition sert avant d'être redéfinie — DQT aux composantes du SOF, DHT (codage de Huffman) ou DAC (codage arithmétique, SOF9 à SOF15) et DRI au scan qui suit. Une table jamais utilisée, redéfinie sans avoir servi ou définie après son dernier usage rend le fichier illisible. C'est l'option « garder la dernière définition avant le scan qui l'utilise », la plus simple qui accepte les JPEG progressifs (libjpeg y redéfinit ses tables DHT entre deux scans) : aucune définition ne reste sans usage. DAC : chaque paire bornée (classe 0 ou 1, table 0 à 3 ; DC : L ≤ U ; AC : Kx de 1 à 63) ; un DAC dans un JPEG de Huffman ou un DHT dans un JPEG arithmétique ne sert à rien, donc refusé. Chaque scan a 1 à 4 composantes, toutes déclarées par le SOF ; un JPEG séquentiel code chaque composante dans exactement un scan (un scan de plus ne porterait que des données libres). La table DC sert à un premier passage DC (Ss = 0, Ah = 0), la table AC dès que Se > 0 : un JPEG sans perte (SOF3, SOF7, SOF11, SOF15), qu'aucun appareil photo n'écrit, est refusé, de même qu'un SOF dont la précision n'est pas de 8 bits (un JPEG 12 ou 16 bits n'est affiché par aucun navigateur). Un seul segment Adobe ; gardé, sa transformée vaut 0, 1 ou 2.
    - Tables de Huffman réalisables (troisième retour du challenger #65, 2026-09-28) : 1 à 256 codes ; à chaque longueur de 1 à 16, le code canonique suivant tient dans cette longueur sans être le code tout à 1 (la règle de libjpeg) ; symboles distincts ; table DC : catégories 0 à 11 (précision de 8 bits) ; table AC : EOB (0x00), ZRL (0xF0) ou une paire course/taille de taille 1 à 10, plus les EOBn (taille 0, course 1 à 14) dans un JPEG progressif seulement. Une table AC de 510 symboles ou trois codes de longueur 1 rendent le fichier illisible. Un JPEG de 12 bits (catégories au-delà de 11) est donc refusé : aucun téléphone n'en écrit. DNL est refusé partout (il ne sert qu'à une hauteur nulle dans le SOF, déjà refusée), comme tout SOF sans perte (SOF3, 7, 11, 15), avec ou sans DHT.
    - PNG : PLTE dans une image en couleurs (types 2 et 6, palette suggérée inutile au rendu) et cHRM sont **retirés** ; gAMA n'est gardé que dans la plage 1 000 à 1 000 000 (gamma de 0,01 à 10), sinon retiré. Ordre imposé : IHDR premier, PLTE, tRNS, gAMA, cHRM et sRGB avant le premier IDAT, tRNS après PLTE, IDAT consécutifs, IEND dernier.
    - Plafonds : 256 segments JPEG hors scan, 64 scans, 4096 chunks PNG, 64 chunks WebP ; au-delà, le fichier est refusé avant d'être lu en entier. Le remplissage `0xFF` et la fin d'un scan sont cherchés par une expression régulière, sans boucle Ruby octet par octet. `strip` ne lit plus le fichier qu'une fois (`analyze` rend les faits et les parties). Un fichier de 1 Mo fait de 174 000 DRI, 104 000 scans, 87 000 IDAT vides, d'un million d'octets de remplissage ou d'un scan bourré est tranché en moins de 0,5 s (contre 1,2 à 1,9 s).
  - **JPEG coupé à son premier EOI** (même amendement, décision du coordinateur) : un téléphone écrit après l'EOI du flux principal des images secondaires (Motion Photo, index MPF, carte de gain iPhone). Refuser ces fichiers bloquait des photos ordinaires envoyées sans recadrage ; ils sont désormais **acceptés**, et tout ce qui suit le premier EOI est retiré comme une métadonnée (l'index MPF, en APP2, part déjà par la liste blanche). Les images secondaires et la carte de gain disparaissent : la photo stockée est l'image principale seule.
  - `Dtos::Identity::ProfilePhotoInput(photo:)` : présence, poids **avant** lecture, puis format et dimensions ; `data` = les octets sans métadonnées, **relus** : s'ils portaient encore des métadonnées ou ne se relisaient pas, l'image serait refusée (défense en profondeur).
  - Port `Ports::Identity::ProfilePhotoStorePort` : `attach(user_id:, data:, content_type:)` → true (remplace), `attached?(user_id:)` → Boolean, `remove(user_id:)` → Boolean (efface le fichier), `read(user_id:)` → `StoredPhoto(content_type, data)` | nil.
  - Use cases `ChangeOwnPhoto` et `RemoveOwnPhoto` sous `UpdateSelfPolicy` (ADR-0028), `Shared::Result` (ADR-0026), audit `profile.photo_changed` (format, poids, dimensions) et `profile.photo_removed` ; `ReadAccountPhoto` sous `ReadUserPolicy`, où « enseigne » = la classe principale de l'élève (active ou archivée, comme la liste nominative) est déclarée par l'enseignant.
- **Infrastructure** : `Orm::User has_one_attached :photo` (aucune migration : les tables Active Storage existent) ; `Repositories::Identity::ProfilePhotoStore` ; le blob est créé `analyzed: true` pour qu'aucun `AnalyzeJob` ne cherche libvips. `Queries::Identity::PhotoVersions` donne la version (empreinte MD5 du blob, en base64 URL) aux requêtes du shell, du profil, de la liste de classe et du compte retrouvé.
- **Delivery** : `Identity::ProfilePhotosController` (`edit`, `update`, `destroy` sur `/profile/photo`) et `Identity::AccountPhotosController#show`, `send_data` en `inline`, `Cache-Control: private, max-age=86400` ; une nouvelle photo change l'adresse, donc le cache ne sert jamais une photo périmée.
- **Routes Active Storage non dessinées** (`config.active_storage.draw_routes = false`, amendement du 2026-09-28) : aucune fonctionnalité ne sert un fichier par Active Storage ni ne téléverse en direct (imports : formulaire et `ImportFileStore` côté serveur ; éditeur riche : pièces jointes refusées). Avant, un `signed_id` fuité ouvrait le fichier sans session (proxy, redirect, disk) et `POST /rails/active_storage/direct_uploads` créait un blob pour un visiteur anonyme. Le partiel `active_storage/blobs/_blob` d'Action Text (pièce jointe déjà présente dans un contenu riche, que la validation refuse désormais) est réécrit sans aucune adresse : légende, ou nom et taille ; sans cela, la page d'un tel contenu répondait 500 (« Can't resolve image into URL »). `rich_textarea` demandait `rails_direct_uploads_url` et `rails_service_blob_url` pour ses attributs `data-direct-upload-url` et `data-blob-url-template` : les deux formulaires de l'éditeur (cours, fiche essentielle) passent désormais des adresses vides (`RichTextHelper#rich_text_without_uploads`), inutilisées puisque `@rails/actiontext` n'est pas chargé et que l'éditeur retire toute pièce jointe.
- **CSP** : inchangée. L'image vient de la même origine (`img-src 'self'`) ; l'aperçu local est un `blob:` (déjà permis). Aucun script en ligne : le recadrage est le contrôleur Stimulus `identity--photo-picker`.
- **Aucune adresse Active Storage** (`/rails/active_storage/...`) n'est émise pour une photo : aucun `signed_id` de photo ne sort du serveur.

## 5. Conséquences

### 🟢 Positives

- Aucune dépendance nouvelle, aucune migration ; la construction Docker ne change pas.
- Envoi typique de 20 à 60 Ko au lieu de plusieurs Mo ; affichage mis en cache par le navigateur jusqu'au changement de photo.
- La lecture d'une photo applique la même règle que la lecture d'un compte : une seule règle, testée dans le domaine.
- La position GPS d'une photo de téléphone ne peut pas être stockée : soit le canvas l'a retirée, soit le serveur refuse.

### 🔴 Coûts consentis

- **Photo non carrée acceptée** par le serveur : le canvas produit toujours un carré ; seule une image envoyée sans recadrage peut ne pas l'être, et l'avatar rond la recadre à l'affichage (`object-cover`). L'exiger refuserait sans gain de confidentialité les petites images propres d'un navigateur sans canvas.
- **L'ancien fichier part par `purge_later`** lors d'un remplacement (le retrait, lui, efface tout de suite) : une purge synchrone dans la transaction du use case effacerait le fichier avant une éventuelle annulation. Entre-temps, l'ancien fichier n'est plus rattaché à aucun compte et aucune route ne le sert ; le worker (ADR-0052) l'efface dans les secondes qui suivent.
- Le serveur ne décode pas l'image : un flux bien formé dont les données compressées sont abîmées passe. Le navigateur refuse une image qui se décode en rien (0 × 0 ou sans aucun pixel visible) avant l'envoi.
- **Octets libres encore possibles dans les données compressées** (limites documentées au retour du challenger #65, 2026-09-28) : le serveur ne décode pas l'image, et trois endroits ne se vérifient pas sans décodage. (1) JPEG : la fin d'un scan (données entropiques, bourrées de bits à 1 jusqu'à l'octet) ; des octets ajoutés juste avant EOI y sont indiscernables du flux ; de même, un JPEG progressif peut porter un scan de raffinement superflu (au plus 64 scans), que seul un décodage révélerait ; enfin, la valeur d'un intervalle DRI (2 octets, au plus un par scan) est un paramètre libre de la norme. Le **contenu** des tables gardées est lui aussi choisi par l'encodeur : une table de Huffman de forme valide peut porter des symboles choisis (de l'ordre de 120 octets par définition, redéfinissable entre les scans d'un progressif), et une table DQT des valeurs choisies, y compris en précision 16 bits dans un JPEG baseline, que libjpeg décode ; seul un décodage complet dirait si ces valeurs sont « naturelles ». (2) PNG : des octets après la fin du flux zlib des IDAT ; seule une décompression dirait où le flux s'arrête (et ouvrirait la porte aux bombes de décompression). (3) WebP : des octets après le bitstream dans un chunk `VP8 ` (la dernière partition de coefficients n'a pas de longueur déclarée : elle court jusqu'à la fin du chunk ; l'en-tête de trame ne donne que la taille de la première partition, déjà vérifiée), dans un chunk `VP8L`, ou dans un `ALPH` compressé (flux VP8L sans en-tête). Ces octets ne peuvent venir que de l'expéditeur lui-même (aucun appareil n'y écrit de métadonnées, et le recadrage par le canvas les efface) ; il pourrait tout aussi bien cacher un message dans les pixels. Aucune position ni aucun champ de métadonnée ne peut y être lu par un logiciel ordinaire.

- Chaque image affichée repasse par Rails (session, règle, lecture du bucket) : une liste de quarante élèves coûte quarante requêtes au premier affichage, puis zéro grâce au cache privé.
- Un navigateur sans canvas ni `DataTransfer` envoie le fichier brut : une photo de téléphone y sera refusée (trop lourde, trop grande). Le message dit la limite, mais l'utilisateur n'a pas d'autre recours.
- Retirer l'Exif d'un JPEG envoyé brut retire aussi son orientation : une telle photo peut s'afficher couchée. Le canvas, lui, applique l'orientation avant de l'oublier.
- Une seule taille (512 px) sert tous les avatars, y compris ceux de 32 px.
- Le cache privé du navigateur garde la photo sur un téléphone partagé après la déconnexion (au plus un jour).
- Le lecteur d'en-têtes est du code maison : il ne valide pas l'image entière, seulement son format, ses dimensions et ses segments de métadonnées. Une image corrompue au-delà de l'en-tête s'affiche cassée ; elle n'est jamais décodée par le serveur.

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
- `grep -rn "rails_blob\|rails_storage\|signed_id" app` ne trouve rien pour les photos ; `bin/rails routes | grep active_storage` est vide ; un envoi direct anonyme et un `signed_id` fuité répondent 404 (`test/integration/identity/active_storage_routes_test.rb`).
- Troisième retour du challenger #65 : tables DHT à 510 symboles, aux longueurs irréalisables, au code tout à 1, aux symboles répétés ou hors de leur classe, DNL, SOF sans perte : refusés (`atk2.rb`) ; le corpus de non-régression du challenger (205 images de navigateurs et d'encodeurs) reste accepté et idempotent, sortie identique.
- Second retour du challenger #65 : DAC hors d'un JPEG arithmétique ou aux valeurs hors bornes, DQT, DHT, DAC ou DRI inutilisés ou redéfinis avant usage, scan de trop dans un JPEG séquentiel, composante de scan inconnue, deux segments Adobe ou transformée hors 0 à 2, chunks PNG hors de l'ordre de la norme : refusés ; palette suggérée, cHRM et gAMA invraisemblable : retirés ; fichiers de 1 Mo faits de parties vides : tranchés en moins de 0,5 s. Le harnais du challenger (`atk.rb`, `adobe.rb`, `fuzz.rb`, `h.rb`) ne laisse passer que les deux limites documentées (octets en fin de scan JPEG, ALPH compressé).
- Retour du challenger #65 : pour chaque partie gardée allongée ou hors norme (DQT, DHT, SOF, SOS, DRI, DAC, gAMA, sRGB, cHRM, PLTE, tRNS, IHDR, IEND, VP8X, ALPH, VP8L), pour un chunk après IEND, un bourrage non nul, un VP8X dont la taille diffère du bitstream, le fichier est refusé ou ses octets gardés ne portent plus le secret, sans exception et en moins de 2 s (`test/domain/entities/identity/image_header_test.rb`) ; un JPEG suivi d'une image MPF et d'un secret est stocké identique à l'image principale (domaine, DTO, contrôleur) ; des images normales (JPEG progressif, PNG indexé avec tRNS, gris avec tRNS, avec gAMA/cHRM/sRGB, WebP sans perte étendu, avec alpha) passent octet pour octet.
- Fuzz : à chaque frontière de segment d'un JPEG, des octets de remplissage, un octet égaré ou un segment Exif ne laissent jamais passer de métadonnée ; chaque préfixe strict de chaque image est refusé.
