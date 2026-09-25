---
name: bugfix
description: Ouvre et cadre un chantier de correction Lnclass (un comportement documenté ne se produit pas, mais la prod tient et un contournement existe). Utilise-la quand l'utilisateur tape /bugfix <slug>, signale un bug, une régression, un écran qui affiche le mauvais résultat, ou dit « ça ne marche pas ».
---

# Cycle Bugfix

Tu exécutes le cycle décrit dans `docs/workflows/bugfix.md`. **Lis-le maintenant**, ainsi que `docs/workflows/README.md` et `docs/guide/conventions.md`. Cette skill joue ces documents, elle ne les remplace pas.

Argument : un `<slug>` kebab-case (`login-contact-vide`). S'il manque, demande-le.

**La règle qui domine tout le cycle : le test de reproduction s'écrit AVANT le correctif et DOIT échouer.** Tu refuses de passer à la correction tant que tu n'as pas vu ce test rouge, pour la bonne raison. Ce n'est pas une préférence, c'est un interdit (`docs/workflows/README.md#les-interdits`).

---

## Étape 0 — Vérifier que c'est bien un bugfix

Tableau « Quand utiliser ce cycle » de `docs/workflows/bugfix.md` :

- Le comportement n'a **jamais** été spécifié → ce n'est pas un bug, c'est une spec manquante → `/feature`.
- Le résultat est correct mais lent → `/optimize`.
- Rien n'est cassé, le code est juste pénible → `/refactor`.
- La prod est cassée **maintenant, sans contournement** → `/hotfix`.

**Test du bug déguisé** : si le correctif exige une colonne, un port ou une règle métier qui n'existait nulle part, ferme et rouvre en feature. Pose la question tôt, pas après le test rouge.

## Étape 1 — État de départ

```bash
git rev-parse --abbrev-ref HEAD
git status --porcelain
```

Working tree sale → arrête-toi et demande à l'utilisateur de committer ou stasher. Jamais de commit direct sur `main` (`docs/guide/conventions.md` §3).

```bash
git checkout -b fix/<slug>
```

Branche déjà existante → `git checkout fix/<slug>`, le chantier est **repris**.

## Étape 2 — Scaffolder le chantier

```bash
test -d docs/chantiers/<slug> || cp -r docs/chantiers/_TEMPLATE docs/chantiers/<slug>
```

Dossier déjà présent → ne l'écrase pas : lis `memo.md` et `journal.md`, annonce la phase atteinte, reprends là. Supprime `pr-faq.md` du chantier (inutile pour un bug).

En-tête de `docs/chantiers/<slug>/memo.md` (date via `date +%F`) :

```markdown
| **Type de cycle** | bugfix |
| **Statut** | cadrage |
| **Ouvert le** | <date du jour> |
| **Branche** | `fix/<slug>` |
```

## Étape 3 — CADRER : symptôme et reproduction

Le memo est allégé, mais **trois blocs sont non négociables**. Grille l'utilisateur pour les obtenir, **une question à la fois**, et écris chaque réponse dans le memo au fur et à mesure.

| Bloc | Ce que tu dois obtenir |
|---|---|
| **Symptôme** | Ce que l'utilisateur voit, **littéralement**. Pas d'interprétation, pas de diagnostic. « Il obtient X au lieu de Y. » |
| **Reproduction** | Étapes exactes, acteur, données, environnement. Si l'utilisateur ne sait pas reproduire, tu ne sais pas corriger — c'est le premier obstacle à lever |
| **Portée** | Depuis quand · combien d'acteurs touchés · **des données déjà corrompues à réparer, oui ou non ?** |

Questions de grill propres à ce cycle :

1. Quel document dit que le comportement attendu est Y ? (PRD antérieur, ADR, UDR, test existant.) Pas de source → c'est peut-être une feature.
2. Depuis quel déploiement / commit ? `git log` sur les fichiers suspects.
3. **Multi-appartenance** : reproduit-on aussi le bug sur un élève rattaché à plusieurs classes ou plusieurs écoles ? C'est le piège récurrent du projet.
4. Quels autres acteurs (`Parent`, `SchoolStaff`, `Team`) passent par le même chemin ?
5. Des données déjà écrites sont-elles fausses en base ? Si oui, réparation ou dette assumée — tranché maintenant, écrit dans le memo.

`Hors périmètre` sert ici à interdire le « pendant que j'y suis » : tout ce qu'on remarque à côté part dans `journal.md` → chantier de suivi.

**Porte** : tu as reproduit le bug **à la main dans l'application** (ou l'utilisateur l'a fait devant toi et tu as consigné les étapes) avant toute ligne de code. Si tu ne peux pas, dis-le et arrête le chantier là.

## Étape 4 — DÉCIDER : la root cause, pas le symptôme

C'est la phase qui décide de la qualité du cycle. **Pas de PRD.**

### 4.1 Rapport de root cause — obligatoire, sans exception

Remonte du symptôme à la cause. Tu peux déléguer cette recherche à un agent `Explore`, mais le rapport doit répondre à **trois questions** :

1. Quelle est la **chaîne d'appels** du point d'entrée au point fautif ?
2. Quel **fichier et quelle ligne** portent la cause — pas l'endroit où ça s'affiche mal ?
3. **Pourquoi aucun test existant n'a détecté ça ?** La réponse dicte où placer le test de reproduction.

Écris le rapport dans `journal.md`, section `Ce qu'on a appris sur la codebase`.

**Tu refuses de passer à l'étape 5 sans ce rapport.** Un correctif posé sur le symptôme fait revenir le bug ailleurs dans quinze jours.

Test de contrôle : reformule la cause en une phrase qui ne contient **pas** les mots du symptôme. Si tu n'y arrives pas, tu n'as pas la cause.

### 4.2 ADR — seulement si la cause est architecturale

Port mal découpé, règle métier logée dans un contrôleur, contrat de retour ambigu → ADR écrit **avant** le correctif :

```bash
ls docs/decisions/adr/ | tail -3
cp docs/decisions/adr/TEMPLATE.md docs/decisions/adr/NNNN-titre-en-kebab-case.md
```

Puis indexe dans `docs/decisions/adr/README.md`.

### 4.3 UDR — seulement si la correction change ce que l'utilisateur voit

État d'erreur, libellé, parcours. Un bug purement backend n'en produit pas. Template : `docs/decisions/udr/TEMPLATE.md`, index `docs/decisions/udr/README.md`.

## Étape 5 — PLANIFIER

Souvent **un seul lot**. Tu peux sauter `plan.md` **si et seulement si** : un seul lot, aucun fichier partagé touché, aucune migration. Dans ce cas les portes de sortie migrent dans `memo.md` et tu supprimes `plan.md` du chantier.

Deux lots ou plus dès qu'il y a une réparation de données : Lot 0 = correctif de code, Lot A = tâche de réparation des données déjà corrompues. Dans ce cas, invoque la skill `plan-lots`.

Copie dans `plan.md` (ou `memo.md`) les portes de sortie de `docs/workflows/bugfix.md`, telles quelles.

## Étape 6 — Le contrat d'exécution que tu imposes

Tu **ne codes pas** dans cette skill. Mais tu écris noir sur blanc dans le plan, et tu le redis à l'utilisateur, la séquence à laquelle l'exécutant est tenu :

1. **Écrire le test de reproduction** au niveau le plus bas qui reproduit le bug : domaine > infrastructure > contrôleur > intégration. Arborescence : `test/domain/`, `test/infrastructure/`, `test/controllers/`, `test/integration/`.
2. **Le lancer et le voir échouer** — et échouer *pour la bonne raison* : on lit le message, pas seulement le rouge.
   ```bash
   bin/rails test test/domain/use_cases/<contexte>/<nom>_test.rb
   ```
3. Corriger **à la cause**, dans la couche où vit la cause. Un mauvais rendu causé par une règle métier se corrige dans `app/domain/`, jamais dans le `.erb`.
4. Relancer : vert.
5. Relancer la suite du contexte borné : rien d'autre n'a bougé.

**Un test qui passe du premier coup ne reproduit pas le bug.** Il ne prouve rien : il est à jeter et à réécrire plus bas dans la pile. Dis-le explicitement si ça arrive.

## Étape 7 — S'arrêter et présenter

Présente : le symptôme, la cause (fichier + ligne), le trou de test identifié, l'emplacement prévu du test de reproduction, le ou les lots. Rappelle que la phase 5 exige un **challenger empirique** qui **rejoue les étapes de reproduction du memo dans l'application** — pas seulement la suite de tests — et vérifie le **cas symétrique** (le chemin nominal voisin marche toujours).

Demande **« Je lance la correction ? »** et attends.

Commit du cadrage :

```bash
git add docs/chantiers/<slug> docs/decisions
git commit -m "docs(docs): open chantier <slug> — root cause and repro"
```

Rappel pour le commit du correctif (`docs/guide/conventions.md` §4) : `fix(<contexte>): …` avec en pied de message `Chantier: docs/chantiers/<slug>`.
