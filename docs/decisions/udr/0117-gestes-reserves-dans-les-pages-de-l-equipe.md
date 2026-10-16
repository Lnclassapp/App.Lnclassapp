# UDR-0117 : Gestes réservés selon le sous-rôle dans les pages partagées de l'équipe (catalogue, imports, Pilotage, fiche du compte, modération)
<!-- index
titre: Gestes réservés selon le sous-rôle dans les pages partagées de l'équipe
statut: Proposé
adr-lie: [0100](../adr/0100-matrice-des-sous-roles-de-l-equipe-par-capacite.md)
problematique: Des pages ouvertes aux trois sous-rôles portent des gestes que seuls certains peuvent faire ; chaque geste est rendu sur un booléen de policy, le Pilotage du contenu perd ses blocs nominatifs, les imports ne montrent que les types permis. Amende UDR-0020, UDR-0049, UDR-0055
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/sous-roles-equipe`](../../chantiers/sous-roles-equipe/memo.md) |
| **ADR lié** | [ADR-0100](../adr/0100-matrice-des-sous-roles-de-l-equipe-par-capacite.md) |
| **Amende** | [UDR-0020](0020-debloquer-un-compte.md) (actions de la fiche) · [UDR-0049](0049-page-pilotage-de-l-equipe.md) (blocs nominatifs) · [UDR-0055](0055-import-de-plusieurs-fichiers.md) (types proposés) |
| **Remplacé par** | — |

---

## 1. Contexte

Cinq pages restent ouvertes à plusieurs sous-rôles mais portent des gestes réservés :

- **Cours** (`/courses`) : « Nouveau cours » et « Importer » sont rendus à tout `team?` ; le terrain recevrait 403.
- **Imports** : la liste mélange les imports de contenu et d'établissements ; le formulaire propose les cinq types.
- **Pilotage** : la page entière exige aujourd'hui `ReadUserPolicy` (recherche nominative) ; le contenu, qui doit lire les indicateurs, en serait exclu.
- **Débloquer un compte** : « Réinitialiser le second facteur » est rendu à tout `team?`.
- **Modération des annonces** : rendue à tout `team?`.

## 2. Décision

- **Une page, des gestes conditionnés** : la page reste là où le sous-rôle a au moins une raison d'y être ; chaque geste réservé est rendu sur un booléen calculé par le contrôleur à partir de la policy du use case visé. Jamais `current_actor.team?` ni `team_role` dans la vue.
- **Un bloc nominatif est retiré, pas vidé** : au Pilotage, le contenu voit les indicateurs agrégés ; la recherche et les dernières inscriptions (noms) ne sont pas rendues du tout.
- **Les imports filtrent par type**, en liste comme en création : un membre ne voit jamais l'import qu'il n'aurait pas pu lancer.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Cours (`app/views/catalog/courses/index.html.erb`, `_page.html.erb`, `show.html.erb`)

- `Catalog::CoursesController` expose `can_manage_content` (`ManageContentPolicy`). La variable locale `team = current_actor.team?` est remplacée :
  - boutons « Importer » et « Nouveau cours » : `can_manage_content` ;
  - pastilles de statut (brouillon, archivé) sur les cartes et les fiches : `current_actor.may?(:read_catalog)` via un booléen `show_status` calculé au contrôleur (les trois sous-rôles le voient).
- La fiche d'un cours (`show`) : les menus d'édition, publication, archivage des fiches et exercices sont rendus sur `can_manage_content`.

### 3.2 Imports (`app/views/teams/imports/`)

- `Entities::Catalog::ImportKind.allowed_kinds(actor)` (domaine) renvoie les types dont la policy accepte l'acteur, génération des classes comprise pour le filtre de la liste.
- `index` : le filtre par type ne propose que ces types ; `Queries::Catalog::ImportReportsQuery#call(kinds:)` ne renvoie que leurs rapports. Le bouton « Importer » ouvre `new` avec le premier type permis.
- `new` : la liste des types (radios ou onglets de l'UDR-0055) ne montre que les types permis. Un `kind` interdit dans l'URL : 403.
- `show` d'un rapport d'un type interdit : 403 (déjà le cas par `authorize_report`).
- *Vide* : un membre sans aucun import permis n'existe pas (contenu : 3 types, terrain : 2 types + génération).

### 3.3 Pilotage (`app/views/teams/dashboards/`)

- `Teams::DashboardsController#show` autorise par `ReadIndicatorsPolicy` seule ; il calcule `can_read_people` (`ReadUserPolicy`).
- Rendus seulement avec `can_read_people` : `_search` (et son frame `team_dashboard_search`) et `_recent_signups`. Une requête au frame de recherche sans la capacité : 403.
- Toujours rendus : `_key_figures`, `_filters`, `_drenas`, `_levels`, `_schools` (noms d'établissements, sans personne).
- Mise en page : les blocs restants gardent leur ordre ; la grille ne laisse pas de colonne vide (le bloc suivant remonte).

### 3.4 Débloquer un compte (`app/views/teams/account_lookups/_result.html.erb`)

- La page entière exige `read_people` (admin, field) — inchangé dans la forme, `ReadUserPolicy` change de règle.
- « Émettre un code » : toujours rendu (la page est déjà réservée à `read_people`).
- « Réinitialiser le second facteur » (cible `team`) : rendu seulement avec `can_manage_team`.
- « Changer le rôle » (cible `team`, pas soi-même) : rendu seulement avec `can_manage_team` — détail dans l'UDR-0118.
- Suppression et demande de suppression (cible élève) : `can_delete`, inchangé.

### 3.5 Modération des annonces (`app/views/communication/moderations/index.html.erb`, `communication/shared/_tabs.html.erb`)

- `Communication::ModerationsController` refuse (403) un membre de l'équipe sans `moderate_announcements` ; la vue remplace `current_actor.team?` par un booléen `team_view` calculé au contrôleur.
- L'onglet qui y mène (`communication/shared/_tabs.html.erb`, onglet « Toutes » de l'équipe, clé `:moderation`) n'est rendu qu'avec un local `can_moderate` passé par chaque page qui rend les onglets ; sans lui, l'équipe n'a que l'onglet « Mes annonces ».

**Tokens** : aucun nouveau. Composants existants (`ui_button`, `ui_card`, `ui_modal`, `ui_empty_state`).

**Comportement** : aucun nouveau frame ; les frames existants (`team_dashboard_search`, `import_status`, `account_lookup`) refusent côté serveur ce que la vue ne rend pas.

**États obligatoires** : *Vide* et *Erreur* inchangés pour chaque page ; *403* pour une adresse forgée (page de l'UDR-0116 §3.4 en HTML, toast en Turbo Stream).

**Accessibilité** : un geste masqué n'est pas dans le DOM ; les boutons restants gardent `min-h-tap` ; l'ordre de tabulation reste continu.

**Captures exigées** : `/courses` pour terrain et contenu ; `/teams/imports` et sa modale « Importer » pour terrain et contenu ; `/teams/dashboard` pour contenu et terrain ; fiche d'un compte de l'équipe vue par un admin et par le terrain ; à 390 px et sur ordinateur.

## 4. Conséquences

- Un geste ajouté à une page partagée de l'équipe déclare sa capacité dans son UDR et arrive dans la vue par un booléen.
- Le Pilotage n'est plus « une page qui exige deux policies » : il exige `read_indicators`, ses blocs nominatifs `read_people`.
- Les tests de vue (ou d'intégration) de ces cinq pages vérifient, pour chaque sous-rôle, la présence ou l'absence de chaque geste par son `id`.
