# Journal — Annonces ciblées, programmables et écartables

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-03 | La V6 sort du backlog : le chantier `annonces` s'ouvre | Demande du porteur (« nous allons mettre en place la feature d'annonce ») | — (feuille de route à dater) |
| 2026-10-03 | Trois auteurs : équipe, direction (officielle), enseignant (ses classes) | Grill + maquette de l'accueil élève validée par le porteur | ADR-0078 |
| 2026-10-03 | Date de fin obligatoire (30 j par défaut, 90 j au plus), filtrée à la lecture | « L'auteur seul gère » laissait des annonces orphelines en ligne | ADR-0078 |
| 2026-10-03 | Retrait par l'équipe et par la direction, distinct de l'archivage | Contenu déplacé destiné à des mineurs | ADR-0078 |
| 2026-10-03 | Texte de 140 caractères, sans page de détail ; l'audio porte les détails | Choix du porteur | ADR-0078, UDR-0071 |
| 2026-10-03 | Audio = fichier téléversé, pas de synthèse vocale | Choix du porteur, contre le design system §10 | UDR-0071 (écart assumé) |
| 2026-10-03 | Un Lot D d'intégration porte les entrées de navigation | `role_homes_test` compte et suit chaque entrée : une entrée sans page casse tous les worktrees | — (plan) |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Cadrage, 2026-10-03** : le premier jet du memo suivait l'ADR-0045 à la lettre. La maquette du porteur, apportée en cours de grill, en contredisait sept points (auteurs, audio, image, officiel, signature, ordre, page de détail). Leçon : demander la maquette **avant** le grill, pas pendant.
- **Lot 0, 2026-10-04** : la contrainte `status = 'draft' OR ends_at IS NOT NULL` de l'ADR-0078 interdisait d'archiver un brouillon. Vue à la relecture du Lot 0, avant le merge ; corrigée en « date de fin exigée des annonces en ligne » (amendement de l'ADR-0078). Leçon : écrire, pour chaque `CHECK`, la transition de statut qui pourrait la violer.
- **Lot 0** : l'UDR-0071 titrait « Lot 0 » la carte et l'audio que le plan donnait au Lot B ; l'agent a suivi le plan. Deux documents écrits le même jour se contredisaient déjà : relire l'UDR contre le plan avant de lancer.
- **Environnement** : Ruby 3.4.9, PostgreSQL, Yarn 4 (Corepack) et un chromedriver accordé au Chromium (141) manquaient à la session ; `LANG=C.UTF-8` est nécessaire au garde de pureté.
- **Cadrage** : le plan écrivait « DS-11 amendé » alors que les routes d'annonces vivent sous `/announcements` ; DS-11 tient tel quel. Corrigé avant le commit.

- **Merge de `Develop`, 2026-10-04** : pendant le cadrage, `Develop` a pris les numéros ADR-0069 et UDR-0056, la version de migration `20261003100000`, et ouvert le contexte `communication` (blog, ADR-0074) ; l'ADR-0071 avait déjà levé la lecture seule de la direction. Renumérotation en ADR-0078 et UDR-0071, migrations décalées au `20261004…`, fabriques et routes fusionnées. Leçon : avant de numéroter une décision, regarder `origin/Develop` **et** les branches ouvertes (`git ls-tree` sur `origin/*`), pas seulement le dépôt local.

- **Lot A, 2026-10-04** : l'UDR prévoyait `ui_field … as: :file` et `as: :datetime_local`, que le composant ne connaît pas ; contourné par `type:` (amendement de l'UDR-0071). Leçon : vérifier chaque `as:` d'une UDR contre `FIELD_BUILDERS` avant de la figer. Pendant le merge, `ImageHeader` avait migré de `identity` à `shared` sur `Develop` : corrigé au merge.

- **Lot B, 2026-10-04** : le garde `test/guards/system_budget_test.rb` de `Develop` exige la durée de chaque test système dans `script/ci/test_timings.yml` (fichier partagé) et borne le temps système du chantier (15 s) ; durée enregistrée au merge (5,4 s). Le Lot D devra tenir dans le reste. Le carrousel faisait défiler la page en largeur sur téléphone (`min-w-0` manquant), vu par le test système et non par les tests de vue.
- **Lot C, 2026-10-04** : le brief demandait `allow_roles :school_admin, :team` sur le retrait (enseignant → 403), contre AN-17 et l'ADR-0078 §4.2 (404) ; l'agent a suivi l'ADR. L'UDR donnait le même id au frame et à la liste (amendée). Leçon : un brief se relit contre les critères du PRD, pas seulement contre le plan.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `Entities::Identity::Actor` ne porte pas l'établissement d'un élève (`school_id: nil`) ni sa classe : la lecture doit les résoudre (classe principale active → établissement).
- Marcel, cité par l'ADR-0045, n'est appelé nulle part : les types de fichiers se lisent dans les octets (`Entities::Identity::ImageHeader`, ADR-0060).
- `ui_toast` n'a pas d'emplacement d'action, et aucun motif « Annuler » n'existe : il naît au Lot 0.
- `NAV_GRIDS` s'arrête à 5 colonnes ; l'équipe en a déjà 5.
- `test/architecture/port_contracts_test.rb` exige un adaptateur dès qu'un port existe : un port ne peut pas être gelé seul au Lot 0.
- Le contrôleur `Stimulus` s'enregistre par motif de fichier (`controllers/index.js`) : aucun manifeste partagé.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Enregistrer sa voix depuis le navigateur (webm/opus) | Hors périmètre ; formats non autorisés par l'ADR-0045 | à ouvrir si les auteurs le demandent |
| Texte alternatif de l'image téléversée | Hors périmètre ; une image porteuse d'information est inaccessible | à ouvrir si les auteurs mettent l'information dans l'image |
| Fonctions précises de la direction dans la signature | Pas de donnée en base | `espace-direction` (backlog) |
| Signalement d'une annonce déplacée | La modération est réactive | à ouvrir après les premiers retours |
| `announcement_date` et ses formats copiés de « Mes annonces » dans `ModerationsController` | Lots A et C parallèles, fichiers disjoints | helper commun au prochain passage dans `communication` |
| « Retirer » sans nom accessible propre à chaque annonce | `ui_modal` ne prend pas d'`aria-label` de déclencheur | chantier de composants |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
