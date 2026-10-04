# Journal — Accueil de la direction : établissement, niveaux, annonces, activité

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-04 | Grill mené à partir de Q5 en **décisions par défaut** de l'agent, sans aller-retour | Consigne du porteur : « prendre des décisions, c'est autonome ; pose-moi la question si et seulement si tu doutes » | Non |
| 2026-10-04 | Le Lot 0 est exécuté par l'orchestrateur lui-même, sur la branche de chantier | Lot séquentiel et court ; aucun gain à un worktree pour un seul agent | Non |
| 2026-10-04 | Le Lot D n'a plus de test système ; AD-15 se prouve au niveau contrôleur | `script/ci/test_timings.yml` (budget système de 15 s par chantier) aurait été touché par D et E en parallèle : collision trouvée au Lot 0, le fichier reste au seul Lot E | Non |
| 2026-10-04 | Lot C : une panne de la base dans le frame d'activité répond 503 avec `ui_error_state`, journalisée | L'UDR exigeait un état d'erreur dans le frame ; sans JavaScript, seule la réponse peut le porter. Motif existant : compteur des articles (ADR-0074 §4.7). UDR-0072 §3.11 précisée | Non |
| 2026-10-04 | Lot C : un enseignant retiré mais non anonymisé garde son nom sur ses devoirs passés | Écart memo ↔ UDR relevé par l'exécutant ; l'UDR l'emporte (fait daté, seul l'anonymisé est masqué). Memo corrigé | Non |
| 2026-10-04 | Lot B : le nombre de la moyenne est mis en valeur comme celui du taux (`font-medium text-ink`) ; UDR-0072 §3.8 précisée | Lecture de l'exécutant (« même rendu » pour les deux lignes), retenue : deux chiffres voisins, un seul style | Non |
| 2026-10-04 | Lot B : le test rouge et le code sont dans le même commit | Le pre-commit refuse un test rouge ; le rouge d'abord est prouvé par le rapport de l'exécutant (9 erreurs `MissingController` avant le code), pas par l'historique | Non |
| 2026-10-04 | La pastille de la bulle n'ajoute `relative` au rond que si elle est présente | UDR-0072 §3.5 : sans signal, la bulle reste strictement celle de l'UDR-0069 (accueil enseignant inchangé) | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Branche de départ périmée** : le chantier a été ouvert sur un `Develop` local en retard de plusieurs dizaines de commits (accueil enseignant par niveau, gestes de la direction, pilotage par DRENA). Constaté en lisant la branche `annonces` ; branche rebasée sur `origin/Develop` avant le grill Q2. À faire au départ de tout chantier : `git fetch origin Develop` **avant** de brancher.
- **Test de routage qui chargeait le contrôleur d'un autre lot** : `recognize_path` instancie le contrôleur ; le Lot 0 dessine des routes dont les contrôleurs n'arrivent qu'aux Lots B et C. Corrigé en lisant la route par le routeur seul (`first_match`).
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
| Un frame différé en échec réseau (ou 500 hors de son contrôleur) affiche le « Content missing » de Turbo, sur l'accueil de la direction comme sur celui de l'élève | Corriger demande un écouteur `turbo:frame-missing` commun (JavaScript), hors du périmètre de l'UDR-0072 | à ouvrir : état d'erreur commun des frames différés |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
