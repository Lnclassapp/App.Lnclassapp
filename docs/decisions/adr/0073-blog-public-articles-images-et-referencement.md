# ADR-0073 : Le blog public vit dans `communication` ; ses articles ont une adresse lisible figée, des images vérifiées et servies par Lnclass, un compteur de lectures tenu par le serveur et un plan du site

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-02 |
| **Chantier** | [`docs/chantiers/blog`](../../chantiers/blog/memo.md) — grill 1 à 12 ; [PRD](../../chantiers/blog/prd.md) §2, §4 (BL-01 à BL-21), §5 |
| **Amende** | [ADR-0027](./0027-contextes-bornes-et-arborescence.md) §4 (tables de `communication`) · [ADR-0029](./0029-identifiants-exposes-public-id-et-slugs.md) §4 (tables à `public_id` et à slug) · [ADR-0038](./0038-comptes-de-l-equipe-et-sous-roles.md) §4 (matrice, ligne « Blog », appliquée dès maintenant) · [ADR-0047](./0047-stockage-objet-s3-sur-railway.md) §4 (fichiers publics) · [ADR-0051](./0051-navigateurs-supportes-et-budget-de-poids.md), amendement du 2026-09-25 (Action Text et pièces jointes hors cours et fiches) |
| **Complète** | [ADR-0026](./0026-contrat-result-entites-et-dto.md) et [ADR-0028](./0028-policies-de-domaine-par-use-case.md) (`:expired` en lecture) · [ADR-0035](./0035-cycle-de-vie-et-propriete-du-contenu.md) (même cycle, `ContentStatus` partagé) · [ADR-0049](./0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (compteur serveur) · [ADR-0060](./0060-photo-de-profil-stockee-privee-recadree-par-le-navigateur.md) et [ADR-0068](./0068-import-de-plusieurs-fichiers-de-cours-et-ecriture-acceleree.md) (`ImageHeader` et `RichTextSanitizer` partagés, inchangés) · [ADR-0067](./0067-budgets-de-temps-serveur-des-ecrans.md) (deux écrans budgétés) |
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
| **G — Articles dans `communication`, Trix ouvert aux images pour le blog seul, envoi par un endpoint de l'équipe, service par un contrôleur Lnclass, compteur `UPDATE` atomique, plan du site par route** | Réutilise les mécanismes existants ; ne touche ni la CSP ni les cours | **Retenue** — voir coûts consentis |

## 4. Décision

> **Nous rangeons les articles du blog dans le contexte `communication`, table `articles`, adressés par un slug figé à la création ; nous leur appliquons le cycle `draft → published → archived → published` des contenus ; nous réservons leur gestion à l'équipe `admin` et `content` ; nous ouvrons l'éditeur Trix aux images pour le blog seulement, envoyées par un endpoint de l'équipe après réduction par le navigateur, vérifiées par `ImageHeader` et servies par un contrôleur Lnclass en cache public immuable une fois l'article publié ; nous comptons les lectures par un seul `UPDATE` côté serveur ; nous servons le plan du site et `robots.txt` par des routes, sur un hôte canonique configurable.**

### 4.1 Tables (amende ADR-0027 et ADR-0029)

`communication` porte désormais `articles` et `article_images`, en plus de `messages` et `message_dismissals`.

| `articles` | Contrainte |
|---|---|
| `public_id` | `string(14) NOT NULL`, unique (ADR-0029) : adresses de l'équipe (`/teams/blog/:public_id/…`) et de l'envoi d'image |
| `slug` | `string(140) NOT NULL`, unique, `has_frozen_slug from: :title` : adresse publique `/blog/:slug`, jamais régénérée, `-2`, `-3` en cas de collision ; un slug n'est jamais réutilisé (un article n'est jamais supprimé) |
| `title` | `string(120) NOT NULL`, `CHECK (char_length(btrim(title)) >= 1)` : exigé dès le brouillon, le slug en dérive |
| `excerpt` | `string(200) NULL` : exigé à la publication |
| `cover_alt` | `string(250) NULL` : exigé à la publication si une couverture est jointe ; couverture : `has_one_attached :cover` |
| `signature` | `string NOT NULL DEFAULT 'team'`, `CHECK IN ('team','author')` |
| `status` | `string NOT NULL DEFAULT 'draft'`, `CHECK IN ('draft','published','archived')` |
| `published_at` / `archived_at` | `datetime NULL` ; `CHECK (status = 'draft' OR (published_at IS NOT NULL AND btrim(excerpt) <> ''))` ; `CHECK ((status = 'archived') = (archived_at IS NOT NULL))` |
| `author_id` | `bigint NOT NULL`, FK `users` `on_delete: :restrict`, indexée ; trace, aucun droit (ADR-0035) |
| `reads_count` | `integer NOT NULL DEFAULT 0`, `CHECK (reads_count >= 0)`, non indexé |

Index : `public_id` et `slug` uniques ; `(published_at DESC, id DESC) WHERE status = 'published'` pour la liste et le plan du site ; `author_id`. Le texte est `has_rich_text :body` (table `action_text_rich_texts`).

| `article_images` | Contrainte |
|---|---|
| `public_id` | `string(14) NOT NULL`, unique : adresse de l'image |
| `article_id` | FK `articles` `on_delete: :restrict` |
| `content_type`, `byte_size`, `width`, `height` | `CHECK IN ('image/jpeg','image/png','image/webp')`, `byte_size BETWEEN 1 AND 1048576`, côtés `BETWEEN 1 AND 1600` |
| `in_body` | `boolean NOT NULL DEFAULT false` : vrai quand le texte enregistré la cite |

Le fichier est `has_one_attached :file`, créé `analyzed: true` comme la photo (aucun `AnalyzeJob` ne cherche libvips).

**Article et annonce ne se confondent pas.** L'article est public, sans audience, sans établissement, sans rejet ni programmation, en texte riche illustré, adressé par slug ; un archivé répond 410. L'annonce (ADR-0045) est connectée, ciblée par audience et établissement, en texte simple, programmable, adressée par `public_id`. Deux tables, deux jeux de use cases ; aucun ne lit l'autre.

### 4.2 Cycle de vie (complète ADR-0035)

- **Même table de transitions que les contenus, sans parent.** `Entities::Catalog::ContentStatus` est **déplacé** en `Entities::Shared::ContentStatus`, sans changer une ligne de sa logique ; les 13 fichiers qui le citent (catalogue, évaluation, aide de statut, tests) changent de nom. On généralise au lieu de réutiliser tel quel : `communication` ne dépend pas d'une entité du catalogue (ADR-0027 : on ne connaît d'un autre contexte que les entités de ses ports), et la dépendance d'`assessment` envers `Catalog::ContentStatus` disparaît du même coup. Un article appelle `transition(…, parent_published: true)`, comme un cours.
- `published_at = COALESCE(published_at, now)` : une remise en ligne garde la date d'origine (BL-11) ; `archived_at` est remis à `NULL`.
- **Publier exige un article complet** : titre, résumé, texte non vide, texte de remplacement de la couverture et de chaque image du texte. Sinon `:invalid` (422), `errors` nomme le champ ou l'image (`body: [{ image_alt_missing: "<nom du fichier>" }]`), le brouillon est gardé (BL-09, BL-13).
- **Journal** : `article.created`, `article.updated`, `article.published` (`metadata.republished`), `article.archived`, ajoutés à `Entities::Identity::AuditAction::ALL`. Création et modification sont tracées en plus de la publication : BL-07 l'exige, et l'auteur réel d'un texte public signé « L'équipe Lnclass » n'est lisible que là.
- **Lecture** (`Policies::Communication::ReadArticlePolicy`, sur la `Row` de la query) : publié → succès pour tous, `actor: nil` compris ; tout état → succès pour qui gère le blog (aperçu, bandeau « Brouillon », `<meta name="robots" content="noindex">`) ; archivé → `:expired` ; brouillon → `:not_found`, comme une adresse inconnue (BL-04). `Communication::ArticlesController` traduit `:expired` en **410** et rend « Cet article n'est plus disponible » ; `RendersResult` n'est pas modifié (ailleurs, `:expired` reste un jeton périmé, 422). Aucun code d'erreur n'est ajouté à l'ADR-0026.

### 4.3 Qui gère (amende ADR-0038)

`Policies::Communication::ManageArticlesPolicy` : succès si `actor&.team?` **et** `actor.team_role` ∈ `admin`, `content` ; sinon `:forbidden` (403, ou connexion pour un visiteur). Elle garde tous les use cases d'écriture et la liste de gestion. La matrice de l'ADR-0038 gagne une ligne, **appliquée dès cet ADR** pour le blog seul (la question générale des sous-rôles reste à la V4) :

| Action | `admin` | `content` | `field` |
|---|---|---|---|
| Blog : écrire, publier, archiver, remettre en ligne un article ; envoyer ses images ; lire ses lectures | ✅ | ✅ | |

### 4.4 Images (amende ADR-0047 et ADR-0051, complète ADR-0060)

- **Où** : une couverture par article (`cover` + `cover_alt`), et au plus **10 images dans le texte**. BL-21 mesure un article de cinq images ; dix laissent une image tous les 150 mots d'un article de 1 500 mots, et bornent le pire cas à 11 Mo (couverture comprise). La onzième est refusée à l'envoi.
- **Réduction par le navigateur**, comme la photo (ADR-0060) : canvas, plus grand côté ramené à **1600 px**, WebP qualité 0,82 (JPEG à défaut). 1600 px couvrent une colonne de lecture de 390 px CSS sur un écran de densité 3 (1170 px) et de 720 px sur un écran de densité 2 (1440 px), et dépassent les 1200 px qu'attend un aperçu Facebook. Le canvas n'écrit aucune métadonnée. Poids typique : 100 à 300 Ko.
- **Vérification serveur**, sans bibliothèque : JPEG, PNG ou WebP lus dans les octets (pas d'extension, pas de GIF, pas de WebP animé, pas de SVG) ; **1 Mo au plus**, vérifié avant toute lecture ; **1600 px au plus** de chaque côté ; métadonnées retirées par `ImageHeader.strip`, puis relues absentes (fail closed). 1 Mo est le plafond de la photo : la réduction étant obligatoire, il n'y a aucune raison d'accepter les 2 Mo des annonces. Sinon l'image est refusée avec sa raison et rien n'est stocké (BL-12).
- **`ImageHeader` sert deux contextes sans couplage** : il est **déplacé** de `Entities::Identity::ImageHeader` en `Entities::Shared::ImageHeader` (`app/domain/entities/shared/`, à côté de `NaturalKey`), code et tests inchangés. Il ne sait rien d'un compte ni d'un article ; chaque contexte garde ses plafonds (`Entities::Identity::ProfilePhoto`, `Entities::Communication::ArticleImage`).
- **Envoi** : `POST /teams/blog/:public_id/images` (`Teams::ArticleImagesController`, `UploadArticleImage` sous `ManageArticlesPolicy`), multipart, jeton CSRF, même origine : `connect-src 'self'` suffit. Il répond `{ url, width, height }` en 201, ou 422 avec la raison. Pas de `direct_upload`, routes Active Storage toujours non dessinées, `@rails/actiontext` toujours non chargé. L'article doit exister : un nouvel article s'enregistre une première fois avant de recevoir des images dans son texte ; la couverture, elle, part avec le formulaire de création.
- **Trix pour le blog seul** : `rich_text_editor_controller.js` reçoit une valeur `uploadUrl`. Vide (cours, fiches), le comportement est celui d'aujourd'hui, octet pour octet. Posée (article), il accepte JPEG, PNG et WebP, réduit l'image dans un module importé à la demande, l'envoie, puis pose `url`, `width` et `height` sur la pièce jointe Trix. Action Text l'enregistre comme une **image distante** (`<action-text-attachment url="/blog/images/…" content-type width height caption>`), sans `sgid` ni blob Action Text.
- **Texte de remplacement d'une image du texte : la légende Trix** (attribut `caption` de la pièce jointe, conservé par Action Text). Le champ de légende est libellé « Texte de remplacement (obligatoire) » ; le rendu le pose en `alt` et n'affiche pas de légende visible. Il voyage avec l'image dans le HTML : aucune table ni second formulaire. Couverture : colonne `cover_alt`. 250 caractères au plus.
- **Service public par Lnclass** : `GET /blog/images/:public_id/:version` et `GET /blog/:slug/couverture/:version` (`Communication::ArticleImagesController`, `ReadArticleImage` sous `ReadArticlePolicy`). `version` = empreinte MD5 du blob en base64 URL (formule de `Queries::Identity::PhotoVersions.of`) ; une autre version répond 404, donc une adresse désigne un seul contenu.
  - Image `in_body` (ou couverture) d'un article **publié** : `Cache-Control: public, max-age=31536000, immutable`, lisible sans session (BL-14).
  - Brouillon, ou image pas encore enregistrée dans le texte : servie à qui gère le blog en `Cache-Control: private, no-store` (éditeur, aperçu) ; 404 pour tout autre.
  - Archivé : 404 pour qui ne gère pas.
- **Purge des orphelines** : enregistrer le texte pose `in_body` sur les images citées ; celles qui l'étaient et ne le sont plus sont supprimées dans la même transaction, fichier purgé après validation (`purge_later`, ADR-0047). Une image envoyée puis jamais enregistrée est purgée par `Communication::PurgeOrphanArticleImagesJob` (`config/recurring.yml`, chaque jour) après 48 h. Une image citée par le texte enregistré n'est jamais purgée.

### 4.5 Assainissement (amende ADR-0051, complète ADR-0068)

`Repositories::Catalog::RichTextSanitizer` est **déplacé** en `Repositories::Shared::RichTextSanitizer`, analyse unique inchangée (ADR-0068). Il prend un argument `image_urls:` : `nil` par défaut (cours, fiches, imports) retire, comme aujourd'hui, toute pièce jointe ; seul `Repositories::Communication::ArticleRepository` passe l'ensemble des adresses des images **de cet article**. Une pièce jointe n'est gardée que si son `url` est dans cet ensemble et son `content-type` une image permise ; `sgid`, `href` et tout attribut hors liste partent. Le HTML est d'abord canonisé par `ActionText::Content` (les `figure[data-trix-attachment]` deviennent des `<action-text-attachment>`), puis assaini, puis écrit. Action Text réassainit au rendu ; sa liste d'attributs gagne `loading` et `decoding`, sans quoi `loading="lazy"` serait retiré (BL-21).

### 4.6 Référencement

- **Hôte canonique** : `config.x.canonical_origin = "https://#{ENV["CANONICAL_HOST"].presence || "lnclass.com"}"`. Il sert au lien `canonical`, à `og:url`, à `og:image` (adresse absolue, BL-03), au plan du site et à la ligne `Sitemap:`. `CANONICAL_HOST` doit figurer dans `APP_HOSTS`. La question du porteur (`lnclass.com` ou `www`) se tranche par une variable, sans code. Aucune redirection entre les deux hôtes : le lien `canonical` suffit aux robots.
- **Balises** posées par la vue d'article dans `content_for :head` (déjà rendu par `layouts/application.html.erb`), par `tag.meta` et `tag.link` : `description` (le résumé), `og:type` `article`, `og:title`, `og:description`, `og:url`, `og:image` (couverture, sinon l'image par défaut `app/assets/images/blog/share.png`, 1200 × 630), `og:image:alt`, `og:site_name`, `og:locale` `fr_FR`, `article:published_time`, `link rel="canonical"`.
- **`/sitemap.xml`** par `Communication::SitemapsController#show` (`Queries::Communication::SitemapQuery`) : page d'accueil, `/aide`, les pages de `Communication::PagesController::ONLINE`, `/blog`, chaque article publié avec `lastmod` = `updated_at`. `Cache-Control: public, max-age=3600`. Ni brouillon ni archivé (BL-19).
- **`/robots.txt`** par le même contrôleur (`#robots`) : `public/robots.txt` est **supprimé**, car `public/` est servi en cache d'un an et la ligne `Sitemap: <origine canonique>/sitemap.xml` doit suivre `CANONICAL_HOST`. `Cache-Control: public, max-age=86400`. Aucun `public/sitemap.xml`.

### 4.7 Compteur de lectures (complète ADR-0049 et ADR-0067)

- `RecordArticleRead` (policy `ReadArticlePolicy`) compte une lecture si l'article est publié, la requête est un `GET` HTML qui n'est pas un préchargement (`Sec-Purpose` ou `X-Sec-Purpose` contenant `prefetch` : Turbo précharge un lien au survol), l'acteur n'est pas `team` (aperçu compris), et l'agent ne se déclare pas robot (`Entities::Communication::ArticleRead.robot?` : agent vide, ou motif `bot|crawl|spider|slurp|facebookexternalhit|whatsapp|preview|curl|wget|python|headless`, le robot d'aperçu de WhatsApp compris). Sinon succès sans écriture.
- **Une requête SQL**, sans transaction ni verrou applicatif : `UPDATE articles SET reads_count = reads_count + 1 WHERE id = $1 AND status = 'published'`. `updated_at` n'est pas touché (le `lastmod` du plan du site ne bouge pas) ; la colonne n'est pas indexée, la mise à jour reste HOT.
- **Rien d'autre n'est lu ni gardé** : ni cookie, ni adresse IP, ni agent, ni lien avec une inscription. Le cookie de session que pose déjà toute page (nonce CSP, ADR-0049) n'est pas lu. Le chiffre est brut, affiché « lectures, sans dédoublonnage », visible de l'équipe seule.
- **Budget** : `/blog` et `/blog/:slug` relèvent de la ligne « < 100 ms p95, < 150 Ko de HTML » de l'ADR-0067 ; l'`UPDATE` d'une ligne par clé primaire (≈ 1 ms) y est compté. La page d'article lit l'article, sa signature et ses versions d'images en une requête, et ne charge jamais la liste.

### 4.8 Signature et lecture connectée

- **Repli à la lecture, sans job** : `ArticleDetailQuery` et `PublishedArticlesQuery` lisent le nom de l'auteur par `CASE WHEN articles.signature = 'author' AND users.anonymized_at IS NULL THEN users.first_name || ' ' || users.last_name END` ; `NULL` s'affiche « L'équipe Lnclass ». Un article signé `team` ne sélectionne jamais le nom (BL-18). Le code ne connaît aujourd'hui qu'un état de départ d'un compte, l'anonymisation (ADR-0036) ; la condition vit dans une seule constante SQL, et un futur état « désactivé » s'y ajoute.
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
- **Pas de légende visible sous une image** : la légende Trix est le texte de remplacement. Une vraie légende demandera un nouvel attribut.
- **Une image ne s'ajoute au texte qu'après le premier enregistrement** d'un nouvel article.
- **Une image retirée puis rétablie par « annuler » après un enregistrement est perdue** : elle a été purgée, l'assainisseur retire son adresse inconnue ; il faut la renvoyer.
- **Le compteur ment dans les deux sens** : un lecteur qui revient compte deux fois ; un robot qui ne se déclare pas compte ; un membre de l'équipe dont le second facteur n'est pas vérifié est lu comme un visiteur et compte.
- **Une lecture écrit en base** : un `GET` n'est plus sans effet, et un article très lu concentre les mises à jour sur une ligne.
- **`:expired` prend un second sens** (contenu retiré, 410) traduit par un seul contrôleur ; un futur contrôleur de lecture qui l'oublierait renverrait vers la connexion.
- **Trois déplacements** (`ContentStatus`, `ImageHeader`, `RichTextSanitizer`) touchent des fichiers du catalogue, de l'évaluation et de l'identité, livrés : un commit de pur renommage, au Lot 0.
- **Changer d'hôte canonique** après indexation demande une variable et une nouvelle indexation ; les anciens aperçus partagés gardent l'ancien hôte.

## 6. Notes d'implémentation

```ruby
# db/migrate/20261002120000_create_articles.rb (extrait) — contraintes de §4.1
add_check_constraint :articles, "status IN ('draft','published','archived')", name: "articles_status_values"
add_check_constraint :articles, "signature IN ('team','author')", name: "articles_signature_values"
add_check_constraint :articles, "status = 'draft' OR (published_at IS NOT NULL AND btrim(excerpt) <> '')", name: "articles_published_complete"
add_check_constraint :articles, "(status = 'archived') = (archived_at IS NOT NULL)", name: "articles_archived_at"
add_index :articles, %i[published_at id], order: { published_at: :desc, id: :desc }, where: "status = 'published'"
```

```ruby
# 🔌 INFRA · Orm::Article
# Rôle : table articles, articles du blog (brouillon, publié, archivé), adressés par slug figé, gérés par public_id
# ADR  : 0029, 0035, 0073
module Orm
  class Article < ApplicationRecord
    include HasPublicId
    include HasFrozenSlug

    self.table_name = "articles"

    has_frozen_slug from: :title
    def to_param = slug # le slug pour le public ; l'équipe passe public_id explicitement

    belongs_to :author, class_name: "Orm::User"
    has_rich_text :body
    has_one_attached :cover
    has_many :images, class_name: "Orm::ArticleImage", inverse_of: :article, dependent: :restrict_with_error
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
# app/infrastructure/repositories/shared/rich_text_sanitizer.rb (extrait) — Repositories::Shared::RichTextSanitizer
# image_urls : nil (cours, fiches, imports : aucune pièce jointe, comportement inchangé) ou Set des adresses des images de l'article.
def self.call(html, image_urls: nil)
  return html if html.nil?

  fragment = Loofah.html5_fragment(html).scrub!(:prune)
  fragment.scrub!(image_urls ? ArticleImageScrubber.new(image_urls) : SCRUBBER).to_s
end

# Liste blanche de Rails, plus <action-text-attachment> seulement vers une image de cet article ; sgid et href partent.
class ArticleImageScrubber < Rails::HTML::PermitScrubber
  ATTACHMENT = "action-text-attachment"
  ATTACHMENT_ATTRIBUTES = %w[url content-type width height caption filename filesize presentation].freeze
  IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze

  def initialize(image_urls)
    super()
    @image_urls = image_urls
    self.tags = Rails::HTML5::SafeListSanitizer.allowed_tags.to_a + [ ATTACHMENT ]
    self.attributes = Rails::HTML5::SafeListSanitizer.allowed_attributes.to_a + ATTACHMENT_ATTRIBUTES
  end

  def allowed_node?(node)
    return super unless node.name == ATTACHMENT

    @image_urls.include?(node["url"]) && IMAGE_TYPES.include?(node["content-type"])
  end
end
```

```ruby
# config/initializers/action_text.rb — ADR-0073 : sans eux, l'assainissement au rendu retire loading="lazy" et decoding="async".
Rails.application.config.after_initialize do
  ActionText::ContentHelper.allowed_attributes =
    Rails::HTML5::SafeListSanitizer.allowed_attributes.to_a + ActionText::Attachment::ATTRIBUTES + %w[loading decoding]
end
```

```erb
<%# 🌐 UI · action_text/attachables/_remote_image — image du texte d'un article, servie par Lnclass (/blog/images/…) %>
<%# Rôle : la légende Trix est le texte de remplacement, jamais affichée ; dimensions posées, chargée à la demande %>
<%# ADR  : 0073 %>
<figure class="attachment attachment--preview">
  <%= image_tag remote_image.url, alt: remote_image.try(:caption).to_s, width: remote_image.width,
                                  height: remote_image.height, loading: "lazy", decoding: "async" %>
</figure>
```

```ruby
# app/controllers/communication/article_images_controller.rb (extrait) — après ReadArticleImage
def send_image(image)
  if image.public?
    response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
  else
    response.headers["Cache-Control"] = "private, no-store" # brouillon, pour qui gère le blog
  end
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
config.x.canonical_origin = "https://#{ENV["CANONICAL_HOST"].presence || "lnclass.com"}"
```

```ruby
# config/routes/communication.rb (extrait)
get "blog", to: "communication/articles#index", as: :blog
get "blog/images/:public_id/:version", to: "communication/article_images#show", as: :article_image
get "blog/:slug/couverture/:version", to: "communication/article_images#cover", as: :article_cover
get "blog/:slug", to: "communication/articles#show", as: :article
get "sitemap.xml", to: "communication/sitemaps#show", defaults: { format: :xml }, as: :sitemap
get "robots.txt", to: "communication/sitemaps#robots", defaults: { format: :text }, as: :robots
```

Le reste suit le PRD §5 : DTO `Dtos::Communication::ArticleInput` (titre ≤ 120, résumé ≤ 200, texte ≤ 100 000 caractères de HTML, sous le budget de 150 Ko) et `ArticleImageInput` (calqué sur `ProfilePhotoInput`), ports `ArticleRepositoryPort` et `ArticleImageStorePort`, use cases `CreateArticle`, `UpdateArticle`, `PublishArticle`, `ArchiveArticle`, `UploadArticleImage`, `RecordArticleRead` et `ReadArticleImage` (lecture d'octets sous policy, comme `ReadAccountPhoto`). Le slug suit l'ADR-0029 : une collision concurrente (`RecordNotUnique`) régénère et réessaie une fois. Le bouton de fichier de Trix, masqué par la feuille commune, n'est rétabli que sous l'éditeur qui porte `uploadUrl`.

## 7. Comment vérifier que la décision est respectée

- `test/db/schema_constraints_test.rb` : `articles` dans `PUBLIC_ID_TABLES` et `SLUG_TABLES`, `article_images` dans `PUBLIC_ID_TABLES` ; la base refuse `status = 'publié'`, `signature = 'x'`, un article publié sans résumé, un archivé sans `archived_at`, une image de 1601 px ou `image/gif` ; la FK `author_id` est `restrict`.
- `test/domain/policies/communication/manage_articles_policy_test.rb` : `admin` et `content` passent ; `field`, `teacher`, `student`, `school_admin` et `nil` reçoivent `:forbidden`. `read_article_policy_test.rb` : brouillon → `:not_found` et archivé → `:expired` pour chacun de ces cinq acteurs ; tout état → succès pour `admin` et `content`.
- `test/domain/use_cases/communication/*_test.rb` : BL-07 (chaque geste écrit son action au journal), BL-09 et BL-13 (`:invalid` qui nomme le champ ou l'image, rien d'écrit), BL-11 (`published_at` gardé), refus → le double n'a rien enregistré ; `record_article_read_test.rb` : équipe, robot, préchargement, brouillon et archivé n'appellent jamais `increment_reads`.
- `test/domain/entities/shared/image_header_test.rb` (déplacé, inchangé) et `test/domain/dtos/communication/article_image_input_test.rb` : faux `.jpg`, GIF, WebP animé, 1 Mo + 1 octet, 1601 px refusés ; Exif retiré.
- `test/infrastructure/repositories/shared/rich_text_sanitizer_test.rb` : sans `image_urls`, toute pièce jointe part (comportement des cours, à l'identique) ; avec, seule une image de l'article reste, sans `sgid` ni `href` ; une adresse d'un autre article, une adresse externe, `<script>`, `onerror`, `javascript:` partent (BL-16). Un test d'architecture échoue si un autre fichier que `app/infrastructure/repositories/communication/article_repository.rb` passe `image_urls:`.
- `test/infrastructure/repositories/communication/article_repository_test.rb` : `increment_reads` est **une** requête (`assert_queries_count(1)`), sans effet sur un brouillon ni sur `updated_at` ; une image retirée du texte est supprimée, une image citée jamais ; `test/jobs/communication/purge_orphan_article_images_job_test.rb` : 47 h gardée, 49 h purgée, citée jamais.
- `test/integration/communication/articles_test.rb` : BL-02 (200, un seul `h1`, pas de shell), BL-03 (balises, `og:image` absolue vers `https://lnclass.com`, image par défaut sans couverture), BL-04 (404 sans le titre), BL-05 (410), BL-06, BL-17 (compteur à 2), BL-18, BL-20 (élève connecté : 200, aucune redirection) ; `loading="lazy"` présent sur les images du texte (BL-21).
- `test/integration/communication/article_images_test.rb` : `Cache-Control` exact pour un article publié, `private, no-store` pour qui gère un brouillon, 404 pour un visiteur sur une image de brouillon, d'archivé, de version périmée ; la page ne contient pas `/rails/active_storage`. `test/integration/identity/active_storage_routes_test.rb` reste vert : aucune route Active Storage.
- `test/integration/communication/sitemaps_test.rb` : BL-19 ; `/robots.txt` contient `Sitemap: https://lnclass.com/sitemap.xml` ; `public/robots.txt` et `public/sitemap.xml` n'existent pas.
- `test/integration/content_security_policy_test.rb`, `test/views/no_third_party_resources_test.rb`, `test/architecture/lazy_libraries_test.rb` et `bin/check-asset-budget` restent verts sans modification : CSP, aucun tiers, Trix à la demande, budget commun.
- Test système : un cours refuse toujours une image collée (BL-15) ; un article reçoit une image de 4000 px réduite à 1600, renseigne son texte de remplacement, se publie, et la page publique la montre.
- Hors CI (ADR-0067) : `script/perf/measure_screens.rb` mesure `/blog` et `/blog/:slug` sous 100 ms p95 et 150 Ko de HTML ; le poids des images servies se lit dans `article_images.byte_size` (≤ 1 Mo par contrainte).

## 8. Points à confirmer par le porteur

- Hôte canonique : `lnclass.com` par défaut, `CANONICAL_HOST=www.lnclass.com` sinon (memo, question 3).
- Plafonds : 1 Mo et 1600 px par image, 10 images dans le texte, en plus de la couverture (memo, question 4).
- La légende Trix sert de texte de remplacement, sans légende visible en V1.
