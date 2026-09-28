# Plan d'exécution — Photo de profil

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Chantier court, exécuté par un seul agent dans le worktree `feature/photo-de-profil` : les lots A, B et C sont parallélisables sur le papier mais ont été enchaînés.

## Graphe

```
Lot 0 — SOCLE (contrats : en-têtes d'image, règles, port, audit, routes, locales, has_one_attached, ui_avatar)
  ↓
  ├─► Lot A « ajouter / changer sa photo »   ┐
  ├─► Lot B « retirer sa photo »              ├─ en parallèle, fichiers disjoints
  └─► Lot C « voir une photo »                ┘
```

---

## Lot 0 — Socle

- **Couche**       : domaine (contrats) + infrastructure + fichiers partagés
- **Fichiers**     : `app/domain/entities/identity/image_header.rb`
                     `app/domain/entities/identity/profile_photo.rb`
                     `app/domain/entities/identity/audit_action.rb`
                     `app/domain/ports/identity/profile_photo_store_port.rb`
                     `app/infrastructure/orm/user.rb` (`has_one_attached :photo`)
                     `app/infrastructure/repositories/identity/profile_photo_store.rb`
                     `app/infrastructure/queries/identity/photo_versions.rb`
                     `app/helpers/components_helper.rb` (`ui_avatar` : `xl`, `loading`) · `app/helpers/profile_photos_helper.rb`
                     `config/routes/identity.rb` · `config/locales/identity/profile_photos.fr.yml` *(fichiers partagés)*
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/identity/image_header_test.rb` · `test/infrastructure/repositories/identity/profile_photo_store_test.rb` · `test/helpers/components_helper_test.rb`
- **Done quand**   : le port est gelé, l'adaptateur attache, relit et efface une photo sur le service Active Storage, et `ui_avatar` rend une photo ronde

---

## Lot A — Ajouter ou changer sa photo

- **Couche**       : domaine + delivery + ui + front
- **Fichiers**     : `app/domain/dtos/identity/profile_photo_input.rb`
                     `app/domain/use_cases/identity/change_own_photo.rb`
                     `app/controllers/identity/profile_photos_controller.rb` (`edit`, `update`)
                     `app/views/identity/profile_photos/edit.html.erb`
                     `app/views/identity/profiles/_information.html.erb`
                     `app/infrastructure/queries/identity/profile_query.rb`
                     `app/javascript/controllers/identity/photo_picker_controller.js`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/dtos/identity/profile_photo_input_test.rb` · `test/domain/use_cases/identity/change_own_photo_test.rb` · `test/controllers/identity/profile_photos_controller_test.rb` · `test/system/identity/profile_photo_test.rb`
- **Done quand**   : un élève choisit une photo, voit l'aperçu recadré, enregistre, et la voit dans sa carte et son menu (PH-01, PH-02, PH-04, PH-07)

---

## Lot B — Retirer sa photo

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : `app/domain/use_cases/identity/remove_own_photo.rb`
                     (action `destroy` du contrôleur du lot A, bouton de la modale du lot A — *remontés au lot A, voir la collision*)
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/identity/remove_own_photo_test.rb`
- **Done quand**   : « Retirer ma photo » efface le fichier et les initiales reviennent (PH-03)

---

## Lot C — Voir une photo (soi, ses élèves, l'équipe)

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/identity/read_account_photo.rb`
                     `app/controllers/identity/account_photos_controller.rb`
                     `app/controllers/authenticated_controller.rb` · `app/infrastructure/queries/identity/shell_user_query.rb`
                     `app/infrastructure/queries/classroom/classroom_overview_query.rb` · `app/views/classroom/classrooms/_roster.html.erb`
                     `app/infrastructure/queries/identity/account_lookup_query.rb` · `app/views/teams/account_lookups/_result.html.erb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/identity/read_account_photo_test.rb` · `test/controllers/identity/account_photos_controller_test.rb`
- **Done quand**   : la photo s'affiche dans le menu du compte, la liste de la classe et le compte retrouvé ; un autre élève reçoit 403 (PH-05)

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/identity.rb` | Lot 0 |
| `config/locales/identity/profile_photos.fr.yml` | Lot 0 |
| `app/helpers/components_helper.rb` | Lot 0 |
| `app/domain/entities/identity/audit_action.rb` | Lot 0 |
| `app/controllers/identity/profile_photos_controller.rb` | Lot A (l'action `destroy` du lot B y vit : le lot B ne livre que son use case, branché par le lot A) |
| `app/views/identity/profile_photos/edit.html.erb` | Lot A (idem, bouton « Retirer ma photo ») |
| `app/views/identity/profiles/_information.html.erb` | Lot A |
| `app/infrastructure/queries/identity/profile_query.rb` | Lot A |

Hors chantier, en parallèle : `feature/code-etablissement` touche `config/routes/identity.rb` (autres lignes) et `school_detail_query.rb` (d'où l'absence de photo dans la liste des enseignants) ; `feature/bareme-classes` ajoute des actions à `audit_action.rb` (ajout sur une ligne séparée pour limiter le conflit) ; `fix/finitions-generation-menu` et `feature/cycles-en-radio` touchent `components_helper.rb` hors de `ui_avatar`.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md`
- [x] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md`
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
