# Journal — Correctifs mineurs de la revue de sécurité

## À trancher

- [ ] 2026-11-24 · securite-correctifs-mineurs · Durée du verrou au 5ᵉ code faux — appliqué : paliers existants (15 min, 1 h à 10, jusqu'à récupération à 20) ; autre : verrou jusqu'à récupération dès le 5ᵉ échec ; recommandé : paliers existants.

## Ce qui a dérapé

- 2026-11-24 : Ruby 3.4.13 absent de l'environnement cloud (ruby-build ne le connaît pas) : les tests Rails du point 1 n'ont pas pu tourner dans la session, seule la CI les joue.
