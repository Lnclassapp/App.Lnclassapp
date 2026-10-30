# Memo — « Prépare interros » à l'identique de la maquette cahier

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-30 |
| **Branche** | `feature/prepare-interros-cahier` |
| **Programme** | — |

---

## Le problème

Dans la page d'une leçon, « Prépare interros » est une liste de liens : un exercice par ligne, groupés par notion. L'élève
ouvre chaque exercice sur une autre page, le fait, le vérifie, puis revient à la liste. Il ne voit jamais la notion en entier.
Il ne retrouve pas non plus la feuille d'interrogation qu'il connaît en classe.

La maquette de Touré (« Prépare interros Thalès », projet de design, 2026-10-29) montre ce que l'élève devrait avoir :
- une feuille de cahier en noir et blanc ;
- pour chaque notion, un encadré « À retenir », puis ses exercices les uns sous les autres, sur la même page ;
- dans chaque exercice, des questions de quatre types (QCM, Complète, Vrai ou faux, Calcul) ;
- sous chaque exercice, « Indice » et « Vérifier ma réponse » ; une fois vérifié : la note, une mention et la correction
  de chaque question, puis « Refaire l'exercice » ;
- une progression : combien d'exercices sont réussis.

## Pour qui

- **L'élève**, qui révise une leçon avant une interrogation.
- **L'enseignant**, qui ouvre la même page pour assigner des exercices à sa classe.

## Pourquoi maintenant

Touré a fini la maquette le 2026-10-29 et demande que l'application la reprenne telle quelle, sans changer de design. Le
chantier `correction-comme-en-classe` est clos : la feuille, la correction complète et la pause de « Recommencer » existent.

## Hors périmètre

- « Prépare devoirs » (la seconde maquette, trois sujets de quatre exercices) : un autre chantier.
- Le design « cahier noir et blanc » des sujets assignés hors de cette page (issue #390), en attente du porteur.
- …

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

Touré demande la maquette telle quelle (2026-10-30). Les réponses ci-dessous sont les propositions de Claude, faites là où la
maquette contredit une règle de l'application ; Touré les valide, puis le porteur.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Q1. « Vérifier ma réponse » sous un exercice rend-il une vraie copie (note vue par l'enseignant, maîtrise, badge, pause de 3 copies) ? | Proposé : oui, comme aujourd'hui | Aucune règle de note ne change. La page de la leçon rend la copie sans en sortir : l'exercice se remplace par sa version corrigée |
| Q2. La maquette note sur 10, avec « Excellent » dès 9. L'application note sur 20, avec « Très bien » dès 16 (ADR-0115). Laquelle ? | Proposé : la note sur 20 et l'appréciation de l'application, dans le cadre et la typographie de la maquette | L'élève lit la même note que l'enseignant et que la page de résultat. Écart assumé avec la maquette sur ce seul chiffre |
| Q3. « Indice » : l'application ne connaît pas d'indice | Proposé : un indice par exercice, facultatif, écrit dans le fichier d'import ; sans indice, pas de bouton | Donnée nouvelle sur l'exercice et dans l'import |
| Q4. « Recommencer cette notion » remet à zéro trois exercices d'un coup, alors que la pause bloque après 3 copies | Proposé : retiré ; chaque exercice garde « Refaire l'exercice », soumis à la pause | La pause reste la seule règle de recommencement |
| Q5. Que voit l'enseignant sur cette page ? | Proposé : la même feuille, sans champs de réponse ni « Vérifier », avec « Assigner » sous chaque exercice | Les bascules d'assignation d'aujourd'hui passent dans la feuille |
| Q6. Quand un exercice est-il « Réussi » dans la progression ? | Proposé : comme la maquette, quand toutes ses questions sont justes à la meilleure copie | Compteur par notion et pour la leçon |
| Q7. Les exercices d'un type absent de la maquette (association, ordre, liste, rédaction, cahier) | Proposé : rendus dans le même cadre noir et blanc, avec leur interaction d'aujourd'hui | Aucun exercice de la leçon ne disparaît de la page |

## Cas limites identifiés

- …

## Questions encore ouvertes

- …
