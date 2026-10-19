# UDR-0119 : Fiche à revoir — l'encart propose un exercice choisi, le démarre d'un tap, et donne la règle sur 20
<!-- index
titre: Fiche à revoir : exercice proposé, démarrage direct, règle sur 20
statut: Accepté
adr-lie: [0101](../adr/0101-remediation-implicite-exercice-propose-et-lecture-enseignant.md), [0043](../adr/0043-remediation-declenchee-par-la-cloture.md)
problematique: Encart `#essential_gap` de la fiche (élève) : le bouton mène au premier exercice et la règle se lit en %. Il démarre l'exercice choisi par `RemediationPick`, le nomme, et la règle se lit « 15/20 » ; l'aide aussi. Amende UDR-0015 §2.6 et son amendement R4.
-->

| | |
|---|---|
| **Statut** | Accepté (2026-10-16, porteur : recommandations Q1 à Q12 acceptées) |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/remediation-ciblee`](../../chantiers/remediation-ciblee/memo.md) — Lot A, AS-16 |
| **ADR lié** | [ADR-0101](../adr/0101-remediation-implicite-exercice-propose-et-lecture-enseignant.md) §4.1, §4.2 · [ADR-0043](../adr/0043-remediation-declenchee-par-la-cloture.md) (seuil 75, amendement du 2026-09-27) |
| **Amende** | [UDR-0015](0015-page-fiche-essentielle.md) §2.6 et la ligne « Encart `#essential_gap` » de son amendement (R4) |
| **Remplacé par** | — |

---

## 1. Contexte

Sur la fiche, l'élève qui a une fiche à revoir voit l'encart « Fiche essentielle à revoir ». Son bouton « Refaire un exercice » ouvre la page du **premier** exercice de la liste, souvent celui qu'il vient de rater, et il faut encore toucher « Commencer ». La règle de l'infobulle dit « au moins 75 % », alors que l'élève lit toutes ses notes sur 20 (UDR-0023). L'aide dit « moins de 50 % » et « au moins 75 % ».

## 2. Décision

1. **Le bouton démarre l'exercice proposé**, choisi par `RemediationPick` (ADR-0101 §4.2) : un formulaire POST vers `exercise_sessions_path(<exercice>)`, comme « Commencer ». Une session commencée est reprise. Un tap de moins, et jamais l'exercice raté s'il en existe un autre.
2. **L'exercice proposé est nommé** sous le bouton, pour que l'élève sache ce qu'il va faire.
3. **La règle se lit sur 20** : « 15/20 » et « 10/20 », calculés par `Grading.grade_on_20` à partir des seuils, jamais écrits en dur.
4. **Rien d'autre ne change** dans l'encart : titre, icône, couleurs, date, infobulle. L'accueil (« Fiches essentielles à revoir ») reste tel quel : il mène à la fiche, où l'élève relit avant de refaire.

## 3. Règles d'implémentation

**Structure** — `app/views/catalog/essentials/show.html.erb`, bloc `#essential_gap` existant :
- Inchangés : `section#essential_gap`, l'icône `light-bulb`, le titre `#essential_gap_title` avec son `ui_info_tip`, la date `gap_since`.
- Le `div.pt-2` du bouton est rendu si `gap.exercise` n'est pas `nil` (au lieu de `exercises.any?`). Il contient :
  - `form_with url: exercise_sessions_path(gap.exercise.public_id), method: :post, id: "essential_gap_form"`, qui contient `ui_button t(".gap_action"), type: :submit, variant: :secondary, size: :sm, icon_end: "arrow-right", id: "essential_gap_action"` ;
  - sous le formulaire, `p#essential_gap_exercise.mt-2.text-sm.text-mute` : `t(".gap_exercise", title: gap.exercise.title)`.
- `Queries::Catalog::EssentialDetailQuery::GapRow` devient `Data.define(:public_id, :opened_at, :exercise)`, où `exercise` est un `ExerciseRow` de la même lecture, ou `nil`.

**Textes** (`config/locales/catalog/essentials.fr.yml`, `communication/help.fr.yml`)

| Clé | Texte |
|---|---|
| `catalog.essentials.show.gap_body` | « Relis son contenu, puis obtiens au moins %{grade}/20 à l'un de ses exercices : elle ne sera plus à revoir. » |
| `catalog.essentials.show.gap_action` | « Refaire un exercice » (inchangé) |
| `catalog.essentials.show.gap_exercise` | « Exercice proposé : %{title} » |
| `communication.help.…gaps.answer` | « Quand tu obtiens moins de %{pass}/20 à un exercice, sa fiche essentielle passe « à revoir ». Relis-la, puis obtiens au moins %{remediation}/20 à l'un de ses exercices : elle ne sera plus à revoir. » |

- Les variables `grade`, `pass`, `remediation` reçoivent `Grading.grade_on_20(Grading::REMEDIATION_THRESHOLD)` (15) et `Grading.grade_on_20(Grading::PASS_THRESHOLD)` (10). La vue d'aide (`communication/help/show`) passe ces valeurs au lieu des pourcentages.

**Tokens** — inchangés : `border-warning/30`, `bg-warning-soft`, `text-warning` (icône), `text-mute` (date et exercice proposé), `rounded-card`.

**Comportement**
- Le POST change de page (redirection vers la session, Turbo Drive), comme « Commencer » sur la page de l'exercice. Pas de frame.
- Sans JavaScript : le formulaire fonctionne tel quel.
- Un double tap : l'index partiel de `StartExerciseSession` renvoie la session déjà ouverte (comportement existant).

**États obligatoires**
- Pas de lacune : pas d'encart (inchangé).
- Lacune, aucun exercice publié : encart sans bouton ni exercice proposé.
- Lacune, un seul exercice publié : le bouton propose cet exercice, même s'il est l'exercice raté.
- Exercice proposé déjà commencé : même bouton ; la session est reprise.

**Accessibilité**
- Le bouton reste ≥ 48 px de haut (`ui_button size: :sm` respecte `min-h-tap`).
- `#essential_gap_exercise` est lié au bouton par `aria-describedby="essential_gap_exercise"` sur le `button`.
- L'ordre de tabulation reste titre → infobulle → bouton.

## 4. Conséquences

- La ligne « Encart `#essential_gap` » de l'amendement de l'UDR-0015 (R4) reste vraie pour le titre et l'infobulle ; le bouton et sa cible suivent cette UDR.
- La phrase « Aucun bouton de remédiation en V1 » de l'UDR-0015 §2.6 et la note « Un futur bouton de remédiation (`StartRemediationSession`) » de ses conséquences sont caduques.
- Toute nouvelle mention du seuil de remédiation à l'élève s'écrit sur 20.
