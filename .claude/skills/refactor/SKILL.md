---
name: refactor
description: Ouvre et cadre un chantier de refactoring Lnclass, à comportement observable strictement identique (couplage, namespace, duplication, couche violée). Utilise-la quand l'utilisateur tape /refactor <slug>, veut déplacer, renommer, découpler ou dédupliquer du code sans rien changer pour l'utilisateur.
---

# Cycle Refactoring

Tu exécutes le cycle décrit dans `docs/workflows/refactoring.md`. **Lis-le maintenant**, ainsi que `docs/workflows/README.md` (la **Table de routage** et **Les interdits** seulement) et `docs/guide/conventions.md` §2, §4 et §5 (le reste à la demande).

Argument : un `<slug>` kebab-case (`namespaces-dupliques`). S'il manque, demande-le.

**La règle qui domine tout le cycle : le comportement observable est identique avant et après.** Refactoring + changement de comportement dans le même lot = interdit (`docs/workflows/README.md#les-interdits`). Tu le répètes à l'utilisateur à chaque fois qu'une amélioration « au passage » est proposée.

---

## Étape 0 — Le test de la feature déguisée

Pose les quatre questions de `docs/workflows/refactoring.md`, **une par une**. Si **une seule** réponse est « oui », ce n'est pas un refactoring :

1. Un écran change, même légèrement ? (alors il faut une UDR → feature)
2. Un message d'erreur, un libellé, un tri, un arrondi change ?
3. Une permission devient plus ou moins permissive ?
4. Un champ apparaît ou disparaît d'une réponse ?

Dans ce cas : **deux chantiers, jamais un seul.** `refactor/<slug>` d'abord (iso-comportement, mergé), puis `feature/<slug>` sur une base propre. Dis-le et laisse l'utilisateur trancher.

Autres redirections : comportement actuel faux → `/bugfix` d'abord, refactoring ensuite. But = réduire un temps ou un nombre de requêtes → `/optimize`. Prod cassée → `/hotfix`.

## Étape 1 — État de départ

```bash
git rev-parse --abbrev-ref HEAD
git status --porcelain
```

Working tree sale → arrête-toi. Jamais de commit direct sur `main`.

```bash
git checkout -b refactor/<slug>
```

Branche existante → `git checkout refactor/<slug>`, chantier **repris**.

## Étape 2 — Scaffolder le chantier

```bash
test -d docs/chantiers/<slug> || cp -r docs/chantiers/_TEMPLATE docs/chantiers/<slug>
```

Dossier déjà présent → ne l'écrase pas, lis-le, annonce la phase atteinte, reprends. Supprime `prd.md` et `pr-faq.md` du chantier : **un refactoring n'a pas de PRD**.

En-tête de `docs/chantiers/<slug>/memo.md` (`date +%F`) :

```markdown
| **Type de cycle** | refactoring |
| **Statut** | cadrage |
| **Ouvert le** | <date du jour> |
| **Branche** | `refactor/<slug>` |
```

## Étape 3 — CADRER : motif + périmètre gelé

Trois blocs, obtenus par grill **une question à la fois**, écrits dans le memo au fur et à mesure :

| Bloc | Ce que tu exiges |
|---|---|
| **Motif** | Le **coût concret payé aujourd'hui** : bug récurrent, lot impossible à paralléliser, règle dupliquée en 3 endroits, `app/domain/` qui frôle l'ORM. « C'est plus propre » n'est pas un motif |
| **Périmètre gelé** | La **liste exhaustive des fichiers** touchés, écrite **avant** de commencer. C'est le contrat |
| **Hors périmètre** | Écrit littéralement : « aucun changement de comportement observable » |

Questions de grill propres à ce cycle :

1. Quel incident concret ce refactoring aurait-il évité ? Un exemple daté, pas une gêne.
2. Quel est le coût de **ne rien faire** ? (Cette réponse ira dans l'ADR §3.)
3. **Qui appelle le code déplacé ?** Recense les appelants avant de bouger quoi que ce soit — et pas seulement dans `app/` : cherche aussi dans `app/views/`, `test/fixtures/`, `config/`, `db/`.
   ```bash
   grep -rn "NomDeLaConstante" app test config db lib
   ```
4. La zone est-elle testée ? Une zone sans test est **la plus risquée** : c'est là que va l'effort, pas moins.
5. Quelles bizarreries du comportement actuel connais-tu, et sont-elles en fait des bugs ? Si oui : on les **fige telles quelles** ici et on ouvre un chantier bugfix séparé.

Un refactoring sans périmètre écrit à l'avance dérive systématiquement. Tout fichier découvert nécessaire en cours de route s'ajoute au memo **par une modification explicite**, jamais en silence.

Le memo doit ressortir du grill modifié — a minima, le périmètre s'est allongé des appelants oubliés.

## Étape 4 — DÉCIDER : **ADR obligatoire**

C'est le seul cycle où l'ADR est obligatoire **même si « on ne fait que déplacer du code »**. Un refactoring sans ADR se refait à l'envers six mois plus tard par quelqu'un qui ignorait pourquoi. Tu ne passes pas à l'étape 5 sans lui.

```bash
ls docs/decisions/adr/ | tail -3
cp docs/decisions/adr/TEMPLATE.md docs/decisions/adr/NNNN-titre-en-kebab-case.md
```

4 chiffres, kebab-case sans accent (`docs/guide/conventions.md` §2). Trois sections ne peuvent **pas** rester vides :

- **§3 Options envisagées** — y compris « ne rien faire », avec son coût.
- **§5 Coûts consentis** — un ADR sans coût consenti n'a pas été écrit honnêtement.
- **§7 Comment vérifier** — le test, le cop rubocop ou la commande qui **échoue si quelqu'un revient en arrière**. Un refactoring qui ne laisse pas de garde-fou sera défait. Exemple de garde-fou existant sur ce projet : `test/domain/domain_purity_stress_test.rb`.

Indexe l'ADR dans `docs/decisions/adr/README.md`.

**Pas de PRD. Pas d'UDR** — si une UDR devient nécessaire, ce n'est plus un refactoring : retour à l'étape 0.

## Étape 5 — PLANIFIER : lots par zone

Invoque la skill `plan-lots` avec le slug, en lui précisant que le découpage de ce cycle est **par zone** et non par cas d'usage :

- Un lot = une **zone** : un contexte borné, une couche, un namespace.
- Chaque lot est **mergeable seul et laisse l'application fonctionnelle**. Pas de « lot intermédiaire cassé rattrapé au lot suivant ».
- Fichiers partagés (`config/routes.rb`, `config/locales/fr.yml`, layouts) → Lot 0, comme toujours.
- Le champ `Done quand` s'écrit **toujours de la même manière** : « les characterization tests de la zone passent, inchangés ».

Copie dans `plan.md` les portes de sortie de `docs/workflows/refactoring.md`.

## Étape 6 — Le contrat d'exécution que tu imposes

Tu ne codes pas ici, mais tu graves la séquence dans `plan.md` et tu la rappelles :

1. **Écrire les characterization tests** : ils décrivent le comportement **actuel**, bizarreries comprises. Une bizarrerie qui est en fait un bug se **fige telle quelle** ici, et part en chantier bugfix séparé.
2. **Lancer : tout est vert avant la première modification.** C'est le filet.
   ```bash
   bin/rails test test/domain test/infrastructure
   ```
3. Refactoriser **par petits pas**, en relançant les characterization tests à chaque pas.
4. **Les characterization tests ne sont jamais modifiés pendant le refactoring.** Un test qu'il faut adapter est la preuve qu'un comportement a changé → **on annule le pas**.

Exception unique et documentée : le renommage d'une constante ou d'un namespace oblige à changer l'`include`/le nom de classe dans le test. Le corps des assertions reste identique — sinon ce n'est plus un renommage.

Contraintes permanentes : en-tête HITL sur tout fichier de `app/` (`docs/guide/conventions.md` §5, bloqué par `.githooks/pre-commit`), namespaces par contexte borné (§2), commits `refactor(<contexte>): …` (§4).

## Étape 7 — S'arrêter et présenter

Présente : le motif, le périmètre gelé (liste de fichiers), le numéro d'ADR et son garde-fou §7, le graphe de lots par zone, le dispatch proposé.

Rappelle le mandat du **challenger ISO**, non négociable en phase 5 : il **rejoue les parcours de la zone dans l'application, avant/après**, compare libellés, tri, erreurs, permissions, contenu ; il lit le diff en cherchant les `if`, `rescue` et valeurs par défaut **nouveaux** ; il vérifie que le garde-fou de l'ADR §7 échoue bien si on revient en arrière. **Il lui est interdit de commenter le style** — c'est le travail de rubocop. « Le code est plus lisible » n'est pas une preuve.

Demande **« Je lance les lots ? »** et attends.

```bash
git add docs/chantiers/<slug> docs/decisions
git commit -m "docs(docs): open chantier <slug> — scope and ADR"
```
