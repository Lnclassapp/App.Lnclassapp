# Journal — [Titre du chantier]

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |

## Retouches

> Format : `- AAAA-MM-JJ · #<PR> · <ce qui change, en une phrase>`

- 2026-11-12 · #547 · Une seule version de l'accueil (capture 5 du porteur) : la photo des deux élèves de la maquette, recadrée sans le filigrane et éclaircie (`students.webp`, 40 Ko), le macaron étoilé « De la 6ème à la Terminale, même sans internet » en haut à droite, les téléphones visibles au-dessus de la feuille à 320 et 390 px, la photo qui ne passe plus sous la feuille sur ordinateur ; `student.webp` et `student-portrait.webp` retirés.
- 2026-11-12 · #PR · Sur ordinateur, la feuille blanche passe de 7/12 à la moitié de l'écran, sans bord arrondi, et la photo ne passe plus sous elle : l'élève de gauche est entier (demande du porteur).

## À trancher

- **Pourquoi quatre versions ?** Le code n'en a qu'une : aucune condition (application installée, user-agent, PWA, Stimulus, cache). Les captures 3 et 4 (ligne « application mobile », voile sombre, poignée) sont des maquettes (`interface-epuree/maquettes/homepage-telephone.html` et ses variantes), pas l'application. L'application, elle, montrait une seule élève et une pastille « Même sans internet ». Rien à corriger côté comportement.
- **Bleu du macaron** : tranché par le porteur (2026-11-12) : le bleu clair `brand` (#00a0ff), comme à l'UDR-0059 §3, avec « 6ème » en `ink`. Le reste du texte, blanc et gras, n'est qu'à 2,8:1 sur ce bleu, sous le minimum de 3:1 pour un texte large : c'est le choix du porteur, il est écrit ici.
- **Éclairage** : appliqué dans l'image (luminosité + 20 %, contraste + 5 %), pas en filtre CSS : plus léger et identique partout.
- **Macaron sur ordinateur** : posé aussi sur la photo, en haut à droite ; la pastille de la colonne de texte disparaît (une seule version).
- **Taille de la retouche** : 4 fichiers hors tests (vue, locale, feuille de style pour deux utilitaires `home-photo` / `home-badge` qu'exige le garde des valeurs arbitraires, photo), un de plus que la limite d'une retouche ; aucune règle ni droit touché.
- **Cadrage à 320 px** : le macaron touche le haut de la tête de l'élève de droite ; les deux visages et les deux téléphones restent visibles.
