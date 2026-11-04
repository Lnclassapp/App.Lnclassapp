# UDR-XXXX : Suivi des écoles — page Suivi à onglets, fiche de suivi d'une école, journal et relances
<!-- index
titre: Suivi des écoles (CRM)
statut: Proposé
adr-lie: XXXX-suivi-commercial-des-ecoles
problematique: où l'équipe prépare ses relances et note ses échanges avec une école, sur téléphone d'abord
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-11-04 |
| **Chantier** | `docs/chantiers/crm-ecoles` |
| **ADR lié** | ADR-XXXX-suivi-commercial-des-ecoles |
| **Remplacé par** | — |

---

## 1. Contexte

Les membres `admin` et `field` démarchent les écoles depuis leur téléphone, souvent entre deux visites. Ils doivent savoir en un coup d'œil qui relancer et pourquoi, puis noter un échange en moins d'une minute juste après l'avoir eu. Aujourd'hui, rien de tout cela n'est dans l'application.

## 2. Décision

- **Une entrée de shell « Suivi »** plutôt qu'un onglet dans la fiche d'établissement existante : c'est un outil de travail quotidien, pas un détail du référentiel.
- **Une page à onglets** (`ui_tabs`, rendue côté serveur, un onglet par URL `?tab=`) : « À relancer » d'abord, parce que c'est la question du matin.
- **Une fiche de suivi distincte** de la fiche d'établissement (`teams/schools/show`), reliées entre elles par un lien : la fiche d'établissement reste celle du référentiel (classes, direction, enseignants), sans encombrement.
- **Noter un échange dans une modale** (`ui_modal`), pas sur une page : on reste sur la fiche et le journal se met à jour par Turbo Stream.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 Shell

- `app/helpers/navigation_helper.rb` : `DESTINATIONS[:team]` gagne `[ :follow_ups, :teams_follow_ups_path, "phone-arrow-up-right" ]`, après `:schools`, rendue seulement si `FollowSchoolPolicy` `:read_and_note` accepte l'acteur (helper `can_follow_schools?`). Pour `content`, rien ne change.
- Libellé `t("navigation.team.follow_ups")` = « Suivi ». Si la barre basse dépasse 5 cases pour `admin` ou `field`, « Pilotage » passe dans « Plus » pour ces deux sous-rôles.
- Pastille sur l'entrée : nombre d'alertes « À voir » non lues (`ui_badge` `tone: :team`, `size: :sm`), masquée à 0 ; `aria-label` « Suivi, N alertes ».

### 3.2 Page Suivi (`app/views/teams/follow_ups/index.html.erb`)

- `ui_page_header title: "Suivi des écoles"`.
- **Bandeau « sans responsable »** (`admin` seul, si N > 0) : `ui_card` avec `class: "bg-warning-soft"`, texte « N écoles sans responsable », bouton « Attribuer » → onglet « Toutes » filtré `owner=none` avec cases à cocher.
- **Bloc « À voir »** (si alertes non lues) : liste de 5 au plus, ligne = icône (`chat-bubble-left` pour un échange d'un collègue, `arrow-trending-up` pour une reprise d'usage), texte (« Konan a noté un appel — Lycée X », « Lycée X sert de nouveau »), date relative ; la ligne est un lien vers la fiche. Lien « Tout voir » s'il y en a plus de 5.
- **Onglets** `ui_tabs id: "follow_ups"` :

| Clé | Libellé | Contenu |
|---|---|---|
| `queue` | « À relancer (N) » | File de l'acteur (§3.3). `admin` : sélecteur « Mes écoles · Toutes » (liens, `aria-current`) |
| `all` | « Toutes » | Liste filtrée (§3.4) |

### 3.3 Ligne de la file « À relancer » (`_queue_row.html.erb`)

- Carte cliquable (`ui_card href:` vers la fiche), hauteur ≥ 64 px. Ligne 1 : nom de l'école (`font-medium text-ink`, tronqué), à droite le badge d'étape (§3.6). Ligne 2 (`text-sm text-mute`) : motif, une icône par motif :

| Motif | Icône | Texte |
|---|---|---|
| `follow_up_due` | `bell-alert` | « Relance prévue le 3 nov. » + note de la relance tronquée à 60 caractères |
| `demo_stalled` | `presentation-chart-line` | « Démo sans suite depuis 9 jours » |
| `inactive` | `moon` | « Plus de devoir depuis 20 jours » |

- Ligne 3 : DRENA · responsable (`admin` en « Toutes » seulement).
- Ordre : motif dans l'ordre ci-dessus, puis le plus ancien d'abord. 50 par page, `ui_pagination`.

### 3.4 Onglet « Toutes » (`_all.html.erb`)

- Filtres en `form` GET (comme `teams/schools/_filters`) : recherche (nom, sigle, code national), étape affichée (les 6), responsable (« Moi », « Sans responsable », chaque membre `admin`/`field`), DRENA. Envoi automatique au changement (Stimulus `autosubmit` existant), bouton « Filtrer » visible sans JS.
- Téléphone (< 768 px) : cartes comme §3.3, avec ligne 2 = « Dernier échange il y a 4 j » ou « Aucun échange ». Ordinateur (≥ 768 px) : tableau `École · Étape · Responsable · Dernier échange · Dernier geste pédagogique`.
- `admin` : une case à cocher par ligne (`aria-label` « Choisir Lycée X »), et une barre d'action collante en bas quand ≥ 1 case est cochée : « N écoles · Attribuer à [sélecteur] · Attribuer ». Envoi : `POST /teams/owner_assignments`. Succès : `ui_toast` « 3 écoles attribuées à Touré » et liste rechargée.

### 3.5 Fiche de suivi (`app/views/teams/relationships/show.html.erb`, route `/teams/schools/:school_id/relationship`)

Ordre des blocs (une colonne sur téléphone ; sur ordinateur `lg:grid-cols-main-aside`, journal à gauche, colonne de droite = 1 à 3) :

1. **En-tête** (`#relationship_header`) : `ui_back_link` « Suivi » ; nom de l'école (`font-display text-2xl`) ; DRENA ; badge d'étape (§3.6) ; « Responsable : Touré » ou « Sans responsable ». Actions :
   - « Noter un échange » (`ui_button` primaire, pleine largeur sur téléphone) → modale §3.7 ;
   - menu `ui_dropdown` : « Changer l'étape » (si `:change_stage`), « Changer le responsable » (`admin`), « Planifier une relance », « Fiche de l'établissement » (lien vers `teams/schools/show`).
2. **Usage** (`ui_card title: "Usage"`) : « 12 enseignants · 340 élèves · 3 directions » ; « Dernier geste : devoir donné par M. Yao, il y a 3 jours » ou « Aucun geste pédagogique ». Une ligne d'aide `ui_info_tip` : « Inscrite et Active se calculent : un compte rattaché ; un devoir donné ou un travail rendu dans les 14 derniers jours. »
3. **Relances** (`#relationship_follow_ups`) : relances ouvertes, ligne = date (rouge `text-error` si dépassée), destinataire, note, deux boutons icône 48 px « Faite » (`check`) et « Annuler » (`x-mark`), `aria-label` complets. Vide : `ui_empty_state title: "Aucune relance prévue"`, action « Planifier ».
4. **Assistants** : les quatre boutons de l'UDR-XXXX-assistants-ia-du-suivi.
5. **Journal** (`#relationship_journal`, `<ol>` antéchronologique, 20 par page, « Voir plus » en lien Turbo Frame `journal_page`) :
   - échange : icône du type (`phone`, `chat-bubble-oval-left`, `map-pin`, `presentation-chart-line`, `envelope`, `ellipsis-horizontal`), « Appel — Mme Kouassi (directrice) », badge de résultat (`positive` → `success` « Positif », `neutral` → `neutral` « Neutre », `negative` → `error` « Négatif », `no_answer` → `warning` « Sans réponse »), note (texte échappé, `whitespace-pre-line`, repliée au-delà de 4 lignes avec « Lire la suite »), « par Konan · 3 nov., 14:20 » ;
   - trace (étape, responsable, relance faite, reprise d'usage, rapport téléchargé) : ligne compacte `text-sm text-mute`, icône `arrow-path`, ex. « Étape : Prospect → Démo faite · par Touré · 3 nov. ». « Rapport téléchargé » porte un lien « Télécharger à nouveau ».
   - Vide : `ui_empty_state title: "Aucun échange noté"`, `description: "Notez votre premier appel ou votre première visite."`.
- Ouvrir la fiche marque lues les alertes de l'acteur pour cette école.

### 3.6 Badge d'étape (`teams/relationships/_stage_badge.html.erb`)

| Étape | Libellé | `tone` |
|---|---|---|
| `prospect` | Prospect | `neutral` |
| `demo_done` | Démo faite | `info` |
| `registered` | Inscrite | `brand` |
| `active` | Active | `success` |
| `subscribed` | Abonnée | `gold` |
| `lost` | Perdue | `error` |

`dot: true`. Une étape calculée (`registered`, `active`) porte en plus `title`/texte masqué « calculée d'après l'usage ».

### 3.7 Modale « Noter un échange » (`ui_modal id: "interaction_modal"`)

- Champs (`ui_field`), dans cet ordre : type (`ui_radio_group`, 3 colonnes, 6 choix avec icône), date et heure (`datetime-local`, défaut maintenant), interlocuteur (texte, ≤ 120), fonction (texte, ≤ 80, suggestions `datalist` : Directeur, Directrice des études, Censeur, Enseignant, Fondateur), résultat (`ui_radio_group`, 4 choix), note (textarea 5 lignes, ≤ 4 000, compteur), case « Planifier une relance » qui révèle date + note (Stimulus `reveal` existant).
- Envoi : `POST /teams/schools/:school_id/interactions`, `data-turbo-frame` absent ; réponse Turbo Stream : `prepend` dans `#relationship_journal`, `replace` de `#relationship_follow_ups` si relance, fermeture de la modale, `ui_toast` « Échange noté ».
- Erreur de validation : 422, la modale est re-rendue avec les erreurs sous chaque champ (`aria-describedby`, `aria-invalid="true"`), focus sur le premier champ en erreur.
- Bouton « Enregistrer » désactivé pendant l'envoi (`data-turbo-submits-with="Enregistrement…"`).

### 3.8 Modales « Changer l'étape », « Changer le responsable », « Planifier une relance »

- Étape : `ui_radio_group` de Prospect, Démo faite, Abonnée, Perdue seulement (jamais Inscrite ni Active) ; le choix Perdue révèle un sélecteur de motif obligatoire. Réponse : `replace` de `#relationship_header`, `prepend` de la trace au journal.
- Responsable : sélecteur des membres `admin`/`field` non anonymisés + « Aucun ». Réponse identique.
- Relance : date (défaut J+7, min. aujourd'hui), destinataire (défaut le responsable, sinon soi), note (≤ 500).

### 3.9 États obligatoires

| Surface | Vide | Chargement | Erreur | Succès |
|---|---|---|---|---|
| File « À relancer » | `ui_empty_state title: "Rien à relancer aujourd'hui"`, icône `check-circle` | navigation Turbo standard (barre de progression) | `ui_error_state` avec « Réessayer » (lien vers l'URL courante) | liste |
| « Toutes » | sans filtre : « Aucune école suivie » ; avec filtre : « Aucune école ne correspond », lien « Effacer les filtres » | idem | idem | liste paginée |
| Fiche | voir §3.5 (journal, relances) | — | 404 si école inconnue | fiche |
| Modales | — | bouton désactivé « Enregistrement… » | 422 re-rendu ; 403 → `ui_toast type: :error` « Vous ne pouvez pas faire ce changement » | toast + streams |

### 3.10 Accessibilité

- Cibles ≥ 48×48 px (`min-h-tap`), y compris les boutons icône des relances.
- Onglets : `ui_tabs` (WAI-ARIA, flèches). Badges : le texte porte l'information, jamais la couleur seule.
- Journal : `<ol aria-label="Journal de l'école">`, chaque entrée `<li>` avec `<time datetime>`.
- Toast : `role="status"` (succès), `role="alert"` (erreur). Focus rendu au bouton d'ouverture à la fermeture d'une modale.
- Toute la page à 390 px sans défilement horizontal ; le tableau « Toutes » n'existe qu'à partir de 768 px.

### 3.11 Textes

Tous dans `config/locales/fr.yml` sous `teams.follow_ups.*`, `teams.relationships.*`, `teams.interactions.*`, `school_relationship_stages.*`, `school_interaction_kinds.*`, `school_interaction_outcomes.*`, `school_lost_reasons.*`. Toujours `t(".key")` dans les vues.

## 4. Conséquences

- La barre basse de `admin` et `field` change : « Pilotage » passe dans « Plus » si nécessaire (§3.1).
- La fiche d'établissement existante gagne un seul lien « Suivi de l'école » dans son en-tête ; rien d'autre n'y bouge.
- Tout futur écran de relation (agents IA, V2 kanban) part de la fiche de suivi et réutilise le badge d'étape §3.6.
