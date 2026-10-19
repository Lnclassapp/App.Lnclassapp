# ADR-0099 : Les pages Niveau, Série et Matière se lisent sans compte, ne montrent que les titres des cours publiés, s'indexent en production et ne passent par aucun cache HTML
<!-- index
titre: Pages publiques du catalogue (niveau, série, matière) : lues sans compte, titres des cours publiés seulement, indexées en production, sans cache HTML
statut: Proposé — *amende 0035, 0074 ; confirme 0076 ; complète 0029, 0067*
problematique: Première lecture anonyme du catalogue (CA-17, CA-21, CA-23) : requêtes `Queries::Catalog::Public*` filtrées sur le publié en SQL, rien au-delà du nom et de la description d'un cours ; adresses françaises à slug figé ; plan du site étendu, `noindex` des pages vides ; aucun cache HTML partagé (ADR-0076), nombre fixe de requêtes. Chantier `catalogue-complet`.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/catalogue-complet`](../../chantiers/catalogue-complet/memo.md) — questions 1 à 8 du grill, en attente du porteur |
| **Amende** | [ADR-0035](./0035-cycle-de-vie-et-propriete-du-contenu.md) (lecture : titres des cours publiés lisibles par tous) · [ADR-0074](./0074-blog-public-articles-images-et-referencement.md) §4.6 (le plan du site gagne les pages du catalogue) |
| **Confirme** | [ADR-0076](./0076-politique-de-cache-reglee-sur-les-allers-retours.md) §4.1 (aucun HTML en cache partagé, même public) |
| **Complète** | [ADR-0029](./0029-identifiants-exposes-public-id-et-slugs.md) (slugs figés, adresses du contenu public) · [ADR-0067](./0067-budgets-de-temps-serveur-des-ecrans.md) (quatre écrans budgétés) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

La vague V4 doit livrer l'« Espace Niveau » (CA-17), la page matière (CA-21) et les pages des séries (CA-23). Dans l'ancienne application, les deux premières étaient réservées aux personnes connectées et montraient les brouillons ; les séries n'avaient de page que pour l'équipe, sans gabarit. La feuille de route les appelle « pages publiques du catalogue » ([§5, V2, « Sorti de la vague »](../../chantiers/refonte-application/feuille-de-route.md#v2--organisation-scolaire-et-espace-direction)).

Le catalogue connecté couvre déjà le besoin des personnes connectées : `/courses` filtre par niveau, série et matière (CA-02), pagine par 24 (CA-03), et l'élève a la vue de sa matière (UDR-0085). Ce qui manque est une **vitrine lisible sans compte**, que Google peut indexer et qu'un parent peut ouvrir depuis WhatsApp.

Quatre règles en vigueur s'y opposent ou la cadrent :

- **Aucune lecture anonyme du catalogue.** `Policies::Catalog::ReadPublishedPolicy` renvoie `:forbidden` pour un acteur `nil` ; les trois routes de `config/routes/catalog.rb` passent par `AuthenticatedController`.
- **L'élève ne lit que son niveau** (ADR-0035, second amendement du 2026-10-01) : 404 sur les cinq portes du contenu hors de son niveau.
- **Aucun HTML en cache partagé** (ADR-0076 §4.1, option B refusée) : les pages portent le cookie de session, le jeton CSRF et le nonce CSP.
- **Le référencement suit le modèle du blog** (ADR-0074 §4.6) : hôte canonique, plan du site, indexation de la production seule.

## 2. Moteurs de décision

1. **Aucune fuite** : ni brouillon, ni archivé, ni contenu (fiche, exercice, question) d'un cours, même par adresse forgée.
2. **Ne pas rouvrir l'ADR-0076** : le cache se règle sur les allers-retours, pas sur le calcul.
3. **Un nombre fixe de requêtes par page** (ADR-0067 : 100 ms serveur, 150 Ko de HTML).
4. **Réutiliser** : slugs figés du référentiel, `AudienceFilter` pour la règle des séries, mécanisme de pagination de CA-03, balises et plan du site du blog.
5. **Une seule page pour tous** : pas de variante par rôle à maintenir.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Pages réservées aux connectés, comme l'ancienne application | Aucune lecture anonyme à justifier | Elles doublent `/courses` (filtres livrés) et ne servent ni la vitrine ni Google, ce qui est la raison de les appeler « publiques » |
| **B — Pages lisibles sans compte, titres des cours publiés seulement, sans cache HTML** | Elles servent le visiteur, Google et la personne connectée ; elles n'exposent rien que la homepage ne pourrait dire | **Retenue** (recommandation, questions 1 à 4 et 7 du grill) |
| C — Comme B, avec cache HTML chez Cloudflare par un gabarit sans session (comme `/sitemap.xml`) | Elle retire l'aller-retour jusqu'au serveur pour les visiteurs | Elle exige un layout sans cookie ni jeton, donc sans « Se connecter » dynamique ni CSP à nonce, et une purge à chaque publication. Le trafic attendu ne le justifie pas encore ; à rouvrir sur mesure |
| D — Comme B, avec le sommaire public de chaque cours | Plus de texte à indexer | Une quatrième page et une frontière plus floue entre vitrine et contenu (question 3) ; chantier suivant si le porteur le veut |

## 4. Décision

> **Nous publions, sans compte, trois pages du catalogue — le niveau, le niveau et sa série, la matière — et la liste des niveaux. Elles ne montrent que des noms de niveaux, de séries et de matières, le nom et la description des cours publiés, et des nombres. Elles sont lues par des requêtes CQRS qui filtrent le publié en SQL, s'indexent en production seulement, et ne passent par aucun cache HTML.**

### 4.1 Ce qui est lisible sans compte

| Lisible | Jamais lisible |
|---|---|
| Nom, slug et cycle d'un niveau ; nom et slug de ses séries (`level_series`) | Un cours en brouillon ou archivé, même son titre |
| Nom, slug, catégorie et rang d'une matière | Une fiche, un exercice, une question, une réponse, un badge |
| Nom et description courte (`courses.subtitle`) d'un cours **publié** | Le statut d'un cours, sa date, son auteur |
| Le nombre de cours publiés d'un groupe | Toute donnée d'une personne (avancement, classe, établissement) |

**Amendement de l'ADR-0035** : les titres et descriptions des cours publiés sont lisibles par tous, connectés ou non, quel que soit le niveau de l'élève. La règle du second amendement du 2026-10-01 est inchangée pour le reste : le catalogue de l'élève (`/courses`) et les cinq portes du contenu (cours, fiche, exercice, session, résultat) restent limités à son niveau. Une carte publique n'est **pas un lien** vers la page du cours.

### 4.2 Lecture

- Aucune policy de domaine nouvelle : il n'y a ni acteur ni action. La règle tient dans la requête, comme `CourseCatalogQuery` hors équipe : `courses.status = 'published'`, en SQL, jamais par un filtre Ruby après coup.
- Un socle partagé, `Queries::Catalog::PublicCourses`, porte la portée publiée, la ligne de carte (`Card`) et l'ordre ; chaque page a sa requête (`PublicLevelsQuery`, `PublicSeriesQuery`, `PublicMaterialQuery`, `PublicSitemapQuery`, et `HomepageMaterialsQuery` pour la bande de la homepage), pour que les lots parallèles ne partagent aucun fichier.
- **Série** : la règle d'`AudienceFilter` vaut ici aussi — un cours sans série est commun à toutes les séries de son niveau.
- **Ordre** : matières par `materials.position` (vides en dernier, puis par nom ; ADR-0090), niveaux par `levels.position`, séries par nom, cours par nom puis `id`.
- Les contrôleurs héritent d'`ApplicationController` avec `allow_unauthenticated_access`, layout `application`, sans shell, et ne redirigent pas une personne connectée (comme le blog, BL-20). Le seul élément qui dépend de la personne est l'appel à l'action (« Créer mon compte élève » ou « Voir mes cours »).

### 4.3 Adresses

Françaises, comme `/mission` et `/blog`, à slug figé (ADR-0029, ADR-0034) :

| Adresse | Page | Nom de route |
|---|---|---|
| `GET /niveaux` | Liste des niveaux | `public_levels` |
| `GET /niveaux/:slug` | Espace Niveau (CA-17) | `public_level` |
| `GET /niveaux/:level_slug/:series_slug` | Niveau et série (CA-23) | `public_level_series` |
| `GET /matieres/:slug` (`?niveau=`, `?serie=`, `?page=`) | Page matière (CA-21) | `public_material` |

Slug inconnu, ou série non rattachée au niveau : `render_not_found` (404). `/courses` et ses routes ne changent pas.

### 4.4 Référencement (amendement de l'ADR-0074 §4.6)

- Le plan du site (`/sitemap.xml`) liste, après le blog, `/niveaux`, puis chaque niveau, chaque couple niveau × série et chaque matière **qui ont au moins un cours publié**, avec `lastmod` = le `updated_at` le plus récent de leurs cours publiés. Jamais une adresse avec `?page=`, `?niveau=` ou `?serie=`.
- Lien `canonical` par `canonical_url` (hôte canonique, jamais `request.host`) ; il garde `niveau` et `serie`, jamais `page`.
- Une page sans cours publié porte `<meta name="robots" content="noindex">`.
- L'indexation reste réservée aux hôtes de production (`config.x.indexed_hosts`, `X-Robots-Tag` d'`ApplicationController`), sans changement.

### 4.5 Cache (confirmation de l'ADR-0076)

Aucun `expires_in … public: true`, aucun fragment, aucun ETag sur ces pages : le HTML reste en `private, max-age=0, must-revalidate`. Un cours dépublié disparaît à la requête suivante. La vitesse se tient par un nombre fixe de requêtes : trois au plus par page (référentiel, comptes par groupe, cartes), sans requête par carte.

## 5. Conséquences

### 🟢 Positives

- Le visiteur voit ce que Lnclass couvre avant de créer un compte ; Google indexe le programme, niveau par niveau.
- Aucune donnée nouvelle, aucune migration, aucune policy : la sécurité tient dans un filtre SQL testé.
- Le catalogue connecté et la règle de l'élève ne changent pas.

### 🔴 Coûts consentis

- **Les titres de tous les niveaux deviennent publics**, y compris pour un élève qui ne peut pas ouvrir ces cours : une carte sans lien est le prix de cette frontière.
- **Chaque visite fait un aller-retour jusqu'au serveur** (250 à 360 ms depuis Abidjan) : l'option C est remise à plus tard.
- **Un titre mal écrit est public** dès la publication du cours : la relecture du contenu par l'équipe devient une relecture de vitrine.
- Quatre écrans de plus au budget de l'ADR-0067 et à `script/perf/audit_pages.rb`.

## 6. Notes d'implémentation

```ruby
# app/infrastructure/queries/catalog/public_courses.rb — Lot 0, socle partagé
module Queries
  module Catalog
    module PublicCourses
      Card = Data.define(:slug, :name, :subtitle, :material_slug, :level_slug)
      ORDER = [ Arel.sql("materials.position ASC NULLS LAST"), "materials.name", "courses.name", "courses.id" ].freeze

      # La seule portée lue par les pages publiques : jamais un brouillon ni un archivé (ADR-0099 §4.1).
      def self.scope = Orm::Course.joins(:level, :material).where(status: "published")
    end
  end
end
```

```ruby
# app/controllers/catalog/public_controller.rb — Lot 0, parent des trois pages
module Catalog
  class PublicController < ApplicationController
    allow_unauthenticated_access
  end
end
```

```ruby
# config/routes/catalog.rb — Lot 0
get "niveaux", to: "catalog/level_pages#index", as: :public_levels
get "niveaux/:slug", to: "catalog/level_pages#show", as: :public_level
get "niveaux/:level_slug/:series_slug", to: "catalog/series_pages#show", as: :public_level_series
get "matieres/:slug", to: "catalog/material_pages#show", as: :public_material
```

## 7. Comment vérifier que la décision est respectée

- `test/infrastructure/queries/catalog/public_*_query_test.rb` : un cours en brouillon et un cours archivé, de même niveau et même matière qu'un cours publié, n'apparaissent dans aucune requête ni dans aucun compte.
- `test/integration/catalog/public_level_pages_test.rb`, `public_series_pages_test.rb`, `public_material_pages_test.rb` : sans session, chaque page répond 200 ; le HTML ne contient ni le titre d'un brouillon, ni un lien vers `/courses/`, `/exercises/` ou une fiche ; `Cache-Control` ne contient pas `public` ; slug inconnu et série non rattachée : 404 ; page vide : `noindex`.
- `test/integration/communication/sitemaps_test.rb` : les pages du catalogue avec au moins un cours publié y sont, les vides et les adresses à paramètre n'y sont pas.
- `test/system/catalog/student_courses_test.rb` reste vert : la règle de l'élève est inchangée.
- `script/perf/audit_pages.rb` : les quatre pages sous 100 ms et 150 Ko, trois requêtes au plus.
