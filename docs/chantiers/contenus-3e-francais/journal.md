# Journal — Les 10 premières leçons de Français de 3ème

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-30 | Les fiches « construire le sens » et « conclure » de la leçon 4 s'appuient sur *Une vie de boy* et *L'Enfant noir*, par paraphrase de faits vérifiés, sans citation longue | Exigence du porteur (plusieurs œuvres du collège ivoirien) ; une citation non vérifiée mot pour mot est un risque de droit et de justesse | Non |
| 2026-10-30 | Les productions rédigées valent 3 à 6 points, et jusqu'à 8 pour un problème de niveau BEPC ; le corrigé donne la répartition des points | Les relectures ont trouvé des barèmes incohérents d'une leçon à l'autre ; règle ajoutée à `prompt-redaction.md` | Non |
| 2026-10-30 | Le décompte des mots d'un résumé est présenté comme un usage courant, soumis à la consigne du sujet | Aucune convention officielle n'a été trouvée | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Aucune leçon n'était livrable au premier jet** : la relecture indépendante a trouvé de 5 à 8 défauts bloquants par leçon. On y trouvait des règles de grammaire fausses (« or » d'opposition, ordre des pronoms à l'impératif, participe présent et adjectif verbal), des faits d'œuvre inventés (résumé erroné de *L'Enfant noir*, fin à Conakry), des fautes de langue dans une leçon de Français, des réponses justes refusées par les `fill_blank` et des corrigés modèles qui recopiaient la thèse contre leur propre critère. Le script ne voit rien de tout cela : la relecture humaine ou IA reste la seule porte sur le fond.
- **Le relais des rapports de relecture par message coûtait cher** : les rapports sont désormais écrits dans un fichier lu par l'auteur. Le brief du relecteur le demande.
- **Scratchpad partagé** : un agent a écrasé le fichier temporaire d'un autre ; chaque agent doit nommer ses fichiers de façon unique.
- **Le hook d'arrêt a demandé un commit à chaque tour** : il a été ignoré à dessein, car les leçons en relecture partent en un seul commit de lot.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Le schéma v3 refuse avant l'adaptateur : points hors 0,5-20 ou 1,25, tolérance négative, unité > 10, critères > 8 rendent `schema` (pas `question_structure`) ; une clé inconnue est notée à la clé (`questions[0].criterias`). Une `written`/`notebook` sans explication rend `blank` ET `question_structure` à `explanation`. `script/` n'entre pas dans la couverture SimpleCov du projet : mesurée à part (module `Coverage`, 1 processus).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Relecture par un enseignant de Français : faits d'œuvre (L4), décompte des mots (L7), pronoms à l'impératif et participes (L8, L9), barèmes | Aucun enseignant disponible dans le chantier | Liste dans `docs/contenus/README.md`, section 3ème Français |
| `valider.rb` ne contrôle ni `statement_blocks`, ni les clés inconnues du cours, de la notion, de l'exemple et de l'exercice ; l'import les refuse (constat de revue) | Défaut antérieur à ce chantier, hors du périmètre du Lot A | À ouvrir : parité complète du contrôle avec le schéma v3 |
| Liste des œuvres intégrales de l'établissement : la leçon 4 n'en suppose aucune en particulier | Varie selon l'établissement | — |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
