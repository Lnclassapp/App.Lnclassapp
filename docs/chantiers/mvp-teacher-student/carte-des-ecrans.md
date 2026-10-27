# Carte des écrans — MVP Lnclass Teacher & Student

> Livrable 2 du chantier [`mvp-teacher-student`](memo.md). Écrite le 2026-10-23, après les UDR acceptées et le [PRD](prd.md).
> Elle dit **quels écrans existent pour le pilote, comment on passe de l'un à l'autre, et lequel change**. Le dessin de chaque écran est dans son UDR ; les critères dans le PRD.
> Téléphone (390 px) d'abord. Les versions ordinateur sont l'étape 4 du chantier.

Légende du statut (celle de [`perimetre.md`](perimetre.md)) : **Gardé** · **Modifié** · **Construit** · **Masqué**.
Abréviations des UDR : **Pal** palette froide · **AccÉ** accueil élève · **InsÉ** inscription élève · **ÉcrÉ** écrans élève · **Ens** écrans enseignant.

## 1. Règle de navigation

- **Pas de barre basse**, ni pour l'élève ni pour l'enseignant. L'accueil porte toutes les destinations ; chaque destination a **une seule entrée**.
- **L'avatar ouvre « Mon compte »** en plein écran : compte et réglages seulement, jamais une destination de l'accueil.
- Chaque page qui n'est pas l'accueil commence par un lien de retour **« ‹ <page parente> »**.
- La coque Android (Lnclass Student, Lnclass Teacher) montre les mêmes écrans ; son menu natif ouvre les pages `students/menu` et `teachers/menu`, qui suivent « Mon compte ».

## 2. Visiteur

```
/  page d'accueil publique
├── « Je suis élève »   → fenêtre : Se connecter (/login) · Créer mon compte (/student-signup)
├── « Enseignant(e) »   → fenêtre : Se connecter (/login) · Créer mon compte (/teacher-signup)
└── « Espace établissement » — masqué jusqu'au 2 novembre (drapeau de configuration)
/c/<jeton>   lien de classe WhatsApp     → /student-signup, étape 2/3
/i/<jeton>   lien d'invitation enseignant → /teacher-signup, étape 2/3
```

| Écran | Route · vue | Statut | Règle |
|---|---|---|---|
| Page d'accueil publique | `/` · `homepage/index` | **Construit** | chantier `page-d-accueil-photo` ; PRD CA-A1, CA-A2 |
| Connexion, code oublié | `/login`, `/pin-reset` | Gardé (fond blanc) | Pal |

## 3. Élève

```
/student-signup  Inscription — 1. Ta classe → 2. Toi → 3. Ton code secret
        │
        ▼
/students  ACCUEIL
├── avatar ─────────────► « Mon compte » (plein écran)
│                          ├── Mon profil ──────────► /profile
│                          ├── Modifier mon code secret ► /profile/pin/edit
│                          ├── Mode sombre (interrupteur)
│                          └── Se déconnecter
├── « Besoin d'aide ? » ─► /aide
├── carte du prochain exercice
│   ├── « 3E B · CM1T › » ─► /students/classroom  MA CLASSE
│   │                         ├── exercices assignés ─► session
│   │                         ├── Fiches à revoir ────► fiche de révision
│   │                         └── exercices traités
│   ├── bouton (selon l'état) ─► session d'exercice ─► résultat ─► « Recommencer »
│   │                         ou fiche de révision (état « À revoir »)
│   └── « Et N autres en retard › » ─► Ma classe
├── grille : 6 matières ─► /courses?material  COURS ─► /courses/<cours>/essentials/<fiche>
│            « Inviter » ─► partage WhatsApp
├── annonces (carrousel ; lecture audio, masquer)
└── Historique ─ « Voir plus » ─► /students/archive  MON HISTORIQUE
```

| Écran | Route · vue | Statut | On y arrive par | Règle |
|---|---|---|---|---|
| Inscription en 3 étapes | `/student-signup`, `/c/<jeton>` · `classroom/student_registrations/new`, `classroom/joins/new` | **Modifié** (code de classe **Construit**) | page publique, lien de classe | InsÉ ; ADR code ; CA-B, CA-C |
| Accueil | `/students` · `classroom/student_homes/show` | **Construit** (refait) | connexion, inscription | AccÉ ; CA-D |
| Accueil sans classe (« Choisis ta classe ») | même route, état 6 de la carte | **Construit** | élève sans classe | AccÉ §3.3 ; CA-D7 |
| « Mon compte » | dialogue plein écran · `shared/navigation/_account_panel` ; `/students/menu` | **Modifié** | avatar | ÉcrÉ §3.1 ; CA-E1 |
| Mon profil | `/profile` · `identity/profiles/_student*` | **Modifié** | « Mon compte » | ÉcrÉ §3.2 ; CA-E2 |
| Modifier mon code secret | `/profile/pin/edit` | Gardé | « Mon compte » | — |
| Ma classe | `/students/classroom` · `classroom/student_classrooms/show` | **Modifié** (+ Fiches à revoir) | en-tête de la carte de l'accueil | ÉcrÉ §3.3 ; CA-E3 |
| Cours | `/courses` · `catalog/courses/index` | **Modifié** (lignes compactes) | grille de l'accueil | ÉcrÉ §3.6 ; CA-E6 |
| Fiche de cours, fiche de révision | `/courses/<cours>/essentials/<fiche>` · `catalog/essentials/show` | **Modifié** (étiquette « À revoir ») | Cours, Ma classe, carte « À revoir » | ÉcrÉ §3.4 ; CA-E4 |
| Session d'exercice | `/sessions/<id>` | Gardé | carte, Ma classe, Historique (« Refaire ») | — |
| Résultat de session | `/sessions/<id>/result` | **Modifié** (un bouton) | fin de session | ÉcrÉ §3.5 ; CA-E5 |
| Mon historique | `/students/archive` | Gardé | « Voir plus » de l'Historique | — |
| Aide | `/aide` | Gardé | « Besoin d'aide ? » | — |
| Changer de classe | `/students/classroom/change` | **Masqué** | aucune entrée | CA-K2 |

## 4. Enseignant

```
/teacher-signup  Inscription — 1. Votre établissement → 2. Vous (une matière) → 3. Votre code secret
        │
        ▼
/teachers  ACCUEIL (bandeau jaune)
├── avatar ─────────────► « Mon compte » (plein écran)
│                          ├── Établissement en cours (dès deux)
│                          ├── Mon profil ──────────────► /profile
│                          ├── Modifier mon code secret ─► /profile/pin/edit
│                          ├── Ajouter une matière (N sur 3) ─► modale « Mes matières » ; à 3 : écran de retrait
│                          ├── Ajouter un établissement (N sur 3) ─► ajout par code ; à 3 : /teachers/schools (retrait)
│                          ├── Mode sombre
│                          └── Se déconnecter
├── « Besoin d'aide ? » ─► /aide
├── carrousel des classes
│   ├── « TLE D 1 · CSMT › » ─► /classrooms/<id>  PAGE DE CLASSE
│   │                            ├── Partager sur WhatsApp · Copier le lien · ⋮ Changer le lien et le code
│   │                            ├── exercice assigné ─► RAPPORT /classrooms/<id>/assignments/<id>
│   │                            ├── Fiches à revoir
│   │                            └── élève ─► FICHE /classrooms/<id>/students/<id>
│   ├── code + « Copier »
│   └── « + Ajouter une classe » ─► /teachers/classrooms (déclarer ses classes)
├── ronds de niveau ─► /courses?level&series  COURS DE TLE D ─► fiche ─► assigner
│   └── « Inviter » ─► partage WhatsApp /i/<jeton>
├── annonces (lecture seule)
├── Cette semaine ─► RAPPORT
└── Historique ─► RAPPORT
```

| Écran | Route · vue | Statut | On y arrive par | Règle |
|---|---|---|---|---|
| Inscription en 3 étapes | `/teacher-signup`, `/i/<jeton>` · `identity/teacher_registrations/new` | **Modifié** | page publique, lien d'invitation | Ens §3.9 ; CA-J |
| Accueil | `/teachers` · `classroom/teacher_homes/show` | **Modifié** (refait) | connexion, inscription | Ens §3.3 ; CA-G |
| « Mon compte » | dialogue plein écran · `_account_panel` ; `/teachers/menu` | **Modifié** | avatar | Ens §3.4 ; CA-H1, CA-H2 |
| Mes matières (modale, ajout) | `/profile/materials/edit` | Gardé | « Ajouter une matière » sous 3 | — |
| Mes matières (retrait, à 3) | vue nouvelle sous `identity/profile_materials` | **Construit** | « Ajouter une matière » à 3 | Ens §3.4 ; CA-H3, CA-H5 |
| Mes établissements (retrait, à 3) | `/teachers/schools` · `school/teacher_schools/index` | **Modifié** (lignes « Retirer ») | « Ajouter un établissement » à 3 | Ens §3.4 ; CA-H4, CA-H5 |
| Ajouter un établissement | ajout par code existant (`/teachers/schools`) | Gardé | « Ajouter un établissement » sous 3 | — |
| Mon profil | `/profile` | **Modifié** (Matières sans action) | « Mon compte » | Ens §3.4 ; CA-H6 |
| Déclarer ses classes | `/teachers/classrooms` · `classroom/teaching_selections` | Gardé | « + Ajouter une classe » | — |
| Page de classe | `/classrooms/<id>` · `classroom/classrooms/show` | **Modifié** | en-tête de la carte de classe | Ens §3.5 ; CA-I1, CA-I2 |
| Fiche d'un élève | `/classrooms/<id>/students/<id>` · `classroom/classroom_students/show` | **Modifié** | liste de la page de classe, rapport | Ens §3.6 ; CA-I3 |
| Cours de <niveau> | `/courses?level&series` · `catalog/courses/index` | **Modifié** | rond de niveau | Ens §3.7 ; CA-G5 |
| Fiche de cours, assigner | `/courses/<cours>/essentials/<fiche>`, `/classrooms/<id>/assignments/new` | Gardé | Cours | — |
| Rapport d'un exercice | `/classrooms/<id>/assignments/<id>` · `classroom/assignment_follow_ups/show` | **Modifié** (badges) | Cette semaine, Historique, page de classe | Ens §3.8 ; CA-I4, CA-I5 |
| Inviter un collègue | partage WhatsApp `/i/<jeton>` | Gardé | rond « Inviter » seul | Ens §3.3 |
| Aide | `/aide` | Gardé | « Besoin d'aide ? » | — |
| Annonces (boîte) | `/announcements` | Gardé, **sans entrée** (l'onglet disparaît ; les annonces sont sur l'accueil) | — | Ens §3.3 |
| Rédiger une annonce | `/announcements/new`, `/announcements/mine` | **Masqué** | aucune entrée | CA-K1 |
| Vos jours de séance | `/classrooms/<id>/session_days/edit` | **Masqué** | aucune entrée | Ens §3.5 |
| Page Croissance (parrainage) | `/teachers/invite` | Gardé, **sans entrée sur téléphone** ; carte de la barre latérale sur ordinateur, à revoir à l'étape 4 | — | Ens §3.3 |

## 5. Ce qui disparaît de la navigation

| Entrée retirée | Où elle était | Où vit la destination désormais |
|---|---|---|
| Barre basse élève et enseignant | bas de l'écran | accueil |
| « Entrer en classe », « À faire ensuite » | accueil élève | en-tête de la carte → Ma classe |
| Accueil, Cours, Ma classe, Mon historique, Besoin d'aide | menu de l'avatar élève | accueil |
| Mode sombre | en-tête et profil élève | « Mon compte » |
| Code secret, Se déconnecter | profil élève | « Mon compte » |
| Onglet Classes (liste) | barre basse enseignant | carrousel de l'accueil |
| Onglet Annonces | barre basse enseignant | carrousel de l'accueil (lecture) |
| « Modifier mes classes » (⋮) | carte « Mes classes » | carte « + Ajouter une classe » |
| « Inviter un collègue » | menu du compte, carte sous lg | rond « Inviter » |
| Modifier les matières | ligne Matières du profil | « Mon compte » |
| Code de classe | page de classe (ADR, avant le 2026-10-23) | carte de la classe de l'accueil |
| Menus Niveau et Série | Cours enseignant | ronds de niveau de l'accueil |

## 6. Ce qui ne change pas d'écran (fond seulement)

Direction et Équipe : tous leurs écrans gardent leur navigation ; seuls le fond blanc, les gris et la police des titres changent (UDR palette). Captures avant fusion.
