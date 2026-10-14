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
- **Une nouvelle charte** : couleurs et polices restent celles du design system. Seul l'usage de `brand-strong` pour les boutons pleins est nouveau.

## Ce que le grill a révélé

> Rempli au fil des questions adverses.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Le bleu de marque `#00a0ff` porte du texte blanc à 2,8:1 (sous le minimum de 3:1 pour un gros texte). Quelle variante de boutons ? | Bleu foncé (`brand-strong`, 5,3:1) pour « Je suis élève », fond bleu pâle pour « Enseignant(e) » (porteur, 2026-10-14). | Le bouton plein de la page est `brand-strong`. Il faut aussi vérifier le contraste de « chap chap » et de la pastille, qui utilisent le même bleu. |
| La pastille promet « même sans internet », alors que l'UDR-0064 §2.6 interdit de promettre ce que l'application ne livre pas encore. | On garde la promesse ; la lecture hors ligne sera ajoutée après les maquettes des écrans (porteur, 2026-10-14). | Cette règle de l'UDR-0064 est levée pour la pastille, et l'écart doit être écrit dans la nouvelle UDR. Un chantier « lecture hors ligne » est à ouvrir. |
| D'où vient la photo ? | Elle a été générée, il n'y a donc pas de droit à l'image à obtenir (porteur, 2026-10-14). | Elle doit tenir dans le budget de poids (WebP ≤ 100 Ko, UDR-0064 §3) avec un cadrage portrait pour le téléphone et un cadrage paysage pour l'ordinateur. |
| Où se connecte un élève ou un enseignant qui revient ? La maquette n'a ni en-tête ni « Se connecter ». | Dans la modale de rôle, comme aujourd'hui : « Tu es élève ? » propose « Se connecter » puis un second bouton, renommé de « Rejoindre ma classe » en **« Créer mon compte »** (porteur, 2026-10-14). | La page n'a plus d'en-tête ni de bouton « Se connecter » propre : la connexion passe uniquement par les deux modales. Le libellé du bouton d'inscription de la modale élève change, et son indice (« Choisis ta classe, ou ouvre le lien… ») est à relire. Les tests qui cherchent « Se connecter » dans l'en-tête de `/` changent. |
| Quelle mise en page sur ordinateur ? | Texte à gauche, photo à droite (porteur, 2026-10-14). | Il y a deux familles de mise en page : feuille sur la photo au téléphone, deux colonnes à partir de 1 024 px. |

## Cas limites identifiés

- …

## Questions encore ouvertes

- …
