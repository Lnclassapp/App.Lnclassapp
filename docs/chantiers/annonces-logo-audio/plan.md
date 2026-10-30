# Plan d'exécution — Annonces : le logo officiel, un audio de 10 secondes téléchargeable, plus de « Toutes les annonces »

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
(pas de Lot 0 : aucun port, aucune table, aucune route ; les bornes vivent dans des fichiers du seul Lot A)
  ├─► Lot A « joindre un audio de 10 s au plus »          ┐ en parallèle,
  └─► Lot B « lire, télécharger, logo, sans le lien »     ┘ fichiers disjoints
```

---

## Lot A — Joindre un audio de 10 secondes au plus

- **Couche**       : domaine + delivery (formulaire) + ui
- **Fichiers**     : `app/domain/entities/communication/audio_duration.rb` *(nouveau)*
                     `app/domain/entities/communication/message.rb` (bornes `AUDIO_MAX_SECONDS`, `AUDIO_SLACK_SECONDS`, `AUDIO_MAX_MEGABYTES`)
                     `app/domain/dtos/communication/message_input.rb` (`audio_is_short`, poids 1 Mo)
                     `app/views/communication/authored_messages/_form.html.erb` (champ audio, UDR-0071 amendement du 2026-10-30 §3.8)
                     `app/javascript/controllers/communication/audio_duration_controller.js` *(nouveau)*
                     `config/locales/communication/authored_messages.fr.yml`
                     `test/domain/entities/communication/audio_duration_test.rb` *(nouveau)*, `test/domain/dtos/communication/message_input_test.rb`,
                     `test/controllers/communication/authored_messages_controller_test.rb`, `test/system/communication/announcement_audio_duration_test.rb` *(nouveau)*,
                     `test/fixtures/files/audio/*` (fichiers réels de 9 s et 11 s, MP3 et M4A, et `README.txt`)
- **Dépend de**    : —
- **Test associé** : LA-2, LA-3, LA-4, LA-5, LA-6 ; menaces M1 à M8 de l'ADR
- **Done quand**   : un audio de 11 s est refusé dans le navigateur et, contrôle contourné, en 422 avec la durée lue ; un audio de 9 s est publié

---

## Lot B — Lire, télécharger, logo, plus de « Toutes les annonces »

- **Couche**       : delivery + ui
- **Fichiers**     : `app/controllers/communication/message_files_controller.rb` (pièce jointe sur `download`)
                     `app/views/communication/messages/_card.html.erb` (logo, « Télécharger »)
                     `app/views/communication/messages/_carousel.html.erb` (`link:` → `student:`, plus de lien)
                     `app/views/classroom/student_homes/show.html.erb`, `app/views/communication/message_dismissals/create.turbo_stream.erb`, `destroy.turbo_stream.erb` (`student: true`)
                     `app/controllers/communication/inboxes_controller.rb`, `app/views/communication/inboxes/show.html.erb` (en-têtes : « Toutes les annonces » ne nomme plus la page)
                     `config/locales/communication/messages.fr.yml` (`audio.download`, `audio.download_label`), `config/locales/communication/inboxes.fr.yml` (retrait de `carousel.all`)
                     `test/controllers/communication/message_files_controller_test.rb`, `test/views/communication/carousel_test.rb`, `test/views/communication/card_test.rb` *(nouveau si absent)*,
                     `test/controllers/school_admin/home_announcements_test.rb`, `test/controllers/classroom/teacher_homes_controller_test.rb`, `test/controllers/classroom/student_homes_controller_test.rb`,
                     `test/controllers/communication/message_dismissals_controller_test.rb`, `test/system/communication/announcements_journey_test.rb`, `test/system/communication/student_announcements_test.rb`
- **Dépend de**    : —
- **Test associé** : LA-1, LA-7, LA-8 ; menaces M9, M10
- **Done quand**   : une carte de l'équipe est signée du logo officiel ; « Télécharger » rend `annonce-<public_id>.mp3` en pièce jointe, 404 hors droit ; aucun accueil ne montre « Toutes les annonces »

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `app/domain/**`, `_form.html.erb`, `audio_duration_controller.js`, `authored_messages.fr.yml` | Lot A |
| `_card.html.erb`, `_carousel.html.erb`, `message_files_controller.rb`, `messages.fr.yml`, `inboxes.fr.yml` | Lot B |
| `docs/chantiers/annonces-logo-audio/journal.md` | orchestrateur (à la clôture) |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture) — ici, amendement daté de l'UDR-0071
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle — sans objet, aucun port
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [x] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
