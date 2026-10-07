# Plan d'exécution — Installer Lnclass sur le téléphone (PWA)

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Entrées : [PRD](prd.md) · [ADR-0082](../../decisions/adr/0082-application-installable-sans-page-de-compte-sur-le-telephone.md) · [UDR-0078](../../decisions/udr/0078-bandeau-d-installation-et-page-pas-de-connexion.md).

## Graphe

```
Lot 0 — SOCLE (séquentiel)
  migration users.app_opened_at · port UserRepositoryPort#mark_app_opened (gelé)
  routes PWA · <link rel="manifest"> · rendu du bandeau dans le shell · locales · icônes
  ↓
  ├─► Lot A « installer, et voir “Pas de connexion” sans réseau »   ┐  CA-1 à CA-4
  ├─► Lot B « bandeau d'installation Android et iPhone »           ├─ en parallèle
  ├─► Lot C « ouverture depuis l'icône comptée »                   │  CA-10
  └─► Lot D « indicateur du pilotage »                             ┘  CA-11
```

Le Lot 0 gèle le contrat `mark_app_opened(user_id:, at:) → true`. Les lots verticaux l'implémentent ou le lisent ; aucun ne le redéfinit. Un lot qui doit changer un port **s'arrête** et le Lot 0 rouvre. Aucun lot parallèle ne démarre avant que le Lot 0 soit dans la branche de chantier.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrat) + fichiers partagés
- **Fichiers**     : `db/migrate/<horodatage>_add_app_opened_at_to_users.rb` · `db/schema.rb`
                     `app/domain/ports/identity/user_repository_port.rb` *(ajout de `mark_app_opened`, `NotImplementedError`)*
                     `config/routes.rb` *(`get "manifest" => "rails/pwa#manifest", as: :pwa_manifest` et `get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker`)*
                     `app/views/layouts/application.html.erb` *(balise `<link rel="manifest">`, `meta theme-color`)*
                     `app/views/layouts/shell.html.erb` *(`render "shared/navigation/install_banner", role:` pour `student` et `teacher`, premier enfant de `[data-bleed]`)*
                     `app/views/shared/navigation/_install_banner.html.erb` *(fichier vide avec son en-tête HITL, rempli par le Lot B)*
                     `config/locales/shared/navigation.fr.yml` *(clés `install_banner` de l'UDR-0078 §3.1)*
                     `config/locales/teams/dashboards.fr.yml` *(clés de la tuile, UDR-0078 §3.3)*
                     `public/icon-192.png` · `public/icon-maskable.png` *(générés depuis le logo officiel)*
- **Dépend de**    : —
- **Test associé** : `test/routing/pwa_routing_test.rb` (les deux routes répondent) · `test/infrastructure/repositories/identity/user_repository_test.rb` (la colonne existe et est nulle par défaut) · `test/i18n/` existant (aucune clé manquante)
- **Done quand**   : `bin/rails test` passe ; les deux routes PWA répondent 200 ; une page élève contient un `#install_banner` vide et caché ; le contrat du port est gelé

---

## Lot A — Installer Lnclass, et voir « Pas de connexion » sans réseau

- **Couche**       : delivery (fichiers PWA servis par Rails) + ui
- **Fichiers**     : `app/views/pwa/manifest.json.erb` *(ADR-0082 §4.1)*
                     `app/views/pwa/service-worker.js` *(ADR-0082 §4.2 et §6)*
                     `public/offline.html` · `public/offline.css` *(UDR-0078 §3.2)*
                     `app/javascript/pwa.js` *(enregistre le programme à la portée `/`, si `navigator.serviceWorker` existe)*
                     `app/javascript/application.js` *(une ligne : `import "./pwa"`)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/integration/pwa_test.rb` (CA-1, CA-2 : JSON du manifeste, `Cache-Control: no-cache`, la constante `OFFLINE_FILES` ne liste que les trois chemins, aucun `cache.put`) · `test/system/pwa_offline_test.rb` (CA-3, CA-4 : Chrome, programme actif, réseau coupé → « Pas de connexion », sans le nom de l'élève ; le contenu de `caches` se limite aux trois fichiers)
- **Done quand**   : sur Chrome Android, le menu propose « Installer l'application » ; l'icône Lnclass ouvre le site en plein écran ; réseau coupé, une navigation affiche « Pas de connexion » et « Réessayer » ramène à la page demandée une fois le réseau revenu

---

## Lot B — Bandeau d'installation (Android et iPhone)

- **Couche**       : ui
- **Fichiers**     : `app/views/shared/navigation/_install_banner.html.erb` *(contenu, UDR-0078 §3.1)*
                     `app/javascript/controllers/install_controller.js` *(UDR-0078 §3.1.1 ; enregistré automatiquement par `controllers/index.js`)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/system/identity/install_banner_test.rb` (CA-5 : événement `beforeinstallprompt` simulé → bandeau, « Installer » appelle `prompt()` ; CA-6 : horloge du navigateur avancée de 2 puis 4 jours, aucune requête vers le serveur au clic ; CA-7 : User-Agent de Safari iPhone → deux étapes, pas de bouton « Installer » ; CA-8 : `display-mode: standalone` émulé → pas de bandeau) · `test/integration/identity/install_banner_test.rb` (CA-9 : le HTML de la direction, de l'équipe et de la page publique ne contient pas `install_banner` ; celui de l'élève et de l'enseignant le contient avec `hidden`)
- **Done quand**   : un élève connecté sur Chrome Android voit « Installe Lnclass sur ton téléphone » ; « Plus tard » le fait disparaître pour 3 jours sur ce téléphone ; un enseignant sur iPhone voit les deux étapes ; un compte direction ne voit rien

---

## Lot C — Ouverture depuis l'icône comptée

- **Couche**       : domaine + infrastructure + delivery
- **Fichiers**     : `app/domain/use_cases/identity/record_app_open.rb` *(ADR-0082 §4.3)*
                     `app/infrastructure/repositories/identity/user_repository.rb` *(`mark_app_opened` ; `anonymize` remet `app_opened_at` à `NULL`)*
                     `app/controllers/homepage_controller.rb` *(appelle le use case si `params[:source] == "app"` et un compte est connecté, puis redirige comme aujourd'hui)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/identity/record_app_open_test.rb` (pose l'heure de l'horloge injectée ; un échec du port est journalisé et n'empêche pas la suite) · `test/infrastructure/repositories/identity/user_repository_test.rb` (`mark_app_opened` ; l'anonymisation efface la colonne) · `test/controllers/homepage_controller_test.rb` (CA-10 : élève sur `/?source=app` → colonne posée et redirection vers son accueil ; visiteur → page publique, rien d'écrit ; `source=autre` → rien d'écrit)
- **Done quand**   : un élève qui touche l'icône arrive sur son accueil et son compte porte l'heure d'ouverture ; un visiteur sur `/?source=app` voit la page publique sans écriture en base

> `user_repository_test.rb` est aussi cité par le Lot 0 : le Lot 0 n'y ajoute que l'assertion de colonne ; le Lot C y ajoute ses tests **après** le merge du Lot 0. Les deux ne tournent jamais en parallèle (dépendance), ce n'est pas une collision.

---

## Lot D — Indicateur « Ouvert depuis l'app installée » du pilotage

- **Couche**       : infrastructure (query) + ui
- **Fichiers**     : `app/infrastructure/queries/school/team_dashboard_query.rb` *(`app_openers` par rôle, ADR-0082 §4.4)*
                     `app/views/teams/dashboards/_key_figures.html.erb` *(tuile `#figure_app_openers`, UDR-0078 §3.3)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/school/team_dashboard_query_test.rb` (CA-11 : 3 élèves et 1 enseignant dans la période comptés ; ouverture antérieure et compte anonymisé exclus ; une seule requête de plus) · `test/controllers/teams/dashboards_controller_test.rb` (la tuile rend « 3 élèves » et « 1 enseignant » ; la direction est refusée comme aujourd'hui)
- **Done quand**   : un membre de l'équipe lit, dans « Sur la période », le nombre d'élèves et d'enseignants qui ont ouvert l'app installée ; un zéro s'affiche « 0 élève »

---

## Couverture des critères d'acceptation

| Critère (PRD §4) | Lot |
|---|---|
| CA-1 Fiche d'application | A (route et balise : Lot 0) |
| CA-2 Programme d'arrière-plan | A |
| CA-3 Page « Pas de connexion » | A |
| CA-4 Aucune page de compte gardée | A |
| CA-5 Bandeau Android | B |
| CA-6 « Plus tard » 3 jours | B |
| CA-7 Mode d'emploi iPhone | B |
| CA-8 Pas de bandeau dans l'app installée | B |
| CA-9 Pas de bandeau pour les autres | B (le choix du rôle est dans le shell : Lot 0 ; le test est dans B) |
| CA-10 Ouverture comptée | C |
| CA-11 Indicateur du pilotage | D |

Aucun critère orphelin.

## Vérification de collision

> Vérifiée mécaniquement (`awk … | sort | uniq -d`) : deux fichiers reviennent, chacun entre le Lot 0 et un lot qui en dépend, donc jamais en parallèle : `user_repository_test.rb` (Lot 0 puis Lot C) et `_install_banner.html.erb` (créé vide par le Lot 0 pour que le shell le rende, rempli par le Lot B). Aucun fichier n'est partagé entre deux lots de la vague 2.

| Fichier | Lot propriétaire |
|---|---|
| `config/routes.rb` | Lot 0 |
| `config/locales/shared/navigation.fr.yml` | Lot 0 |
| `config/locales/teams/dashboards.fr.yml` | Lot 0 |
| `app/views/layouts/application.html.erb` | Lot 0 |
| `app/views/layouts/shell.html.erb` | Lot 0 |
| `app/domain/ports/identity/user_repository_port.rb` | Lot 0 |
| `db/migrate/…_add_app_opened_at_to_users.rb` · `db/schema.rb` | Lot 0 |
| `public/icon-192.png` · `public/icon-maskable.png` | Lot 0 |
| `app/views/shared/navigation/_install_banner.html.erb` | Lot 0 (création vide) puis Lot B (contenu) |
| `app/javascript/application.js` | Lot A |
| `app/views/pwa/*` · `public/offline.*` · `app/javascript/pwa.js` | Lot A |
| `app/javascript/controllers/install_controller.js` | Lot B |
| `app/infrastructure/repositories/identity/user_repository.rb` | Lot C |
| `app/controllers/homepage_controller.rb` | Lot C |
| `app/infrastructure/queries/school/team_dashboard_query.rb` | Lot D |
| `app/views/teams/dashboards/_key_figures.html.erb` | Lot D |

**Hors chantier** : la feuille de route signale que le gabarit du shell (UDR-0006) n'a qu'un propriétaire à la fois. Avant le Lot 0, vérifier qu'aucune PR ouverte ne touche `layouts/shell.html.erb`.

## Dispatch

```
Vague 1 : Lot 0                          → 1 agent, séquentiel
Vague 2 : Lot A ‖ Lot B ‖ Lot C ‖ Lot D  → 4 agents, worktrees isolés
```

Les lots sont petits : un seul exécutant peut aussi les enchaîner sans perte, dans l'ordre 0 → C → D → A → B.

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

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Ici : il installe Lnclass sur un vrai téléphone Android (Chrome) et sur un iPhone (Safari), ouvre l'app depuis l'icône, coupe le réseau (mode avion) et change de page, touche « Plus tard », puis vérifie dans le pilotage de l'équipe que l'ouverture est comptée. Chemin d'erreur : un compte direction ne voit aucun bandeau, et une page de compte vue avant la coupure n'est pas resservie hors ligne. Il mesure le poids ajouté au JavaScript d'entrée (≤ 2 Ko compressé).
