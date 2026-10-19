# Plan d'exécution — Catalogue complet : pages publiques Niveau, Matière et Série

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
>
> **Condition d'entrée** : le porteur a répondu aux questions 1 à 7 et 12 du [memo](memo.md#ce-que-le-grill-a-révélé), validé les maquettes des trois pages, et ADR-0099, UDR-0113 à 0115 sont réécrites si une réponse diffère de la recommandation. Branche de chantier : `feature/catalogue-complet`, depuis `Develop` ; une seule PR.

## Graphe

```
Lot 0 — SOCLE (séquentiel, court)
  routes · locales · Catalog::PublicController · PublicCourses (portée, Card, ordre)
  partials communs catalog/public/* · clé du pied de la homepage
  ↓
  ├─► Lot A  Liste des niveaux + Espace Niveau   (CA-17)   ┐
  ├─► Lot B  Page matière, 24 par page            (CA-21)   ├─ en parallèle, fichiers disjoints
  ├─► Lot C  Page niveau × série                  (CA-23)   │
  └─► Lot D  Plan du site + points d'entrée homepage        ┘
```

Pas de lot pour CA-01, CA-02, CA-03 ni AS-01 : livrés ou couverts (inventaire du memo, questions 9 et 10). Leur fermeture est écrite dans la feuille de route au commit de clôture.

---

## Lot 0 — Socle

- **Couche**       : infrastructure (contrat de lecture) + delivery + ui (fichiers partagés)
- **Fichiers**     : `config/routes/catalog.rb` *(4 routes de l'ADR-0099 §4.3)*
                     `config/locales/catalog/public.fr.yml` *(toutes les clés des Lots A, B, C, gabarit compris)*
                     `config/locales/communication/public_pages.fr.yml` *(clé `links.catalog`, lue par le Lot D)*
                     `app/controllers/catalog/public_controller.rb`
                     `app/infrastructure/queries/catalog/public_courses.rb` *(`scope`, `Card`, `ORDER`, partition « 6 par matière »)*
                     `app/views/catalog/public/_header.html.erb`
                     `app/views/catalog/public/_footer.html.erb`
                     `app/views/catalog/public/_head.html.erb`
                     `app/views/catalog/public/_call_to_action.html.erb`
                     `app/views/catalog/public/_course_card.html.erb`
                     `app/views/catalog/public/_material_group.html.erb`
                     `test/infrastructure/queries/catalog/public_courses_test.rb`
- **Dépend de**    : — (après validation du porteur)
- **Test associé** : `test/infrastructure/queries/catalog/public_courses_test.rb` — un brouillon et un archivé ne sortent jamais de `scope` ; l'ordre suit `materials.position` puis le nom ; la partition garde 6 cours par matière
- **Done quand**   : les routes répondent (404 tant que les contrôleurs manquent n'est pas un échec, `bin/rails routes -g niveaux` les liste), `Card` et `scope` sont gelés, les partials se rendent dans un test de vue, et les Lots A à D démarrent sans toucher un fichier partagé

---

## Lot A — Liste des niveaux et Espace Niveau (CA-17)

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/catalog/public_levels_query.rb`
                     `app/controllers/catalog/level_pages_controller.rb`
                     `app/views/catalog/level_pages/index.html.erb`
                     `app/views/catalog/level_pages/show.html.erb`
                     `test/infrastructure/queries/catalog/public_levels_query_test.rb`
                     `test/integration/catalog/public_level_pages_test.rb`
                     `test/system/catalog/public_level_pages_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/integration/catalog/public_level_pages_test.rb` (CC-01 à CC-08, CC-19, CC-20 sur `/niveaux` et `/niveaux/:slug`) ; `test/system/catalog/public_level_pages_test.rb` (parcours visiteur à 390 px : `/niveaux` → `/niveaux/tle` → « Voir les N cours »)
- **Done quand**   : un visiteur sans compte ouvre `/niveaux`, choisit la Terminale, voit ses séries et ses cours publiés par matière dans l'ordre du programme, 6 au plus par matière, et l'appel à l'action ; aucun brouillon dans le HTML ; trois requêtes au plus ; captures envoyées au porteur (UDR-0113 §3.10)

---

## Lot B — Page matière (CA-21)

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/catalog/public_material_query.rb`
                     `app/controllers/catalog/material_pages_controller.rb`
                     `app/views/catalog/material_pages/show.html.erb`
                     `app/views/catalog/material_pages/_page.html.erb`
                     `app/views/catalog/material_pages/_page_frame.html.erb`
                     `test/infrastructure/queries/catalog/public_material_query_test.rb`
                     `test/integration/catalog/public_material_pages_test.rb`
                     `test/system/catalog/public_material_pages_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/integration/catalog/public_material_pages_test.rb` (CC-06, CC-09, CC-10, CC-12, CC-13, CC-17 côté destination, CC-20) ; `test/system/catalog/public_material_pages_test.rb` (CC-11 : 30 cours, la suite au défilement, titre de niveau non répété)
- **Done quand**   : `/matieres/mathematiques` montre les cours publiés par niveau avec les pastilles ; `?niveau=` et `?niveau=&serie=` filtrent et titrent ; la page suivante se charge au défilement et sans JavaScript ; adresses inconnues en 404 ; captures envoyées (UDR-0114 §3.7)

---

## Lot C — Page niveau × série (CA-23)

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/catalog/public_series_query.rb`
                     `app/controllers/catalog/series_pages_controller.rb`
                     `app/views/catalog/series_pages/show.html.erb`
                     `test/infrastructure/queries/catalog/public_series_query_test.rb`
                     `test/integration/catalog/public_series_pages_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/integration/catalog/public_series_pages_test.rb` (CC-14 à CC-18, CC-06, CC-20) ; `test/infrastructure/queries/catalog/public_series_query_test.rb` (cours sans série commun, série non rattachée)
- **Done quand**   : `/niveaux/tle/d` montre les cours de la série D et les cours sans série de Terminale, par matière, avec les autres séries en pastilles ; `/niveaux/6eme/d` répond 404 ; captures envoyées (UDR-0115 §3.6)

---

## Lot D — Plan du site et points d'entrée de la homepage

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/catalog/public_sitemap_query.rb`
                     `app/infrastructure/queries/catalog/homepage_materials_query.rb`
                     `app/controllers/communication/sitemaps_controller.rb`
                     `app/views/communication/sitemaps/show.xml.builder`
                     `app/controllers/homepage_controller.rb`
                     `app/views/homepage/index.html.erb`
                     `app/helpers/public_pages_helper.rb` *(`catalog_link`)*
                     `script/perf/audit_pages.rb` *(les quatre pages publiques, profil visiteur)*
                     `test/infrastructure/queries/catalog/public_sitemap_query_test.rb`
                     `test/infrastructure/queries/catalog/homepage_materials_query_test.rb`
                     `test/integration/communication/sitemaps_test.rb`
                     `test/system/homepage_test.rb`
- **Dépend de**    : Lot 0 *(les adresses existent dès le Lot 0 ; le plan du site ne lit que le référentiel et les cours publiés)*
- **Test associé** : `test/integration/communication/sitemaps_test.rb` (CC-21) ; `test/system/homepage_test.rb` (CC-22)
- **Done quand**   : `/sitemap.xml` liste `/niveaux`, les niveaux, les couples niveau × série et les matières qui ont un cours publié, sans adresse à paramètre ; la bande « Matières » de la homepage mène aux pages matière dans l'ordre du programme ; « Les cours par niveau » est au pied ; captures de la homepage à 390 px envoyées

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/catalog.rb` | Lot 0 |
| `config/locales/catalog/public.fr.yml` | Lot 0 |
| `config/locales/communication/public_pages.fr.yml` | Lot 0 |
| `app/controllers/catalog/public_controller.rb` | Lot 0 |
| `app/infrastructure/queries/catalog/public_courses.rb` | Lot 0 |
| `app/views/catalog/public/*` | Lot 0 |
| `app/infrastructure/queries/catalog/public_levels_query.rb`, `app/controllers/catalog/level_pages_controller.rb`, `app/views/catalog/level_pages/*` | Lot A |
| `app/infrastructure/queries/catalog/public_material_query.rb`, `app/controllers/catalog/material_pages_controller.rb`, `app/views/catalog/material_pages/*` | Lot B |
| `app/infrastructure/queries/catalog/public_series_query.rb`, `app/controllers/catalog/series_pages_controller.rb`, `app/views/catalog/series_pages/*` | Lot C |
| `app/controllers/communication/sitemaps_controller.rb`, `app/views/communication/sitemaps/show.xml.builder`, `app/controllers/homepage_controller.rb`, `app/views/homepage/index.html.erb`, `app/helpers/public_pages_helper.rb`, `script/perf/audit_pages.rb` | Lot D |
| `test/integration/communication/sitemaps_test.rb`, `test/system/homepage_test.rb` | Lot D |

Aucun fichier listé par deux lots parallèles. Aucune migration : `db/schema.rb` n'est pas touché. Aucun fichier de la V2 en cours (`school`, `identity`, shell) : chevauchement permis ([tableau de collision](../refonte-application/feuille-de-route.md#chevauchement-v2--v4--tableau-de-collision), ligne « Contexte `catalog` »). Seul `app/views/homepage/index.html.erb` est un écran partagé : vérifier, au lancement du Lot D, qu'aucun autre chantier ouvert ne le modifie.

## Portes de sortie

- [x] Lots 0, A, B, C, D `Done`
- [x] Un rôle distinct de l'auteur a **exécuté** le résultat *(agent de reprise, 2026-10-16 : sept pages en 200 et `private`, trois adresses inconnues en 404, `/sitemap.xml` lu en `public` une heure, aucun brouillon dans le HTML ; l'élève connecté (CC-19) par les tests d'intégration seulement)* : parcours visiteur refait dans l'application (homepage → matière → niveau → série → inscription), élève de Tle D connecté (CC-19), `curl -sI` de chaque page (pas de `public`), `/sitemap.xml` lu
- [ ] `bin/ci-quiet` au vert, écrit dans la PR (ADR-0069) ; pureté du domaine sans objet (aucun fichier `app/domain/`)
- [x] `script/perf/audit_pages.rb` : quatre pages < 100 ms, < 150 Ko, ≤ 3 requêtes du catalogue (CC-23), chiffres dans la PR
- [ ] Sous-agents de revue sur le diff final (route ajoutée) : `security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`
- [x] Captures 390 px et ordinateur envoyées au porteur pour les quatre pages et la homepage
- [x] Clôture : ADR-0099 et UDR-0113 à 0115 passées en « Accepté » si le porteur les accepte ; index régénérés par `script/docs/build_index` ; feuille de route §5 (V4) et §6 (CA-01, CA-02, CA-03, CA-17, CA-21, CA-23, AS-01) et `features-refonte.md` mis à jour ; `docs/chantiers/README.md` modifié une seule fois ; `journal.md` complété
