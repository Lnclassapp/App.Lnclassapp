# Journal — Premier exercice : formules des listes et envoi de la copie

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-24 | Une liste dont une proposition est une formule : le menu propose des lettres, les propositions se lisent rendues et lettrées sous la phrase | Une `<option>` n'est que du texte : KaTeX ne peut pas y rendre. Garde le `select` natif d'UDR-0140 (sans JavaScript, plein écran au téléphone) | UDR-0183 |
| 2026-11-24 | Une liste sans formule ne change pas | Le cas courant (« alignés », « parallèles ») se lit déjà dans le menu | — |

## À trancher

- [ ] 2026-11-24 · premier-exercice-formules-soumission · Liste en formule : menu de lettres + propositions rendues dessous, ou cartes à cocher comme un choix unique (le trou de la phrase devient « …… ») ? — appliqué : menu de lettres + propositions rendues ; autres : cartes à cocher ; traduction LaTeX → texte (« ln 7 », « 1/7 ») dans les options ; recommandé : menu de lettres (UDR-0140 garde son menu natif)
- [ ] 2026-11-24 · premier-exercice-formules-soumission · Le symptôme 2 (« on n'arrive pas à soumettre ») n'est pas reproduit seul : sur Staging et en local la copie part. Le porteur a-t-il vu un autre écran, ou un message, en essayant d'envoyer ? — appliqué : traité comme conséquence du 1 ; autres : rouvrir un chantier avec l'exercice exact ; recommandé : le porteur donne le titre de l'exercice si l'envoi bloque encore après fusion

## Retouches

- …

## Ce qui a dérapé

- Le premier essai sur Staging a semblé montrer des choix qui ne se cochent pas : c'était un brouillon `localStorage` restauré et un clic forcé sous la barre collée « Vérifier ma copie ». Rejoué proprement, tout se coche.
- Le conteneur n'avait ni Ruby 3.4.13 ni le pilote de Chrome 158 : compilés et téléchargés à la main (une heure). Les tests système finissent ici sur `* is not a valid URL` au démontage, test existant compris (`question_matching_test`) : propre à ce Chrome, pas au correctif.

## Ce qu'on a appris sur la codebase

**Rapport de cause.**

1. Chaîne : `Assessment::ExerciseSessionsController#show` → `assessment/exercise_sessions/show.html.erb` (carte de question, `data-controller="math"`) → `kinds/_select.html.erb` → `options_for_select(question.answers.map { [ it.content, it.index ] })` → `math_controller.js` → `renderMathInElement` de KaTeX.
2. Cause : `app/views/assessment/exercise_sessions/kinds/_select.html.erb`, lignes 15 et 30 (avant correctif) : le texte de la proposition, formule comprise, devient le libellé d'une `<option>`. Une option n'affiche que du texte, et KaTeX auto-render ignore `option` (`ignoredTags` par défaut) : la formule reste `$\ln 7$`.
3. Trou de test : les tests de liste (`new_kinds_without_javascript_test`, tests de copie) n'utilisent que des mots (« alignés »). Aucun test ne croisait « liste » et « formule ». Le test de reproduction est un test système, car le défaut est le rendu dans le navigateur.

Reformulation sans les mots du symptôme : la vue confiait du LaTeX à un élément qui ne sait afficher que du texte brut.

- `select` est aussi le menu de repli de « relier » et « remettre dans l'ordre » ; caché dès que JavaScript tourne.
- Le parcours « Commencer » (POST `/exercises/:id/sessions`, puis 303) et « Reprendre » (lien) mènent à la même copie : rien de propre au premier exercice dans la copie.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Fiche « Je m'entraîne » : même menu natif avec formules (`catalog/practice_checks/_question.html.erb`) | Autre écran, autre style (cahier) | à ouvrir : `fiche-listes-formules` |
| Formule coupée par une case (`$A_7^3 = ___$`, 115 questions `fill_blank`) : LaTeX brut autour du champ | Autre cause (le champ coupe la formule), demande une règle de contenu ou un rendu en deux morceaux | à ouvrir : `formule-coupee-par-une-case` |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-11-24 |
| **PR** | #700 |
| **ADR produits** | — |
| **UDR produits** | UDR-0183 |
