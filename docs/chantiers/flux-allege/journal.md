# Journal — Un flux allégé

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-06 | Point 6 dans un chantier séparé (`ci-durees-enregistrees`), session Sonnet | Choix du porteur | non |
| 2026-11-06 | `ci-quiet` enregistre lui-même la durée d'un test système neuf | Choix du porteur | non (chantier `ci-durees-enregistrees`) |
| 2026-11-06 | Audit des dépendances le mercredi et le vendredi à 10 h (Abidjan) | Choix du porteur | non |
| 2026-11-06 | La mesure compte les commits qui *touchent* l'index des chantiers, et ceux qui ne touchent que lui | Le chiffre de 51 du rapport n'avait pas de définition reproductible | non |

## À trancher

- [ ] 2026-11-06 · flux-allege · « Une PR par chantier » devient « une PR par chantier et par jour » — appliqué : par jour, la suite repart de `Develop` sur `<type>/<slug>-2` ; autres : garder une PR par chantier et ne viser que des chantiers d'une journée ; recommandé : par jour
- [ ] 2026-11-06 · flux-allege · L'audit du mercredi et du vendredi ouvre-t-il une PR de mise à jour ? — appliqué : oui, PR prête que le porteur fusionne ; autres : rapport seul dans la boîte de 12 h ; recommandé : PR
- [ ] 2026-11-06 · flux-allege · Seuil d'une retouche — appliqué : ≤ 3 fichiers hors tests ; autres : 1 fichier ; 5 fichiers ; recommandé : 3

## Retouches

- …

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

- La médiane des commits par PR est déjà de 3 ; la moyenne (7,0 en octobre) est tirée par quelques grosses PR. Les deux sont suivies.

## Clôture

| | |
|---|---|
| **Livré le** | 2026-11-06 |
| **PR** | |
| **ADR produits** | — |
| **UDR produits** | — |
