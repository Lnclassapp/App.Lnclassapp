# UDR-0113 : Pages publiques du catalogue — gabarit commun, liste des niveaux `/niveaux` et Espace Niveau `/niveaux/:slug`
<!-- index
titre: Pages publiques du catalogue : gabarit commun, liste des niveaux, Espace Niveau (CA-17)
statut: Proposé
adr-lie: [0099](../adr/0099-pages-publiques-du-catalogue-lues-sans-compte-indexees-sans-cache-html.md)
problematique: Gabarit des pages publiques du catalogue (en-tête de la homepage, appel à l'action selon la session, pied, balises), liste des niveaux par cycle, Espace Niveau : séries en pastilles, cours publiés groupés par matière dans l'ordre du programme, 6 cartes par matière puis « Voir les N cours ». Cartes sans lien. Points d'entrée : bande « Matières » de la homepage en liens, « Les cours par niveau » au pied (amende 0064, 0063 §3.4). Chantier `catalogue-complet`.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/catalogue-complet`](../../chantiers/catalogue-complet/memo.md) — questions 1, 3, 4, 6, 8, 12 du grill ; [PRD](../../chantiers/catalogue-complet/prd.md) CC-01 à CC-08, CC-19 à CC-22 |
| **ADR lié** | [ADR-0099](../adr/0099-pages-publiques-du-catalogue-lues-sans-compte-indexees-sans-cache-html.md) · [ADR-0067](../adr/0067-budgets-de-temps-serveur-des-ecrans.md) · [ADR-0090](../adr/0090-lecture-des-fiches-par-l-eleve-et-rang-des-matieres.md) (rang des matières) |
| **Amende** | [UDR-0064](0064-page-d-accueil-un-ecran-une-decision.md) (bande « Matières » en liens, §3.9) · [UDR-0063](0063-pages-publiques-mission-confidentialite-cgu-cgv.md) §3.4 (pied de la homepage : « Les cours par niveau », §3.9) |
| **Suit** | [UDR-0059](0059-homepage-telephone-et-tablette.md) (en-tête de la homepage) · [UDR-0066](0066-blog-public-liste-article-et-partage.md) §3.4 (balises de tête) · [UDR-0085](0085-page-cours-eleve-groupee-par-matiere-avec-bouton-d-avancement.md) (titre de groupe par matière, grille des cartes) · [UDR-0005](0005-design-system-fondateur.md) (tokens) |
| **Remplacé par** | — |

---

## 1. Contexte

Un visiteur qui se demande si Lnclass couvre « la Terminale » n'a rien à ouvrir : la homepage cite sept matières sans lien, et le catalogue demande un compte. Une personne connectée doit filtrer `/courses` pour voir un niveau. L'ancien « Espace Niveau » (CA-17) montrait les séries du niveau et un carrousel de cours, brouillons compris, aux seuls connectés.

## 2. Décision

- **Une page par niveau, lisible sans compte**, avec les séries du niveau en pastilles et ses cours publiés groupés par matière, dans l'ordre du programme (comme « Cours » de l'élève). Pas de carrousel : une grille qui défile verticalement, lisible au pouce.
- **Six cartes par matière au plus**, puis un lien « Voir les N cours » vers la page matière filtrée sur le niveau (UDR-0114). La page reste courte et son nombre de requêtes fixe ; la pagination vit sur la page matière.
- **Une carte n'est pas un lien** (ADR-0099 §4.1) : un seul appel à l'action par page, en tête et en pied.
- **Une liste `/niveaux`** sert d'entrée unique (pied de la homepage, plan du site) : deux sections, premier et second cycle.
- **Un gabarit commun** aux quatre pages publiques, défini ici et repris par les UDR-0114 et 0115.

## 3. Règles d'implémentation

### 3.1 Gabarit commun (Lot 0)

**Contrôleur parent** : `Catalog::PublicController < ApplicationController`, `allow_unauthenticated_access`, layout `application` (aucun shell), aucune redirection d'une personne connectée.

**Partials** dans `app/views/catalog/public/` :

| Partial | Locals | Contenu |
|---|---|---|
| `_header.html.erb` | — | Copie de l'en-tête de la homepage (UDR-0059) : `header.sticky.top-0.z-50.border-b.border-ink/10.bg-paper/90.backdrop-blur` > `nav.mx-auto.flex.h-bar.max-w-page.items-center.justify-between.gap-4.px-gutter` ; à gauche, logo et « Lnclass » vers `root_path` ; à droite, visiteur : `ui_button t("catalog.public.header.sign_in"), href: new_session_path, variant: :secondary, size: :sm, icon: "arrow-right-end-on-rectangle"` ; connecté : `ui_button t("catalog.public.header.my_space"), href: root_path, variant: :secondary, size: :sm, icon: "home"` |
| `_call_to_action.html.erb` | `id:` | `div#<id>.rounded-card.bg-brand-soft.p-5.text-center` : `p.font-display.text-lg.font-extrabold.text-ink` puis un `ui_button` plein. Visiteur : `t(".visitor_title")` (« Ces cours t'attendent sur Lnclass. ») et « Créer mon compte élève » → `new_student_registration_path`, puis `link_to "J'ai déjà un compte"` → `new_session_path` en `text-sm.font-medium.text-brand-strong`. Élève connecté : « Voir mes cours » → `courses_path`. Autre rôle connecté : « Ouvrir le catalogue » → `courses_path` |
| `_course_card.html.erb` | `card:` (`PublicCourses::Card`) | `li` > `article.h-full.rounded-card.border.border-line.bg-white.p-4.shadow-card` : `h3.font-display.text-base.font-bold.text-ink.text-balance` (nom) ; `p.mt-1.line-clamp-2.text-sm.text-mute` (description, omis si vide). **Aucun lien, aucun bouton, aucun statut** |
| `_material_group.html.erb` | `material:`, `count:`, `cards:`, `more_href:` (ou `nil`) | `section#group_<slug>` `aria-labelledby` ; titre : pastille `size-10.rounded-full` teintée par `subject_illustration(slug).tint` avec son image (`alt=""`), `h2.font-display.text-xl.font-extrabold` (nom complet), `ui_badge t("catalog.public.courses_count", count:), tone: :brand, size: :sm` ; le titre est un lien vers `public_material_path(slug, niveau: …)` ; grille `ul.mt-3.grid.grid-cols-1.gap-3.min-[700px]:grid-cols-2.lg:grid-cols-3` ; si `more_href`, `link_to` « Voir les N cours » (`t("catalog.public.see_all", count:)`), `min-h-tap.text-sm.font-bold.text-brand-strong`, sous la grille |
| `_head.html.erb` | `title:`, `description:`, `canonical:`, `index:` | Mêmes balises et même ordre que l'UDR-0066 §3.4 (`description`, `canonical`, `og:*` en `type` `website`, image `blog/partage.png`), par `tag.meta` et `tag.link` ; si `index` est faux, `tag.meta name: "robots", content: "noindex"` en premier |
| `_footer.html.erb` | — | `footer.border-t.border-ink/10` > liste `flex.flex-wrap.gap-6.text-sm.text-mute` : « Les cours par niveau » → `public_levels_path`, `blog_link` s'il existe, puis `public_page_links` (UDR-0063 §3.1) |

**Conteneur de page** : `catalog/public/_header`, puis `main#public_catalog.mx-auto.w-full.max-w-page.px-gutter.py-8` (pleine largeur jusqu'à 1 200 px, marge `px-gutter` de 16 px au téléphone), puis `_footer`.

**Fil d'Ariane** : `nav aria-label="Fil d'Ariane"` > `ol.flex.flex-wrap.gap-x-2.text-sm.text-mute` en tête de `main`, séparateur `ui_icon "chevron-right", variant: :mini` (`aria-hidden`). Dernier élément en `aria-current="page"`, sans lien.

### 3.2 Liste des niveaux — `catalog/level_pages/index.html.erb`

De haut en bas :

1. Fil d'Ariane : « Accueil » (`root_path`) › « Niveaux ».
2. `h1.font-display.text-3xl.font-extrabold` « Les cours par niveau » ; `p.mt-2.text-mute` « Du collège au lycée, le programme ivoirien sur Lnclass. »
3. Deux `section` : « Premier cycle » et « Second cycle » (`levels.cycle`), `h2.font-display.text-xl.font-extrabold`. Une section sans niveau listé n'est pas rendue.
4. Dans chaque section, `ul.grid.grid-cols-2.gap-3.sm:grid-cols-3.lg:grid-cols-4` ; un niveau = `li` > `link_to public_level_path(slug)`, `rounded-card.border.border-line.bg-white.p-4.shadow-card.min-h-tap.block`, nom en `font-display.text-lg.font-extrabold`, puis `text-sm.text-mute` « N cours » ; ses séries en `text-xs.text-mute` (« Séries A, C, D »), si elles existent.
5. `_call_to_action id: "levels_cta"`.

Un niveau **sans cours publié** n'est pas listé. Aucun niveau listé : `ui_empty_state title: "Les cours arrivent bientôt.", icon: "book-open"`, et `index: false`.

### 3.3 Espace Niveau — `catalog/level_pages/show.html.erb`

De haut en bas :

1. Fil d'Ariane : « Accueil » › « Niveaux » (`public_levels_path`) › nom du niveau.
2. `h1` : `t(".title", level: name)` → « Cours de Terminale » ; `p.mt-2.text-mute` : « N cours publiés, en M matières. »
3. **Séries** (si le niveau en a) : `nav aria-label="Séries"` > `ul.mt-4.flex.flex-wrap.gap-2` ; une pastille par série, `link_to public_level_series_path(level, series)`, `inline-flex.min-h-tap.items-center.rounded-full.border.border-line.bg-white.px-4.text-sm.font-bold.text-ink`, texte « Terminale D ». Une série sans cours publié propre **ni** cours commun du niveau n'est pas rendue.
4. `_call_to_action id: "level_cta_top"`, `mt-6`.
5. Les groupes : `div#level_groups.mt-8.space-y-8`, un `_material_group` par matière ayant au moins un cours publié du niveau, dans l'ordre de `materials.position` (vides en dernier, par nom). `cards` : les 6 premiers cours par nom ; `more_href` : `public_material_path(slug, niveau: level.slug)` si `count > 6`, sinon `nil`.
6. `_call_to_action id: "level_cta_bottom"`, `mt-10`.

**Niveau sans cours publié** : titres 1 et 2 (« Aucun cours publié pour l'instant. »), puis `ui_empty_state title: "Les cours de ce niveau arrivent bientôt.", icon: "book-open", action: { label: "Voir les autres niveaux", href: public_levels_path }` ; `index: false`. **Slug inconnu** : `render_not_found`.

### 3.4 Balises et titres d'onglet

| Page | `page_title` | `description` | `canonical` | `index` |
|---|---|---|---|---|
| `/niveaux` | « Les cours par niveau » | « Les cours de Lnclass de la 6e à la Terminale : choisissez un niveau. » | `canonical_url(public_levels_path)` | vrai si au moins un niveau listé |
| `/niveaux/:slug` | « Cours de Terminale » | « Les cours de Terminale sur Lnclass : Mathématiques, Physique-Chimie, … » (les trois premières matières, puis « … ») | `canonical_url(public_level_path(slug))` | vrai si au moins un cours |

### 3.5 Textes

Fichier `config/locales/catalog/public.fr.yml` (Lot 0) ; **tutoiement** dans l'appel à l'action (il s'adresse à l'élève, comme l'UDR-0085), vouvoiement nulle part ailleurs : les textes de page sont impersonnels. Vocabulaire de l'UDR-0007 : « cours », « matière », « niveau », « série » ; jamais « chapitre » ni « module ».

### 3.6 Comportement

- Aucun Turbo Frame, aucun contrôleur Stimulus : pages statiques, liens ordinaires (Turbo Drive par défaut, préchargement au survol conservé, ADR-0076).
- Aucune requête par carte : trois requêtes au plus (référentiel du niveau, comptes par matière, cartes limitées à 6 par matière par `ROW_NUMBER() OVER (PARTITION BY material_id)`).

### 3.7 États obligatoires

| État | Rendu |
|---|---|
| Nominal | §3.2, §3.3 |
| Vide | `ui_empty_state` ci-dessus, `noindex` |
| Inconnu | 404 (`errors/not_found`, inchangé) |
| Chargement, erreur réseau | Ceux du navigateur et de Turbo : aucune requête différée sur ces pages |

### 3.8 Accessibilité

- Un seul `h1` par page ; `h2` pour les sections et les matières, `h3` pour les cartes.
- Cibles tactiles ≥ 48 px (`min-h-tap`) : pastilles de série, titres de groupe, « Voir les N cours », boutons.
- Image de la matière décorative (`alt=""`, `aria-hidden`) : le nom est dans le `h2`.
- Focus visible : `focus-visible:outline-2 focus-visible:outline-brand` sur tous les liens personnalisés.
- À 390 px : aucune barre de défilement horizontale ; les pastilles de série passent à la ligne.

### 3.9 Points d'entrée sur la homepage (Lot D) — amende l'UDR-0064 et l'UDR-0063 §3.4

**Bande « Matières »** (`homepage/index.html.erb`, `section#matieres`, UDR-0064) : la liste écrite en dur `subjects` est remplacée par `@public_materials`, lu par `HomepageController#index` pour un visiteur seulement (`Queries::Catalog::HomepageMaterialsQuery` → `[[slug, name, category]]` des matières qui ont au moins un cours publié, ordre de `materials.position`, une requête). Chaque matière : `link_to public_material_path(slug), class: "inline-flex min-h-tap items-center rounded-full focus-visible:outline-2 focus-visible:outline-brand"` autour de `ui_subject_badge name, category:` (inchangé). Liste vide (aucun cours publié) : la liste écrite en dur actuelle, sans lien, reste rendue. Le titre `h2#matieres-title` ne change pas.

**Pied de page** (« Plus sur Lnclass », UDR-0063 §3.4, UDR-0066 §3.5) : `PublicPagesHelper#catalog_link` → `[t("public_pages.links.catalog"), public_levels_path]` si au moins un cours est publié, sinon `nil` (une requête par rendu, mémorisée comme `blog_link`). La liste devient `[catalog_link, blog_link, *public_page_links].compact`. Libellé : « Les cours par niveau ».

**Aucun autre point d'entrée** : ni la navigation du shell, ni les accueils connectés, ni `/aide`, ni la carte d'aide ne changent.

### 3.10 Vérification

Captures envoyées au porteur, non commitées : `/niveaux` et `/niveaux/tle` à 390 px et à 1 280 px, en visiteur et en élève connecté (appel à l'action différent) ; la homepage à 390 px avec la bande de matières en liens.

## 4. Conséquences

- Les pages publiques du catalogue ont leur gabarit propre, plus large que celui du blog (`max-w-page` contre `max-w-prose`) : une grille de cartes ne tient pas dans une colonne de lecture.
- Une carte publique ne mène nulle part : un futur sommaire public d'un cours (question 3 du grill) amendera `_course_card`.
- La navigation connectée (`NavigationHelper::DESTINATIONS`, shell) ne change pas : on n'entre sur ces pages que par la homepage, le plan du site, un lien partagé ou la page matière.
