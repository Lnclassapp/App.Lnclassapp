# Memo — Un élève change de classe ou d'établissement en cours de scolarité

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage — en attente des réponses du porteur (questions 1 à 9) |
| **Ouvert le** | 2026-10-16 *(reporté le 2026-09-28, relancé avec les vagues V2 à V6)* |
| **Branche** | `docs/cadrage-changement-etablissement-eleve` (cadrage) ; `feature/changement-etablissement-eleve` (code) |
| **Programme** | `refonte-application` — hors vague, ligne du backlog de [`docs/chantiers/README.md`](../README.md#backlog) ; recoupe le « changement de classe par l'enseignant ou l'équipe » de `vie-de-la-classe` (V3, [feuille de route §5](../refonte-application/feuille-de-route.md#v3--suivi-pédagogique-enseignant)) |

Décisions : [ADR-0095](../../decisions/adr/0095-l-eleve-change-lui-meme-de-classe-et-d-etablissement.md) · [UDR-0101](../../decisions/udr/0101-profil-eleve-ligne-classe-vers-changer-de-classe.md) · [UDR-0102](../../decisions/udr/0102-changer-de-classe-choix-et-confirmation.md) · [UDR-0103](../../decisions/udr/0103-historique-eleve-periode-de-chaque-classe.md) — toutes « Proposé ».

---

## Le problème

Un élève qui a une classe active ne peut rejoindre aucune autre classe. `JoinAsStudent` le refuse (« Tu es déjà inscrit dans une classe »), par la cascade comme par le lien `/c/<jeton>`, et « Choisis ta classe » le renvoie à l'accueil. La seule sortie est qu'une personne qui gère son **ancienne** classe (enseignant, direction, équipe) le retire ; il choisit alors sa nouvelle classe. Or la plupart des classes n'ont ni enseignant ni direction sur Lnclass : l'élève qui déménage, qui change d'établissement ou qui s'est trompé de classe à l'inscription reste bloqué dans une classe qui n'est plus la sienne.

### Inventaire des règles d'adhésion (2026-10-16, `Develop`)

**Table `classroom_students`** (ADR-0040, ADR-0085) : une ligne par élève et par classe (unique `(classroom_id, student_id)`), jamais supprimée. `primary` ; `joined_at` ; `left_at` (départ) ; `joined_via` ∈ `standard`, `link`, `code` ; `removed_at` et `removed_by_id` (retrait, seulement si `left_at`). Index partiel : une seule adhésion `primary` sans `left_at` par élève.

| Événement | Écriture | L'élève ensuite |
|---|---|---|
| Inscription (`RegisterStudent`) | adhésion `primary`, voie `standard` ou `link` | dans sa classe |
| Retrait par l'enseignant de la classe, la direction ou l'équipe (`RemoveStudent`) | `left_at` + `removed_at` + `removed_by_id` | accueil « Choisis ta classe » ; peut entrer dans **toute** classe, sauf celle-ci (sauf par son lien) |
| Archivage de la classe (`ArchiveClassroom`, ADR-0088) | rien sur l'adhésion | accueil « Choisis ta classe » ; l'adhésion n'est close qu'à son prochain choix ; la restauration le ramène |
| Choix d'une classe sans classe active (`JoinAsStudent`) | `leave_primary` (`left_at`) sur l'ancienne, `add_primary` sur la nouvelle, même transaction ; une ancienne ligne de la même classe est **rouverte** | dans la nouvelle classe |
| Anonymisation (ADR-0036) | `leave_all` | — |
| Élève à classe active qui choisit une autre classe ou ouvre un autre lien | **refus** `already_enrolled` | bloqué |

**Choix de classe** : `ClassPicker` (concern) et le partial `_class_picker` servent l'inscription et « Choisis ta classe » (UDR-0091) : DRENA → établissement → niveau → classe, classes actives de l'**année en cours** seulement ; `ClassroomDesignation` revérifie la classe côté serveur ; `JoinPolicy` refuse classe archivée, complète, ou retiré sans lien.

**Historique** : « Mon historique » (`StudentArchiveQuery`, UDR-0090) lit **toutes** les adhésions, quittées ou non (nom, niveau, établissement, année), et les exercices terminés par `student_id`. Il ne montre ni l'entrée ni la sortie d'une classe.

**Quand un élève quitte sa classe** (`left_at` posé, retrait ou changement) :

- toutes les lectures « présents » l'écartent (liste et effectif de la classe, suivi des devoirs, rapports, accueils enseignant et direction, « Travail des élèves ») : elles filtrent `left_at IS NULL` ;
- ses séances (`exercise_sessions.student_id`, `classroom_assignment_id`), ses badges et ses lacunes de remédiation (`knowledge_gaps.student_id`) restent à lui ; ses devoirs rendus ne comptent plus dans le taux de rendu de l'ancienne classe (règle « présents », ADR-0072 §4.4) ;
- la direction de l'ancien établissement le voit dans « Anciens élèves » avec ses résultats obtenus chez elle (`DepartedStudentsQuery`) ;
- son profil perd les lignes Classe et Établissement ; son accueil lui propose « Choisis ta classe ».

**Trouvé en chemin** : `Membership#classroom_active?` ne lit que `classrooms.status`, pas `school_year`. À la rentrée 2027, un élève dont la classe 2026-2027 n'a pas été archivée sera bloqué comme ci-dessus : « déjà inscrit », alors que la cascade ne lui propose que des classes 2027-2028.

## Pour qui

- **Student**, au moment où il change d'établissement (déménagement, mutation d'un parent, réorientation), où il change de classe dans son établissement, ou quand il découvre qu'il s'est inscrit dans la mauvaise classe.
- Indirectement : l'**enseignant** des deux classes (listes et suivis justes), la **direction** des deux établissements (effectifs, « Anciens élèves »).

## Pourquoi maintenant

- L'inscription en libre-service (ADR-0085, en production) multiplie les erreurs de classe à l'inscription, sans moyen de les corriger seul.
- Le porteur relance les vagues V2 à V6 ; ce chantier, reporté le 2026-09-28, est le plus petit pas qui débloque un élève sans attendre que ses enseignants ou sa direction soient sur Lnclass.
- Il désamorce le blocage de la rentrée 2027 (ci-dessus) avant qu'il ne touche tous les élèves en même temps.

## Hors périmètre

- **Plusieurs classes à la fois** (cours du soir, adhésions `primary = false`) : `multi-classes-eleve`, V3, Q5 de la feuille de route.
- **Changement de classe à l'initiative de l'enseignant, de la direction ou de l'équipe** (« déplacer cet élève vers… ») : le retrait existant suffit ; un geste de déplacement par un tiers attend `vie-de-la-classe` (V3).
- **Validation par la nouvelle direction ou le nouvel enseignant**, demande en attente (voir question 2).
- **Notification** de l'ancien enseignant ou de la direction (pas de canal : `notifications-push` au backlog).
- **Transfert ou copie des résultats** vers la nouvelle classe ; le nouvel enseignant ne voit pas les résultats obtenus ailleurs.
- **Passage de classe à la rentrée** (reconduction, archivage de fin d'année, lecture de l'année scolaire dans `classroom_active?`) : `vie-de-la-classe`, Q8 de la feuille de route.
- **Matricule MENA**, dossier scolaire, certificat de radiation : `espace-direction` (V2 complète).
- **Quota de changements** par élève et par an (voir question 7).
- **Écran d'équipe** listant les changements : la trace d'audit suffit pour ce chantier.

## Ce que le grill a révélé

> Grill tenu par l'agent de cadrage sur le code de `Develop` ; **réponses du porteur attendues**. Chaque ligne donne la recommandation retenue par défaut dans l'ADR-0095 et les UDR : une réponse différente les change avant tout code.

| # | Question posée au porteur | Recommandation | Conséquence sur le chantier |
|---|---|---|---|
| 1 | **Qui déclenche le changement ?** L'élève, l'ancien établissement (enseignant, direction), le nouveau, ou l'équipe ? | **L'élève lui-même**, depuis la ligne « Classe » de son profil. L'équipe garde le retrait existant pour les cas de support. Ni l'ancien ni le nouvel enseignant ne déplacent un élève | Un use case élève `ChangeClassroom` (ADR-0095 §4.1) ; entrée dans le profil (UDR-0101) ; aucun écran enseignant ni direction |
| 2 | **La nouvelle direction (ou le nouvel enseignant) valide-t-elle l'arrivée ?** | **Non.** Entrée immédiate, comme l'inscription (ADR-0085) : la plupart des établissements n'ont pas de direction sur Lnclass, une demande en attente bloquerait l'élève. Protection a posteriori : marque « nouveau » 7 jours et retrait | Pas de table de demandes, pas d'écran de validation ; `JoinPolicy` inchangée |
| 3 | **Que deviennent ses résultats ?** | **Ils suivent l'élève**, sans copie ni transfert : historique, badges, progrès, exercices à revoir. Le nouvel enseignant ne voit que ce qui est fait dans sa classe ; l'ancienne direction les garde dans « Anciens élèves » | Aucune migration ; confirmation qui le dit (UDR-0102 §3.2) |
| 4 | **Que devient la classe d'origine ?** Retrait, simple départ, ou adhésion gardée ? | **Simple départ** : `left_at` posé, **sans** `removed_at`. L'élève disparaît de la liste, des suivis et du taux de rendu de l'ancienne classe ; il peut y revenir plus tard par la voie standard (la même ligne est rouverte). L'ancien enseignant n'est pas prévenu | ADR-0095 §4.2 ; aucune colonne `left_reason` ; trace `classroom.student_moved` pour distinguer le départ volontaire |
| 5 | **Changer de classe dans le même établissement** (erreur à l'inscription, 2nde A → 2nde C) : même geste ? | **Oui**, même use case et même écran, nommé « Changer de classe » ; changer d'établissement passe par « Changer » de l'étape 1 | Le chantier couvre les deux ; UDR-0102 part de l'établissement actuel replié |
| 6 | **Le lien `/c/<jeton>` d'une autre classe**, ouvert par un élève déjà inscrit : refus comme aujourd'hui, ou proposition de changer ? | **Proposer** : le lien mène à la page de confirmation du changement. C'est le moyen naturel pour un nouvel enseignant d'accueillir un élève qui arrive | Lot C ; `JoinsController#new` redirige vers la confirmation (UDR-0102 §3.3) |
| 7 | **Quels garde-fous** contre les allers-retours ou un compte prêté ? Quota annuel ? | **Confirmation obligatoire**, débit de 5 envois par minute et par compte, trace d'audit `classroom.student_moved`, **pas de quota** : un abus se voit dans le journal et se traite par le retrait | ADR-0095 §4.4 ; une action d'audit de plus |
| 8 | **Prévenir l'ancien enseignant et la direction** du départ ? | **Non dans ce chantier** : aucun canal n'existe. À reprendre avec `notifications-push` | Coût consenti écrit dans l'ADR-0095 §5 |
| 9 | **Classe d'une année passée encore active** (rentrée 2027) : la traiter ici ? | **Non** : c'est `vie-de-la-classe` (archivage de fin d'année, Q8). Mais ce chantier débloque déjà l'élève : il peut changer lui-même vers une classe de l'année | Hors périmètre ; signalé dans la feuille de route au moment de `vie-de-la-classe` |

## Cas limites identifiés

- **Classe d'arrivée = classe actuelle** : refusée (`same_classroom`) ; la case est désactivée et marquée « Ta classe » dans la cascade.
- **Classe d'arrivée complète ou archivée entre la confirmation et l'envoi** : refus de `JoinPolicy` sous verrou ; l'élève reste dans sa classe actuelle.
- **Élève retiré de la classe visée** : refus par la cascade, accepté par le lien (ADR-0085 §4.3).
- **Retour dans une ancienne classe** : la même ligne est rouverte (`joined_at` à la date du retour, `joined_via` de la voie du retour) ; aucun doublon.
- **Deux envois simultanés** (double tap, deux onglets) : le verrou de la classe et l'index partiel garantissent une seule adhésion active ; le second échoue proprement (`:conflict`) ou ne change rien.
- **Séance commencée dans l'ancienne classe** et terminée après le départ : elle garde son assignation, entre dans l'historique, ne compte plus pour l'ancienne classe.
- **Lacunes de remédiation en attente** : elles suivent l'élève (par `student_id`) et restent à revoir.
- **Élève sans classe active** qui ouvre « Changer de classe » : renvoyé à « Choisis ta classe » (`JoinAsStudent`).
- **Lien de sa propre classe** ouvert par l'élève : accueil, comme aujourd'hui.
- **Établissement d'arrivée inactif** : la cascade ne le propose pas ; le lien d'une de ses classes est un lien mort (ADR-0085 §4.1).
- **Restauration de l'ancienne classe** archivée après le départ : l'élève n'y revient pas (son adhésion est close), contrairement à l'élève resté sans choisir (ADR-0088).
- **Deux classes la même année** dans l'historique : distinguées par leur période (UDR-0103).

## Questions encore ouvertes

- Les questions 1 à 9 ci-dessus, à trancher par le porteur avant le Lot 0.
- Faut-il, plus tard, un écran d'équipe des changements (lecture de `classroom.student_moved`) ? Hors périmètre ici.
