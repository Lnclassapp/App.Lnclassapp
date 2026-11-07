# Memo — Suivi de la classe sur une leçon : lacunes, réussite par exercice, remédiation

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-11-05 |
| **Branche** | `feature/suivi-classe-lecon` |
| **Programme** | — |

---

## Le problème

La refonte de la page de la leçon (issue #340) a retiré les pages de notion, et trois fonctions sont parties avec elles :

1. L'enseignant ne voit plus, notion par notion, quels élèves de sa classe ont une lacune ouverte et lesquels l'ont levée. La page de la classe affiche encore « Fiches à revoir » avec un nombre d'élèves, mais le lien mène à la leçon, où rien ne détaille ce nombre.
2. L'enseignant ne voit plus le taux de réussite de sa classe exercice par exercice.
3. L'élève qui a une lacune n'a plus d'exercice de remédiation proposé : il doit trouver seul quoi refaire.

## Pour qui

- **Enseignant**, depuis la page de sa classe ou la page de la leçon vue depuis la classe, quand il prépare sa prochaine séance.
- **Élève**, après un exercice raté qui ouvre une lacune, et depuis « Fiches à revoir » de « Ma classe ».

## Pourquoi maintenant

Le porteur a fusionné la refonte en acceptant ce manque, à condition de le remettre dans un chantier de suivi (2026-10-28). Le compteur « Fiches à revoir » promet aujourd'hui un détail qui n'existe plus.

## Hors périmètre

- Le parent : il ne voit ni les lacunes de la classe ni la réussite par exercice (pas plus qu'aujourd'hui).
- Les sujets de devoir (exercices sans notion) : pas de lacune, donc pas de remédiation ; leur réussite par exercice est affichée comme les autres.
- Une nouvelle règle d'ouverture ou de levée des lacunes : on montre celles qui existent, la règle actuelle ne change pas.
- Toute statistique au-delà d'un exercice (moyenne de la leçon, évolution dans le temps, export).
- La direction n'assigne rien et ne modifie pas les jours de séance.
- Le choix de l'exercice proposé ne se règle pas par l'enseignant (pas de « proposer cet exercice-ci »).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Où l'enseignant voit-il « à revoir / levée » d'une notion ? | Sur la page de la leçon vue depuis la classe, sous chaque notion | Pas de nouvelle page ni de route : un bloc dans la leçon en classe. Le lien de « Fiches à revoir » (page de la classe), qui pointe déjà vers l'ancre de la notion, tient enfin sa promesse |
| Où propose-t-on l'exercice de remédiation à l'élève ? | À trois endroits : « Fiches à revoir » de « Ma classe », la page de résultat de l'exercice raté, la notion dans la page de la leçon | Un seul choix d'exercice (même règle partout), servi à trois vues : les trois doivent proposer le même exercice au même moment. Trois vues modifiées → UDR |
| Qui d'autre que l'enseignant voit les noms « à revoir / levée » et la réussite par exercice ? | L'équipe Lnclass (comme aujourd'hui) et la direction de l'établissement ; pas le parent | La direction voit déjà la liste des élèves d'une classe de son établissement, mais pas la page d'une leçon dans la classe ni les lacunes nominatives : c'est un droit de lecture nouveau → règle d'accès écrite et testée (une classe d'un autre établissement n'existe pas pour elle), ADR et revue sécurité obligatoires. La direction lit, n'assigne pas. Le parent est hors périmètre |
| La dette de #340 (code mort, route d'images de question sans formulaire, « Modifier les jours » et bascules d'assignation de l'équipe) : ici ou à part ? | Tout ici | Le chantier grossit : un lot de nettoyage (code mort, route) à comportement identique, et un lot d'interface pour les jours de séance et les bascules de l'équipe. Vérifié : le bloc « Jours de séance » n'est plus rendu nulle part ; un enseignant qui a déjà renseigné ses jours ne peut plus les modifier |
| Où remettre « Modifier les jours » ? | Sur la page de la classe : le bloc « Jours de séance » revient, avec son menu « Modifier les jours » | Réutilise la fenêtre des jours qui existe encore ; rien sur la page de la leçon |
| L'équipe peut-elle de nouveau assigner un exercice à une classe ? | Oui, depuis la leçon ouverte depuis une classe, pour cette seule classe | La règle d'assignation l'autorise peut-être déjà ; c'est l'écran qui ne lui montre pas la barre. À vérifier en décision : si la règle refuse l'équipe, c'est un droit qui change → ADR |
| Pour la réussite par exercice, quelle copie compte quand un élève a fait l'exercice plusieurs fois ? | La meilleure : un élève compte une fois, réussi s'il a au moins une copie à 10/20 ou plus | Le taux s'exprime en élèves (« 12 / 20 élèves ont réussi »), pas en copies ; même règle que « la meilleure note compte » |

## Cas limites identifiés

- Notion dont le seul exercice publié est celui raté : on repropose ce même exercice (pas d'autre choix).
- Notion sans aucun exercice publié (retiré depuis l'ouverture de la lacune) : aucune proposition ; la ligne reste dans « Fiches à revoir » et mène à la notion de la leçon.
- Exercice proposé en pause (3 copies, puis 30 minutes) : on le propose quand même ; la page de l'exercice dit déjà « Tu pourras recommencer à … ».
- Élève parti de la classe ou compte anonymisé : absent des listes (règle des élèves présents, déjà en place).
- Élève dans deux classes qui suivent la même leçon : la lacune est à l'élève, pas à la classe ; il apparaît dans les deux classes.
- Lacune levée l'année scolaire précédente : n'apparaît pas dans « levée » ; une lacune en attente apparaît quelle que soit sa date.
- Classe sans aucune copie sur un exercice : « Pas encore fait » au lieu de « 0 % ».
- Classe de 1 élève : le taux s'affiche en nombre (« 1 / 1 élève »), jamais en pourcentage seul.
- Classe de 60 élèves avec 30 lacunes sur une notion : la liste se replie après quelques noms (« Voir plus »).
- Classe archivée : la page n'existe plus (404), comme aujourd'hui.
- Direction d'un autre établissement : la classe n'existe pas pour elle (404), comme pour les membres.
- Enseignant qui enseigne dans deux établissements : voit le détail pour ses seules classes, comme aujourd'hui.

## Questions encore ouvertes

- Emplacement de la réussite par exercice : décidé en phase 2 (sous chaque exercice de la feuille vue depuis la classe, dans la barre de l'enseignant), réversible.
- La direction a-t-elle une entrée vers la leçon en classe ? Décidé en phase 2 : le bloc « Fiches à revoir » apparaît sur sa page de la classe et mène à la leçon en classe, en lecture seule.
