# Journal — « Choisis ta classe » aux couleurs Wave et Djamo

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-15 | Pas d'ADR | Interface seule : routes, paramètres et `ClassPicker` inchangés | Non |
| 2026-10-15 | À coder avant `connexion-inscription-eleve` si possible | L'inscription reprend la même cascade | Non |
| 2026-10-15 | Branche `feature/choix-classe-eleve` empilée sur `feature/accueil-eleve` (en-tête d'UDR-0084), sans PR | La PR `accueil-eleve` n'est pas encore fusionnée | Non |
| 2026-10-15 | Pastille de niveau choisie en `bg-brand-strong text-white`, et non `bg-brand text-white` (UDR-0091 §3.1) | Blanc sur `brand` : contraste ≈ 2,8:1, sous l'AA ; `brand-strong` est la teinte des maquettes, et ses tokens sombres donnent la pastille claire de la maquette sombre | Non |
| 2026-10-15 | « Changer » remet aussi l'établissement sur son invite (pas seulement vider les étapes 2 et 3) | Sinon, rechoisir le même établissement ne déclenche aucun `change` : l'élève resterait sans niveaux. Rails n'écrit l'invite que sans valeur : le `select` la porte en `data-prompt`, le contrôleur la remet | Non |
| 2026-10-15 | Chaque étape dans sa carte sur « Choisis ta classe » (`framed: true`), sans carte dans l'inscription | Une carte dans la carte de l'inscription alourdirait la rubrique 1 ; même partial, mêmes étapes | Non |
| 2026-10-15 | « Continuer » sans JavaScript à l'étape 1 et à l'étape 2 | Établissement replié, le « Continuer » de la DRENA est caché : celui de l'étape 2 fait avancer du niveau à la classe | Non |
| 2026-10-15 | Une indication sous les étapes vides : « Choisis d'abord ton établissement. » / « … ton niveau. » (maquette) | Affichée en CSS (`peer-empty`), donc aussi après « Changer » et sans JavaScript | Non |

## Ce qui a dérapé

- Un commentaire ERB qui citait `do -%>` se fermait sur son propre `%>` : le reste du commentaire s'affichait dans le cadre. Ne jamais écrire `%>` dans un commentaire ERB.
- Chrome rend un `<noscript>` en ligne quand JavaScript est actif : dans un bloc, il ajoute une ligne vide (12 px) au bas de l'étape. `display: contents` est pire (le texte brut du `<noscript>` s'affiche). Les étapes sont des colonnes flex, où le `<noscript>` devient un élément sans hauteur, et le bouton porte son écart (`mt-3`).
- Une légende de `fieldset` posée dans une carte qui est elle-même le `fieldset` chevauche la bordure : la carte entoure le `fieldset`.
- Garde « budget système » (ADR-0069 §9) rouge sur cette branche : elle compte `accueil-eleve` (9,9 s) et ce chantier (7,5 s) ensemble, faute de base fusionnée. Ce chantier seul ajoute 7,5 s ; la garde repasse au vert une fois `accueil-eleve` dans `Develop`.

## Ce qu'on a appris sur la codebase

- La cascade passe par trois routes publiques (`drena_schools`, `school_picker_levels`, `school_picker_classrooms`), en cadres Turbo pilotés par `classroom--class-picker`, avec un repli sans JS par `formaction` GET.
- Le préremplissage vient de `StudentHomeQuery#last_classroom` (DRENA et établissement seulement).
- Un cadre Turbo n'est `:empty` que sans aucun nœud texte : `do -%>` (le tiret de Rails) supprime le saut de ligne d'ouverture, et les lignes `<% %>` seules sont rognées.
- Sous 640 px, une carte de premier niveau du shell va bord à bord (UDR-0005, `data-bleed`) : les cartes des étapes suivent cette règle, contrairement aux maquettes, qui les montrent dans la marge.
- `ui_field … as: :select` ne transmet que `prompt:` à Rails ; avec `required: true` et sans invite, Rails ajoute une option vide de lui-même.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Index UDR (`script/docs/build_index`) et index des chantiers non régénérés | Faits à la clôture de la PR, avec ceux des chantiers voisins de la même session | Clôture de la PR |
| « Changer » sans JavaScript dans l'inscription : le lien ne renvoie que la DRENA, nom, prénoms et contact déjà saisis sont perdus (seulement après un 422/403 re-rendu, où l'établissement est replié) | Comportement gardé ; l'href est testé | `connexion-inscription-eleve` |
| Revue par un rôle distinct (parcours nominal + erreur) et sous-agent `pr-test-analyzer` | Pas d'outil de sous-agent dans la session d'exécution | Avant la fusion de la PR |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-15 (branche, sans PR) |
| **PR** | — (branche `feature/choix-classe-eleve`, après la PR `accueil-eleve`) |
| **`bin/ci-quiet`** (2026-10-15, après le lot A) | ROUGE, rien de ce chantier : garde budget système (`accueil-eleve` comptée avec ce chantier) ; couverture 99,99 % (`DailyExerciseQuery`, bouchon du lot 0 d'`accueil-eleve`) ; `image_header_test.rb:500` (chrono sous charge) ; système : `sign_in_test.rb:106`, `public_pages_test.rb:79/:97`, `team_invitation_test.rb:13`, `staff_invitation_test.rb:7` (numéro mis en forme, déjà rouges), `boucle_pedagogique_test.rb:37` (voie du lien, cascade non rendue : page blanche après l'inscription, à vérifier sur `accueil-eleve`). Pureté, HITL, rubocop, brakeman, audits, graines, perf, budget des assets : verts |
| **ADR produits** | — |
| **UDR produits** | UDR-0091 |
