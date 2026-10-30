# Memo — Les exercices en cartes

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-10-30 |
| **Branche** | `feature/exercices-en-cartes` |
| **Programme** | — |

---

## Le problème

Demande du porteur : « rendre les exercices en card avec un design UI/UX amélioré ».

Aujourd'hui, un exercice s'affiche de quatre façons différentes selon l'écran : une ligne de liste dans « Ma classe » de l'élève (assignés, traités), une ligne dans un cadre bordé sur la page d'une leçon (« Prépare interros »), une ligne de suivi sur la page de classe de l'enseignant. Aucune ne dit tout ce qu'il faut pour décider : la matière n'apparaît pas sur la page de la leçon, le type (fixation, évaluation) n'apparaît pas dans « Ma classe », l'action (« commencer », « reprendre », « voir ma copie ») n'est écrite nulle part — seule une flèche la suggère.

Dans l'écran d'un exercice, les questions se suivent sur une seule feuille, séparées par un blanc : au téléphone, le numéro de la question se perd au-dessus de l'énoncé, et rien ne dit le format attendu (relier, remettre dans l'ordre, rédiger) avant de lire les propositions.

## Pour qui

- **Élève** : dans « Ma classe » (exercices assignés et traités), sur la page d'une leçon, et dans l'écran d'un exercice.
- **Enseignant** : sur la page d'une leçon (avec ses bascules d'assignation) et sur la page de sa classe (« Exercices assignés »).
- **Équipe** : sur la page d'une leçon, avec le statut éditorial.

## Pourquoi maintenant

Le porteur le demande, et une session parallèle raccourcit le parcours matière → leçon → exercice : la carte est la pièce qu'elle branchera dans ses écrans. Sans un partial unique, chaque écran réinvente sa ligne.

## Hors périmètre

- Les écrans de navigation (liste des matières, liste et page des leçons) : session parallèle. On n'y touche que pour brancher le partial de carte.
- La carte « Prochain exercice » de l'accueil élève (UDR-0132) : elle a ses 7 états et sa place, elle reste telle quelle.
- L'écran de passage d'un exercice (`exercise_sessions`, la saisie des réponses) et l'écran du résultat : ils gardent leur rendu.
- Le corrigé enseignant de la leçon (feuille imprimable de l'équipe) et le fil « Historique » de l'accueil.
- Parent, SchoolStaff (direction) : ils ne voient pas de liste d'exercices aujourd'hui ; rien ne change pour eux.
- Aucune nouvelle table, aucun nouveau port, aucune nouvelle route.

## Ce que le grill a révélé

> Grill joué en session d'agent à partir de la demande écrite du porteur et de la charte (`lnclass-design-system`), sans réponse orale ; les réponses tranchées sont reprises dans l'UDR et soumises au porteur dans la PR.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| « Type de question » : le format de chaque question (QCM, relier) ou le type de l'exercice (fixation, évaluation) ? | Sur la carte d'un exercice, le type de l'exercice : un exercice mêle plusieurs formats, en lister 4 sur une carte serait du bruit. Le format de chaque question s'affiche sur la carte de la question, dans l'écran de l'exercice. | Deux libellés distincts : type d'exercice (carte d'exercice), format de question (carte de question). Les lignes de « Ma classe » et du suivi enseignant n'ont pas le type : la lecture l'ajoute. |
| La carte dit « À faire » dans la section « Exercices assignés » ? | Non : la charte (§11) interdit l'étiquette redondante. L'état visible est l'échéance (neutre, ou ambre si < 24 h ou en retard) ; « à faire » se lit dans le verbe de l'action, « Commencer ». | L'état de la carte se lit en deux endroits sans répétition : la pastille d'état (échéance, note, « À revoir », statut) et le verbe de l'action. |
| Répéter la matière sur la page d'une leçon, dont toutes les cartes ont la même ? | Non : la couleur (pastille illustrée) reste, le nom disparaît (« dire chaque chose une seule fois »). | Le partial accepte une matière sans nom : la pastille seule. |
| Une note sous 10/20 en rouge ? | Jamais (charte §5) : vert dès 14/20, encre en dessous ; l'action devient « Refaire » sur la page de la leçon. | Le vert suit `Grading::MASTERY_THRESHOLD`, comme aujourd'hui. |
| La carte entière cliquable, et l'enseignant qui a des bascules d'assignation dedans ? | Le titre porte un lien étiré sur toute la carte ; les bascules sont posées au-dessus (`relative z-10`) et restent cliquables. | Le partial accepte un bloc (contenu sous la carte) ; un seul lien par carte. |
| L'élève qui n'a jamais ouvert un exercice non assigné ? | Pas de pastille d'état, l'action « Commencer » suffit. | État `nil` rendu sans pastille. |
| L'enseignant qui suit une assignation sans droit de suivi (`counts` nil) ? | Carte sans lien ni action, comme aujourd'hui sans lien. | Le partial accepte `href: nil` : article non cliquable, pas d'action. |
| L'élève voit-il « 3 propositions correctes » sur la carte de question ? | Non : ce serait lui donner la moitié de la réponse. L'élève lit « Plusieurs réponses », comme aujourd'hui sous la question. | Libellés de format propres à l'écran de l'exercice, pas ceux de l'équipe. |

## Cas limites identifiés

- Titre long (2 lignes au téléphone) : tronqué à 2 lignes, nom complet dans le lien.
- Matière inconnue ou sans illustration : pastille neutre (`subject_illustration` a déjà un repli).
- Zéro exercice : les états vides existants des sections ne changent pas.
- Exercice sans question : l'écran de l'exercice garde son état vide.
- Une question avec image : l'image reste dans sa carte, en largeur pleine.
- Mode sombre : uniquement des tokens du bloc `@theme`.

## Questions encore ouvertes

- Le porteur valide-t-il la lecture « type = fixation / évaluation » ? (posée dans la PR, captures à l'appui)
