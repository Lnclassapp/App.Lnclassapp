# Chantier — Amélioration UI/UX des pages élève

**Type :** feature · **Branche :** `feature/ux-pages-eleve` · **Cible :** `Develop`

Améliorer l'interface et l'expérience des pages de l'espace élève.

Le porteur modifie directement la codebase et transmet au fil de l'eau les points à traiter.
Chaque point est consigné ici, puis livré sur cette branche.

## Points à traiter

Plan par priorité de page, établi le 2026-10-06 sur les données de démo du Collège Saint Michel de Tiassalé
(`db/seeds/demo/saint_michel.rb`), à 360, 390 et 1280 px, avec un élève fort et un élève qui a des lacunes.
Gravité : **B** bloquant · **G** gênant · **F** finition.

| # | Page | Points | Gravité | Statut |
|---|---|---|---|---|
| 1 | Ma classe, Historique, Accueil | La page est plus large que l'écran (611 et 583 px à 360) : le navigateur dézoome tout. Une grille sans `minmax(0, 1fr)` prend la largeur des titres tronqués et du carrousel | B | Fait |
| 2 | Résultat de session | « Ton choix » éclate une proposition KaTeX en colonnes et perd les espaces (`li.flex` sans `span`) ; grille Note / Maîtrise décalée par l'ⓘ ; cadenas pour « Non acquis » ; « Non acquis » et « En difficulté » pour le même état ; aucune mention de la lacune notée ni lien vers la fiche | B, G | Fait (lacune : dette) |
| 3 | Session (question, correction) | Même défaut KaTeX dans la correction ; « Question suivante » sous le pli après une explication longue ; boutons petits et à droite ; barre du bas visible (mode focus à décider) | B, G | Fait |
| 4 | Exercice | Grille « Ta progression » décalée par les ⓘ ; fractions KaTeX vers 8 px ; formules coupées en milieu de ligne ; aucun accès aux passages précédents | G | Fait |
| 5 | Fiche | Titres d'exercice réduits à 13 caractères à côté de « Commencer » ; « Commencer » sur un exercice fait 6 fois ; bloc « Fiche à revoir » sans action ; formules coupées | G | Fait |
| 6 | Cours | Titres de fiche tronqués sur une ligne ; ni avancée ni lacune par fiche | G | Fait (avancée par fiche : dette) |
| 7 | Catalogue | 19 cours sur 4 560 px sans filtre sur téléphone (UDR-0077 §3.2) ; Leçon 2 avant Leçon 1 (tri par nom) ; aucune avancée sur la carte ; ⓘ isolée | G, F | Fait (ordre, avancée : dette) |
| 8 | Accueil (hors débordement) | Notes basses sur ambre ; « Besoin d'aide ? » isolé ; carte imbriquée ; titres « À faire » tronqués ; carrousel d'annonces peu lisible | G, F | Fait |
| 9 | Toutes | Pastilles (matière, échéance, type de question) en 11 px ; lien de retour tronqué ; barre latérale « Collège Saint Michel de Tiassa… » | G, F | Fait (retour tronqué : UDR-0054) |
| 10 | Aide, Accès interdit | Perdent la coquille de l'application une fois connecté ; liens de 18 px de haut | F | Aide : fait (UDR-0061, amendée). Accès interdit : au backlog (`erreurs-dans-le-shell`, décision du porteur du 2026-10-06) |
| 11 | Profil | Boutons d'action de 3 styles différents ; « vous » et « tu » mêlés | F | Fait (UDR-0041, amendée) |
| 12 | Annonces | Pas d'onglet dans la barre du bas (à décider) | F | Décidé : pas d'onglet |

### Deuxième passe — 2026-10-06, après la PR #186

Demande du porteur : sur l'Accueil, retirer « Tous les cours » et « Toutes les annonces » ; un bouton de retour sur
le catalogue filtré (`/courses?material=…`) et sur Ma classe ; puis fouiller toutes les pages élève.
Chaque point a d'abord été vérifié sur `Develop` (7f48b744) : ce que la PR #186 a déjà livré n'est pas refait.

| # | Page | Points | Gravité | Statut |
|---|---|---|---|---|
| 13 | Accueil | « Tous les cours » encore affiché dès 640 px (le point 8 ne l'a retiré que sur téléphone) ; « Toutes les annonces » sous le carrousel | G | Fait (UDR-0069 et UDR-0071, amendées) |
| 14 | Catalogue, Ma classe, Annonces | Aucun lien de retour : le seul chemin vers l'Accueil est la navigation | G | Fait (UDR-0054, amendée) |
| 15 | Cours | « Cours » (le retour) renvoie au catalogue sans son filtre (`?material=`) : l'élève reperd sa matière | G | Fait (UDR-0054, amendée) |
| 16 | Rejoindre une classe | « ton professeur » sur les écrans du code, « tes enseignants » partout ailleurs dans l'espace élève (glossaire : enseignant) | F | Fait (FAQ comprise) |
| 17 | Compte en attente | Aucun titre de page (`h1`) : le lecteur d'écran n'a pas de point d'entrée | F | Fait (`h1` pour lecteur d'écran) |

Déjà livrés par la PR #186, non refaits : débordement de Ma classe, de l'Accueil et de l'Historique (point 1) ;
grilles Note / Maîtrise décalées (points 2 et 4) ; ⓘ du catalogue isolée (point 7) ; « vous » du profil (point 11) ;
retour de l'Aide vers l'accueil du rôle (point 10).

Écartés, car déjà tranchés : « Essentielles de la leçon » (UDR-0007, amendement du 2026-09-30) ; « Entrer » sur la
carte de classe (UDR-0010).

À décider par le porteur, non faits : « Mon historique » n'est lié que depuis l'écran d'attente, pas pour l'élève qui
a une classe ; « Exercice : Exercice 2 de Fiche… » sur le résultat, quand le titre de l'exercice commence lui-même par
« Exercice ».
