# UDR-0027 : Page classe — en-tête et code copiable, cours assignés, liste des élèves, pour l'enseignant de la classe et l'équipe

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot D4, critères CL-10, CL-04 (affichage), ID-15 (bouton de l'enseignant), TR-cadre-4 |
| **ADR lié** | [ADR-0028](../adr/0028-policies-de-domaine-par-use-case.md) (`ReadClassroomPolicy`, fait `show_roster`) · [ADR-0032](../adr/0032-recuperation-assistee-du-pin.md) (code de récupération) · [ADR-0048](../adr/0048-statuts-d-assignation-active-et-archived.md) (assignations actives) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0006](0006-shell-applicatif-par-role.md) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) · UDR-0020 du Lot B8 (modale du code) |
| **Remplacé par** | — |

---

## 1. Contexte

L'enseignant ouvre une de ses classes pour **relever le code** à transmettre aux élèves, voir ce qu'il leur a assigné et qui est inscrit. Dans l'ancienne application :

- la fiche de l'espace enseignant (`teachers/classrooms/show`) **cassait dès le premier exercice assigné** (`PG::UndefinedTable`, puis `NoMethodError exercise_id`, CS#B8) ; sa liste d'élèves et ses cours assignés étaient commentés ;
- le tableau de bord générique (`classroom/classrooms/show`) affichait le code **en minuscules**, sous trois noms différents, et **n'était protégé par rien** : tout connecté y lisait le code et la liste nominative de n'importe quelle classe (B9) ;
- ses compteurs « % actifs », « Moyenne classe », « Progression » étaient vides ou faux ; ses onglets cachaient la liste des élèves derrière un chargement différé ;
- un élève qui avait perdu son PIN n'avait aucun recours (ID-15).

## 2. Décision

1. **Une seule page, `/classrooms/:public_id`**, pour l'enseignant qui enseigne la classe et pour l'équipe. Un élève reçoit **403**, y compris pour sa propre classe : il voit le code de sa classe sur son accueil et sur « Ma classe » (UDR-0011), jamais la liste nominative. Un enseignant qui n'y enseigne pas reçoit 403, et la réponse ne contient **ni le code ni un nom d'élève** (TR-cadre-4).
2. **Trois blocs empilés, sans onglets** : l'en-tête, les cours assignés, la liste des élèves. Tout est lisible d'un défilement, au téléphone comme au bureau ; aucun chargement différé.
3. **Le code s'affiche en majuscules, sous un seul nom : « Code de la classe »**, en grand, avec un bouton **« Copier »**. La copie est le seul geste que Turbo ne sait pas faire : un contrôleur Stimulus écrit le code affiché dans le presse-papiers, puis pose un **toast « Code copié »** (ou « La copie a échoué : recopiez le code à la main. ») rendu par le serveur dans un `<template>`. La valeur copiée est celle du serveur, déjà en majuscules.
4. **Les cours assignés** sont les assignations **actives** de type cours, dont le cours est **publié**. Une fiche essentielle ou un exercice assigné n'apparaît pas ici (il se voit dans la page du cours, lots D5 et D6) et **ne casse plus la page**.
5. **La liste des élèves** ne contient que les adhésions présentes (`left_at` vide), triées par nom : nom, numéro, **dernier score** (celui de la dernière session terminée, tous exercices confondus). Elle n'est **même pas lue** quand la policy ne l'accorde pas (`show_roster`).
6. **« Générer un code de récupération »** sur chaque ligne, tant que la classe est active : un formulaire `POST` vers `account_pin_recovery_codes_path(public_id)` (route du socle). La réponse est le stream du Lot B8, qui ouvre **la modale du code** (UDR-0020) : le code ne passe jamais par cette page ni par un flash. Classe archivée : pas de bouton, l'enseignant n'y peut plus émettre de code (`IssuePinRecoveryCodePolicy`).
7. **Pas de compteurs de moyenne ni d'activité** : « Moyenne » est un terme interdit (UDR-0007), et les chiffres de l'ancienne page étaient faux. L'effectif et le plafond suffisent à la V1.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- `classroom/classrooms/show` : `_header`, puis `div.space-y-10` → `_assigned_courses`, et `_roster` seulement si `@overview.students` n'est pas `nil`. `content_for :nav_key, "classrooms"`.
- `_header` (`#classroom_header`) : lien « Accueil » (`home_path_for`) ; `ui_card` → pastille `academic-cap`, `h1` nom de la classe, badge « Classe archivée » (`warning`) si archivée ; `dl` : niveau · série (`ui_badge`), établissement, année scolaire, effectif / plafond (`#classroom_headcount`, « 2 / 60 élèves »). À droite (dessous au téléphone) : bloc `bg-brand-soft` « Code de la classe », code `#classroom_join_code` en `font-mono text-3xl tracking-widest`, `ui_button` « Copier » (`secondary`, `sm`, icône `clipboard-document`), aide « À transmettre aux élèves pour qu'ils rejoignent la classe. ». Classe sans code : « Aucun code pour cette classe », sans bouton.
- `_assigned_courses` (`#assigned_courses`) : grille `sm:grid-cols-2 xl:grid-cols-3` de cartes `li#course_<slug>` ; badge de matière **toujours** `ui_subject_badge(name, category:)`, badge niveau · série, nom en lien étiré vers `classroom_course_path(classroom_public_id, course_slug)`, sous-titre sur deux lignes au plus, « N fiches essentielles » publiées.
- `_roster` (`#classroom_roster`) : titre « N élèves », aide sur le code de récupération, liste `ul.divide-y` de `li#student_<public_id>` : `ui_avatar`, nom, numéro groupé par deux chiffres, « Dernier score » (« 85 % » ou « Aucune session terminée »), bouton « Générer un code de récupération » (`secondary`, `sm`, icône `key`).
- Lecture : `ClassroomHeaderQuery` (en-tête, faits de la policy), `ReadClassroomPolicy`, puis `ClassroomOverviewQuery(public_id:, show_roster:)` → `Overview(courses, students)`.

**Tokens**
- Composants `ui_*` et tokens `@theme` seulement. Aucune classe de l'ancienne application, aucun dégradé.

**Comportement**
- Lecture seule : aucun `*.turbo_stream.erb` propre à la page.
- Stimulus `classroom--join-code-copy` : valeur `code` (le code affiché), cibles `copied` et `failed` (deux `<template>` contenant chacun un `ui_toast`). `copy` → `navigator.clipboard.writeText(code)` → clone du toast dans `#toasts`, avec un `id` neuf (chaque toast est permanent pour Turbo). Échec (page hors HTTPS, refus du navigateur) : toast d'avertissement.
- Le bouton du code de récupération n'a pas de `data-turbo-frame` : la réponse est un Turbo Stream de B8.

**États obligatoires**
- Vide : « Aucun cours assigné » (« Ouvrez un cours du catalogue pour l'assigner à cette classe. ») ; « Aucun élève inscrit » (« Partagez le code de la classe : les premiers inscrits apparaîtront ici. »).
- Chargement : sans objet (page rendue d'un bloc).
- Erreur : 403 (élève, enseignant hors de la classe) et 404 (classe inconnue) par `RendersResult`, sans aucune donnée de la classe.
- Succès : toast « Code copié ».

**Accessibilité**
- Le bouton « Copier » a pour nom « Copier le code KFM37 » ; celui du code de récupération « Générer un code de récupération pour Awa Bamba ».
- Les icônes de l'en-tête qui remplacent un libellé (établissement, année scolaire, effectif) portent ce libellé ; le numéro est précédé d'un libellé `sr-only`.
- Cibles tactiles ≥ 48 px ; la page tient dans 390 px sans défilement horizontal (test système).

## 4. Conséquences

- Tout écran qui affiche un code d'adhésion l'affiche en majuscules et, s'il propose de le copier, réutilise `classroom--join-code-copy` plutôt qu'un nouveau contrôleur.
- Le tableau de bord générique de l'ancienne application (onglets, « % actifs », « Moyenne classe », « Progression ») n'est pas repris ; une vue d'activité de la classe relève de la V3.
- La fiche d'un élève (CL-13) est en V3 (`rapports-de-classe`) : les lignes de la liste ne sont pas des liens.
