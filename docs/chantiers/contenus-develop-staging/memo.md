# Memo — Les leçons arrivent seules sur Develop et Staging

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-10-31 |
| **Branche** | `feature/contenus-develop-staging` |
| **Programme** | — |

---

## Le problème

Une leçon rédigée dans le dépôt (par exemple Thalès, avec ses 4 sujets de devoir et 2 exercices par notion) n’arrive pas dans l’application de Develop ni de Staging. Il faut qu’un membre de l’équipe télécharge le fichier puis le téléverse à la main dans Imports, environnement par environnement. Et si la leçon y est déjà publiée, l’import la refuse : l’ancienne version reste en place.

## Pour qui

Touré, pilote, qui teste les leçons sur téléphone ; l’équipe, qui n’aura plus à importer à la main hors production. Les élèves et enseignants de test de Develop et Staging voient la dernière version.

## Pourquoi maintenant

La leçon Thalès refaite (#423) est fusionnée mais absente de Develop et Staging ; Touré veut l’y voir sans manipulation (« sans télécharger, envoyé sur Develop et Staging »).

## Hors périmètre

- La production : elle garde l’import à la main (décision de Touré, « laisser production, après on va faire ça »).
- Les leçons sans sujet de devoir : elles restent à importer à la main.
- La création du référentiel (niveaux, séries, matières) sur Staging : c’est l’équipe qui le crée.
- Garder les résultats de test des élèves sur l’ancienne version d’une leçon remplacée.
- Porter les écrans de #423 sur Staging : c’est le train Develop → Staging, hors chantier.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quelles leçons doivent arriver seules ? | « Je ne parle pas de leçon mais plutôt Prépare interros et Prépare devoirs » | Le besoin vu par Touré : ce qu’il a vu aux captures (feuilles numérotées, 4 sujets de devoir, 2 exercices par notion) doit être visible sur Develop et Staging. Deux moitiés : le code (déjà sur Develop, à porter sur Staging par un train) et le contenu qui remplit ces feuilles, qui vit dans les leçons et n’arrive que par import : c’est lui que ce chantier livre. |
| Des élèves de test ont fait les feuilles Thalès de l’ancienne version : que deviennent leurs résultats quand la nouvelle arrive ? | « On les efface » | Hors production, une leçon déjà publiée est remplacée : son ancien contenu et les résultats qui s’y rattachent sont effacés, puis le nouveau est chargé et publié. La production n’est jamais touchée. |
| Staging n’a peut-être ni la 3ème ni les Mathématiques : l’application les crée-t-elle ? | « Elle attend » | Le référentiel n’est jamais créé par ce chantier. Une leçon dont le niveau ou la matière manque n’est pas chargée ; elle est comptée et nommée dans le journal du déploiement, et sera chargée au déploiement suivant une fois le référentiel créé par l’équipe. |
| Comment l’application sait-elle qu’elle est sur Develop ou Staging, jamais en production ? | « Par le nom ; si un nom change chez Railway, elle ne s’arrête pas mais elle prévient » | Repérage par le nom d’environnement Railway (Develop, Staging), sans réglage à poser. Production : rien. Nom inconnu (hors environnement de PR, qui charge déjà ses leçons) : l’application démarre normalement, ne charge rien, et laisse un avertissement lisible. |
| Où voir ce qui a été chargé, refusé, ou l’avertissement de nom inconnu ? | « Écran Imports » | Chaque passage laisse une ligne « Chargement automatique » dans l’écran Imports de l’équipe, avec le détail comme un import à la main (chargées, remplacées, refusées et pourquoi) ; l’avertissement de nom inconnu y figure aussi, sans aucun contenu chargé. |
| La première fois, toutes les leçons sont-elles remises à jour ? | « Je travaille sur Prépare interros et Prépare devoirs seulement » | Seules les leçons retravaillées pour ces feuilles, reconnues à leurs sujets de devoir, sont chargées : aujourd’hui la seule leçon Thalès. Les autres leçons de Develop et Staging ne sont jamais touchées. Une leçon chargée n’est remplacée ensuite que si son fichier a changé. |
| (Précision au lancement) | « Je travaille sur interros, devoirs et la leçon » | La leçon entière est chargée (fiches des notions, exercices, problèmes, sujets), pas seulement les feuilles : c’est déjà le cas, le fichier porte toute la leçon. Le critère de sélection (sujets de devoir) désigne les leçons que Touré retravaille. |

## Cas limites identifiés

- Leçon déjà publiée sur l’environnement : remplacée, ses résultats et devoirs envoyés effacés, puis republiée.
- Leçon en brouillon sur l’environnement : remplacée puis publiée.
- Leçon absente : chargée puis publiée.
- Niveau ou matière absent : leçon non chargée, nommée dans la ligne de l’écran Imports, retentée au déploiement suivant.
- Fichier inchangé depuis le dernier chargement : rien n’est fait, et la ligne le dit.
- Fichier invalide : la leçon n’est pas chargée, l’erreur est dans la ligne ; l’application démarre quand même.
- Aucun membre d’équipe sur l’environnement : rien n’est chargé (la ligne d’import a besoin d’un auteur), avertissement dans le journal du déploiement.
- Deux démarrages en même temps : un seul chargement à la fois.
- Un import à la main en cours au même moment : le chargement attend le déploiement suivant.

## Questions encore ouvertes

- Le nom exact de l’environnement Staging chez Railway (Develop est confirmé par ADR-0108) : un nom différent donnera l’avertissement, sans dégât.
