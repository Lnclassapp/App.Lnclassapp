# Plan d'exécution — Fiches de cours à l'identique des maquettes

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot). Refait le 2026-10-27 (#318).

## Les 4 points « À trancher au plan »

| Point | Décision | Statut |
|---|---|---|
| Où vit le contenu d'une fiche | Un document de blocs `jsonb` par leçon (`course_sheets`), importé au format `lnclass.course_sheet` v1, rendu par un partial par type de bloc | Retenu par le pilote — [ADR-XXXX](../../decisions/adr/XXXX-fiche-de-cours-en-donnees-importees.md) |
| Figure propre à une fiche | `kind` en liste fermée : un partial et un contrôleur Stimulus par `kind`, réglages dans les données, bornés par le schéma | Retenu par le pilote — même ADR |
| Rendu sous 1 000 px | Proposition : même design, pages fluides (détail dans l'[UDR-XXXX](../../decisions/udr/XXXX-fiche-de-cours-a-l-identique-des-maquettes.md) § 4) | Retenu par Touré pour le test (2026-10-27), à confirmer par le porteur — Lot G, phase 1 |
| Nom à l'écran | « Fiche de cours » par défaut | **En attente du porteur** — Lot H |

Le libellé « Fiche de cours » est une valeur de locale : si le porteur choisit un autre nom, seule cette valeur change (Lot H).

## Graphe

Consigne de Touré (2026-10-27) : **d'abord un test sur une seule fiche, Thalès**. Lentilles et Texte argumentatif attendent la validation de ce test.

```
PHASE 1 — test sur la fiche Thalès
  Lot 0 — SOCLE (séquentiel)
    ↓
    ├─► Lot A  Importer une fiche         ┐
    ├─► Lot B  Lire une fiche             ├─ en parallèle
    └─► Lot C  Exercices et Je m'entraîne ┘
          ↓
    Lot G  Téléphone : pages fluides sous 1 000 px
          ↓
    Lot D  Fiche Thalès, importée dans les seeds des environnements de PR
          → PR ouverte prête (après accord de Touré) : lien Railway pour le test

PHASE 2 — après validation du test par Touré
    ├─► Lot E  Fiche Lentilles            ┐ en parallèle
    └─► Lot F  Fiche Texte argumentatif   ┘
    Lot H  Nom à l'écran (attend le porteur)
```

---

### Lot 0 — Socle : table, contrat du document, habillage

- **Couche**      : infrastructure + domaine (contrats) + ui (fichiers partagés)
- **Fichiers**    : db/migrate/…_create_course_sheets.rb
                    db/schema.rb
                    app/infrastructure/orm/course_sheet.rb
                    app/domain/entities/catalog/course_sheet.rb
                    app/domain/entities/catalog/sheet_document.rb
                    app/domain/ports/catalog/course_sheet_repository_port.rb
                    config/schemas/lnclass.course-sheet.v1.json
                    config/routes/catalog.rb
                    config/locales/catalog/course_sheets.fr.yml
                    app/views/catalog/course_sheets/_block.html.erb
                    app/assets/stylesheets/course_sheet.css
                    public/fonts/kalam-*.woff2, public/fonts/source-serif-4-*.woff2
                    test/design/design_tokens_test.rb
                    test/fixtures/course_sheets.yml
- **Dépend de**   : —
- **Test associé**: test/domain/entities/catalog/sheet_document_test.rb
                    test/design/design_tokens_test.rb
- **Done quand**  : `SheetDocument` accepte le document de référence et refuse HTML, URL, `kind` inconnu, lexique incohérent ; la table existe ; `design_tokens_test` passe avec l'exception bornée aux dossiers de la fiche (CA-12)

`_block.html.erb` gèle l'aiguillage : il rend `blocks/_<type>` et `kinds/_<kind>` pour chaque type et `kind` de la liste fermée ; les lots créent ces partials, ils ne touchent pas l'aiguillage. `course_sheet.css` porte les jetons, les 3 thèmes, le Seyès et les composants communs ; un lot qui a besoin d'une règle propre à un `kind` l'écrit dans un fichier à lui (`course_sheet/<kind>.css`) importé par ce fichier dès le Lot 0.

### Lot A — Importer une fiche de cours

- **Couche**      : domaine + infrastructure + delivery
- **Fichiers**    : app/domain/use_cases/catalog/import_course_sheet.rb
                    app/domain/entities/catalog/import_kind.rb
                    config/initializers/imports.rb
                    app/infrastructure/repositories/catalog/course_sheet_repository.rb
                    app/jobs/catalog/import_course_sheet_job.rb
                    config/locales/catalog/imports.fr.yml
- **Dépend de**   : Lot 0
- **Test associé**: test/domain/use_cases/catalog/import_course_sheet_test.rb
                    test/infrastructure/repositories/catalog/course_sheet_repository_test.rb
                    test/integration/catalog/course_sheet_import_test.rb
- **Done quand**  : l'équipe importe un fichier de fiche sur l'écran d'import ; un fichier hostile est refusé avec un rapport par bloc ; une fiche existante est ignorée (CA-1, CA-2, CA-3, CA-4 pour l'import)

### Lot B — Lire une fiche de cours

- **Couche**      : infrastructure + delivery + ui
- **Fichiers**    : app/infrastructure/queries/catalog/course_sheet_query.rb
                    app/controllers/catalog/course_sheets_controller.rb
                    app/helpers/catalog/course_sheet_text_helper.rb
                    app/views/catalog/course_sheets/show.html.erb
                    app/views/catalog/course_sheets/_page.html.erb
                    app/views/catalog/course_sheets/blocks/_paragraph.html.erb, _box.html.erb, _simple.html.erb, _steps.html.erb, _table.html.erb
                    app/views/catalog/courses/show.html.erb
                    app/javascript/controllers/course_sheet/glossary_controller.js
                    app/javascript/controllers/course_sheet/simple_toggle_controller.js
- **Dépend de**   : Lot 0
- **Test associé**: test/controllers/catalog/course_sheets_controller_test.rb
                    test/helpers/catalog/course_sheet_text_helper_test.rb
                    test/system/catalog/course_sheet_reading_test.rb
- **Done quand**  : un élève ouvre la fiche d'une leçon publiée (fixture) et lit 3 pages dans l'habillage ; le lexique s'ouvre en bulle ; les explications simples se masquent ; refus en brouillon (CA-4, CA-5, CA-6)

### Lot C — Exercices dans la fiche et « Je m'entraîne »

- **Couche**      : domaine + ui
- **Fichiers**    : app/domain/entities/catalog/numeric_answer.rb
                    app/views/catalog/course_sheets/blocks/_exercise.html.erb
                    app/views/catalog/course_sheets/blocks/_practice.html.erb
                    app/javascript/controllers/course_sheet/exercise_controller.js
                    app/javascript/controllers/course_sheet/practice_controller.js
                    app/javascript/controllers/course_sheet/generators/bank.js
- **Dépend de**   : Lot 0
- **Test associé**: test/domain/entities/catalog/numeric_answer_test.rb
                    test/system/catalog/course_sheet_exercise_test.rb
- **Done quand**  : sur la fiche de fixture, « Vérifier » rend juste, à revoir ou à compléter avec la tolérance ±0,011 ; « Indice » et « Correction » se déplient ; le choix figé se fige ; « Je m'entraîne » sur banque compte le score une fois par énoncé (CA-7, CA-8)

### Lot D — Fiche Thalès

- **Couche**      : ui + données
- **Fichiers**    : app/views/catalog/course_sheets/kinds/_thales_figure.html.erb
                    app/javascript/controllers/course_sheet/thales_figure_controller.js
                    app/javascript/controllers/course_sheet/generators/thales_ratio.js
                    app/assets/stylesheets/course_sheet/thales_figure.css
                    db/seeds/data/course_sheets/thales.json
                    db/seeds/demo/fiches_de_cours.rb
                    db/seeds.rb
- **Dépend de**   : Lot A, Lot C, Lot G
- **Test associé**: test/system/catalog/course_sheet_thales_test.rb
                    test/integration/catalog/course_sheet_seeds_test.rb
- **Done quand**  : dans l'environnement de PR, la leçon publiée « Propriétés de Thalès dans un triangle » (3ème) a sa fiche de cours, importée par les seeds (`demo/fiches_de_cours`, étapes development et pr) ; elle se lit comme la maquette à 1 000 px et plus, et à 390 px sans défilement horizontal, figure manipulable au doigt ; points déplaçables, réciproque, réinitialisation ; exercices et générateur (CA-9). Fin de la phase 1.

### Lot E — Fiche Lentilles *(phase 2, après validation du test par Touré)*

- **Couche**      : ui + données
- **Fichiers**    : app/views/catalog/course_sheets/kinds/_lens_simulator.html.erb, _lens_construction.html.erb, _lens_diagrams.html.erb
                    app/javascript/controllers/course_sheet/lens_simulator_controller.js
                    app/javascript/controllers/course_sheet/lens_construction_controller.js
                    app/assets/stylesheets/course_sheet/lens.css
                    db/seeds/data/course_sheets/lentilles.json
- **Dépend de**   : Lot A, Lot B, Lot C
- **Test associé**: test/system/catalog/course_sheet_lens_test.rb
- **Done quand**  : la fiche Lentilles importée se lit comme la maquette ; simulateur (rayons, image virtuelle, grille) et construction (CA-10)

### Lot F — Fiche Texte argumentatif *(phase 2, après validation du test par Touré)*

- **Couche**      : ui + données
- **Fichiers**    : app/views/catalog/course_sheets/kinds/_argument_highlighter.html.erb
                    app/views/catalog/course_sheets/blocks/_writing.html.erb
                    app/javascript/controllers/course_sheet/argument_highlighter_controller.js
                    app/javascript/controllers/course_sheet/writing_controller.js
                    app/assets/stylesheets/course_sheet/argument.css
                    db/seeds/data/course_sheets/texte-argumentatif.json
- **Dépend de**   : Lot A, Lot B, Lot C
- **Test associé**: test/system/catalog/course_sheet_argument_test.rb
- **Done quand**  : la fiche importée se lit comme la maquette ; surligneurs, tableau des connecteurs, exercice à choix figé, rédaction et ses vérifications (CA-11)

### Lot G — Téléphone : pages fluides sous 1 000 px *(phase 1, retenu par Touré pour le test)*

- **Couche**      : ui
- **Fichiers**    : app/assets/stylesheets/course_sheet.css
                    app/javascript/controllers/course_sheet/glossary_controller.js
                    app/views/catalog/course_sheets/blocks/_table.html.erb
- **Dépend de**   : Lot B, Lot C
- **Test associé**: test/system/catalog/course_sheet_phone_test.rb
- **Done quand**  : à 390 px, la fiche de fixture se lit sans défilement horizontal : même couleurs, polices et rythme Seyès ; plus de hauteur A4 ; marges intérieures de 16 px ; titres réduits ; tableau en cartes ; lexique en tiroir en bas de l'écran sous 640 px ; champs et boutons d'au moins 44 px. Les lots de fiche (D, E, F) rendent leurs figures fluides dans leur propre feuille.

### Lot H — Nom à l'écran *(en attente du porteur)*

- **Couche**      : ui
- **Fichiers**    : config/locales/catalog/course_sheets.fr.yml
                    docs/guide/glossaire.md
- **Dépend de**   : réponse du porteur sur #318
- **Test associé**: test/controllers/catalog/course_sheets_controller_test.rb
- **Done quand**  : le nom retenu s'affiche sur la leçon et en titre de la fiche ; rien à faire si c'est « Fiche de cours »

## Vagues

```
Phase 1
  Vague 1 : Lot 0                  → 1 agent, séquentiel
  Vague 2 : Lot A ‖ Lot B ‖ Lot C  → 3 agents, worktrees isolés
  Vague 3 : Lot G                  → 1 agent
  Vague 4 : Lot D                  → 1 agent ; puis push et PR prête, après accord de Touré
Phase 2 (après validation du test)
  Vague 5 : Lot E ‖ Lot F          → 2 agents
Dès la réponse du porteur
  Lot H                            → 1 agent
```

Le test de la phase 1 se lit sur téléphone dès le Lot G.

Branches de lot : `feature/fiches-de-cours-lot-<x>`, créées depuis `feature/fiches-de-cours` une fois la vague précédente fusionnée dedans. Exécution : agent `executant-lot` (Sonnet), test rouge → domaine → infrastructure → delivery → UI, un commit par lot citant #318.

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/catalog.rb` | Lot 0 |
| `config/locales/catalog/course_sheets.fr.yml` | Lot 0 (valeur du nom : Lot H, après la réponse du porteur) |
| `app/views/catalog/course_sheets/_block.html.erb` | Lot 0 |
| `app/assets/stylesheets/course_sheet.css` | Lot 0 (règles sous 1 000 px : Lot G, séquentiel après B et C) |
| `test/design/design_tokens_test.rb` | Lot 0 |
| `test/fixtures/course_sheets.yml` | Lot 0 |
| `db/schema.rb` | Lot 0 |
| `app/domain/entities/catalog/import_kind.rb`, `config/initializers/imports.rb` | Lot A |
| `app/views/catalog/courses/show.html.erb` | Lot B |
| `db/seeds.rb` | Lot D |
| `app/javascript/controllers/course_sheet/glossary_controller.js` | Lot B (tiroir sous 640 px : Lot G, séquentiel) |
| `app/views/catalog/course_sheets/blocks/_table.html.erb` | Lot B (cartes : Lot G, séquentiel) |

Le Lot G reprend des fichiers du Lot 0 et du Lot B : il ne démarre qu'une fois la vague 2 fusionnée, seul.

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
