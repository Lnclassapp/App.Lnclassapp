# Memo — Avis de sécurité loofah, nokogiri, rails-html-sanitizer

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré |
| **Ouvert le** | 2026-11-02 |
| **Branche** | `bugfix/audit-gems-loofah` |

## Le problème

Le 2026-11-02, la base d'avis de `bundler-audit` publie des failles dans loofah 2.25.2 (contournement des références SVG, XSS par mutation dans les nettoyeurs HTML5), nokogiri 1.19.4 et rails-html-sanitizer 1.7.1. L'étape « Security: Gem audit » de `bin/ci-quiet` est rouge pour toute PR (constaté sur le Lot I de standard-de-test, #453), sans lien avec leur diff.

## Reproduction

`bin/bundler-audit update && bin/bundler-audit` sur Develop : 3 gemmes signalées.

## Correctif

`bundle update --conservative loofah rails-html-sanitizer` : loofah 2.25.3, nokogiri 1.19.6, rails-html-sanitizer 1.7.2 (versions correctives seulement, aucune autre gemme ne bouge).

## Hors périmètre

Aucun code applicatif.
