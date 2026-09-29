# Progressions DPFC 2026-2027 — 10 premières leçons par matière et par niveau

Source : page « Progressions du Secondaire 2026-2027 » de la DPFC (https://dpfc-ci.net/?page_id=5267), PDF téléchargés le 2026-09-29.

Chaque fichier est un import **`lnclass.course-tree` v1** (écran Imports → « Cours complets ») : une leçon = un cours, en brouillon, sans fiche ni exercice. Les fiches essentielles de ces cours se rédigent avec [`../prompt-redaction.md`](../prompt-redaction.md) et se rangent dans [`../lecons-traitees/`](../lecons-traitees/).

## Règles appliquées

- Les **10 premières leçons** de l'année, dans l'ordre chronologique de la progression (semaine de début) ; moins de 10 quand l'année n'en compte pas plus.
- Exclus : régulations, évaluations, remédiations, révisions, mises à niveau, devoirs de niveau, prises de contact, congés.
- Intitulé fidèle au document, sans « Leçon n : » ni volume horaire ; une leçon répétée n'est gardée qu'une fois.
- `subtitle` : « Leçon N — progression DPFC 2026-2027 », N étant le rang dans l'année.
- Série : celle du document. Un « A » en 1ère ou Tle devient deux cours, en **A1** et en **A2** (le référentiel découpe la série A). Progression commune à toutes les séries : pas de `series_name`.
- Apostrophes uniformisées en `'`.

## Fichiers

| Fichier | Cours | Matière reconnue par le référentiel de développement |
|---|---:|---|
| `progressions-2026-2027-allemand.json` | 30 | **non** : créer la matière avant l'import |
| `progressions-2026-2027-anglais.json` | 126 | oui |
| `progressions-2026-2027-arts-plastiques.json` | 63 | **non** : créer la matière avant l'import |
| `progressions-2026-2027-edhc.json` | 40 | **non** : créer la matière avant l'import |
| `progressions-2026-2027-education-musicale.json` | 70 | **non** : créer la matière avant l'import |
| `progressions-2026-2027-eps.json` | 39 | **non** : créer la matière avant l'import |
| `progressions-2026-2027-espagnol.json` | 32 | **non** : créer la matière avant l'import |
| `progressions-2026-2027-francais.json` | 126 | oui |
| `progressions-2026-2027-histoire-geographie.json` | 70 | oui |
| `progressions-2026-2027-mathematiques.json` | 127 | oui |
| `progressions-2026-2027-philosophie.json` | 87 | oui ; la série **E** (17 cours) n'existe pas dans le référentiel |
| `progressions-2026-2027-physique-chimie.json` | 120 | oui |
| `progressions-2026-2027-svt.json` | 126 | oui |

## Couverture (série : nombre de leçons ; « toutes » = progression commune ; — = niveau absent du document)

| Matière | 6ème | 5ème | 4ème | 3ème | 2nde | 1ère | Tle |
|---|---|---|---|---|---|---|---|
| Allemand | — | — | toutes : 8 | toutes : 8 | toutes : 5 | toutes : 6 | toutes : 3 |
| Anglais | toutes : 10 | toutes : 10 | toutes : 10 | toutes : 10 | A : 10<br>C : 10 | A : 10<br>C : 7<br>D : 7 | A : 10<br>C : 6<br>D : 6 |
| Arts plastiques | toutes : 9 | toutes : 9 | toutes : 9 | toutes : 9 | toutes : 9 | toutes : 9 | toutes : 9 |
| EDHC | toutes : 10 | toutes : 10 | toutes : 10 | toutes : 10 | — | — | — |
| Éducation musicale | toutes : 10 | toutes : 10 | toutes : 10 | toutes : 10 | toutes : 10 | toutes : 10 | toutes : 10 |
| EPS | toutes : 6 | toutes : 6 | toutes : 5 | toutes : 5 | toutes : 6 | toutes : 6 | toutes : 5 |
| Espagnol | — | — | toutes : 7 | toutes : 7 | toutes : 6 | toutes : 6 | toutes : 6 |
| Français | toutes : 10 | toutes : 10 | toutes : 10 | toutes : 10 | A : 10<br>C : 10 | A : 10<br>C : 10<br>D : 10 | A : 7<br>C : 6<br>D : 6 |
| Histoire-Géographie | toutes : 10 | toutes : 10 | toutes : 10 | toutes : 10 | toutes : 10 | toutes : 10 | toutes : 10 |
| Mathématiques | toutes : 10 | toutes : 10 | toutes : 10 | toutes : 10 | A : 8<br>C : 10 | A1 : 7<br>A2 : 7<br>C : 10<br>D : 10 | A1 : 8<br>A2 : 7<br>C : 10<br>D : 10 |
| Philosophie | — | — | — | — | — | A1 : 8<br>A2 : 8<br>C : 8<br>D : 8<br>E : 8 | A1 : 10<br>A2 : 10<br>C : 9<br>D : 9<br>E : 9 |
| Physique-Chimie | toutes : 10 | toutes : 10 | toutes : 10 | toutes : 10 | A : 10<br>C : 10 | A : 10<br>C : 10<br>D : 10 | C : 10<br>D : 10 |
| SVT | toutes : 8 | toutes : 8 | toutes : 9 | toutes : 10 | A : 9<br>C : 10 | A : 9<br>C : 10<br>D : 10 | A : 7<br>C : 10<br>D : 10 |

## Points à connaître

- **Allemand** : PDF scanné, relevé sur les images ; titres tronqués ou fautifs recopiés tels quels (« Jungendliche… », « Verwandschaft,… »). 2nde : une Lektion sans titre n'est pas relevée.
- **Histoire-Géographie** : les deux tableaux (histoire, géographie) sont fusionnés par semaine de début ; chaque intitulé est préfixé « Histoire — » ou « Géographie — ».
- **Physique-Chimie, 2nd cycle** : colonnes physique et chimie fusionnées par semaine de début, la physique d'abord à semaine égale.
- **Français** : version « à usage pédagogique » (grille par semaine) ; Terminales : moins de 10 leçons, le perfectionnement de la langue n'en nomme aucune.
- **EPS** : les leçons sont les activités des tableaux « exemples de progression » (5 à 6 par niveau).
- **Arts plastiques** : programme sans calendrier, l'ordre suit la numérotation des leçons.
- Le détail de chaque choix (pages, doublons, coquilles de la source) est dans les relevés d'extraction, hors dépôt.
