# UDR-0049 : Page « Pilotage » de l'équipe — chiffres clés, filtres, répartition, couverture, inscrits, recherche

| | |
|---|---|
| **Statut** | Accepté (par défaut, à confirmer par le porteur) |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/pilotage-equipe`](../../chantiers/pilotage-equipe/prd.md) — V4, TR-10, TR-11, TR-12 |
| **ADR lié** | [ADR-0062](../adr/0062-indicateurs-de-pilotage-lus-en-direct.md) (définitions, lectures bornées) · [ADR-0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (aucun traceur) · [ADR-0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md) (budget) · [ADR-0038](../adr/0038-comptes-de-l-equipe-et-sous-roles.md) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0006](0006-shell-applicatif-par-role.md) · [UDR-0018](0018-accueil-equipe.md) |
| **Remplacé par** | — |

---

## 1. Contexte

L'entrée « Pilotage » de la navigation équipe est grisée depuis la V1. L'équipe ne sait ni combien d'élèves travaillent, ni quelles DRENA sont couvertes, et ne retrouve un compte que par son numéro exact (UDR-0020). Elle consulte souvent depuis un téléphone, en tournée.

## 2. Décision

1. **Une seule page, `GET /teams/dashboard`**, rendue côté serveur, sans JavaScript ajouté ni bibliothèque de graphiques.
2. **Les filtres sont des liens et un formulaire GET** : l'URL porte `period` et `drena`, se partage et survit au retour arrière. La période se choisit par trois liens (7 j, 30 j, année scolaire), la DRENA par une liste déroulante validée par « Filtrer » (pas d'envoi automatique : aucun JavaScript, et un changement involontaire au clavier ne recharge pas la page).
3. **Deux blocs de chiffres** : « Sur la période » (flux, suivent la période) puis « En ce moment » (stocks). L'utilisateur voit tout de suite ce que change le filtre.
4. **Les barres de la répartition sont en CSS pur**, largeur par classes Tailwind littérales en pas de 5 %. Le nombre et le pourcentage sont **écrits** à côté : la barre est décorative (`aria-hidden`).
5. **« Par DRENA » est un tableau** (`caption`, `scope`), qui défile dans sa carte sur téléphone, la page jamais.
6. **Inscrits récents** : 10 comptes, numéro masqué, sans lien (la fiche de compte est la V2).
7. **La recherche vit dans un frame** (`team_dashboard_search`) : chercher ne recalcule pas les indicateurs, l'URL avance, et la page complète rend aussi les résultats (sans JavaScript, ou sur un lien partagé).

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure** — `app/views/teams/dashboards/show.html.erb`, dans le shell (`content_for :nav_key, "dashboard"`) :

1. `ui_page_header` « Pilotage », sous-titre « Indicateurs agrégés, lus en direct dans les données de Lnclass. » ; sous le titre, une ligne `p#team_dashboard_scope` : « Périmètre : <DRENA ou « toute la Côte d'Ivoire »> · <libellé de la période> ».
2. `_filters` : `div#team_dashboard_filters` (`rounded-card border border-line bg-white p-4 shadow-card`, `grid gap-4 lg:grid-cols-2`) :
   - `nav` `aria-label` « Période » : trois liens `a.min-h-tap.rounded-full` (`inline-flex items-center px-4 text-sm font-medium`) ; le courant `bg-ink text-white` avec `aria-current="true"`, les autres `bg-mist text-ink hover:bg-line`. Chaque lien garde la DRENA.
   - `form` GET `team_dashboard_path`, `role="search"`, `aria-label` « Filtrer par DRENA » : `hidden_field_tag :period`, `label` + `select#dashboard_drena` (« Toutes les DRENA », puis les DRENA par nom ; classes `ComponentsHelper::FIELD_*` comme `teams/schools/_filters`), `ui_button` « Filtrer » (`icon: "funnel"`, `type: :submit`), et, si une DRENA est choisie, `ui_button` « Toute la Côte d'Ivoire » `variant: :ghost` vers la page sans `drena`.
3. `_key_figures` : deux `ui_card`, `#team_dashboard_period` « Sur la période » (icône `bolt`) puis `#team_dashboard_now` « En ce moment » (icône `chart-bar`). Dans chacune, `ul.grid.grid-cols-2.gap-3.lg:grid-cols-4` de tuiles `li.rounded-ln.bg-mist.px-3.py-4` : nombre `span.block.font-display.text-3xl.font-extrabold.tabular-nums.text-ink`, libellé `span.text-sm.text-mute` accordé au nombre (i18n `count:`), et au besoin une précision `span.mt-1.block.text-xs.text-mute`.
   - Période (`li#figure_<clé>`) : `signups` (nouveaux inscrits), `active_students` (élèves actifs), `completed_sessions` (exercices terminés, précision « Réussite moyenne : 70 % » ou « Réussite moyenne : — »), `assignments` (assignations par les enseignants).
   - En ce moment : `students`, `teachers`, `team` (« — » et précision « Sans DRENA » sous un filtre), `classrooms` (précision « Année 2026-2027 »), `schools` (établissements actifs) avec, dessous, `ul#team_dashboard_coverage` de trois lignes « dont N avec une classe / un enseignant / un élève ».
4. `_levels` : `ui_card#team_dashboard_levels` « Élèves par niveau » (icône `squares-2x2`, sous-titre « Élèves placés dans une classe active de l'année »). `ul.space-y-3`, un `li#level_share_<slug>` par niveau, par position : ligne `flex justify-between text-sm` avec le nom (`font-medium text-ink`) et « 32 élèves · 18 % » (`tabular-nums text-mute`) ; dessous la piste `div.h-2.rounded-full.bg-mist` `aria-hidden="true"` contenant `div.h-2.rounded-full.bg-brand` et la classe de `dashboard_bar_width(pourcentage)`. En vue nationale seulement, un `p#students_without_classroom` : « Sans classe : N élèves ».
5. `_drenas` : `ui_card#team_dashboard_drenas` « Par DRENA » (icône `map-pin`, sous-titre « Couverture, triée par nombre d'élèves »). `div.relative.overflow-x-auto` → `table.w-full.min-w-2xl.text-left.text-sm` ; `caption.sr-only` « Couverture par DRENA sur <période> » ; en-têtes `th scope="col"` : DRENA, Établissements actifs, Classes, Enseignants, Élèves, Élèves actifs ; chaque ligne `tr#drena_row_<public_id>` commence par `th scope="row"` (nom) ; nombres `text-right tabular-nums`.
6. `_recent_signups` : `ui_card#team_dashboard_signups` « Inscrits récents » (icône `user-plus`). `ol.divide-y.divide-line`, `li#signup_<public_id>` : `ui_avatar(nom, size: :sm)`, nom (`font-medium text-ink`), `ui_role_badge(role)`, établissement ou « — », numéro masqué (`font-mono text-xs text-mute`), `time[datetime]` « il y a 3 jours ».
7. `_search` : `ui_card#team_dashboard_search_card` « Rechercher un élève ou un enseignant » (icône `magnifying-glass`). Formulaire GET `role="search"`, `data-turbo-frame="team_dashboard_search"`, `data-turbo-action="advance"`, champs cachés `period` et `drena`, champ `search_field_tag :q` (`label` « Nom ou numéro », aide « 2 caractères au moins, 4 chiffres pour un numéro »), `ui_button` « Rechercher ». Puis `turbo_frame_tag "team_dashboard_search"` (classe `block transition-opacity aria-busy:pointer-events-none aria-busy:opacity-50`) qui contient `p#search_total` (`aria-live="polite"`), la liste `ul#search_results`, `li#account_<public_id>` : nom, `ui_role_badge`, « établissement · classe » (enseignant : « N classes »), numéro masqué ; puis `ui_pagination`.

**Tokens** : ceux de l'UDR-0005, rien d'autre. Barres `bg-mist` (piste) et `bg-brand` (valeur) ; aucun attribut `style`, aucune valeur arbitraire. `Teams::DashboardsHelper::BAR_WIDTHS` liste les 21 classes littérales `w-0`, `w-1/20` … `w-19/20`, `w-full` ; le pourcentage est arrondi au multiple de 5 le plus proche, avec un minimum de `w-1/20` pour toute valeur non nulle (une barre visible pour un niveau qui a des élèves).

**Comportement**
- Aucun JavaScript ajouté. Liens de période et formulaire DRENA : navigations Turbo de la page entière.
- Recherche : le contrôleur reconnaît le frame `team_dashboard_search` (`turbo_frame_request_id`) et ne rend que `_search_results` ; les liens de pagination restent dans le frame.
- Lecture seule : aucun Turbo Stream, aucun toast.

**États obligatoires**
- Vide : chaque chiffre à 0 ; réussite « — » ; répartition `ui_empty_state` « Aucun élève placé », icône `squares-2x2` ; « Par DRENA » `ui_empty_state` « Aucune DRENA » ; inscrits `ui_empty_state` « Aucun inscrit pour l'instant » ; recherche sans terme : consigne « Tapez un nom ou un numéro. » ; terme trop court : « Tapez au moins 2 caractères. » ; sans résultat : `ui_empty_state` « Aucun compte trouvé ».
- Chargement : le frame de recherche s'estompe (`aria-busy`) pendant la requête. Le reste est rendu en une fois par le serveur.
- Erreur : une erreur serveur rend la page d'erreur commune ; aucune section ne charge séparément, il n'y a donc pas d'échec partiel à afficher.
- Refus : 403 pour tout rôle autre que `team`.

**Accessibilité**
- Un seul `h1` ; chaque carte a son `h2` (titre de `ui_card`).
- Chaque chiffre se lit nombre puis libellé (« 12 élèves actifs ») ; icônes décoratives.
- Tableau : `caption`, `th scope="col"` et `th scope="row"`.
- Barres : texte écrit à côté, barre `aria-hidden="true"`.
- Période courante : `aria-current="true"` ; tous les liens et boutons ≥ 48 px de haut (`min-h-tap`).
- À 390 px : filtres empilés, tuiles sur deux colonnes, tableau qui défile dans sa carte ; `document.documentElement.scrollWidth` ne dépasse pas la largeur de la fenêtre.

## 4. Conséquences

- L'entrée « Pilotage » (`team_dashboard_path`) est active : l'UDR-0006 et l'UDR-0018 sont amendées. La navigation équipe n'a plus d'entrée inactive.
- Un nouvel indicateur s'ajoute par une définition dans l'ADR-0062, une ligne de query testée et une tuile de `_key_figures`, jamais par un script.
- Interdit sur cette page : une bibliothèque de graphiques, un attribut `style`, un numéro complet, un lien vers une fiche de compte avant la V2.
