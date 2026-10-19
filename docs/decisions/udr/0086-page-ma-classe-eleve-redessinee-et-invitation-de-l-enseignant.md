# UDR-0086 : Page Ma classe de l'élève — carte de la classe en dégradé, listes en cartes blanches, « Inviter mon enseignant » sans enseignant
<!-- index
titre: Ma classe de l'élève redessinée, invitation de l'enseignant
statut: Accepté *(porteur, 2026-10-15)*
adr-lie: [0089](../adr/0089-exercice-du-jour-calcule-a-la-lecture-et-fait-seul-deduit.md)
problematique: Élève : Ma classe sans lien « Accueil », carte de la classe en dégradé bleu, ni enseignants ni nombre d'élèves, carte « Aucun enseignant » avec « Inviter mon enseignant » comme seule action possible, bande de 1 / 2,5 / 4 cartes, listes côte à côte dès 1 024 px. Amende UDR-0011, 0057, 0076 §3.2
-->

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-15 ; livré par le chantier ma-classe-eleve)* |
| **Date** | 2026-10-15 |
| **Chantier** | [`docs/chantiers/ma-classe-eleve`](../../chantiers/ma-classe-eleve/memo.md) |
| **ADR lié** | [ADR-0089](../adr/0089-exercice-du-jour-calcule-a-la-lecture-et-fait-seul-deduit.md) §4.3 (message d'invitation de l'enseignant) |
| **Amende** | [UDR-0057](0057-ecrans-eleve-epures.md) (Ma classe peut avoir une action ; palier 700 px) · [UDR-0076](0076-organisation-des-ecrans-eleve.md) §3.2 (mise en page) · [UDR-0011](0011-ma-classe.md) (carte de la classe) |
| **Dépend de** | [UDR-0084](0084-accueil-eleve-en-tete-au-logo-menu-de-l-avatar-et-exercice-du-jour.md) (en-tête, menu de l'avatar, plus de barre du bas) |
| **Remplacé par** | — |

---

## 1. Contexte

« Ma classe » a été redessinée sur la toile https://claude.ai/artifact/5YCL2xGDiioqcrvEBr6W1B. Elle couvre le téléphone (390 px), la tablette (820 px, 1 180 px à l'horizontale) et l'ordinateur (1 280 px), dans les états suivants : avec travail, sans enseignant, « Voir plus » ouvert, menu ouvert et thème sombre. Le porteur a tranché le 2026-10-15 (memo du chantier) :

- même cadre que l'accueil et Cours ;
- ni enseignants ni nombre d'élèves ;
- les deux listes d'exercices restent ;
- une seule action possible, « Inviter mon enseignant », quand la classe n'a aucun enseignant.

## 2. Décision

> **« Ma classe » garde son contenu et prend le cadre de l'accueil. Sa seule action, « Inviter mon enseignant », n'apparaît que si la classe n'a aucun enseignant sur Lnclass.**

## 3. Règles d'implémentation

### 3.1 Haut de page

- **En-tête et navigation** : ceux d'UDR-0084. Il n'y a plus de lien « Accueil » au-dessus du titre (`ui_page_header` sans `back:`), et « Ma classe » est en surbrillance dans les menus.
- **Titre** : « Ma classe ».

### 3.2 Carte de la classe (`#student_classroom_header`)

- **Fond** : dégradé bleu de la carte « Ma classe » de l'accueil, de `brand-strong` vers `brand`, avec le texte en `text-white`.
- **Contenu** :
  - le nom de la classe (`h2`) ;
  - le niveau et la série ;
  - l'établissement (icône `building-library`) ;
  - l'année scolaire (icône `calendar`).
- **Absents** : le nombre d'élèves, la liste des élèves (UDR-0011) et la liste des enseignants.

### 3.3 Carte « Aucun enseignant » (`_no_teacher`, nouveau)

- **Condition** : elle n'est rendue que si `has_teacher` est faux. Elle se place sous la carte de la classe.
- **Contenu** :
  - l'icône `user-plus` ;
  - « Aucun enseignant sur Lnclass pour l'instant » ;
  - une phrase : « Invite ton enseignant : il pourra te donner des exercices. » ;
  - le bouton « Inviter mon enseignant » (`brand`, icône `chat-bubble-left-right`), rendu par `classroom/student_homes/_invite_teacher`, ce qui donne le même message que l'accueil.
- **UDR-0057 R1** : c'est la seule action principale de la page. Quand la classe a un enseignant, la page n'a aucune action, comme aujourd'hui.

### 3.4 Listes

- **Contenu et ordre** : inchangés (UDR-0076 §3.2). Chaque bloc est une `ui_card` blanche, avec 3 lignes puis « Voir plus ».
  - **Cours assignés** : la bande qui défile.
  - **Exercices assignés** : l'ordre de « À faire » ; les échéances en retard, aujourd'hui et demain en orange (`warning`, UDR-0062).
  - **Exercices traités** : le meilleur score, en `text-success` à partir de 14/20 et en `text-ink` en dessous, jamais en rouge. Les badges Acquis / Fragile / En difficulté restent.

| Largeur | Colonne | Bande des cours | Listes d'exercices |
|---|---|---|---|
| < 700 px | pleine largeur | 1 carte et le début de la suivante | l'une sous l'autre |
| 700–1 023 px | 720 px, centrée | 2 cartes et demie | l'une sous l'autre |
| ≥ 1 024 px | 960 px au plus, à droite du menu de gauche | 4 cartes | côte à côte (`lg:grid-cols-2`) |

### 3.5 Palier 700 px

- **Amendement** : UDR-0057 réservait les changements de mise en page des écrans élève au seul palier `lg`. Les pages redessinées (UDR-0084, 0085 et celle-ci) ajoutent un palier à 700 px, qui centre la colonne à 720 px.
- **Classes** : on utilise les classes `min-[700px]:` de Tailwind. Il n'y a pas de nouveau token de point de rupture.

### 3.6 États obligatoires

- Avec travail.
- Sans cours ni exercice assigné : les états vides actuels.
- Sans enseignant.
- Avec enseignant : aucune action.
- « Voir plus » ouvert.
- Menu ouvert.
- Thème sombre.

### 3.7 Accessibilité

- **Carte « Aucun enseignant »** : c'est une `section` titrée. Le bouton a pour nom « Inviter mon enseignant sur WhatsApp ».
- **Contraste** : il est AA sur le dégradé, dans les deux thèmes.
- **Notes** : elles gardent leur texte (« 15/20 »), la couleur n'en est jamais le seul porteur.

## 4. Conséquences

- **Tests à réécrire** : `test/system/classroom/student_classroom_test.rb` (le retour « Accueil », la mise en page) et `test/controllers/classroom/student_classrooms_controller_test.rb` (aucune action quand la classe a un enseignant, la carte quand elle n'en a pas).
- **Partial partagé** : `_invite_teacher` est rendu sur deux pages. S'il gagne un troisième usage, il passe dans `shared/`.
