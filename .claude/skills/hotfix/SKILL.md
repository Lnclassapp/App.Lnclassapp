---
name: hotfix
description: Ouvre un correctif d'urgence Lnclass quand la production est cassée maintenant, sans contournement, et que le correctif tient en 1 ou 2 fichiers — et ouvre obligatoirement son chantier de suivi. Utilise-la quand l'utilisateur tape /hotfix <slug>, dit que la prod est down, que des données se corrompent, ou qu'il faut corriger en urgence.
---

# Cycle Hotfix

Tu exécutes le cycle décrit dans `docs/workflows/hotfix.md`. **Lis-le maintenant**, ainsi que `docs/guide/conventions.md` §3, §5 et §7.

Argument : un `<slug>` kebab-case (`login-contact-espace`). S'il manque, demande-le.

**Ce cycle est un chemin court assumé, pas une dispense.** On coupe le plan, l'ADR et l'UDR ; on ne coupe **jamais** le chantier de suivi qui les rattrape. **Un hotfix sans chantier de suivi ouvert est un hotfix non terminé** — c'est une porte de sortie, pas une bonne intention.

Contrairement aux quatre autres cycles, cette skill **peut aller jusqu'au correctif**, parce que le plan est explicitement supprimé. Elle s'arrête quand même pour faire valider le périmètre avant d'éditer un fichier.

---

## Étape 0 — Les trois conditions, toutes vraies

Pose-les à l'utilisateur, **une par une**, et note les réponses :

1. La production est cassée **maintenant** — ou une donnée se corrompt à chaque minute qui passe.
2. Il n'existe **aucun contournement** acceptable pour l'utilisateur.
3. Le correctif est **petit et localisé** : 1 à 2 fichiers, **aucune migration**, aucun nouveau contrat.

Une seule est fausse → ce n'est pas un hotfix. Contournement existant → `/bugfix`. Migration, port ou nouvelle règle nécessaire → `/bugfix` ou `/feature`. Lent mais correct → `/optimize`. Moche mais fonctionnel → `/refactor`.

**Si l'utilisateur hésite, ce n'est pas un hotfix.** Le doute lui-même est le signal : un vrai hotfix ne se discute pas, il se constate. Dis-le et bascule vers `/bugfix`.

## Étape 1 — Branche, vite mais correctement

```bash
git rev-parse --abbrev-ref HEAD
git status --porcelain
git checkout -b hotfix/<slug>
```

**Jamais de commit direct sur `main`**, même en urgence : la branche + PR coûtent 30 secondes (`docs/guide/conventions.md` §3). Si le working tree est sale, signale-le — mais ne bloque pas le chantier pour ça : demande à l'utilisateur ce qu'il veut faire de ces modifications.

## Étape 2 — Chantier, même réduit

```bash
test -d docs/chantiers/<slug> || cp -r docs/chantiers/_TEMPLATE docs/chantiers/<slug>
rm -f docs/chantiers/<slug>/prd.md docs/chantiers/<slug>/plan.md docs/chantiers/<slug>/pr-faq.md
```

Un chantier sans dossier n'existe pas, même réduit à un memo de 3 lignes. Dossier déjà présent → ne l'écrase pas, reprends-le.

## Étape 3 — CADRER : 3 lignes, écrites AVANT de coder

Remplace le contenu de `docs/chantiers/<slug>/memo.md` par (date via `date +%F`) :

```markdown
# Memo — <titre>

| | |
|---|---|
| **Type de cycle** | hotfix |
| **Statut** | en cours |
| **Ouvert le** | <date du jour> |
| **Branche** | `hotfix/<slug>` |

**Constat** : depuis <heure>, <acteur> obtient <symptôme> sur <parcours>.
**Impact** : <combien d'utilisateurs, quelles données>. Aucun contournement.
**Hypothèse de cause** : <fichier / commit suspect>.
```

Trois lignes, pas zéro. Sans le constat écrit, personne ne saura dans deux mois ce qui s'est passé. Obtiens-les en trois questions courtes, pas en grill : l'urgence justifie la brièveté, pas l'absence.

Copie ensuite les **portes de sortie (hotfix)** de `docs/workflows/hotfix.md` à la fin de ce `memo.md`.

## Étape 4 — DÉCIDER : rien maintenant, mais tout est noté

Aucun ADR, aucune UDR, aucun PRD pendant l'incident. **Tout ce qui aurait mérité une décision est noté sur-le-champ** dans `docs/chantiers/<slug>/journal.md`, section `Dette laissée derrière`, avec le chantier de suivi en regard.

Noté **pendant**, pas reconstitué après : personne ne se souvient le lendemain de ce qu'il a sacrifié.

## Étape 5 — Annoncer le périmètre, puis s'arrêter

Pas de `plan.md`. Mais **avant d'éditer le premier fichier**, annonce à l'utilisateur : **quels fichiers, et rien d'autre.** Écris cette liste dans le memo et fais-la valider.

C'est le point d'arrêt de cette skill. Attends le feu vert.

## Étape 6 — EXÉCUTER : le plus petit diff qui arrête l'hémorragie

- Pas de nettoyage, pas de renommage, pas d'amélioration adjacente. **Chaque ligne non nécessaire est un risque supplémentaire en production.**
- Le **test de reproduction est fortement recommandé maintenant**, obligatoire au plus tard dans le chantier de suivi. Si l'incident permet de l'écrire d'abord, écris-le d'abord.
- **Aucune migration.** Si une migration semble nécessaire, ce n'est plus un hotfix : arrête-toi et requalifie.
- **Si le diff déborde le périmètre annoncé : arrête-toi et requalifie en bugfix.** Ne négocie pas avec toi-même.

Ce qu'on ne dégrade **jamais**, même en urgence (`docs/guide/conventions.md` §7) : pureté du domaine, rubocop, en-tête HITL — ce sont des blocages `.githooks/pre-commit`, pas des consignes.

```bash
bundle exec rubocop <fichiers touchés>
bin/rails test test/domain test/infrastructure   # au moins la suite du contexte borné
```

## Étape 7 — PROUVER : vérification manuelle

1. Rejoue **à la main**, en conditions réelles, le parcours cassé : il fonctionne.
2. Rejoue un **parcours voisin** : rien d'autre n'a bougé.
3. Lance la suite de tests du contexte borné.
4. PR `hotfix/<slug>` → `main`, référençant le chantier.
5. **Le jour même**, PR `main → Develop` pour reporter le correctif (`docs/guide/conventions.md` §3). Sans elle, le prochain passage `Staging → main` l'efface.

Commit (`docs/guide/conventions.md` §4) :

```
fix(<contexte>): <description à l'impératif>

Chantier: docs/chantiers/<slug>
```

## Étape 8 — Le chantier de suivi : **obligatoire, maintenant**

C'est la raison d'être de cette étape et la clause que tu ne négocies pas. **Tu l'ouvres avant d'annoncer que le hotfix est livré.**

```bash
cp -r docs/chantiers/_TEMPLATE docs/chantiers/<slug>-suivi
```

Dans `docs/chantiers/<slug>-suivi/memo.md` : type `bugfix`, statut `cadrage`, date du jour, branche `fix/<slug>-suivi`, et un lien vers `docs/chantiers/<slug>/`.

Reporte-y la **table de remboursement** de `docs/workflows/hotfix.md` (« Ce qu'on accepte de dégrader, et comment on rembourse »), avec pour chaque ligne ce qui est effectivement dû :

- **Memo complet réécrit et grillé**
- **PRD rétroactif**, ou référence au PRD existant
- **ADR sous 5 jours ouvrés** si le correctif a touché un contrat
- **UDR sous 5 jours ouvrés** si un écran a bougé
- **Test de reproduction** + tests des cas voisins
- **Root cause complète** — reportée, jamais supprimée : pourquoi aucun test ne couvrait ce cas
- **Rejeu par un challenger empirique**, un rôle distinct de l'auteur

Enfin, clos `docs/chantiers/<slug>/journal.md` avec le lien vers le chantier de suivi, et **dis explicitement à l'utilisateur** :

> Le hotfix est mergé, mais il n'est pas terminé. La dette est ouverte dans `docs/chantiers/<slug>-suivi/` : \<liste des remboursements dus et leurs échéances\>. Lance `/bugfix <slug>-suivi` pour la rembourser.

Un hotfix mergé sans suivi crée une dette invisible — le pire type.
