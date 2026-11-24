# UDR-XXXX : Choix dans une liste dont une proposition est une formule
<!-- index
titre: Liste en formule — lettres dans le menu, propositions rendues
statut: Accepté
adr-lie: [0051](../adr/0051-navigateurs-supportes-et-budget-de-poids.md)
problematique: une option de menu natif ne peut pas rendre une formule KaTeX, l'élève lisait du LaTeX brut
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-24 |
| **Chantier** | `docs/chantiers/premier-exercice-formules-soumission` |
| **ADR lié** | ADR-0051 |
| **Remplacé par** | — |

---

## 1. Contexte

UDR-0140 §3 fait du choix dans une liste un `select` natif. Une option n'affiche que du texte : une proposition `$\ln 7$` s'y lisait en LaTeX brut, et l'élève ne pouvait ni comprendre ni choisir (signalement du porteur, 2026-11-24, sur le premier exercice).

## 2. Décision

Quand au moins une proposition d'une liste contient une formule (`$`), le menu propose les **lettres** A, B, C…, et les propositions se lisent **rendues et lettrées** sous la phrase. Le menu reste natif (sans JavaScript, plein écran au téléphone, lecteur d'écran), comme le veut UDR-0140. Une liste sans formule ne change pas. Écarté : traduire le LaTeX en texte dans l'option (illisible dès une fraction ou un ensemble) ; remplacer le menu par des cartes à cocher (contredit UDR-0140).

## 3. Règles d'implémentation

**Structure**
- `app/views/assessment/exercise_sessions/kinds/_select.html.erb` : `lettered` vrai si une proposition contient `$` ; libellé d'option = lettre, valeur = indice d'affichage (inchangée).
- `kinds/_select_propositions.html.erb` : sous la phrase (ou sous le menu), une consigne `text-sm text-mute`, puis une `ol` en grille (`sm:grid-cols-2`) ; chaque `li` porte la pastille de lettre et la proposition, et `data-option-value` = la valeur de l'option.
- Plusieurs cases : une liste par case, consigne « Les propositions de la case n ».

**Tokens**
- `rounded-ln border border-line bg-white`, pastille `size-8 rounded-full border-line bg-paper` ; formule large : défilement horizontal dans sa carte.

**Comportement**
- Les formules sont rendues par le contrôleur `math` de la carte de question. Aucun contrôleur nouveau.

**Accessibilité**
- Chaque ligne fait au moins `min-h-tap`. La lettre est lue avec la proposition ; la liste porte un `aria-label`.

## 4. Conséquences

Toute nouvelle vue qui met une proposition dans une `<option>` applique la même règle. La fiche « Je m'entraîne » suit en chantier de suivi.
