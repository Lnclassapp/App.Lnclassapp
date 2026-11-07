# Journal — Les leçons de Terminale A1 préparées comme Thalès

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-07 | Les 15 leçons dont la fiche est la même qu'en Tle C et D reprennent tels quels les ajouts de Tle C, recontrôlés par le script sur le fichier de Tle A1 | Décision 6 de #484 : une fiche commune n'est traitée qu'une fois | Non |
| 2026-11-07 | « Suites numériques » est traitée comme propre à la Tle A1 | Sa fiche diffère de celle de Tle D (254 écarts) | Non |
| 2026-11-07 | Même méthode qu'en Tle C et D pour les 17 leçons propres : un rédacteur par leçon hors dépôt, script de contrôle, relecture indépendante de chaque question | Les relectures de Tle D avaient trouvé 31 défauts de fond que le script ne voyait pas | Non |
| 2026-11-08 | Le jeu standard charge une leçon de Tle A1 par matière (manifeste : 20 couples) | `StandardTestSet` exige une ligne par couple qui a du v3 | Non |

## Leçons reprises de Tle C (15, non réécrites)

Ajouts repris du chantier [`lecons-tle-c-comme-thales`](../lecons-tle-c-comme-thales/journal.md#fichiers-communs-avec-dautres-dossiers-non-modifiés-ici), déjà repris en Tle D ([`lecons-tle-d-comme-thales`](../lecons-tle-d-comme-thales/journal.md)), même script, 0 erreur sur chaque fichier de Tle A1 :

- **Français** (6) : groupement de textes théâtraux, dissertation littéraire, commentaire composé, œuvre narrative, préparation à l'oral du baccalauréat, résumé du texte argumentatif.
- **Philosophie** (9) : Dieu et la religion, la connaissance de l'homme, la connaissance scientifique, la dissertation philosophique, la valeur de la philosophie, la vie en société, langage et vérité, le commentaire de texte philosophique, progrès et bonheur.

## Ce qui a dérapé

- **Valeurs approchées sans tolérance** (fonction exponentielle) : 11 réponses `numeric` approchées avaient une tolérance 0, si bien que 13,86 était refusé quand la réponse arrondie était 14. Le relecteur a posé une tolérance ; un balayage de toutes les leçons n'a trouvé ailleurs que des valeurs exactes.
- **Énoncés incomplets** : ln 4 absent d'un énoncé qui en avait besoin (exponentielle), une question sur le volume crânien sans volume dans l'énoncé (lignée humaine), « la série » sans données (statistique), un énoncé muet sur l'attention alors que trois questions concluent dessus (activité cérébrale).
- **Personnages et textes trahis** : raisonnements prêtés à un élève fictif absents de l'énoncé (primitives, suites, réactions émotionnelles), « progrès » ajouté à Rousseau (histoire et humanité).
- **Leurres vrais ou paires ambiguës** : en SVT, trois matchings avaient une paire défendable de deux façons ; en poésie, deux mauvaises propositions étaient vraies (« répète la voyelle e », « allitération de r »).
- **Rédacteurs qui génèrent par script** : comme en Tle C, plusieurs rédacteurs ont produit leurs JSON avec un petit générateur. Le contrôle porte sur le JSON produit.

## Ce qu'on a appris sur la codebase

- Rien de neuf : `valider.rb` ne contrôle toujours pas les `subjects`.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `valider.rb` ne contrôle pas les sujets | Le chantier ne touche que du contenu | À ouvrir |

## À trancher

- **Course entre `develop_stage_test` et les dossiers `zz-preuve-test-*`** : en Tle D, le premier `bin/ci-quiet` a échoué parce qu'un autre test créait au même moment un dossier `docs/contenus/lecons-traitees/zz-preuve-test-*` que `develop_stage_test` compte. Relancé seul, le test est vert (12/12), puis `bin/ci-quiet` l'a été aussi. Les tests du jeu standard lancés en même temps que d'autres tests de base de données peuvent aussi finir en interblocage. Option prudente appliquée : relancer seul. Option possible : un chantier qui isole ces tests (dossier temporaire hors de `lecons-traitees/`, ou tests non parallèles).
- **Lectures graphiques sans tolérance**, **valeurs illustratives**, **textes d'appui de l'oral** : comme en Tle C et D, option prudente appliquée (laissé tel quel ; un enseignant relit avant publication).
- **Poèmes et recueils écrits pour Lnclass** (œuvre poétique) : les extraits étudiés sont présentés comme écrits pour Lnclass ; les auteurs réels (Hugo, Baudelaire, Césaire, Senghor, Dadié) ne sont cités que pour les dates et les mouvements. Un enseignant relit avant publication.

## Avancement

### 17 leçons propres à la Tle A1

Preuve : sympy sur chaque question en mathématiques ; ailleurs, un extrait mot pour mot de la leçon. Chaque réponse faussée exprès est détectée. Aucune figure ajoutée. Relecture indépendante de chaque leçon.

| Leçon | Questions | Vérifications | Réponses faussées détectées | Défauts de fond corrigés (rédaction + relecture) |
|---|---:|---:|---:|---:|
| Français — Œuvre poétique | 109 | 4 835 | 9/9 | 0 + 6 |
| Philo — L'histoire et l'humanité | 107 | 4 960 | 0/0 | 1 + 3 |
| Maths — Fonction exponentielle népérienne | 126 | 4 986 | 126/126 | 0 + 12 |
| Maths — Fonction logarithme népérien | 115 | 4 563 | 115/115 | 0 + 1 |
| Maths — Primitives et calcul intégral | 111 | 4 064 | 111/111 | 0 + 3 |
| Maths — Probabilité et variable aléatoire | 113 | 4 035 | 113/113 | 0 + 1 |
| Maths — Statistique à deux variables | 116 | 4 273 | 116/116 | 0 + 1 |
| Maths — Suites numériques | 120 | 4 095 | 120/120 | 0 + 2 |
| Maths — Systèmes d'équations linéaires | 110 | 4 113 | 110/110 | 1 + 1 |
| Maths — Étude de fonctions polynômes et rationnelles | 111 | 4 323 | 111/111 | 2 + 0 |
| SVT — L'activité cérébrale chez l'homme | 112 | 4 647 | 33/33 | 0 + 1 |
| SVT — L'hérédité du sexe et du groupe sanguin | 104 | 4 440 | 38/38 | 0 + 1 |
| SVT — L'origine de la vie | 110 | 4 796 | 8/8 | 0 + 1 |
| SVT — L'utilisation des nutriments : la biosynthèse des protéines | 118 | 5 026 | 52/52 | 0 + 3 |
| SVT — L'évolution de la lignée humaine | 114 | 5 061 | 25/25 | 0 + 1 |
| SVT — Les prévisions génétiques | 107 | 4 704 | 23/23 | 0 + 2 |
| SVT — Les réactions émotionnelles chez l'homme | 105 | 4 602 | 8/8 | 0 + 1 |
| **Total** | **1 908** | **77 523** | **1118/1118** | **4 + 40** |

Exemples de défauts de fond trouvés à la relecture : 11 valeurs approchées refusées faute de tolérance (exponentielle) ; « les deux valeurs de x » alors que G(x) = 7 en a trois, et un contre-exemple hors de l'hypothèse « continue sur [0 ; 6] » (primitives) ; une correction de transcription fausse et 150 nucléotides au lieu de 153 (biosynthèse des protéines) ; « s'ouvre sur » au lieu de « s'achève sur » et un énoncé qui donnait la réponse (œuvre poétique). Les relecteurs ont aussi réécrit une quarantaine de corrections dont la forme était fautive ou qui désignaient une proposition par son rang.
