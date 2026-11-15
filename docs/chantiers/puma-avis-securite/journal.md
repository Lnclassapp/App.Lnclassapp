# Journal — Avis de sécurité Puma

## À trancher

- [ ] 2026-11-15 · puma-avis-securite · puma 8.0.3 (patch) ou 8.1.1 (mineure, `--conservative` seul) — appliqué : 8.0.3 (publiée le 13/11, ferme les 5 avis, plus petit pas) ; autres : 8.1.1 (durcissements HTTP, nouveautés, publiée le jour même) ; recommandé : 8.0.3 maintenant, 8.1.x dans un chantier à part après quelques jours de recul.

## Ce qui a dérapé

- Le conteneur n'avait pas Ruby 3.4.9 (3.3.6 seulement) : le serveur répondait 500 (`it` inconnu en 3.3, hors sujet Puma). Installé avec `rbenv install 3.4.9`.
- Le rôle PostgreSQL `dev-rails` n'existait pas, contrairement à la note de lancement : créé à la main (conteneur jetable).
- `bundle update` avec bundler 4.0.18 ajoute une ligne `bundler` aux sommes de contrôle et change `BUNDLED WITH` : retirés, le lock ne porte que puma. Bundler 4.0.10 (celui du lock) installé ensuite.
