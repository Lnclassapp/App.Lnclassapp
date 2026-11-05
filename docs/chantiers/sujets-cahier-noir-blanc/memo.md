# Memo — Les sujets d'interrogation en cahier noir et blanc

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-11-05 |
| **Branche** | `feature/sujets-cahier-noir-blanc` |
| **Programme** | — |
| **Issue** | #390 |

---

## Le problème

Depuis `prepare-interros-cahier`, les feuilles de la page d'une leçon et les devoirs reçus sont en noir, blanc et gris, comme une
feuille d'interrogation distribuée en classe. Mais dès que l'élève ouvre un exercice seul, remplit sa copie ou lit son résultat,
il retombe sur les cartes arrondies de l'application, en bleu, vert et rouge. Le sujet ne ressemble plus à une interrogation, et la
correction parle encore en couleurs.

## Pour qui

- **L'élève**, qui fait un exercice, remplit sa copie et lit sa correction.
- **L'enseignant et l'équipe**, qui ouvrent le même sujet et le même résultat (copie d'un élève).

## Pourquoi maintenant

Le porteur l'a demandé (#390) ; `correction-comme-en-classe` et `prepare-interros-cahier` sont fusionnés : la collision sur la copie
de l'élève ne bloque plus.

## Hors périmètre

- La fiche de révision : elle garde ses couleurs.
- Les feuilles de la page de la leçon et les devoirs reçus : déjà en noir et blanc (`prepare-interros-cahier`).
- L'en-tête, la barre de navigation et le reste de l'application : inchangés.
- Toute règle de note, de pause ou de soumission : rien ne change, seule l'apparence change.
- « Signaler une erreur » par e-mail : autre chantier.
- La matière et la classe dans le cartouche du sujet : elles demandent une donnée que la copie ne lit pas aujourd'hui (à trancher).
- Parent, direction : ils n'ouvrent pas ces écrans aujourd'hui ; rien ne change pour eux.

## Ce que le grill a révélé

Session lancée par l'orchestrateur ; les réponses sont les décisions qu'il a transmises (2026-11-05) et l'UDR-0140.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Q1. Le cartouche affiche-t-il « Durée : 20 minutes » ? | Non : aucune durée nulle part (UDR-0140 §4) | Pas de durée dans le cartouche |
| Q2. La consigne dit-elle « une seule tentative » ? | Non : 3 copies puis une pause | Consigne = nombre de questions et barème seulement |
| Q3. « Rendre ma copie » puis une confirmation ? | Non : un seul bouton « Vérifier ma copie » et la phrase de verrouillage | Le bouton et la phrase d'aujourd'hui restent ; la demande de confirmation des questions vides (UDR-0087 §3.2) reste, ce n'est pas une seconde confirmation systématique (à trancher) |
| Q4. Note sur 10 et mention ? | Non : appréciation en titre, note sur 20, points, « À revoir », correction | Le résultat garde son contenu ; seule la couleur part |
| Q5. Le devoir reçoit-il le même design ? | Oui (option prudente, maquette `Devoir Thales cahier`) | Le devoir reçu est déjà en noir et blanc ; ses copies et résultats passent par les mêmes vues, donc le reçoivent aussi |
| Q6. Juste / Faux sans couleur ? | Oui : le mot et l'icône portent le sens | Les verdicts gardent leur texte ; la couleur devient du gris |
| Q8. Papier blanc ou cahier ? Devoir reçu ? | Décision du porteur (2026-11-05) : pas de maquette par sujet ; le tableau de l'issue et l'exemple Thalès sont un gabarit générique pour tous les sujets d'interrogation et de devoir, toutes matières. Papier `#fbf6e9`, Seyès grises, marge grise, pour tous | Un gabarit commun `exam_sheet.css`, repris par `.ps-sheet` |
| Q7. Que voit l'enseignant ? | Le même sujet et le même résultat, en noir et blanc | Aucune vue par rôle à ajouter |

## Cas limites identifiés

- Exercice sans figure, sans blocs, sans indice : le cartouche et la consigne restent.
- Toutes les questions à 1 point : la consigne ne parle pas de barème (UDR-0140 §3).
- Mode sombre du téléphone : la feuille reste blanche, comme les feuilles de la leçon.
- 375 px : aucun défilement horizontal.

## Questions encore ouvertes

Voir `journal.md` § À trancher.
