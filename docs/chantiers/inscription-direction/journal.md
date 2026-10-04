# Journal — Inscription de la direction sans invitation

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-04 | Porteur, Q12 : « Les directions invitées par l'équipe ne comptent pas » dans le plafond. Le même message disait d'abord « oui toutes comptent » ; la dernière consigne a été retenue | Seules les arrivées par le code ouvrent un risque | Oui, ADR-0077 §4 |
| 2026-10-04 | Lot 0 : « Voir les N autres » de l'accueil de l'équipe devient « Et N autres, sur les fiches de leurs établissements. » | Aucune page ne liste toutes les directions retirées : le lien n'aurait mené nulle part | UDR-0070 §3.5, PRD ID-21 amendés |
| 2026-10-04 | Lot 0 : les places « 2 / 3 » sont un `<p id="school_staff_places">` dans la carte, pas le sous-titre de `ui_card` | Une cible stable pour le Turbo Stream du retrait | Non (détail de l'UDR §3.4) |
| 2026-10-04 | Merge du Lot A : le lien discret du haut de page passe de `text-mute` à `text-ink/90` | `text-mute` sur `bg-brand` donne ≈ 2,4:1 en thème clair et ≈ 2,3:1 en sombre, sous le seuil WCAG AA de 4,5:1 | UDR-0070 §3.2 amendée |
| 2026-10-04 | Merge du Lot B : la ligne des places devient `shared/_school_staff_places`, rendue par le bloc et par les Turbo Streams | Le Lot B avait recopié la balise dans son Turbo Stream ; le Lot C en aura besoin aussi | Non |
| 2026-10-04 | Revue de sécurité (lots 0, A, B, D) : 4 constats bas, aucun haut. Corrigés : débit de l'inscription à 5 par minute comme l'enseignant (constat 2) ; `StaffRepository#archive` sous verrou de l'établissement et auteur relu après lui, car deux directions qui se retiraient l'une l'autre réussissaient toutes deux (constat 3, test à deux threads rouge sans le correctif) ; purge compte par compte, un échec étant rendu dans `failed` et journalisé par id (constat 4). Reporté : constat 1 | Rapport du `security-reviewer` | ADR-0077 §5 précisé ; PRD ID-07 et UDR §3.0 à 5 par minute |
| 2026-10-04 | Merge du Lot C : son module `SchoolStaffBlock`, posé dans `SchoolsController` faute de concern dans sa liste, devient `app/controllers/concerns/teams/school_staff_block.rb` ; la clé inutilisée `not_archived` est retirée ; la restauration remplace tout `#school_staff`, et une cible vide `#school_archived_staff` reste sur la fiche | Trois contrôleurs s'en servent ; pas de texte mort ; mêmes raisons que le Lot C | UDR-0070 §3.5 amendée |
| 2026-10-04 | L'agent du Lot C n'a pas pu lancer la suite complète, que l'outil de permissions lui a refusée (« Modify Shared Resources ») ; le coordinateur l'a lancée sur la branche de chantier après le merge | Le refus a été signalé au porteur ; aucune permission n'a été modifiée | Non |
| 2026-10-04 | Revue de sécurité du Lot C : 1 constat moyen et 1 bas, corrigés. (1) Une direction restaurée juste avant la suppression de la nuit pouvait quand même être supprimée, car la purge ne relisait pas le compte : `StaffRepositoryPort#claim_for_purge` relit le rattachement sous le verrou de l'établissement, et un compte restauré entre-temps est sauté. Le test à deux threads est rouge sans le correctif. (2) La restauration relit la ligne sous le verrou et ne la met à jour qu'archivée : deux restaurations simultanées donnent un seul `:restored`. Ajout de tests sur le second facteur non vérifié, l'élève, l'enseignant et l'admin | Rapport du `security-reviewer` | ADR-0077 §4.2 complété |
| 2026-10-04 | Analyse des tests (`pr-test-analyzer`) : aucun critère orphelin. Renforcés : ID-04 au niveau du use case (6 inscriptions simultanées, 1 compte, 5 annulées), ID-08 (défaut en base et invitation acceptée), session survivante d'une direction archivée (403, rien écrit), date de suppression exacte dans le flux de l'équipe, PRD §5 corrigé à 5/min | Rapport du `pr-test-analyzer` | Non |
| 2026-10-04 | Lot 0 : la route de restauration prend `:staff_member_public_id` (ressource imbriquée), pas `:public_id` | Convention Rails des ressources imbriquées ; le nom de route est celui de l'UDR | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Lot 0 : `db:migrate` en local réécrit les `CHECK … = ANY (ARRAY[…])` de tout `db/schema.rb`, car la version locale de PostgreSQL écrit ces contraintes dans un autre format. N'ont été gardées que les lignes de `school_staffs`, la version et la clé étrangère `archived_by_id` ; le schéma rechargé en test passe.
- Lot 0 rouvert juste après le départ de la vague 2 : `Entities::Identity::AuditAction::ALL` est une liste fermée, et les lots A, B et D écrivent des actions `school_staff.*`. Les 4 actions y ont été ajoutées et chaque lot a mergé la branche de chantier. Pour les prochains plans : vérifier la liste d'audit au Lot 0.
- Lot 0 rouvert une seconde fois, à la demande du Lot A : `RegistrationRepositoryPort` ne savait créer un `school_admin` que par `create_from_invitation`. Ajout de `create_school_admin(user:, pin:)` (ADR-0077 §4.2 amendé), plutôt que d'appeler `create_from_invitation(invitation_id: nil)`.
- Lot 0 : `test/routing/school_admin_routes_test.rb` fige la liste des écritures sous `/school-admin` ; la route de retrait l'y ajoute.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `Entities::Identity::AuditAction::ALL` est une liste fermée : le repository d'audit lève `ArgumentError` sur toute action absente. À vérifier dans chaque Lot 0 qui ajoute une trace.
- `test/guards/system_budget_test.rb` exige la durée de chaque test système dans `script/ci/test_timings.yml`, avec un budget de 15 s par chantier (ADR-0069 §9). Ici : A 2,7 s, B 6,0 s, donc C doit tenir en 6 s environ. Le fichier est partagé : chaque lot n'y ajoute que sa ligne, dans un commit à part.
- `script/ci/record_timings` ne lit pas la première ligne d'un test système lancé seul : la bannière « Capybara starting Puma... » la coupe (Lot B).
- `RAILS_ENV=test bin/rails db:prepare` dans un worktree neuf charge les seeds dans la base de test, ce qui casse les tests d'unicité. Il faut lancer `db:schema:load` (lots A et B).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `test/infrastructure/queries/identity/account_search_query_test.rb:42` est instable : un numéro tiré par la fabrique peut contenir « 0304 » | Sans lien avec le chantier ; vert au passage suivant | à ouvrir (`bugfix`) |
| La suppression d'un compte (élève par `AnonymizeUser`, direction par la purge à J+30) laisse le numéro dans `invitations.contact` et l'IP dans `audit_events.ip_address` (revue de sécurité, constat 1, basse) | Le reste est le même pour toute suppression de compte : à traiter une fois pour toutes | à ouvrir (`feature` ou `bugfix` sur la suppression de compte) |
| `test/system/teams/blog_management_test.rb:71` a échoué une fois dans `bin/rails test:system` complet (texte alternatif de l'image lu `nil`), et passe seul deux fois de suite | Hors du diff (aucun fichier du blog touché) ; à surveiller en CI | à ouvrir si la CI le reproduit |
| `SchoolStaffQuery#archived` n'a pas de limite : l'accueil de l'équipe lit toutes les directions retirées pour en montrer 5 | Rétention de 30 jours : le volume reste faible | — |
| Le format de date avec « 1er » est recopié dans `shared/_school_staff` et les deux `_archived_staff` | Un helper partagé devrait le porter | à ouvrir (`refactor`) |
| `script/ci/record_timings` perd la première ligne quand la bannière Puma la coupe | Contournement possible (retirer la bannière avant l'enregistrement) | à ouvrir |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
