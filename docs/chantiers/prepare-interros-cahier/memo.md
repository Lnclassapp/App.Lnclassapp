# Memo — « Prépare interros » et « Prépare devoirs » à l'identique des maquettes cahier

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
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

La seconde maquette (« Prépare devoirs Thalès ») reprend exactement la même feuille pour des **sujets** de devoir : trois
sujets de quatre exercices qui mélangent les notions de la leçon, avec « Notions mobilisées » à la place de « À retenir ».
L'application ne connaît pas de sujet de devoir aujourd'hui.

**Règle du chantier (Touré, 2026-10-30) : le design des deux maquettes s'applique tel quel.** Cadre, typographie, couleurs,
disposition, libellés et boutons sont repris sans changement, sur téléphone comme sur ordinateur. Les maquettes de
référence sont dans [`maquettes/`](maquettes/).

## Pour qui

- **L'élève**, qui révise une leçon avant une interrogation.
- **L'enseignant**, qui ouvre la même page pour assigner des exercices à sa classe.

## Pourquoi maintenant

Touré a fini la maquette le 2026-10-29 et demande que l'application la reprenne telle quelle, sans changer de design. Le
chantier `correction-comme-en-classe` est clos : la feuille, la correction complète et la pause de « Recommencer » existent.

## Hors périmètre

- Le design « cahier noir et blanc » de la feuille d'un exercice assigné, hors de la page de la leçon (issue #390), en
  attente du porteur.
- « Signaler une erreur » de la maquette (un envoi par e-mail à l'équipe) : un autre chantier, il demande un envoi côté serveur.
- La note de l'enseignant sur les réponses rédigées (ADR-0115, option E).
- Ce que voient le parent, la direction et l'équipe : la page de la leçon ne change pas pour eux, sauf l'équipe qui voit
  la feuille comme l'enseignant, sans « Assigner ».

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

Touré demande les maquettes telles quelles (2026-10-30) et ajoute « Prépare devoirs » au chantier. Là où une maquette
contredit une règle de l'application, la ligne dit ce qui est retenu ; le porteur a donné son accord (rapporté par Touré, 2026-10-30).

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Q1. « Vérifier ma réponse » sous un exercice rend-il une vraie copie (note vue par l'enseignant, maîtrise, badge, pause de 3 copies) ? | Oui | Aucune règle de note ne change. La page de la leçon rend la copie sans en sortir : l'exercice se remplace par sa version corrigée |
| Q2. La maquette note sur 10 (« Excellent » dès 9) ; l'application note sur 20 (« Très bien » dès 16, ADR-0115) | Design tel quel : « Ta note : x / 10 », « Mention : … » comme la maquette, calculés sur la même copie. **Le porteur est d'accord** (rapporté par Touré, 2026-10-30) | Seule cette page affiche sur 10 ; la page de résultat et l'enseignant gardent la note sur 20 |
| Q3. « Indice » : l'application ne connaît pas d'indice | Un indice par exercice, facultatif, écrit dans le fichier d'import ; sans indice, pas de bouton | Donnée nouvelle sur l'exercice et dans l'import |
| Q4. « Recommencer cette notion » et « Recommencer ce sujet » | Gardés, comme la maquette : ils remettent à blanc les exercices de la feuille ; chaque nouvelle copie reste soumise à la pause | La pause reste la seule limite ; le bouton ne contourne rien |
| Q5. Que voit l'enseignant ? | La même feuille, sans champs de réponse, avec « Assigner à … » à la place de « Vérifier ma réponse » et « Indice » | Les bascules d'assignation d'aujourd'hui passent dans la feuille |
| Q6. Quand un exercice est-il « Réussi » ? | Comme la maquette : toutes ses questions justes, à la dernière copie vérifiée | Compteur « x / n exercices réussis » par notion ou par sujet |
| Q7. Les exercices d'un type absent de la maquette (association, ordre, liste, rédaction, cahier) | Rendus dans le même cadre, avec leur interaction d'aujourd'hui | Aucun exercice de la leçon ne disparaît |
| Q8. Qu'est-ce qu'un sujet de devoir ? | Un titre, la liste des notions mobilisées et ses exercices dans l'ordre, écrits dans le fichier d'import de la leçon | Donnée nouvelle ; un exercice de sujet n'a pas de notion |
| Q9. Où va « Prépare devoirs » dans la page ? | Juste sous « Prépare interros », un sujet par feuille ; sans sujet, la section n'apparaît pas | Les exercices « Toute la leçon » sans sujet restent sous « Prépare interros », dans une dernière feuille |
| Q10. Les réponses tapées avant « Vérifier » survivent-elles à un rechargement ? | Oui, dans le navigateur, comme la maquette | Rien n'est envoyé avant « Vérifier » |

## Cas limites identifiés

- Une notion sans exercice : sa feuille n'apparaît pas (son ancre « notion-… » reste, comme aujourd'hui).
- L'élève en pause (3 copies en 30 minutes) clique « Vérifier ma réponse » ou « Refaire l'exercice » : la feuille dit l'heure
  de reprise, ses réponses restent dans les champs.
- Un exercice archivé pendant que la page est ouverte : « Vérifier » répond que l'exercice n'existe plus, sans perdre la page.
- Un élève non connecté : la feuille se lit, « Vérifier » mène à la connexion.
- Une notion sans « À retenir » : l'encadré n'apparaît pas.

## Questions encore ouvertes

- Aucune.
