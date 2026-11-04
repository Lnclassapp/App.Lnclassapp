# Memo — Les 9 leçons de SVT de 1ère A1 et A2

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré (PR prête) |
| **Ouvert le** | 2026-11-02 |
| **Branche** | `feature/contenus-1ere-a-svt` |
| **Programme** | `contenus-v3-tous-niveaux` (vague P6) |

---

## Le problème

Un élève de 1ère A1 ou A2 n'a aucune leçon de SVT à réviser au format en vigueur : 6 des 9 leçons de la progression sont absentes, et les 3 leçons rédigées sont au format v1, qui ne s'importe plus.

## Pour qui

- **Student** de 1ère A1 ou A2, qui révise avant une interrogation ou un devoir de SVT.
- **Teacher**, qui donne les exercices et corrige les questions rédigées.
- **Team**, qui importe les fichiers en brouillon, relit et publie.

## Pourquoi maintenant

Vague P6 du programme : la feuille de route est validée (D1 à D5) ; la SVT de 1ère C et D (P5, #435) et celle de Tle A (T5, #425) posent le modèle.

## Hors périmètre

- Tout code : aucune sorte de figure, planche ou partie nouvelle (schémas absents décrits en texte ou en `diagram`, signalés au journal).
- Les séries C et D (vague P5), les autres matières et niveaux.
- Les tests : les contrôles de « Je m'entraîne » sont joués à part par script.
- L'import, la relecture par l'équipe et la publication : les leçons restent en brouillon.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quelle série ? | Le référentiel n'a pas de série « A » en 1ère : A1 et A2. Les progressions A1 et A2 sont identiques (mêmes intitulés, mêmes rangs). | 9 leçons écrites une fois dans `1ere-a1/svt/`, déclinées dans `1ere-a2/svt/` : 18 fichiers qui ne diffèrent que par `series_name`. Pas de dossier `1ere-a/`. |
| Une leçon existe-t-elle déjà en 1ère D (#435) ? | Non : aucun des 9 intitulés n'y figure (la D traite « Le réflexe inné » et « …monohybridisme », autres intitulés). | Aucune adaptation ; 9 rédactions complètes. |
| Que deviennent les 3 × 2 fichiers v1 (L1 à L3) ? | Remplacés (D4). | Réécrits en v3 au même nom ; aucun doublon. |
| Quel niveau d'exigence en série A ? | Littéraire : vocabulaire précis mais accessible, documents à analyser plutôt que calculs. | Probabilités et fréquences en fractions simples ; échiquier de croisement simple. |
| Faits médicaux (drogues, contraception) ? | Rien qui ne soit sûr ; aucune posologie ni chiffre incertain. | Relecture par un sous-agent Opus ; points signalés à l'enseignant. |
| Une figure demande-t-elle une sorte nouvelle ? | Non, sauf constat contraire au journal. | Aucun code, aucun amendement d'ADR. |

## Cas limites identifiés

- Un arbre généalogique : aucune sorte ne le dessine ; décrit en texte (générations, individus numérotés).
- Une notion dont le rattachement au programme de 1ère A est incertain : non écrite, signalée à l'enseignant.
- Un sujet sensible (drogues, contraception) : informer sans conseiller de produit ni de dose, sans jugement.

## Questions encore ouvertes

- Aucune.
