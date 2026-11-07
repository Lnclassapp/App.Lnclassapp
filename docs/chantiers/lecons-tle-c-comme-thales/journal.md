# Journal — Les leçons de Terminale C préparées comme Thalès

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-05 | Même méthode que la 3ème : un rédacteur par leçon écrit ses ajouts hors dépôt, un script les fusionne dans la version de `Develop` et contrôle tout | Le cours, les fiches et les 4 problèmes restent identiques octet pour octet | Non |
| 2026-11-05 | En mathématiques, chaque question est prouvée par sympy ; aucune preuve par extrait | Toutes les réponses sont des calculs | Non |
| 2026-11-05 | Une relecture indépendante de chaque leçon, par un agent qui ne l'a pas écrite, avant son commit | Les trois premières relectures (commentaire de texte, « Dieu et la religion », dissertation littéraire) ont chacune trouvé des défauts que le script ne voit pas | Non |
| 2026-11-05 | Une leçon de Tle C dont la même fiche existe dans un autre dossier de Terminale n'est modifiée qu'ici | Décision 6 de #484 : le chantier suivant reprend les ajouts depuis le fichier de Tle C | Non |

## Ce qui a dérapé

- **sympy 1.14 se trompe sur les limites de puissances à base numérique** : `limit(3**x, x, -oo)` rend `oo`, `limit((1/2)**x, x, -oo)` rend `0`. Une preuve a donc validé une limite fausse aux exponentielles. Correctif dans l'outil de preuve : toute limite passe par `a**u = exp(u ln a)`. Les 10 leçons de mathématiques ont été recontrôlées après ce correctif.
- **Réponse faussée qui retombe sur la bonne valeur** : pour −1, la valeur faussée `2v + 1` redonnait −1. Le script décale maintenant la valeur quand c'est le cas.
- **Faux positif du contrôle de rang** : « proposition d'action » était pris pour « proposition A ». Expression corrigée.
- **Rang non vu par le script** : « la première égalité », « la seconde », « les deux premières » échappent à l'expression ; ce sont les relecteurs qui les ont attrapés et réécrits.
- **Rédacteurs qui génèrent par script** : plusieurs ont écrit leurs JSON avec un petit générateur au lieu de fichier par fichier. Le contrôle porte sur le JSON produit ; les générateurs restent hors dépôt.
- **Develop a rangé la Tle C pendant le chantier** : le chantier `base-de-lecons` (2026-11-06) a déplacé les 45 fichiers vers `a-reprendre/` (36 en `sujets-manquants/`, 9 en `exercices-et-sujets-manquants/`). La fusion de Develop a suivi le déplacement sans conflit ; les 45 fichiers fusionnés étaient identiques octet pour octet aux fichiers contrôlés. Ils sont revenus dans `lecons-traitees/tle-c/` selon la règle de retour de `a-reprendre/README.md` (format complet, `valider.rb` ✓).
- **Quota de la session** : une vingtaine d'agents (rédacteurs de physique-chimie et de SVT, relecteurs de mathématiques) se sont arrêtés en pleine tâche le 5/11 ; ils ont repris le 7/11 sans rien perdre.

## Ce qu'on a appris sur la codebase

- `script/contenus/valider.rb` ne valide toujours pas `subjects` ; le script hors dépôt le relance avec chaque sujet à la place des 4 problèmes (dette déjà notée par le chantier de 3ème).
- Le jeu standard nomme 5 leçons de Tle C, mais `standard_activity_test.rb` ne charge que 27 leçons (1ère et 3ème) : son empreinte reste `f1defa0fb0`. La plus longue leçon de Tle C fait 266 452 octets (Les alcools) : la clé `longue` de `db/seeds/standard/jeu.yml` reste `3eme/edhc/le-scrutin-electoral.json` (278 740 octets).
- Le contrôle de rang du script ne voit pas « la première », « les deux premières », « le second » : les relecteurs en ont réécrit plus de 150 dans les 45 leçons. Une relecture indépendante trouve aussi ce que l'extrait mot pour mot ne juge pas : fill_blank à plusieurs réponses, appariements à deux lectures, affirmation prêtée à un texte qui ne la contient pas.

## Fichiers communs avec d'autres dossiers (non modifiés ici)

Même fiche dans un autre dossier de Terminale ; le chantier suivant (Tle D, puis Tle A1 et A2) reprend les mêmes ajouts — 2e exercice et sujets — depuis le fichier de Tle C (décision 6 de #484).

- **Français** (6) : les 6 leçons, même fiche en `tle-a1`, `tle-a2` et `tle-d`.
- **Philosophie** (9) : les 9 leçons, même fiche en `tle-a1`, `tle-a2` et `tle-d`.
- **Mathématiques** (5) : dérivabilité et étude de fonctions, fonctions logarithmes, limites et continuité, nombres complexes, primitives — même fiche en `tle-d`.
- **Physique-chimie** (8) : acides carboxyliques, cinématique du point, composés carbonylés, fabrication d'un savon, les alcools, mouvement du centre d'inertie, mouvements dans les champs g et E, oscillations mécaniques libres — même fiche en `tle-d`.
- **SVT** (3) : l'infection par le VIH, la transmission d'un caractère héréditaire, le système de défense — même fiche en `tle-d`.
- Homonymes qui sont d'autres leçons (rien à reprendre) : dérivabilité (1ère A1, A2), limites (1ère C, D), production d'énergie et cycles sexuels (1ère A1, A2), commentaire composé et résumé (1ère) ; œuvre narrative et résumé ont des copies v1 en 2nde.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `valider.rb` ne contrôle pas les sujets (déjà noté en 3ème) | Le chantier ne touche que du contenu | À ouvrir |

## À trancher

- **Lectures graphiques sans tolérance** : comme en 3ème, une valeur lue sur une construction est en `numeric` avec `tolerance` 0 quand la valeur est entière. Option prudente appliquée : laisser tel quel. Option possible : une tolérance d'une demi-unité.
- **Valeurs illustratives** : les données chiffrées des énoncés (mesures, effectifs, prix, résultats d'expérience en SVT et physique-chimie) sont inventées et présentées comme des exemples. Un enseignant relit avant publication.
- **Jeu standard** : la règle de retour dit d'ajouter une leçon revenue à `db/seeds/standard/jeu.yml` pour que le jeu standard la charge. Option prudente appliquée : ne pas l'ajouter ici (le chantier ne touche que du contenu et l'empreinte du jeu reste celle de Develop). Option possible : une retouche qui ajoute la Tle C à `jeu.yml`.
- **Oral du bac (Français)** : les textes d'appui reprennent Birago Diop (1947) et Bernard Dadié, « Climbié » (1956), sur le modèle de la 3ème.

## Avancement

### Mathématiques — 10 leçons

Preuve : sympy sur chaque question ; chaque réponse faussée exprès est détectée. Aucune figure ajoutée. Relecture indépendante de chaque leçon.

| Leçon | Questions | Vérifications | Réponses faussées détectées | Défauts de fond corrigés (rédaction + relecture) |
|---|---:|---:|---:|---:|
| Barycentre et lignes de niveaux | 121 | 4 665 | 121/121 | 3 + 0 |
| Coniques | 111 | 4 238 | 111/111 | 0 + 0 |
| Dérivabilité et étude de fonctions | 112 | 4 391 | 112/112 | 2 + 0 |
| Divisibilité dans ℤ | 104 | 3 970 | 104/104 | 1 + 3 |
| Fonctions exponentielles et puissances | 110 | 4 573 | 110/110 | 2 + 0 |
| Fonctions logarithmes | 119 | 4 723 | 119/119 | 0 + 2 |
| Géométrie analytique de l'espace | 104 | 4 065 | 104/104 | 0 + 3 |
| Limites et continuité | 114 | 4 539 | 114/114 | 0 + 2 |
| Nombres complexes | 118 | 4 769 | 118/118 | 0 + 3 |
| Primitives | 106 | 4 360 | 106/106 | 0 + 5 |
| **Total** | **1 119** | **44 293** | **1 119/1 119** | **8 + 18** |

Exemples de défauts de fond trouvés : 14 multiples de 7 entre 100 et 200 et non 15 (divisibilité) ; une limite fausse validée par le défaut de sympy (exponentielles) ; deux questions de logarithmes qui reprenaient l'exercice d'application de la leçon ; un encadrement « 1,4 < α < ___ » qui admettait plusieurs bornes (limites) ; une explication qui donnait $-2/x^3+3$ pour la dérivée de f (primitives). Les relecteurs ont aussi réécrit 47 corrections qui désignaient une proposition par son rang.


### Français — 6 leçons

Pas de calcul sauf comptages : questions corrigées automatiquement seulement ; chaque bonne réponse justifiée par un extrait mot pour mot de la leçon, ou par du code pour 31 questions chiffrées (oral, résumé). Aucune figure. Relecture indépendante de chaque leçon.

| Leçon | Questions | Vérifications | Erreurs au 1er passage | Défauts de fond (relecture) |
|---|---:|---:|---:|---:|
| Groupement de textes théâtraux | 105 | 4 737 | 20 | 3 |
| La dissertation littéraire | 105 | 4 759 | 6 | 5 |
| Le commentaire composé | 104 | 4 914 | 5 | 1 |
| Œuvre narrative | 104 | 4 782 | 7 | 7 |
| Préparation à l'oral du baccalauréat | 106 | 4 595 | 1 | 11 |
| Résumé du texte argumentatif | 104 | 4 553 | 4 | 3 |
| **Total** | **628** | **28 340** | **43** | **30** |

Défauts de fond typiques trouvés en relecture : fill_blank qui admettaient plusieurs mots (6 à l'oral), appariements ambigus (métaphore/hyperbole), corrections qui citaient une proposition absente, résumés « corrects » qui recopiaient le texte.

### Philosophie — 9 leçons

Uniquement les auteurs, thèses et citations de la leçon d'origine ; questions corrigées automatiquement seulement ; chaque bonne réponse justifiée par un extrait mot pour mot de la leçon (8 comptages prouvés par code). Aucune figure. Relecture indépendante de chaque leçon.

| Leçon | Questions | Vérifications | Erreurs au 1er passage | Défauts de fond (relecture) |
|---|---:|---:|---:|---:|
| Dieu et la religion | 106 | 4 860 | 2 | 8 |
| La connaissance de l'homme | 105 | 4 880 | 0 | 2 |
| La connaissance scientifique | 107 | 4 778 | 1 | 0 |
| La dissertation philosophique | 105 | 4 782 | 3 | 4 |
| La valeur de la philosophie | 116 | 5 345 | 0 | 3 |
| La vie en société | 104 | 4 586 | 6 | 2 |
| Langage et vérité | 113 | 5 175 | 1 | 9 |
| Le commentaire de texte philosophique | 107 | 5 099 | 18 | 5 |
| Progrès et bonheur | 104 | 4 822 | 2 | 5 |
| **Total** | **967** | **44 327** | **33** | **38** |

Défauts de fond typiques : affirmation prêtée à un personnage ou à un texte qui ne la contient pas ; ordre de citation dans la leçon confondu avec l'ordre chronologique (Towa/Hountondji) ; ordering non défendable par la fiche ; matching à deux lectures.

### Physique-chimie — 10 leçons

Chaque question de calcul prouvée par sympy (720), les questions de cours par un extrait mot pour mot de la leçon (374) ; chaque réponse chiffrée faussée exprès est détectée. Aucune figure ajoutée ; quelques exercices citent une figure existante de la leçon qui montre exactement leur situation. Relecture indépendante de chaque leçon.

| Leçon | Questions | Vérifications | Calculs prouvés (faussés détectés) | Erreurs au 1er passage | Défauts de fond (relecture) |
|---|---:|---:|---:|---:|---:|
| Acides carboxyliques et dérivés | 104 | 3 951 | 80 (80/80) | 3 | 1 |
| Champ magnétique | 109 | 4 259 | 65 (65/65) | 2 | 0 |
| Cinématique du point | 104 | 3 661 | 89 (89/89) | 0 | 0 |
| Composés carbonylés | 110 | 4 568 | 34 (34/34) | 4 | 5 |
| Fabrication d'un savon | 115 | 4 268 | 67 (67/67) | 118 | 0 |
| Interaction gravitationnelle | 104 | 3 799 | 83 (83/83) | 2 | 2 |
| Les alcools | 116 | 4 695 | 41 (41/41) | 4 | 8 |
| Mouvement du centre d'inertie | 104 | 3 725 | 82 (82/82) | 0 | 4 |
| Mouvements dans les champs g et E | 113 | 4 116 | 89 (89/89) | 1 | 0 |
| Oscillations mécaniques libres | 115 | 4 343 | 90 (90/90) | 0 | 3 |
| **Total** | **1 094** | **41 385** | **720 (720/720)** | **134** | **23** |

Les 118 erreurs du savon au 1er passage venaient d'une seule faute du générateur du rédacteur (une clé de forme répétée sur chaque question). Défauts de fond typiques : questions des alcools qui renvoyaient à « flacon 2 » sans en redonner les données ; demi-équation expliquée par un mauvais bilan d'atomes (carbonylés) ; distracteur « acide carboxylique » ambigu au test à la DNPH, remplacé par un alcool ; explication qui jugeait 13 m/s² « absurde » alors qu'une accélération vers le haut peut dépasser g.

### SVT — 10 leçons

Questions corrigées automatiquement seulement, sans formule ; calculs (pourcentages, différences, probabilités génétiques) prouvés par du code (280), les autres par un extrait mot pour mot de la leçon (786). 7 figures ajoutées, sortes existantes seulement : 2 au VIH, 3 à la production d'énergie, 2 aux cycles sexuels ; leurs valeurs ont été relues contre les énoncés qui les citent. Relecture indépendante de chaque leçon.

| Leçon | Questions | Vérifications | Calculs prouvés (faussés détectés) | Erreurs au 1er passage | Défauts de fond (relecture) |
|---|---:|---:|---:|---:|---:|
| L'exploitation des gisements pétrolifères | 104 | 4 105 | 30 (30/30) | 3 | 0 |
| L'infection de l'organisme par le VIH | 116 | 5 039 | 14 (14/14) | n. c. | 3 |
| L'utilisation de l'énergie par la cellule musculaire | 108 | 4 236 | 38 (38/38) | 0 | 2 |
| La communication nerveuse | 111 | 4 476 | 29 (29/29) | 0 | 0 |
| La mise en place des gisements pétrolifères en Côte d'Ivoire | 106 | 4 375 | 34 (34/34) | 4 | 1 |
| La production d'énergie par la cellule | 104 | 4 048 | 45 (45/45) | 8 | 0 |
| La transmission d'un caractère héréditaire chez l'homme | 99 | 4 187 | 28 (28/28) | 0 | 0 |
| Le système de défense de l'organisme | 110 | 4 825 | 13 (13/13) | 5 | 3 |
| Les cycles sexuels chez la femme | 104 | 4 393 | 34 (34/34) | 1 | 2 |
| Les drogues et le système nerveux | 104 | 4 507 | 15 (15/15) | 3 | 0 |
| **Total** | **1 066** | **44 191** | **280 (280/280)** | **24+** | **11** |

n. c. : le rédacteur du VIH, interrompu par le quota, n'a pas noté son premier passage. En transmission héréditaire, le relecteur a remplacé par un calcul trois vérités écrites à la main dans la preuve (échiquiers). Défauts de fond typiques : fill_blank qui admettait aussi « œstradiol » (cycles) ; matching où trois cellules « sans CD4 » se confondaient (VIH) ; fermentation lactique prêtée à un footing de 2 h à allure modérée (énergie musculaire).

## Clôture

45 leçons, 5 matières, un commit par matière. Chaque notion a deux exercices, et chaque leçon 4 sujets de 4 exercices. Le cours, les fiches et les 4 problèmes sont inchangés, octet pour octet, ce que le script contrôle. Chaque fichier commité a le sha256 du fichier vérifié, relu au moment du commit. Le test de rendu (`lesson_rendering_test.rb`) passe sur les 45 fichiers ; `standard_manifest`, `standard_activity` et `pilot_lessons` sont verts.

| Matière | Questions ajoutées | Vérifications | Erreurs au 1er passage | Défauts de fond (rédaction + relecture) | Figures ajoutées | Preuve |
|---|---:|---:|---:|---:|---:|---|
| Mathématiques | 1 119 | 44 293 | 161 | 8 + 18 | 0 | sympy sur chaque question ; 1 119/1 119 réponses faussées détectées |
| Français | 628 | 28 340 | 43 | 0 + 30 | 0 | extraits ; 31 comptages par code |
| Philosophie | 967 | 44 327 | 33 | 0 + 38 | 0 | extraits ; 8 comptages par code |
| Physique-Chimie | 1 094 | 41 385 | 134 | 0 + 23 | 0 | sympy sur 720 calculs, tous faussés détectés ; extraits pour le cours |
| SVT | 1 066 | 44 191 | 24+ | 0 + 11 | 7 | extraits ; 280 calculs par code, tous faussés détectés |
| **Total** | **4 874** | **202 536** | **395+** | **8 + 120** | **7** | |
