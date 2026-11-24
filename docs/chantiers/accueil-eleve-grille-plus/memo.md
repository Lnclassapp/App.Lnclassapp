# Memo — Accueil élève : « Inviter » et « Plus » dans la grille

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
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

## Cas limites identifiés

- …

## Questions encore ouvertes

- …
