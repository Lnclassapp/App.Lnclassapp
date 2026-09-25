# UDR-0028 : Cours dans la classe et bascule d'assignation — « Assigner », ou « Assigné » avec « Retirer », remplacée en place

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot D5, critères CL-11, CL-16, CL-17, CL-20, AS-18, AS-19 |
| **ADR lié** | [ADR-0048](../adr/0048-statuts-d-assignation-active-et-archived.md) (active/archived, nouvelle ligne à la réassignation) · [ADR-0035](../adr/0035-cycle-de-vie-et-propriete-du-contenu.md) (seul un contenu publié s'assigne) · [UDR-0006](0006-shell-applicatif-par-role.md) §7 (CRUD Hotwire) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) (vocabulaire) |
| **Remplacé par** | — |

---

## 1. Contexte

L'enseignant prépare sa classe en lui assignant un cours, une fiche essentielle ou un exercice : c'est ce qui oriente l'accueil de ses élèves (ADR-0028). Dans l'ancienne application, ce geste était cassé partout :

- l'écran « cours dans la classe » levait une erreur dès que le cours avait une fiche (CL-11) ;
- les routes d'assignation des cours et des fiches étaient inatteignables depuis l'interface (CL-16, CL-17) ;
- l'assignation d'un exercice répondait `204 No Content` : le bouton ne changeait pas, le toast était perdu (AS-18) ;
- réassigner après un retrait levait `RecordNotUnique` : une ressource retirée ne pouvait plus jamais revenir (CL-20, AS-19).

## 2. Décision

1. **Une seule bascule pour les trois types de ressource**, `classroom/assignments/_toggle`. Le cours dans la classe (ce lot), la fiche essentielle dans la classe (D6) et la page d'assignation d'un cours (D7) la rendent telle quelle : une ressource a le même bouton partout.
2. **Deux états, pas trois.** Non assignée : un bouton « Assigner ». Assignée : un badge « Assigné » et un bouton « Retirer ». Le badge dit l'état ; le bouton dit l'action. Un seul bouton qui changerait de sens au clic (« Assigné » cliquable pour retirer, comme dans l'ancienne application) cache le retrait derrière un libellé d'état.
3. **Remplacée en place, jamais de rechargement.** Chaque clic répond par un Turbo Stream qui remplace la bascule et affiche un toast qui nomme la ressource et la classe. Retirer ne demande pas de confirmation : le geste se défait d'un clic, l'historique garde les deux lignes (ADR-0048).
4. **Le cours dans la classe** montre l'en-tête du cours avec sa propre bascule, puis ses fiches essentielles publiées, chacune avec son nombre d'exercices publiés et sa bascule. Le nom d'une fiche mène à la fiche dans la classe (D6).
5. **Classe archivée : lecture seule.** L'état « Assigné » reste lisible, sans aucun bouton, et un bandeau dit pourquoi.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- Bascule `classroom/assignments/_toggle`, locaux stricts : `classroom_public_id:, assignable_type:, assignable_key:, assignable_name:, assignment_public_id:` (`nil` quand la ressource n'est pas assignée). `assignable_type` ∈ `Course`, `Essential`, `Exercise` ; `assignable_key` est le slug d'un cours ou d'une fiche, le `public_id` d'un exercice.
  - Conteneur `div#assignment_<classroom_public_id>_<type>_<key>`, `flex flex-wrap items-center gap-2`.
  - Non assignée : `button_to` POST `classroom_assignments_path(classroom_public_id)`, paramètres `assignment[assignable_type]` et `assignment[assignable_key]`, bouton `secondary` `sm`, icône `plus`, « Assigner ».
  - Assignée : `ui_badge` « Assigné » (`success`, icône `check`), puis `button_to` PATCH `archive_assignment_path(assignment_public_id)` avec le paramètre `classroom_public_id`, bouton `ghost` `sm`, icône `x-mark`, « Retirer ».
- Écran `classroom/classroom_courses/show` :
  - lien de retour « Retour à <classe> » vers `classroom_path` ;
  - `ui_card` : « <classe> · <établissement> », `h1` du cours, sous-titre, badge du niveau (et de la série), `ui_subject_badge` de la matière ; à droite (dessous sur téléphone), la bascule du cours ;
  - `section#classroom_course_essentials` : titre « Fiches essentielles », aide « Assignez une fiche essentielle pour la proposer aux élèves de la classe. », puis une liste (`divide-y`, carte) d'une ligne par fiche publiée, dans l'ordre du cours : nom (lien vers `classroom_essential_path`), sous-titre, « N exercices publiés », bascule.
- Navigation : l'écran déclare `content_for :nav_key, "classrooms"`.

**Tokens**
- Composants `ui_*` et constantes de `ComponentsHelper` (`BUTTON_BASE`, `BUTTON_SIZES[:sm]`, `BUTTON_VARIANTS`) uniquement ; bandeau d'archive en `bg-warning-soft text-warning rounded-ln`.
- Aucune couleur ni classe reprise de l'ancienne application.

**Comportement**
- `create` : succès, toast « <ressource> ajouté à <classe>. » et `replace` de la bascule, qui passe à « Assigné ». La ligne créée est `active`, son auteur est l'utilisateur connecté (jamais un profil).
- `archive` : succès, toast « <ressource> retiré de <classe>. » et `replace` de la bascule, qui repasse à « Assigner ». La ligne est archivée, jamais supprimée ; réassigner crée une **nouvelle** ligne.
- Refus en place, statut 422, toast d'erreur seul : « Déjà assigné à cette classe » (`:conflict`, `already_assigned`), « Déjà retiré de cette classe » (`already_archived`), type inconnu (`:invalid`).
- Classe qu'on n'enseigne pas ou archivée : 403 ; ressource absente ou non publiée : 404 ; tous deux en toast d'erreur dans le stream. Jamais de `204`.
- Repli sans Turbo : redirection `303` vers la page d'où le bouton a été cliqué (à défaut, la page de la classe), avec un flash `notice` ou `alert`.
- La page est réservée à l'enseignant de la classe et à l'équipe (`ReadClassroomPolicy`) ; un élève reçoit 403, comme sur la page de la classe (D4).

**États obligatoires**
- Vide : « Aucune fiche essentielle pour ce cours. » (UDR-0007), icône `document-text`.
- Classe archivée : bandeau « Cette classe est archivée : ses assignations ne changent plus. », badges « Assigné » sans bouton.
- Refus : toast d'erreur persistant (`role="alert"`), titre « Action refusée ».
- Succès : toast de succès, bascule remplacée.

**Accessibilité**
- « Assigner » et « Retirer » portent un `aria-label` qui nomme la ressource et commence par le libellé visible (« Assigner « La méiose » à la classe »).
- La bascule du cours est dans un `role="group"` nommé « Assignation du cours à la classe ».
- Cibles tactiles ≥ 48 px (taille `sm`, zone étendue). Sur téléphone, la page ne défile jamais en largeur.

## 4. Conséquences

- D6 (fiche essentielle dans la classe) et D7 (assigner un cours depuis sa page) rendent la même bascule avec les mêmes locaux, et reçoivent les streams de ce lot sans en écrire.
- Aucun contenu non publié n'est proposé à l'assignation, et aucun ne peut l'être par une requête forgée.
- Retirer puis réassigner est un geste sûr : l'historique garde chaque ligne.
