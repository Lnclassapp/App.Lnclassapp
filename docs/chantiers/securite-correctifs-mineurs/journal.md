# Journal — Correctifs mineurs de la revue de sécurité

## À trancher

- [x] 2026-11-24 · securite-correctifs-mineurs · Plafond commun à 5 faux codes par minute et par adresse (10 avant sur /student) : une classe derrière un wifi peut être bloquée une minute par 5 fautes de frappe — appliqué : 5 (décision du porteur) ; autre : 10 ; recommandé : 5, à confirmer. Porteur, 2026-11-24 : garde 5.

## Décisions

- 2026-11-24, porteur (relayée par l'orchestrateur) : au 5ᵉ code secret faux par compte, `/login` et `/student` confondus, le compte est bloqué jusqu'à récupération (`Entities::Identity::Lockout::TIERS = { 5 => :until_recovery }`). Remplace les paliers 15 min / 1 h / récupération. Touche aussi les verrous du second facteur, du changement de code et de contact, qui partagent `Lockout`.

## Constats

- 2026-11-24 : pare-feu du VPS lu par l'API Hostinger (lecture seule, groupe `lnclass-production`, synchronisé) : 80 et 443 en TCP ne sont acceptés que depuis 15 plages IPv4 de Cloudflare (173.245.48.0/20, 103.21.244.0/22, 103.22.200.0/22, 103.31.4.0/22, 141.101.64.0/18, 108.162.192.0/18, 190.93.240.0/20, 188.114.96.0/20, 197.234.240.0/22, 198.41.128.0/17, 162.158.0.0/15, 104.16.0.0/13, 104.24.0.0/14, 172.64.0.0/13, 131.0.72.0/22) ; 22 reste ouvert à tous. Le journal d'hebergement-cloudflare est exact : l'origine n'est pas joignable hors Cloudflare. Rien modifié.

## Ce qui a dérapé

- 2026-11-24 : Ruby 3.4.13 absent de l'environnement cloud (ruby-build ne le connaît pas) : les tests Rails du point 1 n'ont pas pu tourner dans la session, seule la CI les joue.
