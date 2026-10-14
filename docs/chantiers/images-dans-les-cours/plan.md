# Plan d'exécution — Des images dans les fiches de cours

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Décisions : [ADR-0089](../../decisions/adr/0089-images-des-fiches-et-des-questions.md) · [UDR-0084](../../decisions/udr/0084-images-dans-l-editeur-de-fiche-la-question-et-la-lecture.md)

## Graphe

```
Lot 0 — SOCLE (séquentiel) : tables, plafonds, emplacements, ports, routes, locales, envoi JS paramétré
  ↓
  ├─► Lot A  Image dans une fiche : envoyer, insérer, texte de remplacement, servir, lire      ┐
  ├─► Lot B  Publier une fiche : emplacements restants et alts manquants refusés (+ Tout publier) ├─ en parallèle
  ├─► Lot C  Image d'une question : envoyer, servir, voir en session, publier l'exercice        │
  └─► Lot D  Import : emplacements et descriptions d'image, prompt de rédaction                ┘
```

Dispatch proposé : Lot 0 seul, puis A, B, C, D ensemble (4 worktrees).

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + fichiers partagés
- **Fichiers**     : `db/migrate/20261010090000_create_essential_and_question_images.rb` *(une migration : deux tables, une colonne)*
                     `db/schema.rb`
                     `app/domain/entities/shared/content_image.rb`
                     `app/domain/entities/catalog/image_slot.rb`
                     `app/domain/entities/catalog/essential_image.rb`
                     `app/domain/entities/catalog/essential.rb` *(gagne `images`, `image_slots`)*
                     `app/domain/entities/assessment/question.rb` *(gagne `image_description`, `image`, erreurs `image_missing`, `image_alt_blank`)*
                     `app/domain/dtos/shared/content_image_input.rb`
                     `app/domain/ports/catalog/essential_image_store_port.rb`
                     `app/domain/ports/assessment/question_image_store_port.rb`
                     `app/domain/ports/catalog/content_tree_writer_port.rb` *(`QuestionNode` gagne `image_description`)*
                     `app/infrastructure/orm/essential_image.rb` · `app/infrastructure/orm/question_image.rb`
                     `app/infrastructure/orm/essential.rb` · `app/infrastructure/orm/question.rb` *(associations)*
                     `app/infrastructure/repositories/catalog/essential_image_store.rb` *(remonté du Lot A : un port sans adaptateur casse `port_contracts_test`)*
                     `app/infrastructure/repositories/assessment/question_image_store.rb` *(remonté du Lot C, même raison)*
                     `app/jobs/catalog/purge_orphan_essential_images_job.rb` · `app/jobs/assessment/purge_orphan_question_images_job.rb` *(remontés : `recurring_tasks_test` exige leur classe)*
                     `app/domain/entities/assessment/exercise.rb` *(`image_errors` par numéro de question)*
                     `app/domain/dtos/communication/article_image_input.rb` *(plafonds lus sur la classe, comportement du blog inchangé)*
                     `test/support/factories/catalog.rb` · `test/support/factories/assessment.rb` *(`create_essential_image`, `create_question_image`)*
                     `app/infrastructure/repositories/shared/rich_text_sanitizer.rb` *(`image_model:`)*
                     `app/javascript/lib/image_upload.js` *(`field:`, réencodage WebP)*
                     `config/routes/teams.rb` · `config/routes/catalog.rb` · `config/routes/assessment.rb`
                     `config/locales/**/*.fr.yml` *(toutes les clés des lots A à D)*
                     `config/recurring.yml`
                     `test/fixtures/essential_images.yml` · `test/fixtures/question_images.yml`
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/catalog/image_slot_test.rb`
                     `test/infrastructure/repositories/catalog/essential_image_store_test.rb` · `test/infrastructure/repositories/assessment/question_image_store_test.rb`
                     `test/jobs/catalog/purge_orphan_essential_images_job_test.rb` · `test/jobs/assessment/purge_orphan_question_images_job_test.rb`
                     `test/infrastructure/orm/essential_image_test.rb` · `test/infrastructure/orm/models_test.rb` (47 modèles)
                     `test/infrastructure/repositories/catalog/content_tree_writer_characterization_test.rb` *(colonne vide ignorée)*
                     `test/domain/entities/shared/content_image_test.rb`
                     `test/domain/dtos/shared/content_image_input_test.rb`
                     `test/domain/entities/assessment/question_test.rb`
                     `test/infrastructure/repositories/shared/rich_text_sanitizer_test.rb` *(le blog inchangé)*
- **Done quand**   : migrations jouées, contraintes `CHECK` en place, ports gelés ; `bin/rails test` vert (blog et import inchangés) ; une image de 400 Ko, un SVG déguisé et un JPEG GPS sont refusés ou nettoyés par le DTO

---

## Lot A — Image dans une fiche : envoyer, insérer, texte de remplacement, servir, lire

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/catalog/upload_essential_image.rb`
                     `app/domain/use_cases/catalog/read_essential_image.rb`
                     `app/domain/dtos/catalog/essential_input.rb` *(gagne `image_alts`)*
                     `app/domain/use_cases/catalog/update_essential.rb` · `app/domain/use_cases/catalog/create_essential.rb`
                     `app/infrastructure/repositories/catalog/essential_repository.rb` *(rattache les images citées, alts, supprime les retirées)*
                     `app/controllers/teams/essential_images_controller.rb`
                     `app/controllers/catalog/essential_images_controller.rb`
                     `app/controllers/teams/essentials_controller.rb` *(paramètre `image_alts`)*
                     `app/helpers/catalog/essential_form_helper.rb`
                     `app/views/teams/essentials/_form.html.erb`
                     `app/views/catalog/essentials/_body_image.html.erb`
                     `app/javascript/controllers/catalog/essential_image_slots_controller.js`
                     `app/javascript/controllers/rich_text_editor_controller.js` *(remplacement de l'emplacement sélectionné)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/catalog/upload_essential_image_test.rb`
                     `test/domain/use_cases/catalog/read_essential_image_test.rb`
                     `test/controllers/catalog/essential_images_controller_test.rb` *(404 brouillon, 404 hors niveau, 401 sans connexion, `Cache-Control`, 404 après remplacement)*
                     `test/controllers/teams/essential_images_controller_test.rb` *(403 terrain, 422 400 Ko, 31ᵉ image)*
                     `test/system/catalog/essential_images_test.rb` *(insérer dans un emplacement, alt pré-rempli, élève voit l'image `loading=lazy`)*
- **Done quand**   : dans l'application, l'équipe insère une image à la place d'un emplacement, le texte de remplacement est pré-rempli, et un élève du niveau voit l'image dans la fiche publiée ; un élève d'un autre niveau reçoit 404 sur son adresse

---

## Lot B — Publier une fiche : emplacements restants et textes de remplacement manquants refusés

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : `app/domain/use_cases/catalog/publish_essential.rb`
                     `app/domain/use_cases/catalog/publish_cascade.rb`
                     `app/controllers/concerns/publish_cascade.rb` *(message qui nomme la fiche)*
                     `app/views/teams/essentials/transition.turbo_stream.erb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/catalog/publish_essential_test.rb`
                     `test/domain/use_cases/catalog/publish_cascade_test.rb`
                     `test/system/catalog/publish_essential_with_images_test.rb`
- **Done quand**   : publier une fiche avec 2 emplacements affiche « Il reste 2 image(s) à insérer dans cette fiche. » et la laisse en brouillon ; « Tout publier » ne publie rien et nomme la fiche ; une fiche sans image se publie comme avant

---

## Lot C — Image d'une question : envoyer, servir, voir en session, publier l'exercice

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/assessment/upload_question_image.rb`
                     `app/domain/use_cases/assessment/read_question_image.rb`
                     `app/domain/use_cases/assessment/publish_exercise.rb` *(message `image_missing` numéroté)*
                     `app/domain/dtos/assessment/exercise_input.rb` *(question : `image_public_id`, `image_alt`, `image_description`)*
                     `app/infrastructure/repositories/assessment/exercise_repository.rb` *(rattache l'image ; la détache et la supprime avant toute suppression de sa question : FK RESTRICT)*
                     `app/controllers/teams/question_images_controller.rb`
                     `app/controllers/assessment/question_images_controller.rb`
                     `app/controllers/teams/exercises_controller.rb`
                     `app/views/teams/exercises/_question_fields.html.erb`
                     `app/views/teams/exercises/transition.turbo_stream.erb`
                     `app/views/assessment/exercise_sessions/_question_card.html.erb`
                     `app/javascript/controllers/assessment/question_image_controller.js`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/assessment/upload_question_image_test.rb`
                     `test/domain/use_cases/assessment/publish_exercise_test.rb`
                     `test/controllers/assessment/question_images_controller_test.rb`
                     `test/system/assessment/question_image_test.rb`
- **Done quand**   : l'équipe ajoute une image à une question, publie l'exercice, et l'élève la voit au-dessus de l'énoncé en session ; un exercice dont une question attend son image refuse de se publier avec « La question N attend son image. »

---

## Lot D — Import : emplacements et descriptions d'image

- **Couche**       : domaine + infrastructure + documentation de contenu
- **Fichiers**     : `config/schemas/lnclass.course-tree.v1.json` *(propriété facultative `image.description`)*
                     `app/domain/use_cases/catalog/import_course_tree.rb` *(`question_node` lit `image.description`)*
                     `app/infrastructure/repositories/catalog/content_tree_writer.rb` *(écrit `image_description`)*
                     `app/domain/entities/catalog/content_node.rb` *(ajouté au lot : une description faite d'espaces est « blank », le schéma ne le voit pas)*
                     `docs/contenus/prompt-redaction.md` *(règle des images : emplacements, descriptions, style ludique Claude Design)*
                     `docs/contenus/README.md` *(procédure : importer, produire dans Claude Design, insérer, publier)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/catalog/import_course_tree_test.rb`
                     `test/infrastructure/repositories/catalog/import_schema_validator_test.rb`
                     `test/system/imports_end_to_end_test.rb` *(fichier avec emplacements et descriptions)*
- **Done quand**   : un fichier avec `<p>[[image: …]]</p>` et `image.description` s'importe ; la fiche affiche l'emplacement et la question sa description ; les 24 leçons de `docs/contenus/lecons-traitees/` s'importent toujours sans erreur

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `db/migrate/*`, `db/schema.rb` | Lot 0 |
| `config/routes/*.rb` | Lot 0 |
| `config/locales/**/*.fr.yml` | Lot 0 |
| `config/recurring.yml` | Lot 0 |
| `app/domain/entities/catalog/essential.rb` | Lot 0 |
| `app/domain/entities/assessment/question.rb` | Lot 0 |
| `app/domain/ports/catalog/content_tree_writer_port.rb` | Lot 0 |
| `app/infrastructure/repositories/shared/rich_text_sanitizer.rb` | Lot 0 |
| `app/javascript/lib/image_upload.js` | Lot 0 |
| `app/infrastructure/repositories/catalog/essential_repository.rb` | Lot A |
| `app/javascript/controllers/rich_text_editor_controller.js` | Lot A |
| `app/views/teams/essentials/_form.html.erb` | Lot A |
| `app/domain/use_cases/catalog/publish_essential.rb`, `publish_cascade.rb` | Lot B |
| `app/views/teams/essentials/transition.turbo_stream.erb` | Lot B |
| `app/domain/use_cases/assessment/publish_exercise.rb` | Lot C |
| `app/infrastructure/repositories/assessment/exercise_repository.rb` | Lot C |
| `app/infrastructure/repositories/catalog/content_tree_writer.rb` | Lot D |
| `config/schemas/lnclass.course-tree.v1.json` | Lot D |

Aucun fichier n'est listé par deux lots parallèles.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, (index généré par `script/docs/build_index` à la clôture)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, (index généré à la clôture)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
