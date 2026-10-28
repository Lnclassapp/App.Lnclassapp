# Memo — Corriger une copie comme en classe

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | décision |
| **Ouvert le** | 2026-10-28 |
| **Branche** | `feature/correction-comme-en-classe` |
| **Programme** | — |
| **Origine** | issue #350 : proposition de Touré, décisions D1 à D4 du porteur le 2026-10-28 |

---

## Le problème

Un élève traite un exercice comme une interrogation en classe : il remplit toute la feuille, puis rend sa copie. En retour,
il ne reçoit qu'une partie de ce que donnerait un enseignant :

- la note sur 20, la maîtrise, le badge ;
- pour chaque question, « Juste », « Faux » ou « Sans réponse », son propre choix et l'explication.

Il ne voit **jamais la bonne réponse** : décision du porteur du 2026-09-25, prise pour qu'un élève ne refasse pas l'exercice
la correction sous les yeux. Une faute reste donc incomprise quand l'explication ne suffit pas.

Il ne reçoit **aucune appréciation** : un titre (« Félicitations ! » ou « Courage ! ») et une phrase tirée au hasard, sans lien
avec ses erreurs ni avec ce qu'il doit revoir.

## Pour qui

- **L'élève**, juste après avoir rendu sa copie, puis chaque fois qu'il relit sa correction.
- **L'enseignant**, qui lit les notes de sa classe et doit pouvoir s'y fier : une note obtenue après avoir vu la correction ne
  mesure plus rien.

## Pourquoi maintenant

La refonte de la page de la leçon (lots 0 à D, fusionnés le 2026-10-28) a fait de l'exercice une vraie copie, rendue d'un
seul envoi. La correction est l'étape qui suit, et le contenu Thalès v2 en sera le premier terrain. Le porteur a tranché
D1 à D4 le même jour.

## Décisions du porteur (2026-10-28, issue #350)

- **D1** : après la copie rendue, l'élève voit sa réponse, la bonne réponse et l'explication. Jamais avant.
- **D2** : seule la première copie compte pour la note vue par l'enseignant, la maîtrise et le badge. Une fois la correction
  vue, « Recommencer » ne sert plus qu'à s'entraîner.
- **D3** : une appréciation selon la note : « Très bien » dès 16/20, « Bien » dès 12, « Assez bien » dès 10, « À retravailler »
  en dessous. Elle nomme les notions à revoir et les questions en cause.
- **D4** : le bouton garde son nom, « Rendre ma copie ».

**Révision demandée par Touré au grill (Q4, Q4 bis), à valider par le porteur** : D2 est abandonnée, la meilleure note
continue de compter partout, pour l'élève comme pour l'enseignant. En contrepartie, « Recommencer » se met en pause
30 minutes après 3 copies rendues d'affilée (Q5).

## Hors périmètre

- Une appréciation écrite à la main par l'enseignant.
- Un barème par question (des questions à 1 et à 2 points) : chaque question compte autant, comme aujourd'hui.
- Les réponses rédigées, corrigées par l'enseignant.
- Une durée limitée ou un chronomètre.
- Le libellé du bouton (D4 : inchangé).
- Toute règle de note : la meilleure note compte partout, comme aujourd'hui (Q4). Ni la maîtrise, ni le badge, ni la note
  vue par l'enseignant ne changent de calcul.
- Les lacunes : elles s'ouvrent et se referment comme aujourd'hui, à chaque copie rendue (Q2).
- Rattacher une question d'un exercice de toute la leçon à une notion (Q3).
- Le Parent : ce rôle n'existe pas dans l'application.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Q1. Un élève fait librement l'exercice (8/20), voit la correction, puis l'enseignant l'assigne et l'élève le refait (19/20). Quelle note voit l'enseignant ? | 19/20, sans mention (Touré) | « Première copie » se lit **par devoir** : la première copie rendue dans le cadre de l'assignation. Les copies libres d'avant ne comptent pas pour le devoir. Risque accepté : une note de devoir peut être faite correction vue, sans que l'enseignant le sache. À confirmer par le porteur, car D2 vise justement ce risque |
| Q2. Une copie d'entraînement réussie referme-t-elle encore la lacune de la notion ? | Oui (Touré) | D2 ne s'applique qu'à la note vue par l'enseignant, à la maîtrise et au badge. La lacune reste un outil de révision : toute copie rendue, entraînement compris, l'ouvre ou la referme comme aujourd'hui |
| Q3. Un exercice de toute la leçon n'a aucune question rattachée à une notion : quelles « notions à revoir » nomme l'appréciation ? | Les questions seulement (Touré) | Pour un exercice de toute la leçon, l'appréciation nomme les questions en cause et renvoie à la leçon, sans notion. Pour un exercice de notion, elle nomme sa notion. Aucune donnée nouvelle, ni l'import ni le contenu ne changent |
| Q4. Quelle note l'élève voit-il dans ses listes : la première, comme l'enseignant avec D2, ou la meilleure ? | La meilleure, pour l'élève **et** l'enseignant : « mettre à jour D2 » (Touré) | **D2 est remise en cause** : on garde la règle d'aujourd'hui, la meilleure note compte partout. Q1 n'a plus d'objet |
| Q4 bis. Avec la bonne réponse visible après chaque copie, la meilleure note devient 20/20 dès la deuxième copie. Meilleure note avec correction tout de suite, correction d'un devoir après sa date limite, ou D2 tel quel ? | Meilleure note, correction tout de suite (Touré), en connaissance du risque | Risque assumé : une note de devoir peut être obtenue la correction sous les yeux. **À faire valider par le porteur avant le PRD**, car cela annule D2. Le chantier rétrécit : aucune règle de note ne change, il reste la correction complète (D1) et l'appréciation (D3) |
| Q5. La meilleure note compte et la correction est visible : faut-il freiner « Recommencer » ? | Oui : après 3 copies rendues d'affilée, « Recommencer » disparaît 30 minutes, puis 3 copies sont de nouveau possibles (Touré, Q5 bis) | Règle nouvelle au démarrage d'une copie, dans le domaine. La page du résultat dit quand l'élève pourra recommencer. La pause doit aussi tenir si l'élève relance l'exercice depuis la leçon ou depuis un autre onglet, pas seulement sur la page du résultat |
| Q6. À 13/20, « Courage ! » en titre contredirait l'appréciation « Bien ». Que garde-t-on ? | Le titre devient l'appréciation ; la phrase d'encouragement tirée au hasard reste en dessous (Touré) | « Félicitations ! » et « Courage ! » disparaissent. La phrase d'encouragement, la couleur de la note et les confettis gardent leur seuil de 14/20 : à 12 ou 13/20, l'élève lit « Bien » avec une phrase du groupe « Courage » (« Oups ! C'était presque ça… »). Écart de ton à montrer au porteur |
| Q7. L'enseignant ou l'équipe qui ouvre le résultat d'un élève voit-il l'appréciation ? | Oui, la même que l'élève, sans la phrase d'encouragement (Touré) | L'appréciation se calcule à partir de la copie, pas du lecteur : une seule règle pour tous ceux qui lisent le résultat |
| Fait vérifié : un exercice publié peut-il changer de bonnes réponses après des copies ? | Non : ses questions se verrouillent dès la première copie ; un réimport crée un nouvel exercice en brouillon | La correction d'une ancienne copie montre toujours les bonnes réponses qui ont servi à la noter. Pas d'instantané à garder |

## Cas limites identifiés

Imposés par le porteur (issue #350), à couvrir au minimum :

- une copie rendue puis recommencée ;
- une copie abandonnée ;
- un exercice assigné par l'enseignant ;
- un exercice de toute la leçon ;
- une question laissée vide ;
- une leçon réimportée entre deux copies.

Révélés par le grill :

- une question laissée vide : verdict « Sans réponse », la bonne réponse et l'explication s'affichent quand même ;
- une copie abandonnée : jamais corrigée, aucune bonne réponse montrée ; elle ne compte pas dans les 3 copies de la pause ;
- la 3e copie rendue : la page du résultat ne propose plus « Recommencer » et dit à quelle heure il revient ;
- l'élève relance l'exercice depuis la leçon, ou depuis un autre onglet, pendant la pause : refus, avec la même heure ;
- une copie à 20/20 : pas de « Recommencer » (comme aujourd'hui), donc pas de pause à afficher ;
- une copie de remédiation et une copie de devoir comptent-elles dans les 3 ? (question ouverte) ;
- un exercice de toute la leçon : l'appréciation nomme les questions en cause, jamais une notion ;
- une copie sans faute, ou sans question en cause : l'appréciation ne dit rien à revoir ;
- une copie entièrement vide : 0/20, « À retravailler », toutes les questions en cause ;
- un exercice réimporté entre deux copies : c'est un autre exercice ; les anciennes copies gardent leur correction.

## Questions encore ouvertes

- **Pour le porteur** : valide-t-il l'abandon de D2 (Q4 bis) et la pause de « Recommencer » (Q5) ?
- **Pour le porteur** : l'écart de ton à 12 et 13/20, entre « Bien » et une phrase du groupe « Courage » (Q6), lui convient-il ?
- Les 3 copies de la pause se comptent-elles par exercice, toutes sortes confondues (libre, devoir, remédiation) ?
  Proposition : oui, par exercice, toutes sortes confondues.
- Où l'appréciation se coupe-t-elle quand beaucoup de questions sont en cause ? Proposition : la liste des numéros
  (« questions 2, 3 et 7 »), sans limite, puisqu'un exercice en a rarement plus de 10.
