# UDR-XXXX : Le pipeline sur « Établissements », la carte « À relancer » et la page « Relances »
<!-- index
titre: Pipeline et relances
statut: Accepté
adr-lie: [XXXX](../adr/XXXX-contexte-crm-suivi-des-ecoles.md)
problematique: Comment l'équipe voit son pipeline et ses relances du jour sans nouvelle entrée dans la barre de navigation
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-04 |
| **Chantier** | `docs/chantiers/crm-ecoles` |
| **ADR lié** | ADR-XXXX-contexte-crm-suivi-des-ecoles |
| **Remplacé par** | — |

---

## 1. Contexte

Le matin, un membre `admin` ou `field` veut savoir qui appeler aujourd'hui et pourquoi. En semaine, il veut voir son pipeline (combien d'écoles en démo, lesquelles sont à lui). La barre de navigation de l'équipe est figée par l'UDR-0006 (Accueil, Cours, Établissements, Pilotage).

## 2. Décision

- Le **pipeline** n'est pas une page : c'est la liste « Établissements » avec deux filtres et deux colonnes de plus.
- Les **relances** ont une page, `/teams/follow-ups`, atteinte par la carte « À relancer » de l'Accueil et par le menu « Plus » ; aucune entrée dans la barre.
- Chaque école à relancer dit **pourquoi**, en badge.

## 3. Règles d'implémentation

**Liste « Établissements »** (`app/views/teams/schools/_filters.html.erb`, `_school_row.html.erb`, `index.html.erb`)

- Si `@can_manage_crm` : deux `ui_field(as: :select)` après les filtres existants, même gabarit.
  - « Étape » (`name="stage"`) : Toutes, Prospect, Démo faite, Inscrite, Active, Abonnée, Perdue.
  - « Responsable » (`name="owner"`) : Tous, Moi (`me`), Sans responsable (`none`), puis les membres `admin`/`field` (`public_id`).
  - Les filtres s'ajoutent à l'URL comme les autres (CA-21) et se conservent dans la pagination.
- Ligne d'école : colonne « Étape » (`ui_badge`, tons de UDR-XXXX-bloc-suivi-de-la-fiche-etablissement, `size: :sm`) et colonne « Responsable » (nom ou « — »). À 390 px, le badge passe sous le nom de l'école, le responsable n'est pas affiché.
- Pour `content` : ni filtres ni colonnes (la liste reste celle d'aujourd'hui).
- Vide après filtre : l'état vide existant de la liste.

**Carte « À relancer » de l'Accueil équipe** (`app/views/teams/crm/home_follow_ups/show.html.erb`, servie dans le frame que `teams/homes/show.html.erb` pose après `_shortcuts` ; Lot 0 pour l'emplacement)

- Visible pour `admin`/`field` seulement.
- `ui_card(title: "À relancer", icon: "bell-alert", href: teams_follow_ups_path)` : un chiffre `font-display text-3xl` (écoles à relancer dont je suis responsable, plus mes relances échues), puis les 3 premières écoles (nom + premier badge de raison), puis le lien « Voir mes relances ».
- Vide : texte « Rien à relancer aujourd'hui » en `text-mute`, icône `check-circle` en `text-success`.
- Chargée dans un `turbo-frame` paresseux `team_home_follow_ups` avec `ui_loading_state(variant: :skeleton, lines: 2)` : l'Accueil ne paie pas le calcul.

**Page « Relances »** (`GET /teams/follow-ups`, `app/views/teams/crm/follow_ups/index.html.erb`)

- `ui_page_header(title: "Relances", back: team_home_path)`.
- `ui_tabs` (paramètre `tab`) :
  1. « À relancer » (`signals`, défaut) — écoles dont je suis responsable avec au moins un signal ; bascule « Toutes les écoles » (`scope=all`).
  2. « Mes relances » (`mine`) — mes relances ouvertes, échues d'abord, puis par échéance.
  3. « Sans destinataire » (`orphans`) — **`admin` seulement** : relances ouvertes dont le destinataire est indisponible, et écoles sans responsable ayant un signal.
- Ligne (bureau : tableau `<table>` avec `<th scope="col">` ; 390 px : cartes empilées `ui_card(padding: :sm)`) : école (lien vers la fiche, ancre `#school_crm`), DRENA en `text-mute`, badges de raison, échéance, destinataire (onglets 2 et 3), actions.
- Badges de raison : « Relance échue » `:error`, « Perte d'usage » `:warning`, « Démo sans suite » `:info`, « Inscrite sans démarrage » `:brand`.
- Actions d'une relance : « Faite » (`ui_button` `:secondary`, `:sm`, Turbo Stream `remove` de la ligne + `ui_toast`), ⋮ « Réattribuer » (modale, `admin` ou responsable de l'école), ⋮ « Rédiger un message » (UDR-XXXX-assistants-du-suivi).
- Pagination `ui_pagination`, 25 lignes.
- Vides : « Rien à relancer » (onglet 1, icône `check-circle`), « Aucune relance ouverte » (2), « Rien d'orphelin » (3).

**Menu « Plus »** (`app/helpers/navigation_helper.rb`, Lot 0) : entrée « Relances », icône `bell-alert`, pour `team` `admin`/`field`.

**Tokens** : ceux de la liste « Établissements » existante ; badges par `ui_badge` ; aucune valeur en dur.

**États obligatoires** : chargement (squelette de la carte ; la page est rendue côté serveur), erreur (`ui_error_state` dans le frame de la carte), vide (ci-dessus), succès (toast après « Faite » et « Réattribuer »).

**Accessibilité** : onglets `ui_tabs` (`role="tablist"`, `aria-selected`) ; tableau avec en-têtes `scope="col"` ; cibles ≥ 48 px ; le badge de raison est du texte, pas une couleur seule ; la carte est un lien unique (pas de liens imbriqués).

## 4. Conséquences

- La liste « Établissements » porte deux filtres réservés à `admin`/`field` ; tout futur filtre commercial s'y ajoute plutôt que de créer une page pipeline.
- La barre de navigation reste celle de l'UDR-0006.
- La carte « À relancer » ne compte que ce qui me concerne ; la vue de toute l'équipe est sur la page, onglet 1 avec « Toutes les écoles ».
