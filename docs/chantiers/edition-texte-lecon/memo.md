# Memo — Corriger le texte d'une leçon à l'écran

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-11-14 |
| **Branche** | `feature/edition-texte-lecon` |
| **Programme** | — |

---

## Le problème

Une coquille dans une notion ou un exercice d'une leçon publiée ne se corrigeait qu'en réimportant la leçon (ADR-0113 §4.6). Une leçon déjà travaillée par des élèves ne peut pas être supprimée puis réimportée sans perdre leurs résultats : l'équipe n'avait aucun moyen de la corriger.

## Pour qui

L'équipe (Team), sur la page de la leçon : fiche de révision (notions) et feuille d'exercices.

## Pourquoi maintenant

Demande du porteur après le bugfix `edition-lecon-equipe` (#598), tranchée le 2026-11-14 ; la suppression d'une leçon (`suppression-lecon`) sera refusée dès qu'un élève l'a travaillée et renverra ici.

## Hors périmètre

- Ajouter, retirer ou réordonner une notion, un exercice, une question, une proposition ou une étape : import (ADR-0116).
- L'entraînement (« Je m'entraîne ») et la figure d'une notion : import.
- Recalculer un résultat passé après un changement de bonne réponse : refusé par décision.
- Le champ « Contenu » (Action Text) de la modale de la leçon : il reste (décision du porteur).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| La bonne réponse peut-elle changer après des tentatives ? | Oui (porteur) | Les résultats passés restent ; la nouvelle clé vaut pour la suite ; le journal nomme les questions changées |
| Faut-il amender ADR-0035/0036 ? | Non, c'est `suppression-lecon` | ADR-0113 §4.6 seul est amendé |
| Deux voies de correction ? | Sans activité : supprimer et réimporter ; avec : à l'écran | Écrites dans ADR-0113 |

## Cas limites identifiés

- Formulaire ouvert avant un réimport : identifiants différents → `structure_changed`, sous verrou.
- Nom de notion déjà pris dans la leçon → `taken`.
- Question dont la nouvelle clé casse sa règle de type (deux bonnes réponses en choix unique) → refus, sauf si elle la cassait déjà.
- Proposition reliée (« Relier ») : son texte relié se corrige, sa paire non.

## Questions encore ouvertes

- Aucune.
