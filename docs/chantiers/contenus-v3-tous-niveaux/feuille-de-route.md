# Feuille de route — Leçons au format v3 pour tous les niveaux

> Programme (`docs/workflows/programme.md`) : il ne produit pas de code. Chaque vague ouvre son chantier `docs/chantiers/contenus-<niveau>-<matiere>/` (memo, prd, plan) avec la ligne `Programme : contenus-v3-tous-niveaux`, sa session enfant et sa PR prête vers `Develop`.
> Modèle repris tel quel de [`contenus-3e-autres-matieres`](../contenus-3e-autres-matieres/feuille-de-route.md).

## Périmètre chiffré

Source : `docs/contenus/progressions-2026-2027/` (10 premières leçons par matière, niveau et série). Une leçon commune à plusieurs séries est **écrite une fois** puis déclinée par série (un cours porte une seule série) : le chiffre compté est celui des leçons **distinctes**.

| Niveau | Maths | Français | HG | SVT | PC | Philo | EDHC | Total |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Tle (A1, A2, C, D) | 23 | 7 | 10 | 24 | 13 | 10 | — | **87** |
| 1ère (A, C, D) | 18 | 11 | 10 | 25 | 21 | 8 | — | **93** |
| 2nde (A, C) | 17 | 10 | 10 | 18 | 13 | — | — | **68** |
| 3ème | fait | fait | fait | fait | fait | — | fait | **0** |
| 4ème | 10 | 10 | 10 | 9 | 10 | — | 10 | **59** |
| 5ème | 10 | 10 | 10 | 8 | 10 | — | 10 | **58** |
| 6ème | 10 | 10 | 10 | 8 | 10 | — | 10 | **58** |
| | | | | | | | | **423** |

## Les vagues

Règle : **une vague = une matière d'un niveau**, coupée en deux par groupe de séries au-delà de 17 leçons distinctes. Chaque vague : chantier, session enfant, prompt de matière, `valider.rb` sans avertissement, relecture indépendante, « Je m'entraîne », rangement, points enseignant au journal, PR prête avec la ligne de preuve `bin/ci-quiet`.

| # | Niveau | Matière | Séries | Leçons |
|---|---|---|---|---:|
| T1 | Tle | Mathématiques | C, D | 15 |
| T2 | Tle | Mathématiques | A1, A2 | 8 |
| T3 | Tle | Physique-Chimie | C, D | 13 |
| T4 | Tle | SVT | C, D | 17 |
| T5 | Tle | SVT | A1, A2 | 7 |
| T6 | Tle | Philosophie | A1, A2, C, D | 10 |
| T7 | Tle | Français | A1, A2, C, D | 7 |
| T8 | Tle | Histoire-Géographie | toutes | 10 |
| P1 | 1ère | Mathématiques | C, D | 13 |
| P2 | 1ère | Mathématiques | A | 5 |
| P3 | 1ère | Physique-Chimie | C, D | 13 |
| P4 | 1ère | Physique-Chimie | A | 8 |
| P5 | 1ère | SVT | C, D | 16 |
| P6 | 1ère | SVT | A | 9 |
| P7 | 1ère | Philosophie | A, C, D | 8 |
| P8 | 1ère | Français | A, C, D | 11 |
| P9 | 1ère | Histoire-Géographie | toutes | 10 |
| S1 | 2nde | Mathématiques | C | 10 |
| S2 | 2nde | Mathématiques | A | 7 |
| S3 | 2nde | Physique-Chimie | A, C | 13 |
| S4 | 2nde | SVT | C | 10 |
| S5 | 2nde | SVT | A | 8 |
| S6 | 2nde | Français | A, C | 10 |
| S7 | 2nde | Histoire-Géographie | toutes | 10 |
| Q1–Q6 | 4ème | Maths, Français, HG, SVT, PC, EDHC | — | 59 |
| C1–C6 | 5ème | idem | — | 58 |
| X1–X6 | 6ème | idem | — | 58 |

**42 vagues.** Les vagues d'un même niveau ne dépendent pas les unes des autres : elles peuvent tourner **3 à la fois** (seul point de contact : la section du niveau dans `docs/contenus/README.md`, à fusionner à la clôture de chaque PR). Un niveau ne démarre qu'une fois le précédent fusionné, pour respecter l'ordre demandé.

**Figures.** Chaque vague réutilise les sortes existantes (ADR-0116, ADR-0117). Une sorte ou un paramètre nouveau (arbre de probabilités, tableau de variations, circuit électrique, champ…) ouvre un amendement d'ADR **avant** le lot qui l'emploie, avec captures à 390 px et sur ordinateur ; ce code passe par la PR de la vague et le train `Staging` → `main`.

## Registre des décisions à prendre (porteur)

| # | Question | Options | Recommandation | Bloque |
|---|---|---|---|---|
| D1 | Matières couvertes | 7 matières à fiche (Maths, Fr, HG, SVT, PC, Philo, EDHC) · + Anglais · + toutes (langues, arts, musique, EPS) | **7 matières** ; langues, arts, musique et EPS dans un programme à part (exercices d'un autre genre, prompt à écrire) | toutes |
| D2 | « Compléter la 3ème » | rien à faire pour les 6 matières (10/10 chacune) · ajouter Anglais/autres si D1 les retient | **rien** si D1 = 7 matières | 3ème |
| D3 | Série E de Philosophie (absente du référentiel) | ignorer · créer la série | **ignorer** (17 cours non importables) | T6, P7 |
| D4 | Leçons v1 déjà rangées pour ces niveaux | remplacées par le fichier v3 du même intitulé (comme en 3ème) · gardées à côté | **remplacées** ; l'historique git les garde | toutes |
| D5 | Taille et parallélisme | 1 vague = 1 matière d'un niveau, ≤ 17 leçons, 3 sessions en parallèle · regrouper les petites vagues de série A | **comme ci-dessus** | toutes |

**Tranché par le porteur (2026-10-31)** : D1 = les 7 matières (ni anglais, ni EPS, ni musique, ni autres langues ou arts) ; D2 = rien à compléter en 3ème ; D3 = série E ignorée ; D4 = v1 remplacées ; D5 = accepté.

## Registre des contradictions

| Sources | Écart | Tranché par |
|---|---|---|
| CLAUDE.md « une PR par chantier » ↔ « une session nommée qui rassemble les leçons » | une session ne livre pas 42 PR sous 40 commits | la session d'orchestration rassemble ; chaque vague a sa session enfant, son chantier et sa PR (même règle qu'en 3ème) |

## Portes du programme

- [x] Feuille de route validée par le porteur (D1 à D5, 2026-10-31)
- [ ] Tle : 8 vagues fusionnées, 87 leçons rangées
- [ ] 1ère : 9 vagues fusionnées, 93 leçons
- [ ] 2nde : 7 vagues fusionnées, 68 leçons
- [x] 3ème : rien à compléter (D2)
- [ ] 4ème, 5ème, 6ème : 6 vagues chacune
- [ ] Points « à faire valider par un enseignant » tous inscrits au journal ; leçons en brouillon
- [ ] Index des chantiers mis à jour à la clôture, `journal.md` clos

## Challenger empirique — par vague

Un rôle distinct de l'auteur importe en brouillon une leçon de la vague, ouvre la fiche à 390 px et sur ordinateur, fait varier une figure, lance « Je m'entraîne » ; captures envoyées au porteur, jamais commitées.
