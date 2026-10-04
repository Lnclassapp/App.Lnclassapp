# Memo — L'élève voit son propre progrès

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-04 |
| **Branche** | `feature/progres-eleve` |
| **Programme** | `refonte-application` — suite du chantier [`rapports-exercices`](../rapports-exercices/memo.md) (V3), à rattacher à une vague par le porteur |

---

## Le problème

Un élève refait un exercice : 30 %, puis 60 %, puis 90 %. Il voit chaque fois un résultat de session (UDR-0023), et son meilleur score avec son badge sur la fiche. Mais **personne ne lui dit qu'il a progressé**. Avec `rapports-exercices`, son enseignant le voit (« ↗ en progrès », ADR-0079). Lui ne le voit pas.

La mission de Lnclass est d'aider chaque acteur du système éducatif à progresser (porteur, 2026-10-04). Le premier acteur concerné par son progrès est l'élève lui-même.

## Pour qui

- **L'élève (Student)** : à la fin d'une session qu'il refait, et sur ses pages où il retrouve ses exercices.
- *(à griller : l'enseignant, l'équipe, la direction et le parent voient-ils quelque chose de nouveau ?)*

## Pourquoi maintenant

`rapports-exercices` fixe les règles du signe de progrès (ADR-0079 : premier, meilleur et dernier essai, marge de 10 points). Les montrer à l'élève réutilise ces règles sans en inventer. Le porteur a demandé l'ouverture du chantier le 2026-10-04.

## Hors périmètre

- La lecture de classe vue par l'enseignant : chantier `rapports-exercices`.
- *(à compléter pendant le grill)*

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Faut-il montrer à l'élève son propre signe de progrès ? | **Oui, dans un chantier à part** (porteur, 2026-10-04, pendant `rapports-exercices`). | Ouverture de ce chantier. Les règles du signe viennent de l'ADR-0079 ; l'élève ne voit jamais celui d'un camarade. |

## Cas limites identifiés

- *(à griller : un seul essai ; « en baisse » montré à un élève sans le décourager, alors que la charte §5 interdit la sanction ; exercice fait hors assignation ; élève dans deux classes)*

## Questions encore ouvertes

- Où l'élève voit-il son progrès : au résultat de la session, sur la fiche de l'exercice, sur son accueil ?
- Lit-on toutes ses sessions sur l'exercice, ou seulement celles d'une assignation comme l'enseignant ?
- Comment dire « en baisse » à un élève de 11 ans sans le décourager ?
