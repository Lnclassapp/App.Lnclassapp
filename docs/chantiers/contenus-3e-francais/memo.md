# Memo — Les 10 premières leçons de Français de 3ème

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-10-30 |
| **Branche** | `feature/contenus-3e-francais` |
| **Programme** | `contenus-3e-autres-matieres` (vague 1) |

---

## Le problème

Un élève de 3ème n'a aucune leçon de Français à réviser au format en vigueur : les 10 premières leçons de la progression sont des fiches vides, et les 3 anciennes leçons rédigées sont dans un format retiré. Pour les écrire, deux outils manquent : le contrôle des fichiers refuse les questions rédigées que l'import accepte pourtant, et la consigne de rédaction ne parle que de mathématiques.

## Pour qui

- **Student** de 3ème, qui révise avant une interrogation, un devoir ou le BEPC de Français.
- **Teacher**, qui donne les exercices et corrige les questions rédigées.
- **Team**, qui importe les fichiers en brouillon, relit et publie.

## Pourquoi maintenant

Première vague du programme : le Français ne demande aucune figure nouvelle, il part sans code déployé. Le contrôle et la consigne généralisés servent aux quatre vagues suivantes.

## Hors périmètre

- Toute sorte de figure nouvelle (le Français n'en a pas besoin).
- Les leçons au-delà des 10 premières, les autres niveaux, les autres matières.
- Un PDF ou une vue de téléchargement : le livrable est un lot de fichiers prêts à importer, envoyés au porteur.
- L'import lui-même : il accepte déjà tous les types de questions ; aucune règle d'import ne change.
- Parent, SchoolStaff : rien de nouveau.

## Ce que le grill a révélé

Grill court : le cadrage du programme a tranché l'essentiel (memo du programme). Questions propres à la vague :

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Le contrôle refuse une question rédigée que l'import accepte : qui fait foi ? | L'import. | Le contrôle reprend la règle de l'import pour tous les types de questions, avec les mêmes raisons ; la parité est prouvée par test, avant toute rédaction. |
| Quelle part de questions corrigées automatiquement ? | La moitié au moins par leçon. | Avertissement du contrôle sous 50 % ; une leçon livrée n'a aucun avertissement. |
| Une question rédigée a-t-elle besoin d'autre chose que son corrigé ? | Un corrigé modèle, un barème et des critères. | La consigne exige `points` et `criteria` sur chaque question rédigée ; la relecture le vérifie. |
| Quelles œuvres pour « Étude de l'œuvre intégrale n°1 » ? | Plusieurs œuvres étudiées au collège en Côte d'Ivoire, en courtes citations référencées ; la leçon suit les 10 séances du programme. | Aucune œuvre unique ; aucun extrait long d'œuvre protégée, dans toutes les leçons. Textes longs : domaine public ou écrits pour Lnclass. |
| Que deviennent les 3 anciennes leçons du même intitulé ? | Elles sont remplacées. | Les 3 fichiers v1 sont réécrits en v3 au même nom ; aucun doublon dans le dossier. |
| Les 4 blocs (méthode, exemple…) conviennent-ils au Français ? | Oui, adaptés par matière dans la consigne. | La consigne dit, par matière, ce que deviennent La méthode, l'exemple et les 4 problèmes (interrogation, devoir, BEPC). |

## Cas limites identifiés

- Une question rédigée sans corrigé : refusée (`question_structure`), comme à l'import.
- Une question rédigée avec des propositions : refusée (`question_structure`).
- Un barème hors 0,5 à 20 ou non multiple de 0,5 : refusé.
- Des critères sur une question à choix : refusés.
- Une leçon à 49 % de questions corrigées automatiquement : avertissement, donc non livrée.
- Une citation d'œuvre protégée de plus de quelques lignes : refusée à la relecture.
- Une leçon d'oral (dialogue, exposé) : l'oral ne se corrige pas en ligne ; la leçon fait travailler sa préparation et sa structure, par écrit.

## Questions encore ouvertes

- Aucune.
