# Plan d'exécution — Accueil de la direction : établissement, niveaux, annonces, activité

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Spécifications : [`prd.md`](prd.md) · Interface : [UDR-0072](../../decisions/udr/0072-accueil-de-la-direction.md) · Pas d'ADR ([PRD §6](prd.md#6-décisions-rattachées)).

## Graphe

```
Lot 0 — SOCLE (séquentiel)
  signal du domaine · contrat de StudentWorkQuery · routes · navigation « Accueil »
  · tokens signal-* · bulle à pastille · illustrations de niveau · légende · retours
  ↓
  ├─► Lot A « Accueil : Établissement + Niveaux »   ┐
  ├─► Lot B « Page d'un niveau »                    ├─ en parallèle, worktrees isolés
  └─► Lot C « Activité récente »                    ┘
        ↓ (A, B, C mergés)
        Lot E « Parcours de bout en bout »
        ↓ (A mergé + chantier `annonces` mergé dans Develop avec D-A1)
        Lot D « Annonces sur l'accueil »   — peut tourner en même temps que E
```

**Pourquoi D attend une dépendance externe** : le carrousel, la règle de lecture et le masquage appartiennent au chantier `annonces` (branche `feature/annonces`, non mergée au 2026-10-04). D-A1 (« toute annonce est masquable, l'équipe seule rédige ») doit y être reportée avant : sinon la croix de la direction répondrait 403. D commence par merger `Develop` dans `feature/accueil-direction`.

**Pourquoi le Lot 0 porte la query `StudentWorkQuery`** : A (sommes par niveau) et B (page d'un niveau) en consomment le même contrat (`ClassroomRow#level_slug`, `#submitted_count`, `#level`). Le contrat se gèle ici, une fois.

---

## Lot 0 — Socle

- **Couche**       : domaine (règle du signal) + infrastructure (contrat de query) + delivery (routes) + ui partagée
- **Fichiers**     : `app/domain/entities/school/work_signal.rb`
                     `app/infrastructure/queries/school/student_work_query.rb` *(ClassroomRow + `level_slug`, `submitted_count` ; `#level(school_id:, slug:)` → `LevelOverview` ou nil)*
                     `config/routes/school_admin.rb` *(`resources :levels, only: :show, param: :slug` ; `get "activity", to: "activities#show", as: :activity`)*
                     `app/helpers/navigation_helper.rb` · `config/locales/shared/navigation.fr.yml` *(« Accueil » en tête, `student_work` retiré)*
                     `app/assets/stylesheets/application.tailwind.css` *(tokens `signal-*`, clair et deux blocs sombres)*
                     `app/helpers/components_helper.rb` · `app/views/components/_subject_bubble.html.erb` *(`signal:`)*
                     `app/helpers/school_admin/levels_helper.rb`
                     `app/assets/images/levels/6eme.svg` · `5eme.svg` · `4eme.svg` · `3eme.svg` · `2nde.svg` · `1ere.svg` · `tle.svg`
                     `app/views/school_admin/shared/_signal_legend.html.erb` · `config/locales/school_admin/signals.fr.yml`
                     `app/views/school_admin/classrooms/show.html.erb` *(nav_key `home`, retour vers la page du niveau — UDR-0072 §3.9)*
                     `app/views/school_admin/classrooms/index.html.erb` *(nav_key `home` seulement ; réécrit au Lot A)*
                     `app/views/school_admin/departed_students/index.html.erb` · `config/locales/school_admin/departed_students.fr.yml` *(nav_key `home`, retour « Accueil »)*
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/school/work_signal_test.rb` *(AD-01, bornes 39/40, 69/70, nil)*
                     `test/infrastructure/queries/school/student_work_query_test.rb` *(`level_slug`, `submitted_count`, `#level` : autre établissement, archivée, autre année, slug inconnu → nil — AD-10)*
                     `test/helpers/navigation_helper_test.rb` *(AD-20)*
                     `test/helpers/components_helper_test.rb` *(bulle sans signal identique à l'UDR-0069 ; trois couleurs ; valeur inconnue → ArgumentError)*
                     `test/helpers/school_admin/levels_helper_test.rb` *(sept slugs, repli générique, fichiers présents)*
                     `test/routing/school_admin_routes_test.rb`
                     `test/controllers/school_admin/classrooms_controller_test.rb` *(show : retour vers le niveau — AD-13 ; nav « Accueil » active)*
                     `test/controllers/school_admin/schools_controller_test.rb` *(libellé de navigation)*
                     `test/controllers/school_admin/departed_students_controller_test.rb` *(retour « Accueil »)*
- **Done quand**   : la navigation de la direction commence par « Accueil » (active sur l'accueil, une classe, les anciens élèves) ; la page d'une classe ramène à `/school-admin/levels/<slug>` ; `bin/rails runner "puts Entities::School::WorkSignal.for(55)"` affiche `yellow` ; `/design` ou une vue de test rend une bulle à pastille ; les routes `school_admin_level_path` et `school_admin_activity_path` existent.

> Le Lot 0 gèle : `WorkSignal.for(rate)` (seuils et valeurs `:green`/`:yellow`/`:red`/nil), `StudentWorkQuery::ClassroomRow`, `LevelOverview`, `#level`, `ui_subject_bubble(signal:)`, `level_illustration(slug)`, les noms de routes. **Un lot qui a besoin d'en changer un s'arrête : le Lot 0 rouvre.**

---

## Lot A — Accueil : carte « Établissement » et « Niveaux »

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/entities/school/direction_alerts.rb`
                     `app/infrastructure/queries/school/direction_home_query.rb`
                     `app/controllers/school_admin/classrooms_controller.rb` *(index)*
                     `app/views/school_admin/classrooms/index.html.erb` *(réécrit : UDR-0072 §3.2 ; carte « Activité récente » avec son frame paresseux vers `school_admin_activity_path`)*
                     `app/views/school_admin/classrooms/_school_card.html.erb` · `app/views/school_admin/classrooms/_levels.html.erb`
                     `config/locales/school_admin/classrooms.fr.yml` *(clés de l'accueil ; clés du tableau retirées)*
                     `test/performance/school/heavy_screens_budget_test.rb` *(budget « Accueil » à la place de « Travail des élèves »)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/entities/school/direction_alerts_test.rb` *(ordre, trois noms + « autres », absence d'alerte)*
                     `test/infrastructure/queries/school/direction_home_query_test.rb` *(chiffres AD-02, élève compté une fois, enseignants = page « Enseignants », taux d'un niveau, niveaux sans classe absents ; nombre de requêtes identique pour 3 et 30 classes)*
                     `test/controllers/school_admin/classrooms_controller_test.rb` *(index : AD-02 à AD-08, un seul h1, nom accessible des bulles — AD-22)*
- **Done quand**   : une direction connectée voit « Bonjour, <prénom> », la carte de son établissement avec ses trois chiffres et ses alertes (ou « Rien à signaler »), et une bulle à illustration par niveau, avec sa pastille ; toucher une bulle ouvre `/school-admin/levels/<slug>`. **AD-02 à AD-08**, versant accueil d'**AD-20** et **AD-22**.

---

## Lot B — Page d'un niveau

- **Couche**       : delivery + ui *(la lecture est gelée au Lot 0)*
- **Fichiers**     : `app/controllers/school_admin/levels_controller.rb`
                     `app/views/school_admin/levels/show.html.erb` · `app/views/school_admin/levels/_classroom_card.html.erb`
                     `config/locales/school_admin/levels.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/school_admin/levels_controller_test.rb` *(AD-09 : cartes triées, pastilles, « Aucun devoir donné », « — » de la moyenne, légende ; AD-10 : classes hors périmètre absentes ; AD-11 : 404 ; AD-12 : 403 pour l'équipe, l'enseignant, l'élève ; texte sr-only du signal — AD-22 ; nombre de requêtes fixe)*
- **Done quand**   : `/school-admin/levels/3eme` montre une carte par classe de 3ème de l'établissement, avec l'illustration du niveau, la pastille de son taux de rendu et ses chiffres, et chaque carte ouvre la page de la classe ; un niveau sans classe répond 404. **AD-09 à AD-12** (versant niveau), **AD-22**.

---

## Lot C — Activité récente

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/school/school_activity_query.rb`
                     `app/controllers/school_admin/activities_controller.rb`
                     `app/views/school_admin/activities/_activity.html.erb`
                     `config/locales/school_admin/activities.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/school/school_activity_query_test.rb` *(trois types, 10 au plus, 30 jours, autre établissement exclu, élève anonymisé exclu, enseignant anonymisé « Un enseignant », ≤ 4 requêtes — AD-17, AD-18)*
                     `test/controllers/school_admin/activities_controller_test.rb` *(frame seul sans layout, groupement par jour, « Awa K. », état vide AD-19, 403 pour les autres rôles AD-12)*
- **Done quand**   : `GET /school-admin/activity` (demandé par le frame paresseux de l'accueil) rend les 10 derniers événements des 30 derniers jours de l'établissement, groupés par jour, ou « Rien de nouveau ces 30 derniers jours ». **AD-17 à AD-19**, versant activité d'**AD-12**.

---

## Lot D — Annonces sur l'accueil

- **Couche**       : delivery + ui *(tout le reste appartient au chantier `annonces`)*
- **Fichiers**     : `app/controllers/school_admin/classrooms_controller.rb` *(`@announcements`, UDR-0072 §3.10)*
                     `app/views/school_admin/classrooms/index.html.erb` *(rendu du carrousel entre « Niveaux » et « Activité récente »)*
                     `test/controllers/school_admin/home_announcements_test.rb`
                     `test/system/school_admin/home_announcements_test.rb`
- **Dépend de**    : Lot A **et** le chantier `annonces` mergé dans `Develop` avec la décision D-A1 (masquage ouvert à `school_admin`). Première étape du lot : merger `Develop` dans `feature/accueil-direction`.
- **Test associé** : `test/controllers/school_admin/home_announcements_test.rb` *(AD-14 : nationale et de l'établissement visibles, autre établissement absente, croix sur chaque carte ; AD-16 : pas de section sans annonce lisible)*
                     `test/system/school_admin/home_announcements_test.rb` *(AD-15 : masquer, toast, « Annuler »)*
- **Done quand**   : sur son accueil, la direction lit le carrousel des annonces de l'équipe, en masque une et l'annule depuis le toast. **AD-14 à AD-16**.

---

## Lot E — Parcours de bout en bout

- **Couche**       : tests système *(aucun code d'application)*
- **Fichiers**     : `test/system/school_admin/direction_home_test.rb` *(remplace `test/system/school_admin/student_work_test.rb`, supprimé)*
                     `test/system/finitions/school_admin_test.rb` · `test/system/finitions/public_pages_test.rb` · `test/system/finitions/narrow_screens_test.rb`
                     `test/system/school_admin/departed_students_test.rb` · `test/system/role_homes_test.rb` *(commentaires et attentes de l'ancienne page)*
- **Dépend de**    : Lot A, Lot B, Lot C
- **Test associé** : `test/system/school_admin/direction_home_test.rb` — parcours nominal du PRD §3 (connexion → carte « Établissement » et ses alertes → bulle « 3ème » → carte « 3ème 2 » rouge → page de la classe → retour « 3ème » → activité chargée) et un chemin d'erreur (adresse d'un niveau sans classe → 404) ; en bureau et à 375 px sans défilement horizontal (**AD-20**, **AD-21**, **AD-22**)
- **Done quand**   : le parcours nominal et le chemin d'erreur passent en test système, au bureau et au téléphone, et plus aucun test ne cherche « Travail des élèves ».

> **Entre le Lot 0 et le Lot E**, les tests système de la direction qui lisent l'ancien tableau peuvent être rouges **sur la branche de chantier**. Ils sont réécrits au Lot E et doivent être verts **avant la PR**. Les tests unitaires, de contrôleur et de query restent verts à chaque merge de lot.

---

## Dispatch

```
Vague 1 : Lot 0                  → 1 agent, séquentiel, sur feature/accueil-direction-lot-0
Vague 2 : Lot A ‖ Lot B ‖ Lot C  → 3 agents, worktrees isolés
Vague 3 : Lot E                  → 1 agent (dès que A, B et C sont mergés)
          Lot D                  → 1 agent, en même temps que E si `annonces` (avec D-A1) est déjà dans Develop ; sinon il attend
```

Worktree d'un lot, **depuis la branche de chantier une fois le Lot 0 mergé** :

```bash
git worktree add ../lnclass-accueil-direction-lot-a -b feature/accueil-direction-lot-a feature/accueil-direction
```

Brief de chaque agent : chemin **absolu** du worktree (`git -C <worktree>`), son lot recopié en entier, le [PRD](prd.md), l'[UDR-0072](../../decisions/udr/0072-accueil-de-la-direction.md) ; ordre imposé : test rouge → domaine → infrastructure → delivery → UI ; en-tête HITL sur chaque fichier de `app/`. **Interdiction de toucher un fichier hors de son champ `Fichiers`** : s'il en faut un, l'agent s'arrête et remonte (Lot 0 à rouvrir, ou plan faux). Aucun lot ne redéfinit un contrat du Lot 0.

## Couverture des critères

| Critère | Lot(s) |
|---|---|
| AD-01 | 0 |
| AD-02 à AD-08 | A |
| AD-09, AD-11 | B |
| AD-10 | 0 (query), B (page) |
| AD-12 | B (niveau), C (activité) |
| AD-13 | 0 |
| AD-14 à AD-16 | D |
| AD-17 à AD-19 | C |
| AD-20 | 0 (navigation), E (système) |
| AD-21 | E |
| AD-22 | A, B, E |

Aucun critère orphelin.

---

## Vérification de collision

> Rempli avant de lancer les lots parallèles. Deux lots **parallèles** ne listent jamais le même fichier. Détection mécanique :
> `awk '/^## Vérification de collision/{exit} 1' docs/chantiers/accueil-direction/plan.md | grep -oE '(app|test|config|db|lib)/[A-Za-z0-9_/.-]+\.(rb|erb|yml|js|css|svg)' | sort | uniq -d`
> Les doublons qu'elle signale sont **tous séquentiels et voulus** (ci-dessous) ; aucun n'est partagé entre A, B et C.

| Fichier | Lot propriétaire | Remarque |
|---|---|---|
| `config/routes/school_admin.rb` | Lot 0 | routes de B (`levels`) et de C (`activity`) |
| `app/helpers/navigation_helper.rb`, `config/locales/shared/navigation.fr.yml` | Lot 0 | **aussi touchés par le chantier `annonces`** (Lot D d'`annonces` : entrée « Annonces ») ; conflit à résoudre au merge de `Develop`, en gardant les deux entrées |
| `app/helpers/components_helper.rb` | Lot 0 | **aussi touché par `annonces`** (Lot 0 d'`annonces` : `ui_toast(action:)`, `ui_checkbox_group`) ; méthodes distinctes |
| `app/assets/stylesheets/application.tailwind.css` | Lot 0 | tokens `signal-*` |
| `app/views/components/_subject_bubble.html.erb` | Lot 0 | consommé par A (bulles) |
| `app/helpers/school_admin/levels_helper.rb`, `app/assets/images/levels/*.svg` | Lot 0 | consommés par A et B |
| `app/views/school_admin/shared/_signal_legend.html.erb`, `config/locales/school_admin/signals.fr.yml` | Lot 0 | consommés par A et B |
| `app/infrastructure/queries/school/student_work_query.rb` (+ son test) | Lot 0 | contrat consommé par A et B |
| `app/views/school_admin/classrooms/index.html.erb` | **Lot 0 → Lot A → Lot D** | séquentiels : nav_key (0), réécriture (A), carrousel (D) |
| `app/controllers/school_admin/classrooms_controller.rb` | **Lot A → Lot D** | séquentiels |
| `test/controllers/school_admin/classrooms_controller_test.rb` | **Lot 0 → Lot A** | séquentiels : show (0), index (A) ; D écrit dans son propre fichier de test |
| `app/views/school_admin/classrooms/show.html.erb` | Lot 0 | retour vers le niveau ; B ne la touche pas |
| `config/locales/school_admin/classrooms.fr.yml` | Lot A | B et C ont chacun leur fichier de locale |
| `test/performance/school/heavy_screens_budget_test.rb` | Lot A | |
| tests système de la direction | Lot E (D : son propre fichier) | |

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md` *(aucun : PRD §6)*
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md` *(UDR-0072)*
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Ici : il se connecte en direction, lit la carte « Établissement » d'un établissement préparé avec une classe sans enseignant et une classe à 31 %, vérifie les alertes et les pastilles, ouvre « 3ème », ouvre la classe rouge, revient ; il tape `/school-admin/levels/7eme` (404) et ouvre la page d'un niveau en compte enseignant (403) ; il recommence à 375 px, en mode sombre ; il compte les requêtes de l'accueil avec 3 puis 30 classes.
