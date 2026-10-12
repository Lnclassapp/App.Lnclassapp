# UDR-0058 : Accueil élève — maquette du porteur sur téléphone et tablette, accueil actuel épuré sur ordinateur
<!-- index
titre: Accueil élève
statut: Accepté *(2026-10-02)*
adr-lie: [0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md), [0040](../adr/0040-classe-principale-unique-de-l-eleve.md), [0043](../adr/0043-remediation-declenchee-par-la-cloture.md), [0048](../adr/0048-statuts-d-assignation-active-et-archived.md)
problematique: Sous 1 024 px : bandeau bleu, carte « Prochain exercice » (ou la classe et un encouragement), grille de 6 matières et « Inviter », « À faire ensuite » et « Historique » en 3 lignes, sans barre basse ; au-dessus, l'accueil de l'UDR-0010 épuré. Remplace UDR-0010
-->

| | |
|---|---|
| **Statut** | Accepté (2026-10-02, porteur) |
| **Date** | 2026-10-02 |
| **Chantier** | [`docs/chantiers/interface-epuree`](../../chantiers/interface-epuree/memo.md) — grill Q4 à Q12 ; maquette [`accueil-eleve-telephone.html`](../../chantiers/interface-epuree/maquettes/accueil-eleve-telephone.html) |
| **ADR lié** | [ADR-0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md) (note, badges) · [ADR-0040](../adr/0040-classe-principale-unique-de-l-eleve.md) (une classe) · [ADR-0043](../adr/0043-remediation-declenchee-par-la-cloture.md) (fiches à revoir) · [ADR-0048](../adr/0048-statuts-d-assignation-active-et-archived.md) (assignations actives) · [UDR-0057](0057-ecrans-eleve-epures.md) (règle et deux familles) · [UDR-0006](0006-shell-applicatif-par-role.md) (shell) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) (vocabulaire) |
| **Remplace** | [UDR-0010](0010-accueil-eleve.md) |
| **Remplacé par** | — |

---

## 1. Contexte

L'accueil élève de l'UDR-0010 répond à la bonne question (« qu'est-ce que je fais maintenant ? »), mais il la noie.

- **Les lignes sont chargées.** Chaque exercice montre une pastille d'état, le titre, la matière, le badge, le meilleur score, la maîtrise, le nombre de sessions et un bouton.
- **Les boutons se concurrencent.** Il y a autant de boutons « Commencer » que d'exercices.
- **Un texte d'aide reste affiché en permanence.**
- **L'établissement et la classe sont dits deux fois** : dans l'en-tête de page et dans la carte « Ma classe ».

Sur téléphone, l'élève fait défiler quatre cartes avant de voir son activité. Le porteur a dessiné l'écran qu'il veut sur téléphone, dans l'esprit de Wave : un bandeau bleu, une grande carte qui dit quoi faire, une grille de matières, puis deux listes courtes.

## 2. Décision

1. **Sous 1 024 px (téléphone et tablette)**, l'accueil suit la maquette du porteur, **sans ce qui repose sur une fonction absente** (UDR-0057 §2.5). Cela retire les annonces et leur audio, la case Paiement, les échéances et les retards, la durée, la mention hors connexion et l'aide.
2. **À partir de 1 024 px (ordinateur)**, l'accueil garde la structure de l'UDR-0010, épurée par la règle de l'UDR-0057.
3. **La carte du haut dit la prochaine chose à faire, et une seule.** C'est le premier exercice non terminé, dans l'ordre de la liste « À faire » (le plus récemment assigné d'abord, comme aujourd'hui), faute d'échéances. S'il n'y a rien à faire, la carte présente la classe avec un mot d'encouragement (grill Q6).
4. **Les lignes ne gardent que ce qui sert à choisir** (grill Q4) : la matière, le titre et une seule donnée à droite. Le badge, la maîtrise et le nombre de sessions restent sur la page de l'exercice (UDR-0021).
5. **Sous 1 024 px, pas de barre basse sur l'accueil.** Comme chez Wave, l'accueil est un point de départ : ses tuiles et sa carte mènent aux cours, à la classe et aux exercices. Les autres écrans élève gardent la barre basse.
6. **« Inviter » ouvre une modale avec le code de la classe**, qui existe déjà. C'est la place stable du code sur téléphone, à la place de la carte « Ma classe ».

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Données (query `StudentHomeQuery`)

Champs ajoutés aux lignes existantes, sans nouvelle table :

| Ligne | Champs ajoutés | Usage |
|---|---|---|
| `Row` | `school_sigle`, `level_cycle` (`first` ou `second`) | sous-titre de l'en-tête, case EDHC ou Philosophie |
| `ExerciseRow` | `material_slug` | pastille et illustration |
| `SessionRow` | `material_slug`, `material_name`, `exercise_public_id` | pastille, sous-texte, « Refaire » |

### 3.2 Famille téléphone et tablette (sous `lg`)

**Cadre**
- La vue déclare `content_for :mobile_chrome, "none"`. Le shell n'affiche alors ni son en-tête ni sa barre basse **sous `lg`**. À partir de `lg`, il reste inchangé.
- Le bloc entier est `lg:hidden`, centré dans `max-w-phone` (UDR-0057), sur `bg-paper`.

**Hiérarchie, du haut vers le bas**

1. **Bandeau** `header.student-band` : fond `brand`, 168 px de haut, coins du bas ouverts. Une feuille `bg-white` à coins hauts arrondis (`rounded-t-sheet`, 28 px) commence 28 px avant le bas du bandeau.
   - À gauche, un lien vers l'accueil :
     - le logo (`logo/lnclass-mark.png`, baobab détouré, 40 px) ;
     - « Lnclass » (`font-display`, 19 px, 800) ;
     - en dessous, « <classe> · <établissement> » (13 px).
     
     Le contrôleur Stimulus `fit-text` (nouveau) remplace le nom de l'établissement par `school_sigle` quand la ligne déborde. Si le sigle est vide, il tronque avec « … ». Le nom complet reste dans `title` et dans l'`aria-label` du lien.
   - À droite : l'avatar, `ui_avatar` 44 px (initiales sur dégradé or), qui mène à `profile_path`. Aucun bouton d'aide tant qu'aucune page d'aide n'existe.
2. **Carte du haut** `section#student_home_next` : elle chevauche le bandeau de 92 px vers le haut. Fond dégradé `hero-a → hero-b`, motif de tirets (classe CSS `.hero-pattern`), rayon `rounded-hero` (24 px), padding 18 px. Elle a deux états, testés dans cet ordre :
   - **Prochain exercice** (il existe un exercice dont `completed_count == 0`) :
     - étiquette « PROCHAIN EXERCICE » (12 px, capitales) ;
     - `h1` : le titre de l'exercice (21 px, 800) ;
     - « <matière> » (14 px) ;
     - à droite, l'illustration de la matière dans un carré blanc de 60 px, rayon 18 px ;
     - séparateur, puis « <N> exercices faits sur <M> » et un `<progress class="progress-bar">` ;
     - bouton blanc pleine largeur (50 px, texte `hero-ink`) :
       - « Commencer l'exercice », par `button_to exercise_sessions_path(public_id)` ;
       - ou « Reprendre l'exercice », lien vers `exercise_session_path(started_session_public_id)` si une session est en cours.
   - **Rien à faire** (aucun exercice assigné, ou tous terminés) :
     - étiquette « MA CLASSE » ;
     - `h1` « <classe> » ;
     - « <établissement> » ;
     - un mot :
       - « Bravo <prénom>, tout est fait ! » si tous les exercices sont terminés ;
       - « Tes enseignants n'ont rien assigné pour l'instant. » s'il n'y en a aucun ;
     - la barre et le compte, seulement s'il y a au moins un exercice ;
     - bouton blanc « Voir mes cours » vers `courses_path`.
3. **Grille** `nav.subject-grid[aria-label="Mes matières"]` : 4 colonnes, rangées espacées de 16 px. Chaque case est un lien : une pastille ronde de 60 px teintée, avec une illustration de 40 px, puis le libellé (14 px, 500). Les cases, dans l'ordre :
   1. Maths (`maths`, `tint-indigo`)
   2. Physique-Chimie (`physique-chimie`, `tint-lilac`, coupé au trait d'union par `<wbr>`)
   3. SVT (`svt`, `tint-green`)
   4. Français (`francais`, `tint-yellow`)
   5. Histoire-Géo (`histoire-geographie`, `tint-lav`)
   6. EDHC (`edhc`) au 1er cycle, ou Philosophie (`philosophie`) au 2nd cycle (`tint-pink`)
   7. **Inviter** (`tint-red`)
   
   Une case matière mène à `courses_path(material: <slug>)`. Une case dont le slug n'existe pas dans le référentiel n'est pas rendue. Les slugs et les teintes vivent dans une constante unique, `StudentHomeHelper::SUBJECT_TILES`.
   
   « Inviter » ouvre `ui_modal(id: "invite-classmates", size: :sm)` :
   - « Partage le code de ta classe : tes camarades le saisissent pour te rejoindre. » ;
   - le code en `font-mono` (« K7M 4Q2 ») ;
   - `ui_copy_button` ;
   - un lien `secondary` « Voir ma classe » vers `student_classroom_path`.
4. **« À faire ensuite »** `section#student_home_todo`, s'il reste au moins une ligne :
   - `h2` 18 px et la liste ;
   - les exercices non terminés, **sauf celui de la carte du haut** ;
   - puis les fiches à revoir (lacunes en attente) ;
   - au plus 3 lignes visibles, puis « Voir plus » (UDR-0057, contrôleur `reveal`).
   
   Une ligne :
   - pastille de la matière (44 px) ;
   - titre (15 px, 500, tronqué) ;
   - sous-texte :
     - « <matière> · Exercice » ;
     - ou « <matière> · Commencé » si une session est en cours ;
     - ou « <matière> · Fiche à revoir » ;
   - chevron à droite.
   
   La ligne entière est un lien : `exercise_path(public_id)` pour un exercice, `course_essential_path(course_slug, essential_slug)` pour une fiche.
5. **« Historique »** `section#student_home_history` : `h2`, puis le frame différé existant, `turbo_frame_tag RECENT_ACTIVITY_FRAME`, `loading: :lazy`, `target: "_top"`.
   - Il rend les 10 dernières sessions terminées, groupées par jour sous un titre de jour (12 px, capitales, `mute`) :
     - « Aujourd'hui », « Hier », puis « Mardi 29 sept. » ;
     - les 3 premières lignes visibles, puis « Voir plus » qui révèle les suivantes, sans requête.
   - Une ligne :
     - pastille de la matière ;
     - titre ;
     - « <matière> · Exercice » ;
     - à droite, la note « 16/20 » (`font-display`, 800, `success` si elle est ≥ 14/20) et l'heure « 09:14 ».
   - **Sous la note de passage** (`Grading::PASS_THRESHOLD`) : la note neutre, et un bouton bleu doux « Refaire » (`button_to exercise_sessions_path(exercise_public_id)`) à la place de l'heure.
   - La ligne mène à `exercise_session_result_path(public_id)`.

### 3.3 Famille ordinateur (à partir de `lg`)

Le bloc est `hidden lg:block`. On garde la structure de l'UDR-0010, avec ces changements, et ceux-là seulement :

| Élément | Avant (UDR-0010) | Après |
|---|---|---|
| `ui_page_header` | « Bonjour, <prénom> » + « <établissement> · <classe> » | « Bonjour, <prénom> » seul. La carte « Ma classe » dit déjà la classe et l'établissement (R6) |
| Bloc d'aide « Badges » / « Maîtrise » | visible sous le titre « À faire » | retiré (R4). La page de l'exercice explique badges et maîtrise |
| Ligne `_assigned_exercise` | pastille d'état, titre, matière, badge, meilleur score, maîtrise, sessions, bouton | titre, `ui_subject_badge` de la matière, un bouton. Badge, score, maîtrise et sessions vont sur la page de l'exercice (Q4) |
| Boutons « Commencer » et « Reprendre » | `primary` ou `brand` sur chaque ligne | `primary` sur la première ligne seulement, `secondary` ensuite (R1) |
| Listes « À faire », « Fiches à revoir », « Activité récente » | complètes | 3 lignes, puis « Voir plus » (R3) |
| Ligne d'activité | score en %, note sur 20, maîtrise, « il y a … » | note sur 20 dans la pastille, titre, « il y a … » (R6 : une seule forme de la note) |
| Barre basse, en-tête et barre latérale du shell | inchangés | inchangés |

### 3.4 Tokens (ajoutés au `@theme`)

- **Carte du haut** : `--color-hero-a: #0077c2`, `--color-hero-b: #004e80`, `--color-hero-ink: #004e80`.
- **Pastilles** : `--color-tint-indigo: #dee5ff`, `--color-tint-lilac: #f0dfff`, `--color-tint-green: #e3ffdf`, `--color-tint-yellow: #fff8d2`, `--color-tint-lav: #f2f2ff`, `--color-tint-pink: #ffe1f3`, `--color-tint-red: #fff0f0`.
- **Formes** : `--radius-hero: 1.5rem`, `--radius-sheet: 1.75rem`, `--container-phone: 36rem`.
- Les illustrations de matière sont des `<symbol>` SVG d'un partial unique, `shared/_subject_symbols`. Leurs couleurs passent par les classes `.c-*` de la feuille, jamais par un attribut `fill` en dur.
- Pas de mode sombre (UDR-0005 §2.4).

### 3.5 États obligatoires

- **Chargement** : le haut de l'écran est rendu par le serveur. L'historique montre `ui_loading_state variant: :skeleton` (3 lignes) dans son frame.
- **Vide** : la carte du haut passe à « Rien à faire ». « À faire ensuite » n'est pas rendue. L'historique dit « Aucun exercice terminé pour l'instant ».
- **Erreur** : le frame de l'historique en échec affiche `ui_error_state` avec « Réessayer ».
- **Sans classe active** : un seul saut vers l'écran de sortie (`pending_account_path`), comme aujourd'hui.

### 3.6 Accessibilité

- Un seul `h1` par famille rendue : le titre de la carte du haut sous `lg`, « Bonjour, <prénom> » à partir de `lg`. La famille masquée est en `hidden`.
- « Commencer l'exercice » et « Reprendre l'exercice » portent un `aria-label` qui nomme l'exercice. « Refaire » nomme aussi l'exercice.
- `<progress>` porte `aria-label="Exercices faits"` et ses valeurs `value` et `max`.
- Cibles ≥ 44 px (cases de la grille, lignes, avatar). « Voir plus » annonce « N lignes de plus affichées » dans une région `aria-live="polite"`.
- Réservé au rôle élève : un enseignant ou un membre de l'équipe reçoit 403, comme aujourd'hui.

## 4. Conséquences

- L'UDR-0010 est remplacée. Son contrôleur, sa route et sa query restent.
- **La carte « Ma classe » disparaît de l'accueil sous 1 024 px.** La classe reste nommée dans le bandeau, son code est dans « Inviter », et sa page est atteinte par la modale ou par la barre basse des autres écrans.
- **Ce qui attend une fonction**, et reviendra par [`fonctions-espace-eleve`](../../chantiers/fonctions-espace-eleve/memo.md) :
  - la pastille de date et le point de retard ;
  - la durée ;
  - la case Paiement et l'état « abonnement terminé » ;
  - le carrousel d'annonces ;
  - l'audio ;
  - « Hors connexion » ;
  - le bouton d'aide.
- Une nouvelle matière proposée par Lnclass passe par `SUBJECT_TILES`, son illustration et sa teinte. La grille ne s'allonge jamais d'elle-même.

## Amendement du 2026-10-05 — ordre des sections · Statut : Proposé

*Chantier [`interface-eleve-organisation`](../../chantiers/interface-eleve-organisation/memo.md), [UDR-0076](0076-organisation-des-ecrans-eleve.md) §3.1. Cette section fait foi sur le §3.3 en cas d'écart, une fois acceptée.*

- Famille ordinateur (§3.3), aujourd'hui seule rendue : « Ma classe », « Mes matières », annonces, « À faire » (et fiches à revoir), « Mes activités récentes ».
- « Mes matières » remplace la carte « Cours » : une bulle illustrée par matière du niveau de l'élève, vers le catalogue filtré ; pastille ambre si un exercice de la matière est en retard (UDR-0062 §3.3) ; « Tous les cours » en pied de carte.
- La famille téléphone (§3.2), quand elle sera codée, garde cet ordre.
