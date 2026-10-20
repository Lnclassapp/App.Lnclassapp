# UDR-0115 : Page publique d'un niveau et de sa série `/niveaux/:niveau/:serie` — « Terminale D », cours de la série et cours communs
<!-- index
titre: Page publique d'un niveau et de sa série (CA-23) : « Terminale D », cours de la série et cours communs du niveau, par matière
statut: Accepté
adr-lie: [0099](../adr/0099-pages-publiques-du-catalogue-lues-sans-compte-indexees-sans-cache-html.md)
problematique: Page série lisible sans compte, sous la forme niveau × série : pastilles des autres séries du niveau, cours publiés de la série et cours sans série du niveau groupés par matière, 6 par matière puis « Voir les N cours » vers la page matière (`?niveau=&serie=`). Gabarit et partials de l'UDR-0113. Chantier `catalogue-complet`.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-10-16) |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/catalogue-complet`](../../chantiers/catalogue-complet/memo.md) — questions 1, 3 à 5, 8, 12 du grill ; [PRD](../../chantiers/catalogue-complet/prd.md) CC-14 à CC-18 |
| **ADR lié** | [ADR-0099](../adr/0099-pages-publiques-du-catalogue-lues-sans-compte-indexees-sans-cache-html.md) · [ADR-0034](../adr/0034-reprise-des-donnees-et-referentiel-seede.md) (slugs des séries) |
| **Suit** | [UDR-0113](0113-pages-publiques-du-catalogue-gabarit-liste-des-niveaux-et-espace-niveau.md) (gabarit, `_material_group`, `_course_card`, appel à l'action) · [UDR-0114](0114-page-publique-d-une-matiere.md) (destination de « Voir les N cours ») · [UDR-0033](0033-gestion-des-series.md) (la liste des séries de l'équipe, inchangée) |
| **Remplacé par** | — |

---

## 1. Contexte

L'ancienne application avait des pages de série réservées à l'équipe, sans gabarit (CA-23, ❌). L'équipe a aujourd'hui sa liste et sa matrice niveau × série (`/teams/series`, UDR-0033). Ce qui manque est la page que cherchent un élève et un parent : on ne dit pas « la série D », on dit « la Terminale D ». Une série n'a de sens qu'à un niveau, et un cours sans série (la philosophie en Terminale, par exemple) vaut pour toutes les séries du niveau (règle d'`AudienceFilter`).

## 2. Décision

- **Une page par couple niveau × série rattaché** (`level_series`), à l'adresse `/niveaux/tle/d`, plutôt qu'une page par série tous niveaux confondus (question 5 du grill, recommandation).
- Elle montre **les cours de la série et les cours communs du niveau**, groupés par matière : exactement ce que verrait un élève de cette classe dans « Cours ».
- Même structure que l'Espace Niveau (UDR-0113 §3.3), pour qu'on passe de l'une à l'autre sans réapprendre : seuls le titre, les pastilles et la portée changent.

## 3. Règles d'implémentation

### 3.1 Contrôleur et données

`Catalog::SeriesPagesController < Catalog::PublicController`, action `show`. `Queries::Catalog::PublicSeriesQuery.new.call(level_slug: params[:level_slug], series_slug: params[:series_slug])` →

```ruby
Result = Data.define(:level, :series, :sibling_series, :groups, :total_count)
# level : slug, name ; series : slug, name ; sibling_series : [[slug, name]] des autres séries du niveau ayant au moins un cours
# groups : [[material, count, [Card]]] — 6 cartes au plus par matière, dans l'ordre de materials.position
```

- Niveau inconnu, série inconnue, ou couple absent de `level_series` : `render_not_found`.
- Portée : cours publiés du niveau dont `series_id` est celui de la série **ou** `NULL`.
- Trois requêtes au plus (référentiel, comptes par matière, cartes partitionnées par matière).

### 3.2 Page — `catalog/series_pages/show.html.erb`

Gabarit de l'UDR-0113 §3.1. De haut en bas :

1. Retour (UDR-0113 §3.1, amendé) : le nom du niveau, « Terminale » (`public_level_path`).
2. `h1.font-display.text-3xl.font-extrabold` : `t(".title", level:, series:)` → « Cours de Terminale D » ; `p.mt-2.text-mute` : « N cours publiés, en M matières, dont les cours communs à toutes les séries de Terminale. » (la seconde moitié seulement s'il existe au moins un cours sans série).
3. **Autres séries** (si `sibling_series` n'est pas vide) : `nav aria-label="Autres séries"` > `ul.mt-4.flex.flex-wrap.gap-2`, pastilles de l'UDR-0113 §3.3 point 3 ; la série courante est rendue en premier, active (`bg-brand.text-white.border-brand`, `aria-current="page"`, sans lien).
4. `_call_to_action id: "series_cta_top"`, `mt-6`.
5. `div#series_groups.mt-8.space-y-8` : un `catalog/public/_material_group` par matière, `more_href` = `public_material_path(material_slug, niveau: level.slug, serie: series.slug)` si `count > 6`. Le lien du titre de groupe vise la même adresse.
6. `_call_to_action id: "series_cta_bottom"`, `mt-10`.

Une carte n'indique pas si le cours est propre à la série ou commun : l'élève de Terminale D les voit pareils dans « Cours ».

### 3.3 Balises et titres d'onglet

| `page_title` | `description` | `canonical` | `index` |
|---|---|---|---|
| « Cours de Terminale D » | « Les cours de Terminale D sur Lnclass : Mathématiques, Physique-Chimie, … » | `canonical_url(public_level_series_path(level, series))` | vrai si `total_count > 0` |

### 3.4 États obligatoires

| État | Rendu |
|---|---|
| Nominal | §3.2 |
| Couple sans cours publié (ni propre, ni commun) | Titre et `ui_empty_state title: "Les cours de Terminale D arrivent bientôt.", icon: "book-open", action: { label: "Voir la Terminale", href: public_level_path(level) }` ; `noindex` ; la pastille de cette série n'apparaît pas sur l'Espace Niveau |
| Inconnu ou non rattaché | 404 |

### 3.5 Accessibilité

Celle de l'UDR-0113 §3.8. La pastille active n'est pas un lien (`span` avec `aria-current="page"`).

### 3.6 Vérification

Captures envoyées au porteur : `/niveaux/tle/d` à 390 px et à 1 280 px, avec au moins un cours commun (sans série) et un cours propre à la série.

## 4. Conséquences

- CA-23 est couverte sous une forme différente de l'ancienne : la liste des séries reste un écran de l'équipe (UDR-0033), la page publique est celle d'une classe-type.
- Un cours sans série apparaît sur chaque page série de son niveau : un titre de cours doit se comprendre sans la série.
- Si le porteur choisit la page par série tous niveaux (`/series/d`), cette UDR est réécrite avant le Lot C ; l'Espace Niveau ne change pas.
