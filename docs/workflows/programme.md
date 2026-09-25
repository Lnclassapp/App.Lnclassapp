# Cycle Programme

> Un **programme** est un ensemble de chantiers qui poursuivent un seul objectif et qui ne tiennent pas dans un seul graphe de lots : une refonte, un nouveau dépôt, un contexte borné construit de zéro.
> Le processus maître en 5 phases est dans [`README.md`](README.md). Ce fichier ne le remplace pas : il l'applique **au-dessus** des chantiers ordinaires.

Branche : aucune en propre — chaque vague ouvre ses chantiers `feature/<slug>` · Dossier : `docs/chantiers/<programme>/`

---

## Quand utiliser ce cycle

| Utilise **programme** si… | C'est un **autre** cycle si… |
|---|---|
| L'objectif demande **plusieurs livraisons successives**, chacune démontrable seule | Un seul PRD et un seul graphe de lots suffisent → [`feature.md`](feature.md), même si le chantier est gros |
| Un **nouveau dépôt** naît, ou l'application existante est **reconstruite** | On corrige l'existant sans le reconstruire → [`bugfix.md`](bugfix.md) ou [`refactoring.md`](refactoring.md) |
| Plusieurs contextes bornés sont touchés **et** leurs livraisons dépendent les unes des autres | Les chantiers sont indépendants → ce sont des chantiers ordinaires, sans programme |

**Test** : si tu ne peux pas écrire le plan de lots complet aujourd'hui sans inventer des contrats que personne n'a encore décidés, c'est un programme. On planifie alors **par vagues**, et on ne détaille les lots que de la vague qui s'ouvre.

Un programme **ne produit pas de code lui-même**. Il produit une feuille de route, des décisions de fondation, et il ouvre des chantiers ordinaires qui, eux, suivent leur propre cycle (le plus souvent [`feature.md`](feature.md)).

---

## Le dossier d'un programme

```
docs/chantiers/<programme>/
├── memo.md              phase 1 — le problème, le grill, le hors périmètre
├── prd.md               phase 2 — PRD CADRE : acteurs, permissions, exigences transverses
├── inventaire/          phase 1 — l'existant, s'il y en a un (refonte uniquement)
├── feuille-de-route.md  phase 3 — vagues, traçabilité des features, décisions préalables
└── journal.md           tout du long
```

Chaque vague ouvre **ses propres chantiers** dans `docs/chantiers/<slug>/`, avec leurs `memo.md`, `prd.md` et `plan.md`. Leur memo porte une ligne `Programme : <programme>` dans son en-tête.

| Fichier | Ce qu'il contient | Ce qu'il ne contient **pas** |
|---|---|---|
| `prd.md` (cadre) | La matrice acteurs × permissions, les exigences valables pour toutes les vagues (sécurité, couverture, i18n, accessibilité), les critères d'acceptation **transverses** | Les critères d'une feature donnée : ils vont dans le PRD du chantier de la vague |
| `inventaire/` | **Ce que fait l'existant** : parcours, règles chiffrées, état réel (✅ ⚠️ ❌ 💀) | **Aucune décision.** Voir la règle ci-dessous |
| `feuille-de-route.md` | Les vagues, leur ordre, leurs portes ; la table de traçabilité feature → vague ; le registre des décisions à prendre ; le registre des contradictions entre sources | Les lots détaillés d'une vague qui n'est pas encore ouverte |

> **Un inventaire décrit, il ne décide pas.** Quand il constate « le code fait X, l'ADR dit Y », il ne tranche pas pour le code : il inscrit l'écart au registre des contradictions de la feuille de route, et un ADR ou une UDR tranche. Voir la [hiérarchie des sources](../README.md#hiérarchie-des-sources-de-vérité).

---

## Les phases pour ce cycle

### 0. Amorcer le dépôt — uniquement si le programme crée un dépôt

C'est la phase qui manquait à la v1 : les garde-fous doivent exister **avant** la première ligne de code métier, sinon ils arrivent après la dette qu'ils devaient empêcher. Dans l'ancienne application, `core.hooksPath` n'avait jamais été positionné — aucun hook ne s'est jamais exécuté.

Le dépôt est amorcé quand **chacune** de ces lignes est vraie, et prouvée par un commit volontairement fautif qui est refusé :

- [ ] `docs/` est copié **au premier commit**, avec `CLAUDE.md` et `.claude/skills/`
- [ ] `bin/setup` pose `git config core.hooksPath .githooks` et est idempotent
- [ ] Le pre-commit refuse : un `Orm::`/`ActiveRecord` dans `app/domain/`, un fichier de `app/` sans en-tête HITL, un `# :nocov:`, une offense rubocop
- [ ] La CI refuse : pureté du domaine, rubocop, tests, tests système (Chrome headless), brakeman, bundler-audit, couverture < 100 % lignes **et** branches ([ADR-0024](../decisions/adr/0024-couverture-de-tests-a-100-pourcent.md))
- [ ] Les branches `Develop`, `Staging`, `main` existent et sont protégées (aucun push direct, PR obligatoire)
- [ ] La production a `force_ssl`, une route `/up`, `:contact` dans `filter_parameters`, un stockage de fichiers persistant
- [ ] Un test système « squelette » (page d'accueil) passe en CI — la chaîne entière est prouvée avant qu'on y mette du métier

**Porte** : la phase 0 est un chantier ordinaire (`docs/chantiers/<slug>/`), livré et prouvé, avant le Lot 0 de la première vague.

### 1. Cadrer — `memo.md` + `inventaire/`

Poids : **maximum**, comme une feature, plus l'inventaire.

- `memo.md` : le problème, pour qui, pourquoi maintenant, **hors périmètre**. Le grill porte sur le programme entier : acteurs oubliés, features oubliées, ordre de livraison, reprise des données, sort de l'ancien dépôt.
- `inventaire/` (refonte) : produit par une **exploration en lecture seule** de l'existant, un explorateur par contexte borné plus un transverse. Protocole ci-dessous.
- **Règle de complétude** : toute table, toute route et toute branche non fusionnée de l'existant est rattachée à une feature de l'inventaire, ou déclarée morte avec sa preuve. Une feature oubliée ici est une feature perdue.

### 2. Décider — `prd.md` cadre + ADR/UDR de fondation

Deux registres, tenus dans `feuille-de-route.md` :

1. **Le registre des décisions de fondation** — tout ce qu'aucun lot ne peut trancher seul et que plusieurs vagues consomment : contrat de retour des use cases, découpage des contextes bornés, modèle d'autorisation, design system. Chaque décision a : la question, les options, une recommandation, la **vague qu'elle bloque**, et l'ADR/UDR qui la tranchera.
2. **Le registre des contradictions** — chaque fois que deux sources faisant autorité se contredisent (ADR contre ADR, ADR contre UDR, conventions contre ADR, glossaire contre ADR). On ne choisit pas en silence : l'écart est inscrit, puis tranché par un ADR ou une UDR qui **remplace explicitement** l'autre.

**Règle** : aucune vague n'ouvre son Lot 0 tant que les décisions qu'elle consomme ne sont pas **acceptées** (statut `Accepté` dans l'index). Une décision « Proposé » ne débloque rien.

### 3. Planifier — `feuille-de-route.md`

Le découpage est **par vagues**. Une vague = une livraison démontrable à de vrais utilisateurs, qui passe en recette (`Staging`) seule.

Pour chaque vague :

| Champ | Contenu |
|---|---|
| **Objectif** | ce qu'un acteur peut faire à la fin, en une phrase observable |
| **Chantiers** | les slugs à ouvrir, avec leur cycle |
| **Features** | les références de l'inventaire couvertes |
| **Tables** | les tables introduites ou modifiées |
| **Décisions préalables** | les lignes du registre qui doivent être `Accepté` |
| **Dépend de** | les vagues précédentes |
| **Porte de sortie** | ce qui doit être vrai pour ouvrir la suivante |

Trois règles :

1. **Traçabilité totale.** Une table en fin de feuille de route rattache **chaque** feature de l'inventaire à une vague, ou l'écarte avec sa raison. Une ligne sans vague ni raison est un trou.
2. **Planning roulant.** Seule la vague en cours et la suivante ont leurs chantiers ouverts et leurs lots détaillés (via `/feature` puis `/plan-lots`). Les suivantes restent au niveau de la feuille de route — on ne gèle pas aujourd'hui un contrat que la vague 1 n'a pas encore éprouvé.
3. **Les contrats d'une vague livrée sont gelés.** Une vague ultérieure qui a besoin de modifier un port, une table ou une policy déjà livrés ouvre un ADR : c'est un changement de contrat, pas un détail de lot.

### 4. Exécuter — une vague à la fois

Chaque vague est exécutée par ses chantiers, qui suivent **leur** cycle sans exception : Lot 0 séquentiel, lots parallèles en worktrees, test rouge d'abord, ordre des couches imposé. Le programme n'assouplit aucune règle d'un chantier.

Deux vagues peuvent se chevaucher **uniquement** si elles ne partagent aucun fichier et aucun contrat — la règle de collision des lots s'applique entre vagues.

### 5. Prouver — à chaque vague, puis au programme

- Chaque vague se clôt par la phase 5 de ses chantiers (challenger empirique, portes CI, PR vers `Develop`), **puis** par une recette sur `Staging` refaite par un rôle distinct.
- `feuille-de-route.md` est mise à jour : vague livrée, écarts constatés, décisions nouvelles, features déplacées.
- `journal.md` du programme reçoit une entrée par vague.
- Le programme est clos quand la table de traçabilité ne contient plus que des lignes `livré` ou `écarté (raison)`.

---

## Protocole d'exploration de l'existant

Pour une refonte, l'exploration produit l'inventaire. Elle est faite par des agents **en lecture seule**, qui ne proposent rien : ils constatent.

| Règle | Pourquoi |
|---|---|
| Un explorateur par contexte borné, plus un pour le transverse (routes, schéma, jobs, i18n, config, CI) et un pour l'UI | Des fichiers de sortie disjoints, comme des lots |
| Chaque feature suit le format fixe : **Acteur · Parcours · Règles métier (valeurs exactes) · Données · État · À refaire différemment** | Une feature se recode à partir de sa fiche, sans relire le code |
| L'état est **vérifié**, pas déduit : ✅ marche · ⚠️ fragile · ❌ cassé (avec l'erreur) · 💀 jamais exécuté (avec la preuve) | Trois features « acquises » de l'ancienne app n'avaient jamais tourné |
| **Toutes les branches** sont comparées à la branche inventoriée (`git rev-list --count HEAD..<branche>`) | Une feature peut vivre sur une branche non fusionnée |
| Chaque fiche signale les écarts avec les ADR et UDR, **sans trancher** | L'inventaire décrit ; la décision appartient au registre |
| Chaque fichier se termine par « Ce que je n'ai pas pu déterminer » | Un trou avoué se comble ; un trou masqué se paie en production |

---

## Modulateur d'équipage

| Rôle | Obligatoire ? | Ce qu'il fait ici |
|---|---|---|
| **Explorateurs** (phase 1) | oui si refonte | Produisent l'inventaire, en lecture seule, un par contexte |
| **Griller** (phase 1) | oui | Attaque le périmètre du programme : features oubliées, ordre, reprise des données |
| **Architecte** (phases 2-3) | oui | Tient les deux registres et la feuille de route |
| **Chantiers de vague** (phase 4) | 1 par chantier ouvert | Suivent leur propre cycle |
| **Recetteur** (phase 5) | oui, **distinct** des auteurs | Refait les parcours de la vague sur `Staging` |

---

## Portes de sortie — à copier dans `feuille-de-route.md`

```markdown
- [ ] Dépôt amorcé : les 7 garde-fous de la phase 0 prouvés par un commit refusé (si nouveau dépôt)
- [ ] `memo.md` complet, grill fait (≥ 1 ligne), hors périmètre non vide
- [ ] Inventaire complet : chaque table, route et branche non fusionnée rattachée ou déclarée morte
- [ ] `prd.md` cadre : matrice acteurs × permissions, exigences transverses
- [ ] Registre des décisions : chaque décision consommée par la vague en cours est `Accepté`
- [ ] Registre des contradictions : aucune contradiction ouverte ne touche la vague en cours
- [ ] Table de traçabilité : chaque feature a une vague ou une raison d'écart
- [ ] Vague livrée : chantiers clos, recette sur `Staging` refaite par un rôle distinct
- [ ] `feuille-de-route.md` et `journal.md` mis à jour après chaque vague
```

---

## Pièges spécifiques

| Piège | Symptôme | Parade |
|---|---|---|
| **Big bang** | « On livrera tout à la fin » | Chaque vague passe en recette seule. Sans livraison intermédiaire, rien n'est prouvé avant la fin |
| **L'inventaire pris pour une spec** | Un bug de l'ancien est reproduit « parce que le code faisait ça » | L'inventaire décrit. Le PRD du chantier de vague décide, sous les ADR |
| **Contradiction tranchée en silence** | Un agent choisit l'ADR le plus récent, un autre le glossaire | Registre des contradictions, puis ADR/UDR de remplacement |
| **Feuille de route gelée** | La vague 4 est détaillée avant que la vague 1 ait livré | Planning roulant : deux vagues détaillées au plus |
| **Garde-fous « pour plus tard »** | Le pre-commit arrive à la vague 2 | Phase 0 : les garde-fous précèdent le code métier, sans exception |
| **Feature « à reprendre » qui n'a jamais tourné** | Estimée comme un portage, se révèle une conception | L'état 💀 ou ❌ de l'inventaire impose un chantier feature complet, grill compris |
| **Seuil assoupli sous la pression** | `--no-verify` le soir de la livraison | Assouplir est permis ; le faire en silence ne l'est pas. Un ADR daté, ou rien |
