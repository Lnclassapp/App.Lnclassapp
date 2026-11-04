# Memo — Chaque feuille dans une case, lue avant de commencer

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-10-31 |
| **Branche** | `feature/sujet-avant-de-commencer` |
| **Programme** | — |

---

## Le problème

Sur la page d'une leçon, toutes les feuilles « Prépare interros » (une par notion, puis « Toute la leçon ») et « Prépare devoirs » (une par sujet) sont posées les unes sous les autres, déjà prêtes à remplir. L'élève ne voit pas d'un coup d'œil combien il y a de feuilles, et il n'a pas le geste d'un vrai devoir : lire tout le sujet d'abord, puis commencer.

## Pour qui

L'élève (Student), sur la page d'une leçon, au moment de réviser avant une interrogation ou un devoir.

## Pourquoi maintenant

Les feuilles de Thalès (4 sujets, 4 feuilles de notion) arrivent sur Develop et Staging : avec huit feuilles empilées, la page devient très longue. Le pilote veut la forme définitive avant de produire les sujets des autres leçons.

## Hors périmètre

- La saisie des réponses, la vérification, la correction et la note : inchangées.
- Un exercice à la fois (« Suivant ») : refusé par le pilote, la feuille se remplit en entier.
- Le contenu des feuilles (exercices, sujets, notions) : rien n'est écrit ni réécrit.
- Le parent et le personnel d'établissement : ils ne voient pas ces feuilles aujourd'hui, rien ne change pour eux.
- La partie « cours » de la leçon (notions, fiches, « Je m'entraîne ») : inchangée.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Après « Commencer », un exercice à la fois ou toute la feuille ? | Toute la feuille, comme aujourd'hui | La feuille à remplir ne change pas : le chantier ajoute les cases et la lecture avant de commencer, il ne refait pas la saisie des réponses. |
| Le sujet complet s'ouvre où ? | Sur sa propre page, retour vers la leçon, « Commencer » en bas | Une page par feuille : il lui faut une adresse (lien partageable, retour du navigateur) ; la page de la leçon ne garde que les cases. |
| Une feuille déjà commencée ? | La case montre le progrès (« 1 / 2 exercices réussis ») ; le sujet complet s'affiche toujours d'abord, le bouton devient « Continuer » | Le progrès de chaque feuille doit être connu dès la page de la leçon, sans ouvrir la feuille. |
| Et l'enseignant ? | Mêmes cases ; dans le sujet complet, ses boutons d'envoi à une classe ; pas de « Commencer » | Une seule mise en page pour tous ; l'envoi à une classe se fait depuis la page de la feuille, plus depuis la page de la leçon. |
| Les devoirs reçus dans « Ma classe » ? | Pareil : une case par devoir, le sujet complet, puis « Commencer » pour le remplir et le rendre | Deux pages hôtes (leçon et « Ma classe ») ; la page de la feuille doit savoir d'où elle vient pour y ramener l'élève, et porter « Rendre à l'enseignant ». |
| La case, à quoi ressemble-t-elle ? | Pas de maquette : proposition dans le style des feuilles de cahier, montrée en captures avant la fin | L'UDR décrit la case ; captures à 390 px et sur ordinateur avant la PR. |

## Cas limites identifiés

- Leçon sans aucun exercice : l'état vide actuel, sans case.
- Leçon sans sujet de devoir : la section « Prépare devoirs » reste absente, comme aujourd'hui.
- Feuille entièrement réussie : la case le montre (« 2 / 2 ») ; le bouton reste « Continuer », la feuille garde « Recommencer ».
- Visiteur non connecté : mêmes cases et même sujet, « Commencer » comme l'élève (ses réponses restent dans son navigateur, comme aujourd'hui).
- Équipe : cases et sujet, sans « Commencer » ni boutons d'envoi.
- Adresse d'une feuille qui n'existe plus (sujet retiré par un rechargement) : retour à la leçon avec un message, pas d'erreur.
- Devoir reçu déjà rendu : la case le dit ; le sujet s'ouvre, le bouton mène à la feuille avec son statut et « Voir ma correction ».
- Après « Vérifier ma réponse » ou « Voir ma correction », l'élève revient sur la feuille remplie, pas sur la page de la leçon.

## Questions encore ouvertes

- Aucune bloquante. La forme exacte de la case sera validée sur captures.
