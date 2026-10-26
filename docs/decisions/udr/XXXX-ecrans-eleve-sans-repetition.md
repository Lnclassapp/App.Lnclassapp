# UDR-XXXX : Écrans élève sans répétition — menu de l'avatar, profil, Ma classe, fiche de révision, résultat, Cours
<!-- index
titre: Écrans élève sans répétition : menu, profil, Ma classe, fiche, résultat, Cours
statut: Accepté *(porteur, 2026-10-23)*
adr-lie: —
problematique: Le relevé des écrans élève a trouvé la même information à deux ou trois endroits (menu qui répète l'accueil, mode sombre trois fois, carte du profil qui répète ses lignes, « Refaire un exercice » en double sur la fiche, note répétée sur le résultat, « Commencer la fiche de cours » écrit 19 fois). Chaque information garde une seule place.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-10-23 : « 1. oui 2. oui 3. oui » ; choix du porteur le 2026-10-23, écran par écran) · ordinateur (§3.6 bis) ajouté le 2026-10-24, sans rien changer au téléphone |
| **Date** | 2026-10-23 |
| **Chantier** | [`docs/chantiers/mvp-teacher-student`](../../chantiers/mvp-teacher-student/memo.md) |
| **ADR lié** | — |
| **Amende** | [UDR-0080](0080-en-tete-eleve-panneau-du-compte-et-barres-de-l-app-android.md) (panneau du compte) · [UDR-0101](0101-profil-eleve-ligne-classe-vers-changer-de-classe.md) (ligne Classe du profil) · [UDR-0119](0119-fiche-a-revoir-exercice-propose-et-regle-sur-20.md) (fiche à revoir) |
| **S'appuie sur** | UDR-XXXX-accueil-eleve-carte-du-prochain-exercice · UDR-XXXX-palette-froide-et-texte-sans-gras |
| **Remplacé par** | — |

---

## 1. Contexte

Le relevé du 2026-10-23 a compté quatorze répétitions côté élève. Une information dite deux fois coûte de la place sur un petit écran et fait douter l'élève : les deux boutons font-ils la même chose ?

## 2. Décision

Une information, une place. L'accueil porte les destinations (UDR de l'accueil) ; les autres écrans retirent ce qui y est déjà.

## 3. Règles d'implémentation

### 3.1 Menu de l'avatar (`shared/navigation/_avatar_menu.html.erb`, `NavigationHelper`)

- Entrées, dans cet ordre : en-tête (avatar, nom, « 3e B · Collège Moderne 1 de Tiassalé ») · **Mon profil** · **Modifier mon code secret** · **Mode sombre** (interrupteur, `theme_controller`) · séparateur · **Se déconnecter** (`text-ink`, pas de rouge).
- Retirés pour l'élève : Accueil, Cours, Ma classe, Mon historique, Ajouter ma photo, Besoin d'aide (et les destinations du rôle affichées sous lg).
- Le menu est un **panneau plein écran « Mon compte »** (titre et croix en haut), le même que celui de l'enseignant (porteur, 2026-10-23). Il remplace la liste déroulante sous l'avatar.
- **Sur ordinateur (≥ lg) : panneau latéral droit de 400 px** (porteur, 2026-10-24), pleine hauteur, au-dessus d'un voile `bg-ink/40` ; même contenu, même ordre. Échap, la croix ou un clic sur le voile le ferment ; le focus revient sur l'avatar.
- La page `student_menu_path` (coque Android) suit la même liste.

### 3.2 Profil (`identity/profiles/_student*.html.erb`)

- **Pas de grande carte** en tête. La page : « ‹ Accueil », titre « Mon profil », section « Mes informations ».
- Six lignes : Photo (Ajouter ›) · Nom (Modifier ›) · Numéro (Changer ›) · Classe (sans action : le changement de classe est masqué) · Établissement · Inscrit le / Inscrite le.
- Retirés : section « Mon code secret », section « Apparence / Mode sombre », bouton « Se déconnecter » (tous trois dans le menu).

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

- Sous la recherche, une seule ligne : « 19 fiches de cours · Progression DPFC 2026-2027 ».
- Chaque fiche devient une **ligne compacte** dans une carte par matière : titre 14 px, « Leçon 3 » 13 px `text-mute`, chevron ; ligne entière cliquable, ≥ 44 px ; pastille « En cours » gardée.
- Retirés : le lien « Commencer / Reprendre la fiche de cours » de chaque carte et la mention de progression sur chaque fiche. En-têtes de matière inchangés.

### 3.6 bis Sur ordinateur (≥ lg)

Décidé par le porteur le 2026-10-24 sur maquettes à 1440 et 1024 px. **Ne change rien au téléphone** (porteur, 2026-10-24 : les écrans téléphone validés le 2026-10-23 font foi). Gabarit commun : barre du haut, barre latérale Accueil · Cours · Ma classe (entrée active `bg-brand-soft text-brand-strong`), contenu centré de **912 px** au plus.

- **« Mon compte »** : panneau latéral droit de 400 px (§3.1). **Sur ordinateur seulement**, la liste est : en-tête (avatar, nom, « 3e B · établissement ») · Mon profil · **Mon établissement** · Modifier mon code secret · Mode sombre · Se déconnecter. « Ma classe » n'y entre pas (porteur, 2026-10-24 : « uniquement sur ordinateur, mes choix d'hier pour le téléphone »).
- **Ma classe** : carte de classe, puis « Fiches de cours assignées » (bande horizontale), pleine largeur ; dessous **deux colonnes 2/3 – 1/3** : à gauche « Exercices assignés » puis « Fiches à revoir », à droite « Exercices traités ».
- **Fiche de révision (élève)** : **deux colonnes** ; à gauche la fiche (contenu en `max-w-prose`), à droite une colonne de **300 px** avec la carte « Exercices », **collante** (`sticky top-6`). Enseignant et équipe gardent la page actuelle.
- **Résultat de session** : **deux colonnes** ; à gauche une colonne de **340 px collante** (badge, titre, note, maîtrise, progrès, « Recommencer ») ; à droite la carte « Correction ».
- **Mon profil** : une colonne de **720 px** centrée. **Sur ordinateur seulement** : en tête, la **carte bleue** au style du profil de Develop (dégradé `brand-strong`, avatar de 112 px à anneau blanc et bouton « + » de la photo, **nom seul** en blanc 20 px, graisse 500), puis « Mes informations » en **quatre lignes** au style de `_student_row` (pastille d'icône carrée `bg-brand-soft`, libellé au-dessus de la valeur, action `text-brand-strong` et chevron) : Photo · Nom · Numéro · Inscrit·e le. Ni Classe ni Établissement : l'établissement a son écran, la classe est dans l'en-tête du menu.
- **Mon établissement** (nouvel écran, **ordinateur seulement**, ouvert depuis « Mon compte ») : colonne de 720 px, « ‹ Accueil », titre « Mon établissement », carte « Informations » de quatre lignes en lecture seule, même style : Nom · Sigle (absente s'il n'y en a pas) · DRENA · Type. Rien d'autre.
- **Cours** (**ordinateur seulement**, le téléphone garde le §3.6) : les **leçons d'une seule matière** ; en haut, **les 6 matières en pastilles** (rond d'icône 32 px + nom, 44 px de haut), celle affichée pleine `bg-brand-strong` texte blanc (`aria-current="page"`), les autres blanches à bordure `border-line-strong` ; « Cours » de la barre latérale ouvre la matière de la dernière case touchée, sinon la première de la grille. Sous la recherche, « 6 leçons · Progression DPFC 2026-2027 ». **Une carte par leçon**, sur **deux colonnes** (`items-start`) dans l'ordre du programme : « LEÇON N » (12 px majuscules `text-mute`), titre (16 px, 500), « En cours » s'il y a lieu, puis **ses fiches** en lignes entières cliquables ≥ 44 px, avec « À revoir » (`bg-brand-soft text-brand-strong`) si besoin ; au-delà de 3 fiches, « Voir les N fiches ». Exception à l'UDR-0013 (fiches listées sur la carte) pour l'élève sur ordinateur seulement.
- **Fond de page `bg-mist`** sur tous les écrans élève dès lg, contenus en cartes blanches (porteur, 2026-10-24, option A ; voir UDR accueil §3.1).
- Couleurs : uniquement les jetons de l'UDR palette.

**Téléphone inchangé** (porteur, 2026-10-24) : à 390 px, le menu, le profil et Cours restent ceux des §3.1, §3.2 et §3.6, validés le 2026-10-23. Le menu à « Mon établissement », le profil à carte bleue et 4 lignes, l'écran « Mon établissement » et Cours par leçons sont **décidés pour l'ordinateur seulement**. Les porter au téléphone reste une idée pour plus tard, à rouvrir seulement si le porteur le demande.

### 3.7 États obligatoires

- Menu : sans objet. Profil : photo absente (« Aucune photo · Ajouter »). Ma classe : section « Fiches à revoir » absente si vide. Fiche : étiquette absente si la fiche n'est pas à revoir. Cours : recherche sans résultat, message actuel. Résultat : inchangé.

### 3.8 Accessibilité

- Cibles ≥ 44 px (lignes de Cours, lignes de Fiches à revoir, entrées du menu).
- Menu : `role="menu"`, entrées `role="menuitem"`, l'interrupteur « Mode sombre » `role="switch"` avec `aria-checked`.
- Jetons et contrastes de l'UDR palette.

## 4. Conséquences

- L'élève n'a plus qu'un chemin par destination. Ma classe s'ouvre par la tête de la carte de l'accueil ; Mon historique par la section Historique ; l'aide par le bandeau.
- Interdit de remettre dans le menu élève une destination portée par l'accueil.
