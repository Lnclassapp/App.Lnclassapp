# Memo — Carrousel des classes de l'enseignant : revenir vers la gauche sur ordinateur

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré |
| **Ouvert le** | 2026-10-30 |
| **Branche** | `fix/carrousel-classes-enseignant` |
| **Programme** | — |

---

## Symptôme

Le porteur, sur ordinateur, à l'accueil enseignant : « on peut faire défiler le carrousel des classes vers la droite, mais pas revenir vers la gauche ».

## Reproduction

1. Enseignant rattaché à 5 classes, accueil (`/teacher`), fenêtre de 1280 px, souris.
2. La molette (verticale) ne bouge pas la bande ; aucune barre de défilement (`scrollbar-none`) ; aucun bouton.
3. Tab avance dans les cartes, coupées à droite, et fait défiler la bande vers la droite. À la souris, plus aucune carte n'est à moitié visible à gauche : rien ne ramène au début.

Mesuré dans Chrome (Selenium, 1280 px) avant correctif : molette verticale `scrollLeft` 0 → 0 ; défilement horizontal (trackpad) 0 → 552 → 0 ; aucun `button` hors « Copier ».

## Portée

- Depuis la bande en carrousel de l'accueil enseignant (UDR enseignant §3.3, « Sur ordinateur »).
- Tous les enseignants à 4 classes ou plus sur ordinateur sans trackpad. Téléphone non touché (le doigt défile).
- Aucune donnée écrite : rien à réparer.

## Hors périmètre

- Les autres bandes du contrôleur `communication--carousel` (annonces, cours de « Ma classe ») : elles n'ont pas de cibles `previous` / `next` et ne changent pas. Les y ajouter : chantier de suivi si le porteur le demande.
- Les points du pager restent décoratifs (non cliquables).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quel document dit le comportement attendu ? | Aucun : UDR enseignant §3.3 décrit une bande à défiler sans dire comment à la souris | UDR-0143 |
| Un autre carrousel a-t-il déjà des boutons à réutiliser ? | Non : les quatre bandes partagent `communication/carousel_controller.js`, sans navigation | Cibles facultatives `previous` / `next` ajoutées au contrôleur partagé, pas de second contrôleur |
| Multi-appartenance, autres acteurs ? | Sans objet : rendu seul, aucune règle métier | — |

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [x] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [x] Test au vert · suite du contexte borné au vert
- [x] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [x] Données déjà corrompues : réparées, ou dette explicitement notée au journal
- [x] Challenger a rejoué les étapes de reproduction dans l'application
- [x] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés
