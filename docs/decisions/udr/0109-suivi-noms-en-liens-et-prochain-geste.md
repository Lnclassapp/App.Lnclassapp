# UDR-0109 : Page de suivi d'un exercice assigné — les noms mènent à la fiche, une phrase « prochain geste » en tête de la compréhension
<!-- index
titre: Suivi : noms en liens, prochain geste
statut: Proposé
adr-lie: [0097](../adr/0097-fiche-d-un-eleve-dans-sa-classe.md)
problematique: Page de suivi, enseignant et équipe : chaque nom (élèves d'une catégorie, rendus en retard, pas encore faits) devient un lien vers la fiche de l'élève (UDR-0107), hors du Turbo Frame des catégories ; une phrase « Prochain geste » choisie par Entities::Assessment::NextStep remplace l'avertissement « pas encore fiable » dans la carte du grand cercle. Amende UDR-0072 §3.5 et §3.5 bis (identifiants d'élève dans le HTML)
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/rapports-de-classe`](../../chantiers/rapports-de-classe/prd.md) |
| **ADR lié** | [ADR-0097](../adr/0097-fiche-d-un-eleve-dans-sa-classe.md) §4.6 (règle du prochain geste), §4.9 (identifiants) · [ADR-0079](../adr/0079-lecture-de-la-comprehension-d-un-exercice-assigne.md) |
| **Amende** | [UDR-0072](0072-comprehension-d-un-exercice-assigne.md) §3.5 (élèves d'une catégorie, « les lignes ne sont pas des liens ») et §3.5 bis (« aucun identifiant d'élève dans le HTML ») |
| **Remplacé par** | — |

---

## 1. Contexte

La page de suivi d'un exercice assigné nomme trois listes d'élèves : ceux d'une catégorie (avec meilleur score et signe), les rendus en retard, et les pas encore faits. L'enseignant y voit qui est en baisse ou qui n'a rien rendu, mais ne peut pas aller plus loin : les lignes ne sont pas des liens, faute de fiche. La section « Compréhension » lit la classe sans proposer de geste ; l'ancien rapport finissait par un message (AS-23), fait de phrases en dur.

## 2. Décision

1. **Chaque nom mène à la fiche de l'élève dans cette classe.** C'est la suite naturelle de « qui relancer » (ADR-0079 §4.8).
2. **Une phrase, dans la carte du grand cercle**, sous la synthèse des signes : le prochain geste. Elle se lit avec la couleur de la classe, avant les catégories. Pas de carte de plus, pas de bloc « Pour vous » en bas de page.
3. **Elle remplace l'avertissement « pas encore fiable »** quand la lecture n'est pas fiable : la phrase dit déjà qu'elle le sera à partir de 5 (charte §1, dire chaque chose une seule fois).

## 3. Règles d'implémentation

> Contrat d'exécution. Fichiers : `app/views/assessment/comprehension/_section.html.erb` et `app/views/classroom/assignment_follow_ups/show.html.erb`. Locales : `config/locales/assessment/comprehension.fr.yml` (Lot 0).

### 3.1 Noms en liens

Pour les trois listes, le nom (aujourd'hui un `span` ou le texte de la `li`) devient :

`link_to student.display_name, classroom_student_path(classroom.public_id, student.public_id), data: { turbo_frame: "_top" }, class: "min-w-0 truncate font-medium text-ink underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-brand"`

- **`turbo_frame: "_top"` est obligatoire** dans la liste d'une catégorie : elle vit dans le cadre `comprehension_frame`, et un lien sans cible chargerait la fiche dans le cadre.
- Seul le nom est un lien ; le score, le signe et la date restent du texte à droite.
- La `li` garde ses classes ; elle gagne `py-3` déjà présent, assez pour une cible de 48 px.
- Les `Data` lues (`ComprehensionDetailQuery::StudentRow`, `AssignmentFollowUpQuery::LateStudent`, `PendingStudent`) portent `public_id` (ADR-0097 §4.9, Lot 0).

### 3.2 Prochain geste

Dans la première `ui_card` de la section (celle du grand cercle), **à la place** du paragraphe `assessment.comprehension.unreliable` :

```erb
<% step = Entities::Assessment::NextStep.for(done: comprehension.done, pending: comprehension.present - comprehension.done,
                                               readable: comprehension.readable, dominant: comprehension.category,
                                               decline: comprehension.trend_counts.fetch(:decline)) %>
<% if step %>
  <p id="comprehension_next_step" class="mt-4 flex items-start gap-2 border-t border-line pt-4 text-sm text-ink">
    <%= ui_icon "light-bulb", variant: :mini, size: :sm, class: "mt-0.5 shrink-0 text-brand-strong" %>
    <span><span class="font-semibold"><%= t("assessment.comprehension.next_step.label") %></span>
      <%= t("assessment.comprehension.next_step.#{step}", count: …, min: Entities::Assessment::Comprehension::MIN_DONE_FOR_READING) %></span>
  </p>
<% end %>
```

- `count` vaut `pending` pour `:remind`, `decline` pour `:watch_decline` ; il n'est pas passé aux autres clés.
- Le calcul se fait dans la vue par l'appel au domaine, ou dans un helper `comprehension_next_step(comprehension)` de `Assessment::ComprehensionHelper` : la vue ne contient aucune condition sur les cas.
- `pending` se calcule sur `present - done`, la même soustraction que les comptes existants.
- L'icône est `aria-hidden` (par défaut de `ui_icon`) ; le libellé « Prochain geste : » est du texte.
- Le paragraphe est rendu dans le cadre `comprehension_frame` : il reste identique quelle que soit la catégorie choisie.

### 3.3 Libellés — `assessment.comprehension.next_step` (Lot 0)

| Clé | Texte |
|---|---|
| `label` | « Prochain geste : » |
| `remind` | one : « Relancez l'élève qui ne l'a pas encore fait : la lecture de la classe sera fiable à partir de %{min}. » ; other : « Relancez les %{count} élèves qui ne l'ont pas encore fait : la lecture de la classe sera fiable à partir de %{min}. » |
| `look_at_each` | « Tous les élèves l'ont fait. La classe est trop petite pour une tendance : regardez chaque élève. » |
| `revisit_notion` | « La plupart des élèves sont en difficulté : reprenez la notion avant d'avancer. » |
| `revisit_questions` | « La notion se met en place : reprenez en classe les questions marquées, puis avancez. » |
| `watch_decline` | one : « La classe a compris. Un élève est en baisse : voyez-le dans sa catégorie. » ; other : « La classe a compris. %{count} élèves sont en baisse : voyez-les dans leur catégorie. » |
| `move_on` | « La classe a compris : vous pouvez avancer. » |

Vocabulaire vérifié par `locale_files_test` : « session », jamais « essai » (UDR-0007). La clé `unreliable` n'est plus lue par la section : la supprimer si rien d'autre ne la lit.

### 3.4 États obligatoires

| État | Rendu |
|---|---|
| **Vide** (0 fait) | inchangé : l'état vide de la section, aucun prochain geste |
| **Non lisible** (1 à 4 faits) | cercle gris, phrase `:remind` ou `:look_at_each` à la place de l'avertissement |
| **Lisible** | phrase selon la dominante et les élèves en baisse |
| **Chargement** | inchangé (`aria-busy` du cadre) |
| **Erreur** | inchangé : 403, 404 |
| **Classe archivée** | inchangé, tout reste lisible ; les liens vers la fiche répondent 404 (la fiche suit la page de la classe, ADR-0088) : **les noms ne sont pas des liens** quand la classe est archivée |

### 3.5 Accessibilité

- Les liens ont pour nom le nom de l'élève ; dans une même liste, deux homonymes restent distinguables par leur position (comme aujourd'hui).
- Focus visible sur chaque lien ; aucun lien imbriqué.
- Couleur jamais seule : la phrase ne repose sur aucune couleur.

## 4. Conséquences

- Le `public_id` de l'élève apparaît dans le HTML de la page de suivi. Il n'est pas un secret (ADR-0029) et la page reste sous `FollowAssignmentPolicy`.
- La phrase change avec la lecture de la classe : un enseignant qui revient après de nouveaux rendus voit un autre geste.
- Le test système existant `classroom_page_test.rb` qui lit les noms en texte doit viser le lien (sélecteur ou `assert_link`).
- Interdit désormais : une phrase à l'enseignant écrite dans la vue, ou choisie hors du domaine.
