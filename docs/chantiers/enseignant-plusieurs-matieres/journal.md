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
| 2026-10-16 | **Réponse du porteur (Q1, Q7)** : matières par rattachement enseignant-établissement, et non par enseignant | « plusieurs disciplines au sein de l'établissement » ; l'établissement courant cloisonne déjà tout l'espace enseignant (ADR-0094 §10) | Oui, ADR-0103 §4 (option F) |
| 2026-10-16 | Table `teacher_school_materials` à la clé `(teacher_id, school_id)`, **sans FK** vers la ligne `teacher_schools` | La liste survit à un retrait : « Enseignants retirés » la montre, une réintégration la retrouve ; une FK l'aurait effacée | Oui, ADR-0103 §4.1 |
| 2026-10-16 | Port nouveau `TeacherMaterialRepositoryPort`, et non `TeacherProfileRepositoryPort#replace_materials` | La liste dépend de l'établissement, pas du profil | Oui, ADR-0103 §4.3 |
| 2026-10-16 | Un nouveau rattachement **hérite** d'une liste (`inherit`) : celle de l'établissement, sinon celle d'où il l'ajoute, sinon la dernière | Aucun écran ne demande la matière en rejoignant un établissement ; sans liste, il n'aurait aucun cours | Oui, ADR-0103 §4.4 |
| 2026-10-16 | Migration : copie pour chaque rattachement **et** chaque retrait ouvert | Un enseignant retiré retrouve sa matière s'il est réintégré, même après le retrait de la colonne | Oui, ADR-0103 §4.6 |

## Ce qui a dérapé

- Lot D : une requête de plus par liste (les matières) dépassait les budgets de requêtes de l'accueil de la direction (12) et de la modération (4). Les listes lisent désormais les matières dans leur propre requête (`TeacherMaterialsQuery.column`, `json_agg` corrélé).
- Lot D : les demandes en attente (enseignant sans rattachement) n'avaient pas de liste ; la migration du Lot 0 les copie aussi (sinon leur matière disparaissait au Lot Z).

- Lot A : la ligne de détail de l'en-tête est rendue dans la barre latérale sur ordinateur, pas dans `header` ; et `click_on` de Capybara ne lit pas `aria-label` : le test système vise le lien par son attribut.
- Lot A : les fabriques rangeaient les matières **après** `Time.current` ; une matière ajoutée ensuite par `replace` passait devant. Elles les rangent désormais dans la seconde qui précède.

- `origin/Develop` a avancé pendant le cadrage (fusion des cadrages `multi-etablissements-enseignant` et `espace-direction`) : la branche a été avancée en avance rapide avant d'écrire, pour lire l'ADR-0094 réellement fusionné.

## Migration en production

Avant le Lot 0, puis après la migration, la même requête doit donner le même nombre (attendu = copié) :

```sql
-- Attendu : une ligne par rattachement, plus une par retrait encore ouvert sans rattachement à cet établissement.
SELECT
  (SELECT COUNT(*) FROM teacher_schools ts JOIN teacher_profiles tp ON tp.user_id = ts.teacher_id)
  + (SELECT COUNT(*) FROM teacher_school_departures d JOIN teacher_profiles tp ON tp.user_id = d.teacher_id
     WHERE d.reinstated_at IS NULL
       AND NOT EXISTS (SELECT 1 FROM teacher_schools ts WHERE ts.teacher_id = d.teacher_id AND ts.school_id = d.school_id))
  + (SELECT COUNT(*) FROM school_join_requests r JOIN teacher_profiles tp ON tp.user_id = r.teacher_id
     WHERE r.status = 'pending'
       AND NOT EXISTS (SELECT 1 FROM teacher_schools ts WHERE ts.teacher_id = r.teacher_id AND ts.school_id = r.school_id)
       AND NOT EXISTS (SELECT 1 FROM teacher_school_departures d WHERE d.teacher_id = r.teacher_id
                       AND d.school_id = r.school_id AND d.reinstated_at IS NULL))
  AS attendu,
  (SELECT COUNT(*) FROM teacher_school_materials) AS copie;   -- après la migration seulement
-- Et pour mémoire : SELECT COUNT(*) FROM teacher_profiles; (un enseignant sans rattachement, retrait ni demande n'a rien à copier)
```

## Ce qu'on a appris sur la codebase

- Lot C : `classroom/classrooms/_gaps.html.erb` (« Fiches à revoir », ADR-0101 §4.4) n'existe pas encore sur la base : la règle d'UDR-0127 §3.2 s'appliquera à la livraison de `remediation-ciblee` ; elle lira `@overview.courses` (avec `material_slug`) sans code de ce chantier.

- **Aucune policy ne lit la matière** : le catalogue est restreint par lecture (UDR-0077), un cours d'une autre matière reste ouvert et assignable par son adresse. Le chantier ne touche donc à aucun droit.
- **`teacher_classrooms` admet déjà plusieurs enseignants par classe** (unique `teacher_id, classroom_id`), et « Exercices assignés » montre toutes les assignations de la classe, avec un badge : deux enseignants d'une classe se voient déjà.
- **Le badge de matière des cartes du catalogue n'est plus masqué** pour l'enseignant : l'UDR-0077 §3.2 (R6) l'avait retiré, son amendement du 2026-10-06 (bis) l'a rétabli.
- `teacher_profiles` ne peut pas disparaître : elle porte `referral_token` (parrainage), `joined_via` et `onboarding_completed_at`.
- Les seeds (`db/seeds/development.rb`, `db/seeds/demo/saint_michel.rb`) et les fabriques de test créent `Orm::TeacherProfile` directement : ils doivent écrire `teacher_materials` dès le Lot 0, sinon un enseignant de démo n'a aucune matière.
- `ClassroomGapsQuery` (ADR-0101 §4.4) n'est pas encore codée : elle hérite des matières par les slugs des cours de la page de classe, sans code propre.

## Lot Z

- `teacher_profiles.material_id` retirée (`20261016170000`) : `bin/rails db:rollback` puis `db:migrate` repassent ; le retour remplit la colonne avec la première matière de l'établissement principal. La commande de l'ADR-0103 §7 (`grep -rn "teacher_profiles.material_id\|TeacherProfile.*material_id\|teacher_profile: :material" app db/seeds test/support`) ne trouve rien.
- La fabrique `create_teacher(school: nil)` ne crée plus de matière (aucune liste où la ranger) ; `create_join_request(materials:)` pose celle d'une demande en attente.
- `script/perf/dataset.rb` écrit une liste par enseignant et par demande en attente.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Matière par liaison enseignant-classe (option D de l'ADR-0103) | Bruit de la page de classe non encore constaté | à ouvrir si le porteur le constate |
| L'équipe ne peut pas corriger les matières d'un enseignant | Aucun besoin exprimé | — |
| Restreindre l'assignation aux matières de l'enseignant | Le catalogue est une lecture, pas un droit (UDR-0077) | — |
| Badge de matière sur « Fiches à revoir » (UDR-0127 §3.2) | Le bloc n'existe pas encore | `remediation-ciblee` |
| Un enseignant sans aucune liste (ni rattachement, ni retrait, ni demande au moment de la migration) rejoint un établissement sans matière ; son profil propose « Modifier » sur une ligne vide | Cas sans donnée à copier | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-19 (PR prête vers `Develop`, après la PR #250) |
| **PR** | branche `feature/enseignant-plusieurs-matieres`, partie de `feature/multi-etablissements-enseignant` |
| **ADR produits** | ADR-0103 |
| **UDR produits** | UDR-0125, UDR-0126, UDR-0127 |
