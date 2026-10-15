# Journal — Parcours d'exercice de l'élève aux couleurs Wave et Djamo

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-15 | Texte à trous : sans casse ni accents ni espaces en trop, plusieurs réponses justes, faute de frappe fausse | Choix du porteur | ADR-0091 §4.3 |
| 2026-10-15 | Nombre : marge facultative par question, virgule ou point | Choix du porteur | ADR-0091 §4.3 |
| 2026-10-15 | Ordre et relier : tout juste ou faux, pas de points partiels | Choix du porteur ; la note, les badges et les lacunes ne changent pas | ADR-0091 §4.3 |
| 2026-10-15 | La page poste des indices d'affichage, jamais des ids, pour l'ordre et relier | Les ids sont créés dans l'ordre des positions : ils révéleraient la solution | ADR-0091 §4.4 |
| 2026-10-15 | Ordre ou relier faux : « Ton choix » ne dit pas quelle étape ou paire est fausse | Sinon l'élève retrouve la solution en recommençant ; confirmé par le porteur | UDR-0087 §3.5 |
| 2026-10-15 | Nombre illisible : erreur de saisie, la question n'est pas comptée | Confirmé par le porteur | ADR-0091 §4.3 |
| 2026-10-15 | Lot 0 : `AnswerShuffle.for(session_id:, …)` et non `session_public_id:` | L'ancien mélange tirait sa graine de l'id entier de la session (`session_id ^ question_id`) ; garder cette graine est la seule façon qu'une session ouverte se reprenne à l'identique | ADR-0091 §4.4 (écart de signature) |
| 2026-10-15 | Lot 0 : chaque type de question est une classe à méthodes de classe (`structure_errors`, `well_formed?`, `correct?`, `INPUT`, `INVALID`) | `Question` délègue sans instancier ; `INPUT` dit au use case quoi lire (ids, texte, indices) et `INVALID` l'erreur à rendre | ADR-0091 §4.3 |
| 2026-10-15 | Lot A : `ui_modal` gagne `placement: :sheet_compact` (feuille sous 700 px, fenêtre au-dessus) et `trigger_label:` (déclencheur icône seule) | La feuille existante s'arrêtait à 1 024 px ; la croix n'a pas de texte | UDR-0087 §3.3 |
| 2026-10-15 | À la fusion avec `profil-eleve`, `:sheet_compact` devient `:phone_sheet` (même feuille sous 700 px, déjà livrée par le profil, UDR-0089 §3.4) ; `trigger_label:` reste | Deux noms pour une même option ; on garde celle déjà sur `Develop` | Non |
| 2026-10-15 | Lot A : le bouton radio ou la case est la pastille de la lettre (A, B, C), la lettre passe dessus sans intercepter le clic | Le champ reste visible et cliquable pour tous les outils (lecteur d'écran, tests), sans champ caché | UDR-0087 §3.4 |
| 2026-10-15 | Lot 0 : un type n'est proposé au formulaire de l'équipe que si son partial `kinds/_<type>_fields` existe | Les quatre lots livrent chacun leur type sans toucher au formulaire commun | ADR-0091 §4.5 |

## Ce qui a dérapé

- Lot 0 : la construction d'une question importée était copiée dans les trois imports ; elle passe dans `ContentTreeWriterPort::QuestionNode.from_import` pour n'ajouter `tolerance` et `match` qu'une fois.
- Lot 0 : le test de caractérisation de `ContentTreeWriter` compare des lignes entières ; les deux colonnes nouvelles en sont retirées et vérifiées vides à part, plutôt que de réécrire l'instantané de 380 Ko.

- Lot A : « Valider » désactivé tant que rien n'est choisi rend le chemin « valider à vide » injouable dans un navigateur ; `test/system/error_paths_test.rb` vérifie désormais le bouton désactivé, le refus 422 reste couvert par le test du contrôleur.
- Lot A : « n/T » est dans l'en-tête, hors du frame ; « Question suivante » sans requête le recopie depuis `data-counter` de la carte (`assessment--next-question`), et le stream remplace « reprendre à la question N » de la confirmation.

- Lots B à G : les libellés en capitales (`uppercase`) changent le texte que lit Capybara ; quatre assertions de tests système passent en recherche insensible à la casse, et l'infobulle sort du libellé pour garder sa casse.
- Lot D : le texte à trous unifie aussi l'apostrophe typographique (’) avec l'apostrophe droite : un clavier de téléphone tape l'une, l'enseignant l'autre ; ce n'est pas une faute de frappe (écart assumé à la lettre de l'ADR-0091 §4.3).
- Lot D : la largeur du blanc suit ce que l'élève écrit (`field-sizing-content`), et non la longueur moyenne des réponses acceptées (UDR-0087 §3.4) : celle-ci aurait donné un indice sur la solution.
- Lot 0 : deux exécutions de la suite lancées en même temps sur les mêmes bases de test se sont bloquées (deadlocks) ; une seule exécution à la fois.
- Lots B à G : sur une machine chargée, la suite complète hors système dépasse 20 minutes ; les lots d'interface ont été vérifiés par les répertoires touchés (domaine, intégration, contrôleurs, design), la suite complète par `bin/ci-quiet` au Lot H.
- Budget des tests système (ADR-0069 §9) : le chantier ajoute quatre fichiers (15,4 s enregistrées) à une branche `accueil-eleve` qui en avait déjà ajouté 9,9 s ; la somme dépasse 15 s, à trancher par le porteur (dérogation ou fusion séparée).

- Relectures (après le Lot H) : marge bornée à decimal(12,4) (schéma, règle `tolerance_out_of_range`, `ActiveRecord::RangeError` dans les échecs d'écriture), octet nul refusé en 422, œ, æ et tirets Unicode unifiés au texte à trous, « 1.000 » vaut 1, une phrase et un chemin par règle d'import, `tolerance` et `match` refusés hors de leur type, doublons refusés (étapes, gauches, réponses acceptées), mélange jamais résolu d'avance pour l'ordre et relier, « Félicitations » dès « 14/20 » affiché ; le test système du texte à trous redescend en intégration.

## Ce qu'on a appris sur la codebase

- Tout le moteur supposait « cocher parmi des propositions » : CHECK sur `question_type`, `selected_answer_ids` non vide, `correct?` par égalité d'ensembles d'ids.
- Le mélange des propositions est déjà déterministe par session (`SessionPlayQuery`), ce qui permet de reconstituer les ids côté serveur.
- « Quitter la session » n'était qu'un lien : la session reste `started` et se reprend.
- Le shell rend l'en-tête et les barres sur toutes les pages, sauf dans l'app Android : pas de mode concentré avant ce chantier.
- Les trois formats d'import (`exercises`, `essentials`, `course-tree`) partagent la même forme de question.
- `Data.define` accepte un champ facultatif en surchargeant `initialize(champ: nil, **) = super` : toutes les constructions existantes de `Question`, `Answer` et des nœuds d'import restent valides.
- Un `fieldset` désactivé n'envoie pas ses champs : le formulaire de l'équipe garde un panneau par type, un seul actif.
- Un champ `required` caché (`display: none`) compte pour `checkValidity()` : les listes de repli de l'ordre et de relier rendent « Valider » prêt ou non, sans code de plus.
- Minitest 6 n'a plus `minitest/mock` : un double se pose par `define_singleton_method` et se retire dans `ensure`.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Points partiels (ordre, relier) | Refusés par le porteur pour garder la note intacte | — |
| Tolérance aux fautes de frappe (texte à trous) | Refusée par le porteur | — |
| La saisie d'un nombre ou d'un texte refusée (422) est vidée au re-rendu | Le formulaire de la séance n'a pas d'objet ; l'erreur s'affiche, l'élève retape | — |
| Pas de limite de débit sur l'ouverture de sessions ni sur les réponses (relecture de sécurité, point 4) | Décision du porteur : pas de limite pour ce chantier | — |
| Revue par sous-agents (`security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`) | Outil d'agents absent de la session d'exécution ; revue faite à la main sur la fuite de la solution | À lancer sur la PR |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-15, fusionné dans `Develop` |
| **PR** | [#247](https://github.com/Lnclassapp/App.Lnclassapp/pull/247) |
| **`bin/ci-quiet`** | Rouge (2026-10-15) : budget système dépassé (25,3 s dont 9,9 s d'`accueil-eleve`, à trancher) ; couverture 100 % manquée par `daily_exercise_query.rb:14` (stub d'`accueil-eleve`) et trois branches de ce chantier, couvertes depuis ; tests système déjà rouges hors du chantier (connexion, invitations : `sign_in_test`, `team_invitation_test`, `public_pages_test`, `staff_invitation_test` sur le format du numéro) et `classroom_archival_test` instable sous charge (vert seul) |
| **ADR produits** | ADR-0091 |
| **UDR produits** | UDR-0087 |
