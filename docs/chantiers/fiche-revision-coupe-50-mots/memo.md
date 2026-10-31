# Memo — La fiche de révision coupée à 50 mots

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-10-31 |
| **Branche** | `feature/fiche-revision-coupe-50-mots` |
| **Programme** | — |

---

## Le problème

Sur la page d'une leçon, la fiche de révision montre 150 mots avant « Voir plus ». C'est presque toute une notion : l'élève fait défiler longtemps avant d'atteindre la suite de la page, et le bouton ne joue plus son rôle d'aperçu.

## Pour qui

L'élève et l'enseignant qui ouvrent une leçon (page de la leçon, et page de la leçon vue depuis une classe), d'abord sur téléphone.

## Pourquoi maintenant

Demande du porteur du 2026-10-31.

## Hors périmètre

- La fiche en plein écran (PR #398, retirée par #411) : elle ne revient pas.
- Le comportement de « Voir plus » / « Voir moins » : fiche ouverte d'emblée, coupée, dépliée sur place, sans requête.
- La manière de compter les mots (formule = un mot, figure = zéro, coupe en fin de bloc) : inchangée.
- Un seuil réglable par leçon ou par l'équipe.

## Ce que le grill a révélé

| Question | Réponse | Conséquence sur le chantier |
|---|---|---|
| Le seuil est-il écrit à plusieurs endroits ? | Non : une seule constante du domaine, lue par la coupe. | Un seul changement de code ; les commentaires qui citent « 150 » suivent. |
| La coupe tombe-t-elle au mot près ? | Non : en fin du bloc qui atteint le seuil (règle d'UDR-0139 §3.2). | Avec 50 mots, la partie visible est en pratique « À retenir », parfois avec la méthode. Rien à changer à la règle. |
| Une notion courte reste-t-elle entière ? | Une notion type compte environ 48 mots : seule, pas de coupe ; dès deux notions, la seconde est derrière « Voir plus ». | Le test « fiche courte » garde une seule notion ; le test de la coupe la prouve avec 60 mots + une notion. |
| Le seuil est-il figé dans une décision d'interface ? | Oui, UDR-0139 §3.2 et UDR-0141 citent les 150 mots. | Une UDR d'amendement consigne le passage à 50. |
| Parent, établissement, équipe ? | Ils voient la même fiche, avec la même coupe ; l'équipe relit aussi les brouillons. | Rien de propre à un acteur. |

## Cas limites identifiés

- Total ≤ 50 mots : pas de coupe, pas de bouton.
- Un premier bloc de plus de 50 mots reste entier ; s'il est le seul, pas de coupe.

## Questions encore ouvertes

- Aucune.
