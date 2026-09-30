# Le guide Lnclass

> Tu débarques sur le projet ? **Lis ça d'abord.** Ce dossier explique comment on travaille ici : la stack, l'architecture, les conventions, le vocabulaire.
> Les mêmes fichiers servent aux développeurs humains et aux agents IA — environ 97 % du code du dépôt est écrit par des agents, et ils lisent ceci.

---

## Dans quel ordre lire

| # | Fichier | Ce que tu y trouves | Quand |
|---|---|---|---|
| 1 | [`onboarding.md`](onboarding.md) | De `git clone` au premier chantier : prérequis, `bin/setup`, `bin/dev`, tests, premiers réflexes | Jour 1, une fois |
| 2 | [`stack.md`](stack.md) | Ce qui tourne, à quoi ça sert **ici**, où c'est configuré | Jour 1, puis en référence |
| 3 | [`architecture.md`](architecture.md) | Les 4 couches, un parcours tracé de bout en bout, les erreurs classiques | Jour 1, puis **à chaque fois que tu hésites sur l'endroit d'un fichier** |
| 4 | [`conventions.md`](conventions.md) | Les contrats gelés : nommage, branches, commits, en-tête HITL, ce qui bloque | En permanence |
| 5 | [`glossaire.md`](glossaire.md) | Le langage omniprésent : un concept = un seul mot | Dès qu'un terme métier apparaît |
| 6 | [`configuration.md`](configuration.md) | Secrets et variables d'environnement : ce qui doit exister, où, et ce qui casse si ça manque | Avant le premier déploiement |

Puis, **avant d'écrire la moindre ligne de code** : [`../workflows/README.md`](../workflows/README.md). Le guide dit *comment c'est fait*, le workflow dit *comment on fait*.

**Si tu es un agent IA** : [`conventions.md`](conventions.md) → [`../workflows/README.md`](../workflows/README.md) → le [blueprint](../blueprints/) de la couche que tu touches. Les autres fichiers sont du contexte, ces trois-là sont des contrats.

---

## Les trois règles d'or

**1. Le domaine ne connaît rien du monde extérieur.** `app/domain/` est du Ruby pur : ni ActiveRecord, ni `params`, ni `request`. Ce n'est pas une consigne morale, c'est le pre-commit et la CI qui refusent le commit. Voir [`architecture.md`](architecture.md).

**2. Rien ne commence par du code.** Tout travail — une feature comme une correction d'une ligne — passe par les 5 phases du workflow et vit dans un dossier de [`../chantiers/`](../chantiers/). Un chantier sans dossier n'existe pas.

**3. Un concept = un seul mot.** Code en anglais, UI en français, zéro synonyme. Un terme absent du [`glossaire.md`](glossaire.md) ne s'invente pas : on l'ajoute, puis on l'utilise.

---

## J'ai besoin de…

| J'ai besoin de… | Va voir |
|---|---|
| Installer le projet et le lancer | [`onboarding.md`](onboarding.md) |
| Savoir quelle gem fait quoi, et où elle se configure | [`stack.md`](stack.md) |
| Savoir **où** mettre un fichier | [`architecture.md`](architecture.md#1-les-quatre-couches-et-le-sens-des-dépendances) |
| Choisir entre un Use Case et une Query | [`architecture.md` §4](architecture.md#4-lecture-vs-écriture--le-cqrs-léger) |
| **Écrire** un fichier d'une couche (entity, port, use case, repository, query…) | [`../blueprints/`](../blueprints/) |
| Nommer une branche, un commit, un ADR, un chantier | [`conventions.md`](conventions.md) |
| Savoir ce qui bloquera ma PR | [`conventions.md` §7](conventions.md#7-ce-qui-bloque) |
| Comprendre un mot métier | [`glossaire.md`](glossaire.md) |
| Configurer un secret, une variable d'environnement, un déploiement | [`configuration.md`](configuration.md) |
| Installer ou réparer le runner auto-hébergé de la CI | [`runner-auto-heberge.md`](runner-auto-heberge.md) |
| Démarrer un travail (`/feature`, `/bugfix`, `/refactor`, `/optimize`, `/hotfix`) | [`../workflows/README.md`](../workflows/README.md) |
| Comprendre pourquoi un choix technique a été fait | [`../decisions/adr/`](../decisions/adr/) |
| Savoir à quoi doit ressembler une vue | [`../decisions/udr/`](../decisions/udr/) et [`../design/README.md`](../design/README.md) |
| Retrouver une intention passée, une doc v1 | [`../archives/`](../archives/) — **jamais comme référence courante** |

---

## Quand la doc et le code divergent

Ça arrive, et les écarts identifiés sont listés : [`conventions.md` §8](conventions.md#8-écarts-connus-entre-la-doc-et-le-code) et [`architecture.md` §7](architecture.md#7-écarts-connus-entre-cette-architecture-et-le-code).

Un écart **non listé** est une découverte. Tu ne le corriges pas au passage : tu ouvres un chantier `docs/<slug>`. Une doc fausse coûte plus cher qu'une doc absente, parce qu'on lui fait confiance.
