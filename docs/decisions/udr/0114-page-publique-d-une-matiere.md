# UDR-0114 : Page publique d'une matière `/matieres/:slug` — cours publiés groupés par niveau, filtre de niveau en pastilles, 24 par page
<!-- index
titre: Page publique d'une matière (CA-21) : cours publiés par niveau, pastilles de niveau, 24 par page chargées au défilement
statut: Proposé
adr-lie: [0099](../adr/0099-pages-publiques-du-catalogue-lues-sans-compte-indexees-sans-cache-html.md)
problematique: Page matière lisible sans compte : en-tête à l'icône de la matière, pastilles « Tous les niveaux » puis un niveau (`?niveau=`, `?serie=` repris de la page série), cours groupés par niveau dans l'ordre des niveaux, 24 cartes puis la suite au défilement (mécanisme de CA-03). Gabarit de l'UDR-0113. Chantier `catalogue-complet`.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/catalogue-complet`](../../chantiers/catalogue-complet/memo.md) — questions 1 à 4, 6, 8, 12 du grill ; [PRD](../../chantiers/catalogue-complet/prd.md) CC-09 à CC-13 |
| **ADR lié** | [ADR-0099](../adr/0099-pages-publiques-du-catalogue-lues-sans-compte-indexees-sans-cache-html.md) · [ADR-0076](../adr/0076-politique-de-cache-reglee-sur-les-allers-retours.md) §4.2 (frame différé hors de l'écran à l'arrivée) |
| **Suit** | [UDR-0113](0113-pages-publiques-du-catalogue-gabarit-liste-des-niveaux-et-espace-niveau.md) (gabarit, partials, textes) · [UDR-0013](0013-catalogue-et-page-cours.md), amendement du 2026-10-05 (pagination par frame différé) · [UDR-0085](0085-page-cours-eleve-groupee-par-matiere-avec-bouton-d-avancement.md) §3.1 (en-tête d'une matière) |
| **Remplacé par** | — |

---

## 1. Contexte

L'ancienne page matière (CA-21) montrait un carrousel « Mes Cours » aux connectés, brouillons compris, filtré sur le seul niveau de l'élève. Aujourd'hui, l'élève a la vue de sa matière à son niveau (`/courses?material=`, UDR-0085) ; personne d'autre n'a de page de matière, et rien n'est lisible sans compte. C'est pourtant l'entrée la plus naturelle depuis Google (« cours de physique-chimie 3e ») et depuis la bande « Matières » de la homepage.

## 2. Décision

- **Une page par matière, tous niveaux**, les cours groupés par niveau dans l'ordre des niveaux (6e → Terminale).
- **Un filtre de niveau en pastilles**, dans l'adresse (`?niveau=tle`), plutôt qu'une liste déroulante : 7 niveaux au plus, lisibles d'un coup d'œil au téléphone, et un lien partageable. C'est l'adresse que visent « Voir les N cours » de l'Espace Niveau (UDR-0113) et de la page série (UDR-0115, qui ajoute `?serie=`).
- **24 cartes, puis la suite au défilement**, le mécanisme livré pour CA-03 : une matière peut avoir plus de cent cours sur sept niveaux.
- Pas de recherche : la page est une vitrine courte par niveau ; la recherche reste dans le catalogue connecté.

## 3. Règles d'implémentation

### 3.1 Contrôleur et données

`Catalog::MaterialPagesController < Catalog::PublicController`, action `show`. Paramètres lus : `slug`, `niveau`, `serie`, `page` ; tout autre paramètre est ignoré. `Queries::Catalog::PublicMaterialQuery.new.call(slug:, level: params[:niveau], series: params[:serie], page: params[:page])` →

```ruby
Page = Data.define(:material, :levels, :selected_level, :selected_series, :groups, :total_count, :page, :pages)
# material : slug, name, category ; levels : [[slug, name, count]] des niveaux qui ont au moins un cours publié de la matière
# groups : [[level_slug, level_name, count, [Card]]] de la page demandée, dans l'ordre des niveaux
```

- Matière inconnue : `render_not_found`. `niveau` inconnu, ou sans cours de la matière : `render_not_found`. `serie` sans `niveau`, ou non rattachée au niveau : `render_not_found`.
- `serie` applique la règle d'`AudienceFilter` : cours de la série **et** cours sans série du niveau.
- Requête du frame de la page suivante (`turbo_frame_request_id` = `material_courses_page_<n>`) : `render partial: "page_frame"`, comme `Catalog::CoursesController`.

### 3.2 Page — `catalog/material_pages/show.html.erb`

Gabarit de l'UDR-0113 §3.1 (en-tête, `main#public_catalog`, pied). De haut en bas :

1. Fil d'Ariane : « Accueil » › « Niveaux » › nom de la matière (sans niveau) ; avec niveau : « Accueil » › « Niveaux » › niveau (lien `public_level_path`) › matière ; avec série : … › « Terminale D » (lien `public_level_series_path`) › matière.
2. En-tête de matière, repris de l'UDR-0085 §3.1 : `div#material_title.flex.items-center.gap-3` ; pastille `size-12.rounded-full` teintée (`subject_illustration(slug).tint`) avec son image `size-8`, `alt=""` ; `h1.font-display.text-2xl.font-extrabold.sm:text-3xl` : nom de la matière, suivi, si un niveau est choisi, de « en Terminale » ou « en Terminale D » (`t(".title_with_level", material:, level:)`).
3. `p.mt-2.text-mute` : « N cours publiés. »
4. **Pastilles de niveau** : `nav aria-label="Niveaux"` > `ul.mt-4.flex.flex-wrap.gap-2`. Première pastille « Tous les niveaux » → `public_material_path(slug)` ; puis une par niveau de `levels`, « Terminale · 12 » → `public_material_path(slug, niveau: level_slug)`. Pastille active : `bg-brand.text-white.border-brand` et `aria-current="page"` ; les autres : `border.border-line.bg-white.text-ink`. Toutes `inline-flex.min-h-tap.items-center.rounded-full.px-4.text-sm.font-bold`. Avec `serie`, la pastille du niveau est active et le lien « Tous les niveaux » enlève aussi la série.
5. `_call_to_action id: "material_cta_top"`, `mt-6`.
6. `div#material_groups.mt-8` > `render "page", page: @page` (§3.3).
7. `_call_to_action id: "material_cta_bottom"`, `mt-10`.

### 3.3 Pages de cartes — `_page.html.erb` et `_page_frame.html.erb`

- `_page` : pour chaque groupe, `section#level_group_<level_slug>` avec `h2.font-display.text-xl.font-extrabold` (nom du niveau) et `ui_badge` du nombre de cours du niveau dans la matière ; puis la grille de `catalog/public/_course_card` (UDR-0113 §3.1). Un groupe qui continue d'une page à la précédente ne répète pas son titre (`after_level`, comme `after_material` de l'UDR-0085 §3.2). Un niveau choisi : pas de titre de groupe, le `h1` le porte.
- Au bas de `_page`, s'il reste des pages : `turbo_frame_tag "material_courses_page_#{page + 1}", src: public_material_path(slug, niveau:, serie:, page: page + 1, after_level:), loading: :lazy, target: "_top"`, contenant le lien sans JavaScript « Afficher plus de cours » (`ui_button … variant: :secondary`) vers la même adresse. Le frame est hors de l'écran à l'arrivée (ADR-0076 §4.2).
- `_page_frame` : le frame demandé, avec `_page` en `nested: true`.

### 3.4 Balises et titres d'onglet

| Cas | `page_title` | `description` | `canonical` | `index` |
|---|---|---|---|---|
| Sans niveau | « Cours de Mathématiques » | « Les cours de Mathématiques sur Lnclass, de la 6e à la Terminale. » | `canonical_url(public_material_path(slug))` | vrai si `total_count > 0` |
| Niveau | « Mathématiques en Terminale » | « Les cours de Mathématiques en Terminale sur Lnclass. » | avec `niveau` | idem |
| Niveau et série | « Mathématiques en Terminale D » | idem, avec la série | avec `niveau` et `serie` | idem |

`page` n'entre jamais dans le `canonical`. Une page `?page=2` sans JavaScript garde le `canonical` de la page 1.

### 3.5 États obligatoires

| État | Rendu |
|---|---|
| Nominal | §3.2, §3.3 |
| Matière sans cours publié | En-tête, puis `ui_empty_state title: "Les cours de cette matière arrivent bientôt.", icon: "book-open", action: { label: "Voir les niveaux", href: public_levels_path }` ; pas de pastilles ; `noindex` |
| Inconnu (matière, niveau, série) | 404 |
| Chargement de la page suivante | `transition-opacity aria-busy:opacity-50` sur le frame, comme le catalogue |
| Erreur du frame | Le lien « Afficher plus de cours » reste dans le frame : il charge la page entière |

### 3.6 Accessibilité

- Pastilles : `nav` nommée, `aria-current="page"` sur l'active, cibles ≥ 48 px, à la ligne à 390 px.
- Le nombre de cours de chaque pastille est lu : « Terminale, 12 cours » par `aria-label` du lien.
- Un seul `h1` ; `h2` par niveau ; `h3` par carte.

### 3.7 Vérification

Captures envoyées au porteur : `/matieres/mathematiques` et `/matieres/mathematiques?niveau=tle` à 390 px et à 1 280 px, la page suivante chargée au défilement.

## 4. Conséquences

- La page matière est la seule page publique paginée : l'Espace Niveau et la page série s'arrêtent à 6 cartes par matière et y renvoient.
- La vue élève de sa matière (`/courses?material=`) ne change pas et reste distincte : avancement, recherche, niveau de l'élève seulement.
- La bande « Matières » de la homepage (Lot D) pointe ici.
