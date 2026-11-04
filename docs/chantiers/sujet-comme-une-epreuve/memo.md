# Memo — Le sujet se lit comme une vraie épreuve

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-11-04 |
| **Branche** | `feature/sujet-comme-une-epreuve` |
| **Programme** | — |

---

## Le problème

Quand l'élève ouvre une case « Prépare interros » ou « Prépare devoirs », il lit le sujet dans la mise en page du cahier à remplir : cases, boutons de choix, champs vides grisés. Ce n'est pas la feuille qu'il recevra le jour de l'examen. Le pilote a fourni le modèle attendu (BEPC blanc, 2 pages) : un cartouche (examen, matière, classe, durée), un titre « ÉPREUVE DE … », une consigne générale, puis des exercices numérotés avec leurs points, des affirmations en tableau (N°, affirmation, A, B, C ou V/F), une figure à côté de l'énoncé, des questions numérotées « 1. a. b. », et une mention en pied de page.

## Pour qui

L'élève, au moment où il ouvre une feuille, avant de cliquer sur « Commencer ». Il se prépare à un vrai examen : il doit reconnaître la forme de l'épreuve.

## Pourquoi maintenant

La page de lecture vient d'être livrée (sujet-avant-de-commencer, UDR-0151). Le pilote l'a vue et demande qu'elle ressemble à une vraie épreuve avant que les élèves ne la découvrent.

## Hors périmètre

Ce qu'on ne fera **pas** dans ce chantier. Cette section est la plus utile du memo : c'est elle qui empêche le chantier de gonfler.

- La feuille à remplir (« Commencer ») : inchangée, encadrés compris.
- Un titre d'examen par classe (« BEPC BLANC », « BAC BLANC ») et une durée : écartés par le pilote.
- L'indice et la correction : jamais sur la page de lecture (inchangé).
- Le parent et le personnel de l'établissement : ils n'ont pas de page de feuille aujourd'hui, rien ne change pour eux.
- Le contenu des sujets (énoncés, points, figures) : on met en page ce qui existe.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quel titre en haut de la page (le modèle dit « BEPC BLANC ») ? | Le nom de la feuille : « PRÉPARE DEVOIRS N°1 », « PRÉPARE INTERROS N°2 » | Pas de titre d'examen par classe ; le cartouche reprend le nom de la feuille. Rien à ajouter aux données |
| Durée et points (le modèle dit « Durée : 2 heures », « (4 points) ») ? | Points oui, durée non | Chaque exercice affiche la somme des points de ses questions ; pas de durée dans le cartouche, aucune donnée nouvelle |
| Le tableau des QCM sur téléphone (390 px) ? | « Tableau, mais il faut tout faire pour que ça rentre » | Tableau aussi sur téléphone, ajusté à l'écran : colonnes serrées, texte qui passe à la ligne, taille réduite ; le défilement de côté n'est qu'un dernier recours, pour une formule plus large que l'écran, dans sa cellule, jamais la page |
| Un exercice qui mélange vrai ou faux, QCM et calculs ? | Groupé par type | Les vrai ou faux qui se suivent forment un tableau V/F, les QCM qui se suivent un tableau A/B/C(/D), le reste une liste ; les lettres a, b, c… restent celles de la feuille à remplir (« Question e » partout) ; un QCM à 2 ou 3 réponses garde « Coche 2 réponses. » dans sa ligne |
| Les pages de lecture de l'enseignant et de « Ma classe » aussi ? | Oui, partout | Une seule mise en page d'épreuve pour toutes les pages de lecture ; l'enseignant garde ses bascules d'envoi sous chaque exercice |
| « À retenir » et « Notions mobilisées » sur la page de lecture ? | Les retirer | La page de lecture n'a aucune aide ; les deux encadrés restent sur la feuille à remplir |

## Cas limites identifiés

- Un exercice sans question : son énoncé seul, « (0 point) » n'est pas affiché, pas de tableau.
- Des QCM consécutifs qui n'ont pas le même nombre de propositions : le tableau prend le plus grand nombre de colonnes, les cases en trop restent vides.
- Un QCM à 2 ou 3 bonnes réponses dans un tableau : « Coche 2 réponses. » dans sa ligne.
- Des points en demi-point : « (2,5 points) » ; un seul point : « (1 point) ».
- Une formule plus large que sa cellule à 390 px : elle défile dans sa cellule, jamais la page.
- Un élève rattaché à plusieurs classes : inchangé, « Ma classe » ne lit que sa classe principale.
- Un enseignant de deux établissements : inchangé, ses bascules restent limitées à la classe de la page.
- Un brouillon lu par l'équipe : la mention « Brouillon » reste visible à côté de son exercice.

## Questions encore ouvertes

- Aucune : la phrase de consigne et la mention de pied de page sont proposées dans l'UDR, à valider sur les captures.
