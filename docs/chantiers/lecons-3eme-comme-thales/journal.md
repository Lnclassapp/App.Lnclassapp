# Journal — Les leçons de 3ème préparées comme Thalès

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-05 | Un rédacteur par leçon, qui écrit ses ajouts hors dépôt ; un script les fusionne dans la version de `Develop` | Le cours, les fiches et les exercices existants restent identiques octet pour octet, ce que le script contrôle | Non |
| 2026-11-05 | `valider.rb` ne contrôle pas les sujets : le script de vérification le relance avec chaque sujet à la place des 4 problèmes | Mêmes règles de question qu'à l'import, sans toucher au script du dépôt | Non |

## Ce qui a dérapé

- **Message du commit de mathématiques** : il annonce 884 questions et 15 figures. Les bons chiffres sont 888 questions et 18 figures. Le commit n'a pas été réécrit, car l'historique était déjà poussé.
- **Message du commit de physique-chimie** : il annonce 10 figures ajoutées. Il y en a 11 (5 aux lentilles, 2 aux alcanes, 2 à masse et poids, 1 à équilibre, 1 aux défauts de l'œil).
- **Quota de la session** : les 18 rédacteurs de physique-chimie et de SVT se sont arrêtés en pleine rédaction. Ils ont repris chacun leur travail après la levée du quota, sans rien perdre.
- **Corrections trop maigres** : deux leçons de SVT, « La dégradation des sols » et « Les grossesses précoces », avaient des corrections de sujets de 23 à 41 caractères (« Méthode. 25 − 14 = 11 »). check.py ne mesurait pas leur longueur. Elles ont été réécrites : 337 à 385 caractères en moyenne, 204 au minimum. « Les grossesses précoces » portait aussi des `$` dans ses corrections, que check.py ne cherchait que dans les énoncés.
- **Défauts de forme récurrents chez les rédacteurs**, tous attrapés par check.py et corrigés :
  - clé `blank` ou `hint` sur un `select` ;
  - énoncé qui recopie un énoncé déjà dans la leçon ;
  - réponses acceptées en doublon à un accent ou une apostrophe près ;
  - `true_false` dont `correct` est un entier ;
  - extrait de justification coupé par le gras d'une fiche ;
  - mauvaise proposition désignée par son rang.

## Ce qu'on a appris sur la codebase

- `script/contenus/valider.rb` ne valide pas `subjects`. Seul l'import les contrôle : `SUBJECT_TITLE_MAX` 200, `NOTIONS_MAX` 600, `HINT_MAX` 400, 10 sujets et 10 exercices par sujet au plus.
- Une figure `geometry` affiche ses longueurs calculées. Une dimension littérale (« x + 5 ») va donc dans l'énoncé, jamais sur la figure.
- `bin/rails test` sur un seul fichier échoue sur la couverture SimpleCov : il faut `COVERAGE=0`. Le test de rendu demande des assets construits (`yarn build && yarn build:css`).
- La leçon la plus longue du dépôt (`longue` de `db/seeds/standard/jeu.yml`) est maintenant `3eme/edhc/le-scrutin-electoral.json` (278 740 octets). L'empreinte de `standard_activity_test.rb` passe de `41688b73c9` à `f1defa0fb0`, car les leçons de 3ème du jeu standard ont plus d'exercices.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `valider.rb` ne contrôle pas les sujets ; il ne mesure pas la longueur des corrections ni les `$` hors Mathématiques et Physique-Chimie | Le chantier ne touche que du contenu ; le contrôle a été fait par un script hors dépôt | À ouvrir |
| SVT « Le sang » : la planche `lame-de-sang-numeros` ne numérote pas dans le même ordre que l'exercice existant de la leçon | Défaut de la leçon d'origine, que le chantier ne touche pas ; aucune question ajoutée ne s'appuie sur cette numérotation | À ouvrir |

## À trancher

> **Tranché le 2026-11-14** par le validateur pédagogique (chantier [`validation-pedagogique-agent`](../validation-pedagogique-agent/journal.md#décisions-du-validateur), ADR-0135). Chaque point ci-dessous a sa décision (Confirmé, Corrigé, Retiré ou reformulé, Hors base) et sa justification dans la table de sa matière. Plus aucun point n'attend d'enseignant.

- **Lentilles (Physique-Chimie)** : la position et la hauteur de l'image se lisent sur une construction graphique, la méthode de la leçon, mais les réponses `numeric` n'acceptent aucun écart (`tolerance` 0). Les valeurs sont entières et la figure les montre. Option prudente appliquée : laisser tel quel. Option possible : tolérance de 0,5 cm.
- **Valeurs illustratives** : les nombres de T4 (VIH) et les montants (Histoire-Géographie, Physique-Chimie) sont inventés pour les énoncés et présentés comme des exemples. Un enseignant relit avant publication, comme pour le reste de la 3ème.

## Clôture

60 leçons, 6 matières, un commit par matière. Chaque notion a maintenant deux exercices, et chaque leçon 4 sujets de 4 exercices. Le cours, les fiches et les 4 problèmes sont inchangés, octet pour octet, ce que le script contrôle.

| Matière | Questions ajoutées | Vérifications | Erreurs corrigées | Figures ajoutées | Preuve des calculs |
|---|---:|---:|---:|---:|---|
| Mathématiques | 888 | 15 674 | 40 | 18 | sympy sur chaque question ; 120 réponses faussées exprès, 120 détectées |
| EDHC | 1 093 | 20 106 | 68 | 2 | extrait mot pour mot pour chaque question ; 74 réponses chiffrées recalculées à la main |
| Français | 1 101 | 20 100 | 82 | 0 | extrait mot pour mot pour chaque question |
| Histoire-Géographie | 1 080 | 19 893 | 58 | 4 | extrait mot pour mot pour chaque question |
| Physique-Chimie | 1 098 | 19 850 | 42 | 11 | sympy sur 644 questions, extraits pour les questions de cours ; 150 réponses faussées exprès, 148 détectées, les 2 autres vérifiées à la main |
| SVT | 1 044 | 19 197 | 70 | 0 | extrait mot pour mot pour chaque question ; 13 valeurs énergétiques recalculées à la main |
| **Total** | **6 304** | **114 820** | **360** | **35** | |

Les erreurs corrigées sont celles du premier passage de check.py et celles de fond trouvées par les calculs. Cela comprend une dizaine de bonnes réponses fausses, inversées ou ambiguës, dont 3 en statistique, 4 en équations et 1 en électrolyse. Il faut y ajouter les deux leçons de SVT réécrites. Chaque fichier vérifié est identique, octet pour octet, au fichier committé : son sha256 est relu au moment du commit. Le test de rendu (`lesson_rendering_test.rb`) passe sur les 60 fichiers.
