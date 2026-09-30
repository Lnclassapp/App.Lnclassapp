# Documentation Lnclass

> **Ce fichier fait autorité.** En cas de contradiction avec un autre document, c'est lui qui gagne.
> Version 2 — remplace la v1 (gelée dans [`archives/`](archives/)).

Lnclass est une plateforme éducative (LMS) en Rails 8, construite en **architecture hexagonale**. Cette documentation sert autant les développeurs humains que les agents IA : les deux lisent les mêmes fichiers et suivent le même processus.

---

## Par où commencer

| Tu es… | Lis dans cet ordre |
|---|---|
| **Nouveau dans l'équipe** | [`guide/README.md`](guide/README.md) → [`guide/onboarding.md`](guide/onboarding.md) → [`guide/architecture.md`](guide/architecture.md) |
| **Sur le point de coder** | [`workflows/README.md`](workflows/README.md) → le workflow de ton type de cycle |
| **Un agent IA** | [`guide/conventions.md`](guide/conventions.md) → [`workflows/README.md`](workflows/README.md) → le blueprint de la couche que tu touches |
| **En train de décider** | [`decisions/adr/`](decisions/adr/) pour la technique, [`decisions/udr/`](decisions/udr/) pour l'UI/UX |

---

## Ce qu'il y a ici

| Dossier | Contenu | Quand l'ouvrir |
|---|---|---|
| [`guide/`](guide/) | Comment on travaille ici : architecture, stack, conventions, onboarding, glossaire | Au début, puis en cas de doute sur une règle |
| [`workflows/`](workflows/) | Les cycles de travail : feature, bugfix, refactoring, optimisation, hotfix — et le programme qui les enchaîne | **Avant chaque chantier, systématiquement** |
| [`decisions/adr/`](decisions/adr/) | Architecture Decision Records — les choix techniques et leurs conséquences | Avant de trancher une question d'architecture |
| [`decisions/udr/`](decisions/udr/) | UI/UX Decision Records — les choix d'interface, écrits pour être appliqués par un agent | Avant d'écrire une vue |
| [`blueprints/`](blueprints/) | Patterns de code par couche : entity, port, use case, repository, query… | Au moment d'écrire le fichier |
| [`chantiers/`](chantiers/) | **Le travail lui-même** : un dossier par chantier (memo, PRD, plan de lots, journal) | En permanence pendant un chantier |
| [`contenus/`](contenus/) | Les contenus pédagogiques importables : progressions DPFC (cours), prompt de rédaction des fiches essentielles et des exercices, leçons déjà traitées | Avant d'importer des cours ou de rédiger une leçon |
| [`design/`](design/) | Design system et bibliothèque de composants | En construction — voir [`design/README.md`](design/README.md) |
| [`archives/`](archives/) | La v1 gelée et les documents historiques | Rarement, pour retrouver une intention passée |

---

## Les trois règles qui ne se négocient pas

**1. Un seul workflow fait foi.** C'est [`workflows/README.md`](workflows/README.md). Tout autre document décrivant un processus de développement est soit un raffinement de celui-ci, soit une archive.

**2. Le travail vit dans `chantiers/`.** Pas dans une tête, pas dans un chat, pas dans un outil externe. Un chantier sans dossier n'existe pas.

**3. Ce qui protège l'architecture, ce sont les garde-fous, pas la bonne volonté.** Le domaine ne peut pas importer ActiveRecord — ce n'est pas une consigne, c'est un test qui bloque le commit. Voir [`guide/conventions.md`](guide/conventions.md).

---

## Hiérarchie des sources de vérité

Quand deux documents disent des choses différentes, voici qui gagne. Du plus fort au plus faible :

| Rang | Source | Fait autorité sur |
|---|---|---|
| 1 | **ADR et UDR au statut `Accepté`**, non remplacés ([`decisions/`](decisions/)) | les **décisions** : architecture, modèle de données, règles métier structurantes, interface |
| 2 | [`guide/conventions.md`](guide/conventions.md) | la **forme** : nommage, emplacements, branches, commits, format des lots, ce qui bloque |
| 3 | [`workflows/`](workflows/) | le **processus** |
| 4 | Le `prd.md` d'un chantier | les **specs d'une feature**, dans le cadre posé par les rangs 1 à 3 |
| 5 | [`guide/`](guide/) (hors conventions), [`blueprints/`](blueprints/), le glossaire | les **explications et patrons** — ils illustrent les rangs 1 à 3, ils ne décident rien |
| 6 | Les inventaires et constats d'un chantier | **ce que fait le code existant** — jamais ce que doit faire le code à venir |
| 7 | Le code | lui-même |

Trois règles d'application :

1. **Un rang inférieur qui contredit un rang supérieur est un bug de documentation.** Le rang supérieur s'applique, et on corrige l'autre.
2. **Deux sources de même rang qui se contredisent — ou un ADR contre les conventions — ne se départagent pas en silence.** Ni « le plus récent gagne », ni « le code fait foi ». L'écart est inscrit au registre des contradictions du chantier ou du programme, puis tranché par un ADR ou une UDR qui **remplace explicitement** l'autre. D'ici là, le lot qui en dépend est bloqué.
3. **« Le code fait foi » ne vaut que pour décrire l'existant.** Un inventaire peut écrire que le code attribue l'or à 100 % quand l'ADR-0008 dit 80 % : c'est un constat. Ce que fera le nouveau code se décide par ADR.

Ce fichier-ci fait autorité sur l'**organisation** de la documentation, pas sur son contenu.

---

## Cette documentation est vivante

Elle évolue avec le projet. Si tu constates un écart entre ce qui est écrit ici et ce que fait réellement le code, **c'est un bug de la documentation** : ouvre un chantier `docs/<slug>` et corrige. Une doc fausse coûte plus cher qu'une doc absente, parce qu'on lui fait confiance.
