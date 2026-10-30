# Journal — Leçons de 3ème en SVT, Physique-Chimie, Histoire-Géographie, Français et EDHC, et leurs figures

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-30 | L'UDR des figures prend le slug `dessin-des-figures-de-3eme`, distinct de celui de l'ADR | `script/docs/build_index --number` refuse un ADR et une UDR de même slug | Non (ADR-0117, UDR-0142) |

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
| `geometry_errors` a une boucle non bornée (`ids.count` dans la boucle, sans garde de taille) | Code d'une autre vague, hors périmètre de la vague 4 | À ouvrir : `validation-figures-bornee` |
| Relecture des 8 planches de SVT et des points « à faire valider » des 10 leçons (vocabulaire, valeurs données en exemple) par un enseignant de SVT | Hors de portée d'un agent | Avant publication ; captures envoyées au porteur |
| Relecture des 3 planches de PC et des chiffres des 10 leçons par un enseignant de Physique-Chimie | Hors de portée d'un agent | Avant publication |
| Relecture par un enseignant de Français : faits d'œuvre (L4), décompte des mots (L7), pronoms à l'impératif et participes (L8, L9), barèmes | Aucun enseignant disponible | Liste dans `docs/contenus/README.md`, section 3ème Français |
| Relecture par un enseignant d'EDHC : renvois aux textes, Croix-Rouge (L2), juridictions (L5, L6), taxe et redevance (L7), carte des alliances (L10) | Aucun enseignant disponible | Liste dans `docs/contenus/README.md`, section 3ème EDHC |
| `valider.rb` ne contrôle ni `statement_blocks` ni les clés inconnues du cours, de la notion, de l'exemple et de l'exercice, que l'import refuse | Défaut antérieur au programme | À ouvrir : parité complète du contrôle avec le schéma v3 |
| Le contrôle n'avertit ni d'un `*` ou d'un `**` dans un énoncé ou une question, ni d'une correction qui désigne une proposition par sa position (« les trois premières »), alors que l'application mélange les propositions | Hors périmètre des vagues 1 et 5 | À ouvrir : avertissements du contrôle |
| À 390 px, le texte des figures fait ~10 px : le plafond de `--figure-text` (1,4) de `figure_controller` n'a pas été revu ; flèche diagonale du schéma `flow` non traitée | Fichier partagé par toutes les sortes | À ouvrir : chantier UI des figures (même suivi que les deux lignes suivantes) |
| Libellés longs d'abscisse d'une courbe coupés à 390 px (contournés dans les leçons de SVT) ; marge du libellé de curseur à 390 px | Code partagé des vagues 2 et 4 | Chantier UI des figures |
| Couverture 100 % lignes et branches non mesurée par fichier (SimpleCov mélange les processus) | Outillage | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-30 (fusion dans `Develop` ; la production attend le train `Staging` → `main`) |
| **PR** | [#373](https://github.com/Lnclassapp/App.Lnclassapp/pull/373) Français · [#374](https://github.com/Lnclassapp/App.Lnclassapp/pull/374) Histoire-Géographie · [#375](https://github.com/Lnclassapp/App.Lnclassapp/pull/375) EDHC · [#376](https://github.com/Lnclassapp/App.Lnclassapp/pull/376) SVT · [#377](https://github.com/Lnclassapp/App.Lnclassapp/pull/377) Physique-Chimie |
| **ADR produits** | [ADR-0117](../../decisions/adr/0117-figures-des-matieres-de-3eme.md) — figures des matières de 3ème (amende ADR-0116 §4.2) |
| **UDR produits** | [UDR-0142](../../decisions/udr/0142-dessin-des-figures-de-3eme.md) — dessin des figures des matières de 3ème |

50 leçons rangées dans `docs/contenus/lecons-traitees/3eme/{francais,histoire-geographie,svt,physique-chimie,edhc}/`, 10 par matière ; toutes passent `script/contenus/valider.rb`. Les journaux des 5 vagues gardent le détail ; la dette ci-dessus les reprend.
