# Memo — Les 7 leçons de SVT de Terminale A1 et A2

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré (PR prête) |
| **Ouvert le** | 2026-10-31 |
| **Branche** | `feature/contenus-tle-svt-a` |
| **Programme** | `contenus-v3-tous-niveaux` (vague T5) |

---

## Le problème

Un élève de Terminale A1 ou A2 n'a aucune leçon de SVT à réviser au format en vigueur : 4 des 7 leçons de la progression sont absentes, et les 3 leçons rédigées sont au format v1, qui ne s'importe plus.

## Pour qui

- **Student** de Tle A1 ou A2, qui révise avant une interrogation, un devoir ou le BAC de SVT.
- **Teacher**, qui donne les exercices et corrige les questions rédigées.
- **Team**, qui importe les fichiers en brouillon, relit et publie.

## Pourquoi maintenant

Vague T5 du programme : la feuille de route est validée (D1 à D5), le modèle de la SVT de Tle est posé par la vague T4 (PR #421, #422).

## Hors périmètre

- Tout code : aucune sorte de figure, planche ou partie nouvelle (schémas absents décrits en texte ou en `diagram`, signalés au journal).
- Les séries C et D (vague T4), les autres matières et niveaux.
- Les tests : les jeux de tests des contenus sont gérés par la PR #415.
- L'import, la relecture par l'équipe et la publication : les leçons restent en brouillon.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Combien de leçons distinctes ? | 7 : la progression de A1 et celle de A2 sont identiques (mêmes intitulés, mêmes rangs). | Écrites une fois dans `tle-a1/`, déclinées dans `tle-a2/` : 14 fichiers qui ne diffèrent que par `series_name`. |
| Quel niveau d'exigence en série A ? | Littéraire : vocabulaire précis mais accessible. | Documents à analyser (textes, tableaux, courbes) plutôt que calculs ; probabilités en fractions simples au plus. |
| Sur quels acquis s'appuyer ? | Les leçons de SVT de 1ère A (dont la transmission d'un caractère lié aux autosomes et aux chromosomes sexuels). | L5 et L6 reprennent ces acquis sans les refaire ; L5 ne traite pas les maladies héréditaires, réservées à L6. |
| Une figure demande-t-elle une sorte nouvelle ? | Non : courbes, histogrammes, schémas fléchés, frise. | Aucun code, aucun amendement d'ADR. |
| Que deviennent les 3 × 2 fichiers v1 du même intitulé ? | Remplacés (D4). | Réécrits en v3 au même nom ; aucun doublon. |

## Cas limites identifiés

- Un arbre généalogique : aucune sorte ne le dessine (un seul parent par nœud) ; décrit en texte (générations, individus numérotés).
- Une date ou un âge incertain (fossiles, hominidés) : ordre de grandeur sûr seulement, signalé à l'enseignant.
- Une conviction religieuse (origine de la vie) : distinguée de l'explication scientifique, sans la juger.

## Questions encore ouvertes

- Aucune.
