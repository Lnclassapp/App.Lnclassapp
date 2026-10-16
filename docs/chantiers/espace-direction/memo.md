# Memo — Espace direction, ce qui reste de la V2

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage — questions au porteur ouvertes (Q1 à Q9) |
| **Ouvert le** | 2026-10-16 |
| **Branche** | `docs/cadrage-espace-direction` (cadrage) ; code : `feature/espace-direction`, après Q9 |
| **Programme** | `refonte-application`, vague V2 ([feuille de route §5](../refonte-application/feuille-de-route.md#v2--organisation-scolaire-et-espace-direction)) |

---

## Le problème

Le 2026-09-28, la conception complète de l'espace direction est partie au backlog : matricule de l'élève, quatre fonctions de direction et leurs droits, personnel, retrait et réintégration d'enseignants, changement de classe, code d'établissement, ajout de classes, tableau de bord élaboré. Depuis, six chantiers en ont livré la plus grande part, sans fonction et sans matricule (inventaire ci-dessous).

Trois manques restent visibles dans le code de `Develop` au 2026-10-16 :

1. **Tous les comptes de direction ont les mêmes droits.** Une secrétaire arrivée par le code d'établissement peut retirer un enseignant, archiver un niveau entier ou retirer le chef d'établissement. Rien ne dit non plus qui est qui : le bloc « Direction » ne montre qu'un nom et une date d'arrivée.
2. **La direction ne peut pas corriger la classe d'un élève.** Un élève inscrit en 6ème 3 au lieu de 6ème 2 (l'inscription par cascade de l'ADR-0085 rend l'erreur facile) ne peut être que **retiré** ; il doit ensuite choisir lui-même sa classe. La direction, qui connaît les listes officielles, n'a aucun geste direct.
3. **La direction ne trouve un élève qu'en connaissant sa classe.** Les élèves se lisent classe par classe (niveau → classe → recherche dans la classe). Dans un établissement de 2 000 élèves, retrouver « Kouassi Aya » demande d'ouvrir les classes une à une.

S'y ajoute une dette de recette : le changement de PIN (ID-20, SC-25) est livré pour tous les rôles, mais aucun test ne le joue avec un compte de direction.

## Pour qui

- **La direction (SchoolStaff)**, sur son seul établissement : le chef d'établissement et son adjoint (ou directeur des études) gèrent ; l'éducateur et la secrétaire suivent les élèves.
- **L'équipe (Team)** : elle fixe la fonction d'une direction qu'elle invite, et la corrige.
- **L'élève** : il change de classe sans rien faire ; ses résultats passés restent.
- **L'enseignant** : rien ne change, sinon qu'un élève changé de classe apparaît « Nouveau » chez lui.

## Pourquoi maintenant

Le porteur a demandé de lancer les vagues V2 à V6 (2026-10-16). La V2 est la première ; ce chantier en est le reste. Les directions arrivent seules par le code depuis le 2026-10-07 (ADR-0077, trois comptes par établissement) : plus il y a de comptes, plus l'égalité des droits coûte (un compte de secrétaire peut évincer le chef).

## Inventaire : ce qui est fait, ce qui reste

Vérifié dans le code de `Develop` (`d1226437`), le 2026-10-16.

### Les huit points de l'index des chantiers

| Point du backlog | État | Preuve dans le code |
|---|---|---|
| Matricule MENA de l'élève | **Non fait.** Aucune colonne, aucune mention dans `app/` | `grep -ri 'matricule\|student_number' app db/schema.rb` : vide. **Q7** : sortir du périmètre |
| Quatre fonctions de direction et leurs droits | **Non fait.** `school_staffs` n'a pas de colonne `position` ; toutes les policies accordent tout à `actor.school_admin?` | `db/schema.rb` (`school_staffs`), `Policies::School::ManageSchoolStructurePolicy`, `ManageSchoolTeachersPolicy`, `RemoveSchoolStaffPolicy`. **Reste** (Lots 0, A, B, C) |
| Personnel | **Fait.** Invitation par l'équipe ; inscription par le code, 3 comptes au plus ; retrait par une autre direction après 7 jours ; restauration par l'équipe ; purge à 30 jours | `teams/staff_invitations`, `identity/school_staff_registrations`, `school_admin/staff_members#destroy`, `teams/school_staff_restorations`, `PurgeArchivedStaffJob` (ADR-0077, #163, #166) |
| Retrait et réintégration d'enseignants | **Fait** | `school_admin/teachers#destroy`, `teacher_reinstatements#create`, `departed_teachers#index`, `UseCases::School::DetachTeacher`, `ReinstateTeacher` (ADR-0071, #126) |
| Changement de classe | **Non fait.** Seul le retrait existe | `UseCases::Classroom::RemoveStudent`, `DELETE /classrooms/:id/students/:id` (ADR-0085 §4.5). **Reste** (Lot D) |
| Code d'établissement | **Fait autrement.** La direction lit et partage son lien d'invitation des enseignants `/i/<jeton>` ; « Changer le lien » a été retiré par l'ADR-0083 (Q10 d'`inscription-enseignant`) ; le code ne sert plus qu'à l'inscription de la direction | `school_admin/schools/_link.html.erb`, `schools.direction_invite_token`, ADR-0083 §4 |
| Ajout de classes | **Fait** : « + » et « − » par niveau, archivage et restauration d'une classe ou d'un niveau | `school_admin/level_classrooms`, `classroom_archivals`, `level_archivals` (ADR-0059, 0071, 0088) |
| Tableau de bord élaboré | **Fait en partie.** Accueil en quatre sections : chiffres, alertes, niveaux à pastille, annonces, activité récente. Périodes, historique et export ont été exclus par `accueil-direction` | `Queries::School::DirectionHomeQuery`, `school_admin/activities`, UDR-0074 (#167). **Q8** : ne rien ajouter |

### Les features ID et SC de la V2

| ID | Feature | État | Preuve ou raison |
|---|---|---|---|
| ID-09 = SC-23 | Rattacher un enseignant existant | **Hors V2** : backlog `multi-etablissements-enseignant` (porteur, 2026-09-28). En V2, l'enseignant rejoint par le lien `/i/` (ADR-0083) ; le retrait et la réintégration sont faits | `config/routes/school_admin.rb` |
| ID-10 = SC-21 | Rattacher un élève existant à une classe | **Reste**, sous la forme « changer de classe un élève de l'établissement » | Lot D |
| ID-11 = SC-20, SC-22 | Lister les enseignants et les élèves | Enseignants : **fait** (`teachers#index`, 142 Ko, `ecrans-direction-lents`). Élèves : **fait par classe** (`classrooms#show`, recherche dans la classe) ; **reste** la recherche dans tout l'établissement (Q6) | Lot E |
| ID-19 = SC-24 | Profil de direction, avatar compris | **Fait** : « Mon profil » montre l'établissement ; la photo vaut pour tous les rôles | `test/controllers/identity/profiles_controller_test.rb` (« a school admin reads their school »), #50 |
| ID-20 = SC-25 | Changer son PIN côté direction | **Fait dans le code, non recetté** : `profile_pins_controller_test.rb` ne joue que l'enseignant | Lot F (tests seuls) |
| SC-11, SC-12 | Lister, créer, supprimer les rôles d'un établissement | **Reste**, sous la forme d'une **liste fermée** de quatre fonctions, sans création ni suppression (ADR-0044) | Lots 0, A, B |
| SC-13 | Rattacher un membre du personnel | **Fait** (invitation, inscription par le code) | ADR-0077 |
| SC-14 | Retirer un membre du personnel | **Fait** | ADR-0077 |
| SC-15 = TR-15 | Tableau de bord de l'établissement | **Fait** (accueil-direction) ; le reste est Q8 | UDR-0074 |
| SC-16 = TR-16 | Page « en attente d'affectation » | **Sans objet** : `school_staffs.school_id` est `NOT NULL` ; une direction archivée ne se connecte plus | `test/integration/identity/archived_staff_sign_in_test.rb` |
| SC-17 | Classes de son établissement | **Fait** | `school_admin/levels#show`, accueil |
| SC-18 | Tableau de bord d'une classe | **Fait** : tuiles, élèves, devoirs rendus, score moyen ; 404 hors établissement | `school_admin/classrooms#show` |
| SC-19 | Créer une classe | **Fait** sous la forme « + » / « − » ; création au nom libre écartée (Q3 du 2026-09-28) | ADR-0059, ADR-0071 |

**Bilan.** Sur les 22 features de la fiche V2 « Reste : `espace-direction` » : 12 sont faites ou sans objet (ID-19, SC-13 à SC-19, SC-22, SC-24, TR-15, TR-16), 2 sont hors V2 (ID-09, SC-23), et 8 restent, soit quatre manques : SC-11 et SC-12 (fonctions) ; ID-10 = SC-21 (changement de classe) ; ID-11 et SC-20, pour la part des élèves (recherche dans l'établissement) ; ID-20 = SC-25 (recette).

## Hors périmètre

- **Le matricule MENA** de l'élève (Q7) : sans code de classe, la direction retrouve un élève par son nom ; le matricule reviendra avec le paiement s'il en a besoin (`abonnement-mobile-money`).
- **Un tableau de bord par période**, l'historique du taux de rendu, l'export (Q8).
- **Le second facteur de la direction** (ADR-0044 l'exigeait, ADR-0065 l'a retiré) : inchangé.
- **Une fonction libre** ou un rôle créé par l'établissement : la liste reste fermée (ADR-0044).
- **Une direction qui change la fonction d'une autre**, ou la sienne une fois choisie (Q2) : seule l'équipe la corrige.
- **Le changement de classe par l'enseignant** (Q5) ; **le changement d'établissement d'un élève** (backlog `changement-etablissement-eleve`) ; **le multi-établissement de l'enseignant** (backlog).
- **Renommer, modifier ou créer une classe au nom libre** (CL-02, V3).
- **Valider les enseignants en attente** (Q1 du 2026-09-28 ; ADR-0073 les rattache tout de suite).
- **Prévenir l'élève** qu'il a changé de classe : son accueil montre sa nouvelle classe, sans message.
- **L'annuaire des comptes de l'équipe** (`annuaire-equipe`), les **parents**.
- **Changer le lien** d'invitation de la direction (retiré par l'ADR-0083).

## Ce que le grill a révélé

> Grill fait par l'agent de cadrage contre le code de `Develop` et les six chantiers livrés. Les réponses du porteur manquent : chaque question porte la **recommandation** de l'agent, que le PRD, l'ADR-0092, les UDR-0092 à 0094 et le plan appliquent déjà. Une réponse contraire change les fichiers nommés dans la dernière colonne.

| # | Question au porteur | Recommandation | Si la réponse est contraire |
|---|---|---|---|
| Q1 | Quelles fonctions, sous quels libellés ? | Quatre, en liste fermée : **Chef d'établissement** ; **Adjoint au chef d'établissement** dans le public, **Directeur des études** dans le privé et le mixte (vocabulaire du porteur, grill 1 de `gestion-etablissement-direction`) ; **Éducateur** ; **Secrétaire**. Codes : `head`, `deputy`, `educator`, `secretary`. Le libellé du rang 2 dépend de `schools.school_type` | Une autre liste : ADR-0092 §4.1, UDR-0092 et les locales changent, pas les lots. Des rôles libres : table `school_roles` (écartée par l'ADR-0044), nouvel ADR, un lot de plus |
| Q2 | Qui fixe la fonction, et qui la change ? | La personne la choisit **en s'inscrivant** par le code ; l'équipe la choisit **en invitant**. Un seul chef d'établissement actif par établissement : un second qui le déclare est refusé (« contactez l'équipe »). Ensuite, **seule l'équipe** la change. Une direction ne change jamais une fonction, ni la sienne | Si une direction peut changer sa fonction ou celle d'une autre, les droits du Q3 ne protègent plus rien (un compte se promeut seul) : Q3 tombe, et le Lot B gagne un geste côté direction. Sans chef unique : l'index partiel de l'ADR-0092 §4.2 disparaît |
| Q3 | Quels droits pour chaque fonction ? | Deux rangs. **Gestion** (chef, adjoint ou directeur des études) : tous les gestes d'aujourd'hui. **Vie scolaire** (éducateur, secrétaire) : tout lire, partager les liens, retirer un élève, changer un élève de classe ; **pas** de « + » / « − », d'archivage, de retrait ou de réintégration d'enseignant, de retrait d'une direction | Mêmes droits pour tous : le Lot C disparaît, la fonction n'est plus qu'un libellé (Lots 0, A, B). Une autre matrice : ADR-0092 §4.3 et les tests de policy du Lot C changent, pas les fichiers |
| Q4 | Que deviennent les comptes de direction déjà en production, sans fonction ? | Ils **gardent tous leurs droits** tant que leur fonction n'est pas renseignée (aucune régression), et chacun la **précise une fois**, depuis sa ligne du bloc « Direction » (« Préciser ma fonction »). L'équipe peut aussi la fixer | Si l'équipe seule les renseigne : « Préciser ma fonction » sort du Lot B ; l'équipe ouvre chaque fiche. Si, sans fonction, un compte passe en « vie scolaire » : régression immédiate pour les directions actuelles, à annoncer avant la mise en production |
| Q5 | Changement de classe : vers quelles classes, et par qui ? | Par **la direction seule** (toute fonction), vers **toute classe active de son établissement**, de l'année en cours, tous niveaux (une erreur de niveau à l'inscription est possible), sous le plafond d'effectif. Les résultats passés restent à leurs devoirs ; l'élève apparaît « Nouveau » dans sa nouvelle classe | Même niveau seulement : la liste de la modale se filtre (UDR-0093 §3.2), rien d'autre. L'enseignant aussi : sa policy, sa page de classe (`classroom/classrooms/_roster`) et une collision avec la V3 (`vie-de-la-classe`) |
| Q6 | La direction cherche-t-elle un élève dans tout l'établissement ? | **Oui**, par son nom (3 lettres au moins), depuis la carte « Établissement » de l'accueil ; chaque résultat mène à la page de sa classe, filtrée sur son nom. Aucun numéro de téléphone affiché ni cherché | Non : le Lot E et l'UDR-0094 sortent ; changer un élève de classe demande de connaître sa classe |
| Q7 | Le matricule MENA entre-t-il dans ce chantier ? | **Non.** Il servait à retrouver un élève par la direction (grill 1 du 2026-09-28) ; la recherche par nom (Q6) y répond sans nouvelle donnée de mineur ni changement de l'inscription | Oui : un second ADR (numéro à réserver), une migration de `users`, l'inscription élève amendée (UDR-0081, UDR-0088), un lot de plus en collision avec les fichiers de l'inscription élève, et un vrai matricule pour fixer le format |
| Q8 | Le tableau de bord gagne-t-il des périodes, un historique ou un export ? | **Non** : l'accueil d'`accueil-direction` a neuf jours ; attendre ce que disent de vraies directions | Oui : un lot sur l'accueil (filtre de période), un amendement de l'UDR-0074, une clé de cache de `DirectionHomeQuery` et une mesure au budget de l'ADR-0067 |
| Q9 | La branche distante `feature/espace-direction` (conception du 2026-09-28, Lot 0a avec `student_number` et `position`) : que faire ? | L'**archiver** sous l'étiquette `archive/espace-direction-2026-09-28`, puis recréer `feature/espace-direction` depuis `Develop` pour le code de ce chantier. Ses migrations ne doivent jamais être fusionnées | La garder : le code part sur `feature/espace-direction-v2`, et le plan change de nom de branche |

Le grill a changé le chantier sur quatre points par rapport à la conception du 2026-09-28 :

- **Le matricule n'est plus nécessaire** : il servait à chercher un élève sans sonder les téléphones ; depuis la suppression du code de classe (ADR-0085), la direction voit les élèves de ses classes par leur nom.
- **Le personnel, le retrait d'enseignants, le code et l'ajout de classes sont livrés** : le chantier se réduit aux fonctions, au changement de classe et à la recherche.
- **La fonction déclarée seule ne vaut rien sans verrou** (Q2) : un compte inscrit par le code se dirait chef. D'où le chef unique, la correction par l'équipe seule, et la règle des 7 jours de l'ADR-0077 qui reste.
- **Changer de classe n'est pas retirer puis réinscrire** : le retrait marque l'élève « retiré » de l'ancienne classe et l'empêche d'y revenir sans le lien (`JoinPolicy`). Le changement de classe est un geste à part, journalisé, avec sa voie d'arrivée `transfer`.

## Cas limites identifiés

- **Deux chefs** : la seconde inscription qui choisit « Chef d'établissement » est refusée ; deux inscriptions simultanées : l'index unique partiel tranche, une seule passe.
- **Le chef archivé** libère la place : une nouvelle inscription peut se dire chef ; la restauration de l'ancien est refusée si un autre chef est actif.
- **Une direction sans fonction** (Q4) garde tous les gestes ; elle peut choisir « Chef d'établissement » si la place est libre.
- **Une direction de rang « vie scolaire »** qui forge une requête de « − », d'archivage, de retrait d'enseignant ou de direction reçoit 403 ; les boutons ne lui sont pas montrés.
- **Changer un élève vers sa classe actuelle** : refusé (« déjà dans cette classe »).
- **Classe cible pleine, archivée ou d'un autre établissement** : refusé ; une classe d'un autre établissement est introuvable (404).
- **Élève retiré autrefois de la classe cible** : la direction peut l'y mettre ; le retrait est levé (`add_primary` rouvre l'adhésion close).
- **Classe d'origine archivée** : l'élève ne bouge pas (rien ne bouge dans une classe archivée, UDR-0081 §3.7).
- **Deux directions déplacent le même élève en même temps** : verrous des deux classes dans l'ordre des identifiants ; la seconde trouve l'élève déjà parti et reçoit « introuvable dans cette classe ».
- **Recherche** : moins de 3 lettres → aucun appel ; plus de 20 résultats → les 20 premiers et « Affinez votre recherche » ; homonymes : la classe les distingue. Un élève sans classe active dans l'établissement n'apparaît pas.
- **Établissement inactif** : lecture seule pour toutes les fonctions (inchangé).

## Questions encore ouvertes

- Q1 à Q9 ci-dessus : à trancher par le porteur avant de passer l'ADR-0092 et les UDR-0092 à 0094 à `Accepté`.
- Nombre de comptes de direction en production sans fonction (pour Q4) : à compter avant la migration du Lot 0.
