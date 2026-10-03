# ADR-0073 : Le blog public vit dans `communication` ; ses articles ont une adresse lisible figée, des images vérifiées et servies par Lnclass, un compteur de lectures tenu par le serveur et un plan du site

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-02 : délégation, « crée un système de blog et puis c'est tout »)* |
| **Date** | 2026-10-02 |
| **Chantier** | [`docs/chantiers/blog`](../../chantiers/blog/memo.md) — grill 1 à 12 ; [PRD](../../chantiers/blog/prd.md) §2, §4 (BL-01 à BL-21), §5 ; interfaces : [UDR-0064](../udr/0064-blog-public-liste-article-et-partage.md), [UDR-0065](../udr/0065-gestion-du-blog-par-l-equipe.md) |
| **Amende** | [ADR-0027](./0027-contextes-bornes-et-arborescence.md) §4 (tables de `communication`) · [ADR-0029](./0029-identifiants-exposes-public-id-et-slugs.md) §4 (tables à `public_id` et à slug) · [ADR-0038](./0038-comptes-de-l-equipe-et-sous-roles.md) §4 (matrice, ligne « Blog », appliquée dès maintenant) · [ADR-0047](./0047-stockage-objet-s3-sur-railway.md) §4 (fichiers publics) · [ADR-0051](./0051-navigateurs-supportes-et-budget-de-poids.md), amendement du 2026-09-25 (Action Text et pièces jointes hors cours et fiches) |
| **Complète** | [ADR-0026](./0026-contrat-result-entites-et-dto.md) et [ADR-0028](./0028-policies-de-domaine-par-use-case.md) (`:expired` en lecture) · [ADR-0035](./0035-cycle-de-vie-et-propriete-du-contenu.md) (même cycle, `ContentStatus` partagé) · [ADR-0049](./0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (compteur serveur) · [ADR-0060](./0060-photo-de-profil-stockee-privee-recadree-par-le-navigateur.md) et [ADR-0068](./0068-import-de-plusieurs-fichiers-de-cours-et-ecriture-acceleree.md) (`ImageHeader` et `RichTextSanitizer` partagés, inchangés pour leurs usages actuels) · [ADR-0067](./0067-budgets-de-temps-serveur-des-ecrans.md) (deux écrans budgétés) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le porteur demande un blog public, écrit par l'équipe (Administration et Contenu), lisible sans compte à `lnclass.com/blog`, partageable sur WhatsApp et Facebook avec un aperçu illustré, indexable par Google ([memo](../../chantiers/blog/memo.md)). Il refuse un outil externe (grill 1) : Google doit créditer le site principal, et l'équipe garde ses comptes protégés par le second facteur.

Rien de ce qu'il faut n'existe, et cinq règles en vigueur le refusent tel quel :

- **Aucune table publique.** `communication` ne porte que des pages statiques (`/aide`, `/mission`, pages juridiques) et les annonces de l'ADR-0045, connectées, ciblées, en texte simple, qui ne sont pas codées. L'ADR-0027 ne lui donne que `messages` et `message_dismissals`.
- **Les adresses lisibles sont réservées au catalogue** (ADR-0029) ; `SLUG_TABLES` de `test/db/schema_constraints_test.rb` compte six tables, dont `drenas` (ADR-0066).
- **Aucun fichier n'est public.** `config.active_storage.draw_routes = false` (ADR-0060) : aucune route Active Storage, aucun `direct_upload`. La seule image servie, la photo de profil, l'est sous session, en `Cache-Control: private`. Le serveur ne redimensionne pas (`variant_processor = :disabled`, pas de libvips).
- **L'éditeur refuse toute image** (ADR-0051, amendement du 2026-09-25) : `rich_text_editor_controller.js` annule `trix-file-accept` et retire toute pièce jointe ; `Repositories::Catalog::RichTextSanitizer` retire tout `<action-text-attachment>`.
- **Aucune mesure d'audience anonyme** (ADR-0049) : ni script tiers, ni cookie de mesure, ni adresse IP. Or le porteur veut savoir si un article est lu (grill 8).

Enfin, la page publique doit tenir sur un téléphone d'entrée de gamme en 3G (ADR-0051, ADR-0067) et porter les balises qu'un robot lit (description, Open Graph, adresse canonique, plan du site), alors que `lnclass.com` et `www.lnclass.com` servent tous deux l'application (memo, question 3) et que `public/` est servi avec `Cache-Control: public, max-age=31536000` (`config/environments/production.rb`).

## 2. Moteurs de décision

1. **Aucun tiers** : ni hébergeur, ni CDN, ni script, ni domaine de plus dans la CSP (ADR-0049).
2. **Les cours et les fiches ne changent pas** : leur éditeur refuse toujours les images (BL-15).
3. **Rien ne fuit** : un brouillon reste introuvable, ses images aussi ; une image ne porte aucune métadonnée (position GPS d'une photo prise dans un établissement).
4. **Le lecteur paie peu** : 0 Ko de JavaScript ajouté aux pages de lecture, images réduites avant l'envoi et chargées à la demande, page sous les budgets de l'ADR-0067.
5. **V1 minimale pour la rentrée** : réutiliser ce qui existe (`HasFrozenSlug`, `ContentStatus`, `ImageHeader`, `RichTextSanitizer`, Action Text) plutôt qu'en écrire un second.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Outil externe (WordPress, Ghost) ou sous-domaine `blog.lnclass.com` | En ligne en un jour ; éditeur et images offerts | Écartée par le porteur (grill 1) : un sous-domaine partage mal l'autorité du site principal ; un second outil a ses comptes sans second facteur, son design, ses scripts et ses cookies |
| B — Texte en Markdown (champ texte, rendu serveur) | Pas de Trix ; diff lisible | Un second format de contenu riche, un second rendu et un second assainisseur ; l'équipe écrit déjà dans Trix ; insérer une image demanderait de coller une adresse à la main |
| C — Routes standard d'Active Storage (`rails_storage_proxy`, `direct_upload`) | Zéro contrôleur ; Trix et `@rails/actiontext` savent téléverser seuls | Rouvre ce que l'ADR-0060 a fermé : un `signed_id` fuité ouvre un fichier sans règle, un visiteur crée des blobs ; le proxy d'Active Storage ne sait pas qu'un brouillon est privé |
| D — libvips et variantes (plusieurs tailles, `srcset`) | Image adaptée à chaque écran | Dépendance native que la construction Docker a déjà refusée (ADR-0060) ; un envoi de 3 à 8 Mo sur réseau lent ; le navigateur réduit déjà la photo de profil |
| E — Compteur dédoublonné par cookie (ou par empreinte IP + agent) | Lecteurs uniques plutôt que lectures | Un traceur, donc un bandeau de consentement (ADR-0049) ; une IP est une donnée personnelle, interdite de mesure |
| F — Compteur par job (`perform_later` à chaque lecture) | Rien d'écrit dans la requête | Une ligne Solid Queue par lecture coûte plus qu'un `UPDATE` d'une ligne ; le chiffre arrive en retard |
| G — Texte de remplacement dans la légende Trix | Aucune table ni panneau : il voyage dans le HTML | La légende est un texte visible, distinct du texte de remplacement (UDR-0065 §3.4.2) ; on perdrait l'une ou l'autre |
| **H — Articles dans `communication`, Trix ouvert aux images pour le blog seul, envoi par un endpoint de l'équipe, image = pièce jointe `sgid` vers une ligne `article_images`, service par un contrôleur Lnclass, compteur `UPDATE` atomique, plan du site par route** | Réutilise les mécanismes existants ; ne touche ni la CSP ni les cours | **Retenue** — voir coûts consentis |

## 4. Décision

> **Nous rangeons les articles du blog dans le contexte `communication`, tables `articles` et `article_images`, adressés par un slug figé à la création ; nous leur appliquons le cycle `draft → published → archived → published` des contenus ; nous réservons leur gestion à l'équipe `admin` et `content` ; nous ouvrons l'éditeur Trix aux images pour le blog seulement, envoyées par un endpoint de l'équipe après réduction par le navigateur, vérifiées par `ImageHeader` et servies par un contrôleur Lnclass en cache public immuable une fois l'article publié ; nous comptons les lectures par un seul `UPDATE` côté serveur ; nous servons le plan du site et `robots.txt` par des routes, sur un hôte canonique configurable.**

### 4.1 Tables (amende ADR-0027 et ADR-0029)

`communication` porte désormais `articles` et `article_images`, en plus de `messages` et `message_dismissals`.

| `articles` | Contrainte |
|---|---|
| `public_id` | `string(14) NOT NULL`, unique (ADR-0029) : adresses de l'équipe (`edit_teams_article_path(public_id)`…) |
| `slug` | `string(140) NOT NULL`, unique, `has_frozen_slug from: :title` : adresse publique `blog_article_path(slug)`, jamais régénérée, `-2`, `-3` en cas de collision ; jamais réutilisé (un article n'est jamais supprimé) |
| `title` | `string(120) NOT NULL`, `CHECK (char_length(btrim(title)) >= 1)` : exigé dès le brouillon, le slug en dérive |
| `excerpt` | `string(200) NULL` : exigé à la publication |
| `cover_image_id` | `bigint NULL`, FK `article_images` `on_delete: :restrict` : la couverture |
| `cover_alt` | `string(150) NULL` : exigé à la publication si une couverture est posée |
| `signature` | `string NOT NULL DEFAULT 'team'`, `CHECK IN ('team','author')` |
| `status` | `string NOT NULL DEFAULT 'draft'`, `CHECK IN ('draft','published','archived')` |
| `published_at` / `archived_at` | `datetime NULL` ; `CHECK (status = 'draft' OR (published_at IS NOT NULL AND btrim(excerpt) <> ''))` ; `CHECK ((status = 'archived') = (archived_at IS NOT NULL))` |
| `author_id` | `bigint NOT NULL`, FK `users` `on_delete: :restrict`, indexée ; trace, aucun droit (ADR-0035) |
| `reads_count` | `integer NOT NULL DEFAULT 0`, `CHECK (reads_count >= 0)`, non indexé |

Index : `public_id` et `slug` uniques ; `(published_at DESC, id DESC) WHERE status = 'published'` pour la liste et le plan du site ; `author_id`. Le texte est `has_rich_text :body` (table `action_text_rich_texts`).

| `article_images` | Contrainte |
|---|---|
| `public_id` | `string(14) NOT NULL`, unique : adresse de l'image ; une ligne ne change jamais de fichier |
| `article_id` | `bigint NULL`, FK `articles` `on_delete: :restrict` : `NULL` entre l'envoi et le premier enregistrement qui la cite |
| `alt` | `string(150) NULL` : texte de remplacement d'une image du texte, exigé à la publication |
| `content_type`, `byte_size`, `width`, `height` | `CHECK IN ('image/jpeg','image/png','image/webp')`, `byte_size BETWEEN 1 AND 1048576`, côtés `BETWEEN 1 AND 1600` |

Le fichier est `has_one_attached :file`, créé `analyzed: true` comme la photo (aucun `AnalyzeJob` ne cherche libvips). La couverture est une ligne de `article_images` comme les autres : elle s'envoie par le même endpoint avant l'enregistrement du formulaire (UDR-0065 §2.6), se vérifie, se sert et se purge par le même chemin.

**Article et annonce ne se confondent pas.** L'article est public, sans audience, sans établissement, sans rejet ni programmation, en texte riche illustré, adressé par slug ; un archivé répond 410. L'annonce (ADR-0045) est connectée, ciblée par audience et établissement, en texte simple, programmable, adressée par `public_id`. Deux tables, deux jeux de use cases ; aucun ne lit l'autre.

### 4.2 Cycle de vie (complète ADR-0035)

- **Même table de transitions que les contenus, sans parent.** `Entities::Catalog::ContentStatus` est **déplacé** en `Entities::Shared::ContentStatus`, sans changer une ligne de sa logique ; les 13 fichiers qui le citent (catalogue, évaluation, aide de statut, tests) changent de nom. On généralise au lieu de réutiliser tel quel : `communication` ne dépend pas d'une entité du catalogue (ADR-0027 : on ne connaît d'un autre contexte que les entités de ses ports), et la dépendance d'`assessment` envers `Catalog::ContentStatus` disparaît du même coup. Un article appelle `transition(…, parent_published: true)`, comme un cours ; `Entities::Communication::Article::TRANSITIONS` (lu par l'UDR-0065) est `Entities::Shared::ContentStatus::TRANSITIONS`.
- `published_at = COALESCE(published_at, now)` : une remise en ligne garde la date d'origine (BL-11) ; `archived_at` est remis à `NULL`.
- **Publier exige un article complet** : titre, résumé, texte non vide, texte de remplacement de la couverture et de chaque image du texte, au plus 10 images dans le texte. Sinon `:invalid` (422), `errors` nomme le champ (`title`, `excerpt`, `body`, `cover_alt`, `:"image_alts.<public_id>"`), le brouillon est gardé (BL-09, BL-13).
- **Enregistrer un article déjà publié exige la même chose** : `UpdateArticle` applique à un article `published` les règles de la publication. Un article en ligne ne perd jamais son résumé ni un texte de remplacement par une modification.
- **Journal** : `article.created`, `article.updated`, `article.published` (`metadata.republished`), `article.archived`, ajoutés à `Entities::Identity::AuditAction::ALL`. Création et modification sont tracées en plus de la publication : BL-07 l'exige, et l'auteur réel d'un texte public signé « L'équipe Lnclass » n'est lisible que là.
- **Lecture** (`Policies::Communication::ReadArticlePolicy`, sur la `Detail` de la query) : publié → succès pour tous, `actor: nil` compris ; tout état → succès pour qui gère le blog (aperçu, bandeau, `noindex`) ; archivé → `:expired` ; brouillon → `:not_found`, comme une adresse inconnue (BL-04). **Ce résultat ne passe pas par `render_result`**, qui renvoie `:expired` vers la connexion : `Communication::ArticlesController#show` rend lui-même `gone` en **410** pour `:expired` et `render_not_found` pour `:not_found` (UDR-0064 §2). `RendersResult` n'est pas modifié ; aucun code d'erreur n'est ajouté à l'ADR-0026.

### 4.3 Qui gère (amende ADR-0038)

`Policies::Communication::ManageArticlesPolicy` : succès si `actor&.team?` **et** `actor.team_role` ∈ `admin`, `content` ; sinon `:forbidden` (403, ou connexion pour un visiteur). Elle garde tous les use cases d'écriture, l'envoi d'image et la liste de gestion. La matrice de l'ADR-0038 gagne une ligne, **appliquée dès cet ADR** pour le blog seul (la question générale des sous-rôles reste à la V4) :

| Action | `admin` | `content` | `field` |
|---|---|---|---|
| Blog : écrire, publier, archiver, remettre en ligne un article ; envoyer ses images ; lire ses lectures | ✅ | ✅ | |

### 4.4 Images (amende ADR-0047 et ADR-0051, complète ADR-0060)

**Plafonds** — constantes de `Entities::Communication::ArticleImage`, lues par les vues et le JavaScript (UDR-0065 §2) :

| Constante | Valeur | Pourquoi |
|---|---|---|
| `CONTENT_TYPES` | `image/jpeg`, `image/png`, `image/webp` | Ce que lit `ImageHeader` ; ni GIF, ni WebP animé, ni SVG (script possible) |
| `MAX_BYTES` | 1 Mo (`MAX_MEGABYTES = 1`) | Le plafond de la photo : la réduction étant obligatoire, rien ne justifie les 2 Mo des annonces ; typiquement 100 à 300 Ko |
| `MAX_SIDE` | 1600 px | Colonne de 390 px CSS en densité 3 (1170 px), de 720 px en densité 2 (1440 px) ; au-delà des 1200 px d'un aperçu Facebook |
| `MAX_PER_ARTICLE` | 10 images dans le texte, couverture non comptée | BL-21 mesure cinq images ; dix font une image tous les 150 mots d'un article de 1 500 mots, et bornent le pire cas à 11 Mo |
| `ALT_MAX` | 150 caractères | Une phrase qui décrit ; au-delà, c'est une légende |

- **Réduction par le navigateur**, comme la photo (ADR-0060) : canvas, plus grand côté ramené à `MAX_SIDE`, WebP qualité 0,82 (JPEG à défaut), dans un module importé à la demande (`app/javascript/lib/image_upload.js`). Le canvas n'écrit aucune métadonnée.
- **Vérification serveur**, sans bibliothèque (`Dtos::Communication::ArticleImageInput`, calqué sur `ProfilePhotoInput`) : poids vérifié avant toute lecture ; format lu dans les octets ; côtés bornés ; métadonnées retirées par `ImageHeader.strip`, puis relues absentes (fail closed). Sinon l'image est refusée avec sa raison et rien n'est stocké (BL-12).
- **`ImageHeader` sert deux contextes sans couplage** : il est **déplacé** de `Entities::Identity::ImageHeader` en `Entities::Shared::ImageHeader` (`app/domain/entities/shared/`, à côté de `NaturalKey`), code et tests inchangés. Il ne sait rien d'un compte ni d'un article ; chaque contexte garde ses plafonds (`Identity::ProfilePhoto`, `Communication::ArticleImage`).
- **Envoi** : `POST /teams/blog/images` → `teams_article_images_path(article: public_id)`, paramètre `article` absent à la création (`Teams::ArticleImagesController`, `UploadArticleImage` sous `ManageArticlesPolicy`). Multipart `article_image[file]`, jeton CSRF, même origine : `connect-src 'self'` suffit. Réponses : **201** `{ public_id, sgid, url, width, height }` ; **422** `{ error }` (message français rédigé par le serveur) ; **403** `{ error: "forbidden" }` ; **401** `{ error: "unauthenticated" }` à une requête JSON sans session (amendement du 2026-10-03 : la session expirée pendant la rédaction se dit, au lieu d'un renvoi vers la connexion lu comme une panne réseau). L'image est créée sans article (`article_id NULL`). Avec `article`, le serveur refuse au-delà de `MAX_PER_ARTICLE` images déjà citées ; sans, la limite est tenue par l'éditeur, puis par l'enregistrement. Pas de `direct_upload`, routes Active Storage toujours non dessinées, `@rails/actiontext` toujours non chargé.
- **Trix pour le blog seul** : `rich_text_editor_controller.js` passe en mode images sur la valeur `attachments` (UDR-0065 §3.4.3). Absente, cours et fiches gardent le comportement d'aujourd'hui, à l'identique. À la réponse 201, l'éditeur pose `sgid`, `url`, `width`, `height` sur la pièce jointe ; Action Text l'enregistre `<action-text-attachment sgid="…" content-type width height caption>`, et la résout vers `Orm::ArticleImage`, qui inclut `ActionText::Attachable`.
- **Texte de remplacement** : colonne `article_images.alt`, saisi dans le panneau « Images du texte » (`article[image_alts][<public_id>]`) ; `cover_alt` pour la couverture. Action Text ne garde pas d'`alt` dans le contenu : le texte vit avec l'image. La légende Trix reste permise, visible et facultative.
- **Rattachement et purge des orphelines** : enregistrer un article (création ou modification) rattache à lui, dans la transaction, la couverture et les images que cite son texte ; les images qui lui étaient rattachées et qu'il ne cite plus sont supprimées, fichier purgé après validation (`purge_later`, ADR-0047). Une image envoyée et jamais rattachée (modale fermée) est purgée par `Communication::PurgeOrphanArticleImagesJob` (`config/recurring.yml`, chaque jour) après 48 h. Une image citée par le texte enregistré, ou couverture, n'est jamais purgée.
- **Service public par Lnclass** : `GET /blog/images/:public_id` (`blog_image_path`), seul chemin d'une image, couverture comprise ; `Communication::ArticleImagesController#show`, use case `ReadArticleImage` sous `ReadArticlePolicy`. **L'adresse est versionnée par construction** : une ligne ne change jamais de fichier, une nouvelle couverture est une nouvelle ligne, donc une nouvelle adresse. Helper `Communication::ArticlesHelper#article_image_src(image)` → `blog_image_path(image.public_id)` (UDR-0064 §2).
  - Image rattachée à un article **publié** : `Cache-Control: public, max-age=31536000, immutable`, lisible sans session (BL-14).
  - Image d'un brouillon, ou pas encore rattachée : servie à qui gère le blog en `Cache-Control: private, no-store` (éditeur, panneau, aperçu) ; 404 pour tout autre. Image d'un archivé : 404 pour qui ne gère pas.
- **Rendu d'une image du texte** : `Orm::ArticleImage#to_attachable_partial_path` → `"communication/articles/body_image"`. Action Text passe le modèle sous le local `article_image` ; le partiel le nomme `image` et lit les champs de l'`Image` de l'UDR-0064 (`public_id`, `alt`, `width`, `height`), que la ligne porte telle quelle. `loading="lazy"`, `decoding="async"`, dimensions posées. `active_storage/blobs/_blob.html.erb` ne change pas.

### 4.5 Assainissement (amende ADR-0051, complète ADR-0068)

`Repositories::Catalog::RichTextSanitizer` est **déplacé** en `Repositories::Shared::RichTextSanitizer`, analyse unique inchangée (ADR-0068). Il prend un argument `image_ids:` : `nil` par défaut (cours, fiches, imports) retire, comme aujourd'hui, toute pièce jointe ; seul `Repositories::Communication::ArticleRepository` passe l'ensemble des identifiants admis (images de cet article, et images pas encore rattachées). En mode article :

- une pièce jointe n'est gardée que si son `sgid` se lit (`SignedGlobalID.parse(sgid, for: "attachable")`, sans requête) comme un `Orm::ArticleImage` de cet ensemble ; `url`, `href` et tout attribut hors liste partent, une image collée depuis un autre site aussi ;
- **`<h1>` est réécrit en `<h2>`** : le bouton « Titre » de Trix produit un `h1`, et la page garde un seul `h1`, le titre (BL-02, UDR-0064 §3.3).

Le HTML est d'abord canonisé par `ActionText::Content` (les `figure[data-trix-attachment]` deviennent des `<action-text-attachment>`), puis assaini, puis écrit. Action Text réassainit au rendu ; sa liste d'attributs gagne `loading`, `decoding` et `fetchpriority`, sans quoi `loading="lazy"` serait retiré (BL-21).

### 4.6 Référencement

- **Hôte canonique** : `config.x.canonical_host = ENV["CANONICAL_HOST"].presence || "lnclass.com"`. `Communication::ArticlesHelper#canonical_url(path)` → `"https://#{canonical_host}#{path}"`, jamais `request.host`. Il sert au lien `canonical`, à `og:url`, à `og:image` (BL-03), au plan du site et à la ligne `Sitemap:`. `CANONICAL_HOST` doit figurer dans `APP_HOSTS`. La question du porteur (`lnclass.com` ou `www`) se tranche par une variable, sans code. Aucune redirection entre les deux hôtes : le lien `canonical` suffit aux robots.
- **Balises** posées par `communication/articles/_head` dans `content_for :head` (déjà rendu par `layouts/application.html.erb`), par `tag.meta` et `tag.link` ; liste et ordre fixés par l'UDR-0064 §3.4. Sans couverture, `og:image` vise `app/assets/images/blog/partage.png` (1200 × 630, 150 Ko au plus), en adresse absolue sur l'hôte canonique.
- **`/sitemap.xml`** par `Communication::SitemapsController#show` (`Queries::Communication::SitemapQuery`) : page d'accueil, `/aide`, les pages de `Communication::PagesController::ONLINE`, `/blog`, chaque article publié avec `lastmod` = `updated_at`. `Cache-Control: public, max-age=3600`. Ni brouillon ni archivé (BL-19).
- **`/robots.txt`** par le même contrôleur (`#robots`) : `public/robots.txt` est **supprimé**, car `public/` est servi en cache d'un an et la ligne `Sitemap: https://<hôte canonique>/sitemap.xml` doit suivre `CANONICAL_HOST`. `Cache-Control: public, max-age=86400`. Aucun `public/sitemap.xml`.

### 4.7 Compteur de lectures (complète ADR-0049 et ADR-0067)

- `RecordArticleRead` (policy `ReadArticlePolicy`) compte une lecture si l'article est publié, la requête est un `GET` HTML, l'acteur n'est pas `team` (aperçu compris), et `Entities::Communication::ArticleRead.countable?` l'admet. Elle **refuse** :
  - un **préchargement** : en-tête `Sec-Purpose`, `X-Sec-Purpose` ou `Purpose` contenant `prefetch` (Turbo 8 précharge un lien au survol ; la liste pose aussi `data-turbo-prefetch="false"`, UDR-0064) ;
  - un **robot qui se déclare** : agent vide, ou motif `bot|crawl|spider|slurp|facebookexternalhit|whatsapp|preview|curl|wget|python|headless` (le robot d'aperçu de WhatsApp compris).
  Sinon succès sans écriture. Un échec du compteur ne bloque jamais la page.
- **Une requête SQL**, sans transaction ni verrou applicatif : `UPDATE articles SET reads_count = reads_count + 1 WHERE id = $1 AND status = 'published'`. `updated_at` n'est pas touché (le `lastmod` du plan du site ne bouge pas) ; la colonne n'est pas indexée, la mise à jour reste HOT.
- **Rien d'autre n'est lu ni gardé** : ni cookie, ni adresse IP, ni agent, ni lien avec une inscription. Le cookie de session que pose déjà toute page (nonce CSP, ADR-0049) n'est pas lu. Le chiffre est brut, affiché « lectures, sans dédoublonnage », visible de l'équipe seule.
- **Budget** : `/blog` et `/blog/:slug` relèvent de la ligne « < 100 ms p95, < 150 Ko de HTML » de l'ADR-0067 ; l'`UPDATE` d'une ligne par clé primaire (≈ 1 ms) y est compté. La page d'article lit l'article, sa signature et sa couverture en une requête, et ne charge jamais la liste.

### 4.8 Signature et lecture connectée

- **Repli à la lecture, sans job** : `ArticleDetailQuery`, `PublishedArticlesQuery` et `TeamArticlesQuery` lisent le nom de l'auteur par `CASE WHEN articles.signature = 'author' AND users.anonymized_at IS NULL THEN users.first_name || ' ' || users.last_name END` ; `NULL` s'affiche « L'équipe Lnclass ». Un article signé `team` ne sélectionne jamais le nom (BL-18). Le code ne connaît aujourd'hui qu'un état de départ d'un compte, l'anonymisation (ADR-0036) : aucune colonne ne dit « désactivé ». La condition vit dans une seule constante SQL (`Queries::Communication::ArticleSignature::AUTHOR_NAME`), et un futur état de désactivation s'y ajoute.
- **Contrôleur public sans shell** : `Communication::ArticlesController < ApplicationController`, `allow_unauthenticated_access`, layout `application`, aucune redirection d'une personne connectée (contrairement à `HomepageController`, BL-20). `current_actor` reste résolu, pour la règle de lecture et l'exclusion du compteur.

## 5. Conséquences

### 🟢 Positives

- Un article se partage avec titre, résumé et image, s'indexe sous l'hôte canonique, et un brouillon ne fuit ni par son adresse ni par ses images.
- Aucune dépendance, aucun tiers, aucune ouverture de la CSP ; les routes Active Storage restent fermées.
- Les cours et les fiches gardent leur éditeur, leur assainisseur et leurs tests à l'identique.
- `ImageHeader`, `RichTextSanitizer` et `ContentStatus` servent plusieurs contextes depuis `shared`, sans dépendance croisée.
- Le porteur sait si un article est lu, sans traceur ni bandeau.

### 🔴 Coûts consentis

- **Chaque octet d'image passe par Puma** (ADR-0047) : pas de CDN, le cache immuable ne sert qu'au navigateur qui revient. Un article partagé à mille parents, c'est mille lectures du bucket et jusqu'à 11 Mo par lecteur au pire, facturés en sortie.
- **Une seule taille d'image** : pas de `srcset` ; un téléphone de 390 px télécharge l'image de 1600 px.
- **Une lecture par image au rendu** : Action Text résout chaque `sgid` séparément, soit jusqu'à 10 lectures par clé primaire par page d'article, dans le budget de 100 ms.
- **Le `sgid` d'une image figure dans le HTML public.** Il ne désigne qu'une ligne `article_images`, n'ouvre aucun fichier (routes Active Storage non dessinées) et n'est admis par l'assainisseur que pour l'article qui la possède.
- **Une image retirée du texte est purgée à l'enregistrement** : la rétablir ensuite par « Annuler » n'est pas possible, l'assainisseur retire son `sgid` inconnu ; il faut la renvoyer.
- **Le compteur ment dans les deux sens** : un lecteur qui revient compte deux fois ; un robot qui ne se déclare pas compte ; un membre de l'équipe dont le second facteur n'est pas vérifié est lu comme un visiteur et compte.
- **Une lecture écrit en base** : un `GET` n'est plus sans effet, et un article très lu concentre les mises à jour sur une ligne.
- **`:expired` prend un second sens** (contenu retiré, 410), traduit par un seul contrôleur ; un futur contrôleur de lecture qui le passerait à `render_result` renverrait vers la connexion.
- **Trois déplacements** (`ContentStatus`, `ImageHeader`, `RichTextSanitizer`) touchent des fichiers livrés du catalogue, de l'évaluation et de l'identité : un commit de pur renommage, au Lot 0.
- **Changer d'hôte canonique** après indexation demande une variable et une nouvelle indexation ; les anciens aperçus partagés gardent l'ancien hôte.

## 6. Notes d'implémentation

```ruby
# db/migrate/20261002120000_create_articles.rb (extrait) — contraintes du §4.1 ; FK croisées posées après les deux tables
add_check_constraint :articles, "status IN ('draft','published','archived')", name: "articles_status_values"
add_check_constraint :articles, "signature IN ('team','author')", name: "articles_signature_values"
add_check_constraint :articles, "status = 'draft' OR (published_at IS NOT NULL AND btrim(excerpt) <> '')", name: "articles_published_complete"
add_check_constraint :articles, "(status = 'archived') = (archived_at IS NOT NULL)", name: "articles_archived_at"
add_index :articles, %i[published_at id], order: { published_at: :desc, id: :desc }, where: "status = 'published'"
add_foreign_key :article_images, :articles, on_delete: :restrict
add_foreign_key :articles, :article_images, column: :cover_image_id, on_delete: :restrict
```

```ruby
# 🔌 INFRA · Orm::ArticleImage
# Rôle : image d'un article (couverture ou texte), vérifiée, sans métadonnées ; pièce jointe Action Text par sgid
# ADR  : 0029, 0060, 0073
module Orm
  class ArticleImage < ApplicationRecord
    include HasPublicId
    include ActionText::Attachable

    self.table_name = "article_images"

    belongs_to :article, class_name: "Orm::Article", optional: true
    has_one_attached :file

    def to_attachable_partial_path = "communication/articles/body_image"
  end
end
```

```ruby
# 🧠 DOMAINE · Policies::Communication::ManageArticlesPolicy
# Rôle : gérer le blog : l'équipe `admin` et `content` seules (matrice de l'ADR-0038, ligne « Blog »)
# ADR  : 0028, 0038, 0073
module Policies
  module Communication
    class ManageArticlesPolicy
      TEAM_ROLES = %w[admin content].freeze

      def call(actor:)
        return Shared::Result.success if actor&.team? && TEAM_ROLES.include?(actor.team_role)

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
```

```ruby
# 🧠 DOMAINE · Policies::Communication::ReadArticlePolicy
# Rôle : publié → tous ; qui gère → tout état ; archivé → :expired (410) ; brouillon → :not_found (introuvable)
# ADR  : 0028, 0035, 0073
module Policies
  module Communication
    class ReadArticlePolicy
      def call(actor:, article:)
        return Shared::Result.success if article.status == "published"
        return Shared::Result.success if ManageArticlesPolicy.new.call(actor:).success?

        Shared::Result.failure(article.status == "archived" ? :expired : :not_found)
      end
    end
  end
end
```

```ruby
# app/controllers/communication/articles_controller.rb (extrait) — jamais render_result : il renverrait :expired vers la connexion
def show
  @article = Queries::Communication::ArticleDetailQuery.new.call(slug: params[:slug]) or return render_not_found
  read = Policies::Communication::ReadArticlePolicy.new.call(actor: current_actor, article: @article)
  return render(:gone, status: :gone) if read.code == :expired
  return render_not_found if read.failure?

  record_read
end
```

```ruby
# app/infrastructure/repositories/shared/rich_text_sanitizer.rb (extrait) — Repositories::Shared::RichTextSanitizer
# image_ids : nil (cours, fiches, imports : aucune pièce jointe, comportement inchangé) ou Set des Orm::ArticleImage admis.
def self.call(html, image_ids: nil)
  return html if html.nil?

  Loofah.html5_fragment(html).scrub!(:prune).scrub!(image_ids ? ArticleScrubber.new(image_ids) : SCRUBBER).to_s
end

# Liste blanche de Rails, plus <action-text-attachment> vers une image admise ; h1 → h2 (un seul h1 par page).
class ArticleScrubber < Rails::HTML::PermitScrubber
  ATTACHMENT = "action-text-attachment"
  ATTACHMENT_ATTRIBUTES = %w[sgid content-type width height caption filename filesize presentation].freeze

  def initialize(image_ids)
    super()
    @image_ids = image_ids
    self.tags = Rails::HTML5::SafeListSanitizer.allowed_tags.to_a + [ ATTACHMENT ]
    self.attributes = Rails::HTML5::SafeListSanitizer.allowed_attributes.to_a + ATTACHMENT_ATTRIBUTES
  end

  def scrub(node)
    node.name = "h2" if node.name == "h1"
    super
  end

  def allowed_node?(node)
    return super unless node.name == ATTACHMENT

    gid = SignedGlobalID.parse(node["sgid"].to_s, for: ActionText::Attachable::LOCATOR_NAME)
    gid&.model_name == "Orm::ArticleImage" && @image_ids.include?(gid.model_id.to_i)
  end
end
```

```ruby
# config/initializers/action_text.rb — ADR-0073 : sans eux, l'assainissement au rendu retire loading="lazy", decoding et fetchpriority.
Rails.application.config.after_initialize do
  ActionText::ContentHelper.allowed_attributes = Rails::HTML5::SafeListSanitizer.allowed_attributes.to_a +
                                                 ActionText::Attachment::ATTRIBUTES + %w[loading decoding fetchpriority]
end
```

```ruby
# app/controllers/communication/article_images_controller.rb (extrait) — après ReadArticleImage
def send_image(image)
  response.headers["Cache-Control"] = image.public ? "public, max-age=31536000, immutable" : "private, no-store"
  send_data image.data, type: image.content_type, disposition: :inline, filename: "image"
end
```

```ruby
# app/infrastructure/repositories/communication/article_repository.rb (extrait) — une requête, updated_at intact
def increment_reads(article_id:)
  Orm::Article.where(id: article_id, status: "published").update_all("reads_count = reads_count + 1") == 1
end
```

```ruby
# config/application.rb — ADR-0073 : hôte des adresses partagées et indexées (canonical, og:*, plan du site, robots.txt)
config.x.canonical_host = ENV["CANONICAL_HOST"].presence || "lnclass.com"
```

```ruby
# config/routes/communication.rb (extrait)
get "blog", to: "communication/articles#index", as: :blog
get "blog/images/:public_id", to: "communication/article_images#show", as: :blog_image
get "blog/:slug", to: "communication/articles#show", as: :blog_article
get "sitemap.xml", to: "communication/sitemaps#show", defaults: { format: :xml }, as: :sitemap
get "robots.txt", to: "communication/sitemaps#robots", defaults: { format: :text }, as: :robots

# config/routes/teams.rb (extrait) — noms de l'UDR-0065 §2
scope "teams/blog", as: :teams do # images avant les articles : chemin fixe
  post "images", to: "teams/article_images#create", as: :article_images
  resources :articles, path: "", controller: "teams/articles", param: :public_id, only: %i[index new create edit update] do
    member { patch :publish; patch :archive }
  end
end
```

Le reste suit le PRD §5 et les UDR : DTO `Dtos::Communication::ArticleInput` (`title` ≤ `TITLE_MAX` = 120, `excerpt` ≤ `EXCERPT_MAX` = 200, `body` ≤ 100 000 caractères de HTML, sous le budget de 150 Ko, `signature`, `cover_public_id`, `cover_alt`, `image_alts`) et `ArticleImageInput` ; ports `ArticleRepositoryPort` et `ArticleImageStorePort` ; use cases `CreateArticle`, `UpdateArticle`, `PublishArticle`, `ArchiveArticle`, `UploadArticleImage`, `RecordArticleRead` et `ReadArticleImage` (lecture d'octets sous policy, comme `ReadAccountPhoto`). Le slug suit l'ADR-0029 : une collision concurrente (`RecordNotUnique`) régénère et réessaie une fois.

## 7. Comment vérifier que la décision est respectée

- `test/db/schema_constraints_test.rb` : `articles` dans `PUBLIC_ID_TABLES` et `SLUG_TABLES`, `article_images` dans `PUBLIC_ID_TABLES` ; la base refuse `status = 'publié'`, `signature = 'x'`, un article publié sans résumé, un archivé sans `archived_at`, une image de 1601 px ou `image/gif` ; les FK `author_id`, `article_id` et `cover_image_id` sont `restrict`.
- `test/domain/policies/communication/manage_articles_policy_test.rb` : `admin` et `content` passent ; `field`, `teacher`, `student`, `school_admin` et `nil` reçoivent `:forbidden`. `read_article_policy_test.rb` : brouillon → `:not_found` et archivé → `:expired` pour chacun de ces cinq acteurs ; tout état → succès pour `admin` et `content`.
- `test/domain/use_cases/communication/*_test.rb` : BL-07 (chaque geste écrit son action au journal), BL-09 et BL-13 (`:invalid` qui nomme le champ ou `image_alts.<public_id>`, rien d'écrit), modifier un article publié en vidant son résumé → `:invalid`, BL-11 (`published_at` gardé), refus → le double n'a rien enregistré ; `record_article_read_test.rb` : équipe, robot, préchargement (trois en-têtes), brouillon et archivé n'appellent jamais `increment_reads`.
- `test/domain/entities/shared/image_header_test.rb` (déplacé, inchangé) et `test/domain/dtos/communication/article_image_input_test.rb` : faux `.jpg`, GIF, WebP animé, 1 Mo + 1 octet, 1601 px refusés ; Exif retiré. Un test lit les constantes de `ArticleImage` (1 Mo, 1600, 10, 150).
- `test/infrastructure/repositories/shared/rich_text_sanitizer_test.rb` : sans `image_ids`, toute pièce jointe part (comportement des cours, à l'identique) et un `h1` reste ; avec, seule une image admise reste, sans `url` ni `href`, et `h1` devient `h2` ; le `sgid` d'une image d'un autre article ou d'un autre modèle, une image distante, `<script>`, `onerror`, `javascript:` partent (BL-16). Un test d'architecture échoue si un autre fichier que `app/infrastructure/repositories/communication/article_repository.rb` passe `image_ids:`.
- `test/infrastructure/repositories/communication/article_repository_test.rb` : `increment_reads` est **une** requête (`assert_queries_count(1)`), sans effet sur un brouillon ni sur `updated_at` ; enregistrer rattache les images citées et la couverture, supprime une image retirée du texte, jamais une image citée ; `test/jobs/communication/purge_orphan_article_images_job_test.rb` : non rattachée à 47 h gardée, à 49 h purgée, rattachée jamais.
- `test/controllers/teams/article_images_controller_test.rb` : 201 avec exactement `public_id`, `sgid`, `url`, `width`, `height` ; 422 `{ error }` ; 403 pour `field` ; la onzième image d'un article refusée ; aucun blob créé sur un refus.
- `test/integration/communication/articles_test.rb` : BL-02 (200, un seul `h1` même avec un `<h1>` saisi, pas de shell), BL-03 (balises, `og:image` absolue sur `https://lnclass.com`, `blog/partage.png` sans couverture), BL-04 (404 sans le titre), BL-05 (410, jamais de renvoi vers la connexion), BL-06, BL-17 (compteur à 2), BL-18, BL-20 (élève connecté : 200, aucune redirection) ; `loading="lazy"` présent sur les images du texte (BL-21).
- `test/integration/communication/article_images_test.rb` : `Cache-Control` exact pour une image d'un article publié, `private, no-store` pour qui gère un brouillon, 404 pour un visiteur sur une image de brouillon, d'archivé ou non rattachée ; la page ne contient pas `/rails/active_storage`. `test/integration/identity/active_storage_routes_test.rb` reste vert.
- `test/integration/communication/sitemaps_test.rb` : BL-19 ; `/robots.txt` contient `Sitemap: https://lnclass.com/sitemap.xml` ; `public/robots.txt` et `public/sitemap.xml` n'existent pas.
- `test/integration/content_security_policy_test.rb`, `test/views/no_third_party_resources_test.rb`, `test/architecture/lazy_libraries_test.rb` et `bin/check-asset-budget` restent verts sans modification : CSP, aucun tiers, Trix et le module d'images à la demande, budget commun.
- Test système : un cours refuse toujours une image collée (BL-15) ; un article reçoit une image de 4000 px réduite à 1600, son texte de remplacement est exigé à la publication, et la page publique la montre.
- Hors CI (ADR-0067) : `script/perf/measure_screens.rb` mesure `/blog` et `/blog/:slug` sous 100 ms p95 et 150 Ko de HTML ; le poids des images servies se lit dans `article_images.byte_size` (≤ 1 Mo par contrainte).

## 8. Points à confirmer par le porteur

- Hôte canonique : `lnclass.com` par défaut, `CANONICAL_HOST=www.lnclass.com` sinon (memo, question 3).
- Plafonds : 1 Mo et 1600 px par image, 10 images dans le texte en plus de la couverture, 150 caractères de texte de remplacement (memo, question 4).
- « Auteur désactivé » : aucun état de ce nom n'existe ; seule l'anonymisation fait repli en V1.
