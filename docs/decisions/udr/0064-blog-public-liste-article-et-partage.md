# UDR-0064 : Blog public — liste `/blog`, page d'un article, article retiré, aperçu partagé et liens « Blog »

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-02 |
| **Chantier** | [`docs/chantiers/blog`](../../chantiers/blog/memo.md) — grill 3, 5, 6, 7, 9 ; [PRD](../../chantiers/blog/prd.md) §3 (parcours B, chemins alternatifs), §4 (BL-01 à BL-06, BL-10, BL-11, BL-14, BL-18 à BL-21) |
| **ADR lié** | ADR-0073 *(en cours d'écriture : blog public, images publiques, référencement)* · [ADR-0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (aucun tiers, CSP) · [ADR-0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md) (budget JS et CSS) · [ADR-0067](../adr/0067-budgets-de-temps-serveur-des-ecrans.md) (100 ms, 150 Ko) · [UDR-0063](0063-pages-publiques-mission-confidentialite-cgu-cgv.md) (gabarit des pages publiques, **modèle suivi**) · [UDR-0061](0061-carte-d-aide-et-faq.md) (carte d'aide) · [UDR-0060](0060-connexion-et-recuperation-du-pin.md) (logo des pages publiques) · [UDR-0059](0059-homepage-telephone-et-tablette.md), [UDR-0012](0012-landing-et-modales-de-role.md) (homepage) · [UDR-0057](0057-ecrans-eleve-epures.md) (R1 à R6) · [UDR-0054](0054-finitions-d-interface.md) (titre, retour) · [UDR-0013](0013-catalogue-et-page-cours.md), [UDR-0015](0015-page-fiche-essentielle.md) (rendu Action Text `.trix-content`) · [UDR-0062](0062-echeances.md) (dates) · [UDR-0005](0005-design-system-fondateur.md), [UDR-0006](0006-shell-applicatif-par-role.md), [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) |
| **Amende** | [UDR-0061](0061-carte-d-aide-et-faq.md) §3.3 (point 3, pied de la carte : ligne « Blog », liens tirés de `PublicPagesHelper`) et §3.5 (les clés `footer.mission`, `footer.privacy`, `footer.terms` ne sont pas créées ; une clé `footer.label`) · [UDR-0063](0063-pages-publiques-mission-confidentialite-cgu-cgv.md) §3.1 (`PublicPagesHelper` gagne `blog_link`) et §3.4 (pied de page de la homepage : « Blog » en tête de la seconde liste, renommée « Plus sur Lnclass » ; pied de la carte d'aide) |
| **Remplacé par** | — |

---

## 1. Contexte

Lnclass n'a aucun contenu public en dehors de sa page d'accueil et de ses quatre pages institutionnelles ([memo](../../chantiers/blog/memo.md)). Le blog doit la faire trouver par Google, donner à l'équipe quelque chose à envoyer pendant le démarchage, publier des conseils (BEPC, BAC) et expliquer les nouveautés.

Le lecteur type est un **parent sans compte** qui ouvre un lien reçu dans un groupe WhatsApp, sur un Android d'entrée de gamme, avec des données mobiles payées par la famille (PRD §3, parcours B). Trois frictions en découlent :

1. **L'aperçu du lien décide du clic.** Sans `og:title`, `og:description` ni `og:image`, WhatsApp et Facebook n'affichent qu'une adresse nue. Le lien n'est pas ouvert.
2. **Chaque kilo-octet coûte.** Une page qui charge toutes ses images d'un coup, un script ou une police tierce, se paie en données. Une image sans dimensions fait sauter le texte pendant la lecture.
3. **Un lien partagé vit plus longtemps que l'article.** Un article retiré doit dire qu'il n'est plus disponible, pas répondre « page introuvable » comme une adresse mal recopiée (grill 7). Un brouillon, lui, ne doit rien révéler.

L'élève connecté n'a qu'une entrée, le pied de sa carte « Besoin d'aide ? » (grill 3). Enseignants et directions arrivent par les liens partagés. Aucun lien « Blog » ne doit mener à une page vide (memo, cas limites).

## 2. Décision

1. **Trois surfaces publiques sur le gabarit de l'UDR-0063** : layout `application` sans shell, logo, lien de retour, un seul `h1`, colonne `max-w-prose`, vouvoiement. La liste `/blog`, la page d'un article `/blog/:slug`, la page « Cet article n'est plus disponible » (410). Un brouillon répond la 404 standard (`errors/not_found`). Une personne connectée voit exactement la page d'un visiteur, sans renvoi vers son accueil (BL-20). C'est le même motif que `/aide` et les pages juridiques : un lecteur qui passe de l'une à l'autre ne change pas d'univers, et aucun composant n'est inventé.
2. **Une liste de cartes paginée, sans « Voir plus ».** Dix articles par page, du plus récent au plus ancien, `ui_pagination` existant. On renonce au motif R3 (trois lignes puis « Voir plus » qui révèle des lignes déjà rendues). Rendre tous les articles pour en masquer la plupart ferait grossir le HTML avec le blog et casserait le budget de 150 Ko. Des pages numérotées ont aussi chacune une adresse que Google indexe.
3. **Une carte = un lien étiré sur le titre**, et pas `ui_card(href:)`. Avec `ui_card(href:)`, la carte entière serait un `<a>`, et un lecteur d'écran lirait titre, résumé et date comme nom du lien. Avec le lien étiré (motif de l'UDR-0057, déjà dans `catalog/courses/_essential_row`), la carte reste cliquable partout, mais le nom du lien est le titre seul.
4. **La lecture n'ajoute aucun JavaScript.** Ni Trix, ni Action Text JS, ni KaTeX (le contrôleur `math` n'est pas posé : un article n'est pas un cours, et un `$` y reste du texte). Les images du texte se chargent à la demande par `loading="lazy"`, natif, sans script. Leurs `width` et `height` réservent la place.
5. **L'aperçu partagé est un jeu fermé de balises de tête** (§3.4), posées par `content_for :head` dans le `yield :head` du layout. Sans couverture, l'aperçu prend l'image par défaut de Lnclass (BL-03). **Aucun bouton de partage** : le PRD (§3, parcours B) n'en prévoit pas, R1 n'autorise qu'une action principale, et le navigateur sait déjà partager une adresse. Les données structurées (JSON-LD) sont repoussées à une version suivante.
6. **Les liens « Blog » n'existent qu'à partir du premier article publié**, par un helper unique, `PublicPagesHelper#blog_link`. Il est lu par le pied de page de la homepage et par celui de la carte d'aide, jamais par `/aide`. On l'ajoute à côté de `public_page_links` au lieu de l'étendre. `public_page_links` lit une constante et ne fait aucune requête, il est appelé par `/aide` avec une liste fermée (`%i[privacy terms]`) et lève une erreur sur une page inconnue. Le blog dépend au contraire d'une requête et n'a pas sa place sur `/aide`.
7. **Date absolue, avec l'année** : « Publié le 5 octobre 2026 ». Le format relatif de la charte (§12 : « Hier », « Mardi 29 sept. ») sert les échéances de l'élève. Une page indexée et partagée doit rester juste dans un an, pour la même raison que la date absolue de l'enseignant (UDR-0062 §3.1).

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Routes, contrôleur et données lues par les vues

**Routes** — dans `config/routes/communication.rb`, sous les pages publiques :

| Route | Action | Nom |
|---|---|---|
| `GET /blog` | `communication/articles#index` | `blog_path` |
| `GET /blog/:slug` | `communication/articles#show` | `blog_article_path(slug)` |

**Contrôleur** — `Communication::ArticlesController < ApplicationController`, `allow_unauthenticated_access`, aucun `layout "shell"`, aucune redirection d'un connecté.

- `index` :
  - lit `params[:page]` (entier, absent ou invalide = 1) ;
  - appelle `Queries::Communication::PublishedArticlesQuery.new.call(page:)` ;
  - une page au-delà de la dernière, quand il existe au moins un article, répond `render_not_found` (pas de page vide indexable) ;
  - `page=1` explicite rend la même page que `/blog` (la balise canonique dit `/blog`).
- `show` :
  - lit `Queries::Communication::ArticleDetailQuery.new.call(slug: params[:slug])` ; `nil` donne `render_not_found` ;
  - applique `Policies::Communication::ReadArticlePolicy` (PRD §2) :
    - succès : `show` ;
    - `:not_found` (brouillon, pour qui ne gère pas le blog) : `render_not_found` ;
    - `:expired` (archivé, pour qui ne gère pas le blog) : `render :gone, status: :gone`.
  - **Interdit** : passer ce résultat à `render_result`. `RendersResult` traduit `:expired` en renvoi vers la connexion.
  - Compter la lecture (`RecordArticleRead`, ADR-0073) ne change rien au rendu. Un échec du compteur ne bloque jamais la page.

**Données lues par les vues** (lecture CQRS ; noms figés ici, contenu calculé par l'infrastructure de l'ADR-0073) :

| Lecture | Champs | Remarque |
|---|---|---|
| `PublishedArticlesQuery#call(page:)` → `Page(rows:, page:, pages:)` | `rows` : tableau de `Row` ; `PER_PAGE = 10` | Publiés seulement, `published_on` décroissant puis `id` décroissant |
| `PublishedArticlesQuery#any?` → booléen | — | Une requête `EXISTS` sur les publiés ; lue par `blog_link` (§3.5) |
| `PublishedArticlesQuery::Row` | `slug`, `title`, `excerpt`, `published_on` (`Date`), `cover` (`Image` ou `nil`) | — |
| `ArticleDetailQuery::Detail` | `slug`, `title`, `excerpt`, `status` (`"draft"`, `"published"`, `"archived"`), `published_on` (`Date` ou `nil`), `author_name` (`String` ou `nil`), `cover` (`Image` ou `nil`), `body` (le texte riche Action Text) | `author_name` vaut `nil` si l'article est signé « L'équipe Lnclass », **ou** si le compte de l'auteur est désactivé ou anonymisé (BL-18) : c'est la query qui tranche, jamais la vue |
| `Image` | `public_id`, `alt`, `width`, `height` | Dimensions en pixels de l'image servie |

**Helpers** — `app/helpers/communication/articles_helper.rb`, module `Communication::ArticlesHelper` :

- `article_image_src(image)` → chemin public de l'image (route fixée par l'ADR-0073, servie par lnclass.com, lisible sans session, BL-14).
- `canonical_url(path)` → `"https://#{Rails.configuration.x.canonical_host}#{path}"`. `canonical_host` est fixé par l'ADR-0073, `lnclass.com` par défaut (memo, question 3). Toutes les adresses absolues des §3.4 passent par lui, jamais par `request.host` : `lnclass.com` et `www.lnclass.com` servent tous deux l'application.
- `article_date(date)` → `l(date, format: :article_published)`, soit « 5 octobre 2026 ». Aucune vue ne formate une date d'article elle-même.

### 3.2 Mise en page commune et liste — `communication/articles/index.html.erb`

**En-tête commun — `communication/articles/_masthead.html.erb`** (locals : `back_label:`, `back_href:` ; sans retour si `back_label` est `nil`) :
- `div.mb-6.text-center` > `link_to root_path, "aria-label": t(".logo_home")`, classes du motif UDR-0060 (`mx-auto flex w-fit min-h-tap items-center rounded-card focus-visible:outline-2 focus-visible:outline-brand`) > `image_tag "logo/lnclass.jpeg", alt: "", class: "size-14 rounded-card object-cover shadow-card"` ;
- puis `ui_back_link back_label, href: back_href`.

**Conteneur des trois pages** : `main.flex.min-h-dvh.flex-col.items-center.bg-paper.px-gutter.py-10` > `div.w-full.max-w-prose`, comme `communication/pages/_page`.

**Liste `/blog`**, de haut en bas :
1. `render "communication/articles/masthead", back_label: t(".back"), back_href: root_path` (« Accueil »).
2. `h1#blog_title.mb-6.font-display.text-3xl.leading-tight.font-extrabold` : « Blog ».
3. Avec des articles : `ol#blog_articles.space-y-5` avec `aria-labelledby="blog_title"` et `data-turbo-prefetch="false"` (§3.6, Comportement), puis un `li` par `Row`, rendu par `communication/articles/_article_card.html.erb` (local `article:`, `eager:`).
4. `div.mt-8` > `ui_pagination page: @page.page, pages: @page.pages` (le composant ne rend rien s'il n'y a qu'une page ; liens `rel="prev"`/`rel="next"`).

**Carte — `_article_card.html.erb`** :
- `ui_card padding: :none, id: "blog_article_#{article.slug}"`, avec la classe `relative overflow-hidden transition hover:border-brand/40 hover:shadow-lift active:bg-mist motion-reduce:transition-none`. **Pas de `href:`** (§2.3).
- Si `article.cover` : `image_tag article_image_src(article.cover), alt: "", width: article.cover.width, height: article.cover.height, loading: (eager ? :eager : :lazy), decoding: :async, class: "aspect-video w-full bg-mist object-cover"`.
  - `alt: ""` : dans la liste, la couverture illustre un lien dont le titre dit déjà tout (R6). Son texte de remplacement est lu sur la page de l'article.
  - `eager` est vrai pour la première carte de la page seulement.
  - Sans couverture : aucune image, aucun espace réservé.
- `div.p-5` :
  - `h2.font-display.text-lg.leading-tight.font-extrabold` > `link_to article.title, blog_article_path(article.slug)`, classes `text-ink after:absolute after:inset-0 after:rounded-card focus-visible:outline-none focus-visible:after:outline-2 focus-visible:after:-outline-offset-2 focus-visible:after:outline-brand` (lien étiré : toute la carte est la cible) ;
  - `p.mt-2.text-sm.text-mute` : le résumé, en entier (200 caractères au plus) ;
  - `p.mt-3.text-xs.text-mute` > `time[datetime=<published_on ISO 8601>]` : « Publié le 5 octobre 2026 » (`t(".published_on", date: article_date(article.published_on))`).
- Ni signature, ni compteur de lectures, ni badge dans la carte.

### 3.3 Page d'un article — `communication/articles/show.html.erb`

De haut en bas, dans le conteneur commun :

1. **Bandeau d'état** (équipe seulement : `@article.status` ≠ `"published"`). `p#article_status_banner.mb-6.flex.flex-wrap.items-center.gap-2.rounded-ln.bg-mist.px-4.py-3.text-sm.text-ink` :
   - d'abord `article_status_badge(@article.status)`, le helper de l'UDR-0065 (`Communication::ArticleStatusHelper`), qui affiche « Brouillon » ou « Archivé » ;
   - puis `t(".status.#{@article.status}_hint")` : « Visible par l'équipe seulement. » pour un brouillon, « Retiré du blog : les visiteurs ne le voient plus. » pour un article archivé.
   
   Ce sont le même badge et les mêmes tons que dans la liste de gestion et au catalogue (ADR-0035) : un état a une seule apparence dans toute l'application. Le fond du bandeau reste neutre (`bg-mist`).
2. `render "communication/articles/masthead", back_label: t(".back"), back_href: back_href(blog_path, from: blog_path)`. Le libellé est « Blog ». Si le lecteur vient de `/blog?page=3`, le retour y ramène (UDR-0054 §3.2).
3. `article[aria-labelledby="article_title"]` :
   - `header.mb-6` :
     - `h1#article_title.font-display.text-3xl.leading-tight.font-extrabold.text-balance` : `@article.title` ;
     - `p#article_byline.mt-3.text-sm.text-mute` : la signature (`@article.author_name`, sinon `t(".team_signature")`, « L'équipe Lnclass ») ; si `published_on` : `span[aria-hidden="true"]` « · » puis `time[datetime]` « Publié le 5 octobre 2026 ». Un brouillon n'a pas de date.
   - **Couverture**, si `@article.cover` : `figure.mb-8` > `image_tag article_image_src(cover), alt: cover.alt, width: cover.width, height: cover.height, loading: :eager, fetchpriority: "high", decoding: :async, class: "h-auto w-full rounded-card bg-mist"`. L'`alt` n'est jamais vide : la publication le refuse (BL-13, ADR-0073).
   - **Texte** : `div#article_body.break-words` > `<%= @article.body %>`. Action Text l'enveloppe dans `layouts/action_text/contents/_content` (`div.trix-content`, inchangé), dont les règles de `application.tailwind.css` donnent la typographie : 16 px, interligne `leading-relaxed`, liens `text-brand-strong underline`, `h2` en `font-display text-xl`, images `h-auto max-w-full rounded-ln`.
     - **Aucun `h1` dans le texte.** Le bouton « Titre » de Trix produit un `<h1>`. L'assainisseur des articles (ADR-0073) le réécrit en `<h2>` à l'écriture. La vue ne rétrograde rien, et le test de BL-02 compte un seul `h1`.
     - **Images du texte** : une seule vue, `communication/articles/_body_image.html.erb`. La pièce jointe d'image d'un article (choix de l'ADR-0073) la désigne par `to_attachable_partial_path` → `"communication/articles/body_image"`, avec un local `image:` (`Image`). Balisage : `figure` > `image_tag article_image_src(image), alt: image.alt, width: image.width, height: image.height, loading: :lazy, decoding: :async, class: "bg-mist"`. `active_storage/blobs/_blob.html.erb` ne change pas : les cours et les fiches restent sans image (BL-15).
     - Pas de `data-controller="math"`.
4. **Suite de la lecture** — `nav#article_next.mt-10.flex.flex-col.gap-3.border-t.border-line.pt-6.sm:flex-row`, `aria-label` « Suite de la lecture » :
   - `ui_button t(".discover"), href: root_path, variant: :primary, full: true, class: "sm:w-auto"` : « Découvrir Lnclass ». Un connecté y est renvoyé vers son accueil, comme depuis toute page publique.
   - `ui_button t(".all_articles"), href: blog_path, variant: :secondary, full: true, class: "sm:w-auto"` : « Tous les articles ».

La page n'affiche **pas** le résumé (il sert à la liste et à l'aperçu, R6), ni le nombre de lectures (équipe seulement, UDR-0065).

**Article archivé — `communication/articles/gone.html.erb`** (statut 410) :
- `render "communication/articles/masthead", back_label: nil, back_href: nil` : logo seul. Une page d'erreur n'a pas de retour (UDR-0054).
- `section#article_gone.flex.flex-col.items-center.rounded-card.border.border-line.bg-white.px-6.py-10.text-center` :
  - `span.grid.size-14.place-items-center.rounded-full.bg-mist.text-mute` > `ui_icon "archive-box", size: :lg` ;
  - `h1.mt-4.font-display.text-xl.font-extrabold` : « Cet article n'est plus disponible » ;
  - `p.mt-1.text-sm.text-mute` : « Il a été retiré du blog de Lnclass. » ;
  - `div.mt-5` > `ui_button t(".all_articles"), href: blog_path, variant: :primary` (« Tous les articles »).
- `ui_empty_state` n'est pas utilisé ici : son titre est un `p`, et la page doit garder un `h1`.
- La page ne contient ni le titre ni le texte de l'article.

**Brouillon pour qui ne gère pas le blog, adresse inconnue** : `render_not_found`, donc `errors/not_found` existant, inchangé (« Page introuvable. », 404). La réponse ne contient ni le titre ni le texte (BL-04).

### 3.4 Balises de tête et titres d'onglet

**Partial `communication/articles/_head.html.erb`**. Locals : `title:`, `description:`, `canonical:` (adresse absolue), `type:` (`"website"` ou `"article"`), `image:` (`Image` ou `nil`), `published_on:` (`Date` ou `nil`). Il est rendu dans `content_for :head do … end`. Chaque balise passe par `tag.meta` ou `tag.link`, jamais par `raw`. Il émet exactement, dans cet ordre :

| # | Balise | Contenu |
|---|---|---|
| 1 | `meta name="description"` | `description` |
| 2 | `link rel="canonical"` | `canonical` |
| 3 | `meta property="og:site_name"` | « Lnclass » (`PageTitleHelper::PRODUCT`) |
| 4 | `meta property="og:locale"` | `fr_FR` |
| 5 | `meta property="og:type"` | `type` |
| 6 | `meta property="og:title"` | `title` |
| 7 | `meta property="og:description"` | `description` |
| 8 | `meta property="og:url"` | `canonical` |
| 9 | `meta property="og:image"` | avec `image` : `canonical_url(article_image_src(image))` ; sinon `image_url("blog/partage.png", host: "https://#{Rails.configuration.x.canonical_host}")` |
| 10 | `meta property="og:image:width"` / `og:image:height` | `image.width` / `image.height` ; sinon `1200` / `630` |
| 11 | `meta property="og:image:alt"` | `image.alt` ; sinon `t(".default_image_alt")` (« Logo de Lnclass ») |
| 12 | `meta property="article:published_time"` | `published_on.iso8601`, pour `type: "article"` seulement |

**Valeurs par page** :

| Page | `title` | `description` | `canonical` | `type` | `image` |
|---|---|---|---|---|---|
| `/blog` (page 1) | `t(".og_title")` « Le blog de Lnclass » | `t(".description")` | `canonical_url(blog_path)` | `website` | `nil` |
| `/blog?page=N` (N ≥ 2) | idem | idem | `canonical_url(blog_path(page: N))` | `website` | `nil` |
| Article publié | `@article.title` | `@article.excerpt` | `canonical_url(blog_article_path(@article.slug))` | `article` | `@article.cover` |

- **Aperçu de l'équipe** (brouillon ou archivé) et **page 410** : pas de `_head`, une seule balise, `tag.meta(name: "robots", content: "noindex, nofollow")`.
- **404** : rien (vue d'erreur inchangée).
- **Image par défaut** : `app/assets/images/blog/partage.png`, 1200 × 630 px, 150 Ko au plus, le logo de Lnclass (fichier de l'équipe, jamais redessiné, charte §2) centré sur le fond `brand`. Servie par l'application, comme tout asset.
- Rien d'autre dans la tête : ni `twitter:*`, ni JSON-LD, ni `meta keywords`, ni ressource externe.

**Titres d'onglet** (`page_title`, UDR-0054 §3.1 ; le helper ajoute l'espace du rôle connecté et « Lnclass ») :

| Vue | Appel | Onglet d'un visiteur |
|---|---|---|
| `index`, page 1 | `page_title t(".page_title")` | « Blog · Lnclass » |
| `index`, page N ≥ 2 | `page_title t(".page_title_paged", page: N)` | « Blog, page 2 · Lnclass » |
| `show` | `page_title @article.title` | « Réviser le BEPC en 4 semaines · Lnclass » |
| `gone` | `page_title t(".page_title")` | « Article indisponible · Lnclass » |
| 404 | `errors/not_found`, inchangée | « Page introuvable · Lnclass » |

### 3.5 Points d'entrée

**`PublicPagesHelper#blog_link`** (`app/helpers/public_pages_helper.rb`, amendement de l'UDR-0063 §3.1) :

```ruby
# → [libellé, chemin] du blog s'il a au moins un article publié, sinon nil (UDR-0064 §3.5). Une requête par rendu.
def blog_link
  return @blog_link if defined?(@blog_link)

  @blog_link = ([ t("public_pages.links.blog"), blog_path ] if Queries::Communication::PublishedArticlesQuery.new.any?)
end
```

`public_page_links` ne change pas, et `/aide` (ligne « Vos données ») non plus.

**Pied de page de la homepage** (`app/views/homepage/index.html.erb`, amendement de l'UDR-0063 §3.4). La seconde liste devient :

```erb
<% if (public_links = [ blog_link, *public_page_links ].compact).any? %>
```

- Le reste est inchangé : `ul#public_pages`, `li` > `link_to label, href, class: "hover:text-ink"`.
- « Blog » vient en tête : « Blog · Notre mission · Protection des données · Conditions d'utilisation · Conditions de vente ».
- L'`aria-label` de la liste (`homepage.index.footer.public_pages`) passe de « Informations légales » à « Plus sur Lnclass » : la liste porte déjà la mission, qui n'est pas une information légale, et maintenant le blog.
- La première liste (les ancres « Pour qui ? · Fonctionnalités · Comment ça marche ») ne bouge pas : elle ne passe pas à la ligne, et un quatrième lien déborderait à 390 px. L'en-tête de la homepage ne gagne aucun lien.

**Pied de la carte d'aide** (`app/views/shared/_help_sheet.html.erb`, amendement de l'UDR-0061 §3.3, point 3, jamais construit jusqu'ici). Dans le bloc de `ui_modal`, après la `ul` des contacts :

```erb
<% if (links = [ blog_link, *public_page_links(%i[mission privacy terms]) ].compact).any? %>
  <nav id="help_sheet_links" aria-label="<%= t(".footer.label") %>" class="mt-4 border-t border-line pt-2">
    <ul class="flex flex-wrap justify-center gap-x-4 text-sm">
      <% links.each do |label, href| %>
        <li><%= link_to label, href, class: "inline-flex min-h-tap items-center text-mute underline underline-offset-2
                                              hover:text-ink focus-visible:outline-2 focus-visible:outline-brand" %></li>
      <% end %>
    </ul>
  </nav>
<% end %>
```

- Le pied affiche « Blog · Notre mission · Protection des données · Conditions d'utilisation ».
- Les libellés sont ceux de `public_pages.links` : une page a un seul nom dans toute l'application. Les clés `shared.help_sheet.footer.mission`, `.privacy` et `.terms` de l'UDR-0061 §3.5 ne sont pas créées, et « Confidentialité » devient « Protection des données ».
- Le focus d'ouverture reste sur la première ligne (« Questions fréquentes »).

**Aucun autre point d'entrée.** Ne changent pas : `NavigationHelper::DESTINATIONS`, l'en-tête, la barre latérale, la barre basse et le menu du compte de l'espace connecté, ni les accueils enseignant, direction et équipe (grill 3, UDR-0006). Le raccourci « Blog » de l'accueil équipe appartient à l'UDR-0065.

### 3.6 Textes, tokens, comportement, états, accessibilité, budgets

**Textes — fichiers de locale** (vouvoiement, comme l'UDR-0063 ; vocabulaire de l'UDR-0007 : « article », jamais « annonce ») :

`config/locales/communication/articles.fr.yml` (nouveau) :

| Clé | Texte |
|---|---|
| `date.formats.article_published` | `"%-d %B %Y"` → « 5 octobre 2026 » |
| `communication.articles.masthead.logo_home` | « Lnclass, accueil » |
| `communication.articles.index.page_title` | « Blog » |
| `communication.articles.index.page_title_paged` | « Blog, page %{page} » |
| `communication.articles.index.title` | « Blog » |
| `communication.articles.index.back` | « Accueil » |
| `communication.articles.index.og_title` | « Le blog de Lnclass » |
| `communication.articles.index.description` | « Conseils de révision, préparation du BEPC et du BAC, nouveautés : les articles de l'équipe Lnclass. » |
| `communication.articles.index.empty.title` | « Aucun article pour le moment » |
| `communication.articles.index.empty.description` | « Revenez bientôt : les premiers articles arrivent. » |
| `communication.articles.index.empty.action` | « Découvrir Lnclass » |
| `communication.articles.article_card.published_on` | « Publié le %{date} » |
| `communication.articles.show.back` | « Blog » |
| `communication.articles.show.team_signature` | « L'équipe Lnclass » |
| `communication.articles.show.published_on` | « Publié le %{date} » |
| `communication.articles.show.status.draft_hint` | « Visible par l'équipe seulement. » |
| `communication.articles.show.status.archived_hint` | « Retiré du blog : les visiteurs ne le voient plus. » |
| `communication.articles.show.next_label` | « Suite de la lecture » |
| `communication.articles.show.discover` | « Découvrir Lnclass » |
| `communication.articles.show.all_articles` | « Tous les articles » |
| `communication.articles.gone.page_title` | « Article indisponible » |
| `communication.articles.gone.title` | « Cet article n'est plus disponible » |
| `communication.articles.gone.description` | « Il a été retiré du blog de Lnclass. » |
| `communication.articles.gone.all_articles` | « Tous les articles » |
| `communication.articles.head.default_image_alt` | « Logo de Lnclass » |

Fichiers existants, une clé chacun :

| Fichier | Clé | Texte |
|---|---|---|
| `config/locales/communication/public_pages.fr.yml` | `public_pages.links.blog` | « Blog » |
| `config/locales/shared/help_sheet.fr.yml` | `shared.help_sheet.footer.label` | « Plus sur Lnclass » |
| `config/locales/homepage/index.fr.yml` | `homepage.index.footer.public_pages` (valeur modifiée) | « Plus sur Lnclass » (au lieu de « Informations légales ») |

Les textes des articles ne sont pas dans les locales : ils viennent de la base. Aucune clé n'est définie dans deux fichiers, et aucune valeur ne contient un mot interdit par `test/i18n/locale_files_test.rb`.

**Tokens** (UDR-0005 ; aucun nouveau token, aucun nouvel utilitaire, aucune valeur entre crochets, aucun `style=`) :
- **Fond** : `bg-paper` (page), `bg-white` (cartes, page 410), `bg-mist` (bandeau d'état, image en cours de chargement).
- **Texte** : `text-ink` (titres, corps), `text-mute` (résumé, date, signature, liens du pied de la carte), `text-brand-strong` (liens du texte, par `.trix-content`).
- **Bordures** : `border-line`, survol de carte `hover:border-brand/40`.
- **Ombres** : `shadow-card`, survol `shadow-lift`.
- **Rayons** : `rounded-card` (cartes, couverture), `rounded-ln` (bandeau, images du texte).
- **Typographie** : `font-display` 800 pour `h1` (`text-3xl`) et titres de carte (`text-lg`) ; corps 16 px ; résumé `text-sm` ; date de carte `text-xs` (12 px, plancher de la charte §4).
- **Espacements** : sur l'échelle de l'UDR-0005 seulement (`py-10`, `mb-6`, `mb-8`, `mt-10`, `p-5`, `space-y-5`, `gap-3`, `px-gutter`).
- **Couverture de la liste** : `aspect-video` et `object-cover`.

**Comportement** :
- **Turbo** :
  - Turbo Drive seulement : ni `turbo_frame_tag`, ni Turbo Stream, ni morph propre. La pagination est une navigation de page entière (liens `?page=N`), qui marche aussi sans JavaScript.
  - Le frame `modal` et la région `#toasts` du layout restent vides.
  - `data-turbo-prefetch="false"` sur `ol#blog_articles` : Turbo 8 précharge un lien au survol, et ce préchargement serait compté comme une lecture (BL-17). Le compteur de l'ADR-0073 ignore aussi toute requête qui porte `X-Sec-Purpose: prefetch` ou `Purpose: prefetch`.
- **Stimulus** : aucun contrôleur. `autofocus` (posé par le layout) n'a rien à viser : aucun champ.
- Les liens du texte gardent la cible écrite par l'auteur, assainie (BL-16) ; aucun `target` n'est ajouté.

**États obligatoires** :

| État | `/blog` | `/blog/:slug` |
|---|---|---|
| **Vide** | Aucun article publié : sous le `h1`, `div#blog_empty` > `ui_empty_state title: t(".empty.title"), description: t(".empty.description"), icon: "newspaper", action: { label: t(".empty.action"), href: root_path }` (« Aucun article pour le moment »). Pas de `ol`, pas de pagination. | Sans objet : un article publié a toujours titre, résumé et texte (BL-09). Sans couverture, la page passe du `header` au texte. |
| **Chargement** | Rendu serveur complet, sans frame ni squelette. La barre de progression de Turbo (`.turbo-progress-bar`) couvre la navigation. Chaque couverture réserve sa place (`width`, `height`, `aspect-video`) sur `bg-mist` jusqu'à son arrivée. | Idem. Images du texte en `loading="lazy"`, place réservée par `width`/`height` : le texte ne saute pas. |
| **Erreur** | Page au-delà de la dernière : 404 (`errors/not_found`). Panne serveur : `public/500.html`. Une image absente laisse son cadre `bg-mist` (et son `alt` sur la page d'article). | Brouillon (pour qui ne gère pas le blog) ou adresse inconnue : 404 `errors/not_found`. Archivé : 410 `gone` (§3.3). |
| **Succès** | La liste paginée (§3.2). | L'article (§3.3). Pour l'équipe, bandeau « Brouillon » ou « Archivé » et `noindex`. |

**Accessibilité** :
- **Titres** : un seul `h1` par page (« Blog », le titre de l'article, « Cet article n'est plus disponible »). Sur la liste, un `h2` par carte ; dans l'article, les seuls titres du texte sont des `h2` (Trix n'a qu'un niveau de titre, réécrit du `h1` au `h2`, §3.3). Aucun saut de niveau. La 404 garde sa vue actuelle.
- **Landmarks** : `main` unique (`nav` « Retour » ; `article[aria-labelledby="article_title"]` ; `nav` « Suite de la lecture » ; `nav#help_sheet_links` dans la carte).
- **Ordre de tabulation** :
  - liste : logo, « Accueil », chaque carte (son lien étiré), « Précédent », « Suivant » ;
  - article : logo, « Blog », liens du texte, « Découvrir Lnclass », « Tous les articles ».
- **Liens** :
  - soulignés dans le texte (`.trix-content a`) et au pied de la carte d'aide ;
  - le titre de carte est un lien étiré sans soulignement : la carte entière en est la cible, signalée par sa bordure, son survol et son contour de focus ;
  - `focus-visible` partout : `outline-2 outline-brand`, ou contour de la carte entière pour le lien étiré.
- **Cibles ≥ 48 px** : logo et retour (`min-h-tap`), carte entière, boutons `ui_button` `md` (`min-h-tap`), liens du pied de la carte (`min-h-tap`).
- **Images** :
  - `alt` obligatoire sur la couverture de l'article et sur chaque image du texte (refus de publier sans, BL-13) ;
  - `alt=""` sur la couverture de la liste et sur le logo (décoratifs, §3.2) ;
  - `og:image:alt` toujours rempli.
- **Dates** : `time[datetime]` en ISO 8601. Le « · » de la signature est `aria-hidden`.
- **Contraste** : `text-mute` sur `paper` et sur `white`, `text-brand-strong` sur `white`, conformes AA (UDR-0005). Aucun texte sur une image.
- **Lecture** : longueur de ligne bornée par `max-w-prose`, texte 16 px, interligne `leading-relaxed`.
- **À 390 px** : aucun défilement horizontal (`break-words` sur le texte, `pre` défilant dans son cadre, images `max-w-full`) ; boutons de fin pleine largeur, côte à côte à partir de `sm`.
- `prefers-reduced-motion` : `motion-reduce:transition-none` sur la carte. Aucune autre animation.
- `lang="fr"` : posé par le layout.

**Budgets** (PRD §7, BL-21) :
- **HTML brut** < 150 Ko :
  - un article de 1 500 mots avec cinq images ;
  - une page de liste de dix cartes.
  
  Aucune image en `data:` (l'assainisseur les refuse), aucun SVG d'icône hors `ui_icon`.
- **Temps serveur p95** < 100 ms pour `/blog` et `/blog/:slug` (ADR-0067) ; `blog_link` coûte une requête `EXISTS` par rendu de la homepage et de l'accueil élève.
- **JavaScript ajouté aux pages de lecture : 0 Ko.** Aucun nouveau contrôleur, aucun import, aucun chunk. `bin/check-asset-budget` ne bouge pas.
- **CSS** : aucune règle nouvelle ; les utilitaires listés entrent dans la feuille existante (plafond 30 Ko, ADR-0051).
- **Aucune ressource tierce** : images, polices et scripts servis par lnclass.com (ADR-0049, BL-14) ; `test/views/no_third_party_resources_test.rb` couvre les nouvelles vues.

### 3.7 Contrôle de la règle (UDR-0057), appliquée par analogie aux pages publiques

| Règle | `/blog` | `/blog/:slug` | 410 « n'est plus disponible » |
|---|---|---|---|
| R1 — une action principale | Aucune avec des articles (pagination `secondary`). État vide : « Découvrir Lnclass », seule. | « Découvrir Lnclass » (`primary`) ; « Tous les articles » est `secondary`. | « Tous les articles », seule. |
| R2 — 5 blocs avant défilement | Logo, retour, `h1`, liste : 4. | Logo, retour, en-tête (`h1` + signature), couverture, début du texte : 5. Le bandeau de l'équipe en fait 6 : il ne s'affiche qu'à l'équipe, sur un aperçu. | Logo, encadré : 2. |
| R3 — 3 lignes puis « Voir plus » | Ne s'applique pas, comme au catalogue (UDR-0013) et à la FAQ (UDR-0061) : la liste est l'objet de la page. La pagination par 10 tient le budget HTML et donne une adresse par page (§2.2). | Ne s'applique pas : un article se lit en entier, comme une fiche (UDR-0015). | — |
| R4 — pas d'aide permanente | Aucune introduction affichée : le `h1` suffit, la description vit dans la balise `meta`. | Aucune. Le bandeau dit un état, pas une explication. | La phrase dit un fait, pas un mode d'emploi. |
| R5 — une couleur d'accent | `brand` : survol et focus de carte. | `brand` : liens et focus. Le badge du bandeau (équipe seulement) est un signal sémantique d'état, celui de l'UDR-0065 ; le fond du bandeau est neutre. | Aucune couleur d'accent hors focus. |
| R6 — rien de répété | Ni signature ni lectures dans la carte ; la couverture a un `alt` vide parce que le titre dit déjà tout. | Le résumé n'est pas affiché (liste et aperçu seulement) ; la date est dite une fois. | — |

**Points d'entrée** : la carte d'aide garde ses trois lignes (R3) ; son pied est une ligne discrète `text-sm text-mute`, sans couleur d'accent (R5). Le pied de page de la homepage gagne un lien dans une liste existante.

### 3.8 Vérification

| Test | Fichier | Couvre |
|---|---|---|
| BL-01 — liste publique, tri, pagination (11 articles donnent 2 pages, `rel="next"`) | `test/controllers/communication/articles_controller_test.rb` | §3.1, §3.2 |
| BL-02 — 200 sans shell, un seul `h1` (même avec un `<h1>` dans le texte), signature, date | idem | §3.3 |
| BL-03 — les 12 balises du §3.4 avec la couverture, puis avec l'image par défaut ; adresses absolues sur `canonical_host` | idem | §3.4 |
| BL-04 — brouillon en 404 pour visiteur, élève, enseignant, direction, Terrain ; ni titre ni texte dans la réponse | idem | §3.3 |
| BL-05 — archivé en 410, « Cet article n'est plus disponible », lien vers `/blog`, `noindex` ; absent de la liste | idem | §3.3 |
| BL-06 — état vide ; « Blog » absent puis présent au pied de la homepage et de la carte d'aide | idem, `test/controllers/homepage_controller_test.rb`, `test/system/communication/help_sheet_test.rb` | §3.5 |
| BL-14 — chaque `img` de la page vise lnclass.com, avec `width`, `height`, `alt` ; `loading="lazy"` dans le texte | `articles_controller_test.rb` | §3.3 |
| BL-18 — « L'équipe Lnclass » pour un auteur désactivé | idem | §3.1 |
| BL-20 — élève connecté : 200 sur `/blog`, aucun renvoi | idem | §3.1 |
| BL-21 — HTML < 150 Ko (1 500 mots, 5 images) ; aucun `script` propre à la page, aucun `data-controller` | idem, `test/views/no_third_party_resources_test.rb` | §3.6 |
| `blog_link` : `nil` sans article, la paire avec ; une seule requête par rendu | `test/helpers/public_pages_helper_test.rb` | §3.5 |
| Titres d'onglet | `test/views/page_titles_test.rb` (inchangé : chaque vue appelle `page_title`) | §3.4 |

Chaque nouveau fichier de `app/` porte l'en-tête HITL de trois lignes. Exemple : `<%# 🌐 UI · communication/articles/show — page publique d'un article %>`, puis `Rôle`, puis `UDR : 0064 · ADR : 0073`.

## 4. Conséquences

- **Fichiers créés** :
  - vues : `app/views/communication/articles/{index,show,gone,_masthead,_article_card,_body_image,_head}.html.erb` ;
  - code : `app/controllers/communication/articles_controller.rb`, `app/helpers/communication/articles_helper.rb` ;
  - textes et image : `config/locales/communication/articles.fr.yml`, `app/assets/images/blog/partage.png`.
- **Fichiers partagés amendés** :
  - `app/helpers/public_pages_helper.rb` (`blog_link`) ;
  - `app/views/homepage/index.html.erb` (une ligne) ;
  - `app/views/shared/_help_sheet.html.erb` (le pied) ;
  - `config/routes/communication.rb` ;
  - trois locales existantes (§3.6).
  
  Ces fichiers sont touchés par un seul lot du plan, ou par le Lot 0.
- **Dépend de l'ADR-0073** :
  - route et en-têtes de cache des images publiques (`article_image_src`) ;
  - pièce jointe d'image et son `to_attachable_partial_path` ;
  - réécriture des `<h1>` du texte ;
  - `config.x.canonical_host` ;
  - compteur qui ignore les préchargements.
  
  Si l'ADR nomme ces éléments autrement, cette UDR est amendée, pas contournée dans la vue.
- **Interdit désormais** :
  - un lien vers `/blog` qui ne passe pas par `blog_link` ;
  - un lien « Blog » dans la navigation de l'espace connecté ;
  - un bouton ou un script de partage tiers ;
  - un `h1` dans le texte d'un article ;
  - une image d'article sans `width`, `height` et `alt` ;
  - une date d'article formatée hors de `article_date` ;
  - `ui_card(href:)` pour une carte qui contient un texte long.
- **Gestion du blog** (raccourci de l'accueil équipe, liste de gestion, modale d'édition, aperçu, menu ⋮) : [UDR-0065](0065-gestion-du-blog-par-l-equipe.md). Elle fournit `article_status_badge`, repris par le bandeau du §3.3. Elle ouvre l'aperçu sur `blog_article_path`, qui porte le bandeau du §3.3.
- **Famille téléphone de la homepage** (phase 2 d'`interface-epuree`, UDR-0059) : elle reprend le pied de page avec le lien « Blog » dans la même liste.
- **Plus tard, hors V1** : rubriques, recherche (memo, grill 6) et données structurées. Chacun passe par un amendement de cette UDR.
