# Memo — Mode sombre de l'application

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours — livré en PR, en attente du porteur |
| **Ouvert le** | 2026-10-03 |
| **Branche** | `feature/mode-sombre` |
| **Programme** | — |

## Le problème

Un téléphone réglé en thème sombre reçoit aujourd'hui des pages claires : fond papier, texte encre, blanc pleine page le soir. La grille de design du fondateur demande un mode sombre complet, porté par les tokens ; l'UDR-0005 l'avait exclu de la V1. Le porteur a tranché le 2026-10-03, en revue de la refonte de la page d'accueil : « ajoute le mode sombre ».

## Pour qui

Tous les acteurs, sur toutes les pages : élève, enseignant, direction, équipe, et le visiteur des pages publiques. D'abord l'élève, qui révise le soir sur un Android d'entrée de gamme.

## Pourquoi maintenant

La décision du porteur. Et l'application ne passe déjà que par les tokens (le design system le vérifie à chaque commit) : changer la valeur des tokens suffit, sans toucher aux écrans. Plus on attend, plus des écrans risquent d'écrire des couleurs qui ne marchent que dans un thème.

## Hors périmètre

- **Un interrupteur clair / sombre dans l'application** : le mode suit le réglage du téléphone. Un choix manuel demanderait une préférence enregistrée par compte ; il se décide à part.
- **Les e-mails** : ils ont leur propre gabarit, sans la feuille de l'application.
- **La barre d'outils de l'éditeur de texte riche** (pages d'édition de l'équipe et des enseignants) : elle vient de sa propre feuille, claire ; le contenu édité suit les tokens.
- **Les illustrations et les photos** : elles restent telles quelles.
- **La refonte de la page d'accueil** : chantier `refonte-homepage`, sa propre PR. Elle n'écrit que des tokens, elle suivra.

## Ce que le grill a révélé

*Grill mené par l'agent ; le porteur avait déjà tranché le principe.*

| Question | Réponse | Conséquence sur le chantier |
|---|---|---|
| Faut-il réécrire les écrans avec des variantes sombres ? | Non : chaque utilitaire lit la variable de son token. Redéfinir les variables pour le thème sombre change tout l'écran. | Un seul endroit change, la feuille de style. Aucune vue n'est touchée ; la règle « pas de `dark:` » reste. |
| Le texte blanc posé sur une couleur (bouton principal, bouton « Supprimer », pastilles de rôle) reste-t-il lisible si le blanc devient la surface sombre ? | Seulement si la couleur de fond devient claire. Les fonds qui portent un texte blanc (encre, équipe, direction, erreur) deviennent clairs ; ceux qui portent un texte encre (marque, enseignant, or) deviennent profonds. | Une règle d'inversion écrite dans l'UDR, et un test qui calcule le contraste de chaque paire employée par les composants, dans les deux modes. |
| Le voile derrière une modale est fait d'encre à 50 % : que devient-il ? | Un voile clair, illisible. | Le voile reste noir en sombre, par une règle dédiée. |
| Que devient une page imprimée (codes de secours) si le téléphone est en sombre ? | Texte clair sur papier blanc : invisible. | Le mode sombre ne s'applique qu'à l'écran ; un test système imprime la page et vérifie le fond clair. |
| L'écran blanc avant le chargement de la feuille ? | Un éclair blanc à chaque ouverture, le soir. | Le gabarit déclare les deux thèmes au navigateur, qui peint le fond sombre avant la feuille. |

## Cas limites identifiés

- **Imprimer** une page en thème sombre : la page imprimée est claire.
- **Navigateur ancien** (sous le plancher de l'ADR-0051) : les couleurs translucides retombent sur leur valeur claire ; le bandeau « navigateur ancien » reste clair. Acceptable : ces navigateurs ne sont pas pris en charge.
- **Contour de focus** : la marque en sombre garde au moins 3:1 sur les surfaces. En clair, il est à 2,7 sur le papier : constat préexistant, hors de ce chantier.

## Questions encore ouvertes

- Faut-il un interrupteur clair / sombre dans le profil ? (Hors périmètre ; la grille de design prévoit `[data-theme]`.)
- La palette sombre proposée (voir l'UDR-0065) convient-elle au porteur ? Elle se règle en une ligne par token.
