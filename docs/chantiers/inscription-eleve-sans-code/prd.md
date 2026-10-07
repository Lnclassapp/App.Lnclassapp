# PRD — Inscription des élèves sans code de classe

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

> Validé par le porteur le 2026-10-07, avec le développeur du chantier. Les choix marqués *(proposé)* ont été ajoutés par l'agent pour fermer une question que le grill n'avait pas couverte ; ils font partie de ce qui a été validé.

## 1. Contexte

Un élève ne crée son compte qu'avec le code de sa classe, saisi ou porté par un lien ; un élève dont aucun enseignant n'est sur Lnclass n'a donc aucune entrée (memo Q1). Ce chantier retire le code et donne **deux entrées** : l'**inscription standard** (DRENA → établissement → niveau → classe, puis nom complet, genre, numéro, code secret), où l'élève entre tout de suite dans la classe, et le **lien de classe**, qui porte un jeton remplaçable au lieu du code. En contrepartie, les enseignants de la classe, la direction et l'équipe voient les nouveaux arrivés et peuvent **retirer un élève**. Voir le [memo](memo.md), Q1 à Q15.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Visiteur (futur élève) | S'inscrire par la voie standard dans une classe active et non complète ; s'inscrire par un lien de classe valable, la classe déjà choisie ; quitter la classe du lien (« Ce n'est pas ta classe ? ») pour la voie standard | Saisir un code de classe ; choisir une classe archivée, complète, ou d'un établissement en brouillon ou désactivé ; s'inscrire avec un numéro qui a déjà un compte ; créer un compte sans classe (memo Q9) |
| Student sans classe active (classe archivée, ou retiré) | Choisir une nouvelle classe par le même choix, son établissement déjà proposé ; rejoindre une classe par son lien | Rejoindre par la voie standard une classe dont il a été retiré : seul le lien l'y ramène (memo Q7) |
| Student dans une classe active | Voir sa classe, sans code affiché | Rejoindre une autre classe : il est renvoyé vers son accueil (ADR-0040, inchangé) |
| Teacher de la classe | Copier et partager le lien de la classe ; **changer le lien** ; voir les nouveaux arrivés (marque « Nouveau », voie d'arrivée) ; **retirer un élève** | Agir sur une classe où il n'enseigne pas |
| SchoolStaff (direction) | Les mêmes gestes, sur les classes de **son seul établissement** | Agir sur un autre établissement |
| Team | Les mêmes gestes, sur toute classe | — |
| Parent | Rien ne change : il n'a pas de compte | — |

Règles d'autorisation. L'inscription est publique et refusée à toute personne connectée qui n'est pas un élève sans classe. L'entrée dans une classe reste sous `JoinPolicy`, qui perd la vérification du code et gagne le refus « retiré de cette classe » (levé par le lien). Les trois gestes de gestion (copier le lien, le changer, retirer un élève) passent par **une nouvelle policy**, qui accorde l'enseignant de la classe, la direction de l'établissement de la classe et l'équipe ; `TeachPolicy` ne suffit pas, elle ne connaît pas la direction.

## 3. Parcours utilisateur

### Chemin nominal — inscription standard

1. Le visiteur ouvre `/student-signup` (page d'accueil « Je suis élève », ou application).
2. Rubrique **Ta classe** : il choisit sa DRENA ; la liste de ses établissements actifs se charge ; il choisit son établissement ; la liste des niveaux qui y ont une classe active se charge ; il choisit son niveau ; la liste des classes actives de ce niveau se charge ; il choisit sa classe. Une classe complète est affichée désactivée, avec « Complète ».
3. Rubrique **Toi** : il tape son nom complet ; l'aperçu affiche « Nom : … · Prénom(s) : … » ; « Corriger » ouvre les deux champs séparés. Il choisit son genre et saisit son numéro, nettoyé en direct.
4. Rubrique **Code secret** : PIN et confirmation, concordance affichée en direct.
5. « Créer mon compte » : le compte est créé, l'élève entre **tout de suite** dans la classe (classe principale), sa voie d'arrivée est « standard », la session s'ouvre et il arrive sur son accueil avec « Bienvenue dans ta classe ! ».

### Chemin nominal — lien de classe

1. Le visiteur ouvre le lien reçu (`/c/<jeton>`).
2. La même page s'ouvre ; la rubrique Ta classe montre la classe, son établissement et son niveau déjà choisis (bandeau), avec « Ce n'est pas ta classe ? ».
3. Rubriques Toi et Code secret comme ci-dessus.
4. « Créer mon compte » : il entre dans la classe du lien ; voie d'arrivée « lien de classe ».

### Chemin nominal — élève déjà inscrit, sans classe

1. L'élève connecté dont la classe principale est archivée, ou qui a été retiré, voit sur son accueil « Choisis ta classe ».
2. Il ouvre `/students/classroom/new` : la même rubrique Ta classe, sa DRENA et son établissement déjà choisis ; il choisit son niveau et sa classe. Aucune autre rubrique.
3. « Rejoindre cette classe » : la nouvelle classe devient sa classe principale ; il arrive sur son accueil.
4. S'il ouvre un lien de classe : un seul bouton « Rejoindre cette classe », comme aujourd'hui.

### Chemin nominal — voir les arrivées et retirer un élève

1. Un enseignant de la classe (ou la direction, ou l'équipe) ouvre la page de la classe.
2. Dans la liste des élèves, chaque élève arrivé depuis moins de 7 jours *(proposé)* porte la marque « Nouveau » et sa voie d'arrivée (« Inscrit seul » ou « Par le lien »). Le titre de la liste compte les nouveaux.
3. Il ouvre le menu de la ligne et choisit « Retirer de la classe » ; une confirmation nomme l'élève et dit qu'il gardera son compte et son travail.
4. Il confirme : l'élève quitte la classe, la ligne disparaît, le compteur baisse. L'élève, à sa prochaine page, arrive sur son accueil sans classe, avec « Tu ne fais plus partie de cette classe. Choisis ta classe. » *(proposé)*.

### Chemin nominal — changer le lien

1. Sur la page de la classe, le bloc « Lien de la classe » montre « Copier le lien », « Partager sur WhatsApp » et, dans son menu, « Changer le lien ».
2. « Changer le lien » demande confirmation : « L'ancien lien ne marchera plus. »
3. Confirmé : un nouveau lien remplace l'ancien, pour tous ceux qui gèrent la classe ; l'ancien ouvre l'inscription standard avec l'alerte.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Classe complète, choisie malgré tout (envoi direct) | 403, alerte en tête du formulaire : « Cette classe est complète. » ; aucun compte créé |
| Classe archivée, ou d'un établissement en brouillon ou désactivé, ou absente du niveau choisi | 422, message sous le champ ; aucun compte créé |
| Établissement sans niveau, ou niveau sans classe active | La liste est remplacée par l'état « introuvable » : « Ta classe n'est pas encore sur Lnclass. Préviens ton enseignant ou la direction de ton établissement. » ; le bouton d'envoi reste désactivé |
| Nom complet d'un seul mot | 422, sous le champ : « Saisis ton nom et tes prénoms. » |
| Numéro déjà inscrit | 422, message existant « Ce numéro est déjà utilisé. », sans révéler le rôle |
| Lien de classe inconnu, changé, d'une classe archivée, ou **ancien lien à code** | La page standard s'ouvre avec l'alerte « Ce lien n'est plus valable. Choisis ta classe. » ; voie « standard » |
| Lien d'une classe complète | La page du lien s'ouvre avec l'alerte « Cette classe est complète. » et sans formulaire |
| « Ce n'est pas ta classe ? » depuis un lien | La page standard s'ouvre sans classe ; voie « standard » |
| Élève retiré d'une classe qui la choisit par la voie standard | 403, alerte neutre : « Tu ne peux pas rejoindre cette classe. Demande son lien à ton enseignant. » |
| Élève retiré qui ouvre le lien de cette classe | Il la rejoint ; le retrait est levé ; il porte de nouveau « Nouveau » |
| Élève dans une classe active qui ouvre `/student-signup`, `/students/classroom/new` ou un lien | Renvoyé vers son accueil ; `POST` → 403 avec « Tu es déjà inscrit dans une classe. » |
| Enseignant, direction ou équipe connectés qui ouvrent l'inscription ou un lien | Renvoyés vers leur accueil ; `POST` → 403 |
| Retrait d'un élève déjà parti (deux gestes simultanés) | Le second réussit sans erreur ; un seul départ enregistré |
| Retrait par un enseignant d'une autre classe, ou une direction d'un autre établissement | 404 (la classe ne lui existe pas) |
| Ancienne adresse `/join` | Redirigée vers `/student-signup` *(proposé)* |
| Plus de 5 inscriptions par minute et par adresse | 429 re-rendu dans le formulaire (règle existante de l'inscription) |
| Plus de 10 ouvertures de lien, ou 30 chargements de liste, par minute et par adresse | 429 ; la liste montre l'état d'erreur avec « Réessayer » |
| Sans JavaScript | Les quatre listes se chargent par envoi de la page, une étape à la fois ; pas d'aperçu en direct ; le serveur découpe le nom |

## 4. Critères d'acceptation

Formulés de manière vérifiable. Chacun devient un test. Identifiants `IL-NN`.

```gherkin
# IL-01 — inscription standard
Étant donné la classe active « 3e 2 » du « Lycée Moderne de Cocody », DRENA « Abidjan 1 », niveau « 3e », non complète
Quand un visiteur choisit cette DRENA, cet établissement, ce niveau, cette classe,
  tape « KOUASSI Aya Marie », choisit « Féminin », saisit un numéro libre et un code secret confirmé
Alors un compte élève est créé avec le nom « KOUASSI » et les prénoms « Aya Marie »
Et la « 3e 2 » est sa classe principale active, sans attente
Et sa voie d'arrivée est « standard »
Et il arrive sur son accueil avec « Bienvenue dans ta classe ! »

# IL-02 — plus de code de classe
Quand un visiteur ouvre /student-signup
Alors la page ne contient aucun champ « Code de classe »
Et les rubriques apparaissent dans l'ordre : Ta classe, Toi, Code secret
Et /join redirige vers /student-signup
Et aucune page de l'élève, de l'enseignant, de la direction ni de l'équipe n'affiche de code de classe

# IL-03 — une classe sans enseignant accepte l'élève
Étant donné une classe active où aucun enseignant ne s'est déclaré
Quand un visiteur s'y inscrit par la voie standard
Alors il y entre tout de suite

# IL-04 — la liste suit les choix
Quand le visiteur choisit un établissement
Alors seuls les niveaux qui ont une classe active cette année dans cet établissement sont proposés
Quand il choisit un niveau
Alors seules les classes actives de ce niveau dans cet établissement sont proposées
Et chaque classe ne montre que son nom, jamais son effectif, un enseignant ni un élève

# IL-05 — classe complète
Étant donné une classe dont l'effectif atteint son plafond
Alors elle est affichée désactivée avec « Complète » dans la liste
Quand le formulaire est envoyé pour cette classe
Alors la page est re-rendue en 403 avec « Cette classe est complète. » et aucun compte n'est créé

# IL-06 — classe introuvable
Étant donné un établissement actif sans classe active au niveau « 6e »
Quand le visiteur choisit ce niveau, ou un établissement sans aucune classe
Alors la liste est remplacée par « Ta classe n'est pas encore sur Lnclass. Préviens ton enseignant ou la direction de ton établissement. »
Et le bouton « Créer mon compte » est désactivé

# IL-07 — classe hors liste
Quand le formulaire est envoyé avec une classe archivée, d'un autre niveau, d'un autre établissement,
  ou d'un établissement en brouillon ou désactivé
Alors la page est re-rendue en 422 et aucun compte n'est créé

# IL-08 — lien de classe
Étant donné la classe « 3e 2 » et son lien
Quand un visiteur ouvre ce lien
Alors la classe, son établissement et son niveau sont affichés, déjà choisis
Et le lien ne contient ni code de classe ni identifiant de la classe
Quand il complète nom complet, genre, numéro et code secret
Alors la « 3e 2 » est sa classe principale et sa voie d'arrivée est « lien de classe »

# IL-09 — lien qui n'est plus valable
Étant donné un lien de classe inconnu, un lien changé, le lien d'une classe archivée, ou un ancien lien /c/kfm37
Quand un visiteur l'ouvre
Alors la page standard s'affiche avec « Ce lien n'est plus valable. Choisis ta classe. »
Et une inscription faite depuis cette page a la voie « standard »

# IL-10 — « Ce n'est pas ta classe ? »
Quand un visiteur arrivé par un lien choisit « Ce n'est pas ta classe ? » puis s'inscrit dans une autre classe
Alors sa voie d'arrivée est « standard »

# IL-11 — changer le lien
Étant donné un enseignant de la « 3e 2 » sur la page de sa classe
Quand il choisit « Changer le lien » et confirme
Alors le bloc montre un nouveau lien
Et l'ancien lien ouvre la page standard avec « Ce lien n'est plus valable. Choisis ta classe. »
Et un second enseignant de la « 3e 2 » voit le même nouveau lien

# IL-12 — qui gère le lien et la liste
Alors un enseignant de la classe, la direction de son établissement et l'équipe peuvent copier le lien, le changer et retirer un élève
Et un enseignant qui n'enseigne pas dans la classe, comme la direction d'un autre établissement, reçoit 404 sur ces trois gestes
Et un élève reçoit 403

# IL-13 — nouveaux arrivés
Étant donné un élève entré dans la « 3e 2 » il y a 2 jours par la voie standard, et un autre il y a 10 jours par le lien
Quand un enseignant de la classe ouvre la liste des élèves
Alors le premier porte « Nouveau » et « Inscrit seul »
Et le second ne porte pas « Nouveau » et porte « Par le lien »
Et le titre de la liste annonce « 1 nouveau »

# IL-14 — retirer un élève
Étant donné l'élève Koffi dans la « 3e 2 »
Quand un enseignant de la classe choisit « Retirer de la classe » sur sa ligne et confirme
Alors Koffi n'est plus dans la liste et l'effectif baisse d'un
Et Koffi garde son compte, ses sessions et ses résultats
Et Koffi, à sa prochaine page, arrive sur son accueil sans classe avec « Tu ne fais plus partie de cette classe. Choisis ta classe. »

# IL-15 — l'élève retiré ne revient pas par la voie standard
Étant donné Koffi retiré de la « 3e 2 »
Quand il choisit la « 3e 2 » dans « Choisis ta classe »
Alors la page est re-rendue en 403 avec « Tu ne peux pas rejoindre cette classe. Demande son lien à ton enseignant. »
Quand il choisit la « 3e 3 »
Alors la « 3e 3 » devient sa classe principale

# IL-16 — l'élève retiré revient par le lien
Étant donné Koffi retiré de la « 3e 2 »
Quand il ouvre le lien de la « 3e 2 » et choisit « Rejoindre cette classe »
Alors la « 3e 2 » redevient sa classe principale et il porte de nouveau « Nouveau »
Quand il en est retiré une seconde fois
Alors la voie standard lui refuse de nouveau la « 3e 2 »

# IL-17 — élève dont la classe est archivée
Étant donné une élève dont la classe principale est archivée, connectée
Alors son accueil propose « Choisis ta classe », sa DRENA et son établissement déjà choisis
Quand elle choisit un niveau et une classe active
Alors cette classe devient sa classe principale, sans nouveau compte, et l'ancienne adhésion est close

# IL-18 — élève déjà dans une classe active
Étant donné un élève dans une classe active
Quand il ouvre /student-signup, /students/classroom/new ou un lien de classe
Alors il est renvoyé vers son accueil
Et un POST reçoit 403 avec « Tu es déjà inscrit dans une classe. »

# IL-19 — numéro déjà inscrit
Étant donné un compte existant (enseignant, élève ou direction) sur le numéro 0700000001
Quand un visiteur s'inscrit avec ce numéro
Alors la page est re-rendue en 422 avec « Ce numéro est déjà utilisé. » sous le champ
Et aucune adhésion n'est créée

# IL-20 — nom complet, numéro, code secret
Alors le nom complet, le nettoyage du numéro et la concordance du code secret se comportent
  comme les critères IE-03, IE-04, IE-05, IE-17 et IE-19 du chantier inscription-enseignant, avec le tutoiement

# IL-21 — retraits simultanés
Quand un enseignant et la direction retirent le même élève au même moment
Alors un seul départ est enregistré et aucun des deux ne voit d'erreur

# IL-22 — élèves existants
Étant donné des élèves inscrits avant le chantier par le code
Après la mise à jour de la base
Alors leur classe principale est inchangée, leur voie d'arrivée vaut « code »
Et chaque classe active a un lien

# IL-23 — débit
Quand une même adresse envoie une 6e inscription dans la minute
Alors la page est re-rendue en 429 et aucun compte n'est créé
```

## 5. Modélisation préliminaire

Établie après exploration du code existant (contexte `classroom`, avec `identity` pour le compte et `school` pour les listes).

| Couche | Éléments prévus |
|---|---|
| Domaine | `UseCases::Classroom::JoinWithCode` devient **`RegisterStudent`** : la classe est donnée par son `public_id` choisi dans la cascade, ou par le jeton du lien ; même transaction (verrou de la classe, policy, compte, adhésion principale, session). `JoinAsStudent` reçoit la classe de la même façon. `Policies::Classroom::JoinPolicy` : retire `join_code_revoked`, ajoute `removed_from_classroom` (ignoré quand l'entrée vient du lien). Nouveaux use cases **`RemoveStudent`** et **`ChangeClassroomLink`**, sous une nouvelle policy `ManageClassroomMembersPolicy` (enseignant de la classe, direction de l'établissement, équipe). Nouvelle entité-valeur de la voie d'arrivée de l'élève (`standard`, `link`, `code`). DTO `StudentRegistrationInput` : `full_name`, `last_name`/`first_name` (correction), `gender`, `contact`, `pin`, `pin_confirmation`, `classroom_public_id`, `link_token` ; il réutilise `Entities::Identity::FullName` du chantier enseignant. Ports : `ClassroomRepositoryPort` perd `lock_by_join_code` et `taken_join_codes`, gagne `lock_by_public_id`, `lock_by_link_token`, `rotate_link_token` ; `MembershipRepositoryPort` gagne `remove`, `removed_from?` et la voie sur `add_primary`. `Entities::Classroom::JoinCode` disparaît. |
| Infrastructure | Migration : `classrooms.link_token` (12 caractères hexadécimaux tirés par la base, unique, `CHECK` de format — forme des jetons de l'ADR-0082) ; `classroom_students.joined_via` (`CHECK` sur les trois voies, reprise à `code`), `removed_at`, `removed_by_id`. Retrait de `classrooms.join_code` et `join_code_rotated_at` dans le **dernier** lot. Nouvelles queries de lecture pour la cascade : niveaux d'un établissement, classes d'un niveau (nom, `public_id`, complète ou non). `JoinPreviewQuery` lit par jeton. `ClassroomOverviewQuery`, `ClassroomHeaderQuery`, `StudentHomeQuery`, `SchoolDetailQuery` et la page de classe de la direction : le lien au lieu du code, `joined_at` et la voie sur chaque élève. `GenerateMissingClassrooms`, `ImportSchools` et la création de classe ne tirent plus de code. |
| Delivery | `GET/POST /student-signup` ; `GET/POST /c/:token` (le paramètre change de nature) ; `GET/POST /students/classroom/new` ; `GET /schools/:school_public_id/levels` et `GET /schools/:school_public_id/levels/:level_slug/classrooms` (frames de la cascade, limités en débit) ; `PATCH /classrooms/:public_id/link` ; `DELETE /classrooms/:classroom_public_id/students/:student_public_id`. **Retirés** : `GET/POST /join` (redirigé). `/drenas/:drena_public_id/schools` inchangé. |
| UI | Page d'inscription élève en trois rubriques (Ta classe → Toi → Code secret), cascade de quatre listes, bandeau de la classe choisie par lien, alerte « lien plus valable », état « introuvable ». Accueil de l'élève sans classe et page « Choisis ta classe ». Page de classe (enseignant, équipe) et page de classe de la direction : bloc « Lien de la classe » à la place du code, marque « Nouveau » et voie d'arrivée dans la liste, « Retirer de la classe » avec confirmation. Fiche d'établissement de l'équipe et écrans de création de classe : plus de code. Contrôleurs Stimulus du nom complet, du numéro et de la concordance : ceux du chantier enseignant, réutilisés. Un contrôleur de cascade, sur le modèle de celui des établissements d'une DRENA. |

**Dépendance.** Ce chantier réutilise `FullName`, les trois contrôleurs Stimulus et la forme des jetons de `inscription-enseignant`, dont seul le Lot 0 est écrit. Le Lot 0 d'ici ne part qu'une fois les lots B et C de l'enseignant fusionnés dans la branche de base.

## 6. Décisions rattachées

- [ADR-0083](../../decisions/adr/0083-inscription-eleve-sans-code-de-classe.md) *(Accepté)* — l'élève entre dans une classe choisie ou donnée par un lien à jeton remplaçable, sans code ; le retrait d'un élève, sa mémoire et la voie d'arrivée. Amende ADR-0041 (code d'adhésion), ADR-0040 (changement de classe), ADR-0065 (la direction agit sur un élève).
- [UDR-0079](../../decisions/udr/0079-inscription-eleve-sans-code-de-classe.md) *(Accepté)* — page d'inscription élève, cascade, lien de classe, nouveaux arrivés et retrait. Remplace UDR-0009.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Entrées d'inscription pour un élève sans code | 0 | 1 (standard) | |
| Champs à remplir, inscription standard | — (impossible) | 9 (DRENA, établissement, niveau, classe, nom complet, genre, numéro, PIN, confirmation) | |
| Champs à remplir, par lien | 6 (nom, prénoms, genre, numéro, PIN, confirmation) | 5 (nom complet, genre, numéro, PIN, confirmation) | |
| Écrans qui affichent un code de classe | à compter au Lot 0 | 0 | |
