# UDR-0013 : Catalogue et page cours — cartes filtrées dans un frame, contenu riche sous KaTeX, actions du rôle en modale

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) — *amendée le 2026-10-02 (acceptée par le porteur) par le chantier `interface-epuree`* — *amendée le 2026-10-02 (acceptée par le porteur) par le chantier `fonctions-espace-eleve` : plus d'assignation de cours ni de fiche (UDR-0062)* |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot B1, critères CA-01, CA-04, CA-10, CA-26, CA-27 (point d'entrée), TR-41 |
| **ADR lié** | [ADR-0028](../adr/0028-policies-de-domaine-par-use-case.md) (`ReadPublishedPolicy`) · [ADR-0035](../adr/0035-cycle-de-vie-et-propriete-du-contenu.md) (statuts) · [ADR-0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md) (KaTeX et Trix à la demande) · [UDR-0001](0001-design-visuel-du-catalogue-pedagogique.md) (carte-vitrine) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0006](0006-shell-applicatif-par-role.md) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) · [UDR-0014](0014-formulaire-cours.md) (modale du cours, panneau de statut) |
| **Remplacé par** | — |

---

## 1. Contexte

Le catalogue est la porte d'entrée de l'élève, de l'enseignant et de l'équipe. Dans l'ancienne application :

- les filtres par niveau et par matière étaient **silencieusement ignorés** (clés String lues en Symbol) et la pagination était factice ;
- un brouillon était **invisible de l'équipe** sur le catalogue, mais **lisible par n'importe qui** par son URL directe ;
- la couleur d'une matière venait de deux tables d'expressions régulières sur son **nom**, jamais de sa catégorie (CA-26) ;
- la page d'un cours intitulait « Habiletés » la liste des fiches, proposait « Supprimer » à l'équipe, et son bouton d'assignation pour l'enseignant n'était **jamais rendu** (CA-27) ;
- KaTeX venait d'un CDN.

## 2. Décision

1. **Une grille de cartes-vitrines, filtrée dans un frame.** Les filtres niveau et matière sont un formulaire `GET` qui vise le frame `courses` et avance l'URL : le filtre survit au retour arrière et au partage du lien, sans rechargement de page. Le serveur ne renvoie que le frame à ses requêtes. Pas de pagination en V1 : le catalogue publié tient en une page.
2. **Publié seulement, sauf pour l'équipe.** L'élève, l'enseignant et le personnel d'établissement ne voient que les cours publiés. L'équipe voit tous les statuts, chaque carte portant son badge (« Brouillon — visible uniquement par l'équipe », « Publié », « Archivé »). Un cours non publié ouvert par URL directe répond **404** hors de l'équipe, sans rien confirmer.
3. **La matière se reconnaît à sa catégorie** : `ui_subject_badge(name, category:)`, partout.
4. **Page d'un cours** : fil d'Ariane (Cours › matière › cours), en-tête (titre, sous-titre, badges), contenu riche, puis les fiches essentielles. Le contenu est rendu par Action Text, qui l'assainit par sa liste blanche (en plus de `RichTextSanitizer` à l'écriture), et ses formules `$…$` passent par le contrôleur `math` (KaTeX servi par l'application).
5. **Actions selon le rôle, dans l'en-tête.** L'équipe : le panneau de statut (`content_status_panel`, publier ou archiver) et un menu dont chaque entrée s'ouvre dans la modale : « Modifier », « Nouvelle fiche essentielle », « Importer des fiches essentielles ». L'enseignant : « Assigner à mes classes », qui mène à l'écran du Lot D7. Pas de « Supprimer » : un cours s'archive.
6. **Aucun stream propre.** Les pages de B1 sont en lecture ; les écritures (B2, B4, imports) rafraîchissent la page par morphing (`turbo_stream.refresh`) ou remplacent le panneau de statut.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- `catalog/courses/index` : `ui_page_header` (« Cours ») ; équipe : `ui_button` « Importer des cours » (`secondary`, `new_teams_import_path(kind: "course_tree")`) et « Nouveau cours » (`new_teams_course_path`), tous deux `data-turbo-frame="modal"`. Puis `form#courses-filters` (`role="search"`, `method: get`, `data-turbo-frame="courses"`, `data-turbo-action="advance"`) : `select` niveau et matière (« Tous les niveaux », « Toutes les matières »), « Filtrer », « Effacer ». Puis `turbo_frame_tag "courses", target: "_top"` → `#courses_total` (`aria-live`) et `ul#courses_list` (1 colonne, 2 dès `sm`, 3 dès `xl`). Une requête du frame `courses` ne reçoit que le frame.
- `_course_card` (`li#course_<slug>`) : `ui_card(href: course_path)` — toute la carte est le lien. Badge de matière et badge « niveau série », titre `h2` en `font-display font-extrabold`, sous-titre sur 2 lignes (`line-clamp-2`), pied « Ouvrir le cours » ; équipe : `content_status_badge` dans le pied. **Jamais la liste des fiches sur la carte.**
- `catalog/courses/show` : `nav` fil d'Ariane (`ol`, dernier élément `aria-current="page"`) ; `#course_header` → `ui_card` → `h1`, sous-titre, badges, puis `_role_actions`. `section#course_content` (si le contenu n'est pas vide) → `ui_card padding: :lg` → conteneur `#course_content_<empreinte>` → `#course_math_<empreinte>[data-turbo-permanent][data-controller=math]` → le rich text. `section#course_essentials` → titre « Fiches essentielles » → `ul` de `_essential_row`, ou l'état vide.
- `_essential_row` (`li#essential_<slug>`) : lien vers `course_essential_path`, sous-titre, badge « N exercices » ; équipe : `content_status_badge` de la fiche.
- `_role_actions` : équipe → `content_status_panel(record:)` (entité du cours) et `ui_dropdown` `#course-actions-menu` dont chaque `a[role=menuitem]` porte `data-turbo-frame="modal"` ; enseignant → `ui_button` « Assigner à mes classes » vers `course_assignments_path(slug)`.
- Lecture : `CourseCatalogQuery(actor:, level:, material:)` ; `CourseDetailQuery(slug:, actor:)`, puis `ReadPublishedPolicy` sur la ligne du cours ; `ManageContentPolicy` décide du panneau de statut, qui lit l'entité par `CourseRepository#find_by_slug`.

**Tokens**
- Composants `ui_*` et tokens `@theme` seulement. Aucune classe de l'ancienne application, aucune valeur arbitraire.
- Couleur d'une matière : `ui_subject_badge` (science → `brand`, littérature → `gold`, autres → `team`).

**Comportement**
- Filtrer : Turbo Frame `courses`, URL avancée, sans rechargement de page. Sans JavaScript, le même formulaire recharge la page filtrée.
- Une carte ouvre la page du cours par Turbo Drive (`target: "_top"` du frame).
- Rafraîchissement par morphing (modification du cours) : un contenu inchangé garde ses formules rendues (élément permanent) ; un contenu modifié change d'empreinte, donc d'id, et son conteneur est remplacé, ce qui reconnecte le contrôleur `math`. Un élément permanent seul ne serait jamais retiré par le morphing.
- Publier ou archiver : le stream du Lot B2 remplace `#content_status_course_<slug>` et affiche un toast.
- Ni Trix ni Action Text JavaScript ne se chargent sur ces pages ; KaTeX se charge à la demande.

**États obligatoires**
- Vide : « Aucun cours pour l'instant » ; aucun résultat filtré : « Aucun cours ne correspond à ces filtres » et « Effacer les filtres » ; cours sans fiche : « Aucune fiche essentielle pour ce cours. ».
- Chargement : Turbo marque `aria-busy` pendant le filtrage.
- Erreur : 404 (cours inconnu, ou non publié hors équipe) par `RendersResult`, sans aucune donnée du cours.
- Succès : sans objet ici ; les toasts viennent des Lots B2, B4 et de l'import.

**Accessibilité**
- Le formulaire de filtres est un `role="search"` nommé ; chaque `select` a son `label`.
- Le fil d'Ariane est un `nav` nommé, ses séparateurs `aria-hidden`.
- Le menu de l'équipe suit le motif « menu button » de `ui_dropdown` ; son nom cite le cours.
- Cibles tactiles ≥ 48 px ; les deux pages tiennent dans 390 px sans défilement horizontal (test système).

## 4. Conséquences

- Tout écran qui liste des cours réutilise `_course_card` et `ui_subject_badge(category:)`.
- Un brouillon n'est jamais lisible par URL directe hors de l'équipe ; `test/controllers/catalog/courses_controller_test.rb` le garde.
- Les formulaires ouverts depuis ces pages (B2, B4, imports) répondent par `turbo_stream.refresh` et ne rendent aucun partial de B1.
- Toute page qui passe du contenu à KaTeX et qui est rafraîchie par morphing reprend le motif « conteneur à empreinte + élément permanent ».
- Interdit désormais : « Habileté(s) » à l'écran, « Supprimer un cours », une couleur de matière tirée de son nom, un script ou une feuille de style servis par un CDN.

## Amendement du 2026-09-29 — finitions d'interface

*Chantier [`docs/chantiers/finitions-ux`](../../chantiers/finitions-ux/prd.md), [UDR-0054](0054-finitions-d-interface.md). Statut : `Accepté` (avec l'UDR-0054, par le porteur le 2026-09-29). Le texte ci-dessus reste tel qu'il a été accepté ; cette section fait foi en cas d'écart.*

- **Catalogue** : le formulaire des filtres (`form#courses-filters`) gagne un champ `q` (`ui_field as: :search`, « Rechercher un cours ») sur le nom du cours, sans casse ni accents, et porte le contrôleur `search` : envoi 300 ms après la dernière frappe (URL remplacée), envoi au changement des listes niveau et matière ; « Filtrer » reste sans JavaScript. État vide « Aucun cours ne correspond », avec « Effacer la recherche ». Pas de pagination dans ce chantier.
- **Page cours** : le fil d'Ariane complet (« Cours › Matière › Nom ») est remplacé par le lien de retour « Cours » (UDR-0054 §3.2).
- Titres par `page_title` : « Cours · <espace> · Lnclass », « <nom du cours> · <espace> · Lnclass ».

## Amendement du 2026-10-01 — l'élève ne voit que son niveau

*Décision du porteur du 2026-10-01 : « un élève de la TleD ne peut voir que les cours de la TleD uniquement ». Elle remplace, pour l'élève, la règle 2 du §2 (« publié seulement ») : l'élève ne voit que le publié **de son niveau**. Chantier [`catalogue-niveau-eleve`](../../chantiers/catalogue-niveau-eleve/memo.md).*

- **Niveau de l'élève** : le niveau (et la série) de ses classes **actives de l'année scolaire en cours**, dont il n'est pas sorti (`left_at` vide).
- **Cours lisibles** : ceux du niveau d'une de ces classes, **sans série** (communs à toutes les séries du niveau) ou **de la série de cette classe**. Un élève de Tle D lit la Tle D et la Tle sans série, jamais la Tle C ni un autre niveau.
- **Partout** : la règle vaut pour le catalogue, la page d'un cours, d'une fiche, d'un exercice, et le démarrage d'une session. Hors niveau, la réponse est **404**, comme pour un brouillon, sans rien confirmer.
- **Sessions et accueil** *(revue de sécurité de la mise en production, même jour)* : une session ouverte avant la règle, sur un exercice hors niveau, ne se joue plus. Elle ne reçoit plus de réponse et ne montre plus son résultat à son élève (404). Ce contrôle passe après celui du propriétaire : la session d'un autre élève reste un 403. L'accueil de l'élève ne liste plus les exercices assignés, les sessions terminées ni les fiches à revoir hors de son niveau (`Queries::Catalog::AudienceFilter`, la même règle en SQL que le catalogue).
- **Sans classe de l'année** : le catalogue est vide et le dit (« Rejoins ta classe pour voir tes cours »).
- **Catalogue de l'élève** : le filtre « Niveau » disparaît, puisqu'il n'en voit qu'un. Le sous-titre devient « Les cours de ton niveau, par matière. »
- **Autres rôles** : l'enseignant, la direction et l'équipe lisent toujours tous les niveaux. L'enseignant en a besoin pour assigner.
- **Assignation** *(décision du porteur, même jour)* : un contenu ne s'assigne qu'à une classe de son niveau, et de sa série si le cours en a une. Cela vaut pour le cours, la fiche et l'exercice. Sinon, `AssignResource` répond `:conflict` (`other_level`), en 422, avec un toast qui dit pourquoi, et rien n'est écrit. La règle est la même que pour la lecture (`LevelAudience`, avec la paire de la classe) : un élève ne reçoit jamais un contenu qu'il ne pourrait pas ouvrir. Les assignations hors niveau faites avant cette règle restent en base, mais l'élève ne peut pas les ouvrir.
- **Vérification** :
  - `test/domain/entities/catalog/level_audience_test.rb` ;
  - `test/domain/policies/catalog/read_own_level_policy_test.rb` ;
  - les tests de `StudentAudienceQuery`, `CourseLevelQuery` et `CourseCatalogQuery` ;
  - `test/controllers/catalog/student_level_test.rb` (les cinq portes).

## Amendement du 2026-10-02 — épuration (UDR-0057) · Statut : Accepté (2026-10-02, porteur)

> **Décision du porteur (2026-10-02)** : amendement accepté. Les retraits ne valent **que pour l'élève** : l'enseignant et l'équipe gardent ces écrans inchangés, y compris pour les simples répétitions. Toute ligne du tableau ci-dessous qui vise un autre rôle est caduque.

*Chantier [`interface-epuree`](../../chantiers/interface-epuree/memo.md), Lot D, règle de l'[UDR-0057](0057-ecrans-eleve-epures.md). Le texte ci-dessus et les amendements précédents restent en vigueur. Une fois acceptée, cette section fait foi en cas d'écart.*

L'élève arrive au catalogue par la navigation, et bientôt par les cases de matière de l'accueil (`courses_path(material: <slug>)`, [UDR-0058](0058-accueil-eleve.md) §3.2). Cet amendement applique la règle de sobriété au catalogue et à la page d'un cours, tels que l'élève les voit. Ces deux écrans n'ont pas de maquette : ils gardent une seule mise en page, épurée à toutes les tailles (UDR-0057 §3).

### Changements pour l'élève

**Catalogue** (`catalog/courses/index`, `_course_card`)

| Élément | Aujourd'hui | Après | Règle (R1–R6, Q4) | Où va l'information |
|---|---|---|---|---|
| Sous-titre de l'en-tête | « Les cours de ton niveau, par matière. », affiché en permanence | `ui_page_header title: t(".title")`, sans sous-titre. Dans le bloc de l'en-tête : `ui_info_tip t(".student_scope"), label: t(".student_scope_label")` | R4 | Dans l'infobulle : « Tu vois seulement les cours de ton niveau. » (`student_scope`). Son nom : « Quels cours ? » (`student_scope_label`). |
| Badge « niveau série » de chaque carte | « Tle D » ou « Tle » sur chaque carte | Non rendu pour l'élève | R6 | L'élève ne voit que son niveau : le badge redit la même chose sur chaque carte. Le niveau reste dans l'en-tête de la page du cours et de la fiche. |
| Badge de matière de chaque carte, quand le filtre « Matière » est actif | Sur chaque carte | Non rendu pour l'élève seulement (décision du porteur du 2026-10-02) | R6 | La liste « Matière » du formulaire dit la matière, une fois. Sans filtre de matière, le badge reste sur chaque carte. |
| Rangée des badges de la carte (`div.mb-4`) | Toujours rendue | Rendue seulement si elle porte au moins un badge | R6 (conséquence) | — |
| Description de l'état « aucun résultat » | « Essayez un autre nom, un autre niveau ou une autre matière. » | Élève : « Essaye un autre nom ou une autre matière. » (`student_no_match_description`) | Clarté du filtre par matière (UDR-0058 §3.2) | L'élève n'a pas de filtre de niveau. Le texte le tutoie, comme ses autres textes. Une case de matière sans cours mène donc à un état vide juste. |

**Page d'un cours** (`catalog/courses/show`, `_essential_row`)

| Élément | Aujourd'hui | Après | Règle (R1–R6, Q4) | Où va l'information |
|---|---|---|---|---|
| Liste `#course_essentials` | Toutes les fiches | Les 3 premières lignes, puis « Voir plus » | R3 | Les lignes suivantes sont rendues, en `hidden`. « Voir plus » les révèle sans requête. |
| Ligne `_essential_row` | Seul le nom est un lien. La ligne s'empile au téléphone. | La ligne entière est le lien (lien étiré vers `course_essential_path`). Nom tronqué, sous-titre tronqué, chevron à droite. État pressé `active:bg-mist`. | Règle « Listes » de l'UDR-0057 | Rien n'est retiré. |

La pastille de matière de la règle « Listes » n'est pas rendue dans `_essential_row`. Toutes les fiches d'un cours ont la matière du cours, déjà dite par le badge de l'en-tête (R6).

Ce qui ne change pas pour l'élève :
- catalogue : la recherche, la liste « Matière », « Filtrer » (caché par le contrôleur `search`), « Effacer », le compteur `#courses_total`, le titre et le sous-titre de chaque carte, le pied « Ouvrir le cours », les états vides ;
- page cours : le retour « Cours », l'en-tête (titre, sous-titre, badges de matière et de niveau), le contenu sous KaTeX, le titre de la liste et son état vide.

**La grille du catalogue n'est pas plafonnée à 3 (exception à R3).** La grille est l'objet même de la page. Elle est déjà réduite trois fois : au niveau de l'élève, à la matière choisie, au nom cherché. Depuis une case de l'accueil, l'élève ne voit que les cours d'une matière. Un « Voir plus » cacherait des cours sans rien alléger.

### Contrôle de la règle

| Règle | Catalogue (élève) | Page cours (élève) |
|---|---|---|
| R1 — une action principale | Avec JavaScript, aucune : « Filtrer » est caché. Sans JavaScript, « Filtrer » (`primary`) est la seule. « Effacer » est `ghost` ; « Effacer la recherche » est `secondary`. | Aucune : `_role_actions` ne rend rien pour l'élève. |
| R2 — 5 blocs au plus avant le défilement | 3 : en-tête, formulaire `#courses-filters`, frame `courses`. | 3 : retour, `#course_header`, conteneur du contenu et des fiches. |
| R3 — 3 lignes, puis « Voir plus » | Exception justifiée ci-dessus : la grille est l'objet de la page. | Respectée : `#course_essentials` montre 3 lignes, puis « Voir plus ». |
| R4 — aucun texte d'aide permanent | Respectée : le sous-titre passe dans l'infobulle. Les états vides gardent leur phrase, obligatoire (UDR-0057, « États obligatoires »). | Respectée : aucun texte d'aide. Le sous-titre du cours est du contenu, pas une aide. |
| R5 — un seul accent | Respectée. La teinte de `ui_subject_badge` code la matière par sa catégorie ; elle n'est pas un accent. Aucune couleur n'est ajoutée. | Respectée, pour la même raison. |
| R6 — une information une fois | Respectée : le niveau quitte les cartes ; la matière filtrée quitte les cartes. | Respectée : le cours est nommé une fois (`h1`), sa matière et son niveau une fois (badges de l'en-tête). Le retour dit « Cours », pas le nom du cours. |

### Règles d'implémentation

**`catalog/courses/index`**
- Élève : `ui_page_header title: t(".title") do` → `ui_info_tip t(".student_scope"), label: t(".student_scope_label")`. Les autres rôles gardent leur en-tête.
- Les cartes reçoivent `locals: { show_status: team, show_level: !student, show_material: !(student && @filters[:material].present?) }`. Les deux nouveaux locals valent `true` par défaut : un autre appel de `_course_card` garde son rendu.
- État « aucun résultat » : `description: t(student ? ".student_no_match_description" : ".no_match_description")`.

**`_course_card`**
- Locals : `show_status:`, `show_level:`, `show_material:`.
- `ui_subject_badge` seulement si `show_material` ; le badge « niveau série » seulement si `show_level`.
- La rangée des badges n'est rendue que si l'un des deux l'est. Le reste de la carte ne change pas.

**`catalog/courses/show`**
- `student = current_actor.student?`.
- La liste est rendue par `@detail.essentials.each_with_index`. Chaque ligne reçoit `student:` et `folded: student && index >= 3`.
- Une ligne `folded` porte `hidden` et la cible du contrôleur `reveal`, selon le contrat du Lot 0.
- Après le `ul`, si l'élève a plus de 3 fiches : « Voir plus » du Lot 0 (`ui_button`, `ghost`, pleine largeur, contrôleur `reveal`, région `aria-live="polite"`, textes de `shared.components`).
- Enseignant et équipe : la liste reste complète, sans « Voir plus ».

**`_essential_row`**
- Locals : `essential:`, `course_slug:`, `show_status:`, `student: false`, `folded: false`.
- Élève : `li#essential_<slug>.relative.flex.items-center.gap-3.px-4.py-4.active:bg-mist.sm:px-5`. Le lien du nom porte `after:absolute after:inset-0` (motif de `classroom/classrooms/_assigned_courses`). Nom et sous-titre `truncate`. À droite, `ui_icon "chevron-right", variant: :mini`, en `text-mute`, `aria-hidden`.
- Enseignant et équipe : la ligne actuelle, inchangée.

**`config/locales/catalog/courses.fr.yml`**
- Retirer `index.student_subtitle`.
- Ajouter `index.student_scope` : « Tu vois seulement les cours de ton niveau. »
- Ajouter `index.student_scope_label` : « Quels cours ? »
- Ajouter `index.student_no_match_description` : « Essaye un autre nom ou une autre matière. » (« Essaye » et non « Essaie » : le vocabulaire de l'UDR-0007 interdit « essai », et `test/i18n/locale_files_test.rb` refuse « Essaie ».)

**Tokens** : tokens du `@theme` seulement (UDR-0005). Aucune couleur en dur, aucune valeur entre crochets, aucun `dark:`.

### Inchangé pour l'enseignant et l'équipe

- `_role_actions` : le panneau de statut, le menu ⋮ de l'équipe et « Assigner à mes classes » de l'enseignant.
- L'en-tête du catalogue de l'équipe : « Importer des cours » et « Nouveau cours ». Le sous-titre « Les cours du programme, par matière et par niveau. ».
- Le filtre « Niveau », le badge « niveau série » de chaque carte, le badge de statut des cartes et des fiches.
- La liste complète des fiches d'un cours, sans « Voir plus », et la forme actuelle de `_essential_row`.
- Le badge de matière de chaque carte, même quand le filtre « Matière » est actif (décision du porteur du 2026-10-02 : les retraits ne valent que pour l'élève).

### Vérification

- `test/controllers/catalog/student_level_test.rb` : le catalogue de l'élève n'a plus de sous-titre et porte l'infobulle ; ses cartes n'ont pas de badge de niveau.
- `test/system/catalog/course_catalog_test.rb`, à 390 × 844, pour l'élève : sur `courses_path(material: <slug>)`, `assert_single_primary_action` et `assert_blocks_above_fold(max: 5)`, et aucune carte ne porte le badge de matière ; sur la page d'un cours à 4 fiches, `assert_list_capped(max: 3)` sur `#course_essentials`, puis « Voir plus » montre la 4e.
- `test/controllers/catalog/courses_controller_test.rb` : l'enseignant et l'équipe voient le badge de niveau, le badge de matière sous filtre, la liste complète et `_role_actions` inchangé.

## Amendement du 2026-10-02 — un cours ne s'assigne plus · Statut : Accepté (porteur, 2026-10-02 : « lance les lots »)

*Chantier [`fonctions-espace-eleve`](../../chantiers/fonctions-espace-eleve/memo.md), grill Q6 et Q7 ; [ADR-0072](../adr/0072-assignation-d-exercices-et-echeance-a-la-prochaine-seance.md) (seul un exercice s'assigne) ; [UDR-0062](0062-echeances.md) §3.6. Le texte ci-dessus reste tel qu'il a été accepté ; cette section fait foi en cas d'écart.*

- **§2.5 et `_role_actions`** : l'enseignant n'a plus « Assigner à mes classes ». `_role_actions` ne rend rien pour lui : il lit le cours, ses fiches et leurs exercices, sans action dans l'en-tête. Le panneau de statut et le menu ⋮ de l'équipe ne changent pas.
- La route `course_assignments` et son écran disparaissent (UDR-0030, dépréciée).
- **Amendement du 2026-10-01, puce « Assignation »** : la règle de niveau vaut désormais pour le seul exercice ; « Cela vaut pour le cours, la fiche et l'exercice » se lit « Elle vaut pour l'exercice ».
- **Amendement du 2026-10-01, puce « Autres rôles »** : l'enseignant lit toujours tous les niveaux ; il assigne depuis sa classe (UDR-0062 §3.4), plus depuis le catalogue.
- **Vérification** : `test/controllers/catalog/courses_controller_test.rb` — sur la page d'un cours, un enseignant ne voit aucun lien vers `course_assignments_path`, ni aucun bouton « Assigner » ; l'équipe garde `#course-actions-menu`.

## Amendement du 2026-10-03 — réorganisation des espaces équipe et enseignant

*Chantier [`docs/chantiers/reorganisation-equipe-enseignant`](../../chantiers/reorganisation-equipe-enseignant/prd.md), [UDR-0069](0069-accueil-enseignant-par-niveau-et-assignation-depuis-le-catalogue.md). Statut : proposé, accepté avec le plan du chantier. Le texte ci-dessus reste tel qu'accepté ; en cas d'écart, cette section fait foi.*

- **Filtre « Série »** (UDR-0069 §3.4) pour l'enseignant et l'équipe : avec un niveau, il garde les cours sans série et ceux de la série choisie (la règle de l'élève). `FILTERS = %i[level series material q]`.
- **Puce « Autres rôles » de l'amendement du 2026-10-01** : l'enseignant assigne depuis sa classe **et** depuis le catalogue (fiche essentielle, page d'un exercice), aux seules classes de son niveau (UDR-0069 §3.8). La page d'un cours n'a toujours aucun bouton d'assignation.
