# Memo — Develop charge toutes les leçons v3 du dépôt, entières

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré ([#477](https://github.com/Lnclassapp/App.Lnclassapp/pull/477) vers `Develop`, 2026-11-04), clos |
| **Ouvert le** | 2026-11-04 |
| **Branche** | `feature/charger-toutes-les-lecons-develop` |
| **Programme** | — |
| **Source** | ticket #473 (Touré, pilote, 2026-11-04) ; accord du porteur (Kamkara, 2026-11-04) sur le coût |

---

## Le problème

Sur Develop, les leçons ne sont pas celles des fichiers du dépôt. Seules les leçons du manifeste du jeu standard (environ 46) sont remplacées entières ; les leçons de 3ème ne le sont jamais, et une leçon à sujets de devoir (Thalès) ne voit remplacer que ses exercices et sujets. Develop montre donc d'anciennes versions : « Calcul littéral » (3ème) y a 5 notions et 1 exercice par notion, contre 4 notions et 5 exercices par notion dans le fichier.

## Pour qui

L'équipe (Team) qui relit les leçons sur Develop avant le train : elle doit voir exactement le fichier, comme en local.

## Pourquoi maintenant

Les vagues de contenus v3 se relisent sur Develop ; une relecture sur une ancienne version est une relecture perdue.

## Hors périmètre

- Staging, production, Demo et les environnements de PR : comportement inchangé.
- Les fichiers au format 1 (2nde, 4ème, 5ème, 6ème) : toujours ignorés.
- Aucune suppression : une leçon de Develop sans fichier, ou dont le titre diffère, reste ; établissements, classes et comptes du jeu standard inchangés.
- Aucune migration, aucun écran (pas d'UDR).
- Le découpage du premier chargement (N leçons par démarrage, option D d'ADR-0123) : appliqué seulement si Railway coupe le pré-déploiement.
- Parent, SchoolStaff, Teacher, Student : rien de nouveau ; sur Develop seulement, leurs résultats attachés à une leçon remplacée disparaissent (coût consenti).

## Ce que le grill a révélé

> Grill remplacé par les décisions écrites du ticket #473 (« aucune question à poser ») ; les questions ci-dessous ont été tranchées par le ticket ou par la règle « Develop identique au dépôt ».

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Que deviennent les résultats d'élèves, devoirs envoyés et lectures d'une leçon remplacée ? | Effacés, au premier chargement puis à chaque changement de fichier (accord du porteur, 2026-11-04). | Coût écrit dans l'amendement d'ADR-0124 ; aucun garde-fou ajouté. |
| Une leçon à sujets de devoir (Thalès) garde-t-elle le mode « exercices et sujets » sur Develop ? | Non : remplacée entière, sujets compris. | Develop ne prend plus jamais le mode `:exercises` ; Staging le garde. |
| La 3ème entre-t-elle dans la liste des dossiers du programme ? | Non : la liste ne sert plus qu'à Staging, qui ne change pas. | Develop ne lit plus la liste ; 3ème chargée sur Develop seul. |
| Le manifeste du jeu standard filtre-t-il encore quelque chose ? | Non pour les leçons ; il reste celui du jeu standard (comptes, classes, PR). | Le chargement ne lit plus `jeu.yml`. |
| Une leçon de Develop sans fichier ? | Laissée en place. | Aucun chemin d'effacement ajouté ; testé. |
| Un fichier rangé hors des dossiers connus ? | Chargé quand même s'il est au format 3 (« Develop identique au dépôt »). | Le mode ne dépend plus du dossier sur Develop. |

## Cas limites identifiés

- Fichier inchangé : `unchanged`, pas de réimport (empreinte SHA-256).
- Notion renommée à l'écran sur Develop : la leçon est remplacée entière (plus de refus `notion_not_found` sur Develop).
- Premier déploiement long (≈ 417 leçons) : temps mesuré dans le journal du chantier.
- Fichier de plusieurs leçons ou illisible : écarté comme avant, avec avertissement.

## Questions encore ouvertes

- Aucune.
