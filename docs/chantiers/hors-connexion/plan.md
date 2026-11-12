# Plan d'exécution — Lnclass hors connexion

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Références : [PRD](prd.md) · [menace](menace.md) · ADR-0133 · UDR-0170.

## Graphe

```
Lot 0 — SOCLE (séquentiel) : contrats, migration, routes, locales, layout, base locale, signataire
  ↓
  ├─► Lot A  pages gardées + purge (élève)        ┐
  ├─► Lot B  paquet + copie hors ligne + correcteur ├─ en parallèle, fichiers disjoints
  └─► Lot C  synchronisation + file + vue enseignant┘
        ↓ (A)
      Lot D  enseignant hors ligne (lecture seule)
```

Vagues : **jour 1** Lot 0 → A ‖ B ‖ C (3 agents, worktrees isolés, chacun branché sur la branche du Lot 0). **Jour 2** Lot D (1 agent), depuis `Develop` à jour, branche `feature/hors-connexion-2`. Chaque lot = une PR vers `Develop`, ouverte prête, assignée ; un lot branché sur le Lot 0 non fusionné porte son diff jusqu'à la fusion du Lot 0 par l'orchestrateur.

Contrats JavaScript gelés au Lot 0 (les lots les utilisent, ne les changent pas) :

- `app/javascript/offline/store.js` : `currentKey()`, `rememberKey(key)`, `openDb(key)`, `putPack(key, pack)`, `getPack(key, exercisePublicId)`, `putCopy(key, copy)`, `listCopies(key, { status })`, `updateCopy(key, id, patch)`, `deleteCopy(key, id)`, `purgeKey(key, { keepQueue })`, `registerBeforePurge(fn)`, `runBeforePurge()`. Forme d'une copie : ADR §4.5.
- Le layout porte `<div hidden data-controller="offline-session offline-sync">` : `offline-session` est écrit au Lot A, `offline-sync` au Lot C (Stimulus ignore un contrôleur absent).
- Le programme d'arrière-plan reçoit la clé par `postMessage({ type: "lnclass:key", key })` et marque une page servie du cache par une meta `lnclass-offline-served` injectée (Lot A).

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + fichiers partagés
- **Fichiers**     : `docs/chantiers/hors-connexion/*` · ADR et UDR `XXXX-hors-connexion-*` *(cadrage, même PR)*
                     `db/migrate/20261112120000_add_offline_columns_to_exercise_sessions.rb` · `db/schema.rb`
                     `app/domain/ports/assessment/exercise_session_repository_port.rb` (+ `record_offline_copy(session:, attempts:, client_copy_id:, received_at:)` → session ou `:duplicate` ; `find_by_client_copy_id(student_id:, client_copy_id:)`)
                     `app/domain/ports/assessment/offline_pack_signer_port.rb` (`sign(student_id:, exercise_id:, digest:, issued_at:)` → jeton ; `verify(token)` → hash ou `nil`)
                     `app/domain/entities/assessment/offline_copy_window.rb` (bornes d'heure, ADR §4.5)
                     `app/domain/dtos/assessment/offline_copy_input.rb` (UUID, horodatages ISO, réponses → `CopyInput`)
                     `app/infrastructure/repositories/assessment/offline_pack_signer.rb` (MessageVerifier, but `offline_pack`, expire 30 j)
                     `app/controllers/concerns/offline_keepable.rb` · `app/controllers/application_controller.rb` (inclut le concern)
                     `app/helpers/offline_helper.rb` (clé d'appareil HMAC)
                     `app/views/layouts/application.html.erb` (meta `lnclass-offline-key`) · `app/views/layouts/shell.html.erb` (bandeau + div `offline-session offline-sync`)
                     `app/views/shared/offline/_status_banner.html.erb` · `app/javascript/controllers/offline_status_controller.js`
                     `app/javascript/offline/store.js`
                     `config/routes/assessment.rb` (`offline_pack`, `offline_copy`, `POST /offline_copies` → `assessment/offline_copy_syncs#create`)
                     `config/locales/shared/offline.fr.yml` (toutes les clés `offline.*` de l'UDR)
                     `config/ci.rb` (étape « Node tests » : `node --test test/javascript/**/*.test.js`)
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/assessment/offline_copy_window_test.rb` · `test/domain/dtos/assessment/offline_copy_input_test.rb` · `test/infrastructure/repositories/assessment/offline_pack_signer_test.rb` · `test/integration/offline/offline_key_test.rb` (CA-2) · `test/javascript/offline/store.test.js` · `test/infrastructure/orm/exercise_session_test.rb` (index unique)
- **Done quand**   : chaque page connectée porte la clé d'appareil, le bandeau s'affiche hors ligne (navigateur en mode avion), la migration passe, les contrats sont gelés

---

## Lot A — Pages gardées et purge (élève)

- **Couche**       : delivery + ui
- **Fichiers**     : `app/views/pwa/service-worker.js` · `app/javascript/pwa.js`
                     `app/javascript/controllers/offline_session_controller.js` (clé → programme, changement de clé → purge, déconnexion → `runBeforePurge` puis purge)
                     `public/offline.html` · `public/offline.css`
                     `app/controllers/catalog/courses_controller.rb` · `app/controllers/assessment/exercises_controller.rb` · `app/controllers/classroom/student_homes_controller.rb` (`keep_offline only: :show`)
                     `app/controllers/identity/sessions_controller.rb` (`Clear-Site-Data: "cache"` sur `destroy`)
                     `test/integration/pwa_test.rb` (mise à jour : l'ADR-0082 §4.2 est amendé)
- **Dépend de**    : Lot 0
- **Test associé** : `test/integration/offline/keepable_pages_test.rb` (CA-1) · `test/integration/offline/logout_purge_test.rb` (CA-4) · `test/javascript/offline/page_cache.test.js` (CA-3, le programme chargé dans un `vm` avec `caches` et `fetch` simulés) · `test/javascript/offline/offline_session_controller.test.js` (CA-4)
- **Done quand**   : en mode avion, une leçon déjà ouverte s'ouvre avec le bandeau « Hors ligne » (navigation et visite Turbo) ; une leçon jamais ouverte montre « Pas de connexion » mis à jour ; après déconnexion, la leçon ne s'ouvre plus hors ligne. Vérifié aussi dans l'app Android (à noter dans le journal si le WebView n'exécute pas le programme)

---

## Lot B — Paquet de corrigé, copie hors ligne et correcteur

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/assessment/offline_pack_query.rb`
                     `app/controllers/assessment/offline_packs_controller.rb` · `app/controllers/assessment/offline_copies_controller.rb` (`new`, gardable)
                     `app/views/assessment/offline_copies/new.html.erb` · `app/views/assessment/offline_copies/_result.html.erb`
                     `app/views/assessment/exercises/show.html.erb` (bouton « Commencer » : `offline-start`)
                     `app/javascript/offline/grader.js`
                     `app/javascript/controllers/offline_start_controller.js` (range le paquet en ligne ; mène à la copie hors ligne)
                     `app/javascript/controllers/offline_copy_controller.js`
                     `test/fixtures/files/offline/grading_cases.json`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/assessment/offline_packs_controller_test.rb` (CA-5) · `test/infrastructure/queries/assessment/offline_pack_query_test.rb` · `test/domain/entities/assessment/offline_grading_parity_test.rb` + `test/javascript/offline/grader.test.js` (CA-6) · `test/controllers/assessment/offline_copies_controller_test.rb` · `test/javascript/offline/offline_copy_controller.test.js` (CA-7)
- **Done quand**   : un exercice ouvert en ligne se fait en mode avion ; la note s'affiche « Provisoire » avec le corrigé ; la copie est dans la base locale ; un exercice jamais ouvert garde « Commencer » désactivé avec son message

---

## Lot C — Synchronisation, copies à envoyer, vue enseignant

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/assessment/sync_offline_copy.rb`
                     `app/infrastructure/repositories/assessment/exercise_session_repository.rb` (implémente `record_offline_copy`, `find_by_client_copy_id`)
                     `app/controllers/assessment/offline_copy_syncs_controller.rb` (JSON, 20 copies, 256 Kio, 30/min)
                     `app/javascript/offline/sync.js` · `app/javascript/controllers/offline_sync_controller.js` · `app/javascript/controllers/offline_queue_controller.js`
                     `app/views/shared/offline/_pending_copies.html.erb` · `app/views/classroom/student_homes/show.html.erb` (rend le partial)
                     `app/infrastructure/queries/assessment/session_result_query.rb` (+ `received_at`) · `app/views/assessment/session_results/show.html.erb` (mention enseignant)
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/assessment/sync_offline_copy_test.rb` (CA-8 à CA-14) · `test/infrastructure/repositories/assessment/exercise_session_repository_test.rb` (rejeu concurrent) · `test/controllers/assessment/offline_copy_syncs_controller_test.rb` (CSRF, 413, 422, limite) · `test/javascript/offline/sync.test.js` (CA-15, copies d'une autre clé jamais envoyées) · `test/controllers/assessment/session_results_controller_test.rb` (CA-16)
- **Done quand**   : une copie posée en file (console ou Lot B) part au retour du réseau, apparaît une fois côté enseignant avec « Rendue hors ligne le … · reçue le … », et l'accueil élève dit « Copie envoyée · N % »

---

## Lot D — Enseignant hors ligne (lecture seule)

- **Couche**       : delivery
- **Fichiers**     : `app/controllers/classroom/teacher_homes_controller.rb` · `app/controllers/classroom/classrooms_controller.rb` · `app/controllers/classroom/classroom_students_controller.rb` · `app/controllers/classroom/assignment_follow_ups_controller.rb` · `app/controllers/assessment/session_results_controller.rb` (`keep_offline only: :show`)
                     `test/integration/offline/keepable_pages_test.rb` (liste élargie)
- **Dépend de**    : Lot A (et Lot C fusionné : `session_results_controller` n'est pas dans C, mais sa vue l'est)
- **Test associé** : `test/integration/offline/keepable_pages_test.rb` (CA-17)
- **Done quand**   : en mode avion, un enseignant rouvre une classe déjà consultée avec le bandeau « Hors ligne » ; aucune page de formulaire n'est gardée

---

## Décisions ouvertes

> Toutes tranchées par l'option prudente (porteur non joignable dans cette session) et portées dans `journal.md` § À trancher. Aucune ne bloque un lot.

- [x] Heure d'origine : gardée mais bornée [émission du paquet, réception], 30 jours au plus — appliqué
- [x] Exercice modifié entre l'ouverture et l'envoi : copie refusée « non comptée » — appliqué
- [x] Droits évalués à la réception (pas à l'heure d'origine) — appliqué
- [x] Enseignant : lecture seule, aucune écriture hors ligne — appliqué
- [x] 60 pages, 30 jours — appliqué

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/assessment.rb` | Lot 0 |
| `config/locales/shared/offline.fr.yml` | Lot 0 |
| `config/ci.rb` | Lot 0 |
| `db/schema.rb`, `db/migrate/*` | Lot 0 |
| `app/views/layouts/application.html.erb`, `shell.html.erb` | Lot 0 |
| `app/controllers/application_controller.rb` | Lot 0 |
| `app/domain/ports/assessment/exercise_session_repository_port.rb` | Lot 0 |
| `app/javascript/offline/store.js` | Lot 0 |
| `app/infrastructure/repositories/assessment/offline_pack_signer.rb` | Lot 0 (B le lit, C le lit) |
| `app/controllers/assessment/exercises_controller.rb` | Lot A |
| `app/views/assessment/exercises/show.html.erb` | Lot B |
| `app/controllers/classroom/student_homes_controller.rb` | Lot A |
| `app/views/classroom/student_homes/show.html.erb` | Lot C |
| `app/views/assessment/session_results/show.html.erb` | Lot C |
| `app/controllers/assessment/session_results_controller.rb` | Lot D |
| `test/integration/offline/keepable_pages_test.rb` | Lot A, puis Lot D (séquentiel) |
| `app/infrastructure/repositories/assessment/exercise_session_repository.rb` | Lot C |

Contrôle mécanique (`awk … | uniq -d`) : seul `keepable_pages_test.rb` sort, entre A et D, séquentiels.

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
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR *(ici : une PR par lot, consigne de l'orchestrateur)*
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Ici : mode avion réel (Chrome Android et Safari iPhone), copie rendue hors ligne puis réseau rétabli, et la même copie rejouée deux fois.
