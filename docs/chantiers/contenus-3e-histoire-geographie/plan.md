# Plan d'exécution — Leçons de 3ème en Histoire-Géographie, et leurs figures

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Décisions : ADR-0117 (§4.2, §4.3, menace) et UDR-0142 (§3), acceptées.

## Graphe

```
Lot 0 — SOCLE : FigureKinds, FigureCatalogs, cohérence, contrôleur (séquentiel)
  ↓
  ├─► Lot A  timeline.js            ┐
  ├─► Lot B  map.js + 3 fonds       ├─ en parallèle, worktrees
  ├─► Lot C  diagram.js             │
  └─► Lot D  stat_chart.js (courbe) ┘
  ↓
Lot E — 10 leçons (un sous-agent par leçon, 6 au plus à la fois) + relecture IA des faits
  ↓
Lot F — section des sortes de la vague dans le prompt (après fusion de la vague 1 dans Develop)
```

---

## Lot 0 — Socle

- **Couche**       : domaine + UI (contrats)
- **Fichiers**     : `app/domain/entities/catalog/figure_kinds.rb`
                     `app/domain/entities/catalog/figure_catalogs.rb` *(nouveau)*
                     `app/domain/entities/catalog/figure.rb`
                     `app/javascript/controllers/figure_controller.js`
                     `test/domain/entities/catalog/figure_test.rb` · `test/domain/entities/catalog/figure_catalogs_test.rb` *(nouveau)*
                     `test/javascript/figures_structure_test.rb`
                     `test/script/contenus/parite_import_test.rb`
                     `docs/chantiers/contenus-3e-histoire-geographie/*`
- **Dépend de**    : —
- **Test associé** : tests de domaine (CA-1, cohérence de chaque sorte, chemins d'erreur, 100 % lignes et branches) ; parité import ↔ script (CA-2) ; structure (CA-7)
- **Done quand**   : `Figure.errors_for` accepte et refuse les 4 formes ci-dessous ; `ruby script/contenus/valider.rb` valide une carte **sans modification du script** ; le contrôleur accepte les 8 sortes et attend une création asynchrone

### Contrat `FigureKinds` (ADR §4.2)

| `kind` | `params` | `item_range` | `adjustable` | `required` |
|---|---|---|---|---|
| `timeline` | `start`, `end` number(−3000..2100) ; `step` number(1..500) ; `unit` enum(`year`, `month`, `day`) ; `periods` list(8) ; `events` list(16) | −3000..2100 | `start`, `end` | `start end step` |
| `map` | `base` enum(`cote_d_ivoire`, `africa`, `world`) ; `areas` list(40) ; `places` list(20) ; `routes` list(10) ; `legend` list(6) | 1..6 | — | `base` |
| `diagram` | `layout` enum(`flow`, `tree`, `cycle`) ; `direction` enum(`down`, `right`) ; `nodes` list(12) ; `edges` list(16) ; `legend` list(4) | 1..4 | — | `layout nodes` |
| `stat_chart` | `chart` gagne `line` | inchangé | — | inchangé |

`unit` absent = `year` ; `direction` absent = `down`.

### Cohérence (`<kind>_errors`, raison `figure_invalid`, chemin du paramètre)

- **timeline** : `end > start` sinon `params.end` ; `(end − start) / step ≤ 200` sinon `params.step`. Chaque `events[i]` est un objet avec `at` nombre dans `[start, end]` (sinon `params.events[i].at`) et `label` texte non vide (sinon `params.events[i].label`). Chaque `periods[i]` : `from`, `to` nombres dans `[start, end]` (sinon `….from` / `….to`), `from < to` (sinon `params.periods[i].to`), `label` texte non vide. Élément qui n'est pas un objet : `params.events[i]`.
- **map** : chaque `areas[i]` objet, `id` dans `FigureCatalogs.areas(base)` (sinon `params.areas[i].id`), `id` non répété (même chemin), `category` entier de 1 à `legend.size` (sinon `params.areas[i].category`). Aire donnée sans `legend` : `params.legend`. Chaque `places[i].id` dans `FigureCatalogs.places(base)` (sinon `params.places[i].id`), `label` facultatif texte. Chaque `routes[i]` : `from`, `to` dans les lieux du fond (sinon `params.routes[i].from` / `.to`), `label` facultatif.
- **diagram** : chaque `nodes[i]` objet avec `id` texte non vide unique (sinon `params.nodes[i].id`), `label` texte non vide (sinon `params.nodes[i].label`), `category` facultative entière de 1 à `legend.size` (sinon `params.nodes[i].category`). Chaque `edges[i]` objet, `from`/`to` nœuds existants et différents (sinon `params.edges[i].from` / `.to`). `tree` : chaque nœud a au plus un parent (sinon `params.edges[i].to` sur l'arête en trop), exactement une racine et aucun cycle (sinon `params.edges`). `cycle` : au moins 3 nœuds (sinon `params.nodes`).
- Les contrôles d'éléments ne se font que si la liste est un tableau ; les bornes génériques (`param_errors`) restent la première barrière.

### Contrat `FigureCatalogs` (Ruby pur, `Entities::Catalog::FigureCatalogs`)

`figure.rb` commence par `require_relative "figure_catalogs" unless defined?(Entities::Catalog::FigureCatalogs)` : `valider.rb` (qui ne charge que `figure_kinds` et `figure`) valide ainsi les cartes sans être modifié. API : `MAP_BASES = { "cote_d_ivoire" => { areas: [...], places: [...] }, ... }.freeze` ; `self.areas(base)`, `self.places(base)` (→ `[]` pour un fond inconnu).

- **`cote_d_ivoire`** — aires : les 14 districts `abidjan`, `yamoussoukro`, `bas_sassandra`, `comoe`, `denguele`, `goh_djiboua`, `lacs`, `lagunes`, `montagnes`, `sassandra_marahoue`, `savanes`, `vallee_du_bandama`, `woroba`, `zanzan` ; les zones naturelles `dense_forest`, `savanna`, `coastal_strip`, `mountain_west`. Lieux : `abidjan`, `yamoussoukro`, `bouake`, `daloa`, `korhogo`, `san_pedro`, `man`, `gagnoa`, `abengourou`, `bondoukou`, `odienne`, `divo`, `sassandra`, `grand_bassam`, `bingerville`, `assinie`, `grand_lahou`, `dabou`, `agboville`, `kong`, `seguela`, `ferkessedougou`, `katiola`, `dimbokro`, `aboisso`, `tabou`, `soubre`, `toumodi`, `tiassale`, `danane`, `boundiali`, `touba`, `guiglo`, `duekoue`, `bouafle`, `adzope`, `issia`, et les barrages `kossou`, `taabo`, `buyo`, `ayame`.
- **`africa`** — aires : les 54 États (ISO alpha-3 minuscules) `dza ago ben bwa bfa bdi cmr cpv caf tcd com cod cog civ dji egy gnq eri swz eth gab gmb gha gin gnb ken lso lbr lby mdg mwi mli mrt mus mar moz nam ner nga rwa stp sen syc sle som zaf ssd sdn tza tgo tun uga zmb zwe`. Lieux : leurs capitales `algiers luanda porto_novo gaborone ouagadougou gitega yaounde praia bangui ndjamena moroni kinshasa brazzaville yamoussoukro djibouti cairo malabo asmara mbabane addis_ababa libreville banjul accra conakry bissau nairobi maseru monrovia tripoli antananarivo lilongwe bamako nouakchott port_louis rabat maputo windhoek niamey abuja kigali sao_tome dakar victoria freetown mogadishu pretoria juba khartoum dodoma lome tunis kampala lusaka harare`, et `abidjan`, `lagos`, `johannesburg`, `casablanca`, `alexandria`, `mombasa`, `douala`, `suez`.
- **`world`** — aires : les 174 pays de Natural Earth 1:110m (ISO_A3, ou ADM0_A3 si `-99`, en minuscules), sans `ata`, `cyn`, `sol` (Antarctique non dessiné ; Chypre du Nord et Somaliland dessinés avec Chypre et la Somalie) : `afg ago alb are arg arm atf aus aut aze bdi bel ben bfa bgd bgr bhs bih blr blz bol bra brn btn bwa caf can che chl chn civ cmr cod cog col cri cub cyp cze deu dji dnk dom dza ecu egy eri esh esp est eth fin fji flk fra gab gbr geo gha gin gmb gnb gnq grc grl gtm guy hnd hrv hti hun idn ind irl irn irq isl isr ita jam jor jpn kaz ken kgz khm kor kos kwt lao lbn lbr lby lka lso ltu lux lva mar mda mdg mex mkd mli mmr mne mng moz mrt mwi mys nam ncl ner nga nic nld nor npl nzl omn pak pan per phl png pol pri prk prt pry pse qat rou rus rwa sau sdn sen slb sle slv som srb ssd sur svk svn swe swz syr tcd tgo tha tjk tkm tls tto tun tur twn tza uga ukr ury usa uzb ven vnm vut yem zaf zmb zwe` ; et les continents `africa`, `asia`, `europe`, `north_america`, `south_america`, `oceania`. Lieux : `pearl_harbor`, `hiroshima`, `nagasaki`, `stalingrad`, `normandy`, `berlin`, `london`, `paris`, `moscow`, `washington`, `tokyo`, `rome`, `el_alamein`, `midway`, `warsaw`, `yalta`, `brazzaville`, `new_york`, `san_francisco`, `geneva`, `the_hague`, `abidjan`.

### Contrôleur et structure

- `KINDS` : les 8 sortes. `RANGE_PARAMS` : `timeline: ["start", "end"]`, `map: []`, `diagram: []` ; le test de structure compare `RANGE_PARAMS` aux clés `adjustable` de `FigureKinds` (identiques aux paramètres numériques pour les sortes existantes).
- `connect()` attend `module.create(...)` (`await`, puis jeton de génération revérifié) : un module peut charger ses données par `import()` avant de dessiner. Une promesse rejetée → état `error`.
- `FiguresStructureTest` : les scans (balisage, ressource réseau, couleur en dur) couvrent aussi `lib/figures/maps/*.js` ; chaque `lib/figures/maps/*.js` pèse ≤ 150 Ko ; les modules de `lib/figures/` restent exactement des sortes de `FigureKinds` plus `svg`.

---

## Lot A — Frise (`timeline`)

- **Couche**       : UI
- **Fichiers**     : `app/javascript/lib/figures/timeline.js` · `test/system/catalog/figure_timeline_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : CA-4, CA-5, CA-6 (frise mal formée injectée → `error`)
- **Done quand**   : une frise de 1880 à 1960 (pas 10) avec 2 périodes et 6 événements est `ready` à 390 px et à 1280 px sans libellé chevauché ; le curseur `start` réduit les graduations et masque les événements sortis

Rendu : UDR §3 `timeline` (viewBox 640×180, axe gradué, bandes de périodes catégories 1 à 6, événements en quinconce, numérotation de repli). `read()` revérifie bornes et formes comme `stat_chart.js` ; attributs `data-tick`, `data-event`, `data-period` pour les tests.

---

## Lot B — Carte (`map`) et ses fonds

- **Couche**       : UI + script de contenus
- **Fichiers**     : `app/javascript/lib/figures/map.js` · `app/javascript/lib/figures/maps/{cote_d_ivoire,africa,world}.js`
                     `script/contenus/fonds_de_carte.rb`
                     `test/javascript/map_bases_test.rb` · `test/system/catalog/figure_map_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : CA-3 (parité des identifiants), CA-4, CA-6, CA-7 (poids), CA-8 (teinte + motif)
- **Done quand**   : une carte de chaque fond est `ready` ; un lieu inconnu injecté → `error` ; les identifiants des modules = `FigureCatalogs` ; chaque fond ≤ 150 Ko

Fonds (ADR §4.3) : `world` ← Natural Earth 1:110m (Equal Earth, viewBox 640×360) ; `africa` ← Natural Earth 1:50m (viewBox 640×640 ; Sahara occidental et Somaliland dessinés sans identifiant) ; `cote_d_ivoire` ← geoBoundaries CIV ADM1 (CC BY 4.0, 14 districts, viewBox 640×640, attribution « Districts : geoBoundaries, CC BY 4.0 » sous la légende). Zones naturelles : contours schématiques écrits dans le script (polygones convexes en longitude-latitude, découpés sur le contour du pays par Sutherland-Hodgman), sans chevauchement. Lieux : coordonnées de Natural Earth populated places quand la ville y est, sinon celles écrites dans le script. Simplification (Douglas-Peucker) et arrondi faits par le script ; les sources téléchargées vont dans `tmp/`, jamais commitées.

Format des modules (lu par le test de parité) : `export const AREAS = {` puis une entrée par ligne `  <id>: { name: "…", d: "…" },` puis `}` ; `export const PLACES = {` puis `  <id>: { name: "…", x: …, y: … },` ; `export const VIEWBOX`, `export const OUTLINE` (tracés sans identifiant), `export const ATTRIBUTION` (`""` si aucune). Continents de `world` : `export const CONTINENTS = { africa: ["dza", …], … }` — une aire continent colore ses pays.

Rendu : UDR §3 `map` (catégories teinte + motif `fig-<key>-pat-<n>`, points de 5 unités, routes en quadratiques fléchées, numérotation de repli, légende dans le SVG). `map.js` charge le fond par `import(\`./maps/${base}.js\`)` après avoir vérifié `base` dans sa liste blanche ; identifiant absent du fond → erreur (rien n'est dessiné). Attributs `data-area`, `data-place`, `data-route`, `data-legend`.

---

## Lot C — Schéma fléché (`diagram`)

- **Couche**       : UI
- **Fichiers**     : `app/javascript/lib/figures/diagram.js` · `test/system/catalog/figure_diagram_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : CA-4, CA-6
- **Done quand**   : un `flow` à 5 nœuds, un `tree` (organes de l'ONU, 7 nœuds) et un `cycle` à 4 nœuds sont `ready` à 390 px et à 1280 px, nœuds sans chevauchement ; une arête vers un nœud absent injectée → `error`

Rendu : UDR §3 `diagram` (viewBox 640×hauteur calculée ≤ 640, rectangles arrondis rayon 8, 3 lignes au plus, `<title>` du texte complet si tronqué, flèches `<marker>` uniques par figure, catégories teinte + motif). Attributs `data-node`, `data-edge`.

---

## Lot D — Courbe (`stat_chart` `line`)

- **Couche**       : UI
- **Fichiers**     : `app/javascript/lib/figures/stat_chart.js` · `test/system/catalog/figure_kinds_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : CA-4
- **Done quand**   : une courbe de 6 valeurs dessine 6 points reliés (`data-point`), sur le même repère gradué que les bâtons, étiquettes d'abscisse lisibles à 390 px

---

## Lot E — Les 10 leçons

- **Couche**       : contenus
- **Fichiers**     : `docs/contenus/lecons-traitees/3eme/histoire-geographie/*.json` (10 fichiers, les 3 fichiers v1 remplacés)
- **Dépend de**    : Lots 0 à D fusionnés dans la branche
- **Test associé** : CA-9, CA-10, CA-11 — `ruby script/contenus/valider.rb` sans erreur ni avertissement ; relecture IA indépendante des faits, dates et chiffres
- **Done quand**   : les 10 fichiers passent le script, la relecture est soldée, les fichiers sont envoyés au porteur

Un sous-agent par leçon (6 au plus à la fois), prompt actuel + section des sortes de la vague dans le brief. Nom de fichier : intitulé exact en kebab-case sans accent (`histoire-le-mouvement-imperialiste-et-la-colonisation-en-cote-d-ivoire.json`). Figures selon l'inventaire ADR §4.1. Questions à choix seulement tant que la vague 1 n'est pas fusionnée.

---

## Lot F — Prompt de rédaction

- **Couche**       : documentation
- **Fichiers**     : `docs/contenus/prompt-redaction*.md` (section des sortes `timeline`, `map`, `diagram`, `line`)
- **Dépend de**    : fusion de la PR de la vague 1 dans `Develop`, puis fusion de `Develop` dans la branche
- **Test associé** : relecture : chaque forme et liste fermée du prompt = `FigureKinds` / `FigureCatalogs`
- **Done quand**   : le prompt généralisé décrit les sortes de la vague

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `figure_kinds.rb`, `figure_catalogs.rb`, `figure.rb` | Lot 0 |
| `figure_controller.js`, `figures_structure_test.rb`, `parite_import_test.rb` | Lot 0 |
| `timeline.js`, `figure_timeline_test.rb` | Lot A |
| `map.js`, `maps/*.js`, `fonds_de_carte.rb`, `map_bases_test.rb`, `figure_map_test.rb` | Lot B |
| `diagram.js`, `figure_diagram_test.rb` | Lot C |
| `stat_chart.js`, `figure_kinds_test.rb` | Lot D |
| `lecons-traitees/3eme/histoire-geographie/*` | Lot E |
| `prompt-redaction*.md` | Lot F |
| `script/contenus/valider.rb` | aucun (vague 1) |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
