# UDR-0185 : Premier exercice — la fenêtre sur l'accueil seulement, la réponse en nombre refusée sous le champ
<!-- index
titre: Premier exercice : fenêtre sur l'accueil seulement, nombre illisible dit sous le champ
statut: Accepté
adr-lie: —
problematique: la fenêtre « Ton premier exercice » suivait l'élève sur chaque écran, et une réponse en nombre illisible était comptée « sans réponse » puis refusée par une bulle hors de vue
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-25 |
| **Chantier** | `docs/chantiers/premier-exercice-ux` |
| **ADR lié** | — |
| **Amende** | UDR-0179 §3.2 (où s'ouvre la fenêtre, ce que vaut « Plus tard ») · UDR-0087 §3.4 (comment se dit le refus d'une saisie illisible) |
| **Remplacé par** | — |

---

## 1. Contexte

Le porteur, en testant le premier exercice : la fenêtre « Ton premier exercice » revenait sur chaque écran (accueil, Ma classe, historique, cours, aide) tant qu'aucune copie n'était rendue, « Plus tard » ne valant que pour la page. Dans la copie, « x = 8 » dans une réponse en nombre n'était pas compté, « Vérifier ma copie » parlait d'une question sans réponse à un élève qui avait tout rempli, puis la bulle du navigateur s'affichait sous l'en-tête, loin du champ.

## 2. Décision

- La fenêtre est une invitation, pas une barrière : elle s'ouvre sur l'accueil, l'écran où l'élève choisit quoi faire, et « Plus tard » est cru pour toute la visite. Une copie rendue la clôt toujours pour de bon (UDR-0179 §3.2, inchangé).
- Le refus d'une saisie illisible reste (UDR-0087 §3.4, ADR-0091 §4.3) mais se dit là où l'élève regarde : sous le champ. À l'envoi, une saisie illisible passe avant toute question vide : l'élève est ramené au champ, sans dialogue ni bulle du navigateur.

## 3. Règles d'implémentation

### 3.1 La fenêtre « Ton premier exercice »

**Structure**
- `layouts/shell` ne pose le cadre `student_first_exercise_prompt` que si la vue le demande : `content_for?(:first_exercise_prompt)`, hors mode concentré, et `first_exercise_prompt?` (élève, sans `session[:first_exercise_done]`).
- Seul `classroom/student_homes/show` pose `content_for :first_exercise_prompt, true`. `content_for :no_first_exercise_prompt` disparaît (sans objet).

**Comportement**
- Le cadre porte `classroom--first-exercise-prompt` : `turbo:frame-missing` → cadre vide (inchangé) ; `turbo:before-frame-render` → si `sessionStorage["lnclass:first-exercise-later"] == "1"`, `event.detail.render` ne fait rien. Le cadre se charge quand même : le serveur pose le drapeau de session dès qu'une copie est rendue.
- La fermeture de `#student_first_exercise_modal` (« Plus tard », croix, Échap : l'événement `close`, écouté en capture sur le cadre) pose ce drapeau. « Commencer » quitte la page sans le poser.
- Stockage refusé : la fenêtre revient au prochain passage sur l'accueil.

### 3.2 Réponse en nombre illisible

**Structure**
- Sous le champ de `kinds/_numeric` (une case), avant l'aide : `<p id="q<n>-numeric-error" class="text-sm font-medium text-error" hidden>` avec `assessment.exercise_sessions.kinds.numeric.invalid` = « Écris seulement le nombre, par exemple 8 ou -3,5. »

**Comportement**
- `assessment--numeric` : `validate` (à chaque saisie) garde `setCustomValidity` et cache le message dès que la saisie est lisible ; `reveal` (sortie du champ, événement `invalid`) montre le message si la saisie est illisible, et annule la bulle du navigateur.
- `lib/assessment/copy_sheet` pose `noValidate` sur `form#copy-form` (sans JavaScript, rien ne change). À l'envoi, le premier champ illisible arrête tout : `preventDefault`, `checkValidity()` (le champ écrit son message), défilement au centre, focus. Le dialogue « sans réponse » ne vient qu'après.
- Le compteur ne compte toujours pas une saisie illisible (`validity.valid`, sans événement).

**Accessibilité**
- Message montré : `aria-invalid="true"` sur le champ, l'id du message en tête de son `aria-describedby` ; caché : les deux retirés.

## 4. Conséquences

- Les écrans Ma classe, historique, cours, fiches, aide n'ont plus la fenêtre. La bannière d'installation de l'accueil reste soumise à `first_exercise_prompt?` (jamais deux fenêtres).
- Tests système : `ApplicationSystemTestCase#before_teardown` vide le `sessionStorage` de l'onglet, que la remise à zéro de Capybara ne vide pas.
