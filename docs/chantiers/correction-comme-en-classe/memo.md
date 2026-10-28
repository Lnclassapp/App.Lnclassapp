# Memo — Corriger une copie comme en classe

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | décision — memo et PRD à relire par le porteur |
| **Ouvert le** | 2026-10-28 |
| **Pilote** | le porteur, qui cadre lui-même depuis le 2026-10-28 (issue #350) |
| **Branche** | `feature/correction-comme-en-classe`, à repartir de `Develop` : le premier cadrage de Touré (`67c36f94`, `b56a0168`) est remplacé par ce memo et ne se fusionne pas |
| **Programme** | — |
| **Origine** | issue #350 (proposition de Touré, décisions D1 à D4) ; maquettes de Konan « La propriété de Thalès : je m'évalue » et « Les lentilles : je m'évalue » ; décisions du porteur du 2026-10-28 |

---

## Le problème

Un élève traite un exercice comme une interrogation en classe : il remplit toute la feuille, puis rend sa copie. En retour,
il ne reçoit qu'une partie de ce que donnerait un professeur :

- la note sur 20, la maîtrise, le badge ;
- pour chaque question, « Juste », « Faux » ou « Sans réponse », son propre choix et l'explication.

Il ne voit **jamais la bonne réponse** (décision du 2026-09-25) : une faute reste incomprise quand l'explication ne suffit pas.
Il ne reçoit **aucune appréciation** : « Félicitations ! » ou « Courage ! », et une phrase tirée au hasard, sans lien avec ses
erreurs.

Surtout, **la feuille ne ressemble pas à un devoir de 3e.** Les maquettes de Konan montrent ce qu'un professeur donne vraiment :
des phrases à compléter avec une liste de mots, des réponses chiffrées avec leur unité, un tableau de mesures ou un document à
lire dans l'énoncé, des questions à rédiger notées sur plusieurs points, une construction à faire sur le cahier. Lnclass ne
sait proposer que des questions qui valent toutes 1 point, sans unité, sans rédaction et avec un énoncé en texte brut.

## Pour qui

- **L'élève de collège ou de lycée**, qui prépare seul une interrogation ou un devoir, sur son téléphone, puis relit sa
  correction.
- **L'enseignant**, qui lit les notes et les copies de sa classe et doit pouvoir s'y fier.
- **L'équipe**, qui écrit les exercices et les importe.

## Pourquoi maintenant

La refonte de la page de la leçon (fusionnée le 2026-10-28) a fait de l'exercice une vraie copie, rendue d'un seul envoi. La
correction est l'étape qui suit. Le contenu Thalès v2 est en production et les maquettes Thalès et Lentilles en donnent le
premier terrain.

## Décisions du porteur (2026-10-28, issue #350 et cette session)

- **D1 — Correction complète.** Une fois la copie vérifiée, l'élève voit sa réponse, la bonne réponse et l'explication. Jamais
  avant.
- **D2 (révisée) — La meilleure note compte, avec une pause.** La meilleure note compte partout, comme aujourd'hui. En
  contrepartie, après 3 copies vérifiées d'affilée sur un exercice, « Recommencer » disparaît 30 minutes. Les 3 copies se
  comptent par exercice, toutes sortes confondues (libre, devoir, remédiation).
- **D3 — L'appréciation.** « Très bien » dès 16/20, « Bien » dès 12, « Assez bien » dès 10, « À retravailler » en dessous. Elle
  nomme ce qu'il faut revoir. À 12 et 13/20, l'élève lit « Bien » avec une phrase du groupe « Courage » : accepté.
- **D4 (remplacée) — Le bouton s'appelle « Vérifier ma copie »**, et la correction s'affiche tout de suite. Il remplace
  « Rendre ma copie ».
- **D5 — Aucune durée.** Ni chronomètre, ni copie rendue d'office, ni « durée conseillée ». La voie B (devoir chronométré) est
  annulée.
- **D6 — Pas de fiche en deux parties.** La maquette « Partie A · interrogation / Partie B · devoir » devient deux exercices
  séparés de la leçon, « Interrogation » et « Devoir ». Chacun a sa copie, sa note et sa pause.
- **D7 — Les réponses rédigées ne comptent pas dans la note.** Le texte de l'élève est gardé dans sa copie. Après
  vérification, il lit un corrigé type et une grille de vérification, et se compare lui-même. La note ne compte que les points
  corrigés automatiquement. L'enseignant lit le texte rédigé.
- **D8 — Un seul bouton par exercice**, en bas de la feuille. Pas de « Vérifier » par question ni de « Vérifier les réponses
  courtes ».

## Ce que le chantier ajoute

Les éléments des maquettes, rapprochés de ce qui existe :

| Élément des maquettes | Aujourd'hui | Ce que le chantier ajoute |
|---|---|---|
| QCM à une seule bonne réponse, vrai ou faux | existe | rien |
| Phrase à compléter par un mot choisi dans une liste (« Le vocabulaire »), choix d'une propriété par situation (« Quelle propriété utiliser ? ») | n'existe pas : le texte à trous se tape | un type nouveau, **le choix dans une liste** : une liste déroulante, placée dans la phrase quand la phrase a un trou |
| Association un à un (« L'œil et son modèle ») | existe, en touchant un élément à gauche puis à droite | rien d'obligatoire ; la forme en liste déroulante est une question de l'UDR |
| Réponse chiffrée (AN, MN, hauteur de l'arbre) | existe, avec une marge | **l'unité** (cm, m), affichée à côté du champ et dans la correction |
| Question à rédiger, « (2 points) », avec un début de phrase | n'existe pas | un type nouveau, **la réponse rédigée** : un texte libre, un corrigé type, une grille de vérification facultative ; jamais noté par la machine |
| Construction ou schéma sur le cahier | n'existe pas | un type nouveau, **le travail sur le cahier** : une consigne sans champ, puis un corrigé type ; jamais noté par la machine |
| Tableau de mesures, document à lire dans l'énoncé | l'énoncé est du texte brut | **un document et un tableau** dans l'énoncé de l'exercice |
| « 5 points », « (2 points) », « noté sur 20 » | chaque question vaut 1 point | **des points par question**, affichés ; la note sur 20 se calcule sur les points corrigés automatiquement |

## Hors périmètre

- Toute durée : chronomètre, copie rendue d'office, durée conseillée (D5).
- La correction d'une réponse rédigée par l'enseignant, et toute note donnée à la main : un chantier à part, plus tard.
- Une note que l'élève se donne lui-même : avec la meilleure note qui compte, il pourrait se mettre 20/20 (D7).
- Une appréciation écrite à la main par l'enseignant.
- Une fiche qui regroupe plusieurs exercices, et un bouton par question (D6, D8).
- Le dessin à l'écran : la construction se fait sur le cahier.
- Une figure ou une formule tapée par l'élève : il répond par un nombre, un choix ou un texte.
- Toute règle de note autre que les points : la meilleure note compte partout, la maîtrise, le badge, les lacunes et la note
  vue par l'enseignant gardent leur calcul. Un exercice dont toutes les questions valent 1 point garde exactement sa note.
- Rattacher une question d'un exercice de toute la leçon à une notion.
- Réécrire les exercices déjà en production : ils restent valables tels quels.
- Le Parent : ce rôle n'existe pas dans l'application.

## Ce que le grill a révélé

> Le grill de Touré (Q1 à Q7, 2026-10-28) est repris ici pour ce qui reste vrai ; les lignes Q8 et suivantes viennent de la
> session du porteur et des maquettes de Konan.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Q2. Une copie d'entraînement réussie referme-t-elle encore une lacune ? | Oui | Les lacunes ne changent pas : toute copie vérifiée les ouvre ou les referme |
| Q3. Un exercice de toute la leçon n'a aucune question rattachée à une notion : que nomme l'appréciation ? | Les questions | Pour un exercice de toute la leçon, l'appréciation nomme les questions en cause et renvoie à la leçon |
| Q4, Q4 bis. Quelle note compte, maintenant que la correction est visible ? | La meilleure, partout ; risque accepté | D2 révisée, aucun calcul de note ne change |
| Q5. Faut-il freiner « Recommencer » ? | Oui : 3 copies, puis 30 minutes | La pause se décide au démarrage d'une copie, d'où que parte l'élève |
| Q6. À 13/20, « Courage ! » contredirait « Bien ». Que garde-t-on ? | Le titre devient l'appréciation | « Félicitations ! » et « Courage ! » disparaissent ; la phrase tirée au hasard reste dessous |
| Q7. L'enseignant voit-il l'appréciation ? | Oui, sans la phrase d'encouragement | Une seule règle pour tous ceux qui lisent le résultat |
| Q8. La maquette montre une durée (« environ 15 min », « 1 heure ») et Touré proposait un chronomètre. On garde ? | Non, aucune durée (D5) | Le memo exclut toute durée ; aucune migration de temps |
| Q9. Interrogation et devoir sur une même fiche, ou deux exercices ? | Deux exercices (D6) | Pas d'objet « fiche » nouveau. L'import exige 4 exercices de toute la leçon : Interrogation et Devoir en sont deux |
| Q10. Une réponse rédigée peut-elle compter dans la note ? | Non (D7) | La note ne compte que les points corrigés automatiquement ; les autres s'affichent à part, « à comparer au corrigé » |
| Q11. Un bouton « Vérifier » par question ou un seul ? | Un seul, « Vérifier ma copie » (D4, D8) | La copie reste rendue d'un seul envoi, comme aujourd'hui |
| Q12. « Quelle propriété utiliser ? » propose 3 propriétés pour 4 situations : la propriété de Thalès sert deux fois. Est-ce une association ? | Non | Une association est un à un. Cet exercice s'écrit en 4 questions « choix dans une liste » qui ont les mêmes propositions. La liste de mots du vocabulaire aussi |
| Q13. Un exercice peut-il n'avoir que des réponses rédigées ou du travail sur le cahier ? | Non, par défaut | Sans question corrigée automatiquement, il n'y a ni note, ni appréciation, ni maîtrise : un tel exercice ne peut pas être publié (PRD, à confirmer) |
| Q14. « Vérifier ma copie » laisse-t-il croire qu'on peut corriger ses réponses après ? | Risque relevé | La copie est rendue d'un seul envoi, comme aujourd'hui. Avant l'envoi, la feuille dit qu'on ne pourra plus changer ses réponses ; l'UDR fixe la phrase |
| Fait vérifié : un exercice publié peut-il changer de bonnes réponses après des copies ? | Non : ses questions se verrouillent dès la première copie, et un réimport crée un nouvel exercice en brouillon | La correction d'une ancienne copie montre toujours ce qui a servi à la noter |
| Fait vérifié : une réponse tapée est bornée à 200 caractères | Trop court pour un paragraphe de 50 mots | La réponse rédigée a sa propre borne (PRD) |

## Cas limites identifiés

Imposés par le porteur (issue #350) :

- une copie vérifiée puis recommencée ;
- une copie abandonnée : jamais corrigée, aucune bonne réponse montrée, hors du compte de la pause ;
- un exercice assigné par l'enseignant ;
- un exercice de toute la leçon ;
- une question laissée vide : « Sans réponse », la bonne réponse et l'explication s'affichent ;
- une leçon réimportée entre deux copies : c'est un autre exercice, les anciennes copies gardent leur correction.

Révélés par le grill :

- une réponse rédigée laissée vide : la copie part quand même ; le corrigé type s'affiche ; la note n'en dépend pas ;
- une copie dont toutes les questions corrigées automatiquement sont justes, mais les réponses rédigées vides : 20/20 et
  « Très bien » ; la page rappelle les points à comparer au corrigé ;
- un exercice ancien, sans points ni unité : chaque question vaut 1 point, aucune unité ne s'affiche, sa note ne change pas ;
- une réponse chiffrée tapée avec son unité (« 4,8 cm ») ;
- une copie vérifiée sans JavaScript : la liste déroulante, l'association et le texte rédigé marchent sans lui ;
- l'enseignant ouvre la copie d'un élève : il lit le texte rédigé tel quel, jamais interprété comme du HTML ;
- la 3e copie vérifiée d'affilée : plus de « Recommencer », l'heure à laquelle il revient.

## Questions encore ouvertes

Le PRD propose une réponse pour chacune ; le porteur tranche.

1. **Le type des deux exercices.** « Interrogation » et « Devoir » sont-ils seulement des titres, ou les deux types existants
   (fixation et évaluation) ? Proposition : Interrogation en fixation, Devoir en évaluation, sans type nouveau.
2. **Les deux autres exercices de toute la leçon.** L'import en exige 4. Proposition : la règle ne change pas ; l'équipe écrit
   Interrogation, Devoir et deux autres.
3. **La grille de vérification** : gardée dans la copie, ou cochée à l'écran sans être enregistrée ? Proposition : non
   enregistrée, comme la maquette.
4. **Le choix en pastilles** (« convergente / divergente ») : un affichage à part, ou les choix tels qu'ils sont aujourd'hui ?
   Proposition : les choix d'aujourd'hui ; la mise en ligne est une question de l'UDR.
5. **Un devoir « noté sur 20 »** : faut-il que ses points fassent 20 au total ? Proposition : non, la note se ramène sur 20.
6. **Un exercice sans question corrigée automatiquement** : refusé à la publication (Q13) ?
7. **L'image du corrigé** d'un travail sur le cahier (la construction des lentilles). Proposition : un corrigé en texte dans ce
   chantier ; l'image plus tard, car un nouveau téléversement demande d'abord sa menace écrite.
