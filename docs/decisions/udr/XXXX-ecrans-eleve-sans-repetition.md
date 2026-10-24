# UDR-XXXX : Écrans élève sans répétition — menu de l'avatar, profil, Ma classe, fiche de révision, résultat, Cours
<!-- index
titre: Écrans élève sans répétition : menu, profil, Ma classe, fiche, résultat, Cours
statut: Accepté *(porteur, 2026-10-23)*
adr-lie: —
problematique: Le relevé des écrans élève a trouvé la même information à deux ou trois endroits (menu qui répète l'accueil, mode sombre trois fois, carte du profil qui répète ses lignes, « Refaire un exercice » en double sur la fiche, note répétée sur le résultat, « Commencer la fiche de cours » écrit 19 fois). Chaque information garde une seule place.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-10-23 : « 1. oui 2. oui 3. oui » ; choix du porteur le 2026-10-23, écran par écran) · amendé le 2026-10-24 (phase ordinateur : menu, profil, Mon établissement, Cours par leçons, §3.6 bis) |
| **Date** | 2026-10-23 |
| **Chantier** | [`docs/chantiers/mvp-teacher-student`](../../chantiers/mvp-teacher-student/memo.md) |
| **ADR lié** | — |
| **Amende** | [UDR-0080](0080-en-tete-eleve-panneau-du-compte-et-barres-de-l-app-android.md) (panneau du compte) · [UDR-0101](0101-profil-eleve-ligne-classe-vers-changer-de-classe.md) (ligne Classe du profil) · [UDR-0119](0119-fiche-a-revoir-exercice-propose-et-regle-sur-20.md) (fiche à revoir) · [UDR-0085](0085-page-cours-eleve-groupee-par-matiere-avec-bouton-d-avancement.md) et UDR-0013 (Cours de l'élève : leçons d'une matière, fiches listées sur la carte) |
| **S'appuie sur** | UDR-XXXX-accueil-eleve-carte-du-prochain-exercice · UDR-XXXX-palette-froide-et-texte-sans-gras |
| **Remplacé par** | — |

---

## 1. Contexte

Le relevé du 2026-10-23 a compté quatorze répétitions côté élève. Une information dite deux fois coûte de la place sur un petit écran et fait douter l'élève : les deux boutons font-ils la même chose ?

## 2. Décision

Une information, une place. L'accueil porte les destinations (UDR de l'accueil) ; les autres écrans retirent ce qui y est déjà.

## 3. Règles d'implémentation

### 3.1 Menu de l'avatar (`shared/navigation/_avatar_menu.html.erb`, `NavigationHelper`)

- Entrées, dans cet ordre : en-tête (avatar, nom, « 3e B · Collège Moderne 1 de Tiassalé ») · **Mon profil** · **Mon établissement** (§3.2 bis) · **Modifier mon code secret** (son écran actuel) · **Mode sombre** (interrupteur, `theme_controller`) · séparateur · **Se déconnecter** (`text-ink`, pas de rouge).
- **Amendement du 2026-10-24 (porteur)** : « Mon établissement » entre dans le menu, chaque entrée ouvre son propre écran. **« Ma classe » n'y entre pas** : on l'ouvre par l'en-tête de la carte de l'accueil, pas de deuxième chemin. La classe et l'établissement ne sont plus des lignes du profil (§3.2). Vaut aussi sur téléphone.
- Retirés pour l'élève : Accueil, Cours, Ma classe, Mon historique, Ajouter ma photo, Besoin d'aide (et les destinations du rôle affichées sous lg).
- Le menu est un **panneau plein écran « Mon compte »** (titre et croix en haut), le même que celui de l'enseignant (porteur, 2026-10-23). Il remplace la liste déroulante sous l'avatar.
- **Sur ordinateur (≥ lg) : panneau latéral droit de 400 px** (porteur, 2026-10-24), pleine hauteur, au-dessus d'un voile `bg-ink/40` ; même contenu, même ordre. Échap, la croix ou un clic sur le voile le ferment ; le focus revient sur l'avatar.
- La page `student_menu_path` (coque Android) suit la même liste.

### 3.2 Profil (`identity/profiles/_student*.html.erb`)

- **Amendement du 2026-10-24 (porteur, « même design que le profil élève de Develop »)**, téléphone et ordinateur : la **carte bleue revient en tête** (dégradé `brand-strong`, avatar de 112 px à anneau blanc et bouton « + » de la photo, nom en blanc 20 px graisse 500), **avec le nom seul** : ni classe ni « Élève en … ». Puis la carte « Mes informations ». La règle « pas de grande carte » du 2026-10-23 est levée.
- La page : « ‹ Accueil », titre « Mon profil », carte bleue, carte « Mes informations ».
- **Quatre lignes**, au style des lignes actuelles (`_student_row` : pastille d'icône carrée `bg-brand-soft`, libellé `text-mute` au-dessus de la valeur, action `text-brand-strong` et chevron à droite) : Photo (Ajouter ›) · Nom (Modifier ›) · Numéro (Changer ›) · Inscrit le / Inscrite le.
- Retirés : lignes Classe et Établissement (l'établissement a son écran, §3.2 bis ; la classe est dans l'en-tête du menu et dans Ma classe), section « Mon code secret », section « Apparence / Mode sombre », bouton « Se déconnecter » (dans le menu).

### 3.2 bis Mon établissement (nouvel écran, porteur, 2026-10-24)

- Ouvert par l'entrée « Mon établissement » du menu. Lecture seule, même gabarit que le profil : « ‹ Accueil », titre « Mon établissement », carte « Informations ».
- **Quatre lignes**, même style de ligne que le profil, sans action : Nom (nom complet) · Sigle · DRENA · Type (Public, Privé, Mixte). Ligne Sigle absente si l'établissement n'en a pas.
- Rien d'autre (ni direction, ni annonces : elles sont dans le carrousel de l'accueil). Élève sans classe : l'entrée n'est pas dans le menu.

### 3.3 Ma classe (`classroom/student_classrooms/show.html.erb`)

- Tout est gardé (carte de classe, fiches de cours assignées, exercices assignés, exercices traités).
- **Ajout : section « Fiches à revoir »** juste après « Exercices assignés » ; sous-titre « Relis-les, puis refais un de leurs exercices. » ; une ligne par fiche en attente (rond `bg-brand-soft` + icône de matière, titre 14 px, « Maths · Fiche de révision » 13 px, chevron), 3 lignes puis « Voir plus ». Données : celles de l'actuel `_pending_gaps` de l'accueil, déplacé ici. Section absente s'il n'y a aucune fiche.
- La carte de classe est blanche à bordure (`border-line`), pas un aplat bleu.

### 3.4 Fiche de révision (`catalog/essentials/show.html.erb`)

- **Retiré** : la carte « Fiche à revoir · Refaire un exercice » du bas.
- **Ajout** : sous le titre, à côté des puces matière et classe, l'étiquette « À revoir depuis le 26 sept. » (`bg-brand-soft text-brand-strong`, icône de reprise), seulement si la fiche est à revoir.
- La liste « Exercices » reste seule en bas ; l'exercice proposé (UDR-0119) porte la pastille « Proposé » et son bouton « Refaire » est le principal (`primary`), les autres `secondary`.

### 3.5 Résultat de session (`assessment/session_results/show.html.erb`)

- **Retirés** : l'encadré « Tu restes autour de 12/20. Relis la correction ci-dessous… » et le bouton « Revoir l'exercice ».
- Reste un seul bouton, **« Recommencer »** (`primary`). Badge, note, maîtrise et correction question par question inchangés. « Mauvaise réponse » et « Fragile » : pastille neutre (`bg-mist text-mute`).

### 3.6 Cours (`catalog/courses/index.html.erb`)

**Amendé le 2026-10-24 (porteur : « afficher les leçons de la matière, pas les fiches » ; « une carte par leçon, les fiches de révision directement dans la carte »).** Vaut sur téléphone et sur ordinateur, pour l'élève seulement ; le Cours de l'enseignant et de l'équipe ne change pas.

- La page montre **les leçons d'une seule matière** (un « cours » du catalogue est une leçon), jamais toutes les matières à la suite. On y arrive par une case de la grille de l'accueil (`?material=`).
- Sous la recherche (« Rechercher une leçon ou une fiche »), une seule ligne : « 6 leçons · Progression DPFC 2026-2027 ».
- **Une carte par leçon**, dans l'ordre du programme : « LEÇON 3 » (12 px majuscules `text-mute`), titre de la leçon (16 px, 500), pastille « En cours » à droite s'il y a lieu ; puis **ses fiches**, une ligne chacune (14 px, chevron, ligne entière cliquable ≥ 44 px, séparateur `border-line`), avec l'étiquette « À revoir » (`bg-brand-soft text-brand-strong`) si la fiche est à revoir.
- **Au-delà de 3 fiches** : les 3 premières, puis « Voir les N fiches » (lien `text-brand-strong`, ≥ 44 px) qui déplie la carte (`reveal`, comme ailleurs).
- Exception écrite à l'UDR-0013 (« aucune liste de fiches essentielles sur la carte ») : levée pour l'élève seulement.
- Retirés : le lien « Commencer / Reprendre » de chaque carte et la mention de progression sur chaque carte.

### 3.6 bis Sur ordinateur (≥ lg)

Décidé par le porteur le 2026-10-24 sur maquettes à 1440 et 1024 px, en gris puis en palette froide. Gabarit commun : barre du haut, barre latérale Accueil · Cours · Ma classe (entrée active `bg-brand-soft text-brand-strong`), contenu centré de **912 px** au plus.

- **« Mon compte »** : panneau latéral droit de 400 px (§3.1), liste du §3.1.
- **Ma classe** : carte de classe, puis « Fiches de cours assignées » (bande horizontale), pleine largeur ; dessous **deux colonnes 2/3 – 1/3** : à gauche « Exercices assignés » puis « Fiches à revoir » (ce qui reste à faire), à droite « Exercices traités ». Remplace les deux colonnes égales de l'UDR-0086 §3.4.
- **Fiche de révision (élève)** : **deux colonnes** ; à gauche la fiche (titre, puces, étiquette « À revoir depuis le … », contenu en `max-w-prose`), à droite une colonne de **300 px** avec la carte « Exercices », **collante** (`sticky top-6`) pendant la lecture ; l'exercice proposé y porte « Proposé » et le seul bouton `primary`. Enseignant et équipe gardent la page actuelle.
- **Résultat de session** : **deux colonnes** ; à gauche une colonne de **340 px collante** (badge, titre, note, maîtrise, progrès, « Recommencer ») ; à droite la carte « Correction ». Remplace les deux colonnes égales actuelles.
- **Cours** : en haut, **les 6 matières en pastilles** (rond d'icône 32 px + nom, 44 px de haut) ; la matière affichée est pleine `bg-brand-strong` texte blanc (`aria-current="page"`), les autres blanches à bordure `border-line-strong`. « Cours » de la barre latérale ouvre la matière de la dernière case touchée, sinon la première de la grille (Maths). Dessous, recherche, ligne de progression, puis **les cartes de leçon sur deux colonnes** (`items-start`). Les pastilles sont propres à l'ordinateur : sur téléphone, on change de matière par la grille de l'accueil.
- **Mon profil** et **Mon établissement** : une colonne de **720 px** centrée, contenu du §3.2 et du §3.2 bis.
- Couleurs : uniquement les jetons de l'UDR palette ; rien de nouveau à part la pastille de matière pleine `brand-strong` (contraste 5,29:1).

### 3.7 États obligatoires

- Menu : sans objet. Profil : photo absente (« Aucune photo · Ajouter », initiales dans l'avatar de la carte bleue). Mon établissement : sigle absent, ligne masquée. Cours : leçon sans fiche, « Pas encore de fiche » (13 px `text-mute`) ; matière sans leçon, message vide actuel. Ma classe : section « Fiches à revoir » absente si vide. Fiche : étiquette absente si la fiche n'est pas à revoir. Cours : recherche sans résultat, message actuel. Résultat : inchangé.

### 3.8 Accessibilité

- Cibles ≥ 44 px (lignes de Cours, lignes de Fiches à revoir, entrées du menu).
- Menu : `role="menu"`, entrées `role="menuitem"`, l'interrupteur « Mode sombre » `role="switch"` avec `aria-checked`.
- Jetons et contrastes de l'UDR palette.

## 4. Conséquences

- L'élève n'a plus qu'un chemin par destination. Ma classe s'ouvre par la tête de la carte de l'accueil ; Mon historique par la section Historique ; l'aide par le bandeau.
- Interdit de remettre dans le menu élève une destination portée par l'accueil (Ma classe comprise, porteur, 2026-10-24).
- Le 2026-10-24 change aussi le téléphone (menu, profil, Mon établissement, Cours par leçons) : les critères CA-E8, CA-E9, CA-E10 et CA-E14 du PRD §4 bis remplacent CA-E1, CA-E2 et CA-E6.
