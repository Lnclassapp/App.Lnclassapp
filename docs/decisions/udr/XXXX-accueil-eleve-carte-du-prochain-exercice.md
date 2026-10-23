# UDR-XXXX : Accueil élève « Wave » — bandeau court, carte du prochain exercice, grille, annonce, historique
<!-- index
titre: Accueil élève « Wave » : carte du prochain exercice et six états
statut: Accepté *(porteur, 2026-10-23)*
adr-lie: —
problematique: L'accueil élève s'ouvre sur « Entrer en classe » et empile cinq blocs (classe, matières, annonces, À faire, activités) ; l'élève ne voit pas d'un coup d'œil ce qu'il doit faire maintenant. L'accueil devient un bandeau court, une carte blanche qui dit le prochain geste, la grille des matières, une annonce et l'historique.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-10-23 : « 1. oui 2. oui 3. oui » ; agencement validé par le porteur le 2026-10-23, couleurs v3 validées le même jour) |
| **Date** | 2026-10-23 |
| **Chantier** | [`docs/chantiers/mvp-teacher-student`](../../chantiers/mvp-teacher-student/memo.md) |
| **ADR lié** | — |
| **Remplace** | [UDR-0084](0084-accueil-eleve-en-tete-au-logo-menu-de-l-avatar-et-exercice-du-jour.md) (en-tête au logo, menu de l'avatar) · [UDR-0076](0076-organisation-des-ecrans-eleve.md) §ordre de l'accueil |
| **S'appuie sur** | UDR-XXXX-palette-froide-et-texte-sans-gras (jetons) · [UDR-0119](0119-fiche-a-revoir-exercice-propose-et-regle-sur-20.md) (fiche à revoir) |
| **Remplacé par** | — |

---

## 1. Contexte

Un élève ivoirien ouvre l'app sur un Android d'entrée de gamme, souvent sur un réseau faible. L'accueil actuel commence par la carte « Ma classe · Entrer en classe ». Le travail à faire n'arrive qu'au quatrième bloc, et l'information se répète : les exercices sont aussi dans Ma classe, l'historique dans Mon historique, l'aide dans le menu. Le porteur veut la simplicité de Wave, avec le bandeau et la carte disposés comme chez Djamo.

## 2. Décision

1. **Une seule question par écran : « qu'est-ce que je fais maintenant ? ».** Une carte blanche, posée à cheval sur un bandeau bleu court, dit le prochain geste et porte un seul bouton.
2. **Ordre figé :** bandeau → carte → grille des matières (7 cases) → annonce → Historique. **Pas de « À faire ensuite »** : la liste complète vit dans Ma classe. **Pas de barre basse.**
3. **Un seul chemin par destination.** La grille mène aux cours, « 3E B · CM1T › » en tête de carte mène à Ma classe, l'Historique et son « Voir plus » mènent à Mon historique, « Besoin d'aide ? » dans le bandeau ouvre l'aide. Le menu de l'avatar ne répète aucune de ces destinations.
4. **La carte a six états**, choisis par une seule règle de priorité (§3.3).

Pourquoi pas un accueil en liste (comme aujourd'hui) : l'élève qui ouvre l'app pour un exercice doit le trouver sans faire défiler. Pourquoi pas un bandeau plein écran façon Wave : la carte blanche à la Djamo garde le contraste et réduit le bleu foncé dont le porteur ne veut plus.

## 3. Règles d'implémentation

### 3.1 Structure (390 px d'abord)

```
#student_home
├── header.student-band            bandeau, fond brand, hauteur ≈ 96 px
│   ├── avatar (bouton du menu)    à gauche, 48 px, fond white, initiales brand-strong
│   └── lien « Besoin d'aide ? »   à droite, icône casque + texte, couleur band-ink, pas de pastille
├── section#student_next_step      la carte, débord de ≈ 40 % sur le bandeau
├── nav#student_subjects           grille 4 colonnes, 7 cases (6 matières + Inviter)
├── section#student_announcements  carrousel existant (une carte visible, points)
└── section#student_history        « Historique », groupé par jour, 3 lignes + « Voir plus »
```

- La feuille blanche (`bg-paper`, coins supérieurs `rounded-t-sheet`) commence à mi-hauteur de la carte : le bandeau ne descend pas plus bas.
- Sur ordinateur (≥ lg) : colonne centrée de `max-w-form` à côté de la barre latérale actuelle. Le bandeau de la colonne n'affiche ni avatar ni aide, déjà présents dans la barre du haut. La barre latérale perd sa carte profil (l'avatar de la barre du haut suffit).
- Partiels à créer sous `app/views/classroom/student_homes/` : `_band`, `_next_step` (un partiel par état sous `next_step/`), `_subjects` (réécrit), `_history` (remplace `_recent_activity`). Supprimer `_classroom_card` et `_todo` de l'accueil ; `_pending_gaps` part dans Ma classe (§4).

### 3.2 La carte `#student_next_step`

Carte `bg-white`, bordure `border-line`, `rounded-card`, `shadow-card`, padding 20 px, deux colonnes :

| Colonne gauche (de haut en bas) | Colonne droite |
|---|---|
| 1. Lien de classe « 3E B · CM1T › » : 12 px, majuscules, `text-brand-strong`, zone tactile ≥ 44 px, vers `student_classroom_path`. Sigle de l'établissement, ou nom abrégé s'il n'en a pas | Icône de la matière, 88 px, sur un rond `bg-brand-soft` |
| 2. Titre : 18 px, graisse 500, `text-ink` | |
| 3. Méta : « Maths · M. Kouassi · 15 min », 13 px, `text-mute` | |
| 4. Pastille d'échéance (`ui_badge`) | |
| 5. Progression : « 4 exercices faits sur 6 » 13 px + barre (piste `bg-line`, remplissage `bg-brand`) | |
| 6. Bouton principal `ui_button variant: :primary`, 44 px, pleine largeur sur la colonne | |

Petit logo Lnclass discret, 18 px, en bas à droite de la carte, dans les états 1 à 3 seulement.

### 3.3 Les six états — règle de priorité

L'état se calcule dans la query de l'accueil, dans cet ordre ; le premier vrai gagne.

| # | Condition | Lien de classe | Titre | Pastille | Ligne en plus | Bouton |
|---|---|---|---|---|---|---|
| 6 | L'élève n'a pas de classe | — | « Choisis ta classe » | — | « Entre le code donné par ton enseignant. » + champ code + lien « Je n'ai pas de code » | « Rejoindre ». **Grille, annonces et historique masqués** |
| 2 | Au moins un exercice assigné non terminé dont l'échéance est passée | oui | Le plus ancien en retard | « En retard · jeudi 8 oct. » (`warning`) | « Et N autres en retard › » vers Ma classe, si N ≥ 1 | « Le faire maintenant » |
| 1 | Au moins un exercice assigné non terminé | oui | Celui dont l'échéance est la plus proche | « À rendre samedi » (`brand-soft` / `brand-strong`) | — | « Commencer l'exercice », ou « Reprendre » si une session est en cours |
| 3 | Tout l'assigné est terminé et au moins une fiche à revoir est en attente | oui | La plus ancienne fiche à revoir | « À revoir » (`brand-soft`) | « Tu as eu 8/20. Relis la fiche, puis refais un exercice. » | « Revoir la fiche », vers la fiche de révision |
| 4 | Des exercices ont été assignés, tous sont terminés, aucune fiche à revoir | oui | « Tout est fait ! » (libellé 12 px « BRAVO ») | — | « 6 exercices faits sur 6 cette semaine » + bloc secondaire « Exercice du jour » (titre, matière, durée) | « Faire l'exercice du jour » (`secondary`) |
| 5 | Aucun exercice assigné dans les classes de l'élève | oui | Exercice du jour | « Exercice du jour · Lnclass » | lien « Ton enseignant n'est pas sur Lnclass ? Invite-le › » | « Commencer » |

- **Changement de règle à noter :** aujourd'hui l'exercice du jour n'est calculé que si l'élève n'a **aucun** exercice assigné. L'état 4 le demande aussi quand tout l'assigné est terminé. Le calcul de l'exercice du jour garde ses candidats et son tour des matières ; seule la condition d'appel change.
- Si l'exercice du jour est déjà fait aujourd'hui (états 4 et 5), le bloc dit « Exercice du jour fait. Reviens demain ! » sans bouton.

### 3.4 Grille des matières

- 4 colonnes, rond de 56 px **`bg-brand-soft` pour toutes les cases**, illustration en couleur, libellé 13 px `text-ink` sous le rond, nom complet (« Physique-Chimie », « Histoire-Géo »), deux lignes au plus.
- 7 cases : les 6 matières de la classe, puis « Inviter » (partage Lnclass, comportement actuel). Pas de case « Paiement ». Une 8ᵉ case vide n'est pas comblée.
- Une matière avec un exercice en retard porte un point `warning-dot` de 10 px en haut à droite du rond, et son libellé accessible se termine par « , exercice en retard » (clé existante).

### 3.5 Annonce et Historique

- Annonces : le carrousel existant (`communication/messages/_carousel`), carte `bg-brand-soft`, section `bg-mist`. Il n'affiche que les annonces de l'équipe Lnclass et de la direction (les annonces des enseignants sont masquées pour le pilote).
- Historique : titre 16 px graisse 500 ; sous-titres de jour 12 px majuscules `text-mute` (« AUJOURD'HUI », « HIER », puis la date) ; ligne = rond `bg-brand-soft` 40 px + titre 14 px + méta 13 px + note à droite. Une note de 14/20 ou plus est en `text-success`, les autres en `text-ink` ; **jamais de rouge**. Une fiche lue dit « Lue ». Un exercice sous 10/20 porte un bouton `secondary` « Refaire ». « Voir plus » (bouton `secondary` pleine largeur) mène à Mon historique.
- Le frame différé actuel (`student_home_recent_activity`) est gardé pour l'historique.

### 3.6 Jetons

Couleurs, tailles et graisses : uniquement les jetons de l'UDR-XXXX-palette-froide-et-texte-sans-gras. Rien en dur (le test `test/design/design_tokens_test.rb` refuse les codes hexadécimaux et les valeurs arbitraires). Pas de `font-bold` ni de `font-semibold` : graisse 500 au plus, sur les titres.

### 3.7 États obligatoires

- **Vide** : états 5 et 6 de la carte ; Historique vide : « Tes exercices terminés s'afficheront ici. » (13 px `text-mute`), sans bouton « Voir plus ».
- **Chargement** : l'historique arrive par le frame différé, avec un squelette de 3 lignes (`bg-mist`).
- **Erreur** : si le frame de l'historique échoue, la ligne « Impossible de charger l'historique. Réessayer » (lien qui recharge le frame). Le code de classe faux (état 6) affiche l'erreur sous le champ (`aria-describedby`).
- **Succès** : les états 1 à 4.

### 3.8 Accessibilité

- Cibles tactiles ≥ 44 px, y compris le lien de classe et les points du carrousel (zone invisible étendue).
- Contrastes vérifiés : `band-ink` sur `brand` 5,26:1 ; `mute` sur blanc 5,93:1 ; `brand-strong` sur `brand-soft` 4,75:1 ; `warning` sur `warning-soft` 6,17:1. Aucun texte blanc sur `brand`.
- Le bandeau est un `header` ; la carte est une `section` avec `aria-labelledby` pointant sur son titre ; la grille est une `nav` avec `aria-label="Mes matières"`.
- Ordre de tabulation : avatar → aide → lien de classe → bouton de la carte → grille → annonce → historique.
- Minimum 12 px partout.

## 4. Conséquences

- **Ma classe** porte désormais la liste complète du travail et accueille la section « Fiches à revoir » après « Exercices assignés » (UDR des écrans élève épurés).
- La pastille « 3e B › » sous l'avatar et la lune de l'en-tête disparaissent ; le mode sombre est dans le menu de l'avatar.
- Interdit sur l'accueil élève : un deuxième bouton principal, une liste d'exercices, une barre basse, du texte blanc sur le bandeau, du rouge sur une note.
- Retour arrière : la carte et l'ancien accueil ne cohabitent pas. Un retour se fait en revenant au commit précédent, pas par un interrupteur (porteur, 2026-10-23).
