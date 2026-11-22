# Plan d'exécution — Hors connexion total après installation

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Références : [`prd.md`](prd.md) · [`menace.md`](menace.md) · ADR-XXXX-hors-connexion-total-catalogue-telecharge · UDR-XXXX-hors-connexion-telechargement-et-file-enseignant.

## Graphe

```
JOUR 1 — branche feature/hors-connexion-total
Lot 0 — SOCLE (séquentiel)
  ↓
  ├─► Lot A  catalogue téléchargé (liste, pages neutres, images, programme, carte)  ┐
  ├─► Lot B  corrigés en lot et versions d'exercice                                ├─ en parallèle
  ├─► Lot C  entraînement de notion hors ligne                                     │
  └─► Lot D  enseignant : pages gardées (lecture)                                  ┘

JOUR 2 — branche feature/hors-connexion-total-2, depuis Develop
  Lot E  enseignant : écritures hors ligne et file   (dépend de 0 et D)
```

Vagues :

```
Jour 1, vague 1 : Lot 0                       → 1 agent, séquentiel
Jour 1, vague 2 : Lot A ‖ Lot B ‖ Lot C ‖ Lot D → 4 agents, worktrees isolés
Jour 2, vague 1 : Lot E                       → 1 agent
```

- Chaque lot de la vague 2 part de `feature/hors-connexion-total`, **une fois le Lot 0 fusionné dedans**. Branches : `feature/hors-connexion-total-lot-a`, etc., chacune dans son worktree (`git worktree add ../lnclass-hors-connexion-total-lot-a -b feature/hors-connexion-total-lot-a feature/hors-connexion-total`).
- Le soir du jour 1 : une PR `feature/hors-connexion-total` → `Develop`. Le jour 2 repart de `Develop`.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + fichiers partagés
- **Fichiers**     : `db/migrate/<ts>_create_exercise_versions.rb`
                     `db/migrate/<ts>_create_offline_action_receipts.rb`
                     `db/migrate/<ts>_add_offline_columns_to_assignments.rb`
                     `db/schema.rb`
                     `app/infrastructure/orm/assessment/exercise_version.rb`
                     `app/infrastructure/orm/shared/offline_action_receipt.rb`
                     `app/domain/ports/catalog/offline_catalog_port.rb`
                     `app/domain/ports/assessment/exercise_version_repository_port.rb`
                     `app/domain/ports/shared/offline_action_receipt_port.rb`
                     `app/domain/entities/billing/access.rb` *(ajout `ends_on`)*
                     `app/controllers/concerns/offline_keepable.rb` *(`keep_offline_catalog`, `offline_neutral?`)*
                     `app/helpers/offline_helper.rb` *(`offline_neutral?` pour les vues ; pas de clé en rendu neutre)*
                     `app/views/layouts/shell.html.erb` *(coque neutre : sans nom, avatar, menu de compte ni clé)*
                     `app/javascript/offline/packs.js` *(contrat gelé : `export async function fetchPacks(key, publicIds)`, corps vide qui rend `{}`, implémenté au Lot B)*
                     `config/routes/catalog.rb` · `config/routes/assessment.rb` · `config/routes/classroom.rb`
                     `config/locales/shared/offline.fr.yml` *(toutes les clés `offline.download.*`, `offline.actions.*`, `offline.access_ended.*` de l'UDR)*
                     `test/fixtures/files/offline/grading_cases.json` *(cas des types de l'entraînement ajoutés, attendus fixés par Ruby)*
                     `test/fixtures/` *(toute fixture partagée)*
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/billing/access_test.rb` (`ends_on` : abonné, essai, bêta, bloqué) ; `test/integration/offline/neutral_layout_test.rb` (la coque neutre ne porte ni nom ni clé) ; `test/infrastructure/orm/offline_tables_test.rb` (index uniques)
- **Done quand**   : les migrations passent, les trois ports sont gelés, les routes répondent 501 ou un squelette vide, et une page rendue avec `Lnclass-Offline-Fetch: catalog` sort sans nom ni clé d'appareil

---

## Lot A — Catalogue téléchargé : liste, pages neutres, images, programme d'arrière-plan, carte

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/catalog/offline_catalog_query.rb`
                     `app/controllers/catalog/offline_catalogs_controller.rb`
                     `app/controllers/catalog/courses_controller.rb` *(`keep_offline_catalog only: :show`)*
                     `app/controllers/assessment/exercises_controller.rb` *(idem)*
                     `app/controllers/assessment/offline_copies_controller.rb` *(idem sur `new`)*
                     `app/views/catalog/courses/show.html.erb` · `app/views/catalog/courses/_student_lesson.html.erb` · `app/views/catalog/courses/_prepare_sheets.html.erb` · `app/views/catalog/revision_sheets/_todo.html.erb` *(parties de compte tues en rendu neutre)*
                     `app/controllers/assessment/question_images_controller.rb` *(aucun changement de cache attendu ; seulement si un en-tête manque)*
                     `app/views/pwa/service-worker.js`
                     `public/offline-access-ended.html` · `public/offline.html` *(consigne du premier lancement)*
                     `app/views/identity/` *(texte de l'invitation à installer : garder l'application ouverte jusqu'à la fin du téléchargement ; fichier exact relevé au départ du lot)*
                     `app/javascript/offline/download.js`
                     `app/javascript/offline/controllers/download_controller.js`
                     `app/javascript/offline/controllers.js` · `app/javascript/offline/lazy_controllers.js` *(enregistrement de `offline-download`)*
                     `app/javascript/offline/controllers/session_controller.js` *(envoi de la liste au programme, purge à la déconnexion)*
                     `app/views/shared/offline/_download_card.html.erb`
                     `app/views/classroom/student_homes/show.html.erb` *(rendu de la carte)*
                     `app/controllers/classroom/student_offlines_controller.rb` · `app/views/classroom/student_offlines/show.html.erb`
                     `app/views/shared/navigation/_avatar_menu.html.erb` *(ligne « Hors connexion »)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/integration/offline/catalog_list_test.rb` (CA-1, CA-2, CA-3, CA-26, CA-27) ; `test/system/offline/first_launch_test.rb` (CA-28) ; `test/integration/offline/neutral_pages_test.rb` (CA-4) ; `test/javascript/offline/download.test.js` (CA-5, CA-6, CA-7) ; `test/javascript/offline/page_cache.test.js` étendu (CA-8 à CA-12) ; `test/integration/offline/media_test.rb` (CA-18) ; `test/system/offline/download_card_test.rb` (parcours de la carte, 390 px)
- **Done quand**   : dans l'application installée simulée, un élève de 3e télécharge son niveau depuis la carte de l'accueil, coupe le réseau et ouvre une leçon jamais visitée avec ses images. Un second compte sans accès voit « Pas de connexion » sur une leçon payante.

> Le Lot A appelle `fetchPacks` (`offline/packs.js`, contrat du Lot 0) pour chaque leçon téléchargée. Tant que le Lot B n'est pas fusionné, l'appel rend `{}` et le téléchargement des pages marche seul.

---

## Lot B — Corrigés en lot et versions d'exercice

- **Couche**       : domaine + infrastructure + delivery + ui (JS)
- **Fichiers**     : `app/domain/use_cases/assessment/issue_offline_packs.rb`
                     `app/domain/use_cases/assessment/sync_offline_copy.rb` *(version gardée ; `:version_expired` remplace `:stale`)*
                     `app/infrastructure/repositories/assessment/exercise_version_repository.rb`
                     `app/infrastructure/queries/assessment/offline_pack_query.rb` *(enregistre la version à la remise)*
                     `app/controllers/assessment/offline_packs_controller.rb` *(`create` en lot ; `show` enregistre la version)*
                     `app/jobs/assessment/purge_exercise_versions_job.rb` · `config/recurring.yml`
                     `app/javascript/offline/packs.js` *(implémentation du contrat)*
                     `app/views/shared/offline/_pending_copies.html.erb` *(motifs `version_expired` à la place de `stale`, et `account_inactive`)*
                     `app/views/assessment/session_results/` *(mention « Corrigé disponible sur l'appareil de l'élève »)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/assessment/issue_offline_packs_test.rb` (CA-13) ; `test/domain/use_cases/assessment/sync_offline_copy_test.rb` amendé (CA-14, CA-15, CA-16, CA-26 refus `account_inactive`) ; `test/infrastructure/repositories/assessment/exercise_version_repository_test.rb` ; `test/javascript/offline/packs.test.js`
- **Done quand**   : une copie hors ligne faite sur une version d'exercice modifiée depuis 3 jours est envoyée et comptée, et une copie sur une version remplacée depuis 31 jours est refusée « version expirée ».

---

## Lot C — Entraînement de notion hors ligne

- **Couche**       : ui (vue neutre + JS) + test de parité
- **Fichiers**     : `app/views/catalog/revision_sheets/_practice.html.erb` *(bloc `application/json data-offline-practice` en rendu neutre seulement)*
                     `app/javascript/offline/grader.js` *(types de l'entraînement)*
                     `app/javascript/offline/practice.js`
                     `app/javascript/controllers/catalog/` *(contrôleur de l'entraînement existant : bascule sur `practice.js` quand le réseau manque)*
                     `test/domain/entities/assessment/offline_grading_parity_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/javascript/offline/grader.test.js` étendu et `offline_grading_parity_test.rb` (CA-17) ; `test/integration/offline/practice_answers_test.rb` (les réponses n'apparaissent jamais dans une page servie à la navigation)
- **Done quand**   : réseau coupé, un élève répond à un entraînement de notion d'une leçon téléchargée et voit chaque réponse corrigée, sans aucune requête vers le serveur.

---

## Lot D — Enseignant : pages gardées (lecture)

- **Couche**       : delivery + ui
- **Fichiers**     : `app/controllers/classroom/teacher_homes_controller.rb`
                     `app/controllers/classroom/classrooms_controller.rb`
                     `app/controllers/classroom/classroom_students_controller.rb`
                     `app/controllers/classroom/assignment_follow_ups_controller.rb`
                     `app/controllers/assessment/session_results_controller.rb` *(`keep_offline only: :show` sur les cinq)*
                     `app/controllers/classroom/assignments_controller.rb` *(`keep_offline only: :new`)* · `app/controllers/classroom/session_days_controller.rb` *(`keep_offline only: :edit`)*
                     `app/views/layouts/` **non** : la coque porte déjà `offline-session` et `offline-status`
                     `test/integration/offline/keepable_pages_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/integration/offline/keepable_pages_test.rb` étendu (CA-19)
- **Done quand**   : un enseignant ouvre en ligne son accueil et une classe, coupe le réseau et relit les deux pages ; une page d'équipe ou de facturation n'est jamais gardée.

---

## Lot E — Enseignant : écritures hors ligne et file (jour 2)

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/classroom/sync_offline_action.rb`
                     `app/infrastructure/repositories/shared/offline_action_receipt_repository.rb`
                     `app/controllers/classroom/offline_actions_controller.rb`
                     `app/domain/use_cases/classroom/assign_resource.rb` · `assign_exercise_batch.rb` *(paramètres facultatifs `made_offline_at:`, `received_at:`)*
                     `app/infrastructure/repositories/classroom/assignment_repository.rb` *(écriture des deux colonnes)*
                     `app/javascript/offline/actions.js` · `app/javascript/offline/controllers/actions_controller.js`
                     `app/javascript/offline/store.js` *(magasin `actions`, version 2 de la base)*
                     `app/javascript/offline/sync.js` *(envoi des actions après les copies)*
                     `app/views/shared/offline/_pending_copies.html.erb` → `_pending_queue.html.erb` *(renommage, `kind:`)*
                     `app/views/classroom/teacher_homes/show.html.erb` · `app/views/classroom/classrooms/show.html.erb` *(file, boutons désactivés hors ligne)*
                     `app/views/classroom/assignment_follow_ups/show.html.erb` *(mention « Donné hors connexion le …, arrivé le … »)*
                     `app/views/classroom/assignments/new.html.erb` · `app/views/classroom/session_days/edit.html.erb` *(formulaires marqués `data-offline-action` ; leurs contrôleurs sont au Lot D)*
- **Dépend de**    : Lot 0, Lot D
- **Test associé** : `test/domain/use_cases/classroom/sync_offline_action_test.rb` (CA-20, CA-21, CA-22, CA-25) ; `test/integration/offline/offline_actions_test.rb` ; `test/javascript/offline/actions.test.js` (CA-23) ; `test/system/offline/teacher_offline_test.rb` (CA-24)
- **Done quand**   : hors ligne, un enseignant donne un devoir et règle ses jours de cours ; au retour du réseau, le devoir existe une seule fois avec « Donné hors connexion le …, arrivé le … », et un devoir donné sur une classe archivée entre-temps est montré « non envoyé ».

---

## Décisions ouvertes

Toutes tranchées par le porteur le 2026-11-22 (memo, Q1 à Q8). Restent, réversibles, appliquées dans leur version prudente et à reporter dans `## À trancher` du journal :

- [x] Seuil « Wi-Fi » : réseau inconnu (Safari) traité comme données mobiles — prudent pour le forfait.
- [x] 2 demandes à la fois par appareil pendant le téléchargement — prudent pour le serveur.
- [x] Marque « corrigé reçu » renommée « Corrigé disponible sur l'appareil de l'élève » — vraie, pas cachée.
- [ ] Grill Q12 : l'enseignant ne donne hors ligne que depuis une page de choix déjà ouverte (appliqué) ; recommandé : télécharger le catalogue de ses niveaux. Si le porteur choisit l'extension, elle s'ajoute au Lot E sans rouvrir le Lot 0 (même liste, filtre « enseignant », sans corrigé).
- [ ] Grill Q13 : premier lancement sans réseau — consigne dans « Pas de connexion » (appliqué).
- [ ] Grill Q14 : annonces, progression, archive, « Mon compte » — hors périmètre (appliqué) ; recommandé : chantier de suivi `hors-connexion-ecrans-eleve`.
- [ ] Grill arrêté à Q14 par le porteur : angles restants (enseignant dans deux établissements, quota iPhone, charge un jour de rentrée) à reprendre avant le départ du Lot 0.

## Couverture des critères d'acceptation

| CA | Lot |
|---|---|
| CA-1 à CA-12, CA-18, CA-26 (purge), CA-27, CA-28 | A |
| CA-13 à CA-16, CA-26 (refus de la copie) | B |
| CA-17 | C |
| CA-19 | D |
| CA-20, CA-21, CA-22, CA-23, CA-24, CA-25 | E |

Aucun critère orphelin.

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/catalog.rb` · `config/routes/assessment.rb` · `config/routes/classroom.rb` | Lot 0 |
| `config/locales/shared/offline.fr.yml` | Lot 0 |
| `app/views/layouts/shell.html.erb` | Lot 0 |
| `app/controllers/concerns/offline_keepable.rb` · `app/helpers/offline_helper.rb` | Lot 0 |
| `app/javascript/offline/packs.js` | Lot 0 (contrat), puis Lot B (implémentation) — séquentiel |
| `test/fixtures/files/offline/grading_cases.json` | Lot 0 |
| `db/schema.rb` | Lot 0 |
| `app/views/pwa/service-worker.js` | Lot A |
| `app/javascript/offline/controllers.js` · `lazy_controllers.js` · `controllers/session_controller.js` | Lot A |
| `app/controllers/assessment/offline_copies_controller.rb` · `exercises_controller.rb` | Lot A |
| `app/controllers/assessment/offline_packs_controller.rb` | Lot B |
| `app/views/shared/offline/_pending_copies.html.erb` | Lot B (jour 1), puis Lot E (jour 2) — séquentiel |
| `app/javascript/offline/grader.js` | Lot C |
| `app/controllers/assessment/session_results_controller.rb` | Lot D (contrôleur) ; Lot B ne touche que ses vues |
| `test/integration/offline/keepable_pages_test.rb` | Lot D |
| `app/javascript/offline/store.js` · `sync.js` | Lot E |
| `app/controllers/classroom/assignments_controller.rb` · `session_days_controller.rb` | Lot D (contrôleurs) ; Lot E ne touche que leurs vues |

Contrôle mécanique (`awk … | sort | uniq -d`) : à relancer après toute modification du plan. Les doublons attendus sont les deux fichiers séquentiels du tableau.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Ici : application installée simulée (Playwright, `display-mode: standalone`), téléchargement du niveau, réseau coupé (`context.setOffline(true)`), leçon jamais ouverte lue avec ses images, entraînement corrigé ; chemin d'erreur : second compte sans accès sur le même contexte → « Pas de connexion » sur une leçon payante. Jour 2 : devoir donné hors ligne, réseau rendu, devoir créé une fois.

## Chantiers de suivi

- `hors-connexion-android` : programme d'arrière-plan dans le WebView des apps Hotwire Native, recette sur un vrai appareil.
- `hors-connexion-ecrans-eleve` : annonces, progression, archive, « Mon compte » (si le porteur le décide, Q14).
