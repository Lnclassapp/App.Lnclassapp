# Le workflow Lnclass

> **C'est le seul processus de développement valide.** Les workflows de la v1 (`docs/WORKFLOW.md`, `docs/STANDARD/workflow.md`, `CHEATSHEET.md`) sont gelés dans [`../archives/`](../archives/) et ne font plus foi.

Tout travail sur Lnclass — une feature, un bug, un refactoring, une optimisation — suit les mêmes **5 phases**. Ce qui change d'un type de cycle à l'autre, ce n'est pas la nature des phases, c'est leur **poids** : voir la [table de routage](#table-de-routage) plus bas.

---

## Les 5 phases

```
1. CADRER  ──►  2. DÉCIDER  ──►  3. PLANIFIER  ──►  4. EXÉCUTER  ──►  5. PROUVER
   memo.md        prd.md            plan.md           le code          la PR
                  ADR / UDR         graphe de lots
```

### Phase 1 — CADRER

**Produit** : `docs/chantiers/<slug>/memo.md`

On part d'une idée brute et on élimine les zones d'ombre **avant** de parler technique.

1. Écrire le memo : le problème, pour qui, pourquoi maintenant, ce qui est hors périmètre.
2. **Se faire griller** : une session de questions-réponses adverses sur les specs, les cas limites, les règles métier. L'objectif n'est pas de valider l'idée, c'est de la casser pendant qu'elle est encore gratuite à changer.
3. Mettre le memo à jour avec ce que le grill a révélé.

> Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

### Phase 2 — DÉCIDER

**Produit** : `prd.md` + un [ADR](../decisions/adr/) si l'architecture bouge + une [UDR](../decisions/udr/) si l'interface bouge

1. **PRD** — figer les specs : contexte, acteurs et permissions, parcours utilisateur, critères d'acceptation vérifiables.
2. **ADR** — dès qu'un choix technique engage l'avenir (nouveau port, stratégie de persistance, dépendance, changement de contrat). Un ADR se relit dans deux ans : il dit le *contexte* et les *conséquences*, pas seulement la décision.
3. **UDR** — dès qu'une vue est créée ou modifiée. L'UDR n'est pas un compte-rendu, c'est une **consigne exécutable par un agent** : quels tokens, quels états, quel comportement Turbo, quelle accessibilité.

Les décisions se prennent **maintenant**, pas après le code. Un ADR écrit une fois le code livré ne décide rien, il justifie.

### Phase 3 — PLANIFIER

**Produit** : `plan.md` — un graphe de lots au [format gelé](../guide/conventions.md#6-format-dun-lot)

Le découpage est **vertical** : un lot = un cas d'usage complet, de la migration au pixel.

```
Lot 0 — SOCLE (séquentiel, court)
  migration · entités · PORTS (contrats gelés) · fichiers partagés
  (routes.rb, locales, layouts, navigation)
  ↓
  ├─► Lot A « cas d'usage 1 »   ┐
  ├─► Lot B « cas d'usage 2 »   ├─  en parallèle, fichiers disjoints
  └─► Lot C « cas d'usage 3 »   ┘
```

Trois règles :
1. **Le Lot 0 gèle les contrats.** Les lots verticaux implémentent les ports, ils ne les redéfinissent pas.
2. **Les fichiers partagés appartiennent au Lot 0.** C'est là que sont les vraies collisions.
3. **Deux lots parallèles ne listent jamais le même fichier.** Si ça arrive, le fichier remonte au Lot 0.

**On ne décide pas d'un nombre d'agents.** Le nombre d'agents est égal au nombre de lots sans dépendance en attente. Chacun travaille dans son worktree git isolé.

### Phase 4 — EXÉCUTER

**Produit** : le code

L'ordre est imposé par l'architecture hexagonale, **à l'intérieur de chaque lot** :

| Ordre | Couche | Contrainte |
|---|---|---|
| 1 | **Test** | Écrit avant le code, et il doit **échouer** — un test qui passe du premier coup ne prouve rien |
| 2 | **Domaine** (`app/domain/`) | Ruby pur. Zéro ActiveRecord. Le pre-commit le vérifie. |
| 3 | **Infrastructure** (`app/infrastructure/`) | Migrations, modèles `Orm::`, repositories implémentant les ports |
| 4 | **Delivery** (`app/controllers/`) | Transforme les params, appelle le use case, décide du rendu. Zéro logique métier. |
| 5 | **UI** (`app/views/`, `app/javascript/`) | Régie par l'UDR |

Chaque fichier créé porte son [en-tête HITL](../guide/conventions.md#5-en-tête-hitl) de 3 lignes.

### Phase 5 — PROUVER

**Produit** : une PR qui passe

C'est la phase que la v1 n'avait pas, et c'est celle qui manquait le plus.

1. **Contradiction empirique** — un rôle distinct de celui qui a écrit le code **exécute** : il lance les tests, ouvre l'application, refait le parcours, mesure. Il ne relit pas le code, il le met à l'épreuve.
2. **Les portes** — pureté du domaine, rubocop, tests, parcours système, brakeman. Voir [ce qui bloque](../guide/conventions.md#7-ce-qui-bloque).
3. **PR unique** vers `Develop`, référençant le chantier, l'ADR et l'UDR.
4. **Clôture** — `journal.md` du chantier mis à jour : ce qui a été appris, ce qui a dérapé, ce qui reste ouvert.

> Un reviewer qui lit du code ne prouve rien. Un challenger qui l'exécute prouve.

---

## Table de routage

Toutes les phases existent toujours. Leur poids change.

| | **Feature** | **Bugfix** | **Refactoring** | **Optimisation** | **Hotfix** |
|---|---|---|---|---|---|
| **1. Cadrer** | Memo + grill complet | Symptôme + reproduction | Motif du refactoring, périmètre gelé | Mesure **avant**, chiffrée | Constat, 3 lignes |
| **2. Décider** | PRD + ADR si archi + **UDR si vue** | ADR seulement si la cause est architecturale | **ADR obligatoire** | ADR si le contrat change | Aucun — rattrapé après |
| **3. Planifier** | Graphe de lots complet | Souvent un seul lot | Lots par zone, iso-comportement | Un lot par optimisation mesurable | Pas de plan |
| **4. Exécuter** | Toutes les couches | **Test de reproduction rouge d'abord** | **Characterization tests d'abord** | Le bench sert de test | Correctif minimal |
| **5. Prouver** | Challenger empirique | Le test de reproduction passe au vert | Le challenger vérifie que **rien** n'a changé fonctionnellement | **Bench après, chiffré.** Pas de chiffre = rejet | Vérification manuelle + chantier de suivi obligatoire |

Détail de chaque cycle : [`feature.md`](feature.md) · [`bugfix.md`](bugfix.md) · [`refactoring.md`](refactoring.md) · [`optimisation.md`](optimisation.md) · [`hotfix.md`](hotfix.md)

### Au-dessus des cycles : le programme

Quand l'objectif ne tient pas dans un seul graphe de lots — une refonte, un nouveau dépôt, un contexte borné construit de zéro — on ouvre un **programme** : [`programme.md`](programme.md). Il ajoute une phase 0 d'amorçage du dépôt, planifie **par vagues** et ouvre, vague par vague, des chantiers ordinaires qui suivent la table ci-dessus sans exception.

---

## Les interdits

Quel que soit le cycle :

- **Patcher un bug sans test de reproduction.** Le test s'écrit avant le correctif et doit échouer.
- **Refactoriser et changer le comportement dans le même lot.** Un refactoring qui change un comportement est une feature déguisée.
- **Optimiser sans mesure avant et après.** Sans chiffres, ce n'est pas une optimisation, c'est une intuition.
- **Écrire une vue sans UDR.** C'est ce qui produit des interfaces incohérentes d'une session à l'autre.
- **Livrer sans qu'un rôle distinct ait exécuté le résultat.**

---

## Déclencher un cycle

Le processus est outillé. Dans Claude Code :

```
/feature <slug>       ouvre un chantier de fonctionnalité
/bugfix <slug>        ouvre un chantier de correction
/refactor <slug>      ouvre un chantier de refactoring
/optimize <slug>      ouvre un chantier d'optimisation
/hotfix <slug>        ouvre un correctif d'urgence + son chantier de suivi
```

Un programme n'a pas de commande : on copie `docs/chantiers/_TEMPLATE/` dans `docs/chantiers/<programme>/`, on y ajoute `feuille-de-route.md` et, pour une refonte, `inventaire/` — voir [`programme.md`](programme.md).

La commande crée le dossier du chantier, lance la phase 1, et t'accompagne jusqu'au plan de lots. Si tu travailles sans Claude Code, copie `docs/chantiers/_TEMPLATE/` à la main — le processus est le même.
