# Memo — Les 7 leçons de Français de Terminale (A1, A2, C, D)

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré (PR prête) |
| **Ouvert le** | 2026-10-31 |
| **Branche** | `feature/contenus-tle-francais` |
| **Programme** | `contenus-v3-tous-niveaux` (vague T7) |

---

## Le problème

Un élève de Terminale n'a aucune leçon de Français à réviser au format en vigueur : 4 des 7 leçons de la progression sont absentes, et les 3 leçons rédigées (12 fichiers dans 4 séries) sont au format v1, qui ne s'importe plus.

## Pour qui

- **Student** de Tle A1, A2, C ou D, qui révise avant une interrogation, un devoir ou le BAC de Français.
- **Teacher**, qui donne les exercices et corrige les questions rédigées.
- **Team**, qui importe les fichiers en brouillon, relit et publie.

## Pourquoi maintenant

Vague T7 du programme : la feuille de route est validée (D1 à D5) ; le modèle est le Français de 3ème (chantier `contenus-3e-francais`, PR #373).

## Hors périmètre

- Tout code : le Français n'emploie aucune figure ; aucune sorte nouvelle.
- Les tests : non touchés.
- Les autres matières et niveaux.
- L'import, la relecture par l'équipe et la publication : les leçons restent en brouillon.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Combien de leçons distinctes ? | 7. A1 et A2 en ont 7, C et D 6 (pas d'« Œuvre poétique »). | Écrites une fois dans `tle-a1/`, déclinées en `tle-a2/`, `tle-c/`, `tle-d/` : 26 fichiers. |
| Les rangs sont-ils les mêmes ? | Non : l'oral est leçon 2 en A et 3 en C/D, la dissertation 3 en A et 2 en C/D, le résumé 7 en A et 6 en C/D. | Seuls `series_name` et le rang du `subtitle` changent ; aucune leçon ne cite un numéro ni ne s'appuie sur une autre leçon de Terminale. |
| Quels textes supports ? | Comme en 3ème : écrits pour Lnclass ; œuvres réelles en courtes références paraphrasées (auteur, titre, date). | Aucun extrait long d'œuvre protégée ; faits incertains non écrits et signalés à l'enseignant. |
| Que deviennent les 12 fichiers v1 du même intitulé ? | Remplacés (D4). | Réécrits en v3 au même nom ; aucun doublon. |

## Cas limites identifiés

- L'oral ne se corrige pas en ligne : la leçon fait travailler sa préparation et sa structure, par écrit.
- Une règle d'épreuve du BAC ivoirien incertaine (durée, barème, déroulement) : non affirmée, signalée à l'enseignant.

## Questions encore ouvertes

- Aucune.
