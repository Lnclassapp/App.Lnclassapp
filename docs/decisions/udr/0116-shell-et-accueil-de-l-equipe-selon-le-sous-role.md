# UDR-0116 : Shell, accueil et Référentiel de l'équipe filtrés par sous-rôle, page « Accès interdit » qui le dit
<!-- index
titre: Shell, accueil et Référentiel de l'équipe selon le sous-rôle
statut: Proposé
adr-lie: [0100](../adr/0100-matrice-des-sous-roles-de-l-equipe-par-capacite.md)
problematique: Le shell et l'accueil montrent les mêmes entrées aux trois sous-rôles ; une entrée porte désormais une capacité et disparaît pour qui ne l'a pas ; la page 403 dit à un membre de l'équipe pourquoi. Amende UDR-0006, UDR-0018, UDR-0068
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/sous-roles-equipe`](../../chantiers/sous-roles-equipe/memo.md) |
| **ADR lié** | [ADR-0100](../adr/0100-matrice-des-sous-roles-de-l-equipe-par-capacite.md) |
| **Amende** | [UDR-0006](0006-shell-applicatif-par-role.md) (destinations de l'équipe) · [UDR-0018](0018-accueil-equipe.md) (raccourcis et sections) · [UDR-0068](0068-configuration-et-pilotage-par-etablissement.md) §3.1, §3.4 (menu « Plus », tuiles du Référentiel) |
| **Remplacé par** | — |

---

## 1. Contexte

Un membre « Contenu » voit aujourd'hui « Établissements » dans sa navigation, « Débloquer un compte » sur son accueil, les tuiles DRENA et Barème dans le Référentiel. Avec l'ADR-0100, ces pages lui répondent 403 : laisser l'entrée en place, c'est l'envoyer contre un mur à chaque clic. À l'inverse, un membre qui arrive sur une page interdite par un lien reçu voit aujourd'hui « Accès interdit. » sans savoir que c'est son rôle dans l'équipe qui en décide.

## 2. Décision

- **Masquer, jamais griser.** Une entrée hors du sous-rôle n'est pas rendue (ni dans la barre latérale, ni dans la barre basse, ni dans le menu « Plus », ni sur l'accueil, ni dans le Référentiel). Une entrée grisée promettrait un accès que le membre ne peut pas demander à l'écran.
- **Une seule source** : chaque destination de l'équipe déclare la capacité qui la conditionne ; le helper filtre avec `current_actor.may?`. La vue ne connaît jamais le nom du sous-rôle.
- **La page 403 existante** reçoit une phrase propre à l'équipe ; pas de nouvelle page, pas de liste des rôles qui donnent accès (elle apprendrait la matrice à qui n'en a pas besoin).

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Destinations du shell (`app/helpers/navigation_helper.rb`)

- `DESTINATIONS[:team]` et `SECONDARY_DESTINATIONS[:team]` gagnent un 4e élément facultatif : la capacité (`Symbol`) ou `nil`.
- `navigation_for(role, actor = nil)` et `secondary_navigation_for(role, actor = nil)` rejettent une destination dont la capacité est posée et que `actor&.may?(capacité)` refuse. `bottom_bar_size`, `more_active?` et `home_path_for` reçoivent et transmettent l'acteur. Le shell (`layouts/shell`, partials `shared/navigation/*`) passe `current_actor`.
- Table attendue :

| Liste | Entrée | Capacité | admin | content | field |
|---|---|---|---|---|---|
| principale | Accueil | — | ✅ | ✅ | ✅ |
| principale | Cours | — (`read_catalog` pour tous) | ✅ | ✅ | ✅ |
| principale | Établissements | `manage_schools` | ✅ | | ✅ |
| principale | Pilotage | `read_indicators` | ✅ | ✅ | ✅ |
| « Plus » | Référentiel | — | ✅ | ✅ | ✅ |
| « Plus » | Imports | — (types filtrés, UDR-0117) | ✅ | ✅ | ✅ |
| « Plus » | Annonces | `publish_announcements` | ✅ | ✅ | ✅ |

- Barre basse : `NAV_GRIDS` couvre déjà 4 et 5 cases. Admin et terrain : 5 cases (4 + « Plus ») ; contenu : 4 cases (3 + « Plus »). Aucune case vide, aucun espace réservé.
- Les autres rôles ne déclarent pas de capacité : leurs listes sont inchangées.

### 3.2 Accueil de l'équipe (`app/views/teams/homes/`)

- `Teams::HomesController#show` calcule un booléen par geste, tiré des policies : `can_create_course` (`ManageContentPolicy`), `can_manage_schools` (`ManageSchoolPolicy`), `can_manage_blog` (déjà), `can_invite` (déjà), `can_read_people` (`ReadUserPolicy`). Les booléens existants `@deletion_requests` (admin) et `@archived_staff` (admin, field) restent.
- `_shortcuts.html.erb`, dans cet ordre, chaque bouton conditionné :

| Raccourci | Condition |
|---|---|
| Nouveau cours (modale) | `can_create_course` |
| Établissements | `can_manage_schools` |
| Imports | toujours |
| Croissance | toujours (`read_indicators` pour tous) |
| Blog | `can_manage_blog` |
| Inviter un membre (modale) | `can_invite` |
| Débloquer un compte | `can_read_people` |

- Sections (`HOME_SECTIONS[:team]`) : la carte « Régions » n'est rendue qu'avec `can_manage_schools` ; la carte « Activité » (contenu récent, frame différé `team_home_recent_content`) n'est rendue qu'avec `can_create_course`. Un membre « Terrain » a donc sur l'accueil : raccourcis, directions retirées éventuelles, « Régions ». Un membre « Contenu » : raccourcis, « Activité ».
- Le frame différé `team_home_recent_content` refuse (403) à qui n'a pas `manage_content` : la carte n'est pas rendue, la requête forgée ne fuit rien.

### 3.3 Référentiel (`app/views/teams/referentials/_summary.html.erb`)

- Chaque tuile de `figures` porte sa condition ; le contrôleur passe les booléens `can_manage_schools` et `can_manage_taxonomy`, `can_manage_illustrations`.

| Tuile | Condition |
|---|---|
| DRENA | `can_manage_schools` |
| Niveaux, Séries, Matières | `can_manage_taxonomy` |
| Barème des classes | `can_manage_schools` |
| Illustrations d'annonce | `can_manage_illustrations` |

- La grille garde ses colonnes ; une tuile absente n'est pas remplacée. La structure scolaire (bloc sous les tuiles) reste visible de tous : elle ne contient aucune donnée nominative.

### 3.4 Page « Accès interdit » (`app/views/errors/forbidden.html.erb`)

- Si `current_actor&.team?` : description `t(".team_description")` = « Votre rôle dans l'équipe ne donne pas accès à cette page. Un administrateur peut le changer. » ; action « Retour à l'accueil » vers `team_home_path`. Sinon : texte et lien actuels.
- Titre inchangé (« Accès interdit »), icône `no-symbol`, layout `application`, statut 403. Pas de bouton retour (UDR-0054 §3.1).
- Turbo Stream : toast `errors.codes.forbidden` inchangé ; la modale reste ouverte.

**Tokens** : aucun nouveau ; `ui_button`, `ui_card`, `ui_empty_state` existants. Aucune couleur, aucun espacement en dur.

**États obligatoires**

- *Vide* : impossible sur l'accueil (« Imports » et « Croissance » sont communs) ; le Référentiel du terrain a au moins DRENA et Barème, celui du contenu Niveaux, Séries, Matières, Illustrations.
- *Erreur* : 403 décrit au §3.4.
- *Succès* : un sous-rôle changé (UDR-0118) est visible à la navigation suivante, sans rechargement forcé.

**Accessibilité**

- Les cibles gardent `min-h-tap` (48 px) ; l'ordre de tabulation suit l'ordre visuel, sans trou.
- `aria-current="page"` inchangé ; « Plus » reste actif quand la page ouverte est l'une de ses entrées restantes.
- Aucune entrée masquée par CSS : elle n'est pas dans le DOM (un lecteur d'écran ne l'annonce pas).

**Captures exigées** : accueil, menu « Plus » ouvert et Référentiel pour chacun des trois sous-rôles, à 390 px et sur ordinateur ; page 403 d'un membre « Contenu » sur `/teams/schools`.

## 4. Conséquences

- Toute nouvelle entrée du shell de l'équipe déclare sa capacité, ou `nil` en le justifiant dans son UDR.
- `navigation_for` change de signature (acteur facultatif) : les tests du helper et les partials du shell suivent dans le Lot 0.
- Interdit désormais : tester `team_role` ou `current_actor.team?` dans une vue de l'équipe pour décider d'un geste ; la vue reçoit un booléen.
