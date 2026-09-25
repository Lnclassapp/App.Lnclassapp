---
name: optimize
description: Ouvre et cadre un chantier d'optimisation Lnclass, quand le résultat est correct mais trop lent, trop gourmand ou fait trop de requêtes. Utilise-la quand l'utilisateur tape /optimize <slug>, parle de N+1, de page qui rame, de job qui time out, de mémoire qui explose ou de performance.
---

# Cycle Optimisation

Tu exécutes le cycle décrit dans `docs/workflows/optimisation.md`. **Lis-le maintenant** — notamment la section « Quoi mesurer, et comment, sur ce projet », qui donne la métrique et le protocole par symptôme — ainsi que `docs/workflows/README.md` et `docs/guide/conventions.md`.

Argument : un `<slug>` kebab-case (`import-ecoles-bulk`). S'il manque, demande-le.

**La règle qui domine tout le cycle : mesure chiffrée AVANT dans le memo, bench chiffré APRÈS en phase 5. Pas de chiffre = rejet automatique**, à l'entrée comme à la sortie. Tu appliques ce rejet, tu ne le contournes pas.

---

## Étape 0 — Le chantier n'ouvre pas sans un nombre

**Test de l'optimisation déguisée** : si l'utilisateur ne peut pas produire un nombre avant qu'une ligne de code soit écrite, il n'a pas un chantier d'optimisation — il a une intuition. **Tu n'ouvres pas le chantier.** Tu proposes de commencer par prendre la mesure.

Redirections : résultat faux → `/bugfix`. « Du code plus propre » → `/refactor`. Un écran ou une capacité change → `/feature`. Prod down maintenant → `/hotfix`, et l'optimisation devient le chantier de suivi.

## Étape 1 — État de départ

```bash
git rev-parse --abbrev-ref HEAD
git status --porcelain
```

Working tree sale → arrête-toi. **Important pour ce cycle** : la mesure avant se prend sur un arbre propre, sinon elle ne sera pas reproductible par le challenger.

```bash
git checkout -b perf/<slug>
```

Branche existante → `git checkout perf/<slug>`, chantier **repris**.

## Étape 2 — Scaffolder le chantier

```bash
test -d docs/chantiers/<slug> || cp -r docs/chantiers/_TEMPLATE docs/chantiers/<slug>
```

Dossier déjà présent → ne l'écrase pas ; lis le tableau de mesures déjà rempli et reprends là. Supprime `pr-faq.md`.

En-tête de `docs/chantiers/<slug>/memo.md` (`date +%F`) :

```markdown
| **Type de cycle** | optimisation |
| **Statut** | cadrage |
| **Ouvert le** | <date du jour> |
| **Branche** | `perf/<slug>` |
```

## Étape 3 — CADRER : le chiffre AVANT

**Le memo n'ouvre pas sans ce tableau**, que tu ajoutes dans `memo.md` :

```markdown
## Mesure avant

| Métrique | Contexte / volume | Valeur avant | Cible | Comment mesurée |
|---|---|---|---|---|
| Durée `ImportSchoolsJsonJob` | 1 école, 12 classes, 45 élèves/classe | 47 s (timeout) | < 5 s | `Benchmark.realtime` |
```

Grill, **une question à la fois**, réponse écrite au fur et à mesure :

1. **Quelle métrique exactement ?** Durée, nombre de requêtes SQL, objets alloués, temps `View` du log Rails. Choisis-la dans le tableau « Quoi mesurer » de `docs/workflows/optimisation.md`.
2. **Sur quel volume de données ?** « 1 école, 12 classes, 45 élèves démo par classe ». **Une mesure sans volume précisé n'est pas une mesure** — et mesurer sur 3 lignes de fixture produit un gain spectaculaire en dev et nul en prod.
3. **Quelle est la valeur aujourd'hui ?** Si personne ne l'a prise, prends-la maintenant, avant de continuer. Tu ne remplis pas cette case avec une estimation.
4. **Quelle est la cible chiffrée ?** « < 300 ms », « ≤ 5 requêtes », « 1 job au lieu de 4 000 INSERT ». Pas « plus rapide ».
5. **Le protocole est-il reproductible par quelqu'un d'autre ?** Écris-le assez précisément pour que le challenger le rejoue sans te poser de question. C'est lui qui validera ou rejettera la PR.
6. **Qu'est-ce qu'on n'optimise pas ?** `Hors périmètre`, sinon le chantier absorbe toute la couche.

**Porte de sortie du cadrage** : les cinq colonnes du tableau sont remplies avec des valeurs réelles. Une case vide ou une valeur estimée → tu t'arrêtes et tu le dis.

## Étape 4 — DÉCIDER : où part réellement le temps

### 4.1 Localiser le coût — obligatoire

Le goulot n'est presque jamais là où on le croit. Mesure, ne suppose pas : requêtes, allocations, sérialisation. Tu peux déléguer cette exploration à un agent `Explore`, mais le rapport doit nommer **le fichier et la ligne** qui portent le coût, avec le chiffre associé. Écris-le dans `journal.md`.

Leviers déjà entérinés sur ce projet (`docs/workflows/optimisation.md`) : séparation lecture/écriture via `app/infrastructure/queries/` (ADR-0006), bulk insert `insert_all!`/`upsert_all` dans les repositories (ADR-0020).

### 4.2 ADR — si un contrat change

**Obligatoire** si : port modifié, callbacks contournés, invariant désormais garanti à la main, dénormalisation, cache introduit. Un contournement de callbacks (`insert_all!`) est **toujours** un ADR : il déplace une garantie du framework vers ton code — il faut alors générer explicitement `public_id`, `unique_code`, `slug`.

**Pas d'ADR** si l'optimisation reste locale : index ajouté, `includes` correctement posé, `select` restreint.

```bash
ls docs/decisions/adr/ | tail -3
cp docs/decisions/adr/TEMPLATE.md docs/decisions/adr/NNNN-titre-en-kebab-case.md
```

Indexe dans `docs/decisions/adr/README.md`.

**Pas d'UDR** — si l'écran change, ce n'est plus une optimisation : retour à l'étape 0.

## Étape 5 — PLANIFIER : un lot = un levier = un chiffre

Invoque la skill `plan-lots` avec le slug, en lui précisant la règle propre à ce cycle :

- **Un lot = un levier mesurable séparément.** Deux leviers dans le même lot et on ne sait plus lequel a payé.
- `Done quand` s'écrit **toujours en chiffres** : « l'import d'une école passe de 47 s à < 5 s, mesuré au même volume ».
- Ordonne les lots par **ratio gain/risque décroissant** et arrête-toi dès que la cible est atteinte. Un lot devenu inutile se **ferme**, il ne se joue pas « par principe ».

Copie dans `plan.md` les portes de sortie de `docs/workflows/optimisation.md`.

## Étape 6 — Le contrat d'exécution que tu imposes

Grave la séquence dans `plan.md` :

1. **Écrire le bench reproductible** (script ou test) qui produit la valeur *avant*. Il est **versionné** — dans `docs/chantiers/<slug>/` ou dans `test/`.
2. **Écrire ou vérifier les tests de non-régression fonctionnelle** : l'optimisation ne change **rien** au résultat. Ils sont verts avant le premier levier.
3. Appliquer **un seul levier**, relancer le bench, noter le chiffre.
4. **Gain nul ou marginal → annuler le pas.** Une complexité ajoutée sans gain mesuré se retire. Du code illisible « au cas où » n'est pas gardé.

La correction va dans la couche qui porte le coût — le plus souvent `app/infrastructure/queries/` ou `app/infrastructure/repositories/`, **jamais dans la vue**. Un cache posé sur un N+1 masque le problème au lieu de le résoudre : on corrige la requête d'abord.

## Étape 7 — Le refus de conclure sans bench après

Tu écris cette condition dans `plan.md` et tu la répètes à l'utilisateur : **le chantier ne se clôt pas sans mesure après.**

Le tableau §7 `Mesures` de `prd.md` (ou celui du memo s'il n'y a pas de PRD) est complété colonne **Après** avec :

- la **même machine**, le **même volume**, la **même méthode** qu'avant ;
- **au moins 3 exécutions**, médiane retenue — une mesure unique n'est pas une mesure ;
- les tests fonctionnels toujours verts.

**Sans chiffre après, la PR est rejetée.** Et le challenger de ce cycle ne lit pas le code : **il relance lui-même le bench sur sa machine**. S'il n'obtient pas le gain annoncé, la PR ne passe pas. Un gain non reproductible est un gain non prouvé.

## Étape 8 — S'arrêter et présenter

Présente : la métrique, la valeur avant, le volume, la cible, le protocole, l'ADR éventuel, le graphe de lots (un levier par lot, ordonné par gain/risque), le dispatch proposé. Rappelle la clause de rejet ci-dessus.

Demande **« Je lance les leviers ? »** et attends.

```bash
git add docs/chantiers/<slug> docs/decisions
git commit -m "docs(docs): open chantier <slug> — baseline measurement"
```

Commits d'exécution : `perf(<contexte>): …` (`docs/guide/conventions.md` §4). Et à la clôture, `journal.md` porte les **leviers abandonnés et pourquoi** — c'est la partie la plus réutilisable du chantier.
