# PRD — Fonctions de l'espace élève

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
>
> **Statut : proposé le 2026-10-02**, avec l'[ADR-0072](../../decisions/adr/0072-assignation-d-exercices-et-echeance-a-la-prochaine-seance.md) et les UDR [0061](../../decisions/udr/0061-carte-d-aide-et-faq.md), [0062](../../decisions/udr/0062-echeances.md) et [0063](../../decisions/udr/0063-pages-publiques-mission-confidentialite-cgu-cgv.md). La FAQ (`/aide`) est déjà construite (commit `189d7f92`, construction directe demandée par le porteur). Les points marqués **« à fournir »** ou **« ouvert »** (§8) bloquent le lot qui en dépend, pas les autres.

## 1. Contexte

La maquette V2 de l'accueil élève montre six fonctions absentes ; après le grill, ce chantier en garde deux, **les échéances** et **l'aide** (le paiement part dans `abonnement-mobile-money`, les annonces dans `annonces`, la durée est abandonnée). L'enseignant n'assigne plus qu'un exercice, pour la séance suivante, déduite de ses jours de séance dans la classe ; l'élève voit sa date limite et l'enseignant voit qui a rendu en retard (ADR-0072, UDR-0062). Un élève bloqué trouve une FAQ et une carte d'aide (UDR-0061), et quatre pages publiques disent ce qu'est Lnclass, ce qu'elle fait des données et ses conditions (UDR-0063), au nom de **Lnclass Côte d'Ivoire**.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| **Élève** (Student) | voir ses exercices triés par date limite, avec « À rendre … » ou « En retard · prévu … » ; faire un exercice même en retard ; ouvrir la carte d'aide et la FAQ | voir le retard ou le nom d'un autre élève (UDR-0011) ; ouvrir le suivi d'un exercice (403) ; renseigner des jours de séance |
| **Enseignant de la classe** (Teacher, `teacher_classrooms`) | assigner un exercice publié du niveau de la classe ; renseigner, modifier ou effacer **ses** jours de séance pour la classe ; voir les comptes et la liste nominative des rendus en retard de la classe | assigner un cours ou une fiche (`:invalid`) ; écrire les jours d'un autre enseignant ; agir sur une classe archivée (403) |
| **Autre enseignant** | — | voir le suivi ou assigner dans une classe qu'il n'enseigne pas (403) |
| **Équipe** (Team) | assigner un exercice (sans échéance : elle n'a pas de jours) ; voir le suivi et la liste nominative de toute classe | renseigner des jours de séance (`:forbidden`) |
| **Direction** (SchoolStaff) | lire « Travail des élèves » comme aujourd'hui (ADR-0065) | voir les retards ou la liste nominative des retardataires (403, Q12) |
| **Visiteur** (anonyme) | lire `/aide` et les pages publiques en ligne | — |

**Règles d'autorisation** (ADR-0028, une policy par use case, test de refus obligatoire) :

- `Policies::Classroom::AssignPolicy` (inchangée) : enseignant de la classe ou équipe, classe active.
- `Policies::Classroom::SetSessionDaysPolicy` (nouvelle) : l'enseignant de la classe, pour lui-même, classe active.
- `Policies::Classroom::FollowAssignmentPolicy` (nouvelle) : équipe ou enseignant de la classe, classe active ou archivée.
- Pages `/aide`, `/mission`, `/confidentialite`, `/conditions-utilisation`, `/conditions-vente` : `allow_unauthenticated_access`, aucune policy.

**Entité juridique** : **Lnclass Côte d'Ivoire**, éditeur du service et responsable du traitement des données (porteur, 2026-10-02, Q16). Adresse, RCCM et contact : à fournir.

## 3. Parcours utilisateur

### Chemin nominal A — l'enseignant assigne son premier exercice à une classe

1. M. Kouassi enseigne la SVT en 3ème B ; il n'a pas renseigné ses jours. Le lundi 5 octobre, il ouvre la page de la classe : le bloc « Jours de séance » dit « non renseignés ».
2. Dans « Cours », il ouvre « La reproduction », puis la fiche « La méiose » dans la classe.
3. Il touche « Assigner » sur l'exercice « Méiose — QCM » : une modale demande « Quels jours voyez-vous la 3ème B ? ».
4. Il coche lundi et jeudi, puis « Assigner ».
5. La modale se ferme ; la ligne montre « Assigné · Pour jeu. 8 oct. · Retirer » ; un toast dit « Méiose — QCM ajouté à 3ème B, à rendre jeudi 8 oct. ».
6. Il assigne un second exercice : un clic suffit, sans modale.

### Chemin nominal B — l'élève voit sa date limite

1. Le mercredi 7 octobre, Awa (3ème B) ouvre son accueil.
2. « Méiose — QCM » est en tête de « À faire », avec « À rendre demain » en ambre et le bouton principal « Commencer ».
3. Elle le termine le soir même : la ligne ne porte plus de date.

### Chemin nominal C — l'enseignant suit l'exercice

1. Le vendredi 9 octobre, M. Kouassi ouvre la page de la 3ème B : « Méiose — QCM · Pour jeu. 8 oct. · 18 faits, dont 3 en retard · 7 pas encore faits ».
2. Il touche la ligne : la page de suivi nomme les 3 élèves rendus en retard, avec la date de leur première session terminée.

### Chemin nominal D — l'élève cherche de l'aide

1. Awa touche « Besoin d'aide ? » dans l'en-tête de son accueil.
2. **Aujourd'hui** : la FAQ `/aide` s'ouvre ; elle déplie « J'ai oublié mon PIN ».
3. **Avec la carte** : sur téléphone, une carte monte du bas : « Questions fréquentes », « Chatter avec le support », « Appeler le service client » ; elle touche « Chatter avec le support », WhatsApp s'ouvre sur le numéro du support. Échap, la croix ou le fond referment la carte, et le focus revient sur « Besoin d'aide ? ».

### Chemin nominal E — un parent lit les pages publiques

1. Sur la homepage, il touche « Protection des données » dans le pied de page.
2. La page s'ouvre sans compte : un `h1`, un sommaire, des sections ; « Accueil » le ramène à la homepage.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| L'enseignant touche « Plus tard » dans la modale des jours | Exercice assigné **sans échéance** ; la modale reviendra à la prochaine assignation dans cette classe (Q11) |
| « Assigner » dans la modale sans aucun jour coché | 422 : « Cochez au moins un jour, ou choisissez « Plus tard ». », rien n'est écrit |
| Assignation le jour même d'une séance (jeudi, jours lundi et jeudi) | Échéance le lundi suivant, jamais le jour même |
| Un seul jour de séance (mercredi), assignation un mercredi | Échéance le mercredi suivant (+ 7 jours) |
| Assignation un dimanche (jours lundi et jeudi) | Échéance le lendemain lundi |
| L'enseignant modifie ses jours après coup | Les échéances déjà données ne bougent pas ; les assignations suivantes suivent les nouveaux jours |
| L'enseignant décoche tous ses jours sur la page de la classe | Jours « non renseignés » : la modale revient à la prochaine assignation |
| Deux enseignants dans la classe | Chacun ses jours ; l'échéance suit l'auteur de l'assignation |
| Un membre de l'équipe assigne | Pas de modale, pas d'échéance |
| L'enseignant retire sa déclaration de la classe, ou la direction le retire de l'établissement | Ses jours de séance pour ces classes sont effacés ; ses assignations gardent leur échéance |
| Vacances ou jour férié le jour de l'échéance | Ignorés : l'échéance tombe quand même (Q10) |
| Élève qui termine l'exercice le jour de l'échéance | À l'heure |
| Élève qui le termine le lendemain de l'échéance | « Rendu en retard » pour l'enseignant |
| Exercice terminé en retard puis refait | Reste « rendu en retard » (première session terminée) |
| Session de remédiation | Ne compte pas comme « fait » |
| Élève qui avait fait l'exercice depuis le catalogue avant qu'il soit assigné | « Pas encore fait » pour l'enseignant (session non rattachée, ADR-0048) ; terminé pour lui |
| Exercice sans échéance | Jamais en retard ; rangé après ceux qui ont une échéance ; pas de section « Rendus en retard » |
| Exercice désassigné (archivé) | Sort de « À faire » et du suivi, retard compris ; son adresse de suivi répond 404 |
| Élève arrivé dans la classe après l'échéance | **Ouvert** (§8) |
| Élève qui ouvre le suivi d'un exercice | 403 |
| Direction qui ouvre le suivi | 403 |
| Enseignant qui envoie un type `Course` ou `Essential` (requête forgée) | `:invalid`, 422, rien n'est écrit |
| Déploiement avec une assignation de cours ou de fiche en base | La migration s'arrête avec le nombre de lignes ; rien n'est modifié (Q7) |
| Numéro WhatsApp ou d'appel non configuré | Sa ligne n'apparaît pas dans la carte ; la FAQ y reste |
| Navigateur sans JavaScript | « Besoin d'aide ? » mène à `/aide` ; « Assigner » mène à la page du formulaire des jours |
| Page publique dont une donnée est « à fournir » | Pas en ligne : pas de route, pas de lien |

## 4. Critères d'acceptation

Chacun devient un test. Dates : octobre 2026 (lundi 5, jeudi 8, lundi 12), fuseau Africa/Abidjan.

```gherkin
# Domaine et données (ADR-0072)
Étant donné les types assignables
Quand on crée une assignation d'un cours ou d'une fiche essentielle
Alors le domaine refuse (Assignable lève ArgumentError ; AssignResource répond :invalid)
Et la base refuse une ligne dont assignable_type n'est pas « Exercise »

Étant donné une base qui contient une assignation de type « Course »
Quand la migration qui restreint les types est jouée
Alors elle échoue en donnant le nombre de lignes
Et la ligne est intacte

Étant donné un enseignant aux jours lundi et jeudi
Quand il assigne un exercice le lundi 5 octobre
Alors l'échéance est le jeudi 8 octobre
Quand il en assigne un autre le jeudi 8 octobre
Alors l'échéance est le lundi 12 octobre

Étant donné l'horloge fixée au samedi 10 octobre à 23 h 30 à Abidjan
Quand un enseignant aux jours lundi et jeudi assigne un exercice
Alors l'échéance est le lundi 12 octobre

Étant donné un exercice assigné le 5 octobre avec l'échéance du 8 octobre
Quand l'enseignant remplace ses jours par mardi et vendredi
Alors l'échéance de cet exercice reste le 8 octobre

Étant donné une échéance égale à la date de l'assignation, ou 8 jours après
Quand on l'écrit en base
Alors la contrainte classroom_assignments_due_on_within_a_week la refuse

# Assigner (UDR-0062 §3.4)
Étant donné un enseignant de la 3ème B sans jours de séance pour elle
Quand il touche « Assigner » sur un exercice de la fiche dans la classe
Alors une modale demande « Quels jours voyez-vous la 3ème B ? » avec six cases de « Lun. » à « Sam. »
Quand il coche lundi et jeudi et touche « Assigner » le lundi 5 octobre
Alors l'exercice est assigné avec l'échéance du jeudi 8 octobre
Et la ligne montre « Pour jeu. 8 oct. »
Et le toast dit « <exercice> ajouté à 3ème B, à rendre jeudi 8 oct. »
Et les autres « Assigner » de la page assignent sans modale

Étant donné un enseignant de la 3ème B sans jours de séance
Quand il touche « Plus tard » dans la modale
Alors l'exercice est assigné sans échéance
Et au prochain « Assigner » dans la 3ème B, la modale revient

Étant donné la modale des jours
Quand l'enseignant touche « Assigner » sans cocher de jour
Alors il reçoit 422 et le message « Cochez au moins un jour, ou choisissez « Plus tard ». »
Et aucune assignation n'est créée

Étant donné un membre de l'équipe
Quand il assigne un exercice à la 3ème B
Alors aucune modale ne s'ouvre et l'assignation n'a pas d'échéance
Quand il envoie des jours de séance
Alors il reçoit :forbidden et rien n'est écrit

Étant donné un enseignant de la 3ème B avec des jours renseignés
Quand il ouvre la page de la classe
Alors il voit « Vos jours de séance : lundi, jeudi » et « Modifier »
Quand il décoche tous les jours et enregistre
Alors le bloc dit « Jours de séance non renseignés »

Étant donné deux enseignants de la 3ème B, l'un aux jours lundi et jeudi, l'autre au mardi
Quand le second assigne un exercice le lundi 5 octobre
Alors l'échéance est le mardi 6 octobre

Étant donné un enseignant aux jours renseignés pour la 3ème B
Quand il retire sa déclaration de la 3ème B
Alors ses jours de séance pour la 3ème B sont effacés
Et l'échéance de ses assignations reste inchangée

# Accueil élève (UDR-0062 §3.1, §3.2)
Étant donné une élève de la 3ème B et un exercice non terminé dû le jeudi 8 octobre
Quand elle ouvre son accueil le mercredi 7 octobre
Alors la ligne porte « À rendre demain » en ton warning
Quand elle l'ouvre le lundi 5 octobre
Alors la ligne porte « À rendre jeudi » en ton neutral
Quand elle l'ouvre le jeudi 8 octobre
Alors la ligne porte « À rendre aujourd'hui » en ton warning
Quand elle l'ouvre le vendredi 9 octobre
Alors la ligne porte « En retard · prévu hier » en ton warning
Et l'exercice se démarre toujours

Étant donné une élève avec trois exercices non terminés : sans échéance assigné hier, dû le 12 octobre, dû le 8 octobre et commencé
Quand elle ouvre son accueil le 6 octobre
Alors l'ordre est : dû le 8, dû le 12, sans échéance
Et seul le premier porte le bouton principal

Étant donné une élève qui a terminé un exercice dû hier
Quand elle ouvre son accueil
Alors sa ligne ne porte aucune date et se range après les exercices non terminés

# Suivi de l'enseignant (UDR-0062 §3.5, ADR-0072 §4.4, §4.5)
Étant donné un exercice dû le 8 octobre dans une classe de 25 élèves présents
Et 15 élèves dont la première session rendue date du 8 octobre au plus tard
Et 3 élèves dont la première session rendue date du 9 octobre
Quand l'enseignant de la classe ouvre la page de la classe
Alors la ligne de l'exercice dit « 18 faits, dont 3 en retard · 7 pas encore faits »
Quand il ouvre son suivi
Alors la section « Rendus en retard » nomme ces 3 élèves avec « Fait le ven. 9 oct. »
Et les 7 élèves « pas encore faits » ne sont pas nommés

Étant donné un élève rendu en retard le 9 octobre puis qui refait l'exercice le 10
Quand l'enseignant ouvre le suivi
Alors l'élève reste dans « Rendus en retard », avec « Fait le ven. 9 oct. »

Étant donné un élève qui n'a terminé qu'une session de remédiation
Quand l'enseignant ouvre le suivi
Alors l'élève est compté « pas encore fait »

Étant donné un élève parti de la classe
Quand l'enseignant ouvre le suivi
Alors l'élève n'est compté nulle part

Étant donné un exercice assigné sans échéance
Quand l'enseignant ouvre son suivi
Alors aucun compte « en retard » ni section « Rendus en retard » n'apparaît

Étant donné un exercice désassigné
Quand l'enseignant ouvre l'adresse de son suivi
Alors il reçoit 404
Et l'exercice n'est plus dans « À faire » de ses élèves

# Refus de policy (FollowAssignmentPolicy, SetSessionDaysPolicy)
Étant donné un exercice assigné à la 3ème B
Quand une élève de la 3ème B ouvre son suivi
Alors elle reçoit 403
Quand un enseignant qui n'enseigne pas la 3ème B l'ouvre
Alors il reçoit 403
Quand la direction de l'établissement l'ouvre
Alors elle reçoit 403
Quand un visiteur anonyme l'ouvre
Alors il est renvoyé vers la connexion

Étant donné un enseignant qui n'enseigne pas la 3ème B
Quand il envoie des jours de séance pour la 3ème B
Alors il reçoit 403 et rien n'est écrit

Étant donné une classe archivée
Quand son enseignant envoie des jours de séance
Alors il reçoit 403

Étant donné une élève de la 3ème B
Quand elle ouvre « Ma classe » ou son accueil
Alors aucune page ne montre le nom ni le retard d'un autre élève

# Retrait de l'assignation de cours et de fiches (UDR-0062 §3.6)
Étant donné un enseignant
Quand il ouvre la page d'un cours du catalogue
Alors il ne voit pas « Assigner à mes classes »
Et l'adresse /courses/<slug>/assignments répond 404

Étant donné un enseignant sur le cours dans la classe
Alors il ne voit aucune bascule pour le cours ni pour ses fiches
Et chaque fiche mène à la fiche dans la classe

Étant donné un enseignant sur la fiche dans la classe
Alors il ne voit pas de bascule pour la fiche
Et chaque exercice a sa bascule

Étant donné l'enseignant d'une classe sans exercice assigné
Quand il ouvre la page de la classe
Alors il voit « Aucun exercice assigné » et le bloc « Cours » (si le porteur le valide, §8)

# FAQ (UDR-0061 §3.1, déjà construite)
Étant donné un visiteur anonyme
Quand il ouvre /aide
Alors il voit un seul h1 « Questions fréquentes » et toutes les questions, réponses repliées
Et « Accueil » mène à la homepage

Étant donné un élève connecté
Quand il touche « Besoin d'aide ? » sur son accueil
Alors /aide s'ouvre (tant que la carte n'existe pas)
Et « Accueil » le ramène à son accueil

Étant donné la FAQ
Alors les seuils cités (50 %, 70 %, 80 %, 100 %) viennent de Entities::Assessment::Grading

Étant donné le lot des échéances livré
Alors la FAQ contient « Que veut dire « En retard » ? »

# Carte d'aide (UDR-0061 §3.2 à §3.7)
Étant donné un élève sur un écran de 390 px
Quand il touche « Besoin d'aide ? »
Alors une feuille s'ouvre ancrée en bas, d'au moins 25 % de la hauteur, avec une poignée et une croix
Et elle montre « Questions fréquentes », « Chatter avec le support » et « Appeler le service client »
Et le focus est sur « Questions fréquentes »
Quand il appuie sur Échap
Alors la feuille se ferme et le focus revient sur « Besoin d'aide ? »

Étant donné un élève sur un écran de 1 280 px
Quand il touche « Besoin d'aide ? »
Alors une modale centrée s'ouvre avec les mêmes lignes

Étant donné la configuration du support avec le numéro WhatsApp 2250700000000
Alors la ligne WhatsApp mène à https://wa.me/2250700000000 dans un nouvel onglet
Et la ligne d'appel mène à tel:+<numéro d'appel>

Étant donné une configuration sans numéro WhatsApp
Alors la carte ne montre pas la ligne WhatsApp
Et la ligne « Questions fréquentes » reste

Étant donné la carte ouverte
Alors elle n'a aucun bouton de variante primary ni brand
Et aucune vue ni locale ne contient un numéro de support

# Pages publiques (UDR-0063)
Étant donné un visiteur anonyme
Quand il ouvre /mission, /confidentialite, /conditions-utilisation ou /conditions-vente une fois la page en ligne
Alors la page répond 200 sans connexion, sans le shell
Et elle a un seul h1, une h2 par section et le lien « Accueil » vers la homepage

Étant donné la politique de protection des données en ligne
Alors elle a un sommaire dont chaque lien mène à une h2
Et elle nomme « Lnclass Côte d'Ivoire » comme responsable du traitement
Et elle cite la loi n° 2013-450 comme cadre, sans affirmer de conformité

Étant donné la homepage
Alors son pied de page porte un lien vers chaque page publique en ligne, et vers elle seule

Étant donné la page /aide
Alors elle renvoie à la protection des données et aux conditions d'utilisation, une fois en ligne

Étant donné le fichier config/locales/communication/pages.fr.yml
Alors il ne contient ni « à fournir », ni « TODO », ni « XXX »

Étant donné une page dont le texte n'est pas validé
Alors sa route n'existe pas (404) et aucun lien n'y mène

Étant donné les conditions de vente
Alors elles ne sont pas en ligne tant que le chantier abonnement-mobile-money n'a pas fixé l'offre

# Garde-fous
Étant donné le code de app/
Alors aucun fichier ne passe « Course » ou « Essential » comme type assignable
Et app/domain/ ne référence ni ActiveRecord ni Orm::

Étant donné les vues du chantier
Alors aucune ne contient de #hex, d'attribut style, de valeur entre crochets ni de variante dark:
Et l'ambre (warning) n'y sert qu'aux échéances
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| **Domaine** | `Entities::Classroom::Assignable::TYPES = %w[Exercise]` ; `Entities::Classroom::Assignment` gagne `due_on` ; `Entities::Classroom::SessionDays` (valeur, `#next_after`) ; `Ports::Classroom::SessionDaysRepositoryPort` (`for`, `replace`) ; `Ports::Classroom::AssignmentRepositoryPort` (`create` écrit `due_on`, `resolve_assignable` réduit à `Exercise`) ; `Dtos::Classroom::AssignmentInput` gagne `weekdays` ; `Dtos::Classroom::SessionDaysInput` ; `UseCases::Classroom::AssignResource` (jours, échéance, transaction) ; `UseCases::Classroom::SetSessionDays` ; `Policies::Classroom::SetSessionDaysPolicy`, `Policies::Classroom::FollowAssignmentPolicy` |
| **Infrastructure** | Migrations : restriction de `assignable_type` (garde Q7), `classroom_assignments.due_on` et sa contrainte, table `classroom_session_days` (clé composite vers `teacher_classrooms`) ; `Orm::ClassroomSessionDay` ; `Repositories::Classroom::SessionDaysRepository` ; `AssignmentRepository` réduit ; `TeachingRepository#withdraw` et `#withdraw_all_in_school` retirent les jours ; queries `StudentHomeQuery` (`due_on`, ordre, `late_material_slugs`), `ClassroomOverviewQuery` (exercices assignés et comptes, cours de la classe), `AssignmentFollowUpQuery` (nouvelle), `ClassroomCourseQuery`, `ClassroomEssentialQuery`, `EssentialDetailQuery` (sans `Course`/`Essential`) ; suppression de `CourseAssignmentTargetsQuery` ; `config/support.yml` lu par `config_for` |
| **Delivery** | `Classroom::AssignmentsController#new` (modale des jours) et `#create` (jours, « Plus tard ») ; `Classroom::SessionDaysController#edit`, `#update` ; `Classroom::AssignmentFollowUpsController#show` ; suppression de `Classroom::CourseAssignmentsController` ; `Communication::HelpController#show` (fait) ; `Communication::PagesController` (`mission`, `privacy`, `terms`, `sales_terms`) ; routes dans `config/routes/classroom.rb` et `config/routes/communication.rb` |
| **UI** | `DueDateHelper` ; formats `date.formats.due_short` et `due_long` ; `classroom/assignments/_toggle` (`needs_session_days:`, date), `new` ; `classroom/session_days/edit` ; `classroom/classrooms/_session_days`, `_assigned_exercises`, `_courses` ; `classroom/assignment_follow_ups/show` ; `classroom/student_homes/_assigned_exercise` ; retrait des bascules de `classroom_courses/show`, `classroom_essentials/show`, de `catalog/courses/_role_actions`, de `classroom/course_assignments/` et de la carte « Cours assignés » de `student_classrooms/show` ; `ui_modal placement: :sheet`, classe `.dialog-sheet` ; `shared/_help_sheet` et `SupportHelper` ; `communication/help/show` (fait) ; `communication/pages/_page` et ses quatre vues ; pied de page de la homepage ; textes de la homepage (« des exercices ») ; locales `classroom/*.fr.yml`, `shared/help_sheet.fr.yml`, `communication/pages.fr.yml` ; contrôleurs Stimulus `modal` (retour du focus) et `autofocus` (`data-autofocus-first`) |

**Aucune table** pour l'aide et les pages publiques. **Une table** (`classroom_session_days`) et **une colonne** (`due_on`) pour les échéances.

## 6. Décisions rattachées

- [ADR-0072](../../decisions/adr/0072-assignation-d-exercices-et-echeance-a-la-prochaine-seance.md) — Seul un exercice s'assigne ; échéance = prochaine séance, figée à l'assignation (Proposé ; amende ADR-0048, 0071)
- [UDR-0061](../../decisions/udr/0061-carte-d-aide-et-faq.md) — Carte d'aide et FAQ (FAQ acceptée, carte proposée)
- [UDR-0062](../../decisions/udr/0062-echeances.md) — Échéances (Proposé ; amende UDR-0011, 0013, 0015, 0027, 0028, 0029, déprécie 0030)
- [UDR-0063](../../decisions/udr/0063-pages-publiques-mission-confidentialite-cgu-cgv.md) — Pages publiques : Mission, Protection des données, CGU, CGV (Proposé ; amende UDR-0061 §3.1, 0012)
- Brouillons des textes publics : [`pages-publiques.md`](pages-publiques.md)
- **Signalé, non modifié ici** : l'UDR-0058 annonce le retour de la durée d'un exercice, abandonnée (Q9) ; son amendement de phase 2 d'`interface-epuree` la retire et reprend l'UDR-0062 §3.3 (carte du haut, point ambre) et l'icône d'aide de l'UDR-0061.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes de l'accueil élève | mesurées au Lot 0 | inchangées à ± 1 (l'échéance est une colonne lue avec l'assignation) | |
| Temps serveur p95 de la page de la classe et du suivi, au volume de l'ADR-0067 | — | < 100 ms (ADR-0067) ; sinon `completed_at` entre dans l'`INCLUDE` de `index_exercise_sessions_handed_in` | |
| Requêtes du suivi d'un exercice | — | nombre fixe, quel que soit l'effectif | |
| Poids HTML de l'accueil élève (ADR-0067 : < 150 Ko) | 31,9 Ko (interface-epuree, Lot A) | < 150 Ko | |
| JavaScript ajouté (ADR-0051) | — | aucun contrôleur nouveau ; deux contrôleurs existants étendus | |
| Assignations avec échéance, un mois après livraison | 0 % | à observer (part des enseignants qui renseignent leurs jours) | |

## 8. Points ouverts

| Point | État | Bloque |
|---|---|---|
| Numéro d'appel, numéro WhatsApp, horaires et délai de réponse du support | **à fournir** (porteur) | la mise en ligne des lignes WhatsApp et appel (la carte peut sortir avec la FAQ seule) |
| Élève arrivé dans la classe après l'échéance : en retard dès son arrivée (règle générale, aucune donnée de plus), ou échéance comptée depuis son arrivée (`classroom_students.joined_at`) | **ouvert** | le lot des échéances (affichage élève, comptes du suivi) |
| Chemin de l'enseignant vers les exercices sans cours assignés : bloc « Cours » sur la page de la classe (cours publiés du niveau, de sa matière) — proposition de l'UDR-0062 §3.4 | **ouvert** (à valider) | le lot des échéances |
| Carte « Cours assignés » de « Ma classe » (élève) : retirée — proposition de l'UDR-0062 §3.6 | **ouvert** (à valider) | le lot des échéances |
| Liste nominative : nommer aussi les élèves « pas encore faits » après l'échéance ? | **ouvert** (le grill ne nomme que les retardataires) | rien (sinon on s'en tient aux rendus en retard) |
| Choix faits sans réponse du grill, à valider : limite de l'échéance (fin du jour), ambre aujourd'hui et demain, dimanche exclu, équipe sans échéance, tout décocher = non renseigné, jours effacés au retrait de la déclaration, exercice terminé rangé en fin de liste sans date (ADR-0072 §9, UDR-0062) | **à valider** | le lot des échéances |
| Adresse, RCCM, forme juridique et contact de Lnclass Côte d'Ivoire | **à fournir** | pages Protection des données, CGU, CGV |
| Déclaration ou autorisation ARTCI, durées de conservation, région d'hébergement, âge minimum et accord des parents, bases légales, responsabilité, droit applicable | **à fournir** / juriste ([`pages-publiques.md`](pages-publiques.md) §5) | pages Protection des données et CGU |
| Purges prévues par l'ADR-0036 (tentatives de connexion, codes périmés) non programmées ; anonymisation d'un compte non construite | **constat** : à construire ou à retirer de la politique | page Protection des données |
| Acceptation des CGU à l'inscription (case à cocher) | **ouvert** | rien dans ce chantier (sinon un chantier sur l'inscription) |
| Offre, prix, durée, remboursement, réclamation | **ouvert**, chantier `abonnement-mobile-money` | page CGV |
