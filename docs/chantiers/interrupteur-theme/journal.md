# Journal — Interrupteur clair / sombre

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-03 | Un cookie plutôt que le stockage du navigateur | Le serveur rend la page dans le bon thème dès la première image ; une préférence lue par JavaScript ferait clignoter chaque ouverture | Non — UDR-0065 |
| 2026-10-03 | Deux états, sans « automatique » | Sans choix, l'application suit déjà le téléphone ; l'interrupteur demandé est clair / sombre | Non |
| 2026-10-03 | La phrase sur les cookies de la page de confidentialité est complétée | Elle disait « aucun cookie autre que celui qui vous garde connecté » | Non — à relire par les juristes |

## Ce qui a dérapé

- **Les tests ont été écrits juste après le code.** Leur rouge a été établi en retirant les changements de `app/` et `config/` : 8 échecs sur 13, puis vert.
- **Deux premières captures ratées** : l'une sans la carte à l'écran, l'autre prise pendant la transition des couleurs des boutons. Refaites après la fin des animations.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Interrupteur sur les pages publiques | Hors périmètre : pas de profil ni d'avatar | à décider par le porteur |
| Choix retenu par compte, sur tous les appareils | Demande une colonne et un port | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-03, en PR brouillon vers `Develop` |
| **PR** | [#155](https://github.com/Lnclassapp/App.Lnclassapp/pull/155) |
| **ADR produits** | aucun |
| **UDR produits** | amendement de l'UDR-0065 |
