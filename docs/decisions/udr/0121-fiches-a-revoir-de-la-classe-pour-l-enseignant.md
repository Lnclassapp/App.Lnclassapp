# UDR-0121 : Fiches à revoir de la classe — un bloc sur la page de la classe, les noms sur la fiche vue depuis la classe
<!-- index
titre: Fiches à revoir de la classe, pour l'enseignant
statut: Accepté
adr-lie: [0101](../adr/0101-remediation-implicite-exercice-propose-et-lecture-enseignant.md), [0043](../adr/0043-remediation-declenchee-par-la-cloture.md), [0079](../adr/0079-lecture-de-la-comprehension-d-un-exercice-assigne.md)
problematique: L'enseignant ne voit aucune lacune. Page de classe : bloc `#classroom_gaps` (fiche, nombre d'élèves à revoir, 3 lignes puis « Voir plus »). Fiche dans la classe : section `#classroom_essential_gaps` « Élèves à revoir » et « Fiche levée ». Amende UDR-0027 et UDR-0029.
-->

| | |
|---|---|
| **Statut** | Accepté (2026-10-16, porteur : recommandations Q1 à Q12 acceptées) |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/remediation-ciblee`](../../chantiers/remediation-ciblee/memo.md) — Lot C, AS-17 |
| **ADR lié** | [ADR-0101](../adr/0101-remediation-implicite-exercice-propose-et-lecture-enseignant.md) §4.4 · [ADR-0041](../adr/0041-vie-d-une-classe-annee-scolaire-et-code.md) (année scolaire) · [ADR-0072](../adr/0072-assignation-d-exercices-et-echeance-a-la-prochaine-seance.md) §4.5 (pas de noms pour la direction) |
| **Amende** | [UDR-0027](0027-page-classe.md) (un bloc de plus) · [UDR-0029](0029-fiche-essentielle-dans-la-classe.md) (une section de plus) |
| **Remplacé par** | — |

---

## 1. Contexte

L'enseignant prépare sa prochaine séance depuis la page de sa classe : jours de séance, cours, exercices assignés, élèves (UDR-0027, UDR-0077 §3.4). Il ne voit nulle part quels élèves ont une fiche à revoir ni qui l'a levée, alors que l'application le sait depuis la V1. L'ancienne application avait une pastille « N en difficulté / N résolus » par exercice, qui levait une `NameError`. Et la lacune porte sur la fiche, pas sur l'exercice.

## 2. Décision

1. **Deux niveaux, deux pages existantes.** La page de la classe dit **où** (quelles fiches, combien d'élèves). La fiche vue depuis la classe dit **qui** (les noms). On n'ajoute pas de page.
2. **Pas de pastille par exercice** : la lacune est une affaire de fiche (ADR-0043), et la page de suivi d'un exercice assigné (UDR-0072) reste inchangée.
3. **Deux groupes seulement**, « Élèves à revoir » et « Fiche levée ». On ne distingue pas « corrigé seul » de « remédiation réussie » (ADR-0101 §4.4).
4. **Le compte d'échecs s'affiche dès 2** : il signale l'élève qui bloque, sans charger la ligne de celui qui a raté une fois.
5. **Le bloc est absent s'il est vide.** On n'affiche pas d'état vide « aucune fiche à revoir » sur la page de classe, déjà longue.

## 3. Règles d'implémentation

### 3.1 Page de la classe — bloc `#classroom_gaps`

**Structure** — nouveau partial `app/views/classroom/classrooms/_gaps.html.erb`, `locals: (classroom:, gaps:)`. Dans `classrooms/show.html.erb`, il est rendu **après** `_assigned_exercises` et **avant** `_roster`, si `@gaps.present?`. `@gaps` vaut `nil` sans `show_roster`.

```erb
<%= tag.section id: "classroom_gaps", "aria-labelledby": "classroom_gaps_title", class: "min-w-0", data: ui_reveal_data do %>
  <h2 id="classroom_gaps_title" class="font-display text-xl font-extrabold"><%= t(".title") %></h2>
  <p class="mt-1 mb-4 text-sm text-mute"><%= t(".subtitle") %></p>
  <ul class="divide-y divide-line rounded-card border border-line bg-white shadow-card" data-turbo-prefetch="false">
    <%# une li par fiche, ui_reveal_item(index) : 3 visibles, la suite en hidden %>
  </ul>
  <div class="mt-3"><%= ui_reveal_more gaps.size %></div>
<% end %>
```

- **Ligne** : `li.relative.flex.items-center.gap-3.px-4.py-4.hover:bg-mist.sm:px-5`, qui contient :
  - `ui_icon "light-bulb", size: :md, class: "text-warning"` ;
  - `div.min-w-0.flex-1` avec un `link_to gap.essential_name, classroom_essential_path(classroom.public_id, gap.course_slug, gap.essential_slug), class: "block truncate font-medium text-ink after:absolute after:inset-0 focus-visible:outline-2 focus-visible:outline-brand"` ;
  - `ui_badge t(".students", count: gap.pending_count), tone: :warning, size: :sm` ;
  - `ui_icon "chevron-right", variant: :mini, size: :sm, class: "text-mute"`.
- **Ordre** : celui de la query (`pending_count` décroissant, puis nom de la fiche).
- **Fiches** : celles des cours de `@overview.courses` (ADR-0101 §4.4). Le contrôleur passe leurs slugs à `ClassroomGapsQuery#summary`.

**Textes** (`config/locales/classroom/classrooms.fr.yml`, `classroom.classrooms.gaps`)

| Clé | Texte |
|---|---|
| `title` | « Fiches à revoir » |
| `subtitle` | « Des élèves ont eu moins de 10/20 sur ces fiches et ne les ont pas encore levées. » |
| `students` | one : « 1 élève » · other : « %{count} élèves » |

### 3.2 Fiche vue depuis la classe — section `#classroom_essential_gaps`

**Structure** — nouveau partial `app/views/classroom/classroom_essentials/_gaps.html.erb`, `locals: (detail:)`. Dans `classroom_essentials/show.html.erb`, il est rendu **entre** la carte d'en-tête et `#classroom_essential_exercises`, si `@gaps` existe et que `@gaps.pending` ou `@gaps.lifted` n'est pas vide.

```erb
<section id="classroom_essential_gaps" aria-labelledby="classroom_essential_gaps_title" class="mb-8">
  <h2 id="classroom_essential_gaps_title" class="mb-4 font-display text-xl font-extrabold"><%= t(".title") %></h2>
  <div class="grid grid-cols-1 gap-4 lg:grid-cols-2">
    <%# carte « Élèves à revoir », puis carte « Fiche levée » ; une carte vide n'est pas rendue %>
  </div>
</section>
```

- **Carte « Élèves à revoir »** : `ui_card title: t(".pending_title"), icon: "light-bulb", id: "classroom_essential_gaps_pending"`, avec `card.actions { ui_badge pending.size, tone: :warning, size: :sm }`. Elle contient un `ul.divide-y.divide-line` dans un conteneur `ui_reveal_data` (3 lignes, limite commune `REVEAL_LIMIT` du composant, puis `ui_reveal_more` ; 5 au cadrage, ramené à 3 à l’exécution, voir le journal du chantier). Chaque `li.flex.flex-wrap.items-baseline.justify-between.gap-x-3.gap-y-1.py-3` contient :
  - `span.font-medium.text-ink` : le nom affiché ;
  - `span.text-sm.text-mute` : `t(".since", date: l(row.opened_on, format: :short))`, puis, si `row.failed_sessions_count >= 2`, ` · ` et `t(".failures", count: row.failed_sessions_count)`.
- **Carte « Fiche levée »** : `ui_card title: t(".lifted_title"), icon: "check-badge", id: "classroom_essential_gaps_lifted"`, avec `card.actions { ui_badge lifted.size, tone: :success, size: :sm }`. Mêmes lignes, sauf le texte de droite : `t(".lifted_on", date: l(row.resolved_on, format: :short))`.
- **Ordre** : « À revoir », de la lacune la plus ancienne à la plus récente (ceux qui attendent depuis longtemps d'abord) ; « Fiche levée », de la plus récente à la plus ancienne.
- **Aucun identifiant d'élève dans le HTML** (comme UDR-0072) : ni `public_id`, ni lien vers un élève.

**Textes** (`config/locales/classroom/classroom_essentials.fr.yml`, `classroom.classroom_essentials.gaps`)

| Clé | Texte |
|---|---|
| `title` | « Fiche à revoir dans la classe » |
| `pending_title` | « Élèves à revoir » |
| `lifted_title` | « Fiche levée » |
| `since` | « depuis le %{date} » |
| `failures` | other : « %{count} sessions sous la moyenne » (« essai » est interdit par l’UDR-0007 ; corrigé à l’exécution) |
| `lifted_on` | « le %{date} » |

### 3.3 Commun

**Tokens** — design system seulement : `text-warning`, `ui_badge tone: :warning | :success`, `text-mute`, `text-ink`, `divide-line`, `rounded-card`, `shadow-card`, `bg-mist` au survol. Aucune couleur en dur.

**Comportement**
- Rendu serveur, sans frame et sans Stimulus, en dehors du contrôleur `reveal` existant (« Voir plus » sans requête).
- `data-turbo-prefetch="false"` sur la liste du bloc : la page de la fiche dans la classe n'est pas préchargée au survol.
- Classe archivée : même affichage (lecture), avec les lacunes levées de l'année de la classe.

**États obligatoires**
- Aucune lacune : bloc et section absents.
- Seulement des levées (fiche dans la classe) : la carte « Fiche levée » seule, sur toute la largeur.
- Lecteur sans `show_roster` : rien n'est lu, rien n'est rendu (la page est de toute façon refusée à l'élève et à la direction).

**Accessibilité**
- Chaque ligne du bloc est un lien unique, avec une cible ≥ 48 px (`py-4` sur une ligne).
- Le badge du bloc porte un texte complet (« 2 élèves ») ; dans les cartes, le nombre seul suit le titre de la carte dans l'ordre de lecture (`ui_card` place `actions` après le titre), sans attribut ARIA de plus.
- Contraste AA en clair et en sombre (tokens redéfinis en sombre).
- À 390 px : une colonne, sans défilement horizontal ; nom et date passent à la ligne (`flex-wrap`).

## 4. Conséquences

- L'ordre de la page de classe (UDR-0077 §3.4) devient : jours de séance, cours, exercices assignés, **fiches à revoir**, élèves.
- La fiche dans la classe (UDR-0029) gagne une section au-dessus de ses exercices. L'enseignant y voit qui aider **avant** de choisir quoi assigner.
- La fiche d'un élève (CL-13, `rapports-de-classe`) devra reprendre `ClassroomGapsQuery`, sans nouvelle règle.
- La pastille par exercice de l'ancienne application (AS-17) n'est pas reprise.
