# Plan — demarrage-develop

Un lot, un levier. Le chantier ne se clôt pas sans mesure après, sur les journaux réels (au moins 3 déploiements,
médiane).

## Lot A — semis en tâche de fond après `/up`, un seul `db:prepare`

- `deploy/hostinger/test.yaml` : l'entrypoint de l'application ne joue plus `db:prepare db:seed` ; il écrit le repère
  `[démarrage]`, lance en arrière-plan une boucle qui attend `/up` puis joue `db:seed`, et passe la main à
  `bin/docker-entrypoint` (qui fait le seul `db:prepare`, puis Puma).
- `test/config/hostinger_demarrage_test.rb` : ordre réel (un `db:prepare`, serveur, `/up`, semis) en rejouant le
  script avec des faux `rails`, `thrust` et `curl` ; production inchangée.
- `script/mesure/demarrage` : le banc, lu dans les journaux Hostinger.

**Done quand** : `/up` répond 200 moins de 2 min après le repère `[démarrage]`, sur Develop et Staging, et la ligne
`[démarrage] semis terminé` suit (leçons et jeu standard à jour).

## Portes de sortie

- Mesure avant chiffrée : oui (16 min 36 s ; 42 s sans rechargement).
- Tests fonctionnels verts avant et après.
- Mesure après : au déploiement qui suit la fusion, par `script/mesure/demarrage` ; sans elle, le chantier reste ouvert.
