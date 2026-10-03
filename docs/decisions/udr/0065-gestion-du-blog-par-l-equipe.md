# UDR-0065 : Gestion du blog par l'équipe — raccourci de l'accueil, liste de gestion, modale d'édition avec images, publication refusée, aperçu

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-02 : délégation, « crée un système de blog et puis c'est tout »)* |
| **Date** | 2026-10-02 |
| **Chantier** | [`docs/chantiers/blog`](../../chantiers/blog/prd.md) — chemin nominal A ; critères BL-07, BL-08, BL-09, BL-12, BL-13, BL-15, BL-17, BL-18 |
| **ADR lié** | ADR-0073 *(en cours d'écriture : images d'article JPEG/PNG/WebP vérifiées par le serveur, envoyées par un endpoint de l'équipe, plafonds chiffrés)* · [ADR-0035](../adr/0035-cycle-de-vie-et-propriete-du-contenu.md) (cycle de vie) · [ADR-0038](../adr/0038-comptes-de-l-equipe-et-sous-roles.md) (sous-rôles) · [ADR-0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (CSP stricte, aucun tiers) · [ADR-0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md) (Trix à la demande, budget JS) · [ADR-0060](../adr/0060-photo-de-profil-stockee-privee-recadree-par-le-navigateur.md) (réduction dans le navigateur) |
| **Amende** | [UDR-0014](0014-formulaire-cours.md) et [UDR-0016](0016-formulaire-fiche-essentielle.md) (éditeur riche : images admises **pour le blog seul**) · [UDR-0018](0018-accueil-equipe.md) (raccourci « Blog ») — les sections « Amendement » de ces UDR sont à ajouter par le chantier, ce fichier fait foi en attendant |
| **S'appuie sur** | [UDR-0005](0005-design-system-fondateur.md) (tokens, composants) · [UDR-0006](0006-shell-applicatif-par-role.md) (CRUD en modale, 5 destinations) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) (vocabulaire) · [UDR-0042](0042-actions-de-ligne-dans-un-menu.md) (menu ⋮) · [UDR-0050](0050-inviter-un-collegue-et-croissance.md) (page atteinte par un raccourci) · [UDR-0054](0054-finitions-d-interface.md) (titre, retour, auto-focus, infobulle) · UDR-0064 (pages publiques du blog, bandeau « Brouillon ») |
| **Remplacé par** | — |

---

## 1. Contexte

Le blog public de Lnclass ([PRD](../../chantiers/blog/prd.md)) est écrit dans l'application par l'équipe, et seulement par les sous-rôles **Administration** (`admin`) et **Contenu** (`content`). Le Terrain (`field`) le lit et le partage comme un visiteur. Aujourd'hui :

- l'accueil équipe n'a aucune entrée vers un contenu public, et la navigation de l'équipe est pleine (5 destinations, UDR-0006) ;
- l'éditeur riche (Trix) refuse tout fichier, partout (UDR-0014, UDR-0016) : un article sans image n'a pas d'aperçu illustré quand on le partage sur WhatsApp ou Facebook (grill 5) ;
- l'équipe n'a aucun moyen de savoir si un article est lu (grill 8), ni de retirer un article déjà partagé sans casser son lien (grill 7) ;
- un membre de l'équipe écrit souvent depuis un téléphone, sur un réseau lent : une photo prise au téléphone pèse plusieurs Mo.

Sans écran de gestion, aucun des quatre objectifs du blog (se faire connaître, rassurer, aider à réussir, annoncer les nouveautés) ne démarre.

## 2. Décision

1. **Entrée par un raccourci de l'accueil équipe, « Blog »**, visible des seuls sous-rôles qui gèrent le blog. Aucune destination de navigation n'est ajoutée : l'équipe reste à 5 (UDR-0006 §4), comme pour « Croissance » (UDR-0050). La vue ne teste pas le rôle : elle reçoit un booléen calculé par la policy, comme `can_invite` (UDR-0018 §2.2).
2. **Une liste de gestion `/teams/blog`**, en tableau, avec **tous** les articles (brouillon, publié, archivé), leur badge d'état, une date, leur nombre de lectures, et un menu ⋮ par ligne. Le tableau plutôt que des cartes : c'est le motif de tous les écrans de gestion de l'équipe (UDR-0042), et l'équipe y compare des chiffres. Le compteur dit sa limite à l'écran (« sans dédoublonnage »), parce qu'un chiffre brut lu sans sa limite mène à une mauvaise décision.
3. **Toutes les actions sur un article vivent dans son menu ⋮** (UDR-0042, amendement du 2026-09-30) : Modifier, Aperçu, puis la transition permise par l'état (Publier, Archiver, Remettre en ligne). Seul « Nouvel article » reste en tête de page. Pas de suppression : on archive (grill 7).
4. **Création et modification dans une seule modale large** (`ui_modal size: :lg`), comme un cours (UDR-0014) : l'état ne s'y choisit pas. Un article naît en brouillon. L'état change par le menu ⋮ (transitions nommées, journal d'audit, ADR-0035).
5. **L'éditeur riche s'ouvre aux images pour le blog seul.** Le même contrôleur `rich-text-editor` sert aux deux usages ; une valeur Stimulus (`data-rich-text-editor-attachments-value`) l'active. Absente ou fausse, rien ne change : cours et fiches refusent toujours tout fichier (BL-15). On ne crée pas un second contrôleur d'éditeur : la traduction de la barre d'outils, le chargement à la demande et le refus des fichiers resteraient en double.
6. **Les images sont réduites dans le navigateur, puis envoyées tout de suite à un endpoint de l'équipe**, une par une, pendant la rédaction ; l'article ne transporte ensuite que leurs identifiants. Pourquoi pas dans l'envoi du formulaire (multipart, comme la photo de profil) : un champ fichier se vide à chaque re-rendu 422, et l'auteur perdrait ses images à la première erreur de titre. La couverture suit le même chemin, pour la même raison.
7. **Le texte de remplacement de chaque image se saisit dans un panneau « Images du texte », sous l'éditeur**, une ligne par image avec sa vignette et son champ. Pourquoi pas une boîte qui s'ouvre à chaque image insérée : coller trois images ouvrirait trois boîtes et couperait la rédaction ; et Action Text ne conserve pas d'attribut `alt` dans le contenu, le texte vit donc avec l'image (`Entities::Communication::ArticleImage`). Enregistrer un brouillon sans texte de remplacement est permis ; **publier** ne l'est pas (BL-13).
8. **Publication refusée : la modale de modification s'ouvre d'elle-même**, avec chaque manque sous son champ et un résumé en tête. Un toast seul nommerait le manque sans mener à l'endroit où le corriger.
9. **Aucune règle sur le sujet d'un article** (décision du porteur du 2026-10-02, grill 4) : ni rappel éditorial dans la modale, ni case d'accord, ni vérification. Ce qu'un article dit relève de l'équipe qui le publie.
10. **L'aperçu est la page publique de l'article**, ouverte dans le même onglet ; son bandeau « Brouillon » est régi par l'UDR-0064. Cette UDR ne régit que le lien.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement. Chaque nouveau fichier de `app/` porte l'en-tête HITL ([conventions §5](../../guide/conventions.md#5-en-tête-hitl)) et cite « UDR : 0065 ».

### 3.0 Routes et données attendues

Routes (contrat du Lot 0 ; un autre nom impose d'amender cette section) :

| Geste | Verbe et chemin | Helper |
|---|---|---|
| Liste | `GET /teams/blog` | `teams_articles_path` |
| Nouvel article | `GET /teams/blog/new` · `POST /teams/blog` | `new_teams_article_path` · `teams_articles_path` |
| Modifier | `GET /teams/blog/:public_id/edit` · `PATCH /teams/blog/:public_id` | `edit_teams_article_path(public_id)` · `teams_article_path(public_id)` |
| Publier, remettre en ligne | `PATCH /teams/blog/:public_id/publish` | `publish_teams_article_path(public_id)` |
| Archiver | `PATCH /teams/blog/:public_id/archive` | `archive_teams_article_path(public_id)` |
| Envoyer une image | `POST /teams/blog/images` | `teams_article_images_path(article: public_id)` (paramètre `article` absent à la création) |
| Aperçu | page publique de l'article (UDR-0064) | `blog_article_path(slug)` |

- Contrôleurs : `Teams::ArticlesController` et `Teams::ArticleImagesController`, sous `Teams::BaseController` (connexion, second facteur), chaque action passant par `Policies::Communication::ManageArticlesPolicy` : 403 pour le Terrain, l'élève, l'enseignant et la direction (BL-08) ; un visiteur est renvoyé à la connexion.
- Les gestes d'écriture suivent `RendersResult` et le motif de `Teams::CoursesController` : `render_result …, form: :new|:edit, success: ->(article) { … }`.
- Clé d'un article dans l'équipe : `public_id`. Le `slug` ne sert qu'à l'aperçu.
- Constantes lues par les vues, jamais recopiées en dur, ni dans une vue ni dans le JavaScript :
  - `Entities::Communication::Article::TITLE_MAX` (120) et `EXCERPT_MAX` (200) ;
  - `Entities::Communication::ArticleImage::CONTENT_TYPES` (`image/jpeg`, `image/png`, `image/webp`), `MAX_BYTES`, `MAX_SIDE`, `MAX_PER_ARTICLE` et `ALT_MAX`. **Valeurs fixées par l'ADR-0073.** Défaut proposé en attendant l'ADR : 1 Mo, 1 600 px de côté, 10 images dans le texte par article (couverture non comptée), 150 caractères de texte de remplacement.
- Ce que la vue de la modale lit sur `@form` (`Dtos::Communication::ArticleInput`) : `title`, `excerpt`, `body`, `signature` (`"team"` ou `"author"`), `cover_public_id`, `cover_url`, `cover_alt`, et `images`, la liste ordonnée, dans l'ordre du texte, des images du texte (`public_id`, `sgid`, `url`, `alt`). La liste est reconstruite par le contrôleur à partir du `body` envoyé et de `image_alts` : un re-rendu 422 garde les images et leurs textes.
- Ce que la vue de la liste lit (`Queries::Communication::TeamArticlesQuery#call(page:)` → `page`, `pages`, `total_count`, `rows`) : chaque ligne porte `public_id`, `slug`, `title`, `status`, `signature`, `author_name`, `published_at`, `archived_at`, `updated_at`, `reads_count`. Tri : dernière modification d'abord. 20 lignes par page (`PER_PAGE`).

### 3.1 Raccourci « Blog » de l'accueil équipe

**Structure**
- `Teams::HomesController#show` calcule `@can_manage_blog = Policies::Communication::ManageArticlesPolicy.new.call(actor: current_actor).success?`, à côté de `@can_invite`.
- `teams/homes/show` : `render "shortcuts", can_invite: @can_invite, can_manage_blog: @can_manage_blog`.
- `teams/homes/_shortcuts` : déclaration `<%# locals: (can_invite:, can_manage_blog:) -%>` ; après « Croissance » et avant « Inviter un membre » :
  `<% if can_manage_blog %><%= ui_button t(".blog"), href: teams_articles_path, variant: :secondary, icon: "newspaper", id: "team_home_blog_shortcut" %><% end %>`.
- Navigation Turbo ordinaire (pas de modale). Mettre à jour la ligne « Rôle » de l'en-tête HITL du partial.

**États** : `admin` et `content` voient le raccourci ; `field` ne le voit pas (BL-08). Aucun autre état : le bouton est un lien.

**Accessibilité** : cible de 48 px (`ui_button` `md`), libellé visible, icône décorative ; à 390 px, les raccourcis passent à la ligne (inchangé).

### 3.2 Liste de gestion — `teams/articles/index`

**Structure**
- `<% page_title t(".page_title") %>` → « Blog · Équipe · Lnclass ».
- `ui_page_header title: t(".title"), subtitle: t(".subtitle"), back: { label: t(".back"), href: team_home_path }`, avec en action : `ui_button t(".new_article"), href: new_teams_article_path, icon: "plus", data: { turbo_frame: "modal" }, id: "teams_articles_new"`.
- Aucun Turbo Frame autour de la liste (pas de recherche ni de filtre) : la pagination est une visite Turbo Drive ordinaire.
- `p#teams_articles_total.mb-3.text-sm.text-mute[aria-live="polite"]` : `t(".total", count: @page.total_count)`.
- Si `@page.rows.any?` : `div.relative.overflow-x-auto.rounded-card.border.border-line.bg-white.shadow-card` → `table.w-full.min-w-3xl.text-left.text-sm` :
  - `caption.sr-only` : `t(".caption")` ;
  - `thead.border-b.border-line.text-xs.text-mute`, une `th[scope=col].px-4.py-3.font-medium` par colonne, dans l'ordre : « Article », « État », « Date », « Lectures », puis `th.sticky-actions.px-4.py-3` contenant `span.sr-only` « Actions » ;
  - colonne « Lectures » : le libellé, puis la mention visible `span.block.text-2xs.font-normal` `t(".columns.reads_note")` (« sans dédoublonnage »), puis `ui_info_tip t(".reads_tip"), label: t(".columns.reads")` ;
  - `tbody#teams_articles_list.divide-y.divide-line` : `render partial: "article_row", collection: @page.rows, as: :article`.
- Sinon : `div#teams_articles_empty` → `ui_empty_state title: t(".empty_title"), description: t(".empty_description"), icon: "newspaper"` avec le bloc `ui_button t(".new_article"), href: new_teams_article_path, icon: "plus", data: { turbo_frame: "modal" }`.
- `div.mt-5` → `ui_pagination page: @page.page, pages: @page.pages` (ne rend rien s'il n'y a qu'une page).

**Ligne — `teams/articles/_article_row`** : `tr#article_<public_id>.align-middle`
1. `td.min-w-64.px-4.py-3` : titre `span.font-medium.text-ink` (texte, pas un lien : l'aperçu est dans le menu) ; dessous `span.block.text-xs.text-mute` : `t(".written_by", author: article.author_name)` puis ` · ` puis `t(".signed_team")` ou `t(".signed_author")` selon `signature`. Un auteur désactivé ou anonymisé garde son nom ici, l'équipe en a besoin ; c'est la page publique qui signe « L'équipe Lnclass » (BL-18, UDR-0064).
2. `td.px-4.py-3` : `article_status_badge(article.status)`.
3. `td.px-4.py-3.whitespace-nowrap.text-mute` : `published` → `t(".published_on", date: l(article.published_at.to_date, format: :long))` ; `archived` → `t(".archived_on", …archived_at…)` ; `draft` → `t(".updated_on", …updated_at…)`.
4. `td.px-4.py-3.tabular-nums` : si `published_at` est nul, `span[aria-hidden=true]` « — » puis `span.sr-only` `t(".never_published")` ; sinon `number_with_delimiter(article.reads_count)` (BL-17 : l'archivé garde son compteur).
5. `td.sticky-actions.px-4.py-3` → `div.flex.justify-end` → `ui_dropdown label: t(".actions", title: article.title), id: "article-actions-#{article.public_id}", fixed: true` contenant `article_menu_items(article:)` (§3.2 bis).

**Helper — `app/helpers/communication/article_status_helper.rb`** (`Communication::ArticleStatusHelper`, couvert à 100 % par `test/helpers/communication/article_status_helper_test.rb`)
- `ARTICLE_STATUS_TONES = { "draft" => :warning, "published" => :success, "archived" => :neutral }`, les mêmes tons que le catalogue.
- `article_status_badge(status)` → `ui_badge(t("teams.articles.status.#{status}"), tone:, dot: true)`.
- `article_menu_items(article:)` → `div#article_transitions_<public_id>.contents[role=none]` qui contient, dans l'ordre :
  1. `ui_dropdown_item t("teams.articles.menu.edit"), href: edit_teams_article_path(public_id), icon: "pencil-square", frame: "modal"` ;
  2. `ui_dropdown_item t("teams.articles.menu.#{published ? 'view' : 'preview'}"), href: blog_article_path(slug), icon: "eye"` (« Voir l'article » pour un publié, « Aperçu » sinon) ;
  3. une entrée par transition de `Entities::Communication::Article::TRANSITIONS.fetch(status)`, en `method: :patch` : `draft → published` « Publier » (`check-circle`, `publish_teams_article_path`), `published → archived` « Archiver » (`archive-box`, `archive_teams_article_path`), `archived → published` « Remettre en ligne » (`arrow-uturn-up`, `publish_teams_article_path`). Le libellé et l'icône viennent d'une table `{ [from, to] => [clé, icône, action] }` du helper, jamais d'une condition dans la vue.
- Pas de confirmation pour « Archiver » : le geste se rattrape (« Remettre en ligne »), comme pour un cours.

**Comportement**
- « Nouvel article » et « Modifier » chargent la modale dans le frame `modal` du layout (UDR-0006).
- Transition réussie : `transition.turbo_stream.erb` = `turbo_stream_toast(…, type: :success)` puis `turbo_stream.replace "article_<public_id>", method: :morph, partial: "teams/articles/article_row", locals: { article: }`. Le morphing garde le bouton ⋮ (même id) et son focus. La ligne n'est pas déplacée ; elle le sera au prochain affichage.
- Transition déjà faite ou interdite (`:conflict`) : **422**, `turbo_stream_toast t(".conflict", title:), type: :error` et la ligne re-rendue dans son état relu.
- Publication d'un article incomplet : §3.5.
- Repli sans Turbo : chaque écriture redirige en 303 vers `teams_articles_path` avec `notice` ou `alert` (texte des toasts).

**États obligatoires**
- Vide : `#teams_articles_empty` (« Aucun article pour l'instant »), avec « Nouvel article ».
- Chargement : barre de progression de Turbo Drive pour la pagination ; la modale se charge dans son frame (inchangé).
- Erreur : 403 (page `errors/forbidden`) pour qui ne gère pas le blog ; toast d'erreur pour une transition refusée ; une page hors bornes est ramenée à la dernière par `ui_pagination`.
- Succès : toast, ligne remplacée par morphing.

**Accessibilité**
- Bouton ⋮ : `aria-label` « Actions pour « <titre> » » (UDR-0042) ; entrées `min-h-tap`, clavier du motif « menu button ».
- Le chiffre des lectures se lit avec son en-tête ; la mention « sans dédoublonnage » est du texte visible, pas une infobulle seule (UDR-0054 §4).
- À 390 px : le tableau défile dans sa carte, la colonne ⋮ reste collée (`sticky-actions`), la page ne défile pas en largeur.

### 3.3 Modale d'édition — `teams/articles/new`, `edit`, `_edit_modal`, `_form`

**Structure**
- `new.html.erb` : `turbo_frame_tag "modal"` → `ui_modal title: t(".title"), id: "article-modal", size: :lg, open: true, document_title: page_title(t(".title"))`. Pied : `ui_button t(".cancel"), variant: :secondary, data: { action: "modal#close" }`, puis `ui_button t(".submit"), type: :submit, form: "article-form", id: "article-submit"`. Corps : `p.mb-5.flex.flex-wrap.items-center.gap-2.text-sm.text-mute` avec `article_status_badge("draft")` et `t(".draft_notice")`, puis `render "form", input: @form, url: teams_articles_path, method: :post, upload_url: teams_article_images_path`.
- `edit.html.erb` : `turbo_frame_tag "modal" { render "edit_modal", article: @article, form: @form, refused: false }`.
- `_edit_modal.html.erb` (rendu aussi par la publication refusée, §3.5) : même `ui_modal` (`id: "article-modal"`, `size: :lg`, `open: true`, `document_title: page_title(t(".title"))`). Corps : si `refused`, l'encadré `#article_publish_refused` (§3.5) ; puis la ligne d'état : `article_status_badge(article.status)` et `t(".status_notice")`, plus, si l'article est publié, `t(".published_notice")` ; puis `render "form", input: form, url: teams_article_path(article.public_id), method: :patch, upload_url: teams_article_images_path(article: article.public_id)`. Pied : « Annuler » et `ui_button t(".submit"), type: :submit, form: "article-form", id: "article-submit"`.
- `_form.html.erb` : `stylesheet_link_tag "trix"` en tête (une réponse de frame n'a pas de `<head>`), puis `form_with model: input, scope: :article, url:, method:, id: "article-form", class: "space-y-6"`. Dans l'ordre :
  1. **Erreur `base`** : l'encadré `role="alert"` de `teams/courses/_form` (fond `error-soft`, icône `exclamation-circle`), `id="article_base_error"`.
  2. **Titre** : `ui_field form, :title, required: true, maxlength: Entities::Communication::Article::TITLE_MAX, autocomplete: "off", autofocus: true, placeholder: t(".title_placeholder"), hint:`. À la création, `t(".title_hint_new", max:)` ; en modification, `t(".title_hint_edit", max:, path: blog_article_path(slug))` (l'adresse est figée, BL-10).
  3. **Résumé** : `div[data-controller="communication--character-count"][data-communication--character-count-max-value=<EXCERPT_MAX>]` → `ui_field form, :excerpt, as: :textarea, rows: 3, maxlength: EXCERPT_MAX, hint: t(".excerpt_hint", max:), data: { "communication--character-count-target": "input", action: "input->communication--character-count#update" }` → `p#article_excerpt_count.text-right.text-xs.tabular-nums.text-mute[aria-hidden=true][data-communication--character-count-target=count]`, rendu par le serveur avec `t(".excerpt_count", count: input.excerpt.to_s.length, max:)` (« 42 / 200 ») → `span.sr-only[aria-live=polite][data-communication--character-count-target=status]` (vide).
  4. **Couverture** : `fieldset#article_cover` (§3.4.1).
  5. **Texte** (§3.4.2) : barre « libellé + Insérer une image », éditeur, région d'erreurs d'envoi, état d'envoi, aide, erreur du champ, panneau « Images du texte ».
  6. **Signature** : `ui_radio_group form, :signature, choices: [ [ t(".signature_team"), "team" ], [ t(".signature_author", name: author_name), "author" ] ], label: t(".signature_label"), hint: t(".signature_hint"), required: true, columns: 2`. `author_name` est le nom de l'auteur de l'article, celui du membre connecté à la création : c'est vrai même quand un autre membre modifie l'article. Valeur par défaut d'un nouvel article : `"team"`.
- **Aucun rappel éditorial, aucune case d'accord** (§2.9).
- Pas de champ d'état, pas de bouton « Supprimer », pas de « Publier » dans la modale (UDR-0014).

**Composant `communication--character-count`** (`app/javascript/controllers/communication/character_count_controller.js`)
- Valeur `max` (Number). Cibles `input`, `count`, `status`. Messages lus sur l'élément : `data-communication--character-count-near-value` (« Il reste %{count} caractères. ») et `-full-value` (« Limite atteinte : %{max} caractères. »), rendus par le serveur.
- `update()` : `count` = « <longueur> / <max> » ; à 20 caractères restants ou moins, `count` passe en `text-warning` ; à 0, en `text-error`. Le texte de `status` ne change qu'au franchissement d'un seuil (20 restants, puis limite atteinte), pour ne pas annoncer chaque frappe.
- Sans JavaScript : le compteur reste au chiffre rendu par le serveur, et `maxlength` borne la saisie.

**Comportement**
- `create` réussi : `create.turbo_stream.erb` = `turbo_stream_toast t(".created", title:), type: :success`, `turbo_stream.update "modal"`, `turbo_stream.refresh(request_id: nil)` (la liste est re-demandée et fusionnée par morphing, le nouvel article apparaît en tête).
- `update` réussi : `update.turbo_stream.erb`, identique, avec `t(".updated", title:)`, ou `t(".updated_live", title:)` si l'article est publié.
- Saisie invalide : `render :new` ou `:edit` en **422** dans le frame : erreur sous chaque champ, valeurs conservées, contenu riche, couverture et images comprises (§3.0). Le focus va au premier champ en erreur (UDR-0054 §3.3).
- Modifier un article **publié** : l'enregistrement exige ce qu'exige la publication (titre, résumé, texte, textes de remplacement). Le refus est un 422 dans la modale, avec les messages du §3.5. *(Règle attendue du use case `UpdateArticle`, à confirmer par l'ADR-0073 : un article en ligne n'est jamais rendu incomplet.)*
- Envoi tant qu'une image est en cours d'envoi : §3.4.3.
- Fermer la modale (Annuler, Échap, fond) ne demande rien. Les images déjà envoyées et non enregistrées deviennent orphelines et sont purgées par le serveur (ADR-0073).

**États obligatoires**
- Vide : nouvel article : champs vides, signature « L'équipe Lnclass », couverture absente (§3.4.1), panneau des images caché.
- Chargement : la modale arrive dans son frame ; la barre d'outils de Trix apparaît au chargement du module ; `aria-busy` pendant un envoi d'image ou de couverture ; « Enregistrer » en `loading` pendant l'envoi du formulaire.
- Erreur : 422 dans la modale ; refus d'image dans la région du §3.4.2 ; 403 ou 404 rendus en toast d'erreur (`RendersResult`, format Turbo Stream).
- Succès : toast, modale fermée (`modal#submitEnd`), liste rafraîchie sans rechargement.

**Accessibilité**
- `<dialog>` native, focus piégé, Échap ; focus d'ouverture sur « Titre » (`autofocus: true` de `ui_field`), jamais sur la croix.
- Chaque champ a un libellé visible, son aide et sa première erreur reliées par `aria-describedby` et `aria-invalid` (`ui_field`, `ui_radio_group`).
- À 390 px, la modale est pleine largeur, la barre d'outils de Trix défile dans sa propre bande, la vignette d'image passe au-dessus de son champ (`flex-col sm:flex-row`), la page ne défile jamais en largeur.

### 3.4 Images

#### 3.4.1 Couverture — `fieldset#article_cover`

**Structure** : `fieldset#article_cover.space-y-3[data-controller="communication--cover-picker"]`, avec les valeurs `upload-url` (`upload_url`), `max-side` (`MAX_SIDE`), `max-bytes` (`MAX_BYTES`), `accept` (JSON de `CONTENT_TYPES`) et `messages` (JSON, §3.4.4).
1. `legend.text-sm.font-medium.text-ink` : `t(".cover_legend")` (« Image de couverture (facultative) »).
2. Aperçu, `div.overflow-hidden.rounded-ln.border.border-line.bg-mist` :
   - `img#article_cover_preview.aspect-video.w-full.object-cover[data-communication--cover-picker-target=preview][alt=""]`, `hidden` sans couverture. L'aperçu est décoratif : le texte de remplacement est saisi juste en dessous ;
   - `div#article_cover_placeholder.flex.aspect-video.flex-col.items-center.justify-center.gap-2.text-sm.text-mute[data-communication--cover-picker-target=placeholder]`, avec `ui_icon "photo", size: :lg` et `t(".cover_placeholder")` (« Aucune couverture : le partage utilisera l'image par défaut de Lnclass. »), `hidden` s'il y a une couverture.
3. `div.flex.flex-wrap.items-center.gap-3` :
   - champ fichier `input#article_cover_file[type=file]` **sans `name`** (le fichier part par l'endpoint, jamais avec le formulaire), `accept="image/jpeg,image/png,image/webp"`, sans `capture`, `data-communication--cover-picker-target="input"`, `data-action="change->communication--cover-picker#pick"`, `aria-describedby="article_cover_file_hint"`, classes du champ fichier de la photo (`file:min-h-tap …`, bord `border-line`, `border-error` en erreur), précédé de `label[for=article_cover_file]` `t(".cover_file_label")` (« Choisir une image ») ;
   - `ui_button t(".cover_remove"), variant: :secondary, size: :sm, icon: "trash", id: "article_cover_remove", data: { "communication--cover-picker-target": "remove", action: "communication--cover-picker#clear" }`, `hidden` sans couverture.
4. `p#article_cover_file_hint.text-sm.text-mute` : `t(".cover_hint", max_side:, max_bytes:)`.
5. `p#article_cover_status.flex.items-center.gap-2.text-sm.text-mute[aria-live=polite][data-communication--cover-picker-target=status]` : vide au repos ; pendant l'envoi, `ui_spinner(size: :sm)` (cloné depuis un `<template data-communication--cover-picker-target="spinner">`) et le message `uploading`.
6. `p#article_cover_upload_error.flex.items-center.gap-1.5.text-sm.font-medium.text-error[role=alert][hidden][data-communication--cover-picker-target=error]`, avec l'icône `exclamation-circle` et le texte posé par le contrôleur.
7. `hidden_field :cover_public_id, id: "article_cover_public_id", data: { "communication--cover-picker-target": "id" }`. L'erreur serveur de ce champ (image inconnue, refusée) s'affiche en `p#article_cover_public_id_error` sous l'aide, reliée au champ fichier.
8. `ui_field form, :cover_alt, maxlength: ALT_MAX, hint: t(".cover_alt_hint"), data: { "communication--cover-picker-target": "alt" }` : « Texte de remplacement de la couverture ». Il n'est pas marqué obligatoire (on peut enregistrer un brouillon sans lui) ; l'aide dit qu'il l'est pour publier avec une couverture.

**Comportement** (`app/javascript/controllers/communication/cover_picker_controller.js`)
- `pick()` : vérifie le type annoncé (`accept`), sinon refus `format` ; charge `await import("../../lib/image_upload")` ; réduit (§3.4.3) ; refuse `too_heavy` si le fichier réduit dépasse `max-bytes` ; envoie ; à la réponse 201, pose `id` = `public_id`, `preview.src` = `url`, montre l'aperçu et « Retirer la couverture », cache le texte d'attente, vide le champ fichier. Pendant tout le traitement, `aria-busy="true"` sur le `fieldset`.
- Refus ou échec : `error` montré avec le message, `aria-invalid="true"` et `article_cover_upload_error` ajoutés au `aria-describedby` du champ fichier ; la couverture précédente reste en place.
- `clear()` : vide `id`, cache l'aperçu, montre le texte d'attente, cache « Retirer la couverture », rend le focus au champ fichier. Le texte de remplacement est gardé, sans effet tant qu'il n'y a pas de couverture.
- `hold(event)` sur l'envoi du formulaire : §3.4.3.

#### 3.4.2 Texte et images du texte

**Structure** : `div.space-y-2` contenant, dans l'ordre :
1. `div.flex.flex-wrap.items-end.justify-between.gap-3` : `form.label :body` (`id="article_body_label"`) et `ui_button t(".insert_image"), variant: :secondary, size: :sm, icon: "photo", id: "article_insert_image", hidden: true, data: { "rich-text-editor-target": "pickButton", action: "rich-text-editor#pickImages" }`. Le bouton reste caché tant que le contrôleur n'est pas connecté en mode images.
2. `input#article_image_files[type=file][multiple][hidden]`, `accept="image/jpeg,image/png,image/webp"`, sans `name`, `data-rich-text-editor-target="fileInput"`, `data-action="change->rich-text-editor#insertPicked"`.
3. `div#article_editor[data-controller="rich-text-editor communication--image-alts"]` avec les données de `article_editor_data(upload_url:)` (§3.4.4) et `data-action="rich-text-editor:uploaded->communication--image-alts#add rich-text-editor:attached->communication--image-alts#restore rich-text-editor:removed->communication--image-alts#remove trix-change->communication--image-alts#renumber"` :
   - `form.rich_textarea :body, id: "article_body"`, `placeholder: t(".body_placeholder")`, `data: rich_text_without_uploads` (inchangé : l'envoi passe par l'endpoint de l'équipe, pas par Active Storage), `"aria-describedby": "article_body_hint"` (plus `article_body_error` en erreur), `aria-invalid` en erreur, classes de l'éditeur de la fiche essentielle (`trix-content block min-h-48 w-full rounded-ln border bg-white px-4 py-3 text-base text-ink`, `border-error` en erreur, sinon `border-line`) ;
   - `div#article_body_upload_errors.space-y-1[role=alert][hidden][data-rich-text-editor-target=errors]` : un `p.flex.items-center.gap-1.5.text-sm.font-medium.text-error` par refus du dernier lot, avec l'icône `exclamation-circle`, cloné depuis `<template data-rich-text-editor-target="errorTemplate">` ; vidé au lot suivant ;
   - `p#article_body_upload_status.sr-only[aria-live=polite][data-rich-text-editor-target=status]` ;
   - `p#article_body_hint.text-sm.text-mute` : `t(".body_hint", max_count:, max_bytes:)` ;
   - si erreur sur `body` : `p#article_body_error` (même balisage que `essential_content_error`) ;
   - **panneau des images** : `section#article_images.space-y-3.rounded-ln.border.border-line.bg-paper.p-4[aria-labelledby=article_images_title][data-communication--image-alts-target=panel]`, `hidden` s'il n'y a aucune image :
     - `h3#article_images_title.text-sm.font-semibold.text-ink` : `t(".images_title")` puis `span[data-communication--image-alts-target=total]` « (N) » ;
     - `p.text-sm.text-mute` : `t(".images_intro")` ;
     - `ul#article_images_list.space-y-3[data-communication--image-alts-target=list]` : une ligne `_image_alt_row` par élément de `input.images` ;
     - `<template data-communication--image-alts-target="rowTemplate">` : la même ligne, rendue par le serveur avec les jetons `__PUBLIC_ID__`, `__SGID__`, `__URL__` et `__NUMBER__`, que le contrôleur remplace.
- **Ligne — `teams/articles/_image_alt_row`** (`locals: (form:, image:, number:, error:)`) : `li#article_image_<public_id>.flex.flex-col.gap-3.sm:flex-row.sm:items-start[data-sgid=<sgid>][data-communication--image-alts-target=row]`
  - `img.size-16.shrink-0.rounded-sm.bg-mist.object-cover[alt=""][loading=lazy]`, `src` = `url` ;
  - `div.min-w-0.flex-1.space-y-1.5` : `label[for=article_image_alts_<public_id>].block.text-sm.font-medium.text-ink` = `t(".image_alt_label")` (« Texte de remplacement de l'image ») + `span[data-number]` « <n> » ; puis, si le champ est vide, `ui_badge t(".image_alt_missing"), tone: :warning, size: :sm` (`data-communication--image-alts-target="missing"`) ; puis `input[type=text]#article_image_alts_<public_id>[name="article[image_alts][<public_id>]"]`, `maxlength=ALT_MAX`, `autocomplete="off"`, classes des champs `ui_field` (`min-h-tap rounded-ln border bg-white px-4 text-base`, bord `border-line` ou `border-error`), `aria-describedby="article_image_alts_<public_id>_hint"` (+ `_error`), `aria-invalid` en erreur, `data-action="input->communication--image-alts#mark keydown.enter->communication--image-alts#backToEditor"` ; `p#article_image_alts_<public_id>_hint.text-sm.text-mute` = `t(".image_alt_hint")` ; erreur `p#article_image_alts_<public_id>_error`, lue sur `input.errors[:"image_alts.#{public_id}"]`.

**Comportement — `rich-text-editor` en mode images** : §3.4.3.

**Comportement — `communication--image-alts`** (`app/javascript/controllers/communication/image_alts_controller.js`)
- `add({ detail: { publicId, sgid, url } })` : clone `rowTemplate`, remplace les jetons, ajoute la ligne, montre le panneau, renumérote, et écrit dans `status` (de l'éditeur) le message `uploaded` (« Image <n> ajoutée. Saisissez son texte de remplacement sous l'éditeur. »). **Le focus ne bouge pas** : l'auteur continue d'écrire (WCAG 3.2.2) ; la ligne porte le badge « À compléter ».
- `remove({ detail: { sgid } })` (image retirée du texte) : la ligne passe `hidden` et son champ `disabled` (il n'est pas envoyé) ; le texte saisi est gardé. `restore({ detail: { sgid } })` (image revenue par Annuler dans Trix) : la ligne revient, son champ est réactivé.
- `renumber()` (à chaque `trix-change`) : lit l'ordre des pièces jointes (`trix-editor.editor.getDocument().getAttachments()`, par `sgid`), range les lignes visibles dans cet ordre, met à jour `[data-number]` et le total ; panneau caché à zéro image visible.
- `mark()` : badge « À compléter » caché dès que le champ n'est plus vide (espaces retirés), remontré s'il le redevient.
- `backToEditor(event)` : `preventDefault()` (Entrée n'envoie jamais le formulaire depuis ce champ), puis focus dans l'éditeur, curseur juste après l'image de la ligne (`editor.setSelectedRange`).

#### 3.4.3 Réduction, envoi et refus (éditeur et couverture)

- **Module partagé** `app/javascript/lib/image_upload.js`, toujours chargé par `import()` dynamique (il sort du bundle commun, comme Trix ; budget de l'ADR-0051) :
  - `shrinkImage(file, { maxSide })` : décode (`Image` + `URL.createObjectURL`, `decode()`) ; une image de 0 × 0 ou sans pixel visible lève `EmptyImage` ; réduit **sans recadrer** pour que le plus grand côté fasse au plus `maxSide` (jamais d'agrandissement) ; fond `--color-white` sous la transparence ; encode en WebP 0,8, sinon JPEG 0,8 (mêmes règles que `identity/photo_picker_controller.js`) ; le canvas ne recopie aucune métadonnée. Une image que le navigateur ne sait pas décoder part **telle quelle** : le serveur tranche (BL-12).
  - `uploadImage(file, { url, onProgress })` : `XMLHttpRequest` (seul moyen de suivre la progression d'un envoi), `POST url`, `FormData` `article_image[file]`, en-têtes `X-CSRF-Token` (meta `csrf-token`) et `Accept: application/json`. Réponse **201** `{ public_id, sgid, url, width, height }` ; **422** `{ error }`, message français déjà rédigé par le serveur ; **403** `{ error: "forbidden" }` ; **401** `{ error: "unauthenticated" }` (session expirée pendant la rédaction, message `expired` ; *amendement du 2026-10-03*) ; toute autre réponse, une erreur réseau, un envoi sans réponse au bout de 60 s ou interrompu, est un échec (`failed`). *Contrat de réponse à figer dans l'ADR-0073 ; l'interface ne lit que ces champs.*
- **`rich-text-editor` en mode images** (`attachments: true`), dans `app/javascript/controllers/rich_text_editor_controller.js` :
  - `trix-file-accept` : un fichier déjà réduit par le contrôleur (marqué dans un `WeakSet`) passe. Sinon `preventDefault()`, puis, pour chaque fichier, dans l'ordre : type hors `accept` → refus `format` ; nombre d'images du texte déjà égal à `max-count` → refus `too_many` ; sinon réduction, poids réduit supérieur à `max-bytes` → refus `too_heavy` ; sinon le fichier réduit est marqué, puis inséré par `editor.insertFile(file)` à la position du curseur.
  - `trix-attachment-add` : pièce jointe avec `file` → envoi, `attachment.setUploadProgress(%)` pendant l'envoi (barre de progression de Trix), message `uploading` dans `status`, `aria-busy="true"` sur `#article_editor` ; à la réponse 201, `attachment.setAttributes({ sgid, url, width, height })` (sans `href`, une image n'est pas un lien), puis événement `rich-text-editor:uploaded` (`{ publicId, sgid, url }`). Refus ou échec → `attachment.remove()` et message dans `errors`. Pièce jointe **sans fichier** : avec un `sgid`, c'est une image de l'article (chargement, Annuler) → `rich-text-editor:attached` (`{ sgid }`) ; sans `sgid` (image collée depuis une page web, d'un autre hébergeur) → retirée, refus `web_image` (ADR-0049 : aucune image hébergée ailleurs).
  - `trix-attachment-remove` : `rich-text-editor:removed` (`{ sgid }`).
  - `pickImages()` ouvre `fileInput` ; `insertPicked()` passe ses fichiers par le même chemin que `trix-file-accept`, puis vide le champ.
  - **Envoi du formulaire pendant un envoi d'image** : au `connect`, le contrôleur écoute `submit` sur `this.element.closest("form")`. Tant qu'un envoi est en cours, `preventDefault()`, message `waiting` dans `status` (« Envoi des images en cours : l'article s'enregistrera ensuite. »), puis `form.requestSubmit(submitter)` à la fin de tous les envois, réussis ou non. `communication--cover-picker` fait de même pour la couverture. *Amendement du 2026-10-03 (phase 5, échec silencieux) : l'enregistrement ne part que si tous les envois attendus ont réussi ; sinon l'article n'est pas enregistré, la modale reste ouverte, le message `not_saved` s'ajoute au refus (`#article_body_upload_errors` ou `#article_cover_upload_error`, `tabindex="-1"`), qui prend le focus. Avant, l'article partait sans l'image et la modale fermée emportait le refus.*
  - Les messages ne sont jamais écrits en dur dans le JavaScript : ils viennent de `messages`, avec `%{name}` (nom du fichier d'origine), `%{reason}` (raison du serveur ou du client) et `%{number}` remplacés par le contrôleur.
- **Refus, mêmes raisons côté client et côté serveur** (clés `activemodel.errors.models.dtos/communication/article_image_input.attributes.file.*`, reprises dans `messages`) : format ; trop lourde (même allégée) ; trop grande (plus de `MAX_SIDE` px, serveur seul en pratique) ; pas une image lisible (serveur) ; nombre maximal atteint. Chaque refus s'affiche « « <nom> » n'a pas été ajoutée. <raison> » ; rien n'est stocké (BL-12).

#### 3.4.4 Données du contrôleur d'éditeur — `Communication::ArticleFormHelper`

`app/helpers/communication/article_form_helper.rb`, couvert à 100 % par `test/helpers/communication/article_form_helper_test.rb` : `article_editor_data(upload_url:)` renvoie le hash `data` de `#article_editor` :

| Attribut | Valeur |
|---|---|
| `data-rich-text-editor-lang-value` | `t("components.rich_text_editor.lang").to_json`, plus `captionPlaceholder` (« Ajoutez une légende… », clé `components.rich_text_editor.lang.captionPlaceholder`) |
| `data-rich-text-editor-attachments-value` | `true` |
| `data-rich-text-editor-upload-url-value` | `upload_url` |
| `data-rich-text-editor-accept-value` | `ArticleImage::CONTENT_TYPES.to_json` |
| `data-rich-text-editor-max-bytes-value` | `ArticleImage::MAX_BYTES` |
| `data-rich-text-editor-max-side-value` | `ArticleImage::MAX_SIDE` |
| `data-rich-text-editor-max-count-value` | `ArticleImage::MAX_PER_ARTICLE` |
| `data-rich-text-editor-messages-value` | JSON de `t("teams.articles.form.image_messages")`, plafonds interpolés (`number_to_human_size(MAX_BYTES)` → « 1 Mo ») |

La légende Trix (figcaption) reste permise : c'est un texte visible sous l'image, distinct du texte de remplacement, et facultatif.

### 3.5 Publication refusée

**Où** : dans la modale de modification, rouverte d'elle-même sur la liste, pas dans un toast.

**Structure**
- `Teams::ArticlesController#publish` : sur un échec `:invalid` du use case `PublishArticle` (titre, résumé ou texte manquants, couverture ou image du texte sans texte de remplacement), le contrôleur reconstruit `@form` depuis l'article enregistré, y ajoute les erreurs du résultat, et rend `publish_refused.turbo_stream.erb` en **422**.
- `publish_refused.turbo_stream.erb` = `turbo_stream.update "modal", partial: "teams/articles/edit_modal", locals: { article: @article, form: @form, refused: true }`, puis `turbo_stream.replace "article_<public_id>", method: :morph, …` (la ligne, toujours en brouillon, ou toujours archivée pour une remise en ligne). **Pas de toast** : la modale porte l'alerte, un toast d'erreur persistant la doublerait derrière le fond.
- En tête de la modale : `div#article_publish_refused.rounded-ln.bg-error-soft.px-4.py-3.text-sm.text-error[role=alert]`, avec l'icône `exclamation-triangle`, `p.font-semibold` `t(".refused_title")` (« Publication impossible »), `p` `t(".refused_body")` (« L'article reste dans son état. Complétez ce qui est signalé, enregistrez, puis publiez depuis le menu ⋮. »), puis `ul.list-disc.pl-5` avec une `li` par manque (les `full_messages` du `@form`, dans l'ordre du formulaire).
- Messages, sous chaque champ (BL-09, BL-13) : `title` « Indiquez le titre de l'article. » ; `excerpt` « Écrivez le résumé : il est obligatoire pour publier. » ; `body` « Écrivez le texte de l'article : il est obligatoire pour publier. » ; `cover_alt` « Décrivez la couverture : son texte de remplacement est obligatoire pour publier. » ; `image_alts.<public_id>` « Saisissez le texte de remplacement de l'image <n> : il est obligatoire pour publier. ». Le numéro est celui de l'ordre dans le texte, le même que celui du panneau.

**Comportement**
- La modale s'ouvre dès son arrivée (`open: true`) ; le contrôleur `autofocus` vise le premier `[aria-invalid="true"]` (UDR-0054 §3.3). Une image du texte en erreur a sa ligne visible, son badge « À compléter » et `aria-invalid`.
- L'auteur corrige et enregistre (`update`, §3.3) : l'article reste dans son état. Il publie ensuite par le menu ⋮. La modale ne publie jamais (décision 4).
- Repli sans Turbo : 303 vers `edit_teams_article_path` avec `alert` « Publication impossible : complétez l'article. ».

### 3.6 Aperçu

- Entrée du menu ⋮ « Aperçu » (brouillon, archivé) ou « Voir l'article » (publié), icône `eye`, `href: blog_article_path(slug)` : **visite Turbo dans le même onglet**, sans `frame:` ni `method:`. `ui_dropdown_item` n'a pas d'option d'ouverture dans un nouvel onglet, et l'on n'en ajoute pas.
- Ce que montre la page est régi par l'**UDR-0064** (§3.3 : bandeau `#article_status_banner` « Brouillon » ou « Archivé », `noindex`, retour « Blog » vers `blog_path`). L'UDR-0064 ne prévoit pas de lien vers la gestion : l'équipe revient à `/teams/blog` par le retour du navigateur, qui restaure la liste depuis le cache de Turbo. Ajouter « Gestion du blog » au bandeau serait un amendement de l'UDR-0064, pas de celle-ci.
- Le badge d'état de la liste de gestion garde les tons du catalogue (brouillon `warning`) ; le bandeau public de l'UDR-0064 est `neutral`. L'écart est voulu : la gestion signale un travail à finir, la page publique n'alerte personne.
- Un aperçu ne compte pas de lecture (BL-17, côté serveur).

### 3.7 Cours et fiches : l'éditeur reste sans image

- `rich_text_editor_controller.js` déclare `static values = { lang: Object, attachments: { type: Boolean, default: false }, uploadUrl: String, accept: Array, maxBytes: Number, maxSide: Number, maxCount: Number, messages: Object }`.
- **`attachments` faux (défaut)**, ou `uploadUrl` vide : comportement d'aujourd'hui, à l'identique : `trix-file-accept` → `preventDefault()`, `trix-attachment-add` → `attachment.remove()`, aucun `import` du module d'images, aucun bouton « Insérer une image ». `teams/courses/_form` et `teams/essentials/_form` ne changent pas (BL-15).
- Le mode images ne s'active **que** par la valeur posée par `article_editor_data` : aucune détection par l'URL ni par la présence d'un formulaire d'article.
- Le bouton de fichier de la barre d'outils de Trix reste caché pour tous (`application.tailwind.css`, inchangé) : le blog ajoute des images par son propre bouton, par glisser-déposer et par collage.
- `test/architecture/lazy_libraries_test.rb` reste vert : Trix et le module d'images ne sont chargés que par `import("…")` dynamique (`await import("trix")`, `await import("../lib/image_upload")`). Le nouveau module n'est importé statiquement par aucun fichier de `app/javascript`.
- Mettre à jour l'en-tête HITL du contrôleur (« Rôle : … ; images pour le blog seul, sur valeur `attachments` ») et le commentaire `V1 accepts no attachment`.

### 3.8 Locales et cibles Turbo

**Fichiers de locale**
- `config/locales/teams/articles.fr.yml` (nouveau) : `activemodel.attributes.dtos/communication/article_input.*` (`title` « Titre », `excerpt` « Résumé », `body` « Texte », `cover_public_id` « Image de couverture », `cover_alt` « Texte de remplacement de la couverture », `signature` « Signature », `image_alts` « Textes de remplacement ») ; `activemodel.errors.models.dtos/communication/article_input.attributes.*` (messages du §3.3 et du §3.5, `too_long` avec `%{count}`) ; `activemodel.errors.models.dtos/communication/article_image_input.attributes.file.*` (`blank`, `content_type`, `too_heavy`, `too_large`, `unreadable`, `too_many`) ; et `teams.articles.*` :
  - `index` : `page_title`, `title`, `subtitle`, `back`, `new_article`, `total` (`one`/`other`), `caption`, `columns.{article,status,date,reads,reads_note,actions}`, `reads_tip`, `empty_title`, `empty_description` ;
  - `article_row` : `actions`, `written_by`, `signed_team`, `signed_author`, `published_on`, `archived_on`, `updated_on`, `never_published` ;
  - `status.{draft,published,archived}` (« Brouillon », « Publié », « Archivé ») ; `menu.{edit,preview,view,publish,archive,republish}` ;
  - `new` : `title`, `draft_notice`, `submit` (« Créer le brouillon »), `cancel` ;
  - `edit_modal` : `title` (« Modifier l'article »), `status_notice`, `published_notice`, `submit` (« Enregistrer »), `cancel`, `refused_title`, `refused_body` ;
  - `form` : `title_placeholder`, `title_hint_new`, `title_hint_edit`, `excerpt_hint`, `excerpt_count`, `excerpt_near`, `excerpt_full`, `cover_legend`, `cover_placeholder`, `cover_file_label`, `cover_hint`, `cover_remove`, `cover_alt_hint`, `body_placeholder`, `body_hint`, `insert_image`, `images_title`, `images_intro`, `image_alt_label`, `image_alt_hint`, `image_alt_missing`, `signature_label`, `signature_team`, `signature_author`, `signature_hint`, `image_messages.{refused,format,too_heavy,too_many,web_image,forbidden,failed,expired,uploading,uploaded,waiting,not_saved}` ;
  - `create.created` ; `update.{updated,updated_live}` ; `transition.{published,republished,archived,conflict}` ; `publish.refused_fallback`.
- `config/locales/teams/homes.fr.yml` : ajout de `teams.homes.shortcuts.blog` (« Blog »).
- `config/locales/shared/components.fr.yml` : ajout de `components.rich_text_editor.lang.captionPlaceholder`.
- Textes de référence : `subtitle` « Les articles publics de Lnclass, du brouillon à l'archive. » ; `empty_title` « Aucun article pour l'instant » ; `empty_description` « Écrivez le premier : il reste en brouillon jusqu'à sa publication. » ; `reads_note` « sans dédoublonnage » ; `reads_tip` « Ouvertures de l'article publié, hors équipe, aperçus et robots déclarés. Sans cookie, un lecteur qui revient compte deux fois. » ; `draft_notice` « L'article est créé en brouillon ; il se publie ensuite depuis le menu ⋮ de la liste. » ; `status_notice` « L'état se change depuis le menu ⋮ de la liste, jamais dans ce formulaire. » ; `published_notice` « Cet article est en ligne : vos modifications seront visibles dès l'enregistrement. » ; `signature_hint` « Si le compte de l'auteur est désactivé, l'article sera signé « L'équipe Lnclass ». » ; `created` « Article « %{title} » créé (brouillon). » ; `published` « « %{title} » est publié : il est en ligne sur le blog. » ; `republished` « « %{title} » est de nouveau en ligne, à la même adresse. » ; `archived` « « %{title} » est archivé : son lien affiche « Cet article n'est plus disponible ». Vous pouvez le remettre en ligne. » ; `conflict` « « %{title} » a déjà changé d'état : la ligne montre son état actuel. ».
- Vocabulaire : « article », « brouillon », « publié », « archivé », « remettre en ligne », « texte de remplacement », « couverture ». Jamais « post », « billet », « alt » ni « supprimer » à l'écran. Vouvoiement, comme les pages publiques (memo, question 6). Les interdits de `test/i18n/locale_files_test.rb` s'appliquent.

**Ids et cibles**

| Id | Rôle | Remplacé par |
|---|---|---|
| `modal` (frame du layout) | modale de création, de modification, de publication refusée | `new`, `edit` ; `update "modal"` (vidée au succès, remplie par `publish_refused`) |
| `toasts` (layout) | toasts | `turbo_stream_toast` |
| `team_home_blog_shortcut` | raccourci de l'accueil | — |
| `teams_articles_new` | « Nouvel article » de l'en-tête | — |
| `teams_articles_total`, `teams_articles_list`, `teams_articles_empty` | compteur, corps du tableau, état vide | `turbo_stream.refresh` (morphing de la page) |
| `article_<public_id>` | ligne | `replace … method: :morph` (`transition`, `publish_refused`) |
| `article-actions-<public_id>` | menu ⋮ de la ligne | avec la ligne |
| `article_transitions_<public_id>` | entrées du menu (`div.contents`) | avec la ligne |
| `article-modal`, `article-form`, `article-submit` | modale, formulaire, bouton d'envoi | — |
| `article_base_error`, `article_publish_refused` | erreur générale, alerte de publication refusée | — |
| `article_title`, `article_excerpt`, `article_excerpt_count`, `article_cover_alt`, `article_signature` | champs (`form.field_id`) et compteur | — |
| `article_cover`, `article_cover_preview`, `article_cover_placeholder`, `article_cover_file`, `article_cover_file_hint`, `article_cover_remove`, `article_cover_status`, `article_cover_upload_error`, `article_cover_public_id` | couverture | — |
| `article_editor`, `article_body`, `article_body_label`, `article_insert_image`, `article_image_files`, `article_body_upload_errors`, `article_body_upload_status`, `article_body_hint`, `article_body_error` | texte et envoi d'images | — |
| `article_images`, `article_images_title`, `article_images_list`, `article_image_<public_id>`, `article_image_alts_<public_id>` (+ `_hint`, `_error`) | panneau des images | — |

**Contrôleurs Stimulus**
- `rich-text-editor` (modifié, §3.7), `communication--cover-picker`, `communication--image-alts`, `communication--character-count` (nouveaux, dans `app/javascript/controllers/communication/`, enregistrés par motif) ; module `app/javascript/lib/image_upload.js` (dynamique).
- Repris tels quels : `modal`, `dropdown`, `autofocus`, `info-tip`, `toast`.

### 3.9 Tokens

- Composants `ui_*` et tokens `@theme` seulement (UDR-0005) : `ink`, `mute`, `line`, `mist`, `paper`, `white`, `warning`/`warning-soft`, `error`/`error-soft`, `success`, `rounded-ln`, `rounded-sm`, `rounded-card`, `shadow-card`, `min-h-tap`, `sticky-actions`. Aucun `#hex`, aucune valeur entre crochets, aucun `style=`.
- `aspect-video`, `min-w-3xl`, `min-w-64`, `size-16` sont des utilitaires standard de Tailwind (tailles libres, UDR-0005).
- Aucun nouveau token, aucune règle CSS nouvelle : le bouton de fichier de Trix reste caché ; `.trix-content img` est déjà stylé (`h-auto max-w-full rounded-ln`).
- Les seules écritures de style du JavaScript passent par des classes de la palette (`text-warning`, `text-error` du compteur), listées en chaînes littérales dans le contrôleur pour que Tailwind les compile.

### 3.10 Vérification

- `test/system/teams/blog_management_test.rb` (Chrome), sous `assert_no_page_reload` et sans violation de CSP :
  1. un membre `content` voit le raccourci, ouvre la liste vide, crée un brouillon avec couverture et deux images du texte (réduites, envoyées, barre de progression), laisse un texte de remplacement vide, enregistre ; la ligne apparaît en tête ;
  2. il publie par le menu ⋮ : la modale s'ouvre en 422 sur l'image 2 en erreur (BL-13) ; il complète, enregistre, publie : le toast s'affiche, la ligne passe « Publié » ;
  3. il archive, puis remet en ligne ; l'aperçu mène à `blog_article_path` ;
  4. un GIF, un faux `.jpg` et une image trop lourde sont refusés avec leur raison (BL-12) ; une image collée depuis une page web est retirée ;
  5. à 390 px : pas de défilement horizontal, ⋮ visible au chargement.
- `test/system/teams/essential_management_test.rb` et le test des cours restent verts : un fichier inséré dans leur éditeur est toujours refusé (BL-15).
- `test/controllers/teams/articles_controller_test.rb` : 403 pour `field`, `teacher`, `student`, `school_admin` sur chaque route, base inchangée (BL-08) ; 422 de publication avec le champ nommé (BL-09) ; `test/controllers/teams/homes_controller_test.rb` : raccourci absent pour `field`, présent pour `admin` et `content`.
- `test/helpers/communication/article_status_helper_test.rb`, `article_form_helper_test.rb` : 100 % des lignes et des branches.
- `test/architecture/lazy_libraries_test.rb`, `test/design/design_tokens_test.rb`, `test/i18n/locale_files_test.rb`, `test/views/page_titles_test.rb` : verts. `bin/check-asset-budget` : le bundle commun reste sous 60 Ko gzip ; `image_upload` apparaît comme morceau « à la demande ».

## 4. Conséquences

- **UDR-0014 et UDR-0016** : la règle « l'éditeur refuse tout fichier » devient « l'éditeur refuse tout fichier, sauf s'il est posé avec `attachments: true`, ce que seul le blog fait ». Les cours et les fiches gardent leur éditeur en texte seul ; ouvrir les images à un autre contenu exige une nouvelle UDR et un ADR.
- **UDR-0018** : les raccourcis de l'accueil équipe gagnent « Blog » (`secondary`, `newspaper`, vers `teams_articles_path`), entre « Croissance » et « Inviter un membre », réservé à `admin` et `content`. C'est le seul accès à `/teams/blog` depuis l'interface.
- **UDR-0006** : inchangée, la navigation de l'équipe reste à 5 destinations.
- Le module `lib/image_upload.js` et le contrat `{ public_id, sgid, url }` de l'endpoint de l'équipe sont la seule voie d'envoi d'une image d'article. Tout futur envoi d'image (annonces, V6) les reprend plutôt que d'en écrire un autre.
- Un texte de remplacement s'écrit dans un champ à part, jamais dans la légende Trix.
- Interdits désormais :
  - un bouton de publication ou un choix d'état dans la modale ;
  - une suppression d'article ;
  - un rappel éditorial, une case d'accord ou une vérification portant sur le sujet d'un article (grill 4) ;
  - un compteur de lectures affiché sans sa mention « sans dédoublonnage » ;
  - un plafond d'image (poids, côté, nombre) écrit en dur dans une vue ou dans le JavaScript ;
  - une image envoyée par Active Storage direct upload ou servie par un tiers ;
  - un import statique de `trix` ou de `lib/image_upload` ;
  - un test du rôle dans une vue à la place de la policy.
- Ouvert : les plafonds chiffrés et le contrat exact de l'endpoint attendent l'ADR-0073. S'ils diffèrent du défaut proposé (1 Mo, 1 600 px, 10 images, 150 caractères), seules les constantes et les messages changent, pas cette interface.
