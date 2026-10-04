# UDR-0073 : Progrès de l'élève sur le résultat de sa session — une phrase qui dit où il en est et quoi faire ensuite

| | |
|---|---|
| **Statut** | Accepté (2026-10-04, décision déléguée par le porteur) |
| **Date** | 2026-10-04 |
| **Chantier** | [`docs/chantiers/progres-eleve`](../../chantiers/progres-eleve/prd.md) |
| **ADR lié** | [ADR-0079](../adr/0079-lecture-de-la-comprehension-d-un-exercice-assigne.md) (règles du signe) · [ADR-0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md) (note sur 20) |
| **Amende** | [UDR-0023](0023-resultat-de-session.md) (résultat de session) |
| **Remplacé par** | — |

---

## 1. Contexte

L'élève qui recommence un exercice lit sa nouvelle note, mais personne ne lui dit s'il a progressé. Son enseignant le voit, lui non. La mission de Lnclass est d'aider chaque acteur à progresser ; le premier concerné par son progrès est l'élève.

## 2. Décision

1. **Un seul endroit : la carte du résultat**, sous la note, à l'instant où il vient de recommencer (charte §1 : dire chaque chose une seule fois).
2. **Une phrase, pas un signe.** Un élève de 11 ans comprend « Tu progresses : 6/20 à ta première session, 18/20 aujourd'hui » ; il ne déchiffre pas une flèche.
3. **Jamais « stagne » ni « baisse ».** La charte (§5) interdit la sanction. Chaque phrase dit où il en est et **renvoie à la correction**, placée juste en dessous : c'est elle qui fait progresser.
4. **Sur 20**, seule forme de note lue par l'élève (UDR-0023, 2026-10-02).
5. **Pour l'élève seul** : l'enseignant a la page de suivi (UDR-0072).

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Données** — `SessionResultQuery::Row#progress` : `Progress = Data.define(:trend, :first_grade, :best_grade, :current_grade)`, ou `nil`.
- Historique : les sessions de l'élève sur l'exercice, `status = 'completed'`, **`standard` et `remediation`**, dont `(completed_at, id)` est inférieur ou égal à celui de la session affichée, triées par `(completed_at, id)`.
- Moins de deux sessions : `nil`.
- La session affichée est une session de **remédiation** : la phrase s'affiche aussi, avec les mêmes règles. Une remédiation sur un exercice, c'est faire cet exercice. Sous 50 %, une lacune s'ouvre et chaque session suivante de la fiche est une remédiation (ADR-0043) : l'élève qui rate puis réussit ne la fait qu'en remédiation, et c'est ce progrès-là que la mission veut montrer. Les exclure taisait sa phrase et effaçait ses meilleures notes (défauts D1 et D2 du challenger, 2026-10-04 ; remplace la décision du Lot A, qui rendait `nil`).
- `trend = Comprehension.trend_for(scores)` ; `first_grade`, `best_grade`, `current_grade` = `Grading.grade_on_20` du premier, du plus haut et du dernier score (la session affichée).

**Structure** — partiel `app/views/assessment/session_results/_progress.html.erb`, `locals: (progress:)`, rendu dans `show.html.erb` **dans la carte, entre la `dl` des notes et les boutons**, seulement si `@owner && result.progress` :

```
p#session_progress .mt-6.flex.items-start.justify-center.gap-2.text-sm.text-ink.text-balance
  ui_icon (mini, aria-hidden)   texte de la phrase
```

| `trend` | Icône | Couleur de l'icône | Phrase (`assessment.session_results.progress.*`) |
|---|---|---|---|
| `:progress` | `arrow-trending-up` | `text-success` | `progress` : « Tu progresses : %{first}/20 à ta première session, %{current}/20 aujourd'hui. » |
| `:stable` | `check-circle` | `text-success` | `stable` : « Tu confirmes ta maîtrise : %{current}/20. » |
| `:stagnant` | `book-open` | `text-mute` | `stagnant` : « Tu restes autour de %{current}/20. Relis la correction ci-dessous avant de recommencer. » |
| `:decline` | `book-open` | `text-mute` | `decline` : « Ton meilleur résultat reste %{best}/20. Relis la correction, tu peux le retrouver. » |

**Tokens** — `text-ink`, `text-mute`, `text-success` uniquement. **Aucun** `error`, `warning`, `struggling` ni `fragile` sur cette page élève.

**Comportement** — aucun Turbo, aucun Stimulus : texte statique dans la page existante. Les confettis (dès 10/20) et « Recommencer » ne changent pas.

**États obligatoires**
- Premier essai, ou lecteur non propriétaire : le partiel n'est pas rendu ; rien ne bouge dans la carte.
- Chargement, erreur : ceux de la page (inchangés).

**Accessibilité**
- La phrase est du texte : l'icône est `aria-hidden`.
- Contraste : `text-ink` et `text-mute` sur blanc, déjà AA ; mode sombre par les tokens.
- 12 px minimum (charte §4) : `text-sm`.

## 4. Conséquences

- La page de résultat de l'élève parle de progrès, jamais de recul. « En baisse » n'existe que chez l'enseignant.
- Ajouter le progrès ailleurs (accueil, fiche, historique) demandera un amendement de cette UDR, après mesure de l'usage.
