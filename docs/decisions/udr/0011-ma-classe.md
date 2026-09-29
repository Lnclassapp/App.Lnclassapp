# UDR-0011 : Ma classe — la classe principale de l'élève, son code en majuscules et ses cours assignés, sans liste nominative

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) |
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
