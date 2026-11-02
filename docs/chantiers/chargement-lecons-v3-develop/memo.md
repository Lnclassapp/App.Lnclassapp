# Memo — Develop charge seul les leçons v3 du programme, entières

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-11-02 |
| **Branche** | `feature/chargement-lecons-v3-develop` |
| **Programme** | `contenus-v3-tous-niveaux` |

---

## Le problème

Les leçons v3 du programme (Tle, 1ère, puis 2nde, 4ème, 5ème, 6ème) n'entrent sur Develop que par l'écran Imports, fichier par fichier, et l'import refuse toute leçon publiée du même titre (`lesson_already_published`). Les leçons v1 publiées sur Develop masquent donc les v3.

## Pour qui

Team (relecture des contenus sur Develop), puis enseignants et élèves de test sur Develop.

## Pourquoi maintenant

Tle et 1ère sont fusionnées (263 fichiers v3) ; les niveaux suivants arrivent vague après vague. Décision du porteur du 2026-11-02, résultats d'élèves de Develop effacés acceptés.

## Hors périmètre

- Staging, production, environnements de PR : inchangés.
- Les leçons à sujets de devoir : comportement d'ADR-0122 inchangé, sur Develop comme sur Staging.
- La 3ème (programme antérieur).
- Corriger le contenu des fichiers que l'import refuse (2 fichiers de 1ère C/D, « Généralités sur les composés organiques », `duplicate_accepted`).
- Une leçon v1 de titre différent de sa v3 : elle reste à côté.

## Grill

| Question | Réponse |
|---|---|
| Une leçon du programme qui porte des sujets ? | Mode d'ADR-0122 (exercices et sujets seulement), partout : exigence du porteur. Aucune aujourd'hui. |
| Un environnement de PR nommé Develop ? | Rien : `PrEnvironment.active?` passe avant le nom. |
| Le dossier `1ere` (sans série) ? | Dans la liste : il ne contient que du v1 (ignoré) ; l'histoire-géographie v3 de 1ère y arrivera comme celle de Tle dans `tle`. |
| Les dossiers 2nde, 4ème… déjà présents en v1 ? | Dans la liste dès maintenant : seuls les fichiers v3 sont lus, chaque vague arrive à sa fusion. |
| Le texte de cours v1 d'une leçon remplacée ? | Effacé (le v3 n'en a pas). |
| Le statut d'une leçon publiée remplacée ? | Reste publié ; la cascade publie le reste juste après. |
| Trop long pour le pré-déploiement ? | Mesuré : 174 s (création), 191 s (remplacement), 11 s ensuite ; Railway sans limite par défaut. Découpage en réserve (ADR-0123 option D). |
