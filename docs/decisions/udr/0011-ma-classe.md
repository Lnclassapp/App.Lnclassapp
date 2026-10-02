# UDR-0011 : Ma classe — la classe principale de l'élève, son code en majuscules et ses cours assignés, sans liste nominative

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) — *amendée le 2026-10-02 (acceptée par le porteur) par le chantier `interface-epuree`* |
| **Date** | 2026-09-26 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot A3, critères CL-22, CL-10 (volet élève) |
| **ADR lié** | [ADR-0028](../adr/0028-policies-de-domaine-par-use-case.md) (`ReadClassroomPolicy`, fait `show_roster`) · [ADR-0035](../adr/0035-cycle-de-vie-et-propriete-du-contenu.md) (cours publiés) · [ADR-0048](../adr/0048-statuts-d-assignation-active-et-archived.md) (assignations actives) · [UDR-0006](0006-shell-applicatif-par-role.md) (shell, entrée « Ma classe ») · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) (vocabulaire) · [UDR-0010](0010-accueil-eleve.md) (carte « Ma classe » de l'accueil) · [UDR-0027](0027-page-classe.md) (page classe de l'enseignant) |
| **Remplacé par** | — |

---

## 1. Contexte

« Ma classe » est la troisième entrée de la navigation de l'élève, et la destination de la carte « Ma classe » de son accueil. L'élève y vient pour savoir **à quelle classe il appartient** et **quels cours ses enseignants lui ont donnés**. Dans l'ancienne application (`students/classroom/show`, CS#B13) :

- la liste des cours assignés incluait les cours **retirés** par l'enseignant (assignations archivées) : l'élève ouvrait un cours qu'on ne lui demandait plus ;
- le compteur disait « habiletés », un terme que l'UDR-0007 remplace par « fiches essentielles » ;
- l'écran, lui, fonctionnait : il montrait la classe, l'établissement et le code d'adhésion en majuscules.

Le porteur a tranché le 2026-09-25 : **l'élève voit le code de sa classe**, en majuscules, sur son accueil et sur « Ma classe », comme dans l'ancienne application ; il ne voit **jamais la liste nominative** de ses camarades.

## 2. Décision

1. **Une page, `/students/classroom`, sans identifiant dans l'URL** : c'est toujours la classe principale active de l'élève connecté. Un élève ne peut pas y lire une autre classe, faute de paramètre à changer.
2. **Deux blocs empilés** : la carte de la classe (nom, niveau et série, établissement, année scolaire, code), puis la carte « Cours assignés ». Lisible d'un défilement, au téléphone comme au bureau ; aucun chargement différé.
3. **Le code est affiché, pas copiable.** Il est en majuscules, sous le nom « Code de la classe », avec l'aide « Tes camarades rejoignent la classe avec ce code. ». Pas de bouton « Copier » : l'élève le dicte ou le recopie ; le bouton reste un geste d'enseignant (UDR-0027). Le code vient de `ClassroomHeaderQuery`, sous `ReadClassroomPolicy`, comme sur la page de l'enseignant.
4. **Pas d'effectif ni de liste d'élèves** sur cette page : l'effectif est déjà sur l'accueil (UDR-0010), et la liste nominative est réservée aux adultes (`show_roster`). Elle n'est **même pas lue**.
5. **Les cours assignés** sont les assignations **actives** de type cours, dont le cours est **publié** (la même règle que la page de l'enseignant, lue par `ClassroomOverviewQuery` sans `show_roster`), triés par nom. Chaque ligne mène au cours du **catalogue** (`course_path`), où l'élève lit le cours et ses fiches essentielles.
6. **Sans classe principale active**, un seul saut vers l'écran de sortie (`pending_account_path`), comme l'accueil.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- Écran `classroom/student_classrooms/show` : `ui_page_header` « Ma classe » et « <établissement> · <classe> », puis une grille `grid gap-5` :
  - `ui_card#student_classroom_header` : pastille `academic-cap` (`bg-brand-soft`), `h2` nom de la classe, `dl` : niveau · série (`ui_badge sm`, libellé `sr-only` « Niveau »), établissement (icône `building-library` étiquetée), année scolaire (icône `calendar` étiquetée). À droite (dessous au téléphone) : bloc `bg-brand-soft` « Code de la classe », code `#student_classroom_join_code` en `font-mono text-2xl tracking-widest`, relié à son libellé par `aria-labelledby`, puis l'aide. Classe sans code : « Aucun code pour cette classe » sur fond `bg-mist`.
  - `ui_card#student_classroom_courses` « Cours assignés » (icône `book-open`, sous-titre « Les cours que tes enseignants ont assignés à ta classe ») ; dans ses actions, `ui_badge` « N cours » (`brand`, `sm`) ; une liste `ul.divide-y` pleine largeur de la carte, une ligne `_assigned_course` par cours.
- Ligne `_assigned_course` (`li#course_<slug>`) : toute la ligne est un lien vers `course_path(slug)` : pastille `book-open`, nom, sous-titre sur deux lignes au plus, badge de matière **toujours** `ui_subject_badge(name, category:)`, badge niveau · série, « N fiches essentielles » publiées (icône `document-text`), chevron.
- Lecture : `StudentClassroomQuery(student_id:)` → `Row(public_id, classroom_name, level_name, series_name, school_name, school_year, courses)` ; puis `ClassroomHeaderQuery(public_id:)` et `ReadClassroomPolicy` pour le code.
- Navigation : l'entrée « Ma classe » est active par son URL.

**Tokens**
- Composants `ui_*` et tokens `@theme` seulement. Aucune classe de l'ancienne application, aucune vignette de cours, aucun emoji.

**Comportement**
- Écran en lecture seule : aucun `*.turbo_stream.erb`. Ouvrir un cours est une navigation Turbo, sans rechargement de page.
- Réservé au rôle élève : un enseignant ou l'équipe reçoit 403. Un élève qui ouvre la page enseignant de sa classe (`classroom_path`) reçoit 403 (UDR-0027).

**États obligatoires**
- Vide : « Aucun cours assigné pour l'instant », « Les cours que tes enseignants assignent à ta classe apparaîtront ici. ».
- Chargement : sans objet (page rendue d'un bloc).
- Sans classe : redirection unique vers l'écran de sortie.

**Accessibilité**
- Les icônes qui remplacent un libellé (établissement, année scolaire) portent ce libellé ; le niveau a un libellé `sr-only`.
- Le nom accessible d'une ligne de cours est son texte visible (nom, matière, fiches essentielles) : pas d'`aria-label` qui le masquerait.
- Cibles tactiles ≥ 48 px (`min-h-tap`) ; en 390 px, la page ne défile pas en largeur et la barre du bas reste visible.

## 4. Conséquences

- Aucun nom de camarade n'apparaît sur les pages de l'élève ; le code de sa classe, lui, y est (accueil et « Ma classe »).
- Un cours retiré de la classe ou archivé disparaît de « Ma classe » à la requête suivante (CS#B13) ; une fiche ou un exercice assigné seul n'y figure pas : il est sur l'accueil (UDR-0010).
- La règle « cours assignés actifs et publiés » a une seule implémentation (`ClassroomOverviewQuery#courses`), partagée par la page de l'enseignant et celle de l'élève.
- La bascule entre plusieurs classes d'un même élève ([ADR-0003](../adr/0003-multi-appartenance-et-denormalisation-eleves.md), inventaire B13) n'est pas reprise en V1 : seule la classe principale est montrée.

## Amendement du 2026-09-29 — finitions d'interface

*Chantier [`docs/chantiers/finitions-ux`](../../chantiers/finitions-ux/prd.md), [UDR-0054](0054-finitions-d-interface.md). Statut : `Accepté` (avec l'UDR-0054, par le porteur le 2026-09-29). Le texte ci-dessus reste tel qu'il a été accepté ; cette section fait foi en cas d'écart.*

- **Le code reste sans bouton « Copier »** (décision du porteur du 2026-09-29) : c'est désormais une règle commune, « un code fait pour être dicté ne se copie pas » (UDR-0054 §2.7). Le §2.3 et le §3 sont confirmés.
- Titre : « Ma classe · Élève · Lnclass ».

## Amendement du 2026-10-02 — épuration (UDR-0057) · Statut : Accepté (2026-10-02, porteur)

> **Décision du porteur (2026-10-02)** : amendement accepté.

*Chantier [`docs/chantiers/interface-epuree`](../../chantiers/interface-epuree/plan.md), Lot E, [UDR-0057](0057-ecrans-eleve-epures.md). Statut : `Accepté` (porteur, 2026-10-02). Le Lot E ne code rien avant l'acceptation du porteur (plan, « Porte des lots C à F »). Une fois acceptée, cette section fait foi en cas d'écart avec le texte ci-dessus et avec l'amendement du 2026-09-29.*

Cet amendement applique à « Ma classe » la règle de sobriété de l'UDR-0057 : la classe y est dite deux fois, deux aides restent affichées en permanence, et chaque ligne de cours porte six informations.

**Ce qui change**

| Élément | Aujourd'hui | Après | Règle (R1–R6, Q4) | Où va l'information |
|---|---|---|---|---|
| Sous-titre de `ui_page_header` | « <établissement> · <classe> » (`show.subtitle`) | Retiré. `ui_page_header title: t(".title")` seul. La clé `show.subtitle` est supprimée. | R6 | Nulle part : il est répété. Le `h2` de `#student_classroom_header` nomme la classe. Sa `dl` nomme l'établissement. |
| Aide du code | « Tes camarades rejoignent la classe avec ce code. » affiché sous le code (`show.join_code_hint`) | Retirée du bloc. Une infobulle `ui_info_tip` la porte, à droite du libellé « Code de la classe ». La clé devient `show.join_code_info_tip`, même texte. | R4 | Dans l'infobulle, à un tap. |
| Sous-titre de la carte « Cours assignés » | « Les cours que tes enseignants ont assignés à ta classe » (`show.courses_subtitle`) | Retiré. `ui_card` sans `subtitle:`. La clé `show.courses_subtitle` est supprimée. | R4, R6 | Nulle part : il redit le titre « Cours assignés ». L'état vide garde l'explication (« Les cours que tes enseignants assignent à ta classe apparaîtront ici. »). |
| Pastille `book-open` de chaque ligne | Une pastille `bg-brand-soft` à gauche de chaque cours | Retirée. | R6 | Nulle part : elle redit l'icône `book-open` de la carte, identique sur chaque ligne. |
| Sous-titre du cours | Deux lignes au plus sous le nom (`course.subtitle`) | Retiré de la ligne. | Q4 | Page du cours (`course_path`), sous son `h1`. |
| Badge niveau · série de chaque ligne | `ui_badge` « Tle · D » sur chaque cours | Retiré de la ligne. | R6 | Nulle part : il redit le niveau de la classe, dans la `dl` de l'en-tête. Depuis l'amendement du 2026-10-01 de l'UDR-0013, un cours assigné est toujours du niveau de la classe. La page du cours le montre aussi. |
| « N fiches essentielles » | Icône `document-text` et compte sur chaque ligne (`assigned_course.essentials`) | Retiré. La clé `assigned_course.essentials` est supprimée. | Q4 | Page du cours : la section `#course_essentials` liste les fiches. |
| Nom du cours | `text-balance`, sur plusieurs lignes | Une seule ligne, `truncate`. | UDR-0057, « Listes » | Le nom complet reste dans le DOM, donc dans le nom accessible du lien. Il est en entier dans le `h1` de la page du cours. |
| Liste des cours | Tous les cours, sans limite | Les 3 premiers visibles. Les suivants sont rendus mais masqués (`hidden`). « Voir plus » les révèle. | R3 | Dans la même page, sans requête. |

**Règles d'implémentation (remplacent les points correspondants du §3)**

- `show.html.erb` :
  - `ui_page_header title: t(".title")`, sans `subtitle:`.
  - Bloc du code : le libellé `p#student_classroom_join_code_label` et l'infobulle sont dans un `div.flex.items-center.gap-1`. L'infobulle est `ui_info_tip t(".join_code_info_tip"), label: t(".join_code")`. Elle est **hors** du libellé : le nom accessible du code (`aria-labelledby`) reste « Code de la classe ». Le `p` d'aide `text-xs text-mute` disparaît.
  - Classe sans code : « Aucun code pour cette classe », inchangé.
  - `ui_card#student_classroom_courses` : `title: t(".courses_title")`, `icon: "book-open"`, sans `subtitle:`. Le badge « N cours » (`brand`, `sm`) reste dans `card.actions` : il donne le total quand la liste est coupée à 3.
  - « Voir plus » suit le contrat gelé du Lot 0 : contrôleur `reveal`, cibles `item`, `button`, `status`, valeur `step`. Le contrôleur se pose sur un `div` qui enveloppe le `ul`, le bouton et la région `status`.
    - Les lignes au-delà de la 3ᵉ sont rendues `hidden` et portent `data-reveal-target="item"`.
    - Le bouton est `ui_button` `ghost`, pleine largeur, libellé partagé « Voir plus » (`config/locales/shared/components.fr.yml`), cible `button`. Il n'est rendu que s'il y a plus de 3 cours.
    - La région `status` est `sr-only`, `aria-live="polite"`. Elle annonce « N lignes de plus affichées » (texte partagé du Lot 0).
- `_assigned_course.html.erb` :
  - Locals stricts : `locals: (course:, course_counter: 0)`. La ligne est `hidden` et cible `item` quand `course_counter >= 3`.
  - `li#course_<slug>` > lien `course_path(course.slug)` sur toute la ligne : `min-h-tap`, `hover:bg-mist`, `active:bg-mist`, focus `outline-brand`.
  - Contenu, dans l'ordre : un `div.min-w-0.flex-1` avec le nom (`p.truncate`, `font-display font-extrabold text-ink`), puis `ui_subject_badge(course.material_name, category: course.material_category, size: :sm)` ; à droite, le chevron `chevron-right`.
  - Plus de pastille, de sous-titre, de badge de niveau ni de compte de fiches.
- `config/locales/classroom/student_classrooms.fr.yml` :
  - supprimées : `show.subtitle`, `show.courses_subtitle`, `assigned_course.essentials` ;
  - renommée : `show.join_code_hint` → `show.join_code_info_tip` (« Tes camarades rejoignent la classe avec ce code. ») ;
  - inchangées : toutes les autres.
- Accessibilité : le nom accessible d'une ligne de cours devient « <nom> <matière> ». Il reste son texte visible, sans `aria-label`.
- Mise en page : « Ma classe » n'a pas de maquette téléphone. Elle garde une seule mise en page et applique la règle à toutes les tailles (UDR-0057 §3, « Deux familles d'écrans »).

**Ce qui ne change pas**

- L'en-tête de la classe garde le nom (`h2`), le niveau · série, l'établissement, l'année scolaire et le code en majuscules.
- Le code reste sans bouton « Copier » (UDR-0054 §2.7). Sa copie vit dans la modale « Inviter » de l'accueil (UDR-0058 §3.2), un autre écran.
- L'état vide, la redirection sans classe et le 403 des autres rôles sont inchangés.
- Plus tard, sur téléphone, « Ma classe » sera atteinte par « Voir ma classe » dans la modale « Inviter » (UDR-0058). Cette page n'en dépend pas : rien n'y change.

**Contrôle des six points (UDR-0057), après l'amendement**

| # | Vérification sur « Ma classe » | Résultat |
|---|---|---|
| R1 | Aucun bouton `primary` ou `brand` dans le `main`. Les lignes sont des liens, « Voir plus » est `ghost`. | Respecté (0 action principale) |
| R2 | Blocs de premier niveau à 390 × 844 : `ui_page_header`, la carte de la classe, la carte « Cours assignés ». | Respecté (3 ≤ 5) |
| R3 | La liste des cours montre 3 lignes, puis « Voir plus ». | Respecté après l'amendement |
| R4 | Aucune aide permanente. L'aide du code est dans `ui_info_tip`. Restent l'état vide et « Aucun code pour cette classe » : ce sont des états, pas des aides. | Respecté après l'amendement |
| R5 | Accent `brand` seul : pastille de l'en-tête, bloc du code, badge « N cours ». Les teintes de `ui_subject_badge` codent la matière, comme sur l'accueil (UDR-0058 §3.3) : ce ne sont pas des accents d'action. | Respecté |
| R6 | La classe, l'établissement et le niveau ne sont dits qu'une fois, dans l'en-tête. Le code n'apparaît qu'une fois. L'icône `book-open` n'est plus répétée sur chaque ligne. | Respecté après l'amendement |

**Garde-fous**

- **Jamais de liste nominative des camarades** (§2.4). La page ne lit pas `show_roster`. Elle ne montre ni nom d'élève ni effectif. L'épuration n'ajoute aucune donnée.
- Le code reste dicté, jamais copié, sur cette page.
- Aucune route, aucune query, aucune clé de données n'est ajoutée. `StudentClassroomQuery` et `ClassroomHeaderQuery` ne changent pas.
- Tokens du `@theme` seulement : aucun `#hex`, aucun `style=`, aucune valeur entre crochets, aucun `dark:` (UDR-0005).

**Vérification (Lot E, phase code)**

- `test/controllers/classroom/student_classrooms_controller_test.rb` : la ligne d'un cours ne montre plus son sous-titre, son niveau ni ses fiches. L'en-tête montre toujours « Tle · D ». La page n'a plus de sous-titre d'en-tête. `assert_single_primary_action` et `assert_list_capped(max: 3)` passent avec 4 cours assignés.
- `test/system/classroom/student_classroom_test.rb` : à 390 px, `assert_blocks_above_fold(max: 5)` passe. « Voir plus » révèle le 4ᵉ cours et l'annonce. L'infobulle du code s'ouvre au toucher. Ouvrir un cours reste une navigation Turbo.

## Amendement du 2026-10-02 — plus de cours assignés · Statut : Proposé

*Chantier [`fonctions-espace-eleve`](../../chantiers/fonctions-espace-eleve/memo.md) ; [ADR-0072](../adr/0072-assignation-d-exercices-et-echeance-a-la-prochaine-seance.md) (seul un exercice s'assigne) ; le détail est dans l'[UDR-0062](0062-echeances.md) §3.4 et §3.6. Le texte ci-dessus reste tel qu'il a été accepté ; cette section fera foi en cas d'écart une fois acceptée.*

- **La carte « Cours assignés » est retirée** (proposition du rédacteur, à valider par le porteur) : un cours ne s'assigne plus, elle resterait vide. « Ma classe » garde la carte de la classe ; les cours restent au catalogue, filtré sur le niveau de l'élève.
- Toujours aucune liste nominative, aucun retard d'un autre élève (§2, Q12 du chantier).
