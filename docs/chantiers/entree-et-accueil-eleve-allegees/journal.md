# Journal — Entrée et accueil de l'élève allégés

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-21 | Le premier code n'est jamais dans la page : au 4e chiffre, envoi automatique, le serveur compare | 4 chiffres (ou leur empreinte) dans la page se retrouvent en 10 000 essais | UDR pavé §2.3 |
| 2026-11-21 | L'adresse du QR réutilise l'identifiant public de l'établissement et passe par l'entrée élève | Aucun identifiant nouveau ; la recherche publique liste déjà ces identifiants | ADR adresse-publique-etablissement |
| 2026-11-21 | La fenêtre du premier exercice est un cadre différé du shell, éteint par un drapeau de session | Ne pas payer la requête de l'accueil sur chaque écran | UDR accueil §2 |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees · Arrivée sur `/student-signup` sans passer par l'entrée (accueil public, page d'un cours, `/join`) : le numéro n'y est pas connu — appliqué : on garde les trois étapes, numéro et code demandés ; autres : rediriger `/student-signup` vers `/student` (entrée unique) ; recommandé : rediriger vers l'entrée, dans un chantier suivant (tests système de l'inscription à reprendre)
- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees · « Fait son premier exercice », qui éteint la fenêtre : commencé, rendu, réussi ? — appliqué : une copie rendue, quelle que soit la note ; autres : réussie (10/20, ancienne règle de la carte) ; commencée ; recommandé : rendue
- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees · Fréquence de la fenêtre après fermeture — appliqué : une fois par écran chargé (elle revient au chargement suivant, jamais deux fois sur le même) ; autres : une fois par session ; une fois par jour ; recommandé : une fois par écran chargé (précision du porteur)
- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees · La tuile « Inviter » et la bannière « Invite tes camarades » en bas d'accueil — appliqué : la tuile remplace la bannière (une porte par action) ; autres : garder les deux ; recommandé : la tuile seule
- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees · L'invitation à installer l'application et la fenêtre du premier exercice sur l'accueil — appliqué : l'invitation attend tant que la fenêtre peut s'ouvrir ; autres : les deux ; recommandé : l'invitation attend
- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees · Le QR : simple image, ou agrandi au toucher — appliqué : image de 96 px, sans agrandissement ; autres : toucher pour l'agrandir en plein écran ; recommandé : image seule, agrandir si la recette montre que les téléphones peinent à le lire
- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees · Les inscriptions par le QR de l'établissement comptent comme « standard » dans l'attribution (ADR-0143) — appliqué : « standard » ; autres : une étiquette `school_qr` ; recommandé : une étiquette, dans un chantier suivant
- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees (Lot B) · Un ancien formulaire en cache qui poste `join_code` avec un code inconnu : l'erreur `join_code` n'a plus de champ où s'afficher (l'étape 1 s'ouvre sans message sur ce point) — appliqué : le serveur refuse (422) et garde FIELDS comme le veut l'UDR §3.3, sans message dédié ; autres : afficher l'erreur dans le cadre de la cascade ; recommandé : laisser tel quel (cas résiduel, un rechargement règle)
- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees (Lot B) · Tests système du lot (`student_signup_steps_test`, `student_activation_test`, `join_test`) réécrits sur la cascade mais non exécutés : Chrome (153) et chromedriver (147) sont incompatibles dans l'environnement de l'agent — appliqué : réécriture soignée, contrôleurs verts ; recommandé : le vérificateur les rejoue (`bin/system-changed`)

- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees (Lot A) · Où montrer « Les deux codes sont différents. » quand le champ natif est caché — appliqué : un bloc `#student-entry-mismatch` (`role=alert`) rendu `hidden` au-dessus du champ, dévoilé par le contrôleur du pavé ; sans JavaScript, le message reste sous le champ (une seule occurrence visible dans chaque cas) ; autres : déplacer le message dans `base_errors` pour tous les cas ; recommandé : l'appliqué
- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees (Lot A) · Fichiers hors fiche du Lot A modifiés pour ne pas casser des tests existants : `test/support/student_entry_helper.rb` (la confirmation se tape au pavé) et `test/system/identity/pin_reveal_test.rb` (plus de révélation du champ de confirmation) — appliqué : modification minimale de ces deux lignes ; le Lot B reprend la dernière ligne du helper (`#signup-entry-number`) : conflit de fusion à résoudre à la main ; recommandé : l'appliqué

- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees (Lot D) · L'invitation à installer ne s'ouvre qu'une fois le drapeau « copie rendue » posé : un élève qui n'a rien à se voir proposer (pas d'exercice à son niveau) garde le cadre vide sans drapeau, donc n'a plus l'invitation sur l'accueil — appliqué : « seulement si la fenêtre ne peut pas s'ouvrir » = drapeau posé ; autres : poser aussi le drapeau « rien à proposer » pour la session, ou rendre l'invitation quand le cadre revient vide ; recommandé : rendre l'invitation quand le cadre revient vide (dans un chantier suivant)

- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees (revues) · Une erreur 500 de la page de la fenêtre est avalée côté navigateur (`turbo:frame-missing` empêché, voulu par l'UDR) : seule la ligne 500 du journal Rails la trahit, aucun suivi d'erreurs n'existe — appliqué : silence côté élève, rien de plus ; autres : signaler les 5xx (balise vers un point de journalisation) ; recommandé : une alerte sur les 500 de `/students/first-exercise`, dans un chantier d'observabilité
- [ ] 2026-11-21 · entree-et-accueil-eleve-allegees (fermeture) · Tests système de toute la branche non exécutés dans la session (Chrome 153 / ChromeDriver 147, téléchargement d'un pilote refusé) ; `SystemBudgetTest` rouge faute de durées enregistrées pour les 3 nouveaux fichiers — appliqué : PR ouverte avec la preuve non système et le blocage écrit ; recommandé : l'orchestrateur ou le vérificateur joue `bin/system-changed` puis `script/ci/record_timings` sur une machine au pilote assorti avant la fusion

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Lot C : le test existant `test/controllers/classroom/student_homes_controller_test.rb` (« the class card … sigle », l. 140-159) vérifie encore `#student_school_sigle`, qui n'est plus sur la carte ; fichier partagé, laissé au Lot D (à remplacer par le QR, `#student_school_qr`). Les tests système du Lot C n'ont pas pu tourner dans la session (ChromeDriver 147 pour Chrome 153) : à jouer par le vérificateur.
- Lot A : les tests système (Chrome 153 installé, chromedriver 147 seul disponible, téléchargement d'un autre refusé) n'ont pas pu tourner dans l'environnement du lot ; ils sont écrits mais à jouer par le vérificateur (`test/system/student_entry_pin_pad_test.rb`, tous les tests système qui passent par `pass_student_entry`).
- Lot D : les tests système (`student_first_exercise_prompt_test`, `student_activation_test`, `student_home_test`) n'ont pas pu être joués dans la session du lot : Chrome 153 installé, ChromeDriver 147 seulement (`session not created`). Écrits à la lecture du composant `modal`, à rejouer par `bin/system-changed` avant la fusion.
- Adresse du QR : `/e/<identifiant>` (option A′) entrait en collision avec le lien enseignant retiré `/e/<code>` (IE-02, deux tests rouges) ; déplacée en `/ecole/:school_public_id`, contrainte base58 14 caractères ; ADR mise à jour.
- Pavé : le re-rendu 422 par morph Turbo laissait le contrôleur connecté, le champ natif visible et le pavé caché ; vu par le challenger (Playwright), corrigé en rejouant l'installation sur `turbo:render`.
- Écran d'exercice : il ne pose pas `content_for :focus`, donc la fenêtre s'y serait ouverte malgré le PRD ; trouvé par le test ajouté après la revue des tests, corrigé par `first_exercise_prompt? = false` dans les contrôleurs de copie. Leçon : « mode concentré » n'est pas un drapeau fiable du layout.
- `/aide` rend le shell sans `FirstExercisePrompt` ; le `respond_to?` du layout cachait l'oubli (revue silent-failure-hunter) ; retiré.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `layouts/shell` est rendu par des contrôleurs hors `AuthenticatedController` (`HelpController`, `DesignController`) : tout helper du shell doit y exister.
- Un contrôleur Stimulus reste connecté à travers un morph Turbo : l'état initial se rejoue sur `turbo:render`, pas seulement dans `connect`.
- Les worktrees ont leur propre base (suffixe du dossier) ; deux suites lancées en même temps sur la même base se bloquent (deadlocks PG).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Suivi des 5xx de la fenêtre du premier exercice | Pas de service de suivi d'erreurs dans le projet | observabilité (à ouvrir) |
| `/student-signup` en direct redemande numéro et code | Décision réversible, voir À trancher | entrée unique (à ouvrir) |
| Clé du QR testée par appel direct du helper, pas par un attribut de la vue | Coût faible, gain faible | — |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
