# UDR-0010 : Accueil élève — à faire, ma classe, cours, puis l'activité récente en différé

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot A2, critères CL-23, TR-04, AS-36, TR-02 |
| **ADR lié** | [ADR-0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md) (badges, maîtrise, note) · [ADR-0043](../adr/0043-remediation-declenchee-par-la-cloture.md) (lacunes) · [ADR-0048](../adr/0048-statuts-d-assignation-active-et-archived.md) (assignations actives) · [UDR-0006](0006-shell-applicatif-par-role.md) (shell, sections d'accueil) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) (vocabulaire) |
| **Remplacé par** | [UDR-0058](0058-accueil-eleve.md) *(proposée le 2026-10-02, effective à son acceptation)* |

> ⚠️ **Remplacée par l'[UDR-0058](0058-accueil-eleve.md)** (proposée le 2026-10-02, chantier `interface-epuree`). Elle reste en vigueur jusqu'à l'acceptation de l'UDR-0058.

---

## 1. Contexte

L'accueil est la page où arrive chaque élève, à chaque connexion. Dans l'ancienne application :

- il levait une erreur dès que l'élève avait une classe (TR-04, CL-23, AS-36) : la requête lisait deux tables supprimées ;
- un élève sans classe tournait en rond entre `/` et `/students` (TR-02) ;
- le badge gagné n'y était jamais affiché ;
- le compteur des sessions s'intitulait « tentatives ».

L'élève a besoin d'une réponse à une seule question : qu'est-ce que je dois faire maintenant ?

## 2. Décision

1. **Les sections suivent l'ordre du shell** (`NavigationHelper::HOME_SECTIONS[:student]`) : « À faire », « Ma classe », « Cours ». « À faire » vient en premier, parce que c'est la raison de la visite.
2. **« À faire » liste les exercices assignés à la classe principale**, directement ou par leur fiche essentielle ou leur cours, publiés ainsi que leurs parents. Le plus récemment assigné vient d'abord ; un exercice atteint par deux assignations n'apparaît qu'une fois. Chaque ligne dit où en est l'élève : matière, badge, meilleur score et maîtrise, nombre de sessions terminées.
3. **Un seul bouton par exercice** : « Reprendre » s'il a une session en cours, sinon « Commencer ». L'élève ne choisit jamais entre deux actions.
4. **Les fiches essentielles à revoir** (lacunes en attente) suivent la liste, seulement s'il y en a : une section vide qui parle d'échec n'aide personne.
5. **Le code de la classe est visible**, en majuscules, dans la carte « Ma classe » (décision du porteur du 2026-09-25), avec l'effectif. **Jamais la liste nominative.**
6. **L'activité récente est différée** : un frame paresseux, avec un squelette, qui redemande la page et ne reçoit que son partial. Elle est secondaire ; elle ne ralentit pas le premier affichage.
7. **Sans classe principale active**, un seul saut vers l'écran de sortie (`pending_account_path`), qui ne redirige jamais.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- Écran `classroom/student_homes/show` : `ui_page_header` « Bonjour, <prénom> » et « <établissement> · <classe> », puis une grille `grid gap-5` :
  - `ui_card#student_home_exercises` « À faire » (icône de la section) ; dans ses actions, `ui_badge` « N sur M faits » (`brand`, `sm`) ; une liste `ul.divide-y` pleine largeur de la carte, une ligne `_assigned_exercise` par exercice ;
  - `_pending_gaps` : `ui_card#student_home_gaps` « Fiches essentielles à revoir », icône `light-bulb`, un lien par fiche vers `course_essential_path` ;
  - `_classroom_card` : `ui_card#student_home_classroom` « Ma classe » ; tout le bloc de la classe est un lien vers `student_classroom_path` : nom, « <niveau> · <établissement> », « N élèves », « Code de la classe » et le code en `font-mono`, « Entrer » ;
  - « Cours » : `ui_card` lien vers `courses_path`, « Voir les cours » ;
  - « Mes activités récentes » : `ui_card` (icône `bolt`) qui contient `turbo_frame_tag "student_home_recent_activity"`, `src: student_home_path`, `loading: :lazy`, `target: "_top"`, et `ui_loading_state variant: :skeleton`.
- Ligne `_assigned_exercise` : pastille d'état (`check-circle` en `success-soft` dès une session terminée, sinon `clock` en `warning-soft`), titre, `ui_subject_badge`, `ui_badge` « Badge <palier> » (teinte `badge_tone`, icône `trophy`) s'il existe, puis « Meilleur score : N % », la maîtrise et « N sessions terminées ».
  - « Reprendre » : lien `ui_button` `brand` `sm`, icône `arrow-path`, vers `exercise_session_path`.
  - « Commencer » : `button_to` POST `exercise_sessions_path`, taille `sm`, `primary` tant qu'aucune session n'est terminée, `secondary` ensuite, icône `play`.
- Partial `_recent_activity` : le frame, puis une ligne par session (lien vers `exercise_session_result_path`) : pastille du score, titre de l'exercice, note sur 20, maîtrise, « Il y a … ».
- Navigation : l'entrée « Accueil » est active par son URL.

**Tokens**
- Composants `ui_*` et constantes de `ComponentsHelper` uniquement ; teintes `success-soft`, `warning-soft`, `brand-soft` du `@theme`.
- Aucune couleur ni classe reprise de l'ancienne application ; les emoji de badge (🥇, 💎) sont remplacés par l'icône `trophy` et le nom du palier.

**Comportement**
- Écran en lecture seule : aucun Turbo Stream. « Commencer » ouvre la session par une navigation Turbo, sans rechargement.
- Le frame de l'activité récente se charge quand il entre dans la fenêtre ; ses liens visent `_top`.
- Réservé au rôle élève : un enseignant ou l'équipe reçoit 403.

**États obligatoires**
- Vide : « Aucun exercice assigné pour l'instant », « Les exercices que tes enseignants assignent à ta classe apparaîtront ici. » ; activité : « Aucune session terminée pour l'instant ».
- Chargement : squelette `ui_loading_state` dans le frame d'activité.
- Sans classe : redirection unique vers l'écran de sortie.

**Accessibilité**
- Le badge se lit en toutes lettres (« Badge Or »), jamais par la couleur seule (UDR-0007).
- « Commencer » et « Reprendre » portent un `aria-label` qui commence par le libellé visible et nomme l'exercice (« Commencer l'exercice « La méiose » »).
- Cibles tactiles ≥ 48 px ; en 390 px, la page ne défile pas en largeur et la barre du bas reste visible.

## 4. Conséquences

- L'accueil élève ne montre que du contenu démarrable : aucun exercice en brouillon ou archivé, aucune fiche retirée (AS-37, TR-cadre-6).
- Aucun nom de camarade n'apparaît sur l'accueil ; le code de la classe, lui, y est.
- « Ma classe » (A3) et le résultat d'une session (C3) sont les deux destinations de cet écran ; la session elle-même vient de C2.
