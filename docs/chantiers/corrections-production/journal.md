# Journal — Corrections du validateur pédagogique en production

> Demande explicite du porteur (2026-11-14) : appliquer automatiquement les corrections de [`a-reporter-en-production.md`](../validation-pedagogique-agent/a-reporter-en-production.md) (32 leçons) par un script exécuté en production via Railway. Pas de memo ni d'UDR : opération de données, sans règle métier nouvelle.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-14 | Les « Avant / Après » viennent de l'historique git (version d'avant #599 contre la copie figée), pas du texte du rapport | Le rapport abrège certains « Avant » (« … », « […] ») ; la version git est exacte. Extraction : `script/contenus/extraire_corrections.rb` → `corrections.json` | Non |
| 2026-11-14 | Le script passe par `CorrectNotionText` et `CorrectExerciseText` (acteur : membre équipe), jamais par SQL | Anciens scores gardés, événement `content.corrected` écrit | Non |
| 2026-11-14 | Une valeur en base qui n'est pas exactement l'« Avant » n'est jamais forcée : listée « introuvable » | Une modification faite à la main entre-temps ne doit pas être écrasée | Non |
| 2026-11-14 | Lancement : `bin/rails contenus:corriger` (essai), `APPLIQUER=1 bin/rails contenus:corriger` (écrit) ; acteur : `LNCLASS_TEAM_CONTACT` ou `ACTEUR` | Rake n'accepte pas `--appliquer` après le nom de la tâche | Non |

## Périmètre

101 modifications de champ dans 32 leçons : 30 de notions, 67 d'exercices, **4 hors périmètre** (aucun use case ne les écrit) : l'entraînement « Je m'entraîne » de deux notions (`2nde-a/calcul-numerique`, `tle/…problemes-de-developpement-economique-de-la-cote-d-ivoire` : question 5, explication et proposition 3) et l'unité d'une question du sujet 1 de cette dernière. Le script les liste « hors périmètre » ; voir `## À trancher`.

## À trancher

- [ ] 2026-11-14 · corrections-production · Revue sécurité : une cible (notion ou exercice) s'écrit en entier ou pas du tout. Cas réel : `2nde/histoire-geographie/histoire-les-methodes-d-etude-de-l-histoire`, sujet 4 › exercice 4 › question 3, dont la nouvelle explication annonce une réponse « Antiquité » à ajouter ; aucun use case n'ajoute une proposition, donc tout l'exercice reste tel quel et sort en « introuvable ». — appliqué : à reporter à la main ; autres : étendre le use case ; recommandé : à la main.
- [ ] 2026-11-14 · corrections-production · 4 corrections touchent l'entraînement d'une notion (3) ou l'unité d'une question (1), que la modale « Modifier le texte » ne sait pas écrire. — appliqué : listées, à reporter à la main (ou au prochain import de la leçon, qui les porte déjà) ; autres : étendre `CorrectNotionText` à l'entraînement ; recommandé : le prochain import.
- [ ] 2026-11-14 · corrections-production · Accès à la production : la variable `RAILWAY_API_TOKEN` (et `LNCLASS_TEAM_CONTACT`, contact du membre équipe qui agit) n'existe pas dans l'environnement de cette session, et la commande `railway` n'y est pas installée. — appliqué : script et PR livrés, exécution en production non faite ; autres : lancer `bin/rails contenus:corriger` depuis une session qui a la variable ; recommandé : ajouter `RAILWAY_API_TOKEN` à l'environnement Claude Code, puis relancer l'étape 5.

## Ce qui a dérapé

- Rien à ce stade.
