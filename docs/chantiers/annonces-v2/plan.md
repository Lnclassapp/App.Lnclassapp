# Plan d'exécution — Annonces, deuxième version — saisie guidée, illustrations de l'équipe, trois annonces visibles, thèmes de couleur

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

Décisions consommées : [ADR-0081](../../decisions/adr/0081-annonces-trois-en-ligne-themes-et-illustrations-de-l-equipe.md) et [UDR-0075](../../decisions/udr/0075-annonces-themes-illustrations-et-decompte.md). Elles doivent être `Accepté` avant le Lot 0 (programme `refonte-application`).

## Graphe

```
Lot 0 — SOCLE (séquentiel) : schéma, entités, ports + adaptateurs, rendu sûr des illustrations, routes, locales partagées
  ↓
  ├─► Lot A — Publier : décompte, thème, illustration, 30 jours, 3 en ligne      ┐
  ├─► Lot B — Lire : la carte à la couleur de son thème                          ├─ en parallèle
  ├─► Lot C — Gérer la bibliothèque d'illustrations (équipe)                     │
  └─► Lot D — Accepter les enregistrements de téléphone                          ┘
        ↓ (A, B, C et D mergés)
      Lot E — Parcours de bout en bout, nettoyage des constantes, mesures
```

Dispatch :

```
Vague 1 : Lot 0                              → 1 agent, séquentiel
Vague 2 : Lot A ‖ Lot B ‖ Lot C ‖ Lot D       → 4 agents, worktrees isolés
Vague 3 : Lot E                              → 1 agent
```

Worktrees : `git worktree add ../lnclass-annonces-v2-lot-<x> -b feature/annonces-v2-lot-<x> feature/annonces-v2`, **après** le merge du Lot 0.

Règles pour chaque lot :
- **Contrats gelés.** Le Lot 0 gèle les ports, les entités, le schéma et le rendu des illustrations. Un lot qui doit les changer s'arrête : le Lot 0 rouvre.
- **Champ `Fichiers`.** Aucun lot ne touche un fichier hors de son champ `Fichiers`. S'il en a besoin, il s'arrête et remonte.
- **Ordre dans un lot.** Test rouge d'abord, puis domaine, infrastructure, delivery, UI. En-tête HITL de 3 lignes sur chaque fichier de `app/`.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + rendu partagé
- **Fichiers**     : `db/migrate/20261005100000_add_theme_and_library_illustration_to_messages.rb` *(colonne `theme`, défaut `ciel`, contrainte des 10 clés ; table `message_illustrations` ; `messages.illustration` nullable, `messages.illustration_id` et contrainte « exactement l'une des deux »)*
                     `db/schema.rb` · `test/db/schema_constraints_test.rb`
                     `app/domain/entities/communication/message.rb` *(`theme`, `illustration_id`, `THEMES`, `LIVE_CAP = 3`, `DURATION = 30.days` ; `DEFAULT_DURATION` et `MAX_DURATION` restent jusqu'au Lot E)*
                     `app/domain/entities/communication/illustration.rb` *(nouvelle : `id public_id name view_box shapes retired_at`, `SHAPES`, `ATTRIBUTES`, `NAME_MAX = 30`, `MAX_BYTES`, `MAX_SHAPES = 500`)*
                     `app/domain/ports/communication/message_repository_port.rb` *(+ `live_of(author_id:, now:)` : verrou de l'auteur, puis ses annonces en ligne, la plus ancienne d'abord)*
                     `app/domain/ports/communication/illustration_repository_port.rb` *(`find_by_public_id(public_id:)`, `available`, `create(illustration:)`, `rename(id:, name:)`, `retire(id:, at:)`, `find_all_by_ids(ids:)`)*
                     `app/infrastructure/orm/message_illustration.rb` · `app/infrastructure/orm/message.rb` *(association)*
                     `app/infrastructure/repositories/communication/message_repository.rb` *(theme, illustration_id, `live_of`)*
                     `app/infrastructure/repositories/communication/illustration_repository.rb`
                     `app/helpers/communication/illustrations_helper.rb` *(clé de base ou `Illustration` de l'équipe, reconstruite par le constructeur de balises sur liste blanche, sans `html_safe`)*
                     `app/domain/dtos/communication/message_input.rb` *(seulement `HEADER_BYTES` = 4096 : la lecture de l'en-tête audio du Lot D ; le reste du fichier est au Lot A)*
                     `config/routes/teams.rb` *(routes de l'UDR-0075 §3.5)*
                     `config/locales/communication/messages.fr.yml` *(`communication.themes.*`)*
                     `config/locales/communication/authored_messages.fr.yml` *(message de refus de l'audio de l'UDR-0075 §3.3, seulement cette ligne)*
                     `test/support/factories/communication.rb` *(`create_message(theme:, illustration:)` ; `create_illustration`)*
                     `test/architecture/port_contracts_test.rb` *(si une ligne est exigée pour le nouveau port)*
- **Dépend de**    : —
- **Test associé** : `test/db/schema_constraints_test.rb` (contraintes `theme` et « exactement une illustration »), `test/infrastructure/repositories/communication/message_repository_test.rb` (`live_of` : ce qui compte comme en ligne, ordre, verrou), `test/infrastructure/repositories/communication/illustration_repository_test.rb`, `test/helpers/communication/illustrations_helper_test.rb` (une forme hors liste blanche ou un attribut hors liste ne sort jamais ; aucun `html_safe`), `test/domain/entities/communication/illustration_test.rb`
- **Done quand**   : l'application tourne comme avant (« Ciel » partout, 8 illustrations), les contrats de l'ADR-0081 §6 sont en place, et une illustration de l'équipe créée par fabrique se rend en SVG reconstruit

---

## Lot A — Publier : décompte, thème, illustration, 30 jours, 3 en ligne

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/dtos/communication/message_input.rb` *(sans `visible_until` ; `theme` ; illustration = clé de base ou `public_id` d'une illustration disponible ; fin = parution + `DURATION`)*
                     `app/domain/use_cases/communication/create_message.rb` · `update_message.rb` · `publish_scheduled_messages.rb` *(plafond sous verrou, à la parution ; résultat qui nomme les archivées)*
                     `app/infrastructure/queries/communication/authored_messages_query.rb` *(thème des lignes ; annonce qui partirait pour l'encadré)*
                     `app/controllers/communication/authored_messages_controller.rb` *(encadré, toast nommant les archivées, bibliothèque disponible)*
                     `app/views/communication/authored_messages/_form.html.erb` · `new.html.erb` · `edit.html.erb` · `_row.html.erb`
                     `app/javascript/controllers/communication/theme_preview_controller.js`
                     `config/locales/communication/authored_messages.fr.yml` *(sauf la ligne du Lot 0)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/dtos/communication/message_input_test.rb` (AV-02, AV-07 thème inconnu, AV-10 illustration retirée), `test/domain/use_cases/communication/create_message_test.rb` · `update_message_test.rb` · `publish_scheduled_messages_test.rb` (AV-03, AV-04, AV-05), `test/controllers/communication/authored_messages_controller_test.rb` (AV-01 décompte rendu par le serveur, AV-02, AV-06 encadré et toast), `test/infrastructure/queries/communication/authored_messages_query_test.rb`
- **Done quand**   : un enseignant qui a 3 annonces en ligne voit l'encadré, choisit un thème et une illustration de l'équipe sans date de fin, publie, et sa plus ancienne passe « Archivée » ; le décompte suit la frappe. **AV-01 à AV-06**, la saisie de **AV-07** et de **AV-10**

---

## Lot B — Lire : la carte à la couleur de son thème

- **Couche**       : infrastructure + ui
- **Fichiers**     : `app/assets/stylesheets/application.tailwind.css` *(les 10 thèmes, clair et deux blocs sombres, UDR-0075 §3.1)*
                     `app/infrastructure/queries/communication/inbox_query.rb` *(`MessageCard#theme`, illustration de l'équipe préchargée en une requête)*
                     `app/views/communication/messages/_card.html.erb` *(`data-announcement-theme`)*
                     `test/design/announcement_themes_test.rb` *(nouveau : contrastes des 10 thèmes, clair et sombre)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/design/announcement_themes_test.rb` (AV-07), `test/infrastructure/queries/communication/inbox_query_test.rb` (thème et illustration de l'équipe ; nombre de requêtes constant), `test/views/communication/messages/card_test.rb` ou `test/controllers/communication/inboxes_controller_test.rb` (attribut de thème, dessin de l'équipe), `test/controllers/classroom/student_homes_controller_test.rb` (nombre de requêtes de l'accueil inchangé)
- **Done quand**   : une annonce « Mangue » s'affiche orange dans le carrousel, « Reçues » et la modération, en clair et en sombre, avec son illustration de l'équipe ; l'accueil élève garde son nombre de requêtes. **AV-07** (affichage), **AV-08** (couleur du dessin), **AV-10** (dessin gardé sur une annonce en ligne)

---

## Lot C — Gérer la bibliothèque d'illustrations (équipe)

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/ports/communication/drawing_reader_port.rb` · `app/infrastructure/communication/drawing_reader.rb` *(Nokogiri, XML strict, sans réseau ni DTD ; ADR-0081 §4.3)*
                     `app/domain/dtos/communication/illustration_input.rb`
                     `app/domain/policies/communication/manage_illustrations_policy.rb`
                     `app/domain/use_cases/communication/add_illustration.rb` · `rename_illustration.rb` · `retire_illustration.rb`
                     `app/infrastructure/queries/communication/illustration_library_query.rb` *(liste de la page, compte de la tuile)*
                     `app/controllers/teams/announcement_illustrations_controller.rb` · `app/controllers/teams/announcement_illustration_retirements_controller.rb`
                     `app/views/teams/announcement_illustrations/index.html.erb` · `edit.html.erb` · `_illustration.html.erb`
                     `app/controllers/teams/referentials_controller.rb` · `app/views/teams/referentials/_summary.html.erb` *(tuile, UDR-0075 §3.6)*
                     `config/locales/teams/announcement_illustrations.fr.yml` · `config/locales/teams/referentials.fr.yml`
                     `test/fixtures/files/illustrations/*.svg` *(un dessin d'Inkscape, un monochrome, et un fichier piégé par vecteur d'attaque)*
                     `test/architecture/use_case_policies_test.rb` *(si une ligne est exigée)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/communication/drawing_reader_test.rb` (AV-09, chaque vecteur refusé, Inkscape reconstruit), `test/domain/policies/communication/manage_illustrations_policy_test.rb` (AV-11), `test/domain/use_cases/communication/add_illustration_test.rb` · `rename_illustration_test.rb` · `retire_illustration_test.rb` (AV-08, AV-10), `test/controllers/teams/announcement_illustrations_controller_test.rb` (AV-08, AV-09 en 422, AV-11 en 403), `test/controllers/teams/referentials_controller_test.rb` (tuile)
- **Done quand**   : Fatou ajoute « Bus scolaire » depuis la tuile du Référentiel, la renomme, la retire ; un SVG piégé est refusé ; un enseignant reçoit 403. **AV-08** (ajout), **AV-09**, **AV-10** (retrait), **AV-11**

---

## Lot D — Accepter les enregistrements de téléphone

- **Couche**       : domaine
- **Fichiers**     : `app/domain/entities/communication/audio_header.rb` *(4096 octets ; MP3 avec remplissage ; MP4/3GP de toute marque audio, ADR-0081 §4.4)*
                     `test/fixtures/files/audio/*` *(un enregistrement réel par variante : MP3 avec octets nuls en tête, M4A `3gp4`, `3gp5`, `mp41`, `mp42`, `M4A `, `M4B `, `isom` ; un AMR, un OGG/Opus, un WAV)*
- **Dépend de**    : Lot 0 *(il pose le message de refus et la lecture de 4096 octets dans `MessageInput`)*
- **Test associé** : `test/domain/entities/communication/audio_header_test.rb` (AV-12). La preuve de bout en bout (un M4A `3gp4` publié par le formulaire) est au Lot E, car le test du contrôleur appartient au Lot A
- **Done quand**   : chaque fichier de variante est reconnu au bon format ; AMR, OGG et WAV sont refusés ; le poids reste vérifié avant toute lecture. **AV-12** (reconnaissance)

---

## Lot E — Parcours de bout en bout, nettoyage, mesures

- **Couche**       : tests système + nettoyage
- **Fichiers**     : `test/system/communication/announcements_v2_journey_test.rb` *(enseignant à 3 annonces : décompte, thème, illustration de l'équipe, audio M4A, encadré, publication, plus ancienne archivée ; l'élève voit la carte thémée ; l'équipe ajoute puis retire une illustration)*
                     `test/controllers/communication/authored_messages_controller_test.rb` *(AV-12 de bout en bout : un M4A `3gp4` publié)*
                     `app/domain/entities/communication/message.rb` *(retrait de `DEFAULT_DURATION` et `MAX_DURATION`, devenus morts)*
                     `script/ci/test_timings.yml`
- **Dépend de**    : Lots A, B, C et D
- **Test associé** : `test/system/communication/announcements_v2_journey_test.rb`
- **Done quand**   : le parcours nominal du PRD §3 se joue en navigateur réel, en 390 px ; le budget système du chantier tient (15 s, mesuré face à `Develop`) ; l'accueil élève garde 16 requêtes avec des annonces thémées

---

## Rattachement des critères

| Critère | Lots |
|---|---|
| AV-01 décompte | A (+ E en navigateur) |
| AV-02 plus de date de fin | A |
| AV-03 plafond de 3 | 0 (`live_of`), A |
| AV-04 ce qui compte | 0 (`live_of`), A |
| AV-05 publications simultanées | 0 (verrou de `live_of`), A |
| AV-06 encadré et toast | A |
| AV-07 dix thèmes | 0 (contrainte), A (saisie), B (affichage, contrastes) |
| AV-08 l'équipe ajoute | C (ajout), B (couleur sur la carte), A (choix) |
| AV-09 SVG jamais du code | 0 (rendu reconstruit), C (lecture du fichier) |
| AV-10 retirer | C (retrait), A (refus d'une retirée), B (dessin gardé) |
| AV-11 équipe seule | C |
| AV-12 audio des téléphones | D (reconnaissance), E (de bout en bout) |

Aucun critère orphelin.

---

## Vérification de collision

> Contrôle mécanique : `awk '/^## Vérification de collision/{exit} 1' plan.md | grep -oE '(app|test|config|db|lib|script)/[A-Za-z0-9_/.*-]+\.(rb|erb|yml|js|css)' | sort | uniq -d`. Les seuls doublons attendus sont des fichiers de lots **séquentiels** (0 puis A, 0 puis E, A puis E) ; aucun entre A, B, C et D.

| Fichier | Lot propriétaire |
|---|---|
| `db/migrate/…`, `db/schema.rb`, `test/db/schema_constraints_test.rb` | Lot 0 |
| `app/domain/entities/communication/message.rb` | Lot 0 (puis Lot E, séquentiel) |
| `app/domain/ports/communication/message_repository_port.rb`, `illustration_repository_port.rb` | Lot 0 |
| `app/infrastructure/repositories/communication/message_repository.rb`, `illustration_repository.rb` | Lot 0 |
| `app/helpers/communication/illustrations_helper.rb` | Lot 0 |
| `config/routes/teams.rb` | Lot 0 |
| `config/locales/communication/messages.fr.yml` | Lot 0 |
| `config/locales/communication/authored_messages.fr.yml` | Lot 0 (ligne de l'audio), puis Lot A — séquentiel |
| `test/support/factories/communication.rb` | Lot 0 |
| `app/domain/dtos/communication/message_input.rb` | Lot 0 (`HEADER_BYTES` seulement), puis Lot A — séquentiel |
| `app/views/communication/authored_messages/*` | Lot A |
| `app/infrastructure/queries/communication/authored_messages_query.rb` | Lot A |
| `test/controllers/communication/authored_messages_controller_test.rb` | Lot A (puis Lot E, séquentiel) |
| `app/assets/stylesheets/application.tailwind.css` | Lot B |
| `app/infrastructure/queries/communication/inbox_query.rb`, `app/views/communication/messages/_card.html.erb` | Lot B |
| `app/controllers/teams/referentials_controller.rb`, `app/views/teams/referentials/_summary.html.erb`, `config/locales/teams/referentials.fr.yml` | Lot C |
| `test/architecture/use_case_policies_test.rb` | Lot C |
| `test/architecture/port_contracts_test.rb` | Lot 0 *(le port du Lot C, s'il y faut une ligne, l'ajoute — seul lot parallèle à le toucher après le Lot 0)* |
| `app/domain/entities/communication/audio_header.rb` | Lot D |
| `script/ci/test_timings.yml` | Lot E |

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

Propres à ce chantier :

- [ ] ADR-0081 et UDR-0075 `Accepté` **avant** le Lot 0 (programme)
- [ ] Revue de sécurité sur le Lot C (lecture des SVG) et sur le rendu des illustrations du Lot 0, avant le merge du Lot C
- [ ] Palette des 10 thèmes validée par le porteur (UDR-0075 §3.1)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Ici : il publie la 4ᵉ annonce d'un enseignant et constate l'archivage ; il téléverse chaque SVG piégé de `test/fixtures/files/illustrations/` par la page de l'équipe ; il joint un M4A `3gp4` réel ; il regarde les 10 thèmes en clair et en sombre, à 360 et 390 px.
