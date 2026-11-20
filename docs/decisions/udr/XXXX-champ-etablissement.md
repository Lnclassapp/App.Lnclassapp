# UDR-XXXX : Le champ « Ton établissement » et sa liste de résultats
<!-- index
titre: Champ établissement avec recherche
statut: Accepté
adr-lie: XXXX (recherche-etablissement)
problematique: Comment l'élève et l'enseignant trouvent leur établissement en un seul champ, sur téléphone, avec ou sans JavaScript ?
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-20 |
| **Chantier** | `docs/chantiers/recherche-etablissement` |
| **ADR lié** | ADR-XXXX-recherche-etablissement |
| **Remplacé par** | — |

Amende : UDR-0024 §2.4 (repli des listes DRENA), UDR-0081 §3.3 et UDR-0091 §3.2 (étape 1 de la cascade élève : la ligne repliée et « Changer » disparaissent), UDR-0079 et UDR-0099 §3.2 (rattachement enseignant).

---

## 1. Contexte

Deux listes natives (DRENA, puis établissement) : sur téléphone, l'élève fait défiler des centaines de noms et se trompe ; il ne sait pas toujours de quelle DRENA dépend son école (Tiassalé, 2026-11-20).

## 2. Décision

Un champ de texte et, dessous, une liste d'au plus 20 établissements, chacun avec sa DRENA à droite ; on coche un résultat (vrai bouton radio) et la liste se replie sur lui. Des radios plutôt qu'une liste ARIA « combobox » : ils marchent sans JavaScript, au clavier et au lecteur d'écran sans code supplémentaire, et partent avec le formulaire.

## 3. Règles d'implémentation

**Structure** — partial `app/views/school/school_searches/_field.html.erb`, locals `(scope:, label:, chosen:, result:, term:, error: nil, search_form: nil, fallback_url: nil)` :

1. `div[data-controller="school--school-search"]`, `data-school--school-search-url-value` = `school_search_path(scope:)`.
2. Libellé `label[for=school_q]` (`text-sm font-medium text-ink`, astérisque `text-error`) : « Ton établissement » (élève) ou « Votre établissement » (enseignant).
3. `input#school_q[type=search][name=school_q]`, classes de `ui_field` (`FIELD_INPUT`, `min-h-tap`, état invalide si `error`), `autocomplete=off`, `autocapitalize=none`, `spellcheck=false`, `enterkeyhint=search`, `placeholder` « Ex. Notre-Dame Tiassalé », `aria-controls=school_results`, `aria-describedby` = aide (+ erreur), `form=<search_form>` si donné. Actions : `input->school--school-search#queue`, `keydown.enter->school--school-search#now`.
4. Aide `p#school_q_hint.text-sm.text-mute` : « Tape au moins 2 lettres du nom de ton école, ou ta ville. » (vouvoyée chez l'enseignant).
5. Erreur `p#school_q_error` (icône `exclamation-circle`, `text-error`) : la première erreur de `school_public_id`.
6. `noscript` : bouton secondaire `sm` « Chercher » (icône `magnifying-glass`), `type=submit`, `formaction=fallback_url formmethod=get formnovalidate` ou `form=<search_form>`.
7. Le cadre `turbo-frame#school_results` (`block transition-opacity aria-busy:opacity-50`, `aria-live=polite`), contenu = template `school/school_searches/index`.
8. `template[data-school--school-search-target=error]` : `ui_error_state` « La liste n'a pas pu se charger. » + « Réessayer ».

**Liste de résultats** (template `school/school_searches/index`, locals `(scope:, chosen:, result:, rate_limited: false)`) :

- `fieldset.mt-2` + `legend.sr-only` « n établissement(s) trouvé(s) ».
- `ul.divide-y.divide-line.overflow-hidden.rounded-ln.border.border-line.bg-white` ; chaque `li` contient un `label.relative.flex.min-h-12.items-center.gap-3.px-4.py-3` avec : le radio `name="<scope>[school_public_id]"`, `value=public_id`, `required`, `class="peer absolute inset-0 cursor-pointer appearance-none focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-brand"`, `data-action=change->school--school-search#pick` ; le nom `span.min-w-0.flex-1.font-medium.text-ink` ; la DRENA `span.max-w-[45%].shrink-0.text-right.text-xs.text-mute` ; une coche `check-circle` `text-brand` visible si coché (`peer-checked`). Le `li` coché : `has-checked:bg-brand-soft`.
- Plus de 20 : `p.mt-2.text-sm.text-mute` « Plus de 20 établissements : ajoute un mot pour affiner. »
- Un établissement choisi et aucune saisie : la liste ne montre que lui, coché.

**Tokens** — `ink`, `mute`, `line`, `brand`, `brand-soft`, `error` ; `rounded-ln` ; aucune valeur en dur.

**Comportement** (`app/javascript/controllers/school/school_search_controller.js`) :

- `queue` : 300 ms après la dernière frappe ; saisie normalisée < 2 caractères → cadre vidé ; sinon `frame.src = url + "&q=" + saisie`. Toute nouvelle saisie après un choix émet `school--school-search:cleared`.
- `now` (Entrée) : `preventDefault`, recherche immédiate.
- `pick` : retire les autres résultats et la ligne « Plus de 20 », garde le coché, émet `school--school-search:picked` (`detail.publicId`).
- `turbo:frame-missing` / `turbo:fetch-request-error` du cadre → l'état d'erreur, « Réessayer » relance la recherche.
- Hôtes : la cascade élève écoute `picked` → `classroom--class-picker#loadLevels`, `cleared` → `#clearSchool` ; l'inscription enseignant écoute `picked` → `classroom--signup-steps#go` (étape 2).
- Sans JavaScript : « Chercher » renvoie la page en GET avec `school_q` ; élève : tout le formulaire de la cascade (comme le « Continuer » existant) ; enseignant et rattachement : un formulaire GET distinct qui ne porte que `school_q` (et le jeton du lien de parrainage).

**États obligatoires** (dans le cadre) :

- Vide : rien (cadre vide), l'aide sous le champ suffit.
- Chargement : `aria-busy` posé par Turbo → opacité 50 %.
- Erreur : `ui_error_state` ; 429 « Trop de recherches depuis cette connexion. Attends un instant puis réessaie. ».
- Introuvable : `ui_empty_state` icône `magnifying-glass`, « Aucun établissement trouvé », « Vérifie l'orthographe, ou tape un autre mot du nom ou ta ville. ».
- Succès : la liste.

**Accessibilité** — cibles de 48 px (`min-h-12`), focus visible sur chaque radio, les flèches parcourent la liste (un seul groupe de radios), annonce polie du nombre de résultats, le champ relié à son aide et son erreur.

## 4. Conséquences

- Plus aucun écran web ne propose la liste des DRENA pour choisir un établissement : la DRENA est un renseignement affiché.
- Tout nouveau formulaire qui demande un établissement rend ce partial ; il ajoute son scope à `School::SchoolSearchesController::SCOPES`.
- La cascade élève n'a plus de ligne repliée « établissement · Changer » : on change en tapant de nouveau.
