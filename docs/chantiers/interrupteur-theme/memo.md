# Memo — Interrupteur clair / sombre

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours — livré en PR, en attente du porteur |
| **Ouvert le** | 2026-10-03 |
| **Branche** | `feature/interrupteur-theme` |
| **Programme** | — |

## Le problème

Le mode sombre (chantier `mode-sombre`) suit le réglage du téléphone, sans choix possible dans l'application. Un élève qui veut l'interface sombre le soir sans changer tout son téléphone, ou l'inverse, ne peut rien faire. Le porteur a demandé le 2026-10-03 : « ajoute l'interrupteur clair/sombre dans le profil sur mobile et à côté de l'avatar sur la navbar sur les écrans plus larges ».

## Pour qui

Tout compte connecté : élève, enseignant, direction, équipe.

## Pourquoi maintenant

La décision du porteur, juste après la livraison du mode sombre.

## Hors périmètre

- **Un interrupteur sur les pages publiques** (accueil, connexion) : le visiteur n'a ni profil ni avatar ; ces pages suivent le choix déjà fait sur l'appareil, ou le téléphone.
- **Un troisième état « automatique »** : tant qu'aucun choix n'est fait, l'application suit le téléphone ; une fois choisi, l'interrupteur bascule entre clair et sombre.
- **Retenir le choix par compte** (sur tous les appareils d'un même élève) : il faudrait une colonne et un port ; le choix est retenu sur l'appareil.

## Ce que le grill a révélé

*Grill mené par l'agent ; l'emplacement est la demande du porteur.*

| Question | Réponse | Conséquence sur le chantier |
|---|---|---|
| Où retenir le choix ? | Sur l'appareil, dans un cookie : le serveur le lit et rend la page directement dans le bon thème, sans éclair. Le stockage du navigateur ne serait lu qu'après le chargement : la page clignoterait à chaque ouverture. | Un cookie `theme` (« light » ou « dark », un an) ; toute autre valeur est ignorée. |
| La page de protection des données dit « aucun cookie autre que celui qui vous garde connecté ». | Elle deviendrait fausse. | La phrase est complétée dans la même PR : un second cookie, qui retient le choix clair ou sombre sur l'appareil. À relire par les juristes avec le reste de la page. |
| Sans JavaScript ? | L'interrupteur ne pourrait rien faire. | Il est caché tant que son contrôleur n'a pas démarré, comme le bouton œil du PIN. |
| Un choix « clair » sur un téléphone en sombre ? | Le bloc sombre du téléphone ne doit plus s'appliquer. | La feuille ne l'applique qu'en l'absence d'un choix « clair » ; un choix « sombre » a son propre bloc, aux valeurs identiques, vérifiées par le test. |
| Deux interrupteurs sur la page de profil en grand écran ? | La carte du profil est cachée à partir de `lg` ; celui de l'en-tête l'est en dessous. Les deux se tiennent à jour l'un l'autre. | Un seul visible à chaque largeur. |

## Cas limites identifiés

- **Cookie forgé** : ignoré, la page suit le téléphone.
- **Le téléphone change de thème pendant la visite**, sans choix fait : l'interrupteur suit.
- **Page imprimée** : toujours claire, quel que soit le choix.

## Questions encore ouvertes

- Faut-il l'interrupteur sur les pages publiques aussi ?
