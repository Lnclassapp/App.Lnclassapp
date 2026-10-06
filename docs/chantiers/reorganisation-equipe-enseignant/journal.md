# Journal — Réorganisation des espaces Équipe et Enseignant

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-03 | Le chantier vit directement sur `Develop`, sans branche de chantier ni PR | Décision du porteur, contraire à `conventions.md` §3 ; les lots restent sur des branches locales et rien n'est poussé avant les portes vertes | Non |
| 2026-10-03 | « Versement » et le lien de parrainage vers d'autres établissements sont retirés | Grill G1 et G2 | Non |
| 2026-10-03 | Pas de nouvel ADR ; amendement de l'ADR-0062 pour la lecture « Par établissement » | Aucun port, table, dépendance ni contrat ; UDR-0049 §4 exige qu'un indicateur ajouté passe par l'ADR-0062 | Amendement ADR-0062 |
| 2026-10-03 | « Aucun cours ne doit être assigné hors de son niveau » (G12 révisée, G13) : pas de signal « Hors niveau » (aucune assignation en base), refus de changer le niveau d'un cours assigné | Le porteur est revenu sur G12 après le plan ; l'invariant n'avait qu'un trou, la modification d'un cours | ADR-0075 |
| 2026-10-04 | Le retour des écrans du référentiel mène à « Référentiel », qui y est l'entrée courante ; sous-titre de l'accueil équipe sans « référentiel » | Constats d'intégration (Lot A) et du challenger | Non (UDR-0068 §3.4) |
| 2026-10-04 | L'écart de 5 minutes entre la ligne DRENA (gardée en vue « année ») et les établissements (lus en direct) est un coût consenti | Constat du challenger ; aligner en mettant le tableau en cache reste possible | Amendement ADR-0062 |
| 2026-10-03 | Recherche d'établissement côté serveur sous filtre DRENA | Avec la pagination de G10, un filtre dans le navigateur ne verrait que la page affichée ; à confirmer par le porteur | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Des fichiers partagés n'appartenaient à aucun lot.** Sept tests système hors des listes cassaient à cause du Lot 0 ou d'un lot (`boucle_pedagogique`, `invite_colleague`, `teams/classroom_plan`, `imports_end_to_end`, `finitions/team_accounts`, et `role_homes` / `teams/dashboard` qui cherchaient une seule `nav` dans la barre latérale), plus `script/ci/test_timings.yml`. Les agents se sont arrêtés et les ont signalés comme prévu ; l'intégrateur les a corrigés. Leçon : au plan, chercher dans `test/` chaque identifiant ou sélecteur que le chantier retire (`#team_home_referential`, `aside nav`), et donner `test_timings.yml` au Lot 0.
- **Le bouton clair / sombre disparaissait après un rafraîchissement par morphing** (défaut existant, rendu plus fréquent par l'assignation au catalogue) : corrigé (`turbo:morph`, comme `autofocus` et `math`), test système rouge d'abord.
- **Lot 0 : code écrit avant ses tests.** Le rouge a été prouvé après coup : code de `app/` et `config/` mis de côté (`git stash`), tests lancés (6 erreurs `NameError` / `NoMethodError` attendues), code rétabli, tests verts. À ne pas refaire : le test d'abord, même pour un socle.
- **Environnement du conteneur** : Ruby 3.4.9 absent (compilé par `rbenv install`, ~10 min), PostgreSQL arrêté, rôle `dev-rails` à créer, `chromedriver` 147 face à Chromium 141 (driver 141 téléchargé depuis Chrome for Testing), locale non UTF-8 qui faisait échouer le contrôle de pureté du domaine (`invalid byte sequence in US-ASCII`) : `LANG=C.UTF-8`. `db:prepare` en test charge les seeds et casse les tests (`index_materials_on_name`) : `db:test:prepare` ou `db:schema:load`.
- **Exploration sur un clone périmé** : le dépôt local avait 296 commits de retard sur `origin/Develop` pendant la première exploration et le début du grill. Deux questions (G6, G12) sont parties de prémisses fausses : l'assignation de cours existait encore, la règle de niveau n'était pas appliquée. Corrigé dans le memo avant le PRD. Leçon : `git fetch` et comparer à `origin/<branche>` **avant** d'explorer, pas au premier `push` refusé.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- La barre latérale du shell est masquée sous `lg` : tout contenu qui n'y vit que disparaît du téléphone. D'où le bloc d'invitation gardé sur téléphone et le menu « Plus » de l'équipe.
- La bascule d'assignation et ses streams ne dépendent pas de la page : ils remplacent un identifiant. On les réutilise tels quels au catalogue.
- La règle de niveau de l'élève existe déjà en SQL (`Queries::Catalog::AudienceFilter`) et en domaine (`Entities::Catalog::LevelAudience`) : le filtre « Série » du catalogue et le refus de changer le niveau d'un cours assigné (ADR-0075) reprennent la même règle.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Lien de parrainage vers les autres établissements (référence de l'enseignant) | Retiré par le porteur (G2) | À ouvrir si le porteur le demande |
| « Versement » | Retiré par le porteur (G1) : aucune source de vérité du paiement | Chantier paiement |
| `script/perf/dataset.rb` insère encore des assignations de cours et de fiches, refusées depuis l'ADR-0072 : le budget `PERF=1` ne se rejoue plus tel quel | Hors périmètre (existant) ; mesure du Lot B faite sur une copie corrigée (179 ms p95 pour 300 ms) | `bugfix` à ouvrir |
| Toast d'assignation « … à rendre mardi 6 oct.. » (double point) | Existant, `done_due` finit par un point et `%b` aussi | `bugfix` à ouvrir |
| Seeds de développement : énoncés de question en `<p>…</p>` affichés tels quels | Existant, hors périmètre | `bugfix` à ouvrir |
| `ui_copy_button` n'a pas d'option `full:` : « Copier le lien » est moins large que ses voisins dans la carte Parrainage | Composant partagé, retouche visuelle | Finitions |
| L'entrée courante du menu « Plus » n'a pas de style propre (seulement `aria-current`) | Vient de `ui_dropdown_item`, commun à tous les menus | Finitions |
| L'accueil équipe lit encore toute la `TeamHomeQuery` pour trois chiffres | Optimisation sans effet mesuré | `optimize` si l'accueil dépasse son budget |
| Budget système : +0,4 s puis −1,1 s mesurés, parce que les fichiers réenregistrés tournent plus vite ici que sur GitHub ; la durée réellement ajoutée est d'environ 13 s (3 fichiers neufs 8,2 s, pilotage +5,4 s) | Le garde-fou compare aux durées de base, qui viennent d'une autre machine | Réenregistrer depuis la CI à la prochaine promotion |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-04 |
| **PR** | aucune : poussé directement sur `Develop` (décision du porteur, 2026-10-03) |
| **ADR produits** | [0075](../../decisions/adr/0075-niveau-d-un-cours-assigne-fige.md) ; amendement de la [0062](../../decisions/adr/0062-indicateurs-de-pilotage-lus-en-direct.md) |
| **UDR produits** | [0068](../../decisions/udr/0068-configuration-et-pilotage-par-etablissement.md), [0069](../../decisions/udr/0069-accueil-enseignant-par-niveau-et-assignation-depuis-le-catalogue.md) ; amendements des 0006, 0013, 0014, 0015, 0018, 0021, 0026, 0042, 0049, 0050, 0062 |
| **Preuve** | 3 465 tests, 0 échec, couverture 100 % lignes et branches ; rubocop, brakeman, pureté du domaine verts ; challenger distinct : 10 parcours enseignant et équipe + 6 vérifications du pilotage, dans l'application, à 1280 et 390 px, clair et sombre, chemins d'erreur (422 hors niveau, 403 Référentiel, 422 niveau d'un cours assigné, paramètres invalides) ; pilotage filtré 179 ms p95 (budget 300 ms) |
