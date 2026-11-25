# Memo — Accueil élève : « Inviter » et « Plus » dans la grille

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-11-24 |
| **Branche** | `feature/accueil-eleve-grille-plus` |
| **Programme** | — |

---

## Le problème

Sur le téléphone, l'accueil de l'élève a deux grilles : « Mes matières », puis une section à part « Invite tes camarades » avec une seule case. Wave, la référence choisie par le porteur, n'a qu'une grille de 8 cases dont la dernière, « Plus », ouvre le reste. Chez nous, la section à part coûte une rangée et un titre, et les entrées à venir (abonnement, salle d'étude, Littera, Composa, devoirs CI) n'ont pas de place.

## Pour qui

L'élève, sur son accueil, au téléphone. Une classe a au plus 6 matières selon le niveau : avec « Inviter » et « Plus », la grille compte 8 cases, sur 2 rangées de 4.

## Pourquoi maintenant

Le porteur aligne l'accueil sur Wave (comparaison du 2026-11-24, retouches #688 à #690) ; c'est l'écart majeur qui restait, et il a tranché : « Inviter » et « Plus » complètent la grille.

## Hors périmètre

- Les écrans derrière les cases de « Plus » (salle d'étude, Littera, Composa, devoirs CI) : le porteur demande de **placer les icônes seulement**.
- « Plus » sur ordinateur : pas de case « Plus » sur les écrans larges (décision du porteur).
- L'accueil de l'enseignant et de la direction.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Que contient « Plus » ? (porteur, 2026-11-24) | S'abonner, Salle d'étude, Littera, Composa, Devoirs CI, et d'autres à venir ; 4 icônes par ligne ; placer les icônes seulement | La feuille « Plus » est une grille de 4 colonnes, au même format que les matières ; ses entrées sont une liste fixe, ajoutée sans migration |
| Comment s'ouvre « Plus » ? (porteur, 2026-11-24) | Une carte de 25 % de la hauteur, qui monte du bas | Motif nouveau sur l'accueil : il faut une UDR (amendement de l'UDR-0173 et d'accueil-eleve-qr-fenetre-inviter §3.3) |
| Combien de cases ? (porteur, 2026-11-24) | Au plus 6 matières selon le niveau, puis « Inviter » et « Plus » : 8 | La section « Invite tes camarades » disparaît, sa tuile entre dans la grille |
| Que fait une icône dont l'écran n'existe pas encore ? (porteur, 2026-11-24) | Elle a l'air normale ; un toucher affiche un court message « Bientôt disponible » | Chaque entrée de « Plus » porte une destination ou rien ; sans destination, un message annoncé (aria-live), jamais un lien mort. « S'abonner » mène à la page Abonnement existante |
| Sur ordinateur, sans case « Plus », par où passe l'élève ? (porteur, 2026-11-24) | Par le menu de gauche | Les entrées de « Plus » rejoignent le menu de gauche dès lg ; une seule liste d'entrées nourrit la feuille et le menu, pour qu'ils ne divergent jamais. « Inviter » reste une tuile de la grille sur ordinateur |
| Élève sans classe : que montre la grille ? (porteur, 2026-11-24) | Les matières de son dernier niveau et « Plus », sans « Inviter » | « Inviter » dépend de la classe, « Plus » non ; deux conditions distinctes à tester |

## Cas limites identifiés

- Moins de 6 matières (une seule, en Tle D du jeu réduit) : « Inviter » et « Plus » suivent la dernière matière, sans case vide entre elles.
- Aucune matière : la grille garde « Inviter » et « Plus » ; la phrase actuelle « aucune matière » reste sous la grille.
- Plus de 6 matières (un niveau futur) : la grille garde la limite actuelle de matières affichées ; « Inviter » et « Plus » restent les deux dernières cases.
- Élève sans classe : matières + « Plus », sans « Inviter » (réponse du porteur).
- Coque Android : même grille ; la feuille s'ouvre de la même façon.
- Ordinateur : pas de « Plus » ; ses entrées sont dans le menu de gauche ; « Inviter » reste dans la grille.
- Entrée sans écran : message « Bientôt disponible », jamais un lien mort ni une page 404.
- Lecteur d'écran : « Plus » est un bouton qui ouvre une fenêtre nommée ; chaque entrée est nommée ; le message « Bientôt disponible » est lu.

## Questions encore ouvertes

- **Hauteur de la carte « Plus »** (réversible, option prudente appliquée) : 25 % de l'écran au moins, elle grandit avec ses entrées jusqu'à la moitié de l'écran puis défile ; à 5 entrées (2 rangées), 25 % de 844 px (211 px) ne suffit pas pour le titre et deux rangées.
- **Pictogrammes des entrées** (réversible, option prudente appliquée) : pictogrammes du jeu d'icônes existant sur pastille pastel, en attendant des illustrations dédiées.
