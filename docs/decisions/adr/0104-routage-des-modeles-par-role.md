# ADR-0104 : Chaque rôle d'agent a son modèle : Opus pour décider et relire, Sonnet pour exécuter, Haiku pour vérifier
<!-- index
titre: Routage des modèles par rôle
statut: Accepté
problematique: Un seul niveau de modèle pour toutes les tâches coûte cher et ralentit les vérifications, tandis que les revues, qui exigent du jugement, tournaient sur le modèle intermédiaire. Opus pour l'orchestrateur et les revues, Sonnet pour l'exécution, Haiku pour les vérifications pures ; le plus petit modèle suffisant, on monte d'un cran quand il y a du jugement.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-19 |
| **Chantier** | [`docs/chantiers/routage-modeles`](../../chantiers/routage-modeles/memo.md) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Les agents qui travaillent sur Lnclass ne choisissent pas leur modèle selon la tâche. Trois constats :

- **Coût.** Le chantier `sobriete-tokens` a chiffré la consommation comme premier frein à la cadence. Un modèle de pointe qui lance `bin/ci-quiet` et recopie un verdict dépense le même prix qu'un qui arbitre une revue.
- **Vitesse.** Une vérification pure (jouer la CI, relancer un fichier de test système, publier vert ou rouge) n'a rien à raisonner : un petit modèle la fait plus vite.
- **Qualité.** À l'inverse, les revues de la PR #250 ont trouvé des courses subtiles, en concurrence et en autorisation. Ce sont des défauts qu'un modèle trop léger laisse passer et dont le coût apparaît après la fusion. Les trois sous-agents de revue étaient pourtant à `model: sonnet`.

Le porteur résume : « Il ne sert à rien de démarrer un train pour transporter un sac de maïs de 50 kg : une moto ou un vélo est adapté et rapide. » L'inverse vaut aussi : on n'envoie pas un vélo chercher un camion de ciment.

## 2. Moteurs de décision

1. **Ne pas économiser là où l'erreur coûte** : sécurité, concurrence, architecture, décision métier.
2. **Ne pas dépenser là où il n'y a rien à juger** : lancer, relancer, rapporter.
3. **Une règle qu'on applique sans y penser**, et qui tient dans une page.
4. **Appliquée par le dépôt lui-même** (frontmatter des agents), pas seulement par la mémoire de chacun.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Un seul modèle partout | Aucune règle à retenir | Coût et lenteur sur les vérifications ; ou qualité insuffisante sur les revues, selon le modèle choisi |
| B — Choix libre à chaque appel | Souple | Inégal d'une session à l'autre, dérive vers le plus gros par prudence |
| C — **Routage par rôle**, avec montée d'un cran sur jugement | Simple, lisible dans le frontmatter, couvre les trois coûts | Demande de maintenir la table à jour quand un nouveau rôle apparaît |

## 4. Décision

> **Nous choisissons le plus petit modèle qui fait le travail, et nous montons d'un cran dès que la tâche exige du jugement (sécurité, concurrence, architecture, décision métier). Le routage par rôle est le suivant.**

| Rôle | Modèle | Pourquoi |
|---|---|---|
| Orchestrateur (session principale) : cadrage (memo, PRD, ADR/UDR, plan), décisions, arbitrage des revues, fusions | **Opus** | Il tranche et il engage le dépôt |
| Sous-agents de revue : `security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer` | **Opus** | Concurrence, autorisation, échecs silencieux : du jugement (PR #250) |
| Agents d'exécution : écrire les lots, les tests et les corrections à partir d'un plan déjà cadré | **Sonnet** | Le plan a déjà tranché ; reste à bien écrire |
| Vérifications pures : lancer `bin/ci-quiet`, relancer des tests système, publier un verdict | **Haiku** | Aucune décision, seulement l'exécution et le compte rendu |
| Recherche de code (`Explore`) : trouver un fichier, lire du code ou un journal, lister un dossier | **Haiku** | Localiser n'est pas juger ; l'Explore intégré héritait sinon d'Opus |
| Tâches mécaniques hors lot (`chores`) : lancer une commande et résumer sa sortie, lire un journal, renommer un fichier de doc | **Haiku** | Aucune décision ; s'arrête au-delà de 2 fichiers ou dès qu'un choix se pose |

Un agent d'exécution qui se heurte à une décision que le plan ne tranche pas **s'arrête et remonte** à l'orchestrateur ; il ne choisit pas lui-même.

## 5. Conséquences

### 🟢 Positives

- Les vérifications, les plus fréquentes, passent sur le modèle le moins cher et le plus rapide.
- Les revues gagnent en profondeur là où les défauts coûtent le plus.
- La règle se lit dans `.claude/agents/*.md` : un agent neuf sans `model:` saute aux yeux.

### 🔴 Coûts consentis

- Les revues coûtent plus cher par appel : c'est compensé par la règle déjà en vigueur (une fois par PR, sur le diff final, au-delà de 150 lignes ou si un use case, une policy, une route ou un téléversement est touché).
- Haiku se trompe plus facilement sur un journal ambigu : le vérificateur ne conclut que sur le code de sortie et les lignes de `bin/ci-quiet`, et ne diagnostique pas.
- Une table de plus à tenir à jour quand un rôle apparaît.

## 6. Notes d'implémentation

Trois leviers, du plus durable au plus ponctuel :

1. **Frontmatter `model:` des agents du dépôt** (`.claude/agents/`) :

| Fichier | `model:` |
|---|---|
| `security-reviewer.md`, `silent-failure-hunter.md`, `pr-test-analyzer.md` | `opus` |
| `executant-lot.md` | `sonnet` |
| `verificateur-ci.md`, `Explore.md`, `chores.md` | `haiku` |

`Explore.md` remplace l'agent Explore intégré de Claude Code, qui tourne sinon sur le modèle de la session. `chores` ne touche pas au code de `app/` : en-tête HITL, I18n, couches et « un commit par lot » relèvent d'`executant-lot`.

2. **Paramètre `model` à l'appel d'un agent** (outil Agent) : il l'emporte sur le frontmatter. À utiliser pour monter ou descendre d'un cran sur une tâche précise, pas pour contourner la table.
3. **`/model`** pour la session principale : Opus pour l'orchestration.

La règle de référence est dans [`docs/workflows/README.md`](../../workflows/README.md#quel-modèle-pour-quel-rôle) ; `CLAUDE.md` n'en est que le raccourci.

## 7. Comment vérifier que la décision est respectée

Aucune garde automatique : un mauvais `model:` coûte de l'argent, pas de l'intégrité. Contrôle à la main :

```
grep -H '^model:' .claude/agents/*.md
```

Les trois agents de revue doivent afficher `opus`, `executant-lot` `sonnet`, `verificateur-ci`, `Explore` et `chores` `haiku`. La décision tiendra mal si les agents d'un plugin ou d'un nouvel auteur oublient le champ : à relire au moment d'ajouter un agent.
