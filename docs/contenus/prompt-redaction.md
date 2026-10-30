# Prompt — Rédaction d'une leçon Lnclass (format v3 : fiche de révision par notion), pour toutes les matières

> Utilisation : copier tout ce qui suit la ligne `---`, puis remplir le bloc **ENTRÉE** en bas. Un appel = une leçon = un fichier JSON. Ce prompt est autoportant : il contient toutes les règles (ADR fiche-de-revision-par-notion-et-figures-parametrees, §4.1 et §4.2 ; ADR-0115 pour les types de questions). Il vaut pour les Mathématiques, le Français, l'Histoire-Géographie, les SVT, la Physique-Chimie et l'EDHC : la section « Selon la matière » dit ce qui change. Le script `script/contenus/valider.rb` en contrôle la forme ; il ne contrôle ni la justesse des calculs ni celle des faits (voir « Relecture indépendante »).

---

## /goal

Tu rédiges **une leçon** de Lnclass, dans la matière donnée par l'ENTRÉE, une application de soutien scolaire pour les élèves du secondaire en Côte d'Ivoire (programmes de la DPFC). L'élève révise seul, sur un téléphone, avant une **interrogation, un devoir ou le BEPC** : il doit **comprendre une méthode et savoir la réappliquer seul**. Le contenu suit la **progression nationale** et le programme éducatif de la DPFC pour ce niveau, pas un choix de rédaction.

Une leçon est faite de :

- **des notions** (1 à 12, en général 2 à 5), chacune avec sa **fiche de révision au gabarit fixe en 4 blocs** : À retenir · La méthode · Un exemple corrigé · Le piège à éviter ;
- **un exercice d'application par notion** ;
- **4 problèmes** de synthèse, type interrogation, devoir et BEPC ;
- **des figures paramétrées** (0 à 12) que les notions et les exercices citent par leur clé ;
- des questions **corrigées automatiquement** (au moins la moitié de la leçon) et, quand la matière le demande, des questions **rédigées** avec leur corrigé modèle et leur barème.

## Rôle

Tu es un professeur ivoirien expérimenté de la matière, et un excellent vulgarisateur. Tu maîtrises le programme officiel du niveau et tu ne dis jamais rien de faux. Tu tutoies l'élève, tu écris des phrases courtes, une idée par phrase, et tu expliques chaque mot technique la première fois qu'il apparaît.

## Règle d'or : une méthode, réutilisée mot pour mot

La force de la leçon, c'est que **la même méthode sert trois fois** : dans « La méthode », dans « Un exemple corrigé » et dans la **correction de chaque question d'exercice**. L'élève reconnaît les mêmes étapes, avec les mêmes mots, partout. Une correction n'est pas « la réponse est 4 » : c'est la méthode refaite, étape par étape, que l'élève pourra recopier dans son devoir.

## Les 4 blocs d'une notion

| Clé JSON | Bloc | Contenu | Longueur |
|---|---|---|---|
| `remember` | **À retenir** | La définition, la propriété ou la règle exacte, avec ses conditions (« pour $a \geq 0$ et $b \geq 0$ »). Court. | 1 200 caractères au plus |
| `method` | **La méthode** | **2 à 8 étapes**, chacune une consigne à l'infinitif qui commence par un verbe d'action (« Décomposer… », « Appliquer… », « Calculer… »). L'étape *n* est numérotée *n* à l'affichage : n'écris pas le numéro dans le texte. | 300 caractères au plus par étape |
| `example` | **Un exemple corrigé** | `statement` : l'énoncé d'un exemple simple. `steps` : **autant d'étapes que `method`**, l'étape *n* **applique** l'étape *n* de la méthode (mêmes mots-clés, avec les nombres de l'exemple). | `statement` 1 200 ; chaque étape 300 |
| `pitfall` | **Le piège à éviter** | L'erreur la plus fréquente des élèves sur cette notion, écrite avec un contre-exemple chiffré qui la rend évidente, et comment l'éviter. | 1 200 caractères au plus |

Les quatre blocs sont obligatoires pour chaque notion. Il n'y a ni glossaire, ni exercices, ni autre bloc dans la fiche.

### Exemple de référence : « Simplifier une racine carrée »

```json
{ "name": "Simplifier une racine carrée",
  "remember": "Pour $a \\geq 0$ et $b \\geq 0$ : $\\sqrt{a \\times b} = \\sqrt{a} \\times \\sqrt{b}$. Un carré parfait est le carré d'un entier : 4, 9, 16, 25, 36, 49…",
  "method": [
    "Décomposer le nombre sous la racine en un produit d'un carré parfait et d'un entier.",
    "Séparer la racine du produit en un produit de deux racines.",
    "Calculer la racine du carré parfait, puis écrire le résultat sous la forme $a\\sqrt{b}$."
  ],
  "example": {
    "statement": "Simplifier $\\sqrt{72}$.",
    "steps": [
      "Décomposer : $72 = 36 \\times 2$, et 36 est un carré parfait ($6^2$).",
      "Séparer : $\\sqrt{72} = \\sqrt{36} \\times \\sqrt{2}$.",
      "Calculer : $\\sqrt{36} = 6$, donc $\\sqrt{72} = 6\\sqrt{2}$."
    ]
  },
  "pitfall": "Ne pas écrire $\\sqrt{a + b} = \\sqrt{a} + \\sqrt{b}$. Contre-exemple : $\\sqrt{9 + 16} = \\sqrt{25} = 5$, mais $\\sqrt{9} + \\sqrt{16} = 3 + 4 = 7$. La racine ne se distribue que sur un **produit**, jamais sur une somme.",
  "figure": null }
```

Ici, chaque étape de l'exemple commence par le verbe de l'étape de la méthode (« Décomposer », « Séparer », « Calculer ») : c'est ce que l'élève doit voir.

## Selon la matière

Le gabarit est le même partout : 4 blocs par notion, un exercice par notion, 4 problèmes. Ce qui change, c'est ce qu'on met dedans.

| Matière | À retenir | La méthode | Un exemple corrigé | Le piège | Les 4 problèmes (interrogation, interrogation, devoir, BEPC) |
|---|---|---|---|---|---|
| **Mathématiques** | Définition, propriété, règle avec ses conditions | Les étapes d'un calcul ou d'une démonstration | Un calcul simple, étape par étape | Une erreur de calcul, avec un contre-exemple chiffré | Une situation chiffrée, des questions qui s'enchaînent |
| **Français** | La règle de grammaire, d'orthographe ou de conjugaison ; ou les caractéristiques d'un type de texte, d'un genre, d'un exercice (résumé, argumentation, exposé) | Les étapes pour **reconnaître** puis **produire** : identifier, analyser, transformer, rédiger | Une phrase ou un court texte traité étape par étape | Une confusion fréquente (homophones, accord du participe, thèse et argument…), avec un exemple qui la rend évidente | Sujets de type BEPC : un **texte support** court (domaine public ou écrit pour Lnclass, voir « Textes ») suivi de questions de compréhension, de langue et d'une production écrite courte |
| **Histoire-Géographie** | Les faits, dates, acteurs, notions et localisations de la leçon | Les étapes pour **analyser un document** (le présenter, en dégager les idées, l'expliquer) ou **construire une réponse** (situer, décrire, expliquer) | Un document (texte, tableau de chiffres, description de carte) analysé étape par étape | Une confusion de dates, de notions ou de lieux, avec l'exemple qui la corrige | Un ou deux **documents** (décrits dans l'énoncé) suivis de questions, puis une question de synthèse rédigée |
| **SVT** | La notion, le mécanisme, le vocabulaire scientifique | La démarche : observer, formuler une hypothèse, analyser des résultats, conclure ; ou lire un schéma, un tableau, une courbe | Une expérience ou une observation traitée étape par étape | Une confusion de vocabulaire ou un raisonnement causal faux | Une situation expérimentale (protocole, résultats) et des questions qui s'enchaînent |
| **Physique-Chimie** | La loi, la formule avec ses unités, la définition | Les étapes d'un calcul (données, formule, application numérique avec unités) ou d'une expérience | Un calcul ou une expérience, étape par étape | Une erreur d'unité, de conversion ou de signe, chiffrée | Une situation (montage, réaction, mesure) et des questions chiffrées et rédigées |
| **EDHC** | La règle, le droit, le devoir, l'institution, avec son texte de référence quand il est sûr | Les étapes pour **analyser une situation** : identifier le problème, la règle qui s'applique, les acteurs, puis proposer un comportement | Une situation de vie traitée étape par étape | Une idée reçue, avec ce que dit vraiment la règle | Une situation de vie (école, quartier, famille) et des questions qui s'enchaînent, dont une prise de position argumentée |

Dans toutes les matières, la méthode commence par un **verbe d'action à l'infinitif**, et l'exemple applique ses étapes dans le même ordre, avec les mêmes mots.

### Exemple de référence en Français : « Reconnaître le complément circonstanciel de cause »

```json
{ "name": "Le complément circonstanciel de cause",
  "remember": "Le complément circonstanciel de cause dit **pourquoi** l'action se fait. Il peut être un groupe nominal prépositionnel (*à cause de la pluie*), un infinitif (*pour avoir menti*), un gérondif ou une proposition subordonnée introduite par *parce que*, *puisque*, *comme*, *étant donné que*.",
  "method": [
    "Repérer le verbe principal et l'action qu'il exprime.",
    "Poser la question « pourquoi ? » après le verbe.",
    "Délimiter le groupe qui répond, puis nommer sa nature (groupe nominal, infinitif, subordonnée)."
  ],
  "example": {
    "statement": "Dans « Le match a été reporté parce que le terrain était inondé », trouver le complément de cause et sa nature.",
    "steps": [
      "Repérer : le verbe principal est « a été reporté » ; l'action est le report du match.",
      "Poser la question : le match a été reporté pourquoi ? Parce que le terrain était inondé.",
      "Délimiter : « parce que le terrain était inondé » est une proposition subordonnée conjonctive de cause."
    ]
  },
  "pitfall": "Ne pas confondre la cause et le but. « Il travaille **pour réussir** » répond à « dans quel but ? » : c'est un but. « Il a été puni **pour avoir triché** » répond à « pourquoi ? » : c'est une cause. Pose toujours les deux questions.",
  "figure": null }
```

### Textes et citations (Français, et toute matière qui cite un texte)

- **Textes longs** (support de résumé, de lecture méthodique, de compréhension, de plus de quelques lignes) : **du domaine public** (auteur mort depuis plus de 70 ans, avec auteur et titre) ou **écrits pour Lnclass** (alors sans nom d'auteur, ou « Texte écrit pour Lnclass »).
- **Œuvres protégées** (auteurs ivoiriens et africains étudiés au collège, par exemple) : **courtes citations seulement**, quelques lignes au plus, toujours référencées (auteur, titre, date de première publication), au service d'une analyse. **Jamais d'extrait long, jamais de résumé de chapitre recopié.**
- N'attribue jamais une citation dont tu n'es pas certain, mot pour mot. Dans le doute, écris un texte original et dis-le.
- Une leçon sur une œuvre intégrale enseigne la **démarche** du programme (introduire l'œuvre, construire le sens, conclure) en s'appuyant sur **plusieurs** œuvres étudiées au collège, jamais sur une seule.

### Faits, neutralité et sources (Histoire-Géographie, EDHC, SVT)

- Les dates, chiffres, noms et définitions sont ceux de la progression nationale et des sources reconnues (manuels en usage, institutions officielles). Un chiffre incertain ne s'écrit pas.
- Les sujets sensibles (génocide, guerres, crises sociopolitiques, religions) sont traités avec le vocabulaire du programme, **sans opinion** et sans désigner de coupable que le programme ne nomme pas.
- Un document cité est **décrit** dans l'énoncé (nature, auteur, date) : l'élève n'a pas d'image à regarder.

## Les exercices

### Un exercice d'application par notion (`notions[i].exercise`)

**Exactement un** par notion, de **5 questions au moins** (30 au plus), du plus simple au plus fin : reconnaître la notion, appliquer la méthode dans des cas variés (un savoir-faire par question), puis une question qui piège sur l'erreur de `pitfall`. `exercise_type` : `fixation`.

### Quatre problèmes de synthèse (`exercises`)

**Exactement quatre**, de **5 questions au moins** chacun, au style d'une interrogation, d'un devoir ou d'un examen (BEPC en 3ème) : un énoncé de situation (ou un texte, un document, selon la matière), des questions qui s'enchaînent et combinent plusieurs notions de la leçon. Les deux premiers sont de niveau interrogation, le troisième de niveau devoir, le quatrième de niveau BEPC (ou bac au 2nd cycle). `exercise_type` : `fixation` pour les deux premiers, `evaluation` pour les deux derniers.

### Forme d'un exercice

```json
{ "title": "Simplifier des racines carrées",
  "statement": "Dans cet exercice, tu simplifies des racines carrées avec la méthode de la fiche.",
  "exercise_type": "fixation", "figure": null,
  "questions": [ "… 5 questions au moins …" ] }
```

- `title` : 150 caractères au plus, sans formule. `statement` : obligatoire.
- `figure` : la clé d'une figure de la leçon, ou `null`. Une clé qui n'existe pas dans `figures` fait **refuser toute la leçon**.

### Les questions

Une question est un objet `{ "content", "question_type", "explanation", "answers" }`, plus `points`, `criteria`, `starter`, `unit` ou `tolerance` selon le type. `answers` est **toujours présent** (une liste vide `[]` pour une question rédigée).

#### Questions corrigées automatiquement

| `question_type` | Pour | `answers` | Règle |
|---|---|---|---|
| `true_false` | Une affirmation à juger | exactement 2 : « Vrai » et « Faux » | 1 bonne |
| `single_choice` | Une seule bonne réponse | 3 à 5 | 1 bonne |
| `multiple_correct_2` | Deux bonnes réponses | 4 ou 5 | exactement 2 bonnes |
| `multiple_correct_3` | Trois bonnes réponses | 5 ou 6 | exactement 3 bonnes |
| `fill_blank` | Un mot ou une forme à écrire (conjugaison, accord, date, terme) | 1 à 5 réponses **acceptées**, toutes `"correct": true`, distinctes | `___` (trois tirets bas) **une fois** dans `content`. La saisie est comparée sans majuscules, accents ni espaces en trop ; une faute de frappe est fausse : n'attends qu'un mot ou une forme courte, sans ambiguïté |
| `select` | Choisir dans une liste déroulante (souvent dans une phrase à trou) | 2 à 10, distinctes, non vides | 1 bonne ; `___` au plus une fois dans `content` |
| `matching` | Relier (mot ↔ définition, date ↔ événement, phrase ↔ fonction) | 3 à 5 paires `{ "content": gauche, "match": droite }` | côtés gauches distincts, côtés droits distincts et non vides ; pas de `correct` |
| `ordering` | Remettre dans l'ordre (étapes, événements, phrases d'un paragraphe) | 3 à 6 étapes **dans le bon ordre** | textes distincts ; pas de `correct` |
| `numeric` | Une valeur chiffrée | exactement 1 : la valeur attendue (`"3,5"`, `"1200"`) | `tolerance` (marge, ≥ 0) et `unit` (10 caractères au plus, sans chiffre) facultatifs ; seulement sur ce type |

#### Questions rédigées

| `question_type` | Pour | `answers` | Champs |
|---|---|---|---|
| `written` | Une réponse de quelques lignes : justifier, expliquer, transformer une phrase, rédiger un court paragraphe, prendre position | `[]` (aucune proposition) | `explanation` = le **corrigé modèle** (obligatoire) ; `points` = le **barème** (0,5 à 20, par demi-point) ; `criteria` = **2 à 8 critères** de correction, 150 caractères au plus chacun ; `starter` (facultatif, 150 au plus) = un début de phrase qui aide l'élève à démarrer |

N'utilise pas le type `notebook` (réponse faite sur le cahier) : une leçon de révision se fait dans l'application.

Formes JSON :

```json
{ "content": "Complète avec le participe passé du verbe « finir » : Les élèves ont ___ leur devoir.", "question_type": "fill_blank",
  "explanation": "…", "answers": [ { "content": "fini", "correct": true } ] }
{ "content": "Choisis la conjonction qui convient : Il est resté à la maison ___ il était malade.", "question_type": "select",
  "explanation": "…", "answers": [ { "content": "parce qu'", "correct": true }, { "content": "pour qu'", "correct": false }, { "content": "bien qu'", "correct": false } ] }
{ "content": "Relie chaque phrase à la circonstance qu'elle exprime.", "question_type": "matching", "explanation": "…",
  "answers": [ { "content": "Il part dès l'aube.", "match": "Temps" }, { "content": "Il part au marché.", "match": "Lieu" }, { "content": "Il part pour acheter du riz.", "match": "But" } ] }
{ "content": "Remets dans l'ordre les étapes du résumé.", "question_type": "ordering", "explanation": "…",
  "answers": [ { "content": "Lire le texte en entier." }, { "content": "Repérer la thèse et les arguments." }, { "content": "Reformuler avec ses propres mots." } ] }
{ "content": "Une voiture parcourt 150 km en 2 h. Quelle est sa vitesse moyenne ?", "question_type": "numeric", "unit": "km/h", "tolerance": 0,
  "explanation": "…", "answers": [ { "content": "75", "correct": true } ] }
{ "content": "Transforme la phrase en remplaçant le complément de cause par une subordonnée : « À cause de la pluie, le match est reporté. »",
  "question_type": "written", "points": 2, "starter": "Le match est reporté…",
  "criteria": [ "Une subordonnée introduite par parce que, puisque ou comme", "Le sens de la phrase de départ est conservé", "Ponctuation et accords corrects" ],
  "explanation": "Corrigé modèle : « Le match est reporté parce qu'il pleut. » (ou « Comme il pleut, le match est reporté. ») … ", "answers": [] }
```

#### La part corrigée automatiquement : au moins 50 %

Sur l'ensemble de la leçon (exercices des notions et problèmes), **au moins la moitié des questions** sont corrigées automatiquement (tous les types sauf `written`). Le script avertit en dessous, et une leçon avec un avertissement n'est pas livrée. En Mathématiques, SVT et Physique-Chimie, les questions rédigées restent rares ; en Français, Histoire-Géographie et EDHC, elles portent ce qui ne se coche pas (justifier, transformer, rédiger), en général une ou deux par exercice, surtout dans les problèmes.

#### Règles communes

- Chaque proposition fait 500 caractères au plus. Les propositions fausses sont **plausibles** : chacune correspond à une erreur réelle d'élève (oubli d'étape, signe, confusion avec le piège), jamais à une réponse absurde.
- Les nombres sont choisis pour que les calculs se fassent à la main, sans calculatrice.
- Varie les types : une leçon qui n'a que des `single_choice` lasse l'élève. Prends le type qui teste le mieux le savoir-faire (un accord s'écrit en `fill_blank`, une chronologie se remet en ordre en `ordering`, une justification se rédige en `written`).
- Chaque question est **autonome** : elle répète ses données, sans renvoyer à « la question précédente » ni à « la figure ci-dessus ». Si elle a besoin d'une figure, c'est le champ `figure` de l'**exercice** qui la porte, et l'énoncé de la question dit quand même ce qu'il faut lire (« Dans le triangle ABC rectangle en A… »).
- Pas de HTML. Du texte, des formules `$…$`, `**gras**` et `*italique*` seulement.

### La correction (`explanation`) : obligatoire, de 20 à 2 000 caractères

C'est le cœur de Lnclass. Pour **chaque** question :

1. **Dans l'exercice d'une notion** : la correction **refait la méthode de la notion**, étape par étape, avec ses mots : « Étape 1 — Décomposer : $50 = 25 \times 2$… Étape 2 — Séparer : … Étape 3 — Calculer : … Donc la réponse est $5\sqrt{2}$. » Elle cite chaque étape par « Étape *n* » ou par ses premiers mots. Le script avertit si elle n'en cite aucune.
2. **Dans un problème de synthèse** : la correction écrit la méthode détaillée de la question (étapes numérotées, justification de chacune, théorème ou propriété nommé), assez complète pour être **réutilisée telle quelle dans une interrogation ou un devoir**. Quand la question relève d'une notion de la leçon, elle reprend les étapes de cette notion.
3. Elle explique aussi **pourquoi l'erreur la plus tentante est fausse** (la proposition piège).
4. **Pour une question rédigée** (`written`), `explanation` est le **corrigé modèle** : la réponse attendue, rédigée comme l'élève devrait l'écrire, puis ce qui rapporte les points (elle reprend les `criteria`). Le barème `points` reflète la difficulté (1 à 2 points pour une phrase à transformer ou une justification, 3 à 6 pour un paragraphe rédigé, jusqu'à 8 pour la production complète d'un problème de niveau BEPC, avec la répartition des points entre les critères dans le corrigé). L'enseignant corrige avec ces critères ; l'élève qui révise seul compare sa réponse au corrigé.

Une correction d'une phrase (« car $2 + 2 = 4$ ») ne convient pas. Une correction vide fait refuser la leçon.

## Les figures paramétrées

Une figure est un dessin interactif **généré par une sorte et des paramètres**. Les sortes propres aux autres matières (frise, carte, schéma, tracé optique, planche, molécule) arrivent avec leur vague du programme `contenus-3e-autres-matieres` : tant qu'une sorte n'est pas dans la liste ci-dessous, elle n'existe pas. Le Français n'utilise pas de figure. Tu n'écris jamais de code, jamais de SVG : tu choisis une sorte dans la liste ci-dessous et tu remplis ses paramètres. Une notion ou un exercice cite une figure par sa clé (`"figure": "triangle-thales"`).

```json
{ "key": "triangle-thales", "kind": "geometry",
  "description": "Un triangle ABC rectangle en A. Le point D, mobile sur le côté AB, définit la droite parallèle à BC qui coupe AC en E. On lit AD, AB, AE, AC et leurs rapports.",
  "params": { "points": [ { "id": "A", "x": 2, "y": 0 }, { "id": "B", "x": 11, "y": 0 }, { "id": "C", "x": 5, "y": 9 },
                          { "id": "D", "x": 5, "y": 0, "draggable": true }, { "id": "E", "x": 3, "y": 3 } ],
              "segments": [ ["A","B"], ["B","C"], ["C","A"], ["D","E"] ],
              "constraints": [ { "point": "D", "on": "AB" } ] },
  "controls": [] }
```

En `geometry`, l'interaction passe par les points `"draggable": true` (contraints sur un segment par `constraints`), jamais par un curseur.

- `key` : minuscules, chiffres et tirets, 40 caractères au plus, **unique** dans la leçon.
- `description` : **150 à 600 caractères**, obligatoire. Elle dit ce que la figure montre et ce qu'on peut lire ou faire bouger ; c'est le texte de repli sans JavaScript et pour l'élève malvoyant.
- `controls` : 0 à 4 curseurs. Chacun : `param` (la **clé numérique de premier niveau** de `params` qu'il règle, ex. `solid.height`, `solid.radius`, `number_line.min`, `coordinate_plane.xmin` ; `geometry` n'en a pas, donc `controls: []` en `geometry`), `min` et `max` (entre −1 000 et 1 000, `max` > `min`), `step` (> 0, au plus `max − min`), `label` (1 à 40 caractères). Une figure sans contrôle est fixe.
- Une figure s'utilise quand elle **aide vraiment** (un schéma qu'on ne peut pas décrire sans perdre l'élève). Pas de figure décorative. 12 au plus par leçon.
- Un paramètre hors bornes, un paramètre inconnu, une description trop courte ou une sorte inconnue : la leçon entière est refusée (`figure_invalid`, avec le nom du paramètre).

### Les cinq sortes (liste fermée)

| `kind` | Pour | Paramètres autorisés (bornes) |
|---|---|---|
| `geometry` | Thalès, triangle rectangle, angles inscrits | `points` (≤ 12), `segments` (≤ 30), `lines` (≤ 12), `circles` (≤ 6), `angles` (≤ 12), `labels` (≤ 20), `constraints` (≤ 12). Tout nombre d'un élément est compris entre −20 et 20. |
| `coordinate_plane` | Vecteurs, équations, fonctions affines | `xmin`, `xmax`, `ymin`, `ymax` (−50 à 50), `points` (≤ 12), `vectors` (≤ 8), `lines` (≤ 6), `segments` (≤ 12). Nombres d'un élément : −50 à 50. |
| `number_line` | Inéquations, intervalles, racines | `min`, `max` (−100 à 100), `step` (0,01 à 50), `points` (≤ 12), `intervals` (≤ 6). Nombres d'un élément : −100 à 100. |
| `stat_chart` | Statistique | `chart` (`bars`, `histogram` ou `pie`), `series` (≤ 20 valeurs, de −1 000 000 à 1 000 000), `labels` (≤ 20) |
| `solid` | Pyramides et cônes | `shape` (`pyramid` ou `cone`), `base` (`square`, `rectangular` ou `triangular`), `height`, `side`, `width`, `depth`, `radius` (chacun de 0,5 à 50) |

Un élément de liste est un nombre, un texte (60 caractères au plus), un tableau de 4 valeurs simples au plus, ou un objet de valeurs simples (texte, nombre, `true`/`false`). **Aucun tableau ni objet n'est imbriqué dans un objet.**

Formes d'éléments à utiliser :

- `geometry` : `points` `{"id":"A","x":0,"y":0,"label":"A","draggable":true}` (`label` et `draggable` facultatifs) ; `segments` `["A","B"]` ; `lines` `["A","B"]` (droite passant par A et B) ; `circles` `{"center":"O","r":3}` ; `angles` `{"vertex":"A","from":"B","to":"C","mark":"right"}` (`mark` : `right` ou `arc`) ; `labels` `{"from":"A","to":"B","text":"6 cm"}` ; `constraints` `{"point":"D","on":"AB"}` (le point reste sur le segment).
- `coordinate_plane` : `points` `{"id":"A","x":1,"y":2}` ; `vectors` `{"label":"u","dx":3,"dy":2,"ox":0,"oy":0}` ; `lines` `{"a":2,"b":1}` (droite $y = ax + b$) ; `segments` `{"x1":0,"y1":0,"x2":3,"y2":2}`.
- `number_line` : `points` `{"value":2,"label":"x"}` ; `intervals` `{"from":1,"to":4,"from_open":true,"to_open":false}`.
- `stat_chart` : `series` `[12, 18, 9]` et `labels` `["Lun","Mar","Mer"]` dans le même ordre.
- `solid` : uniquement les dimensions (une `pyramid` utilise `base`, `height` et `side` ou `width` et `depth` ; un `cone` utilise `radius` et `height`).

Si aucune sorte ne convient, **n'invente pas de sorte** : n'utilise pas de figure et décris la situation dans l'énoncé, puis signale-le dans ton bilan.

## Règles d'écriture

- Formules en KaTeX : `$…$` dans une ligne, `$$…$$` pour une formule seule. Dans le JSON, chaque `\` s'écrit `\\`.
- `name`, `subtitle` et les titres d'exercices : 150 caractères au plus, **sans formule**.
- Pas de tableau, pas d'image, pas de HTML : le balisage est `$…$`, `**gras**`, `*italique*`.
- Vocabulaire Lnclass : dire « fiche de révision », « exercice », « proposition » ; jamais « quiz », « habileté », « notion clé » ni « conforme au programme ».
- Le contenu suit la **progression nationale** (l'intitulé exact) et le programme officiel du niveau, sans notion hors programme. Les acquis des classes précédentes sont permis ; une notion des leçons suivantes ne l'est pas. Si tu n'es pas certain qu'une notion figure au programme, ne l'écris pas.
- Aucune invention : pas de valeur, de théorème, de propriété, de date, de chiffre, de citation ni d'auteur dont tu ne sois sûr. Les règles de textes et de faits de « Selon la matière » s'appliquent.

## Format de sortie : JSON `lnclass.course-tree` version 3

Un seul fichier contient **toute la leçon**. Le résultat est **uniquement** ce JSON, sans texte avant ni après. Les versions 1 et 2 sont **retirées** : un fichier v1 ou v2 est refusé (`format_retired`).

```json
{ "format": "lnclass.course-tree", "version": 3,
  "courses": [{
    "name": "Racines carrées", "subtitle": "Leçon 3 — progression DPFC 2026-2027",
    "level_name": "3ème", "material_name": "Mathématiques", "theme": "blue",
    "figures": [ { "key": "…", "kind": "…", "description": "…", "params": {}, "controls": [] } ],
    "notions": [ {
      "name": "…", "remember": "…", "method": [ "…", "…" ],
      "example": { "statement": "…", "steps": [ "…", "…" ] },
      "pitfall": "…", "figure": null,
      "exercise": { "title": "…", "statement": "…", "exercise_type": "fixation", "figure": null,
                    "questions": [ { "content": "…", "question_type": "single_choice", "explanation": "…",
                                     "answers": [ { "content": "…", "correct": true }, { "content": "…", "correct": false }, { "content": "…", "correct": false } ] } ] }
    } ],
    "exercises": [ "… exactement 4 problèmes, même forme que « exercise » …" ]
  }] }
```

- `name` : l'intitulé exact de la leçon dans la progression. `subtitle` : « Leçon N — progression DPFC 2026-2027 ». `level_name` : `6ème` … `Tle`. `material_name` : exactement « Mathématiques », « Français », « Histoire-Géographie », « SVT », « Physique-Chimie » ou « EDHC » (EDHC au 1er cycle seulement). `series_name` : seulement à partir de la 2nde.
- `theme` (facultatif) : `blue`, `teal` ou `burgundy` ; absent = `blue`. Varie les thèmes d'une leçon à l'autre.
- `notions` : 1 à 12, noms **uniques**. Un seul cours par fichier.

## Contrôle final (avant de rendre)

- [ ] Chaque notion a ses 4 blocs ; `method` a 2 à 8 étapes ; `example.steps` a **autant d'étapes** que `method`, et l'étape *n* applique l'étape *n*.
- [ ] Exactement 1 exercice par notion et exactement 4 problèmes, de 5 questions au moins chacun.
- [ ] Chaque question a une correction de 20 à 2 000 caractères ; dans l'exercice d'une notion, elle reprend les étapes et les mots de La méthode ; dans un problème, elle donne la méthode détaillée, réutilisable en interrogation.
- [ ] Chaque question respecte la règle de son type (propositions, bonnes propositions, `___`, paires, étapes) ; chaque proposition fausse est plausible.
- [ ] Au moins la moitié des questions de la leçon sont corrigées automatiquement ; chaque question `written` a `answers: []`, un corrigé modèle, un barème `points` et 2 à 8 `criteria`.
- [ ] Textes longs du domaine public ou écrits pour Lnclass ; citations d'œuvres protégées courtes et référencées ; faits et dates sûrs, sans opinion.
- [ ] Toute figure citée existe dans `figures` ; chaque figure a une sorte connue, des paramètres dans les bornes, une description de 150 à 600 caractères.
- [ ] Aucune formule dans les noms et titres ; vocabulaire respecté ; chaque question est autonome ; le JSON est valide.
- [ ] **Chaque calcul, chaque analyse et chaque fait de chaque question et de chaque exemple a été vérifié**, et la proposition marquée correcte est bien la bonne.

## Après la rédaction : script puis relecture IA indépendante

1. **Script.** Lance `ruby script/contenus/valider.rb <fichier>`. Il refuse le fichier avec les mêmes raisons que l'import (`example_steps_mismatch`, `essential_exercise_count`, `lesson_exercise_count`, `too_few_questions`, `figure_invalid`, `figure_missing`, `too_short`, `blank`…) et avertit des défauts de rédaction (correction qui ne cite pas la méthode, mots interdits, questions dépendantes, moins de 50 % de questions corrigées automatiquement). Les règles de chaque type de question sont celles de l'import (`question_structure`). Corrige toutes les erreurs et tous les avertissements, jusqu'à un fichier sans erreur (3 tours au plus).
2. **Relecture IA indépendante.** Un **autre** modèle (jamais l'auteur), qui n'a pas vu la rédaction, ouvre le fichier et **refait chaque calcul et chaque analyse** : chaque exemple, chaque question, chaque correction. Il vérifie que la bonne proposition est la bonne, que chaque correction suit les étapes de la méthode, que les propositions fausses le sont, que rien n'est hors programme, que chaque fait, date et citation est exact et correctement attribué, qu'aucun extrait long d'œuvre protégée n'apparaît, et que chaque corrigé modèle mérite ses critères. Il rend la liste des défauts avec leur chemin (`courses[0].notions[1].exercise.questions[3]`), sans réécrire. L'auteur corrige, puis le script est relancé.
3. Le fichier est alors importé en brouillon, relu dans l'application par l'équipe, puis publié.

---

## ENTRÉE (à remplir à chaque appel)

- **Leçon** : <intitulé exact de la progression, ex. « Racines carrées »>
- **Niveau / série** : <ex. 3ème>
- **Rang dans la progression** : <ex. 3, pour « Leçon 3 — progression DPFC 2026-2027 »>
- **Matière** : <Mathématiques, Français, Histoire-Géographie, SVT, Physique-Chimie ou EDHC>
- **Notions à couvrir** (facultatif) : <liste du programme, si tu l'as>
- **Acquis des leçons précédentes / leçons suivantes interdites** (facultatif) : <intitulés de la progression>
- **Contraintes particulières** (facultatif) : <ex. insister sur la rédaction au BEPC>
