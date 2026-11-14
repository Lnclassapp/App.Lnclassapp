---
name: publier-prod
description: Prépare la publication de leçons Lnclass en production — création seule — à partir de la copie figée de l'application, et rend au porteur les fichiers à importer dans l'écran Imports et la liste de ce qui est écarté. Utilise-la quand l'utilisateur tape /publier-prod, demande de mettre des leçons en production, de préparer un import de production ou de publier une version des contenus.
---

# Préparer une publication en production

Décision : ADR `contenus-dans-un-depot-dedie-copie-figee` §4.3. La production n'a **aucun** chargement automatique (ADR-0122) : on y importe à la main, depuis **Imports → Fiches de cours complètes**, avec un compte équipe.

## Règle d'or

**Création seule.** Cette skill ne prépare jamais un remplacement ni une suppression. Une leçon dont le titre existe déjà en production — **publiée ou en brouillon** (l'import remplace un brouillon de même titre) — est écartée et listée. Elle ne part que si le porteur l'a confirmée **par écrit, leçon par leçon**, dans ce fil ; un « oui » général ne suffit pas. Aucune suppression, jamais.

Tu n'importes pas toi-même : tu prépares, un membre de l'équipe importe.

## 1. Ce qu'on publie

- Source : `docs/contenus/lecons-traitees/` de `origin/main` de l'application (ce qui est en production), à la version nommée par `docs/contenus/VERSION` s'il existe. Jamais une leçon qui n'est pas encore sur `main`.
- Argument facultatif : un filtre (`3ème`, `tle-d mathematiques`, un chemin). Sans argument : toutes les leçons.
- Chaque fichier repasse `ruby script/contenus/valider.rb` : un ✗ l'écarte (« refusée au contrôle »).

## 2. Ce qui existe déjà en production

Il faut la liste des titres de leçons (cours) présents en production, publiés et brouillons :

- `RAILWAY_API_TOKEN` présent : lis-la en lecture seule (`railway run` sur l'environnement `production`, `bin/rails runner` qui lit `Orm::Catalog::Course` (nom, statut, niveau, série, matière) sans rien écrire). **Aucune écriture.**
- Variable absente : nomme `RAILWAY_API_TOKEN` en une ligne, ne la demande pas, et rends la liste à vérifier au porteur (étape 4) en marquant chaque leçon « présence en production non vérifiée ». Rien n'est classé « à créer » sans vérification.

Compare par titre exact **et** par niveau-série + matière (un même titre peut exister dans deux niveaux).

## 3. Préparer

Dans le scratchpad de la session (jamais commité) :

```
publier-prod-AAAA-MM-JJ/
  a-creer/<niveau-série>/<matière>/*.json      ← copies exactes, à importer une par une
  RAPPORT.md
```

`RAPPORT.md` :

| Section | Contenu |
|---|---|
| Version | dépôt, SHA (`VERSION`), date |
| À créer | une ligne par leçon : niveau-série, matière, titre, fichier |
| Écartées — déjà en production | titre, statut en production (publiée, brouillon), ce qu'un import ferait (refus, remplacement du brouillon) |
| Écartées — refusées au contrôle | fichier, première erreur |
| Non vérifiées | si la production n'a pas pu être lue |
| Marche à suivre | 1. se connecter avec un compte équipe ; 2. Imports → Fiches de cours complètes ; 3. importer les fichiers de `a-creer/` dans l'ordre du tableau ; 4. vérifier la ligne de chaque import (créée, aucune erreur) ; 5. publier depuis la leçon ; 6. ne jamais importer un fichier de la section « Écartées » |

Envoie `RAPPORT.md` au porteur (SendUserFile), et l'archive des fichiers à créer.

## 4. Confirmation du porteur

Seulement s'il y a des leçons écartées « déjà en production » ou « non vérifiées » : pose-les en **un seul** `AskUserQuestion` (au plus 4 par écran, recommandé : ne pas remplacer). Dans une session lancée par une autre (contrat de session), ne pose pas la question : écris-la dans `## À trancher` du chantier concerné et finis sur le rapport. Une confirmation déplace la leçon dans `a-creer/` avec la mention « remplace le brouillon, confirmé le AAAA-MM-JJ ».

## Fin

Une ligne : `N à créer · M écartées (déjà en production) · K refusées · version <SHA court>` et le chemin complet du rapport.
