# Journal — Un élève change de classe ou d'établissement

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-09-28 | Chantier reporté (porteur) | Priorité à la V2 simple | — |
| 2026-10-16 | Chantier relancé avec les vagues V2 à V6 ; cadrage seul (memo, PRD, ADR, UDR, plan), code après validation du porteur | Demande du porteur | — |
| 2026-10-16 | Recommandation : l'élève déclenche lui-même, sans validation ; départ = `left_at` sans retrait ; résultats sur l'élève ; aucune migration | Inventaire du code : tout existe sauf le geste ; moteur « aucune étape ne dépend d'un absent » de l'ADR-0085 | ADR-0095 (Proposé) |
| 2026-10-16 | Changement dans le même établissement inclus (même use case) | Les erreurs de classe à l'inscription en libre-service sont le cas le plus fréquent | ADR-0095 §4, à confirmer (question 5) |
| 2026-10-16 | Porteur : recommandations acceptées, l'élève seul change de classe ; ADR-0095 et UDR-0101 à 0103 acceptées | Réponses du porteur | ADR-0095 (Accepté) |
| 2026-10-16 | Lot 0 : la classe d'arrivée est verrouillée **avant** la lecture de la classe actuelle | Deux envois simultanés vers la même classe : le second lit la nouvelle classe et reçoit `same_classroom` au lieu de rouvrir la ligne et d'écrire une seconde trace | ADR-0095 §4.1 (note d'exécution) |
| 2026-10-16 | Lot 0 : trace `classroom.student_moved` avec les identifiants internes (`from_classroom_id`, `to_classroom_id`, `to_school_id`, `via`) | Les identifiants publics de la classe quittée demandaient une lecture que le port des adhésions ne donne pas ; aucun port changé | ADR-0095 §4.1 (note d'exécution) |
| 2026-10-16 | Lot 0 : `ClassroomDesignation#designate` reprend « lien ou cascade » et le refus du lien mort ou archivé | Partagé par `JoinAsStudent` et `ChangeClassroom`, sans copie | — |
| 2026-10-16 | Lot 0 : la cascade accepte le scope `student_classroom_change` (`DrenaSchoolsController::PICKER_SCOPES`) | Les listes de la cascade nomment leurs champs d'après la page | — |
| 2026-10-16 | Lot A : la confirmation relit la classe visée (`ClassroomChangePreviewQuery`) et renvoie à « Changer de classe » une classe hors cascade (422), la classe actuelle (422) ou une classe complète (403) ; le retrait n'est dit qu'à l'envoi | Montrer la page sans rien écrire ; la garde reste `ChangeClassroom` | — |
| 2026-10-16 | Lot A : le rappel « Tu es en … » est le sous-titre de `ui_page_header` (`text-mute`), pas un paragraphe `text-sm` à part | Composant existant ; un seul écart de taille de texte | UDR-0102 §3.1 (écart mineur) |
| 2026-10-16 | Lot A : un seul test système (parcours JS cascade → confirmation → accueil) ; refus, sans JS, lien et rôles en tests contrôleur | Budget système de 15 s par chantier (ADR-0069 §9) | — |
| 2026-10-16 | Lot B : la ligne Classe réutilise la clé `student_information.change` (« Changer ») ; aucune clé nouvelle dans `identity/profiles.fr.yml` | La clé existait pour le Numéro | — |
| 2026-10-16 | Lot B : l'entrée par le profil est jouée au début du test système du Lot A, pas dans `profile_test.rb` | Budget système ; un seul démarrage de navigateur | — |
| 2026-10-16 | Lot C : `/c/<jeton>` d'une autre classe ouverte mène l'élève inscrit à la confirmation (303) ; sa propre classe, un lien mort ou celui d'une classe archivée le ramènent à l'accueil, comme avant | UDR-0102 §3.3 « comportements actuels » : l'élève inscrit n'était jamais renvoyé vers la cascade | — |
| 2026-10-16 | Lot C : couvert en test contrôleur, pas dans `test/system/classroom/join_test.rb` | Budget système ; la page de confirmation est déjà jouée dans le test système du Lot A | — |
| 2026-10-16 | Lot D : formats de date dans la locale de l'historique (`classrooms.day` « %-d %b », `day_year` « %-d %b %Y ») plutôt qu'un format `:short_day_month` global | Le format nommé par l'UDR-0103 n'existe pas ; la ligne d'exercice lit déjà le sien dans la même locale | UDR-0103 §3.2 (écart mineur) |
| 2026-10-16 | Lot D : couvert en tests contrôleur et query ; `test/system/classroom/student_archive_test.rb` inchangé | Budget système ; le test système existant passe avec la nouvelle ligne | — |
| 2026-10-16 | Clôture : l'année scolaire du détail de « Mes classes » ne se coupe plus à son tiret (`whitespace-nowrap`, clé `detail_html`) | Vu sur la capture à 390 px : « 2026- / 2027 » sur deux lignes | — |
| 2026-10-16 | Clôture : `origin/Develop` fusionnée (merge) avant la PR ; documentation seule, sans conflit | Règle de clôture | — |
| 2026-10-19 | Revues de la PR #252 (sécurité, échecs silencieux, tests) : la confirmation par lien compte dans le compteur de `/c/<jeton>` (10 par minute et par adresse, `JoinsController::LINK_RATE_LIMIT`) | La confirmation disait si un jeton ouvre une classe : un oracle de jeton sans limite | ADR-0085 §4.1 (même compteur) |
| 2026-10-19 | Revues : la trace `classroom.student_moved` garde l'adresse de la requête ; `leave_primary` dit s'il a clos une adhésion, et rien à quitter annule le changement (`no_active_classroom`) | ADR-0050, ADR-0080 ; un départ écrit sans adhésion close aurait ouvert une seconde classe sans trace juste | — |
| 2026-10-19 | Revues : course entre deux classes (`:conflict`) → « Ton changement n'a pas pu se faire. Réessaie. » (409) et un avertissement au journal (élève et classe visée, sans contact) ; la garantie « une seule classe active » est l'index `index_classroom_students_one_active_primary` | `already_member` (« déjà inscrit dans cette classe ») était faux pour une autre classe | — |
| 2026-10-19 | Revues : le lien d'une classe archivée dit son motif dès la confirmation (403 `classroom_archived`) ; l'envoi refusé faute de classe active mène à « Choisis ta classe » avec ce motif en toast | Même refus à la confirmation et à l'envoi | — |
| 2026-10-19 | Revues : tests ajoutés — résultats qui suivent l'élève (historique, suivis des deux classes), double envoi, classe archivée avant l'envoi, retour dans l'ancienne classe, classe actuelle complète, atomicité avec les vrais repositories, effets chez l'enseignant et la direction | Constats `pr-test-analyzer` | — |

## Ce qui a dérapé

- L'agent des lots A à D a été arrêté avant la clôture ; un second agent a repris la branche (5 commits, rien en cours), fusionné `Develop`, pris les captures, lancé `bin/ci-quiet` et ouvert la PR.
- Le test de query du Lot D lisait deux fois `40.days.ago` : sous charge, les deux appels tombaient de part et d'autre d'une seconde (rouge dans `bin/ci-quiet`). Un seul instant, lu une fois.
- Premier `bin/ci-quiet` : la suite système s'est effondrée (« tab crashed », 295 tests, machine partagée saturée). Relancée une fois (16 échecs), puis les fichiers en échec seuls (7 échecs) : toasts de 5 s expirés avant l'assertion, charge ≈ 50 sur 4 cœurs, dans des parcours que le chantier ne change pas (dont trois de `join_test.rb` : l'inscription d'un visiteur, que le Lot C laisse passer tel quel). Le test système du chantier et celui de l'historique passent.
- Les revues `security-reviewer`, `silent-failure-hunter` et `pr-test-analyzer` n'ont pas pu être lancées par la session de clôture ; le coordinateur les a lancées sur la PR #252 : aucun constat critique, six corrections et dix tests traités dans un commit (lignes du 2026-10-19).

## Ce qu'on a appris sur la codebase

- Le changement d'établissement était **déjà possible** en deux temps : retrait par l'ancienne classe (`RemoveStudent`), puis choix par l'élève (`JoinAsStudent`), qui accepte toute classe sauf celle du retrait. Le blocage ne tient qu'au refus `already_enrolled` de `JoinAsStudent`.
- `MembershipRepository#add_primary` rouvre la ligne existante d'une classe déjà quittée (et efface le retrait) : revenir dans une ancienne classe ne crée jamais de doublon.
- Toutes les lectures « présents » filtrent `left_at IS NULL` (une trentaine de requêtes) : un départ disparaît partout sans changer une seule lecture.
- `Membership#classroom_active?` ignore `school_year` : à la rentrée 2027, les élèves d'une classe 2026-2027 non archivée seront « déjà inscrits » et la cascade ne leur proposera que 2027-2028. Signalé au memo (question 9), hors périmètre.
- `exercise_sessions` porte `student_id` et `classroom_assignment_id`, jamais l'adhésion : les résultats suivent l'élève sans rien faire.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Prévenir l'ancien enseignant et la direction d'un départ | Aucun canal | `notifications-push` |
| Écran d'équipe des changements de classe | La trace d'audit suffit au démarrage | — |
| `classroom_active?` sans l'année scolaire | Relève de l'archivage de fin d'année | `vie-de-la-classe` (Q8 de la feuille de route) |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-16 (PR vers `Develop`, non fusionnée) |
| **PR** | [#252](https://github.com/Lnclassapp/App.Lnclassapp/pull/252) |
| **ADR produits** | ADR-0095 |
| **UDR produits** | UDR-0101, UDR-0102, UDR-0103 |
