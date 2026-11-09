# Memo — La fiche s'ouvre sous l'Or

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-11-09 |
| **Branche** | `feature/ouverture-remediation` |
| **Programme** | — |

---

## Le problème

Après `seuil-remediation`, une fiche à revoir ne se lève qu'à l'Or, mais elle ne s'ouvre encore que sous 10/20. Un élève Argent sur un nouvel exercice n'est donc pas « à revoir », alors qu'un élève Argent qui a déjà une fiche à revoir y reste : deux règles pour une même médaille.

## Pour qui

L'élève (fiche à revoir, exercice proposé, message du résultat) ; l'enseignant et la direction (comptes de fiches à revoir).

## Pourquoi maintenant

Décision du porteur du 2026-11-09, définitive : « quand la médaille est Argent, l'élève est dans la remédiation. Seules les médailles Or et Diamant ne sont pas dans la remédiation. »

## Règle décidée

Tout score sous l'Or (médaille Bronze ou Argent) ouvre la fiche à revoir, ou la maintient si elle est déjà en attente. L'Or et le Diamant ne l'ouvrent pas et la lèvent si elle est en attente. Une seule échelle : la médaille, lue sur la note affichée (ADR-0106), jamais le pourcentage brut.

## Hors périmètre

- « Pas encore » (aucun exercice fait) reste hors remédiation.
- Aucune réouverture rétroactive des sessions passées, aucune migration.
- Aucun nouvel écran : les textes du résultat disaient déjà « Cette notion passe à revoir » / « Encore à revoir ».
- Les seuils de médaille ne bougent pas.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Le compteur d'échecs de la lacune compte-t-il un Argent ? | Oui (option prudente) : un exercice sous l'Or ne lève pas. | `increment` sous l'Or ; écrit dans l'ADR-0043 et le journal. |
| Une copie vide ouvre-t-elle ? | Non : aucune médaille, donc hors remédiation. Avant, elle ouvrait (0 %). | Décision de clôture reçoit « copie traitée » ; changement de comportement écrit au journal. |
| Plusieurs lacunes pour une fiche ? | Une par élève et par fiche, une seule `pending` : un Argent sur une fiche déjà en attente compte un échec, n'en ouvre pas une seconde. | Rien à créer ; testé. |
| Un Argent sur un exercice de toute la leçon ? | Sans notion, aucune fiche : n'ouvre rien (ADR-0113). | Inchangé. |
| Messages du résultat pour l'Argent ? | Première fois : « Cette notion passe à revoir » ; session de remédiation : « Encore à revoir ». | Aucun libellé à changer ; seule l'aide (/aide) est réécrite en médailles. |
| Volume de fiches à revoir ? | Il double : jeu standard, 136 → 264 (voir ci-dessous). | Dit au porteur ; aucun écran à adapter, les listes sont déjà à 3 lignes + « Voir plus ». |

## Mesure sur le jeu standard (`bin/jeu-standard`)

503 sessions notées liées à une fiche : 167 sous 10/20, 349 sous l'Or. Fiches à revoir en attente à la fin du trimestre simulé : **136** (ouverture sous 10/20) contre **264** (ouverture sous l'Or), soit environ le double.

## Cas limites identifiés

- 77 % s'affiche 15/20 (Argent) : ouvre ; 78 % s'affiche 16/20 (Or) : n'ouvre pas.
- 0 % avec au moins une réponse fausse : Bronze, ouvre. Copie sans réponse : rien.
- 100 % : Diamant, lève.

## Questions encore ouvertes

Aucune bloquante. Voir `## À trancher` du journal.
