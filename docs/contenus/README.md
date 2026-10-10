# Contenus pédagogiques

Les contenus pédagogiques de Lnclass et la méthode pour les écrire : les **progressions** qui créent les cours de l'année, le **prompt** qui rédige une leçon complète (cours, fiches essentielles, exercices), et les **leçons déjà traitées**. Ce dossier ne contient pas de code, seulement des fichiers importables et leur mode d'emploi.

| Fichier | Rôle |
|---|---|
| [`progressions-2026-2027/`](progressions-2026-2027/) | Les 10 premières leçons de la progression DPFC 2026-2027, par matière, niveau et série : 13 fichiers `lnclass.course-tree` (1 056 cours sans fiche), à importer depuis **Imports → Cours complets**, **après** les leçons traitées. Détail et couverture : [`progressions-2026-2027/README.md`](progressions-2026-2027/README.md) |
| [`prompt-redaction.md`](prompt-redaction.md) | Le prompt à donner à un modèle pour rédiger une leçon : règle de l'analogie, structure d'une fiche, 3 exercices par fiche, contraintes de l'application. Il produit **un seul fichier** `lnclass.course-tree` : le cours, ses fiches et leurs exercices |
| [`prompt-redaction-lot.md`](prompt-redaction-lot.md) | La version « lot par niveau » : pour un niveau et une série (Tle D, 1ère D, 3ème…), il prend les 3 premières leçons de chaque matière du niveau (jusqu’à 18), les rédige une par une avec `prompt-redaction.md`, les contrôle (script puis relecture indépendante) et les range dans `lecons-traitees/`. Un appel = un niveau |
| [`../../script/contenus/valider.rb`](../../script/contenus/valider.rb) | Le contrôle mécanique d’un fichier de leçon contre les règles du prompt : `ruby script/contenus/valider.rb fichier.json`. Ruby pur, code de sortie 1 s’il y a une erreur |
| [`lecons-traitees/`](lecons-traitees/) | Les leçons déjà rédigées avec ce prompt, un fichier `lnclass.course-tree` par cours complet, rangées par niveau et série, puis par matière. Pour l'instant `tle-d/` : 18 leçons, 3 par matière, en Maths, Physique-Chimie, SVT, Histoire-Géographie, Philosophie et Français |

## Le principe

La force de Lnclass, c'est que l'élève comprend du premier coup. Chaque notion passe par une **image du quotidien** que l'élève connaît déjà, avant la définition exacte, dans cet ordre :

1. l'image ;
2. le pont entre l'image et la notion ;
3. la notion exacte ;
4. la limite de l'image.

Exemple de référence, le théorème des gendarmes : deux policiers tiennent un prisonnier par les bras. S'ils arrivent tous les deux au commissariat, le prisonnier y arrive aussi.

## Utiliser le prompt

1. Copier le prompt, puis remplir son bloc **ENTRÉE** : intitulé exact de la leçon (celui de la progression), niveau, série, matière, rang dans la progression.
2. Importer le JSON obtenu depuis **Imports → Cours complets**. **Un seul import** crée le cours, ses fiches essentielles et les exercices de chaque fiche, en brouillon. On peut choisir **jusqu'à 50 fichiers d'un coup** (50 Mo au total, 500 cours au plus) : ils forment un seul import, avec une ligne de bilan par fichier. Un même cours présent dans deux fichiers de l'envoi n'est importé dans aucun des deux.
3. Faire relire le contenu par un enseignant de la discipline, puis publier.
4. Ranger le fichier dans `lecons-traitees/<niveau>-<série>/<matière>/` (le slug de la matière : `mathematiques`, `physique-chimie`, `svt`, `histoire-geographie`, `philosophie`, `francais`…) et ajouter une ligne au tableau ci-dessous.

Pour toutes les matières d’un niveau d’un coup, utiliser plutôt [`prompt-redaction-lot.md`](prompt-redaction-lot.md).

## Ordre des imports

Un import ne met jamais à jour l'existant : un cours déjà présent (même nom, niveau, matière et série) est **ignoré** comme doublon, fiches comprises. D'où l'ordre :

1. **D'abord les leçons traitées** (`lecons-traitees/`) : elles créent les cours complets.
2. **Ensuite les progressions** (`progressions-2026-2027/`) : elles créent les autres cours de l'année, vides, et ignorent ceux qui existent déjà.

Si la progression a déjà été importée, le cours de la leçon existe vide, et l'import du cours complet sera ignoré. Un cours ne se supprime pas, et un cours archivé compte encore comme doublon. Il faut donc **renommer** le cours vide dans l'écran des cours (par exemple « Limites et continuité (vide) »), l'archiver, puis importer le cours complet.

## Leçons traitées

### Tle D — `lecons-traitees/tle-d/`

| Fichier | Cours | Fiches | Exercices | Questions |
|---|---|---:|---:|---:|
| `mathematiques/limites-et-continuite.json` | Limites et continuité (Maths) | 3 | 9 | 51 |
| `mathematiques/probabilite-conditionnelle-et-variable-aleatoire.json` | Probabilité conditionnelle et variable aléatoire (Maths) | 3 | 9 | 54 |
| `mathematiques/derivabilite-et-etude-de-fonctions.json` | Dérivabilité et étude de fonctions (Maths) | 3 | 9 | 51 |
| `physique-chimie/cinematique-du-point.json` | Cinématique du point (Physique) | 3 | 9 | 45 |
| `physique-chimie/les-alcools.json` | Les alcools (Chimie) | 3 | 9 | 54 |
| `physique-chimie/mouvement-du-centre-d-inertie-d-un-solide.json` | Mouvement du centre d'inertie d'un solide (Physique) | 4 | 12 | 60 |
| `svt/le-devenir-des-cellules-sexuelles-chez-les-mammiferes.json` | Le devenir des cellules sexuelles chez les mammifères (SVT) | 3 | 9 | 53 |
| `svt/le-fonctionnement-des-organes-sexuels-chez-l-homme.json` | Le fonctionnement des organes sexuels chez l'Homme (SVT) | 3 | 9 | 54 |
| `svt/la-reproduction-chez-les-spermaphytes.json` | La reproduction chez les spermaphytes (SVT) | 3 | 9 | 54 |
| `histoire-geographie/histoire-l-onu.json` | Histoire — L'ONU | 3 | 3 | 18 |
| `histoire-geographie/geographie-les-fondements-du-developpement-economique-de-la-cote-d-ivoire.json` | Géographie — Les fondements du développement économique de la Côte d'Ivoire | 3 | 3 | 18 |
| `histoire-geographie/histoire-l-ere-de-la-bipolarisation-de-1947-a-1991.json` | Histoire — L'ère de la bipolarisation de 1947 à 1991 | 3 | 3 | 18 |
| `philosophie/la-dissertation-philosophique.json` | La dissertation philosophique | 3 | 3 | 18 |
| `philosophie/le-commentaire-de-texte-philosophique.json` | Le commentaire de texte philosophique | 3 | 3 | 18 |
| `philosophie/la-connaissance-de-l-homme.json` | La connaissance de l'homme | 3 | 3 | 18 |
| `francais/oeuvre-narrative.json` | Œuvre narrative | 3 | 3 | 18 |
| `francais/la-dissertation-litteraire.json` | La dissertation littéraire | 3 | 3 | 18 |
| `francais/preparation-a-l-oral-du-baccalaureat.json` | Préparation à l'oral du Baccalauréat | 3 | 3 | 18 |

Les 9 leçons d'Histoire-Géographie, de Philosophie et de Français (2026-10-06) n'ont qu'**un exercice par fiche** (Comprendre, Appliquer, S'évaluer, une fiche chacun), contre trois dans le prompt : un format court, pour la démo. Elles ont été importées sans erreur par la vraie chaîne d'import. Aucun enseignant ne les a encore relues.

Les 5 leçons 2 et 3 de Maths, de Physique et de SVT (2026-10-06) suivent le prompt complet, 3 exercices par fiche. Elles ont été importées sans erreur par la vraie chaîne d'import. Aucun enseignant ne les a encore relues. « Mouvement du centre d'inertie d'un solide » a 4 fiches : le mouvement circulaire uniforme, confirmé au programme par le porteur, en a une à lui.

Les 4 premiers fichiers ont été importés le 2026-09-29 sur une base neuve, par la vraie chaîne d'import, **sans aucune erreur** : 4 cours, 12 fiches, 36 exercices, 203 questions, 786 propositions. Les progressions de Maths, Physique-Chimie et SVT importées ensuite ont ignoré ces 4 cours comme doublons et créé les autres.

À faire valider par un enseignant, car le programme détaillé n'était pas disponible :

- **Maths** : les asymptotes ne sont pas traitées, faute de place en 3 fiches. Dans « Dérivabilité et étude de fonctions », l'inégalité des accroissements finis et les dérivées successives ne le sont pas non plus (signalées dans le sous-titre de la dernière fiche). Deux explications de « Limites et continuité » dépassent 400 caractères (450 et 444).
- **Physique** : il faut vérifier que le repère de Frenet et le recours à une primitive sont au programme.
- **Chimie** : il faut vérifier que la règle de Markovnikov est au programme. DNPH, Fehling et Schiff chevauchent peut-être la leçon suivante sur les aldéhydes et cétones.
- **SVT** : l'hCG, le corps jaune et la progestérone sont traités au minimum, parce qu'ils relèvent aussi de la leçon suivante.

## Contraintes de l'application, vérifiées pendant le test

- **Pas de tableau dans une fiche.** L'application supprime `table`, `tr`, `td` et `th`, et ne garde que le texte des cellules. Les balises conservées sont `h2`, `h3`, `p`, `ul`, `ol`, `li`, `strong`, `em` et `blockquote`.
- **Formules KaTeX** (`$…$`, `$$…$$`). Elles sont rendues dans les fiches, les questions, les propositions et les explications, mais pas dans les noms ni les titres. L'extension chimie `\ce` n'est pas chargée : on écrit les formules chimiques en indices Unicode (CH₃–CH₂–OH).
- **Ordre des propositions.** L'application les mélange à chaque session.
