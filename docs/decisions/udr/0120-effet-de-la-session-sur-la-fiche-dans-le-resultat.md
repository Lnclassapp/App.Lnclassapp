# UDR-0120 : Résultat d'une session — une ligne dit à l'élève ce qu'il advient de sa fiche : à revoir, levée, ou encore à revoir
<!-- index
titre: Effet de la session sur la fiche, dans le résultat
statut: Accepté
adr-lie: [0101](../adr/0101-remediation-implicite-exercice-propose-et-lecture-enseignant.md), [0043](../adr/0043-remediation-declenchee-par-la-cloture.md)
problematique: Le résultat ne dit jamais qu'une fiche passe à revoir ni qu'elle est levée, et 14/20 donne des confettis sans lever la fiche. Une ligne `#session_gap_outcome` sous la phrase de progrès, élève seul. Amende UDR-0087 §3.6 (ordre des blocs).
-->

| | |
|---|---|
| **Statut** | Accepté (2026-10-16, porteur : recommandations Q1 à Q12 acceptées) |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/remediation-ciblee`](../../chantiers/remediation-ciblee/memo.md) — Lot B, AS-16 |
| **ADR lié** | [ADR-0101](../adr/0101-remediation-implicite-exercice-propose-et-lecture-enseignant.md) §4.3 · [ADR-0043](../adr/0043-remediation-declenchee-par-la-cloture.md) (seuils 50 et 75) |
| **Amende** | [UDR-0087](0087-parcours-d-exercice-eleve-mode-concentre-et-nouveaux-types-de-questions.md) §3.6 (colonne de gauche du résultat : un bloc de plus) |
| **Remplacé par** | — |

---

## 1. Contexte

L'élève apprend qu'une fiche est « à revoir » sur son accueil, plus tard, sans savoir quelle session l'a ouverte. Quand il la lève, rien ne le félicite. Et à 14/20, le résultat titre « Félicitations ! » avec des confettis (UDR-0087 §3.6, seuil de 70 %), alors que la fiche ne se lève qu'à 15/20 (75 %, amendement de l'ADR-0043) : il croit avoir réussi, et la fiche reste sur son accueil.

## 2. Décision

1. **Une ligne, trois messages**, selon `GapOutcome` (ADR-0101 §4.3) :
   - `:opened` → « Cette fiche passe à revoir. »
   - `:lifted` → « Fiche levée ! »
   - `:still_pending` → « Encore à revoir. »
   - `nil` → rien.
   Chaque message est suivi de sa consigne, et la fiche est nommée.
2. **Élève seul** (`@owner`), comme la phrase de progrès (UDR-0073). L'enseignant et l'équipe lisent les lacunes sur leurs pages de classe (UDR-0121).
3. **Titre et confettis inchangés.** 14/20 reste une réussite de l'exercice ; la ligne dit seulement qu'il manque un point pour la fiche. On ne touche pas au barème des titres.
4. **Sous la phrase de progrès**, avant les boutons : l'élève lit sa note, puis son progrès, puis l'effet sur sa fiche, puis ce qu'il peut faire.

## 3. Règles d'implémentation

**Structure** — nouveau partial `app/views/assessment/session_results/_gap_outcome.html.erb`, `locals: (outcome:, essential:)`, rendu dans `show.html.erb` après le bloc `_progress` :

```erb
<% if @owner && result.gap_outcome %>
  <%= render "assessment/session_results/gap_outcome", outcome: result.gap_outcome, essential: result.essential %>
<% end %>
```

- Racine : `div#session_gap_outcome.flex.items-start.gap-3.rounded-card.px-4.py-4.text-sm.text-ink`, avec le fond selon l'effet (tableau ci-dessous).
- Icône `ui_icon …, variant: :mini, size: :sm, class: "mt-0.5 …"`, puis un `div.min-w-0.space-y-1` contenant :
  - `p.font-bold` : le message ;
  - `p` : la consigne ;
  - pour `:opened` et `:still_pending` seulement, un lien `link_to t(".open_essential"), course_essential_path(essential.course_slug, essential.slug), class: "font-medium text-brand underline-offset-2 hover:underline focus-visible:outline-2 focus-visible:outline-brand"`.
- `Queries::Assessment::SessionResultQuery::Row` gagne `gap_outcome` (symbole ou `nil`), calculé par `GapOutcome` après **une** lecture de `knowledge_gaps` (ADR-0101 §6).

**Tokens et textes** (`config/locales/assessment/session_results.fr.yml`, clé `assessment.session_results.gap_outcome`)

| Effet | Fond | Icône (couleur) | Message | Consigne |
|---|---|---|---|---|
| `:opened` | `bg-warning-soft` | `light-bulb` (`text-warning`) | « Cette fiche passe à revoir. » | « Relis « %{essential} », puis obtiens au moins %{grade}/20 à l'un de ses exercices. » |
| `:still_pending` | `bg-warning-soft` | `light-bulb` (`text-warning`) | « Encore à revoir. » | « Pour lever « %{essential} », vise au moins %{grade}/20. » |
| `:lifted` | `bg-success-soft` | `check-badge` (`text-success`) | « Fiche levée ! » | « « %{essential} » n'est plus à revoir. » |

- `open_essential` : « Revoir la fiche ».
- `grade` = `Grading.grade_on_20(Grading::REMEDIATION_THRESHOLD)`.
- Aucune couleur en dur ; aucun pourcentage dans les textes de l'élève.

**Comportement**
- Rendu serveur, sans Stimulus, sans frame. Le résultat n'a pas de cache (UDR-0087), donc la ligne suit toujours l'état en base.
- La ligne n'entre pas dans l'animation `reveal` de la correction.

**États obligatoires**
- `nil` (pas de lacune liée à cette session, ou fiche levée par une autre session) : rien n'est rendu, aucun espace réservé.
- Lecteur enseignant ou équipe : rien n'est rendu.
- Session à 20/20 qui lève la fiche : « Fiche levée ! », et pas de « Recommencer » (inchangé).

**Accessibilité**
- Le message est du texte, et pas seulement une couleur : les trois états se distinguent sans le fond.
- Contraste AA en clair et en sombre : `text-ink` sur `bg-warning-soft` et `bg-success-soft` (tokens du design system, redéfinis en sombre).
- Le lien a une cible ≥ 48 px de haut (`min-h-tap inline-flex items-center`).
- Pas de `role="alert"` : la ligne est lue dans l'ordre de la page.

## 4. Conséquences

- L'ordre de la colonne de gauche du résultat (UDR-0087 §3.6) devient : note et badge, phrase de progrès, effet sur la fiche, boutons.
- Tout autre message lié à la fiche sur le résultat passe par ce partial ; on n'en ajoute pas ailleurs sur la page.
- Les tests système qui comptent les blocs de la colonne de gauche doivent tenir compte de ce bloc conditionnel.
