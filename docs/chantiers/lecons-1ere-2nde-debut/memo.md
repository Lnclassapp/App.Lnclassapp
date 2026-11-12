# Memo — Les trois premières leçons de 1ère et de 2nde, comme Thalès

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours (2026-11-12) |
| **Ouvert le** | 2026-11-12 |
| **Branche** | `feature/lecons-1ere-2nde-debut` (1ère), `feature/lecons-2nde-debut` (2nde) |

---

## Le problème

Aucune leçon de 1ère ni de 2nde n'est chargée : elles sont toutes dans `docs/contenus/a-reprendre/`. Les élèves de ces niveaux n'ont rien à tester dans l'app.

## Pour qui

L'élève de 1ère (A1, A2, C, D) et de 2nde (A, C) qui teste l'app ; l'enseignant qui envoie un sujet à sa classe.

## Pourquoi maintenant

Demande du porteur, relayée par l'orchestrateur le 2026-11-12 : de quoi tester à ces niveaux, sans attendre les années complètes.

## Hors périmètre

- Les leçons de rang 4 et plus de la progression : chantiers suivants.
- Le cours, les fiches et les 4 problèmes des leçons de 1ère : inchangés (seuls le 2e exercice de chaque notion et les 4 sujets s'ajoutent).
- L'écran et le code (`app/`) : rien ne change, donc ni ADR ni UDR.
- Staging et production : aucun import à la main.

## Ce que le grill a révélé

Les décisions viennent de la demande du porteur et des chantiers de Terminale « comme Thalès » (#484) ; l'orchestrateur les a posées avant le lancement.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quelles leçons ? | Les 3 premières de la progression DPFC 2026-2027, par série et par matière | 1ère : 63 fichiers (36 leçons distinctes) ; 2nde : 27 fichiers (21 leçons distinctes). |
| Quel format ? | Celui des Terminales « comme Thalès » | 2 exercices par notion (le 2e de 6 questions de 4 types au moins), 4 problèmes, 4 sujets de 4 exercices de 5 ou 6 questions. |
| Le « 2e exercice » des fichiers `sujets-manquants` ? | Leur `practice` (« Je m'entraîne », 3 ou 4 questions) n'est pas le 2e exercice de Thalès | Comme en Tle C (36 fichiers `sujets-manquants` eux aussi), on ajoute le 2e exercice **et** les sujets ; `practice` est gardé tel quel. |
| Fichiers de même fiche dans plusieurs séries ? | Écrits une fois, recopiés | Une copie ne diffère que par `series_name` et `theme`, ceux du fichier d'origine de sa série. |
| 2nde au format 1 ? | Réécrite en v3 complet | Le format 1 est refusé à l'import (`format_retired`). |
| Livraison ? | Une PR par niveau, ouverte prête ; l'orchestrateur fusionne | 1ère d'abord, puis 2nde. |

## Cas limites identifiés

- Une leçon de 1ère C et sa jumelle de 1ère D qui n'ont pas la même fiche (Équations, Angles orientés, Généralités sur les fonctions) sont traitées chacune.
- Une figure n'est ajoutée qu'avec une sorte existante de `figure_kinds.rb`.

## Questions encore ouvertes

- Aucune.
