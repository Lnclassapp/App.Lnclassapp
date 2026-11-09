# Journal — Les leçons d'Histoire-Géographie de Terminale préparées comme Thalès

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-09 | Les 10 leçons sont rédigées, prouvées et relues une par une : aucune n'est partagée avec un autre dossier de Terminale | La comparaison des fiches (hors série et sous-titre) ne trouve aucune leçon commune | Non |
| 2026-11-09 | Les questions non calculées sont prouvées par un extrait de la leçon (25 caractères au moins, retrouvé mot pour mot) ; les questions chiffrées le sont en plus par `proof.py` | Une question d'histoire se prouve par le texte de la leçon, pas par un calcul | Non |
| 2026-11-09 | Les documents des sujets sont écrits pour Lnclass, sans fausse citation d'un personnage réel ; les dates, chiffres et faits viennent tous de la leçon d'origine | Un fait inventé dans une leçon d'histoire passe pour vrai auprès de l'élève | Non |
| 2026-11-09 | Le jeu standard charge une leçon d'Histoire-Géographie de Tle (manifeste : 25 couples) | `StandardTestSet` exige une ligne par couple qui a du v3 | Non |

## Ce qui a dérapé

- **Extraits de preuve qui ne prouvaient rien** : le script vérifie qu'un extrait existe dans la leçon, pas qu'il justifie la réponse. Les relecteurs en ont remplacé beaucoup (bipolarisation 13, montée des nationalismes 30, fin de la guerre froide 12, France 7, ONU 5, secteurs 3).
- **Fill_blank à deux réponses vraies** (secteurs d'activités) : « tertiaire », « africain », « Abidjan / San Pedro » admettaient une autre réponse juste. Reformulés.
- **Faits absents de la leçon** (indépendance de la Côte d'Ivoire, 14 défauts ; ONU ; bipolarisation ; fin de la guerre froide) : présidence d'Houphouët-Boigny après 1960, causes du SAA, « téléphone rouge ». Retirés ou ramenés au texte de la leçon.
- **Distracteurs vrais** : Brazzaville (nationalismes), Rhin fleuve frontalier et « 18 ans » (France), Libéria dont la guerre civile se poursuit après 1991 (fin de la guerre froide). Remplacés.
- **Générateurs partagés** : les rédacteurs écrivaient leurs générateurs dans un même dossier de travail et se sont écrasés. Les ajouts eux-mêmes, dans des dossiers séparés, n'ont pas été touchés ; le script les a recontrôlés un par un.

## Ce qu'on a appris sur la codebase

- Rien de neuf : `valider.rb` ne contrôle toujours pas les `subjects`.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `valider.rb` ne contrôle pas les sujets | Le chantier ne touche que du contenu | À ouvrir |

## À trancher

- **Course entre les tests du jeu standard et les dossiers `zz-preuve-test-*`** : comme en Tle A1 et A2. Option prudente appliquée : relancer seul le test touché.
- **Conseil de l'Entente** (indépendance de la Côte d'Ivoire, S1.E3.Q2) : les distracteurs « Soudan français » et « Guinée » sont gardés, car la leçon ne cite que quatre membres. Option possible : les remplacer par des pays hors d'Afrique de l'Ouest.
- **Valeurs illustratives** (problèmes de développement, N5.Q2 : valeur ajoutée calculée sur deux prix fictifs) : comme en Tle A1. Option prudente appliquée : laissées, présentées comme un exemple.

## Avancement

Preuve : extraits de la leçon pour chaque question non calculée, `proof.py` pour les questions chiffrées (chaque réponse faussée exprès est détectée). Aucune figure ajoutée. Relecture indépendante de chaque leçon.

| Leçon | Questions | Vérifications | Réponses faussées détectées | Défauts de fond corrigés (rédaction + relecture) |
|---|---:|---:|---:|---:|
| Histoire — L'ère de la bipolarisation (1947-1991) | 110 | 4 994 | — | 0 + 1 |
| Histoire — L'ONU | 110 | 5 055 | — | 0 + 4 |
| Histoire — La montée des nationalismes en Afrique | 123 | 5 586 | — | 1 + 3 |
| Histoire — L'accession de l'Algérie à l'indépendance | 113 | 5 099 | — | 1 + 17 |
| Histoire — L'accession de la Côte d'Ivoire à l'indépendance | 110 | 4 647 | 8/8 | 0 + 14 |
| Histoire — De la fin de la guerre froide vers un monde multipolaire | 117 | 5 300 | 6/6 | 1 + 6 |
| Géographie — Les secteurs d'activités économiques de la Côte d'Ivoire | 110 | 4 866 | 11/11 | 0 + 5 |
| Géographie — Les fondements de l'économie de la France | 125 | 5 374 | 17/17 | 0 + 11 |
| Géographie — Les fondements du développement économique de la Côte d'Ivoire | 110 | 4 775 | 18/18 | 0 + 4 |
| Géographie — Les problèmes de développement économique de la Côte d'Ivoire | 118 | 4 966 | 21/21 | 0 + 3 |
