# Contenus pédagogiques

Les contenus pédagogiques de Lnclass et la méthode pour les écrire : les **progressions** qui créent les cours de l'année, le **prompt** qui rédige une leçon complète (cours, fiches essentielles, exercices), et les **leçons déjà traitées**. Ce dossier ne contient pas de code, seulement des fichiers importables et leur mode d'emploi.

| Fichier | Rôle |
|---|---|
| [`progressions-2026-2027/`](progressions-2026-2027/) | Les 10 premières leçons de la progression DPFC 2026-2027, par matière, niveau et série : 13 fichiers `lnclass.course-tree` (1 056 cours sans fiche), à importer depuis **Imports → Cours complets**, **après** les leçons traitées. Détail et couverture : [`progressions-2026-2027/README.md`](progressions-2026-2027/README.md) |
| [`prompt-redaction.md`](prompt-redaction.md) | Le prompt à donner à un modèle pour rédiger une leçon : règle de l'analogie, structure d'une fiche, 3 exercices par fiche, contraintes de l'application. Il produit **un seul fichier** `lnclass.course-tree` : le cours, ses fiches et leurs exercices |
| [`lecons-traitees/`](lecons-traitees/) | Les leçons déjà rédigées avec ce prompt, un fichier `lnclass.course-tree` par cours complet, rangées par niveau et série. Pour l'instant `tle-d/` : la première leçon de Maths, Physique, Chimie et SVT |

## Le principe

La force de Lnclass, c'est que l'élève comprend du premier coup. Chaque notion passe par une **image du quotidien** que l'élève connaît déjà, avant la définition exacte, dans cet ordre :

1. l'image ;
2. le pont entre l'image et la notion ;
3. la notion exacte ;
4. la limite de l'image.

Exemple de référence, le théorème des gendarmes : deux policiers tiennent un prisonnier par les bras. S'ils arrivent tous les deux au commissariat, le prisonnier y arrive aussi.

## Utiliser le prompt

1. Copier le prompt, puis remplir son bloc **ENTRÉE** : intitulé exact de la leçon (celui de la progression), niveau, série, matière, rang dans la progression.
2. Importer le JSON obtenu depuis **Imports → Cours complets**. **Un seul import** crée le cours, ses fiches essentielles et les exercices de chaque fiche, en brouillon.
3. Faire relire le contenu par un enseignant de la discipline, puis publier.
4. Ranger le fichier dans `lecons-traitees/<niveau>-<série>/` et ajouter une ligne au tableau ci-dessous.

## Ordre des imports

Un import ne met jamais à jour l'existant : un cours déjà présent (même nom, niveau, matière et série) est **ignoré** comme doublon, fiches comprises. D'où l'ordre :

1. **D'abord les leçons traitées** (`lecons-traitees/`) : elles créent les cours complets.
2. **Ensuite les progressions** (`progressions-2026-2027/`) : elles créent les autres cours de l'année, vides, et ignorent ceux qui existent déjà.

Si la progression a déjà été importée, le cours de la leçon existe vide, et l'import du cours complet sera ignoré. Un cours ne se supprime pas, et un cours archivé compte encore comme doublon. Il faut donc **renommer** le cours vide dans l'écran des cours (par exemple « Limites et continuité (vide) »), l'archiver, puis importer le cours complet.

## Leçons traitées

### Tle D — `lecons-traitees/tle-d/`

| Fichier | Cours | Fiches | Exercices | Questions |
|---|---|---:|---:|---:|
| `limites-et-continuite.json` | Limites et continuité (Maths) | 3 | 9 | 51 |
| `cinematique-du-point.json` | Cinématique du point (Physique) | 3 | 9 | 45 |
| `les-alcools.json` | Les alcools (Chimie) | 3 | 9 | 54 |
| `le-devenir-des-cellules-sexuelles-chez-les-mammiferes.json` | Le devenir des cellules sexuelles chez les mammifères (SVT) | 3 | 9 | 53 |

Les 4 fichiers ont été importés le 2026-09-29 sur une base neuve, par la vraie chaîne d'import, **sans aucune erreur** : 4 cours, 12 fiches, 36 exercices, 203 questions, 786 propositions. Les progressions de Maths, Physique-Chimie et SVT importées ensuite ont ignoré ces 4 cours comme doublons et créé les autres.

À faire valider par un enseignant, car le programme détaillé n'était pas disponible :

- **Maths** : les asymptotes ne sont pas traitées, faute de place en 3 fiches.
- **Physique** : il faut vérifier que le repère de Frenet et le recours à une primitive sont au programme.
- **Chimie** : il faut vérifier que la règle de Markovnikov est au programme. DNPH, Fehling et Schiff chevauchent peut-être la leçon suivante sur les aldéhydes et cétones.
- **SVT** : l'hCG, le corps jaune et la progestérone sont traités au minimum, parce qu'ils relèvent aussi de la leçon suivante.

## Contraintes de l'application, vérifiées pendant le test

- **Pas de tableau dans une fiche.** L'application supprime `table`, `tr`, `td` et `th`, et ne garde que le texte des cellules. Les balises conservées sont `h2`, `h3`, `p`, `ul`, `ol`, `li`, `strong`, `em` et `blockquote`.
- **Formules KaTeX** (`$…$`, `$$…$$`). Elles sont rendues dans les fiches, les questions, les propositions et les explications, mais pas dans les noms ni les titres. L'extension chimie `\ce` n'est pas chargée : on écrit les formules chimiques en indices Unicode (CH₃–CH₂–OH).
- **Ordre des propositions.** L'application les mélange à chaque session.
