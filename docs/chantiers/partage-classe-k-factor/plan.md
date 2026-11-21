# Plan d'exécution — Partage de la classe et mesure du k-factor élève

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> PRD : [`prd.md`](prd.md) · ADR-XXXX-attribution-des-inscriptions-eleves · UDR-XXXX-partage-de-classe-qr-affiche-invitation.

## Graphe

```
Lot 0 — SOCLE (séquentiel) : tables, entités, ports, repositories, helper QR, routes
  ↓
  ├─► Lot A  QR de classe (enseignant)           ┐
  ├─► Lot B  « Invite tes camarades » (élève)    │
  ├─► Lot C  Attribution à l'inscription         ├─ en parallèle
  ├─► Lot D  Affiche A4 et kit d'établissement   │
  └─► Lot E  k-factor sur la page Croissance     ┘
```

Dispatch :

```
Vague 1 : Lot 0                              → 1 agent, séquentiel, sur feature/partage-classe-k-factor
Vague 2 : Lot A ‖ Lot B ‖ Lot C ‖ Lot D ‖ Lot E → 5 agents, worktrees isolés (feature/partage-classe-k-factor-lot-<x>)
Fin     : fusion des lots dans la branche de chantier, revues, bin/ci-quiet, une PR prête vers Develop
```

Tout tient dans la journée du 2026-11-20 : une seule PR. Si une vague déborde, la suite repart de `Develop` sur `feature/partage-classe-k-factor-2`.

**Voisinage** : `entree-eleve-unifiee` (même programme) réécrit le formulaire d'inscription élève. Le Lot C n'y ajoute que deux champs cachés et leur lecture ; la seconde PR fusionnée se rebase sur la première.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats)
- **Fichiers**     : `db/migrate/20261120100000_create_signup_attributions_and_student_invite_codes.rb` · `db/schema.rb`
                     `app/infrastructure/orm/signup_attribution.rb` · `app/infrastructure/orm/student_invite_code.rb`
                     `app/domain/entities/classroom/signup_source.rb` · `app/domain/entities/classroom/invite_code.rb`
                     `app/domain/ports/classroom/signup_attribution_repository_port.rb` · `app/domain/ports/classroom/invite_code_repository_port.rb`
                     `app/infrastructure/repositories/classroom/signup_attribution_repository.rb` · `app/infrastructure/repositories/classroom/invite_code_repository.rb`
                     `app/helpers/classroom/join_qr_helper.rb` (`class_join_qr_svg(link_token)` → SVG du lien `?s=qr`)
                     `config/routes/classroom.rb` (`classroom_poster`, `school_posters`, `class_invite`)
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/classroom/signup_source_test.rb` · `test/domain/entities/classroom/invite_code_test.rb`
                     `test/infrastructure/repositories/classroom/signup_attribution_repository_test.rb` · `test/infrastructure/repositories/classroom/invite_code_repository_test.rb`
                     `test/helpers/classroom/join_qr_helper_test.rb`
- **Done quand**   : `bin/rails db:migrate` crée les deux tables avec leurs contraintes ; les critères « attribution unique », « code stable et opaque », « code d'un anonymisé » passent ; le helper rend un SVG qui décode vers `/c/<jeton>?s=qr`

## Lot A — QR de la classe (enseignant, direction, équipe)

- **Couche**       : ui
- **Fichiers**     : `app/views/classroom/classrooms/_link.html.erb` · `config/locales/classroom/classrooms.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/classroom/classrooms_qr_test.rb` (page de la classe : bouton, QR, lien de l'affiche ; avertissement du changement de lien)
- **Done quand**   : sur la page d'une classe, « QR code » ouvre une fenêtre avec le QR de `/c/<jeton>?s=qr` et « Imprimer l'affiche » ; la confirmation « Changer le lien » prévient pour les affiches

## Lot B — « Invite tes camarades » (élève)

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/classroom/invite_classmates.rb` · `app/domain/policies/classroom/invite_classmates_policy.rb`
                     `app/controllers/classroom/class_invites_controller.rb`
                     `app/infrastructure/queries/classroom/student_home_query.rb` (`has_teacher` dans `Row`)
                     `app/views/classroom/student_homes/_invite_classmates.html.erb` · `app/views/classroom/student_homes/show.html.erb`
                     `config/locales/classroom/student_homes.fr.yml` · `config/locales/classroom/class_invites.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/classroom/invite_classmates_test.rb` · `test/controllers/classroom/class_invites_controller_test.rb` · `test/controllers/classroom/student_homes_invite_test.rb`
- **Done quand**   : un élève de la 3e B touche « Invite tes camarades » et arrive sur WhatsApp avec « Rejoins la classe 3e B de … : …/c/<jeton>?i=<code> », même code au second envoi ; l'invitation de l'enseignant ne s'affiche plus quand la classe a un enseignant

## Lot C — Attribution à l'inscription

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : `app/domain/dtos/classroom/student_registration_input.rb` (`arrival_source`, `invite_code`)
                     `app/domain/use_cases/classroom/register_student.rb` (ports `attributions:`, `invite_codes:` ; écrit dans la transaction)
                     `app/controllers/classroom/student_registrations_controller.rb` · `app/controllers/classroom/joins_controller.rb` (lit `s` et `i`)
                     `app/views/classroom/student_registrations/_form.html.erb` (deux champs cachés)
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/classroom/register_student_test.rb` · `test/controllers/classroom/student_registrations_controller_test.rb` · `test/controllers/classroom/joins_controller_test.rb`
- **Done quand**   : une inscription depuis `/c/<jeton>?s=qr`, `?i=<code>`, sans paramètre, par code et par la cascade écrit respectivement `qr`, `student_invite` (+ invitant), `teacher_link`, `code`, `cold` ; un code inconnu n'échoue jamais ; une inscription refusée n'écrit rien et garde `s` et `i`

## Lot D — Affiche A4 et kit d'établissement

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/policies/classroom/print_school_posters_policy.rb`
                     `app/infrastructure/queries/classroom/poster_query.rb`
                     `app/controllers/classroom/posters_controller.rb` · `app/controllers/classroom/school_posters_controller.rb`
                     `app/views/classroom/posters/_poster.html.erb` · `app/views/classroom/posters/show.html.erb` · `app/views/classroom/school_posters/show.html.erb`
                     `app/views/school_admin/schools/show.html.erb` · `app/views/teams/schools/show.html.erb` (bouton du kit)
                     `config/locales/classroom/posters.fr.yml` · `config/locales/school_admin/schools.fr.yml` · `config/locales/teams/schools.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/classroom/posters_controller_test.rb` · `test/controllers/classroom/school_posters_controller_test.rb` · `test/domain/policies/classroom/print_school_posters_policy_test.rb`
- **Done quand**   : l'enseignant imprime l'A4 de sa classe (nom, établissement, QR `?s=qr`, 3 étapes) ; la direction imprime le kit de son établissement (une A4 par classe ouverte) ; 404 pour un autre enseignant ou établissement, 403 pour un élève

## Lot E — k-factor élève sur la page Croissance

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/classroom/signup_k_factor_query.rb`
                     `app/controllers/teams/growth_controller.rb`
                     `app/views/teams/growth/_signup_k.html.erb` · `app/views/teams/growth/show.html.erb`
                     `config/locales/teams/growth.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/classroom/signup_k_factor_query_test.rb` · `test/controllers/teams/growth_controller_test.rb`
- **Done quand**   : l'équipe lit, pour la période, le k par établissement et par classe (Inscrits · QR · Invitation · Lien · Code · À froid · k), une ligne de total, « Mesuré depuis le … », sans aucun nom d'élève ; période vide dite

---

## Rattachement des critères d'acceptation (PRD §4)

| Critère | Lot |
|---|---|
| Attribution unique, code stable et opaque, code d'un anonymisé | 0 |
| QR de la classe, avertissement du changement de lien | A |
| L'élève invite, code réutilisé, élève sans classe, une seule bannière | B |
| QR, invitation, code inconnu, lien/code/cascade, inscription refusée | C |
| Affiche de l'enseignant, kit de la direction | D |
| k par classe et établissement, période vide, autres rôles refusés | E |

Aucun critère orphelin.

## Décisions ouvertes

> Aucune décision bloquante : D4 est tranchée par le porteur (2026-11-20) ; les choix réversibles sont appliqués dans leur version prudente et écrits dans `journal.md` § À trancher.

- [x] Définition du k affiché — appliqué : celle du playbook (QR + invitation ÷ inscrits), colonnes séparées pour lire le k strict.
- [x] Place de l'invitation de l'enseignant sur l'accueil — appliqué : seulement si la classe n'a aucun enseignant.

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/classroom.rb` | Lot 0 |
| `db/schema.rb`, `db/migrate/*` | Lot 0 |
| `app/helpers/classroom/join_qr_helper.rb` (lu par A et D) | Lot 0 |
| `app/infrastructure/repositories/classroom/invite_code_repository.rb` (lu par B et C) | Lot 0 |
| `config/locales/classroom/classrooms.fr.yml` | Lot A |
| `config/locales/classroom/student_homes.fr.yml`, `class_invites.fr.yml` | Lot B |
| `app/views/classroom/student_registrations/_form.html.erb` | Lot C |
| `config/locales/classroom/posters.fr.yml`, `school_admin/schools.fr.yml`, `teams/schools.fr.yml` | Lot D |
| `config/locales/teams/growth.fr.yml` | Lot E |

Contrôle mécanique (`awk … | uniq -d`) : vide.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL sur chaque fichier créé dans `app/`
- [x] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [x] `journal.md` clos (dérapages, dette, chantiers de suivi)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Ici : il scanne (décode) le QR de l'affiche, s'inscrit par ce lien puis par un lien d'invitation d'élève, et lit les deux inscriptions dans la section k de la page Croissance ; chemin d'erreur : un lien `?i=` inconnu s'inscrit quand même, et un enseignant d'une autre classe reçoit 404 sur l'affiche.
