# Plan d'exécution — Blog de Lnclass

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Entrées : [`memo.md`](memo.md), [`prd.md`](prd.md) (21 critères BL-01 à BL-21), [ADR-0073](../../decisions/adr/0073-blog-public-articles-images-et-referencement.md), [UDR-0064](../../decisions/udr/0064-blog-public-liste-article-et-partage.md), [UDR-0065](../../decisions/udr/0065-gestion-du-blog-par-l-equipe.md).
> Contrat des use cases : `call` → `Shared::Result` (ADR-0026), policy injectée (`policy:`, ADR-0028), comme le code voisin (`UseCases::Catalog::PublishCourse`). `docs/blueprints/use_case.md` et `conventions.md` §8 sont périmés : ne pas les suivre.
> Couverture : 100 % des lignes et des branches (CI, ADR-0024). Chaque fichier `.rb` créé a son test **dans le même lot**.

## Préalables au Lot 0

- [x] ADR-0073, UDR-0064 et UDR-0065 `Accepté` (porteur, 2026-10-02, délégation ; passage de la phase 3 à la phase 4 sans nouvelle validation, `journal.md`).
- [ ] `git fetch origin Develop` puis fusion dans `feature/blog` si `Develop` a avancé (leçon du `journal.md` : référence `origin/Develop` périmée de 181 commits).
- [x] ImageMagick (`/usr/bin/convert`) présent dans le conteneur : l'image par défaut de partage se fabrique à partir du logo de l'équipe, sans le redessiner.

## Graphe

```
Lot 0 — SOCLE (séquentiel, sur feature/blog)
  0.1 renommages purs : ContentStatus, ImageHeader, RichTextSanitizer → shared (iso-comportement)
  0.2 migration · Orm:: · entités · audit · policies · DTO · ports ET leurs adaptateurs
      routes · canonical_host · locales · helpers partagés · fabriques · image de partage · docs
  ↓
  ├─► Lot A « L'équipe rédige, publie, archive, remet en ligne »       ┐
  ├─► Lot B « Une image d'article s'envoie, se sert, se purge »        ├─ vague 2, en parallèle,
  ├─► Lot D « Un visiteur lit le blog » (+ compteur, liens « Blog »)   │  fichiers disjoints
  └─► Lot E « Plan du site et robots.txt »                             ┘
        A + B + D fusionnés
          ↓
        Lot F « L'éditeur du blog insère des images » (JS) + parcours système complet   ← vague 3
```

**Écart à la proposition de découpage, justifié par les fichiers :**

1. **Le Lot C « publier / archiver / remettre en ligne » est fusionné dans le Lot A.** Les routes gelées par l'ADR-0073 §6 et l'UDR-0065 §3.0 mettent `publish` et `archive` dans `Teams::ArticlesController`, qui porte aussi `index`, `new`, `create`, `edit`, `update`. La publication refusée rouvre `_edit_modal` et re-rend `_article_row` (UDR-0065 §3.5) : C toucherait le contrôleur, la ligne et la modale de A. Un contrôleur ne se coupe pas en deux lots ; un C séquentiel après A listerait les mêmes fichiers. A devient le chemin nominal A du PRD, entier.
2. **Les images sont coupées en deux lots : B (serveur) et F (navigateur).** Le JavaScript de l'éditeur, de la couverture et du panneau des textes de remplacement (UDR-0065 §3.4) se branche sur le balisage du formulaire de A ; il n'est démontrable qu'une fois A fusionné, et son test système passe par l'aperçu public de D. B garde tout ce qui se prouve sans navigateur : l'endpoint d'envoi, le service public `/blog/images/:public_id` et la purge des orphelines.
3. **Les deux adaptateurs (`ArticleRepository`, `ArticleImageStore`) sont au Lot 0, avec leurs ports.** `test/architecture/port_contracts_test.rb` exige exactement un adaptateur par port à tout instant : un port gelé sans adaptateur casse `bin/ci` dès le Lot 0 (leçon du plan `gestion-etablissement-direction`, règle gelée 4). Et `ArticleRepository` est lu par A (écrire, transitions), B (images citées d'un article) et D (`increment_reads`) : un seul fichier, trois lots.
4. **Le Lot 0 dépasse « une poignée de fichiers ».** C'est voulu et borné : l'ADR-0073 §5 impose les trois déplacements « en un commit de pur renommage, au Lot 0 » (≈ 30 fichiers à une ligne chacun), et chaque autre fichier y est parce qu'au moins deux lots le lisent ou parce que `port_contracts_test` l'exige. Aucun use case, aucun contrôleur, aucune vue n'y est.

**Règles gelées.**

1. Les lots A, B, D, E, F **implémentent** les contrats du Lot 0 ; aucun ne change un port, un adaptateur, une entité, une policy, un DTO, une route, une locale, un helper partagé ou une fabrique. Un lot qui en a besoin **s'arrête** : le Lot 0 rouvre.
2. Aucun lot vertical n'ajoute de fabrique dans `test/support/factories/` : ses aides de test vivent dans son fichier de test.
3. Aucun lot vertical n'écrit dans `docs/` : il remonte ses notes au porteur du chantier, qui tient `journal.md`.
4. Toutes les locales sont au Lot 0 (`conventions.md` §6, règle 1) : leurs clés et leurs textes sont fixés par l'UDR-0064 §3.6 et l'UDR-0065 §3.8. Une clé manquante arrête le lot.

---

## Lot 0 — Socle

- **Couche**       : domaine (entités, policies, DTO, ports — contrats gelés) + infrastructure (migration, `Orm::`, adaptateurs, assainisseur) + delivery (routes, helpers partagés) + config + locales + docs
- **Fichiers**     : *Étape 0.1 — renommages purs, un commit `refactor(shared)`, aucune ligne de logique changée (ADR-0073 §4.2, §4.4, §4.5, §5)*
                     app/domain/entities/catalog/content_status.rb *(supprimé : déplacé dans shared)*
                     app/domain/entities/shared/content_status.rb
                     app/domain/entities/catalog/course.rb
                     app/domain/entities/catalog/essential.rb
                     app/domain/entities/assessment/exercise.rb
                     app/domain/use_cases/catalog/publish_course.rb
                     app/domain/use_cases/catalog/archive_course.rb
                     app/domain/use_cases/catalog/publish_essential.rb
                     app/domain/use_cases/catalog/archive_essential.rb
                     app/domain/use_cases/assessment/publish_exercise.rb
                     app/domain/use_cases/assessment/archive_exercise.rb
                     app/helpers/catalog/content_status_helper.rb
                     test/helpers/catalog/content_status_helper_test.rb
                     test/domain/entities/catalog/content_status_test.rb *(supprimé : déplacé, voir Test associé)*
                     app/domain/entities/identity/image_header.rb *(supprimé : déplacé dans shared)*
                     app/domain/entities/shared/image_header.rb
                     app/domain/dtos/identity/profile_photo_input.rb
                     test/domain/entities/identity/image_header_test.rb *(supprimé : déplacé, voir Test associé)*
                     test/domain/dtos/identity/profile_photo_input_test.rb
                     test/domain/use_cases/identity/change_own_photo_test.rb
                     test/controllers/identity/profile_photos_controller_test.rb
                     test/system/identity/profile_photo_test.rb
                     app/infrastructure/repositories/catalog/rich_text_sanitizer.rb *(supprimé : déplacé dans shared)*
                     app/infrastructure/repositories/shared/rich_text_sanitizer.rb *(déplacé en 0.1 ; `image_ids:` et `ArticleScrubber` ajoutés en 0.2)*
                     app/infrastructure/repositories/catalog/course_repository.rb
                     app/infrastructure/repositories/catalog/essential_repository.rb
                     app/infrastructure/repositories/catalog/content_tree_writer.rb
                     test/infrastructure/repositories/catalog/rich_text_sanitizer_test.rb *(supprimé : déplacé, voir Test associé)*
                     test/infrastructure/repositories/catalog/content_tree_writer_test.rb
                     test/system/catalog/course_catalog_test.rb *(commentaire seulement)*
                     script/bench/import_course_tree.rb
                     *Étape 0.2 — socle du blog*
                     db/migrate/20261004090000_create_articles.rb *(tables `articles` et `article_images`, contraintes du §4.1, FK croisées posées après les deux tables)*
                     db/schema.rb
                     app/infrastructure/orm/article.rb
                     app/infrastructure/orm/article_image.rb
                     app/domain/entities/communication/article.rb
                     app/domain/entities/communication/article_image.rb
                     app/domain/entities/communication/article_read.rb
                     app/domain/entities/identity/audit_action.rb
                     app/domain/policies/communication/manage_articles_policy.rb
                     app/domain/policies/communication/read_article_policy.rb
                     app/domain/dtos/communication/article_input.rb
                     app/domain/dtos/communication/article_image_input.rb
                     app/domain/ports/communication/article_repository_port.rb
                     app/domain/ports/communication/article_image_store_port.rb
                     app/infrastructure/repositories/communication/article_repository.rb
                     app/infrastructure/repositories/communication/article_image_store.rb
                     app/helpers/communication/articles_helper.rb
                     app/helpers/communication/article_status_helper.rb
                     config/routes/communication.rb
                     config/routes/teams.rb
                     config/application.rb
                     config/locales/communication/articles.fr.yml *(nouveau, UDR-0064 §3.6)*
                     config/locales/teams/articles.fr.yml *(nouveau, UDR-0065 §3.8)*
                     config/locales/teams/homes.fr.yml
                     config/locales/shared/components.fr.yml
                     config/locales/communication/public_pages.fr.yml
                     config/locales/shared/help_sheet.fr.yml
                     config/locales/homepage/index.fr.yml
                     app/assets/images/blog/partage.png *(1200 × 630, ≤ 150 Ko : le logo de l'équipe centré sur le fond `brand`)*
                     test/support/factories/communication.rb
                     test/fixtures/files/article_images/animation.gif
                     test/fixtures/files/article_images/animated.webp
                     test/fixtures/files/article_images/fake.jpg
                     docs/guide/glossaire.md *(article ≠ annonce)*
                     docs/guide/configuration.md *(`CANONICAL_HOST`, à inscrire aussi dans `APP_HOSTS`)*
                     docs/decisions/adr/0027-contextes-bornes-et-arborescence.md · 0029-identifiants-exposes-public-id-et-slugs.md · 0038-comptes-de-l-equipe-et-sous-roles.md · 0047-stockage-objet-s3-sur-railway.md · 0051-navigateurs-supportes-et-budget-de-poids.md · README.md *(mentions « amendé par 0073 »)*
                     docs/decisions/udr/0014-formulaire-cours.md · 0016-formulaire-fiche-essentielle.md · 0018-accueil-equipe.md · 0061-carte-d-aide-et-faq.md · 0063-pages-publiques-mission-confidentialite-cgu-cgv.md · README.md *(sections « Amendement » que l'UDR-0064 et l'UDR-0065 demandent au chantier)*
- **Dépend de**    : — (préalables ci-dessus)
- **Test associé** : test/domain/entities/shared/content_status_test.rb *(déplacé, assertions inchangées)*
                     test/domain/entities/shared/image_header_test.rb *(déplacé, assertions inchangées)*
                     test/infrastructure/repositories/shared/rich_text_sanitizer_test.rb *(déplacé ; ajouts du §7 de l'ADR : sans `image_ids` toute pièce jointe part et un `h1` reste — BL-15 ; avec, seule une image admise reste, sans `url` ni `href`, `h1` → `h2` — BL-02 ; `sgid` d'un autre article ou d'un autre modèle, image distante, `<script>`, `onerror`, `javascript:` partent — BL-16 ; test d'architecture : seul l'adaptateur des articles passe `image_ids:`)*
                     test/db/schema_constraints_test.rb *(`articles` dans `PUBLIC_ID_TABLES` et `SLUG_TABLES`, `article_images` dans `PUBLIC_ID_TABLES` ; refus de `status = 'publié'`, `signature = 'x'`, publié sans résumé, archivé sans `archived_at`, 1601 px, `image/gif` ; FK `restrict`)*
                     test/infrastructure/orm/models_test.rb *(les deux tables ont leur modèle `Orm::`)*
                     test/infrastructure/orm/article_image_test.rb *(nouveau : `to_attachable_partial_path`, résolution par `sgid` ; `Orm::Article#body.to_trix_html` rend une image citée sans partiel manquant — sinon la modale d'édition de A casse)*
                     test/domain/entities/communication/article_test.rb *(`TRANSITIONS` = celles de `ContentStatus` ; règles de complétude de la publication : `title`, `excerpt`, `body`, `cover_alt`, `image_alts.<public_id>`, 10 images au plus — BL-09, BL-13)*
                     test/domain/entities/communication/article_image_test.rb *(constantes 1 Mo, 1600, 10, 150)*
                     test/domain/entities/communication/article_read_test.rb *(robot qui se déclare, `Sec-Purpose`, `X-Sec-Purpose`, `Purpose` — BL-17)*
                     test/domain/entities/identity/audit_action_test.rb *(`article.created`, `article.updated`, `article.published`, `article.archived`)*
                     test/domain/policies/communication/manage_articles_policy_test.rb *(admin et content passent ; field, teacher, student, school_admin, nil → `:forbidden` — BL-07, BL-08)*
                     test/domain/policies/communication/read_article_policy_test.rb *(brouillon → `:not_found`, archivé → `:expired` pour les cinq acteurs ; tout état → succès pour admin et content — BL-04, BL-05)*
                     test/domain/dtos/communication/article_input_test.rb *(plafonds 120, 200, 100 000 ; signature)*
                     test/domain/dtos/communication/article_image_input_test.rb *(faux `.jpg`, GIF, WebP animé, 1 Mo + 1 octet, 1601 px refusés ; Exif retiré — BL-12)*
                     test/infrastructure/repositories/communication/article_repository_test.rb *(slug figé, `-2`, réessai sur `RecordNotUnique` — BL-10 ; `published_at` gardé à la remise en ligne — BL-11 ; rattache couverture et images citées, supprime une image retirée, jamais une citée ; `increment_reads` = une requête, sans effet sur un brouillon ni sur `updated_at` — BL-17 ; HTML assaini à l'écriture — BL-16)*
                     test/infrastructure/repositories/communication/article_image_store_test.rb *(stockage `analyzed: true`, lecture, purge des orphelines de plus de 48 h)*
                     test/helpers/communication/articles_helper_test.rb *(`article_image_src`, `canonical_url` sur `config.x.canonical_host` = `lnclass.com` par défaut, `article_date` → « 5 octobre 2026 » — BL-03)*
                     test/helpers/communication/article_status_helper_test.rb *(badge et entrées du menu ⋮ par état, 100 % des branches)*
                     test/routing/blog_routes_test.rb *(nouveau : les noms des routes de l'ADR-0073 §6 et de l'UDR-0065 §3.0 ; `/teams/blog/images` et `/teams/blog/new` ne sont pas capturés par `:public_id`, `/blog/images/x` pas par `:slug`)*
                     test/support/factories_test.rb *(`create_article`, `create_article_image` écrivent une ligne valide avec leurs défauts)*
- **Done quand**   : `bin/rails db:migrate`, `db:rollback`, `db:migrate` passent ; `bin/rails routes -g blog` montre `blog`, `blog_article`, `blog_image`, `sitemap`, `robots`, `teams_articles`, `new_teams_article`, `edit_teams_article`, `teams_article`, `publish_teams_article`, `archive_teams_article`, `teams_article_images` ; dans `bin/rails console`, `Repositories::Communication::ArticleRepository` crée un brouillon dont le slug suit le titre, et deux titres identiques donnent `-2` ; un cours, une fiche, un exercice se publient et une photo de profil s'envoie exactement comme avant (tests existants verts sans changement d'assertion) ; `bin/ci` au vert

**Contrats gelés par le Lot 0** (signatures proposées par le plan, figées par le Lot 0 ; elles font foi pour A, B, D, E, F) :

- `Entities::Communication::Article` : `TITLE_MAX` (120), `EXCERPT_MAX` (200), `BODY_MAX` (100 000), `SIGNATURES` (`team`, `author`), `TRANSITIONS` (= `Entities::Shared::ContentStatus::TRANSITIONS`), et la règle de complétude qui rend les erreurs nommées par champ (`title`, `excerpt`, `body`, `cover_alt`, `:"image_alts.<public_id>"`), lue par la publication et par l'enregistrement d'un article publié (ADR-0073 §4.2).
- `Entities::Communication::ArticleImage` : `CONTENT_TYPES`, `MAX_BYTES`, `MAX_MEGABYTES`, `MAX_SIDE`, `MAX_PER_ARTICLE`, `ALT_MAX`. `Entities::Communication::ArticleRead.countable?` (motif des robots, en-têtes de préchargement).
- `Ports::Communication::ArticleRepositoryPort` : `find_by_public_id(public_id:)` → `Article` (avec sa couverture et ses images citées, dans l'ordre du texte) ou `nil` ; `create(dto:, author_id:, at:)` ; `update(id:, dto:, at:)` (assainit, rattache, purge, dans la transaction) ; `transition(id:, to:, at:)` (`published_at = COALESCE`, `archived_at`) ; `increment_reads(article_id:)` → Boolean (ADR-0073 §6).
- `Ports::Communication::ArticleImageStorePort` : `store(data:, content_type:, width:, height:)` → `StoredImage(public_id, sgid, width, height)` ; `read(public_id:)` → `ServedImage(content_type, data, article_status)` (`article_status` `nil` si non rattachée) ou `nil` ; `purge_orphans(before:)` → nombre purgé.
- `Dtos::Communication::ArticleInput` (avec `images`, liste ordonnée de `public_id`, `sgid`, `url`, `alt` ; UDR-0065 §3.0) et `Dtos::Communication::ArticleImageInput` (calqué sur `ProfilePhotoInput`, lit `Entities::Shared::ImageHeader`).
- Helpers : `Communication::ArticlesHelper#article_image_src(image)`, `#canonical_url(path)`, `#article_date(date)` ; `Communication::ArticleStatusHelper#article_status_badge(status)`, `#article_menu_items(article:)`.
- Fabriques : `create_article(author:, status:, title:, excerpt:, body:, signature:, cover:, published_at:, archived_at:)`, `create_article_image(article:, alt:, fixture:, created_at:)`, `article_body_with(*images, text:)` (HTML Action Text qui cite les images par `sgid`). Elles passent par `Orm::` et l'adaptateur des images, comme `attach_photo`.
- `Orm::ArticleImage#to_attachable_partial_path` vise un partiel livré par D : aucun test du Lot 0 ne rend `body.to_s` (rendu public) ; seul le rendu de l'éditeur (`to_trix_html`) y est vérifié.

Routes dessinées avant leurs contrôleurs : jusqu'à la fusion de A, B, D, E, elles répondent par une erreur de chargement, comme au plan `boucle-pedagogique` (`test/routing/v1_routes_test.rb` : « most are not merged yet »). Le layout `application` n'est pas modifié : il rend déjà `yield :head`.

---

## Lot A — L'équipe rédige, publie, archive, remet en ligne

- **Couche**       : domaine (use cases) + infrastructure (queries) + delivery + ui
- **Fichiers**     : app/domain/use_cases/communication/create_article.rb
                     app/domain/use_cases/communication/update_article.rb
                     app/domain/use_cases/communication/publish_article.rb
                     app/domain/use_cases/communication/archive_article.rb
                     app/infrastructure/queries/communication/team_articles_query.rb
                     app/infrastructure/queries/communication/article_form_images_query.rb
                     app/controllers/teams/articles_controller.rb
                     app/controllers/teams/homes_controller.rb
                     app/helpers/communication/article_form_helper.rb
                     app/views/teams/articles/index.html.erb
                     app/views/teams/articles/_article_row.html.erb
                     app/views/teams/articles/new.html.erb
                     app/views/teams/articles/edit.html.erb
                     app/views/teams/articles/_edit_modal.html.erb
                     app/views/teams/articles/_form.html.erb
                     app/views/teams/articles/_image_alt_row.html.erb
                     app/views/teams/articles/create.turbo_stream.erb
                     app/views/teams/articles/update.turbo_stream.erb
                     app/views/teams/articles/transition.turbo_stream.erb
                     app/views/teams/articles/publish_refused.turbo_stream.erb
                     app/views/teams/homes/show.html.erb
                     app/views/teams/homes/_shortcuts.html.erb
                     app/javascript/controllers/communication/character_count_controller.js
- **Dépend de**    : Lot 0
- **Test associé** : test/domain/use_cases/communication/create_article_test.rb *(brouillon créé, `article.created` au journal ; refus → rien d'écrit — BL-07, BL-08)*
                     test/domain/use_cases/communication/update_article_test.rb *(`article.updated` ; un article publié dont on vide le résumé → `:invalid` — ADR-0073 §4.2)*
                     test/domain/use_cases/communication/publish_article_test.rb *(sans résumé → `:invalid` nommant `excerpt`, reste brouillon — BL-09 ; image sans texte de remplacement → `image_alts.<public_id>` — BL-13 ; remise en ligne garde `published_at` — BL-11 ; `article.published` avec `metadata.republished` — BL-07)*
                     test/domain/use_cases/communication/archive_article_test.rb *(`article.archived` ; transition interdite → `:conflict`)*
                     test/infrastructure/queries/communication/team_articles_query_test.rb *(tous les états, tri par dernière modification, 20 par page, `reads_count` — BL-17)*
                     test/infrastructure/queries/communication/article_form_images_query_test.rb *(images du texte dans l'ordre, avec `sgid`, `url` et `alt`, reconstruites depuis un `body` et des `image_alts`)*
                     test/controllers/teams/articles_controller_test.rb *(403 pour field, teacher, student, school_admin sur chaque route, base inchangée ; visiteur renvoyé à la connexion — BL-08 ; 422 de publication avec le champ nommé et la modale rouverte — BL-09, BL-13 ; création, modification, publication, archivage, remise en ligne réussis pour admin et content — BL-07 ; la liste affiche les lectures et « sans dédoublonnage » — BL-17)*
                     test/controllers/teams/homes_controller_test.rb *(raccourci « Blog » présent pour admin et content, absent pour field — BL-08)*
                     test/helpers/communication/article_form_helper_test.rb *(`article_editor_data`, 100 % des branches)*
- **Done quand**   : un membre Contenu touche « Blog » sur l'accueil équipe, ouvre `/teams/blog` vide, crée dans la modale un brouillon (titre, résumé, texte, signature) qui apparaît en tête de liste avec le badge « Brouillon » ; « Publier » au menu ⋮ sans résumé rouvre la modale en 422 avec « Écrivez le résumé » sous le champ ; complété et enregistré, il publie (toast, ligne « Publié »), archive, remet en ligne à la même date ; chaque geste est au journal d'audit ; un membre Terrain ne voit pas le raccourci et reçoit 403 sur `/teams/blog`

Ordre intra-lot : tests rouges → use cases → queries → contrôleurs → vues (UDR-0065 §3.1 à §3.5, §3.8 pour les ids) → `communication--character-count`.

`_form.html.erb` pose **tout** le balisage de l'UDR-0065 §3.3 et §3.4 (fieldset de couverture, `#article_editor` avec `article_editor_data`, panneau « Images du texte », gabarit `rowTemplate`, cibles et actions Stimulus nommées) : c'est le contrat que lit le Lot F, qui n'a pas le droit de toucher ce fichier. Tant que F n'est pas fusionné, la couverture ne se choisit pas et l'éditeur refuse toujours les fichiers (comportement actuel du contrôleur `rich-text-editor`) ; les images des tests de A viennent des fabriques du Lot 0. Tant que D et B ne sont pas fusionnés, « Aperçu » et les vignettes répondent par une erreur de chargement.

`TeamArticlesQuery` lit le **nom réel** de l'auteur (UDR-0065 §3.2, `written_by` : « un auteur anonymisé garde son nom ici ») et pas la constante de repli de signature de D : écart avec l'ADR-0073 §4.8, voir « Écarts relevés ».

---

## Lot B — Une image d'article s'envoie, se sert, se purge

- **Couche**       : domaine (use cases) + delivery + job + config
- **Fichiers**     : app/domain/use_cases/communication/upload_article_image.rb
                     app/domain/use_cases/communication/read_article_image.rb
                     app/controllers/teams/article_images_controller.rb
                     app/controllers/communication/article_images_controller.rb
                     app/jobs/communication/purge_orphan_article_images_job.rb
                     config/recurring.yml
- **Dépend de**    : Lot 0
- **Test associé** : test/domain/use_cases/communication/upload_article_image_test.rb *(refus de format, poids, taille, illisible : rien de stocké — BL-12 ; onzième image d'un article refusée ; `:forbidden` pour field — BL-08)*
                     test/domain/use_cases/communication/read_article_image_test.rb *(publiée → publique ; brouillon, non rattachée → qui gère seulement ; archivée → `:not_found` pour qui ne gère pas — BL-14)*
                     test/controllers/teams/article_images_controller_test.rb *(201 avec exactement `public_id`, `sgid`, `url`, `width`, `height` ; 422 `{ error }` en français ; 403 `{ error: "forbidden" }` pour field ; aucun blob créé sur un refus — BL-12)*
                     test/integration/communication/article_images_test.rb *(`Cache-Control: public, max-age=31536000, immutable` sans session pour l'image d'un article publié ; `private, no-store` pour qui gère un brouillon ; 404 pour un visiteur sur une image de brouillon, d'archivé ou non rattachée — BL-14)*
                     test/jobs/communication/purge_orphan_article_images_job_test.rb *(non rattachée à 47 h gardée, à 49 h purgée, rattachée jamais)*
                     test/integration/identity/active_storage_routes_test.rb *(inchangé, reste vert : aucune route Active Storage dessinée)*
- **Done quand**   : connecté en Contenu, un `POST /teams/blog/images` multipart d'un JPEG répond 201 avec son `url`, et cette adresse sert l'image (cache `private, no-store`) ; un GIF, un faux `.jpg`, une image de 1 Mo + 1 octet répondent 422 avec leur raison et laissent la table et le bucket vides ; un membre Terrain reçoit 403 ; l'image d'un article publié se lit sans session, en cache public immuable, celle d'un brouillon répond 404 à un visiteur ; la tâche planifiée de production lance la purge chaque jour et `test/jobs/recurring_tasks_test.rb` reste vert

Ordre intra-lot : tests rouges → use cases → contrôleurs (`Teams::ArticleImagesController` sous `Teams::BaseController` ; `Communication::ArticleImagesController` `allow_unauthenticated_access`, `send_data` de l'ADR-0073 §6) → job → tâche planifiée. Aucune vue, aucun JavaScript.

---

## Lot D — Un visiteur lit le blog

- **Couche**       : domaine (use case du compteur) + infrastructure (queries) + delivery + ui
- **Fichiers**     : app/domain/use_cases/communication/record_article_read.rb
                     app/infrastructure/queries/communication/article_signature.rb
                     app/infrastructure/queries/communication/published_articles_query.rb
                     app/infrastructure/queries/communication/article_detail_query.rb
                     app/controllers/communication/articles_controller.rb
                     app/views/communication/articles/index.html.erb
                     app/views/communication/articles/show.html.erb
                     app/views/communication/articles/gone.html.erb
                     app/views/communication/articles/_masthead.html.erb
                     app/views/communication/articles/_article_card.html.erb
                     app/views/communication/articles/_body_image.html.erb
                     app/views/communication/articles/_head.html.erb
                     app/helpers/public_pages_helper.rb
                     app/views/homepage/index.html.erb
                     app/views/shared/_help_sheet.html.erb
                     config/initializers/action_text.rb
                     script/perf/measure_screens.rb *(hors CI : `/blog` et `/blog/:slug`, ADR-0067)*
                     script/perf/dataset.rb *(articles du jeu de mesure)*
- **Dépend de**    : Lot 0
- **Test associé** : test/domain/use_cases/communication/record_article_read_test.rb *(équipe, robot, préchargement par chacun des trois en-têtes, brouillon, archivé : `increment_reads` jamais appelé ; un échec du compteur ne lève pas — BL-17)*
                     test/infrastructure/queries/communication/article_signature_test.rb *(signé `team` : jamais de nom ; signé `author` d'un compte anonymisé : `NULL` — BL-18)*
                     test/infrastructure/queries/communication/published_articles_query_test.rb *(publiés seulement, `published_on` puis `id` décroissants, 10 par page, `any?` en une requête `EXISTS` — BL-01, BL-05, BL-06)*
                     test/infrastructure/queries/communication/article_detail_query_test.rb *(une requête pour l'article, sa signature et sa couverture ; `author_name` tranché par la query — BL-18)*
                     test/controllers/communication/articles_controller_test.rb *(UDR-0064 §3.8 : BL-01 tri et pagination, 11 articles = 2 pages et `rel="next"` ; BL-02 200 sans shell, un seul `h1` même avec un `<h1>` saisi ; BL-03 les 12 balises du §3.4, avec couverture puis avec `blog/partage.png`, absolues sur `https://lnclass.com` ; BL-06 état vide ; BL-14 chaque `img` vise lnclass.com avec `width`, `height`, `alt`, `loading="lazy"` dans le texte ; BL-16 rien de `<script>`, `onerror`, `javascript:` à l'affichage ; BL-18 ; BL-21 HTML < 150 Ko pour 1 500 mots et 5 images, aucun `script` propre, aucun `data-controller`, aucune adresse `/rails/active_storage`)*
                     test/integration/communication/articles_test.rb *(ADR-0073 §7 : BL-04 404 sans le titre pour visiteur, élève, enseignant, direction, Terrain ; BL-05 410 « Cet article n'est plus disponible », lien vers `/blog`, `noindex`, jamais de renvoi vers la connexion ; BL-11 un article remis en ligne répond 200 à la même adresse, daté d'origine ; BL-17 visiteur, élève, équipe, robot → compteur à 2, aperçu de brouillon sans effet ; BL-20 élève connecté : 200 sur `/blog`, aucune redirection)*
                     test/helpers/public_pages_helper_test.rb *(`blog_link` : `nil` sans article, la paire avec ; une requête par rendu — BL-06)*
                     test/controllers/homepage_controller_test.rb *(« Blog » absent puis présent au pied, en tête de « Plus sur Lnclass » — BL-06)*
                     test/system/communication/help_sheet_test.rb *(pied de la carte d'aide : « Blog » absent puis présent, Mission, Protection des données, Conditions d'utilisation — BL-06, BL-20)*
                     test/views/no_third_party_resources_test.rb *(inchangé, couvre les nouvelles vues — BL-21)*
- **Done quand**   : sans compte, `/blog` montre « Aucun article pour le moment » et aucun lien « Blog » n'est au pied de la homepage ni de la carte d'aide ; un article publié (fabrique) apparaît en carte paginée par 10 et le lien « Blog » apparaît aux deux pieds ; `/blog/<slug>` montre le logo, « Blog », un seul `h1`, la signature (« L'équipe Lnclass » pour un auteur anonymisé), « Publié le 5 octobre 2026 », le texte et ses images en `loading="lazy"`, puis « Découvrir Lnclass » et « Tous les articles » ; la source porte les balises `og:*` sur `https://lnclass.com` ; un brouillon répond 404 à un élève et s'affiche avec le bandeau « Brouillon » et `noindex` pour un membre Contenu ; un archivé répond 410 ; deux lectures (visiteur, élève) font passer le compteur à 2, l'équipe et un `curl` ne comptent pas

Ordre intra-lot : tests rouges → `RecordArticleRead` → queries (`ArticleSignature::AUTHOR_NAME`, puis les deux queries ; la structure `Image` de l'UDR-0064 §3.1 vit dans `ArticleDetailQuery` et sert aussi à `PublishedArticlesQuery`) → contrôleur (jamais `render_result` : `:expired` → `render :gone, status: :gone`, ADR-0073 §6) → vues (UDR-0064 §3.2 à §3.4) → `blog_link` et ses deux pieds (§3.5) → initialiseur Action Text (`loading`, `decoding`, `fetchpriority`).

Les images servies par le Lot B : tant que B n'est pas fusionné, leurs adresses sont justes dans le HTML mais ne répondent pas ; les tests de D n'ouvrent pas les images.

---

## Lot E — Plan du site et robots.txt

- **Couche**       : infrastructure (query) + delivery + ui (XML, texte)
- **Fichiers**     : app/infrastructure/queries/communication/sitemap_query.rb
                     app/controllers/communication/sitemaps_controller.rb
                     app/views/communication/sitemaps/show.xml.builder
                     app/views/communication/sitemaps/robots.text.erb
                     public/robots.txt *(supprimé, ADR-0073 §4.6)*
- **Dépend de**    : Lot 0
- **Test associé** : test/infrastructure/queries/communication/sitemap_query_test.rb *(publiés seulement, avec `updated_at` ; ni brouillon ni archivé — BL-05, BL-19)*
                     test/integration/communication/sitemaps_test.rb *(BL-19 : accueil, `/aide`, chaque page de `Communication::PagesController::ONLINE`, `/blog`, chaque article publié avec `lastmod`, adresses absolues sur l'hôte canonique, `Cache-Control: public, max-age=3600` ; `/robots.txt` contient `Sitemap: https://lnclass.com/sitemap.xml`, `max-age=86400` ; `public/robots.txt` et `public/sitemap.xml` n'existent pas)*
- **Done quand**   : `curl /sitemap.xml` liste la page d'accueil, `/aide`, les pages publiques en ligne, `/blog` et chaque article publié avec sa date, sans brouillon ni archivé ; `curl /robots.txt` répond la ligne `Sitemap:` sur `https://lnclass.com`, et `CANONICAL_HOST=www.lnclass.com` la change sans toucher au code

---

## Lot F — L'éditeur du blog insère des images

- **Couche**       : ui (Stimulus, module JavaScript à la demande) + test système de bout en bout
- **Fichiers**     : app/javascript/controllers/rich_text_editor_controller.js *(mode images sur la valeur `attachments`, UDR-0065 §3.4.3 et §3.7 ; en-tête HITL et commentaire `V1 accepts no attachment` mis à jour)*
                     app/javascript/controllers/communication/cover_picker_controller.js
                     app/javascript/controllers/communication/image_alts_controller.js
                     app/javascript/lib/image_upload.js *(chargé par `import()` seulement)*
- **Dépend de**    : Lot A (balisage du formulaire), Lot B (endpoint d'envoi et service des images), Lot D (aperçu public)
- **Test associé** : test/system/teams/blog_management_test.rb *(UDR-0065 §3.10, Chrome, `assert_no_page_reload`, sans violation de CSP : 1. raccourci, liste vide, brouillon avec couverture et deux images du texte réduites et envoyées, texte de remplacement laissé vide, ligne en tête ; 2. publier → modale 422 sur l'image 2 (BL-13), compléter, publier, toast, ligne « Publié » (BL-07) ; 3. archiver, remettre en ligne, l'aperçu mène à la page publique qui montre l'image (BL-14) ; 4. GIF, faux `.jpg`, image trop lourde refusés avec leur raison (BL-12), image collée d'une page web retirée ; 5. à 390 px pas de défilement horizontal, ⋮ visible ; 6. l'éditeur d'un cours refuse toujours un fichier déposé (BL-15))*
                     test/system/teams/course_management_test.rb *(inchangé, reste vert — BL-15)*
                     test/system/teams/essential_management_test.rb *(inchangé, reste vert — BL-15)*
                     test/architecture/lazy_libraries_test.rb *(inchangé, reste vert : aucun import statique de `trix` ni du module d'images)*
                     test/integration/content_security_policy_test.rb *(inchangé, reste vert)*
- **Done quand**   : dans Chrome, un membre Contenu choisit une couverture et glisse une photo de 4000 px dans le texte : elle est réduite à 1600 px avant l'envoi, la barre de progression de Trix avance, la ligne « Image 1 » apparaît avec « À compléter » ; un GIF est refusé avec « « x.gif » n'a pas été ajoutée. » et sa raison ; enregistrer pendant un envoi attend la fin de l'envoi ; l'éditeur d'un cours refuse toujours une image ; `bin/check-asset-budget` : le bundle commun reste sous 60 Ko gzip et `image_upload` apparaît « à la demande »

Ordre intra-lot : test système rouge → `lib/image_upload.js` (`shrinkImage`, `uploadImage`, mêmes règles que `identity/photo_picker_controller.js`) → `rich-text-editor` (mode images seulement si `attachments` est vrai et `uploadUrl` non vide ; sinon comportement d'aujourd'hui, à l'identique) → `communication--cover-picker` → `communication--image-alts`. Le balisage lu (cibles, valeurs, événements `rich-text-editor:uploaded|attached|removed`) est celui du formulaire du Lot A : un écart s'y règle en remontant, jamais en touchant la vue.

---

## Dispatch

```
Vague 1 : Lot 0                          → 1 agent, séquentiel, sur feature/blog
Vague 2 : Lot A ‖ Lot B ‖ Lot D ‖ Lot E  → 4 agents, worktrees isolés (après fusion du Lot 0)
Vague 3 : Lot F (dépend de A, B, D)      → 1 agent, worktree isolé (après fusion de A, B et D)
```

Le Lot 0 s'exécute directement sur `feature/blog` (`/home/user/App.Lnclassapp`). Chaque lot parallèle part de la branche de chantier, Lot 0 fusionné :

```bash
# Vague 2, depuis /home/user/App.Lnclassapp, une fois le Lot 0 fusionné dans feature/blog
git worktree add ../lnclass-blog-lot-a -b feature/blog-lot-a feature/blog
git worktree add ../lnclass-blog-lot-b -b feature/blog-lot-b feature/blog
git worktree add ../lnclass-blog-lot-d -b feature/blog-lot-d feature/blog
git worktree add ../lnclass-blog-lot-e -b feature/blog-lot-e feature/blog

# Vague 3, une fois A, B et D fusionnés dans feature/blog
git worktree add ../lnclass-blog-lot-f -b feature/blog-lot-f feature/blog
```

Chemins absolus des worktrees : `/home/user/lnclass-blog-lot-a`, `-b`, `-d`, `-e`, `-f`. Noms courts exprès : `config/database.yml` dérive le nom des bases du dossier, et PostgreSQL tronque à 63 caractères (constat du plan `gestion-etablissement-direction`). Ne pas utiliser `EnterWorktree` : il branche depuis la branche par défaut, donc sans le Lot 0.

**Brief de chaque agent** (un `Agent` par lot, tous ceux d'une vague lancés dans le même message) :

- le chemin **absolu** de son worktree, et `git -C <worktree>` pour toute commande git : le répertoire courant est réinitialisé entre deux appels shell ;
- son lot recopié en entier (Couche, Fichiers, Dépend de, Test associé, Done quand, et le paragraphe qui le suit) ;
- les liens vers [`prd.md`](prd.md), [ADR-0073](../../decisions/adr/0073-blog-public-articles-images-et-referencement.md), et l'UDR qui régit ses vues : UDR-0065 pour A et F, UDR-0064 pour D et E ;
- l'ordre intra-lot : test rouge → domaine → infrastructure → delivery → UI ; en-tête HITL sur chaque fichier créé dans `app/` ;
- **interdiction de toucher un fichier qui n'est pas dans son champ `Fichiers`.** S'il en a besoin, il s'arrête et remonte : soit le fichier appartient au Lot 0 (qui rouvre), soit le plan est faux.

Fusion dans `feature/blog` au fur et à mesure, `bin/ci` vert après chaque fusion ; **une seule PR** `feature/blog` → `Develop`. Ordre de fusion conseillé (démonstration, pas fichiers) : E, B, D, A, puis F.

---

## Vérification de collision

> Contrôle mécanique, avant de lancer la vague 2 :
> ```bash
> awk '/^## Vérification de collision/{exit} 1' docs/chantiers/blog/plan.md \
>   | grep -oE '(app|test|config|db|lib)/[A-Za-z0-9_/.-]+\.(rb|erb|yml|js)' | sort | uniq -d
> ```
> Sortie attendue : **vide**. Toute ligne est une collision. Sortie vide ≠ plan sûr : les fichiers que l'expression ne voit pas (`.png`, `.builder`, `.gif`, `.webp`, `.jpg`, `.txt`, `.md`, `script/`) sont relus à la main dans l'inventaire ci-dessous.

### Fichiers remontés au Lot 0 (lus ou touchés par au moins deux lots, ou exigés par un test d'architecture)

| Fichier ou répertoire partagé | Lot propriétaire | Pourquoi |
|---|---|---|
| `db/migrate/20261004090000_create_articles.rb`, `db/schema.rb`, `test/db/schema_constraints_test.rb` | Lot 0 | Seule migration du chantier ; toutes les tables lues par A, B, D, E |
| `app/infrastructure/orm/article.rb`, `app/infrastructure/orm/article_image.rb` | Lot 0 | Lus par les deux adaptateurs, les queries de A, D, E et le rendu Action Text de D |
| `app/domain/entities/shared/content_status.rb` (+ 12 appelants) | Lot 0 | Déplacement imposé par l'ADR-0073 §4.2, lu par A (`TRANSITIONS`) et par le catalogue et l'évaluation |
| `app/domain/entities/shared/image_header.rb` (+ appelants de l'identité) | Lot 0 | Déplacement imposé par l'ADR-0073 §4.4, lu par le DTO des images (B) et la photo de profil |
| `app/infrastructure/repositories/shared/rich_text_sanitizer.rb` (+ appelants du catalogue) | Lot 0 | Déplacement imposé par l'ADR-0073 §4.5, étendu `image_ids:` pour l'adaptateur des articles |
| `app/domain/entities/communication/*.rb` (article, article_image, article_read) | Lot 0 | Contrats lus par A, B, D, F (constantes des plafonds lues par la vue de A et le JavaScript de F) |
| `app/domain/entities/identity/audit_action.rb` | Lot 0 | Liste fermée lue par `AuditLogRepository` ; écrite par les quatre use cases de A |
| `app/domain/policies/communication/*.rb` | Lot 0 | `ManageArticlesPolicy` lue par A et B ; `ReadArticlePolicy` par B et D |
| `app/domain/dtos/communication/*.rb` | Lot 0 | `ArticleInput` lu par A et l'adaptateur ; `ArticleImageInput` par B et l'adaptateur des images |
| `app/domain/ports/communication/*.rb` **et** `app/infrastructure/repositories/communication/*.rb` | Lot 0 | `port_contracts_test` : un adaptateur par port à tout instant ; `ArticleRepository` lu par A, B, D |
| `app/helpers/communication/articles_helper.rb` | Lot 0 | `article_image_src` lu par A (vignettes), D (pages) ; `canonical_url` par D et E |
| `app/helpers/communication/article_status_helper.rb` | Lot 0 | `article_status_badge` lu par A (liste, modale) et D (bandeau d'aperçu) |
| `config/routes/communication.rb`, `config/routes/teams.rb` | Lot 0 | Routes de A, B, D, E, contrat de l'UDR-0065 §3.0 |
| `config/application.rb` | Lot 0 | `config.x.canonical_host`, lu par D et E |
| `config/locales/communication/articles.fr.yml`, `config/locales/teams/articles.fr.yml` | Lot 0 | Lus par les helpers du Lot 0, par A, B, D et F (messages d'envoi) |
| `config/locales/teams/homes.fr.yml`, `config/locales/shared/components.fr.yml`, `config/locales/communication/public_pages.fr.yml`, `config/locales/shared/help_sheet.fr.yml`, `config/locales/homepage/index.fr.yml` | Lot 0 | `conventions.md` §6 : les locales appartiennent au Lot 0 ; textes fixés par les UDR |
| `app/assets/images/blog/partage.png` | Lot 0 | Image par défaut de `og:image` (D), fichier d'équipe décidé par l'UDR-0064 §3.4 |
| `test/support/factories/communication.rb`, `test/support/factories_test.rb` | Lot 0 | Fabriques lues par A, B, D, E, F |
| `test/fixtures/files/article_images/*` | Lot 0 | Lus par le test du DTO (Lot 0) et par B |
| `test/infrastructure/orm/models_test.rb` | Lot 0 | Tables V1 et leurs modèles |
| `app/views/layouts/*` | aucun | Inchangé : `yield :head` existe déjà |
| `app/javascript/controllers/index.js` | aucun | Enregistrement par motif : déposer le fichier suffit |
| `docs/**` (glossaire, configuration, amendements d'ADR et d'UDR, index) | Lot 0, puis porteur du chantier | Les lots verticaux n'écrivent pas dans `docs/` |

### Fichiers à propriétaire unique que la proposition faisait collisionner

| Fichier | Lot propriétaire | Collision évitée |
|---|---|---|
| `app/controllers/teams/articles_controller.rb` | Lot A | Rédiger et publier étaient deux lots (A, C) : fusionnés |
| `app/views/teams/articles/_article_row.html.erb`, `_edit_modal.html.erb` | Lot A | Rendus par la transition et par la publication refusée (ex-C) |
| `app/views/teams/articles/_form.html.erb` | Lot A | Le JavaScript de l'éditeur (F) lit son balisage sans le toucher |
| `app/javascript/controllers/rich_text_editor_controller.js` | Lot F | Seul lot qui change l'éditeur partagé avec les cours et les fiches |
| `app/controllers/communication/articles_controller.rb` | Lot D | Le compteur (`RecordArticleRead`) et la lecture publique dans le même lot |
| `app/views/communication/articles/_body_image.html.erb`, `config/initializers/action_text.rb` | Lot D | Rendu des images du texte sur la page publique, testé par BL-21 dans D |
| `app/helpers/public_pages_helper.rb`, `app/views/homepage/index.html.erb`, `app/views/shared/_help_sheet.html.erb` | Lot D | Seul lot qui ajoute les liens « Blog » |
| `app/infrastructure/queries/communication/article_signature.rb` | Lot D | Seules les queries publiques de D appliquent le repli de signature (A lit le nom réel) |
| `config/recurring.yml` | Lot B | Seule tâche planifiée du chantier |
| `public/robots.txt` | Lot E | Supprimé, remplacé par la route |

### Inventaire complet — fichier → lot

| Fichier | Lot |
|---|---|
| `app/domain/entities/catalog/content_status.rb` *(supprimé)* · `app/domain/entities/shared/content_status.rb` · `app/domain/entities/catalog/course.rb` · `app/domain/entities/catalog/essential.rb` · `app/domain/entities/assessment/exercise.rb` | 0 |
| `app/domain/use_cases/catalog/publish_course.rb` · `archive_course.rb` · `publish_essential.rb` · `archive_essential.rb` · `app/domain/use_cases/assessment/publish_exercise.rb` · `archive_exercise.rb` | 0 |
| `app/helpers/catalog/content_status_helper.rb` · `test/helpers/catalog/content_status_helper_test.rb` · `test/domain/entities/catalog/content_status_test.rb` *(supprimé)* · `test/domain/entities/shared/content_status_test.rb` | 0 |
| `app/domain/entities/identity/image_header.rb` *(supprimé)* · `app/domain/entities/shared/image_header.rb` · `app/domain/dtos/identity/profile_photo_input.rb` | 0 |
| `test/domain/entities/identity/image_header_test.rb` *(supprimé)* · `test/domain/entities/shared/image_header_test.rb` · `test/domain/dtos/identity/profile_photo_input_test.rb` · `test/domain/use_cases/identity/change_own_photo_test.rb` · `test/controllers/identity/profile_photos_controller_test.rb` · `test/system/identity/profile_photo_test.rb` | 0 |
| `app/infrastructure/repositories/catalog/rich_text_sanitizer.rb` *(supprimé)* · `app/infrastructure/repositories/shared/rich_text_sanitizer.rb` · `app/infrastructure/repositories/catalog/course_repository.rb` · `essential_repository.rb` · `content_tree_writer.rb` | 0 |
| `test/infrastructure/repositories/catalog/rich_text_sanitizer_test.rb` *(supprimé)* · `test/infrastructure/repositories/shared/rich_text_sanitizer_test.rb` · `test/infrastructure/repositories/catalog/content_tree_writer_test.rb` · `test/system/catalog/course_catalog_test.rb` · `script/bench/import_course_tree.rb` | 0 |
| `db/migrate/20261004090000_create_articles.rb` · `db/schema.rb` · `test/db/schema_constraints_test.rb` | 0 |
| `app/infrastructure/orm/article.rb` · `article_image.rb` · `test/infrastructure/orm/models_test.rb` · `test/infrastructure/orm/article_image_test.rb` | 0 |
| `app/domain/entities/communication/article.rb` · `article_image.rb` · `article_read.rb` et leurs trois tests sous `test/domain/entities/communication/` | 0 |
| `app/domain/entities/identity/audit_action.rb` · `test/domain/entities/identity/audit_action_test.rb` | 0 |
| `app/domain/policies/communication/manage_articles_policy.rb` · `read_article_policy.rb` et leurs deux tests | 0 |
| `app/domain/dtos/communication/article_input.rb` · `article_image_input.rb` et leurs deux tests | 0 |
| `app/domain/ports/communication/article_repository_port.rb` · `article_image_store_port.rb` | 0 |
| `app/infrastructure/repositories/communication/article_repository.rb` · `article_image_store.rb` et leurs deux tests | 0 |
| `app/helpers/communication/articles_helper.rb` · `article_status_helper.rb` et leurs deux tests | 0 |
| `config/routes/communication.rb` · `config/routes/teams.rb` · `test/routing/blog_routes_test.rb` · `config/application.rb` | 0 |
| les sept fichiers de locale du Lot 0 | 0 |
| `app/assets/images/blog/partage.png` · `test/support/factories/communication.rb` · `test/support/factories_test.rb` · `test/fixtures/files/article_images/{animation.gif, animated.webp, fake.jpg}` | 0 |
| `docs/guide/glossaire.md` · `docs/guide/configuration.md` · amendements des ADR 0027, 0029, 0038, 0047, 0051 et des UDR 0014, 0016, 0018, 0061, 0063 · les deux index | 0 |
| `app/domain/use_cases/communication/{create,update,publish,archive}_article.rb` et leurs quatre tests | A |
| `app/infrastructure/queries/communication/team_articles_query.rb` · `article_form_images_query.rb` et leurs deux tests | A |
| `app/controllers/teams/articles_controller.rb` · `test/controllers/teams/articles_controller_test.rb` | A |
| `app/controllers/teams/homes_controller.rb` · `app/views/teams/homes/show.html.erb` · `_shortcuts.html.erb` · `test/controllers/teams/homes_controller_test.rb` | A |
| `app/helpers/communication/article_form_helper.rb` · `test/helpers/communication/article_form_helper_test.rb` | A |
| `app/views/teams/articles/` : `index`, `_article_row`, `new`, `edit`, `_edit_modal`, `_form`, `_image_alt_row` (`.html.erb`) ; `create`, `update`, `transition`, `publish_refused` (`.turbo_stream.erb`) | A |
| `app/javascript/controllers/communication/character_count_controller.js` | A |
| `app/domain/use_cases/communication/upload_article_image.rb` · `read_article_image.rb` et leurs deux tests | B |
| `app/controllers/teams/article_images_controller.rb` · `test/controllers/teams/article_images_controller_test.rb` | B |
| `app/controllers/communication/article_images_controller.rb` · `test/integration/communication/article_images_test.rb` | B |
| `app/jobs/communication/purge_orphan_article_images_job.rb` · son test · `config/recurring.yml` | B |
| `app/domain/use_cases/communication/record_article_read.rb` et son test | D |
| `app/infrastructure/queries/communication/article_signature.rb` · `published_articles_query.rb` · `article_detail_query.rb` et leurs trois tests | D |
| `app/controllers/communication/articles_controller.rb` · `test/controllers/communication/articles_controller_test.rb` · `test/integration/communication/articles_test.rb` | D |
| `app/views/communication/articles/` : `index`, `show`, `gone`, `_masthead`, `_article_card`, `_body_image`, `_head` (`.html.erb`) | D |
| `app/helpers/public_pages_helper.rb` · `app/views/homepage/index.html.erb` · `app/views/shared/_help_sheet.html.erb` et leurs trois tests | D |
| `config/initializers/action_text.rb` · `script/perf/measure_screens.rb` · `script/perf/dataset.rb` | D |
| `app/infrastructure/queries/communication/sitemap_query.rb` · son test · `app/controllers/communication/sitemaps_controller.rb` · `app/views/communication/sitemaps/show.xml.builder` · `robots.text.erb` · `test/integration/communication/sitemaps_test.rb` · `public/robots.txt` *(supprimé)* | E |
| `app/javascript/controllers/rich_text_editor_controller.js` · `app/javascript/controllers/communication/cover_picker_controller.js` · `image_alts_controller.js` · `app/javascript/lib/image_upload.js` · `test/system/teams/blog_management_test.rb` | F |

Sortie de la commande de détection, exécutée par l'architecte le 2026-10-02 sur ce fichier : **vide** (aucune collision).

---

## Rattachement des critères aux lots

| Critère | Lot(s) | Test(s) |
|---|---|---|
| BL-01 — lecture publique, tri, pagination | D | `test/controllers/communication/articles_controller_test.rb`, `test/infrastructure/queries/communication/published_articles_query_test.rb` |
| BL-02 — page d'un article, un seul `h1` | D, 0 | `articles_controller_test.rb` (D) ; `test/infrastructure/repositories/shared/rich_text_sanitizer_test.rb` (`h1` → `h2`, 0) |
| BL-03 — aperçu partagé et référencement | D, 0 | `articles_controller_test.rb` (12 balises, image par défaut) ; `test/helpers/communication/articles_helper_test.rb` (`canonical_url`) |
| BL-04 — brouillon introuvable | D, 0 | `test/integration/communication/articles_test.rb` ; `test/domain/policies/communication/read_article_policy_test.rb` |
| BL-05 — article archivé (410, hors liste, hors plan du site) | D, E, 0 | `articles_test.rb` ; `published_articles_query_test.rb` ; `test/integration/communication/sitemaps_test.rb` ; `read_article_policy_test.rb` |
| BL-06 — état vide et liens conditionnels | D | `articles_controller_test.rb`, `test/helpers/public_pages_helper_test.rb`, `test/controllers/homepage_controller_test.rb`, `test/system/communication/help_sheet_test.rb` |
| BL-07 — qui gère, chaque geste au journal | A, 0, F | `test/domain/use_cases/communication/{create,update,publish,archive}_article_test.rb`, `test/controllers/teams/articles_controller_test.rb` ; `manage_articles_policy_test.rb`, `audit_action_test.rb` (0) ; `test/system/teams/blog_management_test.rb` (F) |
| BL-08 — qui ne gère pas : 403, base inchangée, pas de raccourci | A, B, 0 | `teams/articles_controller_test.rb`, `test/controllers/teams/homes_controller_test.rb` (A) ; `test/controllers/teams/article_images_controller_test.rb` (B) ; `manage_articles_policy_test.rb` (0) |
| BL-09 — publier exige un article complet | A, 0 | `publish_article_test.rb`, `teams/articles_controller_test.rb` ; `test/domain/entities/communication/article_test.rb` |
| BL-10 — adresse figée et unique | 0 | `test/infrastructure/repositories/communication/article_repository_test.rb` |
| BL-11 — remise en ligne, date d'origine | A, D, 0 | `publish_article_test.rb` (A) ; `articles_test.rb` (200 à la même adresse, D) ; `article_repository_test.rb` (`COALESCE`, 0) |
| BL-12 — image vérifiée | 0, B, F | `test/domain/dtos/communication/article_image_input_test.rb` (0) ; `upload_article_image_test.rb`, `article_images_controller_test.rb` (B) ; `blog_management_test.rb` (F) |
| BL-13 — texte de remplacement obligatoire | A, 0, F | `publish_article_test.rb`, `teams/articles_controller_test.rb` (A) ; `article_test.rb` (0) ; `blog_management_test.rb` (F) |
| BL-14 — images servies par Lnclass, cache public, brouillon illisible | B, D, F | `test/integration/communication/article_images_test.rb`, `read_article_image_test.rb` (B) ; `articles_controller_test.rb` (D) ; `blog_management_test.rb` (F) |
| BL-15 — les cours restent sans image | 0, F | `rich_text_sanitizer_test.rb` (sans `image_ids`, 0) ; `blog_management_test.rb` étape 6, `course_management_test.rb` et `essential_management_test.rb` inchangés (F) |
| BL-16 — contenu assaini | 0, D | `rich_text_sanitizer_test.rb`, `article_repository_test.rb` (0) ; `articles_controller_test.rb` (affichage, D) |
| BL-17 — compteur de lectures | D, 0, A | `record_article_read_test.rb`, `articles_test.rb` (compteur à 2, D) ; `article_read_test.rb`, `article_repository_test.rb` (une requête, 0) ; `team_articles_query_test.rb`, `teams/articles_controller_test.rb` (lu par l'équipe, A) |
| BL-18 — signature | D | `article_signature_test.rb`, `article_detail_query_test.rb`, `articles_controller_test.rb` |
| BL-19 — plan du site | E | `sitemaps_test.rb`, `sitemap_query_test.rb` |
| BL-20 — connecté sans détour | D | `articles_test.rb`, `help_sheet_test.rb` |
| BL-21 — budgets (HTML, chargement à la demande, aucun JS ni tiers) | D, F | `articles_controller_test.rb`, `test/views/no_third_party_resources_test.rb` (D) ; `lazy_libraries_test.rb` et `bin/check-asset-budget` (F) ; p95 hors CI par `script/perf/measure_screens.rb` (D) |

**Aucun critère orphelin** : BL-01 à BL-21, chacun rattaché à au moins un lot et à au moins un fichier de test. BL-10 est le seul porté par le socle seul (le slug naît dans l'adaptateur) ; sa démonstration dans l'application (adresse publique inchangée après correction du titre) suit la fusion de A et D et appartient au challenger.

---

## Écarts relevés entre les décisions et le code (à consigner au `journal.md`)

1. **Horodatage de la migration.** L'ADR-0073 §6 cite `db/migrate/20261002120000_create_articles.rb` (« extrait »). `Develop` porte déjà des migrations jusqu'à `20261003110000` : une migration plus ancienne que la dernière jouée serait déroutante. Le plan la nomme `20261004090000_create_articles.rb` ; le contenu suit l'ADR à la lettre.
2. **Nom de l'auteur dans la liste de gestion.** L'ADR-0073 §4.8 range `TeamArticlesQuery` parmi les queries qui appliquent le repli de signature ; l'UDR-0065 §3.2 dit que la liste garde le nom réel (« Écrit par … »), et un article signé `team` n'aurait sinon aucun nom à afficher. L'UDR fait foi pour la vue : A lit le nom réel, seules les queries publiques de D appliquent `ArticleSignature::AUTHOR_NAME`.
3. **Nom inventé par le plan** : `Queries::Communication::ArticleFormImagesQuery` (A). L'UDR-0065 §3.0 exige que le contrôleur reconstruise `images` (`public_id`, `sgid`, `url`, `alt`) depuis le `body` et `image_alts` ; le `sgid` vient d'`Orm::`, donc d'une query, pas du contrôleur. Aucune décision ne la nomme.
4. **Deux fichiers de test pour la lecture publique.** L'UDR-0064 §3.8 nomme `test/controllers/communication/articles_controller_test.rb`, l'ADR-0073 §7 `test/integration/communication/articles_test.rb`. Les deux sont gardés dans D, sans doublon : rendu dans le premier, parcours HTTP (statuts, compteur, redirections) dans le second.
5. **Lecture de l'aperçu par le test système de l'UDR-0065 §3.10.** Ce test couvre aussi la gestion du Lot A : il est porté par F, dernier lot, parce qu'il exige le JavaScript de F, l'endpoint de B et la page publique de D.

---

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md`
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md`
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

Portes propres à ce chantier :

- [ ] Étape 0.1 du Lot 0 en un commit de pur renommage : les tests existants des cours, fiches, exercices, imports et de la photo de profil passent sans changement d'assertion
- [ ] Couverture 100 % lignes et branches à chaque fusion dans `feature/blog`
- [ ] `bin/check-asset-budget` : bundle commun inchangé, `image_upload` à la demande ; 0 Ko de JavaScript ajouté aux pages de lecture
- [ ] Hors CI : `script/perf/measure_screens.rb` mesure `/blog` et `/blog/:slug` sous 100 ms p95 et 150 Ko de HTML (PRD §7, colonne « Après » remplie)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Son mandat change selon le cycle : bugfix → il rejoue les étapes de reproduction du memo dans l'app ; refactoring → il vérifie que **rien** n'a changé pour l'utilisateur, et il lui est interdit de commenter le style ; optimisation → il **relance lui-même le bench** et doit obtenir le gain annoncé, sinon la PR ne passe pas.
>
> Pour ce chantier (feature), il rejoue au minimum, à 390 px : le chemin nominal A du PRD (raccourci, brouillon avec couverture et deux images, publication refusée sur l'image sans texte de remplacement, publication, archivage, remise en ligne à la même date) ; le chemin nominal B (le lien d'un article publié ouvert sans compte, puis lu une seconde fois : compteur + 2 dans la gestion) ; **un chemin d'erreur forgé à la main** : `PATCH /teams/blog/<public_id>/publish` et `POST /teams/blog/images` depuis un compte Terrain (403, base et bucket inchangés), un brouillon ouvert par son adresse en navigation privée (404 sans le titre), un archivé (410), une image de brouillon demandée sans session (404) ; il colle un lien d'article dans un aperçu de partage (balises `og:*` sur `https://lnclass.com`), lit `/sitemap.xml` et `/robots.txt`, et vérifie qu'un cours refuse toujours une image déposée.
