# Journal — Accueil de la direction : établissement, niveaux, annonces, activité

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-04 | Grill mené à partir de Q5 en **décisions par défaut** de l'agent, sans aller-retour | Consigne du porteur : « prendre des décisions, c'est autonome ; pose-moi la question si et seulement si tu doutes » | Non |
| 2026-10-04 | Le Lot 0 est exécuté par l'orchestrateur lui-même, sur la branche de chantier | Lot séquentiel et court ; aucun gain à un worktree pour un seul agent | Non |
| 2026-10-04 | Le Lot D n'a plus de test système ; AD-15 se prouve au niveau contrôleur | `script/ci/test_timings.yml` (budget système de 15 s par chantier) aurait été touché par D et E en parallèle : collision trouvée au Lot 0, le fichier reste au seul Lot E | Non |
| 2026-10-04 | **Lot D : carrousel sans croix** (D-A2) | `annonces` mergé sans D-A1 ; choix du porteur parmi trois options (masquage ouvert à la direction, lecture seule, D-A1 d'abord). Seul ajout côté `annonces` : le local `dismissible:` du carrousel, vrai par défaut | Non (UDR-0071 et UDR-0072 précisées) |
| 2026-10-04 | **Accueil gardé 5 minutes** (Lot F, AD-23) : 0,1 ms à chaud, 123 ms à froid, au lieu de 138 à 152 ms toujours | Décision du porteur parmi trois options (cache, budget relevé, optimisation reportée), sur la mesure : l'ancienne lecture frôle seule le budget. Motif du pilotage (ADR-0062, 2026-09-29) | **Oui** : amendement de l'ADR-0065 |
| 2026-10-04 | Phase 5 : quatre constats du challenger corrigés dans la PR, chacun test rouge d'abord — D1 (activité en JSON : 500 → 406), R1 (« enseignants » hors de sa tuile à 360 px), O1 (élève de deux classes du niveau compté deux fois sur la page du niveau), O5 (pastille jaune à 1,82:1 en clair → `#b88700`, 3,23:1) | Tous dans le périmètre du chantier et petits ; le jaune reste un jaune (moutarde) | Non |
| 2026-10-04 | Lot C : une panne de la base dans le frame d'activité répond 503 avec `ui_error_state`, journalisée | L'UDR exigeait un état d'erreur dans le frame ; sans JavaScript, seule la réponse peut le porter. Motif existant : compteur des articles (ADR-0074 §4.7). UDR-0072 §3.11 précisée | Non |
| 2026-10-04 | Lot C : un enseignant retiré mais non anonymisé garde son nom sur ses devoirs passés | Écart memo ↔ UDR relevé par l'exécutant ; l'UDR l'emporte (fait daté, seul l'anonymisé est masqué). Memo corrigé | Non |
| 2026-10-04 | Lot B : le nombre de la moyenne est mis en valeur comme celui du taux (`font-medium text-ink`) ; UDR-0072 §3.8 précisée | Lecture de l'exécutant (« même rendu » pour les deux lignes), retenue : deux chiffres voisins, un seul style | Non |
| 2026-10-04 | Lot B : le test rouge et le code sont dans le même commit | Le pre-commit refuse un test rouge ; le rouge d'abord est prouvé par le rapport de l'exécutant (9 erreurs `MissingController` avant le code), pas par l'historique | Non |
| 2026-10-04 | La pastille de la bulle n'ajoute `relative` au rond que si elle est présente | UDR-0072 §3.5 : sans signal, la bulle reste strictement celle de l'UDR-0069 (accueil enseignant inchangé) | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Branche de départ périmée** : le chantier a été ouvert sur un `Develop` local en retard de plusieurs dizaines de commits (accueil enseignant par niveau, gestes de la direction, pilotage par DRENA). Constaté en lisant la branche `annonces` ; branche rebasée sur `origin/Develop` avant le grill Q2. À faire au départ de tout chantier : `git fetch origin Develop` **avant** de brancher.
- **Test de routage qui chargeait le contrôleur d'un autre lot** : `recognize_path` instancie le contrôleur ; le Lot 0 dessine des routes dont les contrôleurs n'arrivent qu'aux Lots B et C. Corrigé en lisant la route par le routeur seul (`first_match`).
- **Consigne du challenger trop large** : `bin/rails db:create db:schema:load` en développement recharge aussi la base de test (Rails 8.1, sauf `SKIP_TEST_DATABASE=1`). Sans effet ici (la suite système tournait sur les bases `_0..3` des workers), mais à écrire dans toute consigne future.
- **Chromium 141 et chromedriver 147** dans le conteneur : `SessionNotCreatedError` sur tous les tests système. Pilote 141 téléchargé depuis Chrome for Testing dans le scratchpad, passé par `CHROMEDRIVER_PATH` ; `CHROME_BIN=/opt/pw-browsers/chromium`.
- **Activité paresseuse invisible au téléphone** dans le premier jet du test système : le frame `loading: lazy` ne se charge qu'en vue. Comportement voulu (données mobiles), le test fait défiler.
- **Budget de l'accueil dépassé (ADR-0067)** : une fois le jeu de données de performance réparé sur `Develop` (chantier `dettes-reorganisation`), l'accueil mesure 138 à 152 ms au p95 pour un budget de 100 ms ; l'ancienne page, 92,6 ms sur la même machine. Le nombre de requêtes était constant (11) : il ne disait rien du coût de chacune. Le compte des élèves distincts a été fondu dans la lecture des effectifs (`GROUPING SETS`), une requête de moins ; l'écart restant (≈ 21 ms en médiane) vient surtout de la lecture des enseignants, sur une base qui frôle déjà le budget. Décision du porteur : cache de 5 minutes (Lot F).
- **Gardes en US-ASCII** : `domain_purity_test` et `repository_rules_test` lèvent `invalid byte sequence` hors locale UTF-8 ; lancer avec `LANG=C.UTF-8`.
- **Environnement cloud sans Ruby 3.4.9 ni PostgreSQL démarré** : `.ruby-version` exige 3.4.9, le conteneur n'avait que 3.1 à 3.3. Installation par `rbenv install 3.4.9` (compilation), démarrage de PostgreSQL 16 et création du rôle `dev-rails` de `config/database.yml`.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Le journal d'audit (`audit_events`) ne porte pas l'établissement : une activité par établissement ne peut pas s'y lire sans migration. L'activité se lit dans les tables métier datées (devoirs, adhésions, rattachements).
- Les niveaux n'ont ni icône ni couleur en base ; leurs slugs sont figés (`Entities::Catalog::Level::SLUGS`), ce qui permet une table de correspondance côté vue, comme les matières (UDR-0069).
- `classroom_assignments` n'accepte que des exercices (`assignable_type = 'Exercise'`, contrainte en base) : un « devoir donné » a toujours un titre d'exercice.
- Le Turbo Stream du masquage d'une annonce (chantier `annonces`) remplace `#student_home_announcements` : réutiliser le carrousel tel quel sur l'accueil de la direction suffit pour que masquer et « Annuler » y fonctionnent.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Libellés de la barre de navigation du bas en 11 px (`text-2xs`, `NavigationHelper::NAV_STYLES[:bottom]`) : sous le minimum de 12 px de la charte | Antérieur au chantier (2026-09-25), commun à tous les rôles ; relevé par le challenger | à ouvrir : barre basse à 12 px |
| Nom accessible des bulles calculé « 6ème , 1 classe » par Chromium (espace avant la virgule) | Composant de l'UDR-0069 (`_subject_bubble`, éléments flex) ; cosmétique | à joindre au chantier de la barre basse |
| La ligne `schools` est lue deux fois par l'accueil (nom, puis type et statut) | Une requête économisable, sous le budget (11 ≤ 12) | optimisation si l'accueil grossit |
| Tuiles des chiffres à 320 px : « enseignants » peut encore déborder | Le PRD vise 375 px ; 360 px (plus petit Android courant) est testé | si des directions utilisent des écrans de 320 px |
| Décision D-A1 du porteur (l'équipe seule rédige, toute annonce se masque) non appliquée | `annonces` a été mergé selon sa propre conception ; c'est un changement de ses règles, hors de ce chantier | à ouvrir par le porteur : `annonces-allegees` ; s'il ouvre le masquage à la direction, passer `dismissible: true` sur l'accueil de la direction |
| Un frame différé en échec réseau (ou 500 hors de son contrôleur) affiche le « Content missing » de Turbo, sur l'accueil de la direction comme sur celui de l'élève | Corriger demande un écouteur `turbo:frame-missing` commun (JavaScript), hors du périmètre de l'UDR-0072 | à ouvrir : état d'erreur commun des frames différés |

## Clôture

| | |
|---|---|
| **Livré le** | *(au merge de la PR)* |
| **PR** | [Lnclassapp/App.Lnclassapp#167](https://github.com/Lnclassapp/App.Lnclassapp/pull/167), `feature/accueil-direction` → `Develop` |
| **ADR produits** | aucun nouveau ; ADR-0065 amendé le 2026-10-04 (accueil gardé 5 minutes) |
| **UDR produits** | UDR-0072 ; UDR-0052, UDR-0006, UDR-0071 amendées |
| **Lots** | 0, A, B, C, E, F et D faits ; phase 5 faite (challenger), quatre constats corrigés |
| **Chantiers de suivi** | D-A1 (`annonces-allegees`) · barre basse à 12 px · état d'erreur commun des frames différés · jeu de données de performance : fait sur `Develop` (`dettes-reorganisation`) |
