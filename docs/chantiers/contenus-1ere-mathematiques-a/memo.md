# Memo — Les 7 leçons de Mathématiques de 1ère A

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours (PR vers `Develop`, leçons en brouillon) |
| **Ouvert le** | 2026-11-02 |
| **Branche** | `feature/contenus-1ere-mathematiques-a` |
| **Programme** | contenus-v3-tous-niveaux (vague P2) |

---

## Le problème

Un élève de 1ère A (série littéraire) n'a aucune leçon de Mathématiques à réviser au format v3 : les 7 leçons de la progression sont des fiches vides, et 3 d'entre elles existent en v1 (rangées sous « 1ère A1 » et « 1ère A2 »), que l'import refuse.

## Pour qui

- **Student** de 1ère A, qui révise et s'entraîne dans la fiche.
- **Teacher**, qui donne les exercices de la leçon à sa classe.
- **Team**, qui importe en brouillon, fait relire par un enseignant, publie.

## Pourquoi maintenant

Deuxième vague de la 1ère, indépendante de P1 (fusionnée, PR #433) dont elle décline « Dénombrement » et « Généralités sur les fonctions ».

## Hors périmètre

- Les séries C et D (vague P1) ; les autres matières.
- Toute sorte ou tout paramètre de figure nouveau (courbe de fonction, tableau de variations) : situations décrites dans l'énoncé, dette déjà notée.
- Le code, les tests et l'import : aucun changement.
- L'import en production, la relecture enseignante, la publication : faits par l'équipe ; les leçons restent en brouillon.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Combien de leçons ? | 7 (la feuille de route disait 5), toutes propres à la série A : 14 fichiers. | Écart noté au journal du programme. |
| Où ranger ? | Le référentiel (`db/seeds/catalog.rb`) ouvre « 1ère A1 » et « 1ère A2 », pas « A » : chaque leçon est écrite une fois puis déclinée en deux fichiers (`series_name` A1 et A2), soit 14 fichiers. Les 6 v1 du même intitulé sont remplacées au même nom (D4). | L'historique git les garde. |
| Dénombrement et Généralités existent en C/D. | Déclinées au niveau A : même plan de notions, calculs plus simples, exercices allégés, contextes concrets. | Le rédacteur lit la leçon C comme modèle de structure, pas pour la copier. |
| Niveau d'une série littéraire ? | Calculs simples, contextes concrets, pas de démonstration théorique. | Brief des rédacteurs. |
| `valider.rb` ne contrôle pas `practice`. | Contrôle à part (`controle-entrainement.rb`, repris de P1). | Chaque fichier passe les deux contrôles. |

## Questions encore ouvertes

- Aucune.
