---
name: plan-lots
description: Transforme le PRD d'un chantier Lnclass en graphe de lots parallélisables et écrit docs/chantiers/<slug>/plan.md. Utilise-la à la phase 3 de n'importe quel cycle, quand l'utilisateur tape /plan-lots <slug>, demande de découper un chantier en lots, de paralléliser du travail, ou de préparer le dispatch des agents.
---

# Plan de lots

Tu produis `docs/chantiers/<slug>/plan.md` : un **graphe de lots** au format gelé de `docs/guide/conventions.md` §6. C'est ce fichier qui rend le parallélisme possible ; un plan bâclé se paie en conflits git et en lots bloqués.

Argument : le `<slug>` du chantier. S'il manque, demande-le.

**Lis d'abord** : `docs/guide/conventions.md` §2 (nommage, contextes bornés) et §6 (format du lot), `docs/workflows/README.md` (phase 3), et le fichier de cycle concerné — `docs/workflows/feature.md`, `bugfix.md`, `refactoring.md`, `optimisation.md`. Puis `docs/chantiers/<slug>/memo.md` et `docs/chantiers/<slug>/prd.md`.

---

## Étape 0 — Entrées

```bash
ls docs/chantiers/<slug>
```

- Pas de `prd.md` rempli ? Pour un cycle **feature**, tu ne peux pas planifier : renvoie à la phase 2. Pour **bugfix**, **refactoring** et **optimisation**, il n'y a pas de PRD — tu planifies à partir du `memo.md` (root cause / périmètre gelé / mesure avant).
- Récupère le **type de cycle** dans l'en-tête du memo : il change la nature du découpage (voir étape 1).
- Explore le code existant avant de nommer des fichiers : un port, un use case ou une query qui existe déjà ne se recrée pas.
  ```bash
  ls app/domain/ports/ app/domain/use_cases/ app/infrastructure/repositories/ app/infrastructure/queries/
  ```

## Étape 1 — Découper

Le découpage est **vertical** : un lot = **un cas d'usage complet**, de la migration au pixel — migration → domaine → repository → contrôleur → vue. **Jamais par couche.** « Lot A = le domaine, Lot B = les vues » est le piège numéro un : rien n'est démontrable avant la fin, et les deux lots se bloquent mutuellement.

Test de validité d'un lot vertical : **peut-on faire une démo à la fin de ce lot seul ?** Si non, ce n'est pas une tranche verticale.

Adaptation par cycle :

| Cycle | Ce qu'est un lot |
|---|---|
| **feature** | un cas d'usage complet, de la migration au pixel |
| **bugfix** | souvent un seul lot (correctif + test) ; deux si des données corrompues doivent être réparées |
| **refactoring** | une **zone** (contexte borné, couche, namespace), mergeable seule, application fonctionnelle après |
| **optimisation** | **un levier = un chiffre**, mesurable séparément ; lots ordonnés par gain/risque décroissant |

## Étape 2 — Le Lot 0, socle séquentiel

**Toujours en premier, toujours seul, toujours court.** Il contient, et lui seul :

- les **migrations** (`db/migrate/…`) ;
- les **entités** (`app/domain/entities/<contexte>/…`) ;
- les **ports — contrats gelés** (`app/domain/ports/<contexte>/…`) ;
- **tous les fichiers partagés** : `config/routes.rb`, `config/locales/fr.yml`, les layouts (`app/views/layouts/`), la navigation, les fixtures partagées.

Deux conséquences que tu écris dans le plan :

1. **Le Lot 0 gèle les contrats.** Les lots verticaux *implémentent* les ports, ils ne les redéfinissent pas. Un lot qui a besoin de changer un port **s'arrête** : le Lot 0 rouvre.
2. **Aucun lot parallèle ne démarre avant que le Lot 0 soit mergé** dans la branche de chantier.

Si le Lot 0 dépasse une poignée de fichiers, c'est qu'il contient du métier qui appartient à un lot vertical. Redécoupe.

## Étape 3 — Écrire les lots au format gelé

Chaque lot a **quatre champs obligatoires**. Un lot incomplet est **refusé** : tu ne l'écris pas dans le plan, tu retournes le compléter.

```markdown
### Lot A — Envoyer un message à une classe

- **Couche**      : domaine + infrastructure + delivery + ui
- **Fichiers**    : app/domain/use_cases/communication/send_message.rb
                    app/infrastructure/repositories/communication/message_repository.rb
                    app/controllers/communication/messages_controller.rb
                    app/views/communication/messages/_form.html.erb
- **Dépend de**   : Lot 0
- **Test associé**: test/domain/use_cases/communication/send_message_test.rb
- **Done quand**  : un enseignant poste un message et il apparaît dans le fil de la classe
```

Contrôles que tu appliques à chaque lot :

- **`Dépend de`** — sans lui, impossible de paralléliser. `—` pour le Lot 0.
- **`Fichiers`** — des chemins réels, namespacés par contexte borné (`docs/guide/conventions.md` §2). Un fichier posé à la racine de `entities/` ou `repositories/` est du legacy, pas un modèle. Namespace ORM : `Orm::`, jamais `ORM::`.
- **`Test associé`** — un chemin sous `test/domain/`, `test/infrastructure/`, `test/controllers/` ou `test/integration/`. Pour une feature, **chaque critère d'acceptation Gherkin du PRD §4 est rattaché à au moins un lot**. Vérifie-le et dis-le si un critère est orphelin.
- **`Done quand`** — un **critère observable dans l'application**, jamais « le code est écrit ». Pour une optimisation, il est **chiffré**. Pour un refactoring, c'est toujours « les characterization tests de la zone passent, inchangés ».

## Étape 4 — Détecter les collisions

C'est la partie que personne ne fait et qui coûte le plus cher. **Avant** de lancer quoi que ce soit, construis le tableau de vérification de collision de `docs/chantiers/_TEMPLATE/plan.md` :

```markdown
## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes.rb` | Lot 0 |
| `config/locales/fr.yml` | Lot 0 |
```

Méthode :

1. Liste **tous** les fichiers de **tous** les lots.
2. Cherche les doublons — mécaniquement, pas à l'œil (l'`awk` s'arrête avant le tableau de collision pour ne pas compter ses propres lignes) :
   ```bash
   awk '/^## Vérification de collision/{exit} 1' docs/chantiers/<slug>/plan.md \
     | grep -oE '(app|test|config|db|lib)/[A-Za-z0-9_/.-]+\.(rb|erb|yml|js)' | sort | uniq -d
   ```
   Toute ligne retournée est une collision. Sortie vide ≠ plan sûr : relis aussi les répertoires listés sans nom de fichier précis.
3. **Tout fichier apparaissant dans deux lots parallèles remonte au Lot 0.** Pas de négociation, pas de « on fera attention », pas de résolution de conflit git après coup.
4. Le tableau final liste chaque fichier partagé avec **un seul** lot propriétaire.

Cas à vérifier systématiquement, parce qu'ils sont toujours oubliés : `config/routes.rb`, `config/locales/fr.yml`, `app/views/layouts/`, la navigation, `test/fixtures/`, les fichiers de `db/`.

## Étape 5 — Le dispatch (ne demande jamais combien d'agents)

**Le nombre d'agents n'est pas une question posée à l'utilisateur : il est égal au nombre de lots sans dépendance en attente.** Tu ne demandes pas, tu proposes.

Écris dans le plan les vagues :

```
Vague 1 : Lot 0                      → 1 agent, séquentiel
Vague 2 : Lot A ‖ Lot B ‖ Lot C      → 3 agents, worktrees isolés
Vague 3 : Lot D (dépend de A)        → 1 agent
```

Chaque lot parallèle travaille dans son **worktree git isolé**, sur une branche de lot créée **depuis la branche de chantier, une fois le Lot 0 mergé** :

```bash
git worktree add ../lnclass-<slug>-lot-a -b feature/<slug>-lot-a feature/<slug>
```

> ⚠️ **Tiret, pas slash** (`docs/guide/conventions.md` §3) : `<type>/<slug>-lot-<x>`. Git refuse `feature/x/lot-a` quand `feature/x` existe, un ref ne pouvant être à la fois un fichier et un répertoire.
>
> N'utilise pas l'outil `EnterWorktree` pour ça : il branche par défaut depuis `origin/<branche par défaut>`, donc **sans le Lot 0**. Ici la branche de base doit être la branche de chantier.

Puis un agent par lot via l'outil `Agent`, **tous lancés dans le même message** pour qu'ils tournent réellement en parallèle (un `Agent` par appel, plusieurs appels dans le même bloc). Le brief de chaque agent contient : le chemin **absolu** de son worktree, son lot recopié en entier (les 4 champs), le lien vers `docs/chantiers/<slug>/prd.md` et vers l'UDR s'il touche une vue, et l'ordre d'exécution intra-lot (test rouge → domaine → infrastructure → delivery → UI).

Deux avertissements à transmettre à chaque agent de lot :

- les chemins doivent être **absolus** : le répertoire courant est réinitialisé entre les appels shell, et l'agent n'est pas dans le worktree par défaut — qu'il utilise `git -C <worktree absolu>` ;
- **interdiction de toucher un fichier qui n'est pas dans son champ `Fichiers`.** S'il en a besoin, il s'arrête et remonte : soit le fichier appartient au Lot 0, soit le plan est faux.

Merge dans la branche de chantier au fur et à mesure, **une seule PR par chantier** vers `Develop` (`docs/guide/conventions.md` §3 — `main` ne reçoit que `Staging`, sauf hotfix).

Si le chantier appartient à un **programme** (ligne `Programme :` dans l'en-tête du memo), lis aussi `docs/workflows/programme.md` et la `feuille-de-route.md` du programme : les contrats des vagues déjà livrées sont gelés, et les décisions que consomme ce chantier doivent être `Accepté` avant le Lot 0.

## Étape 6 — Portes de sortie et challenger

Recopie dans `plan.md` les portes de sortie du cycle concerné (section « Portes de sortie » de `docs/workflows/<cycle>.md`), telles quelles.

Puis écris, en toutes lettres, la clause de phase 5 :

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Son mandat change selon le cycle : bugfix → il rejoue les étapes de reproduction du memo dans l'app ; refactoring → il vérifie que **rien** n'a changé pour l'utilisateur, et il lui est interdit de commenter le style ; optimisation → il **relance lui-même le bench** et doit obtenir le gain annoncé, sinon la PR ne passe pas.

## Étape 7 — Rendre

Écris `docs/chantiers/<slug>/plan.md` en repartant de la structure de `docs/chantiers/_TEMPLATE/plan.md` : graphe ASCII, lots, tableau de collision, portes de sortie.

Présente à l'utilisateur : le graphe, les vagues de dispatch avec le nombre d'agents qui en découle, les fichiers remontés au Lot 0 après détection de collision, et les lots dont un champ a dû être complété. **Ne lance rien** : c'est la skill de cycle appelante, ou l'utilisateur, qui donne le départ.
