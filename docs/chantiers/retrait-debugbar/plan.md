# Plan d'exécution — Retrait de debugbar

> Un seul lot, mais il touche des fichiers partagés (`Gemfile`, `Gemfile.lock`, layout, environnements) : le plan est gardé pour porter les portes de sortie ([`bugfix.md`](../../workflows/bugfix.md#3-planifier--souvent-un-seul-lot)).

## Lot 0 — Retrait

- **Couche**       : infrastructure (dépendances, configuration) + ui (layout)
- **Fichiers**     : `Gemfile` · `Gemfile.lock` (régénéré par `bundle install`)
                     `config/initializers/debugbar.rb` *(supprimé)*
                     `config/environments/development.rb` · `config/environments/test.rb`
                     `app/views/layouts/application.html.erb`
                     `test/integration/development_configuration_test.rb`
                     `docs/guide/stack.md` · `docs/chantiers/README.md`
- **Dépend de**    : —
- **Test associé** : `test/integration/development_configuration_test.rb` — le développement démarre sans `Debugbar` ni ses middlewares, Action Cable y garde sa vérification d'origine ; `Gemfile.lock` ne verrouille plus la gem et le test garde la même vérification
- **Done quand**   : en développement, après l'envoi d'une photo de profil, `/up`, `/` et `/students` répondent `200`

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code (`/up`, `/`, `/students` → `500` après l'envoi)
- [x] Rapport root cause rendu : `Debugbar::TrackCurrentRequest` → `RequestBuffer` → `ActionCable.server.broadcast` ; trou de test : la gem n'est active qu'en développement ([memo, Cause](memo.md#cause))
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (`"debugbar" => true`, middlewares `Debugbar::TrackCurrentRequest` et `Debugbar::QuietRoutes`, `cable_any_origin => true` ; `Gemfile.lock` verrouille `debugbar`)
- [x] Correctif appliqué dans la couche de la **cause** : la dépendance et sa configuration, pas le layout seul
- [x] Test au vert · suite complète au vert, couverture 100 %
- [x] Cas symétrique vérifié : l'envoi de la photo répond `200` et la photo est servie (`GET /accounts/:id/photo` → `200`)
- [x] Données déjà corrompues : aucune, le défaut vivait dans la mémoire du processus
- [x] Étapes de reproduction rejouées dans l'application après correctif (voir `journal.md`)
- [x] Commits avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés
