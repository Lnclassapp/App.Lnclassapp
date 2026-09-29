# Contenus pédagogiques

Les contenus pédagogiques de Lnclass et la méthode pour les écrire : les **progressions** qui créent les cours, le **prompt** qui rédige les fiches essentielles et leurs exercices, et les **leçons déjà traitées**. Ce dossier ne contient pas de code, seulement des fichiers importables et leur mode d'emploi.

| Fichier | Rôle |
|---|---|
| [`progressions-2026-2027/`](progressions-2026-2027/) | Les 10 premières leçons de la progression DPFC 2026-2027, par matière, niveau et série : 13 fichiers `lnclass.course-tree` (1 056 cours sans fiche), à importer depuis **Imports → Cours complets**. Détail et couverture : [`progressions-2026-2027/README.md`](progressions-2026-2027/README.md) |
| [`prompt-redaction.md`](prompt-redaction.md) | Le prompt à donner à un modèle pour rédiger un cours : règle de l'analogie, structure d'une fiche, 3 exercices par fiche, contraintes de l'application, format de sortie `lnclass.essentials` v1 |
| [`lecons-traitees/`](lecons-traitees/) | Les leçons déjà rédigées avec ce prompt (fiches essentielles et exercices, `lnclass.essentials`), rangées par niveau et série. Pour l'instant `tle-d/` : la première leçon de Maths, Physique, Chimie et SVT |

## Le principe

La force de Lnclass, c'est que l'élève comprend du premier coup. Chaque notion passe par une **image du quotidien** que l'élève connaît déjà, avant la définition exacte, dans cet ordre :

1. l'image ;
2. le pont entre l'image et la notion ;
3. la notion exacte ;
4. la limite de l'image.

Exemple de référence, le théorème des gendarmes : deux policiers tiennent un prisonnier par les bras. S'ils arrivent tous les deux au commissariat, le prisonnier y arrive aussi.

## Utiliser le prompt

1. Le cours doit exister dans Lnclass. Il est créé par l'import de sa progression ([`progressions-2026-2027/`](progressions-2026-2027/)).
2. Copier le prompt, puis remplir son bloc **ENTRÉE** : cours, **slug exact du cours** (à lire dans l'application), niveau, série, matière, place dans la progression.
3. Importer le JSON obtenu depuis **Imports → Fiches essentielles**. Tout le contenu arrive en brouillon.
4. Faire relire le contenu par un enseignant de la discipline, puis publier.
5. Ranger le fichier dans `lecons-traitees/<niveau>-<série>/` et ajouter une ligne au tableau ci-dessous.

Le slug se lit dans l'application, jamais à partir du nom : plusieurs cours portent le même nom selon le niveau ou la série, et leur slug prend alors un suffixe (`limites-et-continuite-4`).

## Leçons traitées

### Tle D — `lecons-traitees/tle-d/`

| Fichier | Cours | Fiches | Exercices | Questions |
|---|---|---:|---:|---:|
| `limites-et-continuite-4.json` | Limites et continuité (Maths) | 3 | 9 | 51 |
| `cinematique-du-point-2.json` | Cinématique du point (Physique) | 3 | 9 | 45 |
| `les-alcools-2.json` | Les alcools (Chimie) | 3 | 9 | 54 |
| `le-devenir-des-cellules-sexuelles-chez-les-mammiferes.json` | Le devenir des cellules sexuelles chez les mammifères (SVT) | 3 | 9 | 53 |

Les 4 fichiers ont été importés le 2026-09-29 dans une base de développement, par la vraie chaîne d'import, **sans aucune erreur**. Leur champ `course` contient le slug de cette base : **il faut le remplacer par celui de ton application avant l'import**.

À faire valider par un enseignant, car le programme détaillé n'était pas disponible :

- **Maths** : les asymptotes ne sont pas traitées, faute de place en 3 fiches.
- **Physique** : il faut vérifier que le repère de Frenet et le recours à une primitive sont au programme.
- **Chimie** : il faut vérifier que la règle de Markovnikov est au programme. DNPH, Fehling et Schiff chevauchent peut-être la leçon suivante sur les aldéhydes et cétones.
- **SVT** : l'hCG, le corps jaune et la progestérone sont traités au minimum, parce qu'ils relèvent aussi de la leçon suivante.

## Contraintes de l'application, vérifiées pendant le test

- **Pas de tableau dans une fiche.** L'application supprime `table`, `tr`, `td` et `th`, et ne garde que le texte des cellules. Les balises conservées sont `h2`, `h3`, `p`, `ul`, `ol`, `li`, `strong`, `em` et `blockquote`.
- **Formules KaTeX** (`$…$`, `$$…$$`). Elles sont rendues dans les fiches, les questions, les propositions et les explications, mais pas dans les noms ni les titres. L'extension chimie `\ce` n'est pas chargée : on écrit les formules chimiques en indices Unicode (CH₃–CH₂–OH).
- **Ordre des propositions.** L'application les mélange à chaque session.
