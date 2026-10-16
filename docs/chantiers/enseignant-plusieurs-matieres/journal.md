# Journal — Un enseignant qui enseigne plusieurs matières

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-16 | Cadrage écrit sur les **recommandations** des questions 1 à 11, non encore répondues | Le porteur répond sur un document complet ; une réponse différente amende avant le Lot 0 | ADR-0103, UDR-0125 à 0127 (Proposé) |
| 2026-10-16 | Matières **par enseignant**, pas par liaison enseignant-classe | Pas d'étape de plus dans « Mes classes » ; migration par copie ; la liaison reste ajoutable plus tard (option D) | Oui, ADR-0103 §4.1 |
| 2026-10-16 | Pas de matière principale, ordre d'ajout | Un drapeau sans usage demanderait un geste « Définir comme principale » | Oui, ADR-0103 §4.1 |
| 2026-10-16 | Remplacer toute la liste, jamais ajouter une matière à la fois | Le plafond tient sans verrou entre deux onglets | Oui, ADR-0103 §4.4 |
| 2026-10-16 | Migration en deux temps (copie + écriture double, puis retrait au Lot Z) | Les lots parallèles ne cassent pas les lectures pas encore converties | Oui, ADR-0103 §4.6 |

## Ce qui a dérapé

- `origin/Develop` a avancé pendant le cadrage (fusion des cadrages `multi-etablissements-enseignant` et `espace-direction`) : la branche a été avancée en avance rapide avant d'écrire, pour lire l'ADR-0094 réellement fusionné.

## Ce qu'on a appris sur la codebase

- **Aucune policy ne lit la matière** : le catalogue est restreint par lecture (UDR-0077), un cours d'une autre matière reste ouvert et assignable par son adresse. Le chantier ne touche donc à aucun droit.
- **`teacher_classrooms` admet déjà plusieurs enseignants par classe** (unique `teacher_id, classroom_id`), et « Exercices assignés » montre toutes les assignations de la classe, avec un badge : deux enseignants d'une classe se voient déjà.
- **Le badge de matière des cartes du catalogue n'est plus masqué** pour l'enseignant : l'UDR-0077 §3.2 (R6) l'avait retiré, son amendement du 2026-10-06 (bis) l'a rétabli.
- `teacher_profiles` ne peut pas disparaître : elle porte `referral_token` (parrainage), `joined_via` et `onboarding_completed_at`.
- Les seeds (`db/seeds/development.rb`, `db/seeds/demo/saint_michel.rb`) et les fabriques de test créent `Orm::TeacherProfile` directement : ils doivent écrire `teacher_materials` dès le Lot 0, sinon un enseignant de démo n'a aucune matière.
- `ClassroomGapsQuery` (ADR-0101 §4.4) n'est pas encore codée : elle hérite des matières par les slugs des cours de la page de classe, sans code propre.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Matière par liaison enseignant-classe (option D de l'ADR-0103) | Bruit de la page de classe non encore constaté | à ouvrir si le porteur le constate |
| L'équipe ne peut pas corriger les matières d'un enseignant | Aucun besoin exprimé | — |
| Restreindre l'assignation aux matières de l'enseignant | Le catalogue est une lecture, pas un droit (UDR-0077) | — |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | ADR-0103 |
| **UDR produits** | UDR-0125, UDR-0126, UDR-0127 |
