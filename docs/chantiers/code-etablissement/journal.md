# Journal — Code d'établissement pour l'inscription des enseignants

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | Quatre défauts appliqués sans arbitrage (code obligatoire, l'équipe transmet, 6 caractères `XXX-XXX`, `/e/` à 10 par minute) | Le porteur a laissé ces choix ouverts ; ils sont consignés « à confirmer » dans le memo, l'ADR et l'UDR (statut *Proposé*) | Oui — ADR-0057, UDR-0044 |
| 2026-09-28 | 32 symboles sur 6 positions (~1,07 milliard) plutôt qu'un préfixe | Distinct du code de classe par la longueur et l'affichage, et 1 200 fois plus d'espace ; un préfixe aurait coûté un caractère sans rien protéger | Oui — ADR-0057 §4 |
| 2026-09-28 | Le lien `/e/<code>` est une action du contrôleur d'inscription (`with_code`) qui rend la même page, pas un contrôleur à part | Même formulaire, mêmes partiels ; le `rate_limit` nommé (`name: "school_code"`) lui donne un compteur distinct de celui de l'envoi | Non |
| 2026-09-28 | Après une erreur de saisie, le bandeau de l'établissement remplace le champ si le code était bon | L'enseignant voit qu'il a le bon établissement ; aucune fuite de plus que `/e/`, et l'envoi reste à 5 par minute | Oui — UDR-0044 §2.4 |
| 2026-09-28 | Les tirages des codes d'établissement à l'import n'utilisent pas le `random:` injecté | Le test de course existant (`RacedClassrooms`) rejoue une graine précise pour les codes de classe : partager le générateur décalait la séquence | Non |
| 2026-09-28 | Le générateur de la migration est recopié, pas appelé depuis le domaine | Une migration ne doit pas changer de sens si l'entité évolue ; le test vérifie que ses codes sont valides pour l'entité | Oui — ADR-0057 §6 |
| 2026-09-28 | La copie réutilise `classroom--join-code-copy` (code et lien), sans nouveau contrôleur Stimulus | Il copie une valeur et pose un toast rendu par le serveur : exactement le besoin | Non (UDR-0044 §3) |
| 2026-09-28 | « Création manuelle » d'établissement : sans objet | Aucun écran ne crée d'établissement (amendement de l'ADR-0030) ; le contrat `create(school:)` exige le code, les seeds et les fabriques en tirent un | Oui — ADR-0057 §4 |

## Ce qui a dérapé

- TDD : 161 tests lancés sur les fichiers concernés avant le code : 2 échecs, 119 erreurs (constante `SchoolCode`, colonne, routes absentes), et le test de migration ne se chargeait pas (fichier absent). Puis vert.
- `add_check_constraint … if_not_exists: true` ne reconnaît pas une contrainte déjà posée : PostgreSQL réécrit l'expression (`school_code::text ~ …::text`), Rails compare l'expression. Le second `up` du test de migration a levé `PG::DuplicateObject`. Garde par le nom (`check_constraint_exists?(name:)`).
- Deux `insert_all!` qui lèvent dans la même transaction de test : la seconde voit `InFailedSqlTransaction`. Chacune dans son savepoint.
- Sélecteur `assert_select "button[aria-label='Copier le lien d'inscription']"` : l'apostrophe casse la chaîne CSS. Guillemets doubles.
- Deux `sign_in_as` successifs dans le même test d'intégration : le second ne rouvre pas de session d'équipe et la page ne s'affiche pas. Une seule connexion avant la boucle.
- Test système de régénération : relire la base juste après le clic lisait encore l'ancien code (la requête Turbo n'était pas finie). Attendre que l'ancien code disparaisse de l'écran avant de relire.
- `bin/rails db:migrate` sur PostgreSQL 16 local réécrit toutes les contraintes `CHECK` du `schema.rb` (précédent : generer-classes). Le `schema.rb` a été édité à la main pour ne porter que les lignes du chantier.

## Mesures

`bin/rails runner` sur la base de développement, PostgreSQL 16 local : 3 900 établissements sans code, puis `AddSchoolCodes#up`.

| Cas | Lots | Temps total | Résultat |
|---|---|---|---|
| 3 900 établissements (volume de production) | 8 lots de 500, chacun sa transaction | 0,93 s | 3 900 codes distincts, aucune valeur nulle |

L'index unique est construit `CONCURRENTLY`, et les deux `CHECK` sont validées après coup (`SHARE UPDATE EXCLUSIVE`) : aucune étape ne bloque les écritures au-delà d'un lot.

## Ce qu'on a appris sur la codebase

- `rate_limit` sans `name:` partage le compteur de tout le contrôleur (clé `rate-limit:<contrôleur>:<ip>`) : deux limites dans un même contrôleur exigent un `name:`.
- Les lectures paresseuses `t(".clé")` d'un partiel se résolvent par le chemin du partiel, pas par le contrôleur : `teams/schools/_header` se rend tel quel depuis `Teams::SchoolCodesController`, pourvu que ses `helper_method` (ici `school_status_tone`) existent.
- `/drenas/:drena_public_id/schools` n'a plus de consommateur interne.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Transmettre les ~3 900 codes aux établissements (export, envoi groupé) | Hors périmètre ; la fiche suffit en V1 | — |
| `school/drena_schools/index` (frame HTML) et `school--drena-schools` ne sont plus utilisés par l'inscription | L'adresse reste une API publique (SC-26, UDR-0024 §4) ; la retirer est une décision à part | — |
| La direction (`school_admin`, V2) ne lit ni ne régénère le code | Hors périmètre V1 ; amendement de l'ADR-0057 à prévoir avec la V2 | — |
| Confirmation des quatre défauts par le porteur | Laissés ouverts par la demande | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-09-28 |
| **PR** | *(ouverte par le coordinateur)* |
| **ADR produits** | ADR-0057 ; amendement ADR-0030 |
| **UDR produits** | UDR-0044 ; amendements UDR-0024, UDR-0036 |
