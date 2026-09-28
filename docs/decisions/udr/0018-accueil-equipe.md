# UDR-0018 : Accueil équipe — raccourcis, régions éducatives, référentiel et activité récente différée

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) |
| **Date** | 2026-09-26 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot B6, critères TR-09, CA-25 ; TR-10 hors périmètre (V4) |
| **ADR lié** | [ADR-0034](../adr/0034-reprise-des-donnees-et-referentiel-seede.md) (référentiel créé à l'écran) · [ADR-0035](../adr/0035-cycle-de-vie-et-propriete-du-contenu.md) (statuts du contenu) · [ADR-0038](../adr/0038-comptes-de-l-equipe-et-sous-roles.md) (invitation par un admin) · [ADR-0039](../adr/0039-format-d-import-du-contenu.md) (imports) · [ADR-0041](../adr/0041-vie-d-une-classe-annee-scolaire-et-code.md) (année scolaire) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0006](0006-shell-applicatif-par-role.md) (shell, sections d'accueil) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) (vocabulaire) |
| **Remplacé par** | — |

---

## 1. Contexte

L'accueil est la page où arrive le membre de l'équipe, à chaque connexion. Dans l'ancienne application (`teams/feed/index`) :

- le fil lisait une constante `Orm` disparue : aucun test ne l'a signalé (TR-09, chantier `queries-constantes-orm-disparues`) ;
- les DRENA défilaient dans un carrousel, les niveaux dans une grille d'icônes, les activités dans une liste de données simulées ;
- les séries n'étaient listées nulle part ailleurs que dans l'onglet « Setup » d'un tableau de bord (CA-25). Ce tableau de bord lisait le référentiel par deux caches de 12 h, concurrents de ceux des écrans de gestion : une création pouvait rester invisible une demi-journée ;
- rien ne menait en un geste aux actions quotidiennes de l'équipe : créer un cours, importer, inviter, débloquer un compte.

L'équipe a besoin de voir l'état de la plateforme d'un coup d'œil, et d'atteindre en un geste chaque écran de gestion.

## 2. Décision

1. **Raccourcis en tête**, sous le titre : « Nouveau cours » (modale), « Établissements », « Importer », « Inviter un membre » (modale) et « Débloquer un compte ». « Nouveau cours » est l'action principale ; les autres sont secondaires.
2. **« Inviter un membre » n'apparaît qu'à qui peut inviter** : la vue demande à `Policies::Identity::InviteTeamPolicy`, et non au rôle. Un membre « contenu » ne voit pas un bouton qui lui répondrait 403 (recommandation de l'orchestrateur, en attente du porteur).
3. **Les sections suivent l'ordre du shell** (`HOME_SECTIONS[:team]`) :
   - « Régions éducatives » : les nombres de DRENA, d'établissements et de classes de l'année scolaire, puis « Voir les établissements » ;
   - « Référentiel » : la section de CA-25. Elle occupe la place de « Structure scolaire », dont elle reprend la liste des niveaux ;
   - « Activité récente », chargée en différé.
4. **Le référentiel se compte et se gère depuis l'accueil** : DRENA, niveaux, séries, matières, chacun avec son nombre et un lien « Gérer » vers son écran de gestion. L'accueil n'est **jamais le seul lieu** où lire une ressource (CA-25) : chaque compteur mène à la liste complète.
5. **Aucun cache** : chaque compteur est lu en base à chaque affichage, et une création de l'équipe se voit au retour sur l'accueil.
6. **« Structure scolaire »** liste les niveaux par position, chacun avec ses séries ouvertes, ou « Sans série ». On lit ainsi d'un coup d'œil la matrice niveau × série qui fixe la génération des classes.
7. **Activité récente** : les 5 derniers cours, les 5 derniers exercices et les 5 derniers imports, triés par dernière modification, **tous statuts confondus**. Chacun porte son statut (brouillon, publié, archivé ; statut d'import) et mène à sa page. La section est un frame paresseux : elle ne retarde pas l'affichage des chiffres.
8. **Classes comptées** : les classes actives de l'année scolaire en cours (ADR-0041). Une classe archivée ou d'une année passée n'est pas comptée. Les établissements sont comptés quel que soit leur statut.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- Écran `teams/homes/show` : `ui_page_header` « Bonjour, <prénom> », puis `_shortcuts`, puis une grille `grid gap-5` des sections de `home_sections_for(:team)`.
- `_shortcuts` : `nav#team_home_shortcuts` (`aria-label` « Raccourcis »), `flex flex-wrap gap-3` de `ui_button`. « Nouveau cours » : `primary`, icône `plus`, `data-turbo-frame="modal"`. Les autres : `secondary`, avec les icônes `building-library`, `arrow-up-tray`, `user-plus` (modale) et `lock-open`.
- `ui_card#team_home_regions` « Régions éducatives » : liste `ul.grid.grid-cols-3.gap-3` de trois chiffres (`rounded-ln bg-mist`, nombre en `font-display text-3xl`, libellé accordé au nombre) ; pied : « Voir les établissements » vers `schools_path`.
- `_referential` : `ui_card#team_home_referential` « Référentiel ». Liste `ul.grid.grid-cols-2.lg:grid-cols-4` de quatre liens (`rounded-ln border border-line`, icône `map-pin`, `squares-2x2`, `rectangle-stack`, `book-open` sur fond `brand-soft`, nombre, libellé, « Gérer » et sa flèche) vers `drenas_path`, `levels_path`, `series_index_path` et `materials_path`. Puis `h3` « Structure scolaire » et une pastille `li#level_<slug>` par niveau, avec ses séries.
- `ui_card#team_home_activity` « Activité récente » : `turbo_frame_tag "team_home_recent_content"`, `src: team_home_path`, `loading: :lazy`, `target: "_top"`, avec `ui_loading_state variant: :skeleton` pendant le chargement. Le contrôleur reconnaît le frame par `turbo_frame_request_id` et ne rend que `_recent_content` : trois colonnes (`lg:grid-cols-3`), `#team_home_recent_courses`, `#team_home_recent_exercises` et `#team_home_recent_imports`, une ligne `li#recent_<type>_<clé>` par élément.
  - Cours : nom, `ui_subject_badge`, niveau, `content_status_badge`, « Modifié il y a … », lien vers `course_path`.
  - Exercice : titre, fiche essentielle, statut, lien vers `exercise_path`.
  - Import : type (`import_kinds`), nom du fichier s'il est attaché, statut, lien vers `teams_import_path`.
- Lecture : `Queries::Catalog::TeamHomeQuery#call(today:)` → `Row(drenas_count, schools_count, classrooms_count, levels:, series_count, materials_count, recent_courses:, recent_exercises:, recent_imports:)`. Le frame lit seulement `recent_courses`, `recent_exercises` et `recent_imports`.

**Tokens**
- Composants `ui_*` et tokens `@theme` seulement ; fonds `mist` pour les chiffres, `brand-soft` pour les icônes du référentiel. Aucune classe de l'ancienne application, aucun carrousel, aucun dégradé.

**Comportement**
- Lecture seule : aucun Turbo Stream. « Nouveau cours » et « Inviter un membre » ouvrent la modale du layout sans rechargement ; tous les autres liens sont des navigations Turbo.
- Réservé à l'équipe, second facteur vérifié : un élève, un enseignant ou la direction reçoit 403.

**États obligatoires**
- Vide : chaque chiffre affiche 0. Sans niveau : « Aucun niveau pour l'instant. » Chaque liste récente sans élément : « Aucun cours pour l'instant. », « Aucun exercice pour l'instant. », « Aucun import pour l'instant. ».
- Chargement : squelette dans le frame de l'activité récente.
- Membre « contenu » : les raccourcis, sans « Inviter un membre ».

**Accessibilité**
- Chaque chiffre se lit en entier, nombre puis libellé (« 2 établissements ») ; les icônes sont décoratives.
- Les trois listes récentes sont des `section` nommées par leur titre (`aria-labelledby`).
- Cibles tactiles ≥ 48 px ; en 390 px, les raccourcis passent à la ligne et la page ne défile pas en largeur.

## 4. Conséquences

- L'accueil équipe ne lit aucun cache : sa lecture est bornée (sept comptages, deux lectures du référentiel, trois listes de 5 éléments) et ne dépend pas du volume des tables listées.
- Le « Control Center » (TR-10) reste hors périmètre (V4) : l'entrée « Pilotage » du shell reste inactive.
- Les messages de l'ancien fil (CO) ne sont pas repris en V1 : une section « Messages » s'ajoutera ici quand la communication sera livrée.


## Amendement du 2026-09-28 — le « Control Center » est livré

*Chantier [`docs/chantiers/pilotage-equipe`](../../chantiers/pilotage-equipe/prd.md). Statut : accepté, décidé par le porteur le 2026-09-28. Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- Le §4 « l'entrée Pilotage du shell reste inactive » ne vaut plus : TR-10 est livré en V4 par la page « Pilotage » ([UDR-0049](0049-page-pilotage-de-l-equipe.md)), active dans la navigation.
- L'accueil ne change pas : il garde ses compteurs du référentiel. Les indicateurs d'usage (élèves actifs, exercices terminés, couverture) vivent sur « Pilotage », pas sur l'accueil, pour que l'accueil reste une lecture bornée et rapide.

