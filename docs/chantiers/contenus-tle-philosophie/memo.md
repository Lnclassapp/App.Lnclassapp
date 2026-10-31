# Memo — Les 10 premières leçons de Philosophie de Tle (A1, A2, C, D)

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours |
| **Ouvert le** | 2026-10-31 |
| **Branche** | `feature/contenus-tle-philosophie` |
| **Programme** | `contenus-v3-tous-niveaux` (vague T6) |

---

## Le problème

Un élève de Terminale n'a aucune leçon de Philosophie au format en vigueur : les 3 leçons rédigées (dissertation, commentaire, connaissance de l'homme) sont au format 1, retiré, et les 7 suivantes de la progression n'existent pas. La consigne de rédaction ne disait rien de la Philosophie.

## Pour qui

- **Student** de Tle A1, A2, C ou D, qui révise avant une interrogation, un devoir ou le bac.
- **Teacher**, qui donne les exercices et corrige les questions rédigées.
- **Team**, qui importe les fichiers en brouillon, relit et publie.

## Pourquoi maintenant

Vague T6 du programme, indépendante des autres vagues de Tle. Aucune figure nouvelle : pas de code.

## Hors périmètre

- La série E (décision D3 du programme : absente du référentiel).
- Toute sorte de figure nouvelle, tout code, tout test.
- Les leçons au-delà des 10 premières, la 1ère (vague P7).
- L'import lui-même et la publication : les leçons restent en brouillon jusqu'à la relecture d'un enseignant.

## Ce que le grill a révélé

Grill court : le programme a tranché D1 à D5 ; le modèle est la vague Français 3ème (PR #373).

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Une leçon commune à 4 séries s'écrit-elle 4 fois ? | Non, une fois, puis déclinée par série. | 10 leçons rédigées, 38 fichiers (A1 10, A2 10, C 9, D 9) ; seuls `series_name` et le rang du sous-titre changent. |
| « L'histoire et l'humanité » en C et D ? | Absente de leur progression. | Fichier en A1 et A2 seulement ; en C et D les rangs suivants reculent d'un cran. |
| Que mettre dans les 4 blocs en Philosophie ? | Analyser un sujet ou un texte, puis argumenter. | Ligne Philosophie et règles « Auteurs, doctrines et textes » ajoutées à `prompt-redaction.md`. |
| Textes d'auteurs ? | Courtes citations référencées ; textes longs du domaine public ou originaux. | Traductions récentes évitées ; doctrines en paraphrase avec référence ; points de doctrine au journal pour un enseignant. |
| Part de questions corrigées automatiquement ? | Au moins 50 %, comme en Français. | Aucun avertissement du contrôle sur les 38 fichiers. |

## Cas limites identifiés

- Une citation incertaine mot pour mot : paraphrase, jamais de guillemets.
- « Dieu et la religion » : positions d'auteurs, aucune croyance jugée.
- Une question rédigée note l'argumentation, jamais l'opinion.

## Questions encore ouvertes

- Aucune.
