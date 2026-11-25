# Journal — Premier exercice : la fenêtre qui suit partout, la réponse en nombre refusée sans le dire

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-25 | La fenêtre ne s'ouvre que sur l'accueil ; « Plus tard » ou Échap la taisent jusqu'à la fin de la visite (onglet). | Le porteur la trouve envahissante ; l'accueil est l'écran où l'élève choisit quoi faire. | Non — UDR-0185 §3.1 |
| 2026-11-25 | Une saisie illisible se dit sous le champ ; l'envoi ramène au champ avant tout dialogue « sans réponse ». La copie juge elle-même à l'envoi (`noValidate` posé par JavaScript). | La bulle du navigateur s'affichait hors de vue et le dialogue parlait de « question sans réponse » à un élève qui avait répondu. | Non — UDR-0185 §3.2 |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-25 · premier-exercice-ux · Où s'ouvre la fenêtre « Ton premier exercice » ? — appliqué : accueil seulement ; autres : accueil et Cours ; partout (UDR-0179 §3.2 d'origine) ; recommandé : accueil seulement
- [ ] 2026-11-25 · premier-exercice-ux · Combien de temps « Plus tard » la tait-il ? — appliqué : jusqu'à la fin de la visite (onglet, `sessionStorage`) ; autres : la page seule (avant) ; un jour ; pour de bon ; recommandé : la visite
- [ ] 2026-11-25 · premier-exercice-ux · Libellé du refus d'un nombre — appliqué : « Écris seulement le nombre, par exemple 8 ou -3,5. » ; autres : l'ancien « Écris un nombre, par exemple -3,5. » ; recommandé : le nouveau
- [ ] 2026-11-25 · premier-exercice-ux · Le challenger a rejoué en local (captures 390 px et ordinateur), pas sur Staging — appliqué : preuve locale, vérification Staging au train ; autres : attendre Staging ; recommandé : preuve locale

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Le drapeau « Plus tard » passait d'un test système à l'autre : la remise à zéro de Capybara vide cookies et `localStorage`, pas le `sessionStorage` de l'onglet. Un `teardown` ne suffisait pas (il tourne après la remise à zéro, la page est déjà `about:blank`) : `before_teardown` dans `ApplicationSystemTestCase` vide le stockage pendant que la page est encore sur l'application.

## Ce qu'on a appris sur la codebase

**Rapport de cause.**

1. Fenêtre. Chaîne : tout écran du shell → `layouts/shell.html.erb` (l. 56-61) → `first_exercise_prompt?` (concern `FirstExercisePrompt`) → cadre `student_first_exercise_prompt` → `classroom/student_first_exercises#show` → `ui_modal open: true`. Cause : le shell pose le cadre sur **tout** écran, et la fermeture n'écrit rien (UDR-0179 §3.2, « le prochain écran chargé redemande le cadre ») : c'est la règle elle-même.
2. Nombre. Chaîne : `kinds/_numeric.html.erb` → `assessment/numeric_controller.js#validate` (`setCustomValidity`) → `lib/assessment/copy_sheet.js#answered` (`checkValidity` faux → question comptée vide) → `submit` (dialogue « sans réponse ») → « Rendre quand même » → validation native du formulaire, bulle sur le champ hors de vue. Cause : le refus d'une saisie illisible n'avait d'autre voix que la bulle du navigateur, et la copie confondait « illisible » et « sans réponse ».
3. Trou de test : `student_first_exercise_prompt_test` affirmait le retour de la fenêtre sur l'écran suivant (la règle) ; `question_numeric_test` vérifiait le compteur, jamais l'envoi d'une copie avec une saisie illisible.

Sans les mots du symptôme : (1) une invitation ponctuelle était posée dans le gabarit commun à tous les écrans ; (2) un refus de saisie n'était signalé que par le mécanisme natif du formulaire, déclenché après un dialogue qui le comptait comme une absence.

- `checkValidity()` envoie l'événement `invalid` au champ : le contrôleur du nombre l'écoute pour écrire son message, la copie lit `validity.valid` (sans événement) pour compter.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Données : aucune à réparer (rendu et navigateur seuls). | — | — |
| Les cases multiples d'une réponse en nombre n'ont pas de contrôle de lecture côté navigateur. | Hors périmètre, comportement inchangé. | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-11-25 |
| **PR** | #710 |
| **ADR produits** | |
| **UDR produits** | UDR-0185 (amende UDR-0179 §3.2) |
