# Memo — Une seule échelle : la remédiation suit la médaille

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-11-09 |
| **Branche** | `feature/seuil-remediation` |
| **Programme** | — |

---

## Le problème

L'élève lit des médailles partout. Mais une fiche « à revoir » n'est levée qu'à une note de 15/20, qui ne correspond à aucune médaille : entre l'Argent et l'Or. La consigne affichée (« vise l'Or ») ne dit pas la règle réelle, et l'enseignant ne peut pas la lire en médailles.

## Pour qui

L'élève (sa fiche à revoir, l'exercice proposé, le résultat) ; l'enseignant (les fiches à revoir de sa classe).

## Pourquoi maintenant

Décision du porteur du 2026-11-09, définitive : « tous les élèves ayant la médaille Bronze ou Argent sont dans la remédiation ». Les chantiers médailles (élève, enseignant, vocabulaire) ont laissé le seuil en l'état et l'ont noté à trancher.

## Règle décidée

Une fiche est à revoir tant que la médaille de l'élève sur l'exercice est Bronze ou Argent. Elle n'est levée qu'à partir de l'Or (Or et Diamant). Une seule échelle : la médaille, lue sur la note affichée sur 20 (ADR-0106), jamais sur le pourcentage brut. Le seuil de levée est celui de l'Or.

## Hors périmètre

- L'ouverture d'une fiche à revoir ne change pas : elle s'ouvre sous la réussite (10/20), pas à l'Argent.
- « Pas encore » (aucun exercice fait) n'entre pas en remédiation.
- Aucune réouverture rétroactive des fiches déjà levées.
- Aucun nouvel écran, aucune migration, aucun changement de libellé visible : les textes disaient déjà « vise l'Or ».
- Les seuils de réussite, d'Argent, d'Or et de Diamant ne bougent pas.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Un « Bronze » peut venir d'un 4/20 : l'ouverture doit-elle aussi suivre la médaille ? | Non décidé par le porteur ; la phrase porte sur qui reste en remédiation, pas sur l'ouverture. Ouvrir à l'Argent multiplierait les fiches à revoir. | Ouverture inchangée (10/20) ; écrit dans `## À trancher` du journal. |
| Les fiches déjà levées entre 15/20 et 16/20 (75-77 %) ? | Elles restent levées : l'historique ne se réécrit pas. | Aucune migration ; écrit dans l'amendement de l'ADR-0043. |
| Les fiches en attente à 15/20 ? | Elles restent en attente et demandent désormais l'Or. | Plus de fiches en attente à court terme : volume mesuré dans le journal. |
| Qui voit quoi : parent, direction, équipe ? | Ils lisent les fiches à revoir en médailles ou en comptes ; aucun écran ne cite 15/20. | Aucun écran à modifier. |
| Un élève dans deux classes ? | La lacune est par élève et par fiche, pas par classe. | Aucun effet. |
| Contexte borné qui porte la règle ? | `assessment` seul. | Un seul endroit : la décision de clôture. |

## Cas limites identifiés

- Palier de l'Or lu sur la note : 78 % s'affiche 16/20 et lève ; 77 % s'affiche 15/20 et ne lève pas.
- Diamant (100 %) : lève.
- Copie vide ou « Pas encore » : ne lève rien, n'ouvre rien de plus.
- Session `standard` à l'Or sur une fiche en attente : `self_corrected`, comme avant.

## Questions encore ouvertes

Aucune bloquante. Mesure sur le jeu standard : aucune session entre 73 et 77 %, donc aucun écart de volume (65 sessions sur 198 à 73 % ou plus, toutes à 78 % ou plus) ; 37 lacunes en attente, aucune levée. Voir `## À trancher` du journal (ouverture à l'Argent).
