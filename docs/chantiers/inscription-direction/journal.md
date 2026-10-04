# Journal — Inscription de la direction sans invitation

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-04 | Porteur, Q12 : « Les directions invitées par l'équipe ne comptent pas » dans le plafond. Le même message disait d'abord « oui toutes comptent » ; la dernière consigne a été retenue | Seules les arrivées par le code ouvrent un risque | Oui, ADR-0077 §4 |
| 2026-10-04 | Lot 0 : « Voir les N autres » de l'accueil de l'équipe devient « Et N autres, sur les fiches de leurs établissements. » | Aucune page ne liste toutes les directions retirées : le lien n'aurait mené nulle part | UDR-0070 §3.5, PRD ID-21 amendés |
| 2026-10-04 | Lot 0 : les places « 2 / 3 » sont un `<p id="school_staff_places">` dans la carte, pas le sous-titre de `ui_card` | Une cible stable pour le Turbo Stream du retrait | Non (détail de l'UDR §3.4) |
| 2026-10-04 | Merge du Lot A : le lien discret du haut de page passe de `text-mute` à `text-ink/90` | `text-mute` sur `bg-brand` donne ≈ 2,4:1 en thème clair et ≈ 2,3:1 en sombre, sous le seuil WCAG AA de 4,5:1 | UDR-0070 §3.2 amendée |
| 2026-10-04 | Lot 0 : la route de restauration prend `:staff_member_public_id` (ressource imbriquée), pas `:public_id` | Convention Rails des ressources imbriquées ; le nom de route est celui de l'UDR | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Lot 0 : `db:migrate` en local réécrit les `CHECK … = ANY (ARRAY[…])` de tout `db/schema.rb`, car la version locale de PostgreSQL écrit ces contraintes dans un autre format. N'ont été gardées que les lignes de `school_staffs`, la version et la clé étrangère `archived_by_id` ; le schéma rechargé en test passe.
- Lot 0 rouvert juste après le départ de la vague 2 : `Entities::Identity::AuditAction::ALL` est une liste fermée, et les lots A, B et D écrivent des actions `school_staff.*`. Les 4 actions y ont été ajoutées et chaque lot a mergé la branche de chantier. Pour les prochains plans : vérifier la liste d'audit au Lot 0.
- Lot 0 rouvert une seconde fois, à la demande du Lot A : `RegistrationRepositoryPort` ne savait créer un `school_admin` que par `create_from_invitation`. Ajout de `create_school_admin(user:, pin:)` (ADR-0077 §4.2 amendé), plutôt que d'appeler `create_from_invitation(invitation_id: nil)`.
- Lot 0 : `test/routing/school_admin_routes_test.rb` fige la liste des écritures sous `/school-admin` ; la route de retrait l'y ajoute.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
