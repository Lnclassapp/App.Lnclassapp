# Memo — Accueil élève aux couleurs Wave et Djamo

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-15 |
| **Branche** | `Develop` (cadrage, docs seules) ; le code passera par une PR |
| **Programme** | — |

---

## Le problème

L'accueil de l'élève connecté (bandeau bleu, carte « Prochain exercice », grille des matières, « À faire ensuite », « Historique ») fonctionne, mais il ne ressemble pas encore à la nouvelle page d'accueil publique : celle-ci vient d'être redessinée sur le modèle de Wave et de Djamo (grande photo, feuille arrondie, bleu foncé, un seul écran au téléphone). En passant de l'une à l'autre, l'élève change d'univers visuel. Plusieurs maquettes de l'accueil élève existent (V2, V3, multi-écrans, états de la carte), chacune avec ses choix ; aucune n'a été tranchée face au design system.

## Pour qui

L'élève (Student), à chaque ouverture de l'application une fois connecté, le plus souvent sur un téléphone Android d'entrée de gamme, parfois avec une connexion faible.

## Pourquoi maintenant

La page d'accueil publique est dessinée et ses décisions sont prises : l'accueil élève est l'écran qui suit immédiatement. Le design system Lnclass existe désormais dans l'outil de design ; c'est le moment de dessiner l'accueil élève avec lui, avant de coder les deux écrans ensemble.

## Hors périmètre

- L'accueil de l'enseignant, de la direction et de l'équipe.
- Le contenu des pages ouvertes depuis l'accueil (exercice, matière, historique, paiement) : seul leur point d'entrée change.
- Le paiement lui-même : la tuile ouvre le parcours existant.
- La lecture hors ligne (chantier à part, promis par la pastille de la page d'accueil).
- Une barre d'onglets en bas de l'écran (refusée le 2026-10-14).
- Le parent : il ne voit rien de l'accueil de son enfant ; pas de changement de compte sur un téléphone partagé (2026-10-15).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| La grille mélange matières et actions (« Paiement », « Inviter »). On garde ce mélange ? | Oui : on garde « Paiement » et « Inviter » ; Lnclass se limite à 6 matières (porteur, 2026-10-14). | Grille de 8 tuiles : 6 matières + « Paiement » + « Inviter ». La 7e matière (EDHC ou Philosophie selon le cycle) doit trouver sa place ou disparaître de la grille. |
| Faut-il une barre d'onglets en bas, comme Wave et Djamo ? | Non, pas de barre native en bas (porteur, 2026-10-14). | La navigation reste celle du shell actuel (UDR-0006) ; l'accueil doit se suffire sans onglets. |
| Les maquettes ne montrent que le téléphone. Et la tablette, l'ordinateur ? | On adapte le design aux grands écrans (porteur, 2026-10-14). | Il faut dessiner tablette et ordinateur, pas seulement étirer le téléphone. |
| Le téléphone passe d'un enfant à l'autre, ou au parent : qui voit l'accueil ? | Un seul compte par téléphone : l'autre enfant se déconnecte puis se reconnecte (porteur, 2026-10-15). | Pas de sélecteur de comptes ni de vue parent. L'accueil doit dire clairement à qui il appartient (prénom, classe) pour qu'un frère ou une sœur s'en aperçoive, et la déconnexion doit rester trouvable depuis l'accueil. |

## Cas limites identifiés

- …

## Questions encore ouvertes

- …
