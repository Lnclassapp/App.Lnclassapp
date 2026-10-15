# UDR-0085 : Page Cours de l'élève — groupes par matière, recherche seule, bouton d'avancement, vue de la matière
<!-- index
titre: Page Cours de l'élève groupée par matière, bouton d'avancement
statut: Proposé
adr-lie: [0090](../adr/0090-lecture-des-fiches-par-l-eleve-et-rang-des-matieres.md)
problematique: Élève : plus de filtre Matière, cours groupés par matière dans l'ordre du programme (titre cliquable vers la vue de la matière), carte sans badge de matière dont le bouton dit Commencer / Reprendre / Revoir, 1 / 2 / 3 colonnes. Amende UDR-0013, 0057, 0076
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-15 |
| **Chantier** | [`docs/chantiers/cours-eleve`](../../chantiers/cours-eleve/memo.md) |
| **ADR lié** | [ADR-0090](../adr/0090-lecture-des-fiches-par-l-eleve-et-rang-des-matieres.md) (lectures, rang des matières) |
| **Amende** | [UDR-0013](0013-catalogue-et-page-cours.md) (branche élève de `/courses`) · [UDR-0057](0057-ecrans-eleve-epures.md) (la règle « un seul `li` » du test de sobriété suit les groupes) · [UDR-0076](0076-organisation-des-ecrans-eleve.md) (la vue d'une matière remplace la liste filtrée) |
| **Dépend de** | [UDR-0084](0084-accueil-eleve-en-tete-au-logo-menu-de-l-avatar-et-exercice-du-jour.md) (en-tête, menu de l'avatar, plus de barre du bas) |
| **Remplacé par** | — |

---

## 1. Contexte

« Cours » a été redessiné sur la toile https://claude.ai/artifact/78wguP9ZtQc1g5LrtcxTy4. Elle couvre le téléphone (390 px), la tablette (820 px, 1 180 px à l'horizontale) et l'ordinateur (1 280 px), dans les états suivants : tous les cours, une matière, aucun résultat, sans classe, info ouverte, menu ouvert et thème sombre. Le porteur a tranché chaque point le 2026-10-15 (memo du chantier). Seule la branche élève de `catalog/courses#index` change ; l'enseignant, la direction et l'équipe gardent la page actuelle.

## 2. Décision

> **Pour l'élève, « Cours » n'a plus que la recherche. Les cours sont groupés par matière, dans l'ordre du programme ; le titre d'un groupe ouvre la vue de la matière. Chaque carte porte un seul bouton qui dit où en est l'élève.**

## 3. Règles d'implémentation

### 3.1 Haut de page (`catalog/courses/index`, branche élève)

- **En-tête et navigation** : ceux d'UDR-0084. Le lien « Accueil » au-dessus du titre disparaît, car on revient par le menu. « Cours » est en surbrillance dans le menu de l'avatar (< 1 024 px) et dans le menu de gauche (≥ 1 024 px).
- **Titre** :
  - sur la liste complète, « Cours » suivi de l'info-bulle « Quels cours ? » (« Tu vois seulement les cours de ton niveau. »), comme aujourd'hui ;
  - dans la vue d'une matière (`?material=<slug>`), l'icône de la matière (`ui_subject_bubble`) et son nom complet. Pas de lien « Tous les cours ».
- **Recherche** : un seul champ pleine largeur, avec la recherche pendant la frappe (`search` existant).
  - Pas de liste « Matière », « Niveau » ni « Série ».
  - Le bouton « Filtrer » sans JS reste, pour la recherche.
  - Dans la vue d'une matière, la recherche est limitée à cette matière : le `material` est gardé en champ caché.
- **Compteur et « Tout voir »** : le compteur (`aria-live`) reste. « Tout voir » (`#courses_reset`) n'apparaît que pendant une recherche (`q` non vide).

### 3.2 Groupes (`_course_group_title`, nouveau)

- **Contenu** : le titre `h2` d'un groupe porte l'icône de la matière, son nom complet et le nombre de cours (« 4 cours »). Le nombre vient de `Page#material_counts` ; il compte toute la recherche, pas seulement la page.
- **Lien** : le titre entier est un lien vers `courses_path(material: slug)`, avec une flèche après le nombre. Dans la vue d'une matière, il n'y a qu'un groupe et son titre n'est pas un lien.
- **Ordre** : celui de `materials.position` (ADR-0090), puis le nom.
- **Pendant une recherche** : les groupes restent ; un groupe sans résultat disparaît.
- **Pagination** (24 par page) : un titre n'est rendu que si la matière change par rapport à la carte précédente. Le cadre `courses_page_N` reçoit `after_material=<slug>` pour ne pas répéter le titre du groupe en cours.

### 3.3 Carte (`_course_card`, variante élève)

| Largeur | Grille | Disposition de la carte |
|---|---|---|
| < 700 px | 1 colonne | icône de la matière à gauche du titre |
| 700–1 023 px | 2 colonnes, cartes de même hauteur | idem, bouton aligné en bas |
| ≥ 1 024 px | 3 colonnes, cartes de même hauteur | icône au-dessus du titre, bouton aligné en bas |

- **Contenu** : le nom du cours (`h3`) et la description sur 2 lignes (`line-clamp-2`). Ni badge de matière (le groupe le porte) ni badge de niveau.
- **Bouton**, un seul par carte, toute la carte restant cliquable vers la même cible :

| `progress` | Libellé | Cible | Signe |
|---|---|---|---|
| `:new` | « Commencer le cours » | page du cours | flèche |
| `:started` | « Reprendre le cours » | `course_essential_path(course, resume_essential_slug)` | flèche |
| `:done` | « Revoir le cours » | page du cours | coche `check-circle` en `text-success` devant, flèche après |

- **Interdits** : pas de barre de progression ni de texte d'état (décision du porteur : « c'est moche »).
- **Autres rôles** : la carte de l'enseignant, de la direction et de l'équipe garde le badge de matière, le badge de niveau et « Ouvrir le cours → ».

### 3.4 Mise en page

- **Colonne** : pleine largeur sous 700 px ; 720 px au plus, centrée, dès 700 px ; dès 1 024 px, à droite du menu de gauche (`w-rail`), 960 px au plus.
- **Espacement** : 24 px entre deux groupes, 12 px entre les cartes.

### 3.5 États obligatoires

| État | Rendu |
|---|---|
| Tous les cours | groupes dans l'ordre |
| Une matière | titre de la matière, un groupe |
| Recherche avec résultats | groupes et « Tout voir » |
| Aucun résultat | « Aucun cours trouvé » · « Essaye un autre mot. » · « Effacer la recherche » |
| Sans classe | état actuel (`no_class_*`) |
| Aucun cours publié | « Aucun cours pour l'instant » |
| Erreur de recherche | `ui_error_state` actuel |
| Page suivante | « Afficher plus de cours », sans titre répété |
| Thème sombre | tokens seulement (UDR-0065) |

### 3.6 Tokens

- **Couleurs** : `paper`, `white`, `ink`, `mute`, `line`, `brand`, `brand-strong`, `success`, plus les tons de matière de `ui_subject_bubble`.
- **Rayons et ombres** : `rounded-card`, `shadow-card`.

Aucun nouveau token.

### 3.7 Accessibilité

- **Titres** : un `section` par groupe, `aria-labelledby` sur son `h2`. Le lien du titre a pour nom « %{matière}, %{n} cours, voir la matière ».
- **Bouton de la carte** : son nom accessible contient le nom du cours (« Reprendre le cours Les fractions »).
- **Coche de « Revoir »** : décorative, le texte suffit.
- **Cibles tactiles** : au moins `spacing-tap`. Le contraste est AA dans les deux thèmes.

## 4. Conséquences

- **Une même vue pour les matières** : la vue d'une matière sert aussi aux bulles de « Mes matières » de l'accueil (`/courses?material=<slug>`, inchangé).
- **Tests à réécrire** :
  - `test/system/catalog/course_catalog_test.rb:26` : l'élève ne choisit plus « SVT » dans une liste ;
  - `:175` : la règle de sobriété s'applique à la vue de la matière ;
  - `test/controllers/catalog/courses_controller_test.rb:235`, `:259`, `:362` : badge de matière, lien « Accueil », filtres au téléphone.
- **UDR-0013** : elle ne vaut plus pour la branche élève de `/courses`. Elle reste valable pour les autres rôles et pour la page d'un cours.
