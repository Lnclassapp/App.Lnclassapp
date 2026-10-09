---
name: feature
description: Ouvre et cadre un chantier de fonctionnalité Lnclass (un acteur pourra faire quelque chose de nouveau). Utilise-la quand l'utilisateur tape /feature <slug>, demande d'ajouter une fonctionnalité, un écran, une table ou un port, ou dit « on va faire X » sans qu'un comportement existant soit cassé.
---

# Cycle Feature

Tu exécutes le cycle décrit dans `docs/workflows/feature.md`. **Lis-le maintenant**, ainsi que `docs/workflows/README.md` (la **Table de routage** et **Les interdits** seulement) et `docs/guide/conventions.md` §2, §4 et §6 (le reste à la demande). Cette skill ne remplace pas ces documents : elle les joue. En cas de contradiction, la doc gagne — et signale la contradiction à l'utilisateur.

Argument attendu : un `<slug>` en kebab-case, court, sans type ni numéro (`messagerie-classe`, pas `feature-5-messagerie`). S'il manque, demande-le avant toute commande.

**Tu cadres et tu planifies. Tu ne codes pas.** Cette skill s'arrête à la fin de la phase 3, sur une validation utilisateur explicite.

---

## Étape 0 — Vérifier que c'est bien une feature

Avant de créer quoi que ce soit, passe le tableau « Quand utiliser ce cycle » de `docs/workflows/feature.md`. Si le comportement attendu existe déjà et ne marche pas → arrête et propose `/bugfix`. Si le comportement observable est identique après → `/refactor`. Si seul le temps de réponse change → `/optimize`. Si la prod est cassée maintenant → `/hotfix`.

## Étape 1 — État de départ

```bash
git rev-parse --abbrev-ref HEAD
git status --porcelain
```

- Working tree sale → **arrête-toi** et demande à l'utilisateur de committer ou stasher. Ne stash jamais de ton propre chef.
- Sur `Develop` ou `main` → crée la branche **depuis `Develop`** (`git switch -c feature/<slug> Develop`). Sur une autre branche de chantier → demande confirmation avant de brancher par-dessus.
- Jamais de commit direct sur `Develop`, `Staging` ni `main` (`docs/guide/conventions.md` §3).
- Si la feature est une vague d'un programme, renseigne la ligne `Programme :` du memo et lis `docs/workflows/programme.md` et la `feuille-de-route.md` du programme avant la phase 2.

```bash
git checkout -b feature/<slug>
```

Si la branche existe déjà : `git checkout feature/<slug>` et considère que le chantier est **repris**, pas ouvert.

## Étape 2 — Scaffolder le chantier

```bash
test -d docs/chantiers/<slug> || cp -r docs/chantiers/_TEMPLATE docs/chantiers/<slug>
ls docs/chantiers/<slug>
```

**Si le dossier existait déjà** : ne l'écrase sous aucun prétexte. Lis `memo.md`, `prd.md`, `plan.md`, `journal.md`, déduis la phase atteinte du champ `Statut` du memo et des sections déjà remplies, annonce à l'utilisateur où en est le chantier, et reprends à cette phase.

`pr-faq.md` est optionnel (`docs/chantiers/README.md`) : garde-le seulement si le chantier est gros, sinon supprime-le du dossier et dis-le.

Pré-remplis l'en-tête de `docs/chantiers/<slug>/memo.md` (date via `date +%F`) :

```markdown
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | <date du jour> |
| **Branche** | `feature/<slug>` |
```

Remplace aussi `[Titre du chantier]` par un vrai titre en français dans les quatre fichiers.

## Étape 3 — CADRER : le grill

Poids **maximum** ici. Remplis d'abord, avec l'utilisateur, `Le problème`, `Pour qui`, `Pourquoi maintenant`, `Hors périmètre`.

Puis **grille**. Règles du grill :

- **Une seule question à la fois.** Tu attends la réponse avant la suivante. Une salve de 8 questions n'est pas un grill, c'est un formulaire.
- Tu écris la réponse dans le tableau `Ce que le grill a révélé` **au fur et à mesure**, avec sa colonne `Conséquence sur le chantier`. Pas de rattrapage à la fin.
- Tu attaques, tu ne valides pas. Ton but est de casser l'idée pendant qu'elle est encore gratuite à changer.
- **Minimum 5 questions**, et tu continues tant que tes questions produisent encore des conséquences.

Angles d'attaque obligatoires pour une feature (source : `docs/workflows/feature.md` §1) :

1. **Acteurs oubliés** — `Parent`, `SchoolStaff`, `Team` : que voient-ils, que peuvent-ils faire ? Réponse « rien » acceptée seulement si elle est écrite dans `Hors périmètre`.
2. **Multi-appartenance élève** — un élève rattaché à plusieurs classes ou plusieurs établissements : doublon ? Quelle vue fait foi ?
3. **Permissions inter-établissements** — un enseignant intervenant dans deux écoles.
4. **Cas limites de données** — zéro élément, un seul, mille ; suppression d'un objet référencé ; acteur désactivé.
5. **Frontière du périmètre** — quelle demande adjacente refuses-tu explicitement ?
6. **Contexte borné concerné** — `assessment`, `catalog`, `classroom`, `communication`, `identity`, `school` (`docs/guide/conventions.md` §2). Si la feature en traverse deux, lequel porte la règle ?

**Porte de sortie du grill** : le tableau `Ce que le grill a révélé` a au moins une ligne **et** le memo a changé par rapport à sa première version. Si le memo ressort inchangé, le grill a été raté — recommence avec des questions plus dures. Dis-le à l'utilisateur, ne le cache pas.

Termine la phase en remplissant `Cas limites identifiés` et `Questions encore ouvertes`, et passe le `Statut` du memo à `décision`.

**Non négociable** : aucun nom de fichier, aucun nom de classe dans le memo. On parle métier.

## Étape 4 — DÉCIDER

Avant d'inventer quoi que ce soit, **explore l'existant** si le contexte borné existe déjà : recense les use cases, ports et queries en place sous `app/domain/` et `app/infrastructure/`. On ne crée pas un port qui existe.

### 4.1 `prd.md` — toujours

Remplis `docs/chantiers/<slug>/prd.md` en entier. Les critères d'acceptation (§4) sont en Gherkin et **chacun deviendra un test**. Un critère non testable se réécrit.

### 4.2 ADR — si l'architecture bouge

Obligatoire dès qu'apparaît : un nouveau port, une nouvelle table, une nouvelle dépendance, un changement de contrat, une nouvelle stratégie de persistance. Sautable si le chantier n'ajoute qu'un use case sur des ports existants — dans ce cas, **écris-le explicitement** dans `prd.md` §6.

```bash
ls docs/decisions/adr/ | tail -3        # dernier numéro
cp docs/decisions/adr/TEMPLATE.md docs/decisions/adr/NNNN-titre-en-kebab-case.md
```

4 chiffres, kebab-case sans accent (`docs/guide/conventions.md` §2). Puis ajoute la ligne dans `docs/decisions/adr/README.md`. §5 `Coûts consentis` et §7 `Comment vérifier` ne restent jamais vides.

### 4.3 UDR — **obligatoire dès qu'une vue est créée ou modifiée**

Sans exception. Une vue « simple » n'existe pas : c'est ce qui produit des interfaces incohérentes d'une session à l'autre.

```bash
ls docs/decisions/udr/ | tail -3
cp docs/decisions/udr/TEMPLATE.md docs/decisions/udr/NNNN-titre-en-kebab-case.md
```

Test de conformité de l'UDR : **un agent doit pouvoir écrire la vue à partir de la seule §3, sans poser de question.** Relis la §3 et demande-toi si tu y arriverais. Si la réponse est non, elle n'est pas finie. Les quatre états (vide · chargement · erreur · succès), la cible Turbo et les `aria-*` sont nommés, pas suggérés. Indexe dans `docs/decisions/udr/README.md`.

Reporte les numéros produits dans `prd.md` §6, et passe le `Statut` du memo à `planifié`.

## Étape 5 — PLANIFIER

Invoque la skill `plan-lots` avec le slug. Elle lit `prd.md` et écrit `docs/chantiers/<slug>/plan.md`.

Complète ensuite `plan.md` avec les portes de sortie de `docs/workflows/feature.md` (section « Portes de sortie »), copiées telles quelles.

## Étape 6 — S'arrêter et présenter

Tu **ne codes pas**. Présente à l'utilisateur :

- le graphe de lots et le dispatch proposé (quels lots partent ensemble) ;
- les ADR/UDR produits ;
- les questions restées ouvertes dans le memo ;
- le rappel que la phase 5 exige un **challenger empirique**, un rôle distinct de l'auteur, qui **exécute** le parcours nominal *et* un chemin d'erreur du PRD au lieu de relire le code.

Puis demande explicitement : **« Je lance les lots ? »** et attends.

Commit du cadrage (les docs seulement) :

```bash
git add docs/chantiers/<slug> docs/decisions
git commit -m "docs(docs): open chantier <slug> — memo, prd, plan"
```

## Rappels d'exécution (phase 4, quand elle viendra)

Dans **chaque** lot : test rouge d'abord → `app/domain/` (Ruby pur, zéro `ActiveRecord`/`Orm::`) → `app/infrastructure/` → `app/controllers/` → vues. En-tête HITL 3 lignes sur chaque fichier de `app/` (`docs/guide/conventions.md` §5) — le hook `.githooks/pre-commit` le bloque sinon. Blueprints de couche : `docs/blueprints/`. Un lot vertical n'a **jamais** le droit de redéfinir un port : il s'arrête, le Lot 0 rouvre.
