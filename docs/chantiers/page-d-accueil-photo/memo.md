# Memo — Page d'accueil publique en photo plein écran

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-14 |
| **Branche** | `Develop` (cadrage, docs seules) ; le code passera par une PR |
| **Programme** | — |

---

## Le problème

La page d'accueil publique actuelle (UDR-0064) tient la promesse « un écran, une décision » dans son premier écran, mais elle continue ensuite sur cinq sections (matières, trois étapes, quatre promesses, enseignants, pied). Au téléphone, le visiteur voit d'abord un bandeau bleu avec du texte. La photo n'arrive qu'après, et il doit faire défiler une page de présentation alors qu'il n'a qu'une décision à prendre.

Le porteur a dessiné une autre porte d'entrée (2026-10-14), inspirée des applications que ses élèves utilisent déjà (Wave, Djamo) :
- une photo d'élèves ivoiriens en plein écran ;
- une pastille « De la 6ème à la Terminale, même sans internet » ;
- une feuille blanche arrondie qui monte du bas et porte la promesse « Forcément, tu comprends chap chap », soulignée d'une vague jaune ;
- les deux entrées, élève et enseignant ;
- un lien vers l'espace établissement ;
- les deux applications mobiles.

Sur ordinateur, le texte passe à gauche et la photo à droite.

## Pour qui

- **Le visiteur non connecté**, le plus souvent un élève sur un Android d'entrée de gamme, en 3G : il arrive sur `/`, doit comprendre en un regard ce qu'est Lnclass et choisir son entrée.
- **L'enseignant** à qui un collègue a parlé de Lnclass : même porte, entrée « Enseignant(e) ».
- **La direction d'un établissement** (SchoolStaff) : nouvelle entrée « Espace établissement ».

## Pourquoi maintenant

La page d'accueil est la première pièce de la refonte visuelle que le porteur a lancée le 2026-10-14 à partir de ses maquettes. Elle est petite, ne touche aucune règle métier et fixe le langage visuel des écrans suivants : photo locale, feuille qui monte du bas, boutons en pilule bleu foncé, vague jaune.

## Hors périmètre

- **La lecture hors ligne des fiches.** La pastille la promet, mais elle sera livrée par un chantier à part, après les maquettes des écrans (porteur, 2026-10-14).
- **L'accueil élève**, qui fera l'objet du chantier suivant.
- **Les modales de rôle** : elles gardent leurs identifiants et leur mécanique (UDR-0012 §2). Seul le libellé du second bouton de la modale élève change (voir le grill).
- **Tarifs, abonnement, annales BEPC/BAC, défi du jour, témoignages, chiffres d'audience** : retirés de la maquette tant que la fonctionnalité n'existe pas (porteur, 2026-10-14).
- **Une nouvelle charte** : couleurs et polices restent celles du design system. Seul l'usage de `brand-strong` pour les boutons pleins est nouveau.

## Ce que le grill a révélé

> Rempli au fil des questions adverses.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Le bleu de marque `#00a0ff` porte du texte blanc à 2,8:1 (sous le minimum de 3:1 pour un gros texte). Quelle variante de boutons ? | Bleu foncé (`brand-strong`, 5,3:1) pour « Je suis élève », fond bleu pâle pour « Enseignant(e) » (porteur, 2026-10-14). | Le bouton plein de la page est `brand-strong`. Il faut aussi vérifier le contraste de « chap chap » et de la pastille, qui utilisent le même bleu. |
| La pastille promet « même sans internet », alors que l'UDR-0064 §2.6 interdit de promettre ce que l'application ne livre pas encore. | On garde la promesse ; la lecture hors ligne sera ajoutée après les maquettes des écrans (porteur, 2026-10-14). | Cette règle de l'UDR-0064 est levée pour la pastille, et l'écart doit être écrit dans la nouvelle UDR. Un chantier « lecture hors ligne » est à ouvrir. |
| D'où vient la photo ? | Elle a été générée, il n'y a donc pas de droit à l'image à obtenir (porteur, 2026-10-14). | Elle doit tenir dans le budget de poids (WebP ≤ 100 Ko, UDR-0064 §3) avec un cadrage portrait pour le téléphone et un cadrage paysage pour l'ordinateur. |
| Où se connecte un élève ou un enseignant qui revient ? La maquette n'a ni en-tête ni « Se connecter ». | Dans la modale de rôle, comme aujourd'hui : « Tu es élève ? » propose « Se connecter » puis un second bouton, renommé de « Rejoindre ma classe » en **« Créer mon compte »** (porteur, 2026-10-14). | La page n'a plus d'en-tête ni de bouton « Se connecter » propre : la connexion passe uniquement par les deux modales. Le libellé du bouton d'inscription de la modale élève change, et son indice (« Choisis ta classe, ou ouvre le lien… ») est à relire. Les tests qui cherchent « Se connecter » dans l'en-tête de `/` changent. |
| Quelle mise en page sur ordinateur ? La maquette multi-écrans met la photo à gauche. | Texte à gauche, photo à droite, confirmé contre la maquette ; toutes les maquettes seront reprises (porteur, 2026-10-14). | Il y a deux familles de mise en page : feuille sur la photo au téléphone, deux colonnes à partir de 1 024 px avec la feuille à gauche dont le bord arrondi mord sur la photo. La maquette de référence de l'UDR sera la version reprise, pas l'artefact actuel. |
| Sur tablette et ordinateur, la page reprend-elle la maquette longue du porteur (en-tête, haut de page, matières, défi du jour, 3 étapes, annales, témoignages, appel à s'abonner, pied), qui promet des tarifs, des annales, un défi et des chiffres inventés, dans d'autres couleurs et polices ? | On adapte sa mise en page et son ordre ; les tarifs et les promesses sans fonctionnalité derrière sont retirés. La maquette était trop enthousiaste (porteur, 2026-10-14). | Deux familles : au téléphone, la feuille sur la photo ; à partir de la tablette, la page longue. On ne garde que les sections vraies aujourd'hui, en tokens du design system (couleurs, DM Sans, Bricolage Grotesque). La règle de l'UDR-0064 « ne promettre que ce qui est livré » reste, sauf pour la pastille « même sans internet ». |
| Au téléphone, la page continue-t-elle sous la feuille (sections, pied de page) ? | Non : au téléphone la page reste figée sur un seul écran ; la page longue est réservée à la tablette et à l'ordinateur (porteur, 2026-10-14). | Au téléphone : un écran à hauteur de fenêtre, sans défilement ni pied de page. Les liens légaux du pied (confidentialité, conditions, UDR-0063) n'y apparaissent donc plus : il faut leur trouver une place (question ouverte). Petits écrans (320 × 568) : la feuille doit tenir sans défilement. |
| Au téléphone, quel titre et quel bleu, face à la maquette de bienvenue (« Forcément, tu comprends », bleu `#00a0ff`) ? | « Tu comprends chap chap », en bleu foncé ; boutons en pilule côte à côte, « Enseignant(e) » à contour bleu (porteur, 2026-10-15). | La maquette de bienvenue sert de référence de mise en page au téléphone, mais pas pour le titre ni pour la couleur. Le bouton secondaire passe du fond bleu pâle au contour `brand-strong`. |
| Quel en-tête sur tablette et ordinateur ? | Aucun : ni logo, ni barre de navigation, ni « Se connecter » (porteur, 2026-10-15). | La page commence directement par le haut de page, et la connexion passe seulement par les modales de rôle. Le lien « Se connecter » sort aussi du pied de page. |
| Quel haut de page sur ordinateur ? | Celui de la page d'accueil actuelle (pastille « Plateforme éducative », « Avec Lnclass, tu comprends chap chap ! », phrase, « Je suis élève » / « Je suis enseignant », six matières en pastilles), avec la photo à droite à la place des quatre cartes (porteur, 2026-10-15). | Boutons à coins de 12 px (et non en pilule) sur grand écran. Les couleurs restent celles du design system (`brand-strong`, `brand-soft`, `paper`). Sur tablette, la photo passe au-dessus et le texte se centre. « Espace établissement » et les liens des applications ne sont plus dans le haut de page sur grand écran. |
| Que garde la page longue sur tablette et ordinateur ? | Seulement le haut de page : les sections (matières, étapes, fonctionnalités, enseignants, établissements) et le pied de page sont retirés (porteur, 2026-10-15). | Tablette et ordinateur tiennent aussi sur un seul écran : sur ordinateur, texte à gauche et photo à droite ; sur tablette, la photo en haut et le texte dessous. Les liens légaux n'ont plus de place sur aucun écran, et « Espace établissement » n'a plus de section vers laquelle pointer. La réponse « page longue » plus haut est remplacée. |
| Où mène « Espace établissement » ? | Il ouvre une fenêtre, comme « Tu es élève ? » (porteur, 2026-10-15). | Troisième modale de rôle, sur tous les écrans : titre « Espace établissement », phrase pour la direction (vouvoiement), « Se connecter », « Créer un compte d'établissement » (porteur ; l'application dit encore « Créer mon compte de direction », à aligner), rappel du code de l'établissement. Le lien sous les boutons garde son allure de lien. |

## Cas limites identifiés

- La photo générée porte le filigrane de l'outil (une étoile en bas à droite), visible sur tablette et ordinateur : le recadrage de production doit l'exclure.

## Questions encore ouvertes

- **Liens légaux** : plus aucun écran n'a de pied de page ; où placer confidentialité, conditions et CGV ?
- **Couleur des boutons.** La maquette multi-écrans garde le bleu `#00a0ff` avec un texte blanc (contraste 2,8:1), alors que le porteur a choisi le bleu foncé `brand-strong`. On retient sa réponse écrite tant qu'il ne dit pas le contraire.
- **Photo.** La maquette la décrit comme « à remplacer en production par une vraie photo », alors que le porteur garde l'image générée. On retient l'image générée.
- **Liens des applications** « Lnclass Élève » et « Lnclass Enseignant » : leurs adresses de téléchargement, et que faire sur iPhone.
