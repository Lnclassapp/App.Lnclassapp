# PRD — Espace direction

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

| | |
|---|---|
| **Chantier** | `espace-direction` — cycle feature, programme `refonte-application`, vague V2 |
| **Memo** | [`memo.md`](memo.md) (cadrage validé par le porteur le 2026-09-28 ; phase Décider relue le 2026-09-28, avec ses retours) |
| **Features couvertes** | ID-10, ID-11, ID-19, ID-20 (recette côté direction), SC-11 à SC-22, SC-24, SC-25, TR-15, TR-16 — ID-09 et SC-23 sortent de la V2 (grill 6, V3 avec Q7) ; SC-11 et SC-12 deviennent « voir les fonctions » (liste fermée, ADR-0044) ; ID-10 et SC-21 se réduisent à « changer de classe un élève de l'établissement » (relecture du porteur, 2026-09-28 : aucun rattachement d'un élève venu d'ailleurs) |
| **Décisions** | §6 |

## 1. Contexte

Un établissement importé par l'équipe n'a aujourd'hui personne pour l'administrer : l'équipe fait chaque geste, et ne suit plus quand les établissements se multiplient. Ce chantier donne à la direction invitée (Proviseur, Censeur, Éducateur, Secrétaire) un espace pour gérer **son seul** établissement — classes, enseignants (retrait et réintégration), élèves de l'établissement retrouvés par leur matricule, personnel, code d'établissement, tableau de bord, profil — avec deux niveaux de droits et aucune fuite vers un autre établissement. Il introduit le **matricule MENA** de l'élève, saisi à l'inscription et corrigé par l'élève seul, depuis son profil.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| **Proviseur** (`school_admin`, `principal`) | Tout voir de son établissement ; ajouter la classe suivante d'un niveau ; changer de classe un élève de l'établissement (depuis la liste ou par son matricule) ; inviter un Censeur, un Éducateur ou une Secrétaire ; retirer un enseignant, le réintégrer ; retirer un Censeur, un Éducateur, une Secrétaire ; lire et régénérer le code ; gérer son profil | Se retirer lui-même ; inviter un Proviseur (l'équipe seule) ; valider un enseignant en attente ; chercher ou prendre un élève hors de son établissement ; modifier un matricule ; régénérer ou fermer le code d'adhésion d'une classe ; créer une classe au nom libre, retirer ou modifier une classe ; voir la note d'un élève nommé ; voir un numéro de téléphone ; toucher un autre établissement |
| **Censeur** (`censor`) | Comme le Proviseur | Retirer un Proviseur ; se retirer ; tout ce que le Proviseur ne peut pas |
| **Éducateur**, **Secrétaire** (`educator`, `secretary`) | Tout voir de son établissement ; ajouter la classe suivante d'un niveau ; changer un élève de l'établissement de classe ; lire le code ; gérer son profil | Inviter ; retirer ou réintégrer un enseignant ; retirer un membre ; régénérer le code ; tout ce que le Proviseur ne peut pas |
| **Direction sans établissement** (retirée, ou établissement inactif) | Voir l'écran d'attente et son profil ; se déconnecter | Tout le reste, catalogue compris |
| **Équipe** (`team`) | Tous les gestes de la direction sur tout établissement (par ses propres écrans : fiche de l'établissement, « + » ; aucun écran de réintégration en V2) ; inviter la première direction et tout Proviseur ; retirer tout membre, Proviseur compris ; réinitialiser le second facteur d'un membre de la direction | Réinitialiser son propre second facteur ; chercher un compte par matricule ou corriger un matricule (l'anonymisation d'un usurpateur passe par `annuaire-equipe`) |
| **Enseignant** | Inchangé ; retiré de son établissement, il rejoint un **autre** établissement avec son code, depuis l'écran d'attente, ou il est réintégré par le Proviseur ou le Censeur qui l'a retiré, puis se redéclare dans ses classes | Accéder à l'espace direction ; revenir seul dans l'établissement qui l'a retiré |
| **Élève** | S'inscrire avec son matricule (obligatoire) ; le lire et le corriger au profil, sous son PIN actuel | Modifier le matricule d'un autre ; accéder à l'espace direction |
| **Parent** | — (hors périmètre, memo) | — |

**Règles d'autorisation** : `Policies::School::StaffPolicy` (table fonction × geste, établissement de l'acteur, établissement actif — [ADR-0066](../../decisions/adr/0066-espace-direction-droits-et-gestes.md) §4.3) ; `Policies::Identity::ChangeOwnStudentNumberPolicy` (l'élève, sur son propre compte) ; `Policies::School::RejoinSchoolPolicy` (enseignant sans école ni demande en attente) ; `SecondFactorPolicy` et `ResetSecondFactorPolicy` étendues à la direction ; `ManageSchoolPolicy` et `ManageClassroomPolicy` **inchangées** (équipe seule). Second facteur exigé pour toute la direction ([ADR-0044](../../decisions/adr/0044-rattachement-de-la-direction-par-invitation.md), ADR-0066 §4.2).

## 3. Parcours utilisateur

### Chemin nominal

1. L'équipe ouvre la fiche d'un établissement actif, section « Direction », et invite le Proviseur par son numéro : un lien s'affiche une fois ; elle le transmet hors de Lnclass.
2. Le Proviseur ouvre le lien, crée son compte (nom, prénoms, genre, PIN), se connecte, active son second facteur et arrive sur le **tableau de bord** : nombre de classes, d'enseignants et d'élèves, puis une ligne par classe.
3. Sur **Établissement**, il lit le code d'établissement, le copie et le diffuse aux enseignants ; il invite un Censeur et une Secrétaire.
4. Sur **Classes**, la Secrétaire ajoute une « 6ème 5 » par le « + » de la ligne « 6ème ».
5. Une élève s'est inscrite dans la mauvaise classe : sur **Élèves**, l'Éducateur clique « Chercher par matricule », saisit son matricule, lit son nom et sa classe actuelle, choisit « 6ème 5 », confirme (ou, depuis la ligne de l'élève, « Changer de classe »).
6. Un enseignant quitte l'établissement : sur **Enseignants**, le Censeur le retire ; les classes, les devoirs et les résultats restent ; l'enseignant, à sa requête suivante, voit l'écran d'attente et pourra saisir le code d'un autre établissement. Retiré par erreur, il est réintégré par le Proviseur depuis « Enseignants retirés » et se redéclare dans ses classes.
7. Un nouvel élève s'inscrit par le code de sa classe (généré à la création de la classe) : il saisit son matricule avec son nom ; il corrige plus tard une faute de frappe depuis « Mon profil », sous son PIN.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Direction connectée par PIN, second facteur non vérifié | Toute page de l'espace direction renvoie vers la vérification (ou l'activation) du second facteur |
| Direction retirée, ou établissement inactif | Écran d'attente « Aucun établissement » ; profil accessible ; toute page de l'espace renvoie vers l'écran d'attente |
| Éducateur ou Secrétaire qui force un geste de gestion | 403 ; rien n'est écrit ; le bouton ne lui est pas affiché |
| Ressource d'un autre établissement (classe, enseignant, membre) | 404 ; rien n'est écrit |
| Invitation vers un numéro qui a déjà un compte | « Ce numéro a déjà un compte Lnclass. » |
| Invitation d'un Proviseur par la direction | Fonction non proposée ; forcée, 403 (seule l'équipe invite un Proviseur) |
| Invitation d'un Proviseur par l'équipe alors qu'un Proviseur est actif | « L'établissement a déjà un Proviseur. » |
| Plus de 30 invitations dans l'heure | 429 « Trop d'invitations » |
| Acceptation après qu'un Proviseur a été rattaché entre-temps, ou établissement désactivé | « Cette invitation ne peut plus être acceptée. » ; aucun compte créé |
| Matricule hors format (recherche) | Message de format, sans lecture |
| Matricule inconnu, compte anonymisé, élève sans classe active de l'année, élève d'un autre établissement | **Le même message neutre**, même statut |
| Plus de 10 recherches par minute (ou 100 par jour) | 429 « Trop de recherches » ; aucune lecture |
| Classe pleine au changement de classe | « Cette classe est complète (80 / 80). Choisissez-en une autre. » |
| Élève déjà dans la classe choisie | « <nom> est déjà dans cette classe. » |
| Matricule déjà pris à l'inscription | « Ce matricule est déjà utilisé… » ; jamais le nom du détenteur ; aucun compte créé |
| Enseignant retiré qui saisit un code inconnu, d'un établissement inactif, ou de l'établissement qui l'a retiré (sans réintégration) | Le même message que l'inscription enseignant ; 429 au-delà de 10 par minute |
| Réintégration d'un enseignant retiré d'un autre établissement, anonymisé ou rattaché entre-temps ailleurs | 404 ; il n'est pas dans la liste des retirés |
| Élève qui corrige son matricule avec un PIN faux, un format faux, un matricule pris | « PIN incorrect. » (échec de connexion compté) ; message de format ; « Ce matricule est déjà utilisé… » sans nom ; 429 au-delà de 10 par heure |
| Direction sans établissement qui ouvre le catalogue | Écran d'attente |
| Changer de classe un élève déjà listé | Étape 2 directement, sans matricule ni limite de débit |
| Établissement sans classe, sans enseignant ou sans élève | État vide qui dit quoi faire (ajouter une classe, transmettre le code d'établissement ou le code d'adhésion d'une classe) |
| Mille élèves | Liste paginée par 20, filtrable par classe |

## 4. Critères d'acceptation

Chaque critère devient au moins un test ; le lot qui le porte est indiqué entre crochets, et le chemin du test est dans [`plan.md`](plan.md). « La direction de A » désigne un membre actif de l'établissement actif A ; B est un autre établissement actif. **Chaque cas d'usage a son test de refus inter-établissements** (ED-10, ED-18, ED-22, ED-26, ED-31, ED-38, ED-41, ED-47, ED-62) et **chaque geste sensible son refus Éducateur et Secrétaire, les deux nommés** (ED-08, ED-16, ED-21, ED-37, ED-61). Règle des deux barrières (ADR-0066 §4.4) : le use case qui reçoit l'établissement B répond `forbidden` ; le contrôleur, qui passe toujours l'établissement de l'acteur, répond 404 pour une ressource de B. **65 critères** (ED-01 à ED-65). Relecture du porteur du 2026-09-28 : ED-40, ED-41, ED-43, ED-44, ED-47, ED-52, ED-53, ED-54, ED-58 et ED-59 **réécrits** (même numéro, sens nouveau) ; ED-60 à ED-65 **ajoutés** ; aucun supprimé.

### 4.1 Accès de la direction — [Lot 0]

```gherkin
Scénario: ED-01 — second facteur exigé sur tout l'espace direction
  Étant donné un Proviseur de A, second facteur activé, connecté par son PIN seulement
  Quand il ouvre chacune des routes SchoolAdmin
  Alors chacune le redirige vers la vérification du second facteur
  Et aucune ne rend de page de l'espace direction

Scénario: ED-02 — l'espace direction est réservé à la direction
  Étant donné un élève, un enseignant et un membre de l'équipe, chacun connecté et vérifié
  Quand chacun ouvre chacune des routes SchoolAdmin
  Alors chacun reçoit 403

Scénario: ED-03 — une direction sans établissement actif ne voit que l'écran d'attente et son profil
  Étant donné un membre de la direction dont le rattachement est terminé
  Et un membre de la direction de l'établissement C désactivé
  Quand chacun ouvre le tableau de bord de l'espace direction, puis le catalogue
  Alors chacun est redirigé vers l'écran d'attente les deux fois
  Et chacun voit « Aucun établissement »
  Et chacun peut ouvrir « Mon profil »

Scénario: ED-04 — le shell de la direction a cinq destinations actives
  Étant donné une Censeure de A connectée et vérifiée
  Quand elle ouvre l'accueil de l'espace direction
  Alors la navigation affiche Accueil, Classes, Enseignants, Élèves et Établissement, toutes actives
  Et le détail du shell affiche « Censeur · <nom de A> »

Scénario: ED-05 — profil de la direction (ID-19, ID-20)
  Étant donné une Secrétaire de A connectée et vérifiée
  Quand elle ouvre « Mon profil »
  Alors elle voit le badge « Secrétaire » et la ligne « Établissement : Secrétaire · <nom de A> »
  Et elle ne voit pas le badge « En attente »
  Et elle modifie son nom, son PIN sous PIN actuel et sa photo comme tout compte

Scénario: ED-23 — la direction ne valide pas les enseignants en attente (Q1)
  Étant donné un enseignant en attente de validation pour A
  Quand le Proviseur de A appelle la validation de l'équipe, puis le geste du garant
  Alors il reçoit 403 les deux fois
  Et la demande reste en attente

Scénario: ED-50 — la base garde le format, l'unicité et le rôle du matricule
  Quand on enregistre deux élèves avec le matricule 12345678A
  Alors la base refuse le second
  Et la base refuse un enseignant avec un matricule
  Et la base refuse le matricule « 1234567A »

Scénario: ED-52 — l'élève lit son matricule et peut le corriger
  Étant donné un élève inscrit avec le matricule 12345678A
  Quand il ouvre « Mon profil »
  Alors il voit « Matricule 12345678A » et le bouton « Corriger »
  Et le bouton mène à « /profile/student_number/edit » dans le frame « modal » (la modale arrive avec le Lot F)
  Et un enseignant, un membre de la direction et un membre de l'équipe ne voient ni la ligne ni le bouton sur leur propre profil
```

### 4.2 Inviter la direction et le personnel — [Lot A]

```gherkin
Scénario: ED-06 — l'équipe invite le premier Proviseur
  Étant donné un membre de l'équipe sur la fiche de l'établissement actif A, sans direction
  Quand il invite le numéro 0700000009 comme Proviseur
  Alors un lien d'invitation s'affiche une seule fois
  Et une invitation « school_staff » de fonction « principal » pour A expire dans 72 heures
  Et le journal enregistre « invitation.sent »

Scénario: ED-07 — le Proviseur et le Censeur invitent le personnel
  Étant donné le Proviseur de A et le Censeur de A
  Quand le Proviseur invite un Censeur et que le Censeur invite une Secrétaire
  Alors chacun obtient un lien d'invitation pour A

Scénario: ED-08 — l'Éducateur et la Secrétaire n'invitent pas
  Étant donné l'Éducateur de A et la Secrétaire de A
  Quand chacun envoie une invitation
  Alors chacun reçoit 403
  Et le bouton « Inviter un membre » ne leur est pas affiché
  Et aucune invitation n'est créée

Scénario: ED-09 — seule l'équipe invite un Proviseur, et il n'y en a qu'un
  Étant donné le Proviseur de A et le Censeur de A
  Quand chacun ouvre « Inviter un membre »
  Alors la fonction « Proviseur » ne lui est pas proposée
  Quand chacun force une invitation de Proviseur
  Alors chacun reçoit 403
  Étant donné un membre de l'équipe et le Proviseur actif de A
  Quand l'équipe invite un second Proviseur pour A
  Alors elle lit « L'établissement a déjà un Proviseur. »

Scénario: ED-10 — pas d'invitation pour un autre établissement
  Étant donné le Proviseur de A
  Quand le cas d'usage d'invitation reçoit l'établissement B
  Alors il répond « forbidden »
  Et aucune invitation n'est créée pour B

Scénario: ED-11 — numéro déjà inscrit ou déjà invité
  Étant donné un enseignant inscrit au numéro 0500000001
  Quand le Proviseur de A invite ce numéro
  Alors il lit « Ce numéro a déjà un compte Lnclass. »
  Étant donné une invitation en cours pour 0700000009
  Quand il invite de nouveau ce numéro
  Alors il lit « Une invitation est déjà en cours pour ce numéro. »

Scénario: ED-12 — accepter une invitation de direction
  Étant donné une invitation valide de Censeur pour A
  Quand la personne invitée ouvre le lien et saisit son nom, ses prénoms, son genre et son PIN
  Alors un compte « school_admin » est créé et rattaché à A comme Censeur
  Et à sa première connexion elle active son second facteur
  Et elle arrive sur le tableau de bord de A
  Et le journal enregistre « invitation.accepted »

Scénario: ED-58 — l'invitation est bornée en débit
  Étant donné le Censeur de A qui a créé 30 invitations dans l'heure
  Quand il en crée une 31ᵉ
  Alors il reçoit 429 « Trop d'invitations »
  Et aucune invitation n'est créée

Scénario: ED-13 — une invitation devenue impossible ne crée rien
  Étant donné une invitation de Proviseur pour A
  Et un autre Proviseur rattaché à A entre-temps
  Quand la personne invitée accepte
  Alors elle lit « Cette invitation ne peut plus être acceptée. »
  Et aucun compte n'est créé
```

### 4.3 Personnel — [Lot B]

```gherkin
Scénario: ED-14 — chacun voit le personnel de son seul établissement
  Étant donné la Secrétaire de A et un Censeur de B
  Quand elle ouvre « Établissement »
  Alors elle voit les membres actifs de A, leur fonction et leur date d'arrivée
  Et elle ne voit pas le Censeur de B

Scénario: ED-15 — le Proviseur retire un Éducateur
  Étant donné le Proviseur de A, et l'Éducateur de A connecté sur un autre appareil
  Quand le Proviseur retire l'Éducateur et confirme
  Alors le rattachement de l'Éducateur est terminé
  Et toutes ses sessions sont fermées
  Et à sa connexion suivante il voit l'écran d'attente « Aucun établissement »
  Et le journal enregistre « staff.detached »

Scénario: ED-16 — l'Éducateur et la Secrétaire ne retirent personne
  Étant donné l'Éducateur de A et la Secrétaire de A
  Quand chacun envoie le retrait de l'autre
  Alors chacun reçoit 403
  Et le menu « Retirer » n'est affiché à aucun des deux

Scénario: ED-17 — ni soi-même, ni le Proviseur, sauf par l'équipe
  Étant donné le Censeur de A
  Quand il envoie son propre retrait, puis celui du Proviseur de A
  Alors il reçoit 403 les deux fois
  Étant donné un membre de l'équipe sur la fiche de A
  Quand il retire le Proviseur de A
  Alors le rattachement du Proviseur est terminé

Scénario: ED-18 — pas de retrait dans un autre établissement
  Étant donné le Proviseur de A
  Quand il envoie le retrait d'un membre de B
  Alors il reçoit 404
  Et le membre de B reste rattaché
  Et le cas d'usage de retrait répond « forbidden » s'il reçoit l'établissement B
```

### 4.4 Code d'établissement — [Lot G]

```gherkin
Scénario: ED-19 — toute la direction lit le code
  Étant donné la Secrétaire de A
  Quand elle ouvre « Établissement »
  Alors elle voit le code de A au format « K7M-4QZ », son lien « /e/<code> » et les boutons de copie
  Et elle ne voit pas « Régénérer le code »

Scénario: ED-20 — le Censeur régénère le code
  Étant donné le Censeur de A
  Quand il régénère le code et confirme
  Alors un nouveau code s'affiche
  Et, pour un visiteur non connecté, l'ancien code répond 404 sur « /e/<ancien code> »
  Et le journal enregistre « school.changed » avec « code_regenerated »

Scénario: ED-21 — l'Éducateur et la Secrétaire ne régénèrent pas
  Étant donné l'Éducateur de A et la Secrétaire de A
  Quand chacun envoie la régénération du code
  Alors chacun reçoit 403
  Et le code de A n'a pas changé

Scénario: ED-22 — pas de régénération pour un autre établissement
  Étant donné le Proviseur de A
  Quand le cas d'usage de régénération reçoit l'établissement B
  Alors il répond « forbidden »
  Et le code de B n'a pas changé
```

### 4.5 Classes et tableau de bord — [Lot D]

```gherkin
Scénario: ED-24 — la Secrétaire ajoute la classe suivante d'un niveau
  Étant donné la Secrétaire de A, établissement public qui a « 6ème 1 » à « 6ème 4 » cette année
  Quand elle clique « + » sur la ligne « 6ème »
  Alors la classe « 6ème 5 » est créée dans A, avec un code d'adhésion
  Et la ligne affiche 5 classes, sans rechargement de la page
  Et le journal enregistre « school.changed » avec « classroom_added »

Scénario: ED-64 — la classe ajoutée par la direction a son code d'adhésion dès sa création
  Étant donné la Secrétaire de A qui vient d'ajouter « 6ème 5 »
  Quand on lit « 6ème 5 » en base, sans autre geste
  Alors son code d'adhésion est présent, au format des codes de classe, et différent de celui des autres classes
  Et un visiteur non connecté qui ouvre « /c/<ce code> » voit le formulaire d'inscription de « 6ème 5 »
  Et la page de la classe affiche ce code et « Copier le code », sans « Régénérer » ni « Fermer »

Scénario: ED-25 — la direction n'a ni « − », ni création libre, ni modification
  Étant donné le Proviseur de A
  Quand il ouvre « Classes »
  Alors aucun bouton « − » ni formulaire de nom libre n'est affiché
  Et les cas d'usage de création libre et de retrait de classe lui répondent « forbidden »

Scénario: ED-26 — pas de classe ajoutée ni lue dans un autre établissement
  Étant donné le Proviseur de A
  Quand le cas d'usage d'ajout reçoit l'établissement B
  Alors il répond « forbidden »
  Quand il ouvre la page d'une classe de B
  Alors il reçoit 404

Scénario: ED-27 — la page d'une classe
  Étant donné la classe « 3ème 2 » de A : 30 élèves, plafond 80, 4 devoirs, 2 enseignants déclarés
  Quand l'Éducateur de A ouvre sa page
  Alors il voit « 30 / 80 », 4 devoirs, le taux de rendu, la moyenne, le code d'adhésion et les deux enseignants
  Et il ne voit aucun nom d'élève ni aucune note

Scénario: ED-28 — les chiffres de l'établissement
  Étant donné A avec 3 classes actives de l'année et 1 classe archivée
  Et 2 enseignants dont A est l'établissement principal, et 1 enseignant anonymisé
  Et 5 élèves placés dans A et 1 élève placé dans B
  Quand le Proviseur de A ouvre le tableau de bord
  Alors il lit 3 classes, 2 enseignants et 5 élèves

Scénario: ED-29 — les chiffres par classe
  Étant donné une classe de 6 élèves et 2 devoirs
  Et 5 élèves qui ont terminé une session sur ces devoirs (scores 40, 50, 60, 70, 80) et 1 session de remédiation terminée (score 100)
  Quand le Proviseur ouvre le tableau de bord
  Alors la ligne de la classe affiche effectif 6, 2 devoirs, rendu 83 %, moyenne 60 %
  Et une classe sans devoir affiche « — » pour le rendu et la moyenne
  Et une classe où moins de 5 élèves ont rendu affiche son rendu et « — » pour la moyenne

Scénario: ED-30 — aucune note d'élève nommé
  Étant donné des sessions terminées dans les classes de A
  Quand la direction de A ouvre le tableau de bord, une page de classe et la liste des élèves
  Alors aucune de ces pages n'affiche la note d'un élève nommé

Scénario: ED-31 — le tableau de bord ne lit que l'établissement de l'acteur, en requêtes bornées
  Étant donné des classes, des devoirs et des sessions dans A et dans B
  Quand le tableau de bord de A est lu
  Alors aucune classe ni aucun chiffre de B n'y figure
  Et le nombre de requêtes ne change pas quand le volume triple

Scénario: ED-32 — établissement vide
  Étant donné l'établissement A sans classe de l'année
  Quand le Proviseur ouvre le tableau de bord
  Alors il lit 0 classe, 0 enseignant, 0 élève
  Et « Aucune classe cette année », avec un lien vers « Classes »
```

### 4.6 Enseignants — [Lot C]

```gherkin
Scénario: ED-33 — la liste des enseignants
  Étant donné 25 enseignants dont A est l'établissement principal, et 1 de B
  Quand la Secrétaire de A ouvre « Enseignants »
  Alors elle voit 20 enseignants sur la première page et 5 sur la seconde
  Et chacun avec sa matière et ses classes dans A
  Quand elle filtre sur « 6ème 1 »
  Alors elle ne voit que les enseignants déclarés dans « 6ème 1 », et l'adresse porte le filtre
  Et elle ne voit jamais l'enseignant de B

Scénario: ED-34 — le Censeur retire un enseignant, rien d'autre ne disparaît
  Étant donné un enseignant de A déclaré dans deux classes de A, auteur de 3 devoirs avec des sessions d'élèves
  Quand le Censeur de A le retire et confirme
  Alors l'enseignant n'est plus rattaché à A ni déclaré dans ses classes
  Et les classes, les 3 devoirs et les sessions restent
  Et son compte reste actif
  Et le journal enregistre « teacher.detached »

Scénario: ED-35 — l'enseignant retiré rejoint un autre établissement par son code
  Étant donné un enseignant retiré de A
  Quand il se connecte
  Alors il voit « Vous n'êtes rattaché à aucun établissement » et le champ « Code d'établissement »
  Quand il saisit le code de l'établissement actif B
  Alors il est rattaché à B et arrive sur son accueil
  Et une direction sans établissement voit, elle, « Aucun établissement » et « Mon profil »

Scénario: ED-36 — code refusé ou trop d'essais
  Étant donné un enseignant retiré
  Quand il saisit un code inconnu, puis le code d'un établissement inactif
  Alors il lit « Code d'établissement invalide. Vérifiez-le auprès de votre établissement. » les deux fois
  Quand il fait une 11ᵉ tentative dans la minute
  Alors il reçoit 429 « Trop de tentatives »

Scénario: ED-37 — l'Éducateur et la Secrétaire ne retirent pas d'enseignant
  Étant donné l'Éducateur de A et la Secrétaire de A
  Quand chacun envoie le retrait d'un enseignant de A
  Alors chacun reçoit 403
  Et l'enseignant reste rattaché
  Et le menu « Retirer de l'établissement » n'est affiché à aucun des deux

Scénario: ED-57 — l'enseignant retiré ne revient pas seul dans l'établissement qui l'a retiré
  Étant donné un enseignant retiré de A, qui connaît le code de A
  Quand il saisit le code de A sur son écran d'attente
  Alors il lit « Code d'établissement invalide. Vérifiez-le auprès de votre établissement. »
  Et il n'est pas rattaché à A

Scénario: ED-38 — pas de retrait d'un enseignant d'un autre établissement
  Étant donné le Proviseur de A
  Quand il envoie le retrait d'un enseignant de B
  Alors il reçoit 404
  Et l'enseignant de B reste rattaché à B
  Et le cas d'usage de retrait répond « forbidden » s'il reçoit l'établissement B

Scénario: ED-60 — le Censeur réintègre un enseignant retiré
  Étant donné un enseignant retiré de A, qui était déclaré dans « 6ème 1 » et « 6ème 2 »
  Quand le Censeur de A ouvre « Enseignants »
  Alors il le voit dans « Enseignants retirés », avec la date du retrait
  Quand il choisit « Réintégrer dans l'établissement » et confirme
  Alors l'enseignant a de nouveau A pour établissement principal
  Et il n'est déclaré dans aucune classe de A
  Et il n'est plus dans « Enseignants retirés », et il est dans la liste des enseignants
  Et le journal enregistre « teacher.reinstated »
  Et à sa requête suivante l'enseignant arrive sur son accueil, et non plus sur l'écran d'attente
  Et il peut de nouveau se déclarer dans « 6ème 1 », comme en V1 (DeclareTeaching)

Scénario: ED-61 — l'Éducateur et la Secrétaire ne réintègrent pas
  Étant donné un enseignant retiré de A, l'Éducateur de A et la Secrétaire de A
  Quand chacun ouvre « Enseignants »
  Alors chacun voit l'enseignant dans « Enseignants retirés », sans menu « Réintégrer »
  Quand chacun envoie la réintégration
  Alors chacun reçoit 403
  Et l'enseignant reste sans établissement

Scénario: ED-62 — pas de réintégration dans un autre établissement
  Étant donné le Proviseur de A et un enseignant retiré de B
  Quand il envoie la réintégration de cet enseignant
  Alors il reçoit 404
  Et l'enseignant reste sans établissement
  Et « Enseignants retirés » de A ne le montre pas
  Et le cas d'usage de réintégration répond « forbidden » s'il reçoit l'établissement B

Scénario: ED-63 — un enseignant qui a rejoint un autre établissement n'est plus réintégrable
  Étant donné un enseignant retiré de A, qui a rejoint B par son code
  Et un enseignant retiré de A, puis anonymisé
  Quand le Proviseur de A ouvre « Enseignants retirés »
  Alors il ne voit aucun des deux
  Quand il envoie la réintégration de chacun
  Alors il reçoit 404 les deux fois
  Et le premier reste rattaché à B
  # Le compte anonymisé est fabriqué en base (AnonymizeUser arrive avec annuaire-equipe).
```

### 4.7 Élèves et changement de classe — [Lot E]

```gherkin
Scénario: ED-39 — la liste des élèves
  Étant donné 25 élèves placés dans A et 1 dans B
  Quand l'Éducateur de A ouvre « Élèves »
  Alors il voit 20 élèves puis 5, chacun avec son nom, son matricule et sa classe
  Et aucun numéro de téléphone ni aucune note
  Et il ne voit jamais l'élève de B
  Et le filtre par classe réduit la liste et avance l'adresse

Scénario: ED-40 — trouver un élève de l'établissement par son matricule entier
  Étant donné l'élève « Awa Koné », matricule 12345678A, en « 6ème 1 » de A cette année
  Quand la Secrétaire de A saisit « 1234 5678-a » dans « Chercher par matricule »
  Alors elle lit « Awa Koné », « Actuellement en 6ème 1 » et la liste des classes actives de l'année de A, « 6ème 1 » désactivée

Scénario: ED-41 — une seule réponse pour tout élève qui n'est pas de l'établissement
  Étant donné un matricule inconnu, le matricule d'un compte anonymisé, celui d'un élève placé cette année dans une classe active de B, et celui d'un élève dont la seule classe, de A, est de l'an dernier et archivée
  Quand le Proviseur de A cherche chacun
  Alors il reçoit quatre fois le statut 422 et le même corps de réponse, jeton CSRF excepté
  Et le champ du matricule y est vide
  Et le texte « Aucun élève de l'établissement n'a ce matricule. Vérifiez-le auprès de l'élève. »
  Et le cas d'usage de recherche répond « forbidden » s'il reçoit l'établissement B
  # Le compte anonymisé est fabriqué en base : une fois AnonymizeUser livré, il n'a plus de matricule (ADR-0065 §7).

Scénario: ED-42 — pas de recherche partielle
  Quand la direction de A cherche « 1234 », puis « 12345678 »
  Alors elle lit le message de format
  Et aucune lecture de compte n'a lieu

Scénario: ED-43 — limite de débit par compte
  Étant donné l'Éducateur de A qui a fait 10 recherches par matricule dans la minute
  Quand il en fait une 11ᵉ
  Alors il reçoit 429 « Trop de recherches » sans lecture de compte
  Et au-delà de 100 dans la journée il reçoit aussi 429

Scénario: ED-44 — l'Éducateur change de classe un élève trouvé par son matricule
  Étant donné un élève de « 6ème 1 » de A, trouvé par son matricule
  Quand l'Éducateur de A choisit « 6ème 5 » et confirme
  Alors l'élève a « 6ème 5 » pour classe principale, et son adhésion à « 6ème 1 » est close
  Et le formulaire envoyé ne porte que l'identifiant public de l'élève, jamais son matricule
  Et l'élève voit « 6ème 5 » à sa connexion suivante
  Et le journal enregistre « student.placed » avec les deux classes

Scénario: ED-45 — changer un élève de classe, et l'y ramener
  Étant donné un élève de « 6ème 1 » de A
  Quand la Secrétaire le change pour « 6ème 2 », puis de nouveau pour « 6ème 1 »
  Alors il est dans « 6ème 1 », avec trois adhésions dont une seule ouverte
  Et ses sessions passées restent attachées à leurs devoirs

Scénario: ED-46 — classe pleine, ou même classe
  Étant donné « 6ème 5 » à 80 élèves sur 80
  Quand la direction y change un élève de A
  Alors elle lit « Cette classe est complète (80 / 80). Choisissez-en une autre. »
  Quand elle choisit la classe actuelle de l'élève
  Alors elle lit « <nom> est déjà dans cette classe. »

Scénario: ED-47 — pas de changement vers une classe d'un autre établissement
  Étant donné le Proviseur de A, un élève de « 6ème 1 » de A et une classe de B
  Quand il envoie le changement de cet élève vers la classe de B
  Alors il reçoit 404
  Et l'élève est toujours en « 6ème 1 »
  Et le cas d'usage de changement de classe répond « forbidden » s'il reçoit l'établissement B

Scénario: ED-59 — changer de classe un élève listé, sans matricule ni limite
  Étant donné l'Éducateur de A qui a atteint sa limite de 10 recherches dans la minute
  Et un élève de « 6ème 1 » de A dans la liste des élèves
  Quand il choisit « Changer de classe » sur cette ligne, puis « 6ème 2 »
  Alors l'élève est dans « 6ème 2 »
  Et aucun matricule n'a été saisi ni envoyé
  Quand il ouvre « Changer de classe » pour un élève de B par son identifiant
  Alors il reçoit 404

Scénario: ED-56 — le matricule ne fuit ni dans les journaux ni dans les adresses
  Quand la direction cherche un élève par son matricule et le change de classe
  Et quand un élève corrige son matricule depuis son profil
  Alors le matricule n'apparaît dans aucune adresse
  Et il est filtré dans le journal des requêtes
```

### 4.8 Matricule à l'inscription et au profil, second facteur de la direction — [Lot F]

```gherkin
Scénario: ED-48 — l'élève s'inscrit avec son matricule
  Étant donné un visiteur sur « /c/<code> » d'une classe active
  Quand il remplit le formulaire avec le matricule « 1234 5678 a »
  Alors son compte est créé avec le matricule « 12345678A »

Scénario: ED-49 — matricule absent, mal formé ou pris
  Quand il laisse le matricule vide
  Alors il lit « Saisis ton matricule. »
  Quand il saisit « 1234567 »
  Alors il lit « Le matricule compte 8 chiffres et une lettre, par exemple 12345678A. »
  Étant donné un élève déjà inscrit avec 12345678A
  Quand il saisit 12345678A
  Alors il lit « Ce matricule est déjà utilisé… » sans aucun nom
  Et aucun compte n'est créé

Scénario: ED-51 — la base exige le matricule de tout élève non anonymisé
  Quand on enregistre un élève sans matricule
  Alors la base le refuse
  Et elle accepte un élève anonymisé sans matricule

Scénario: ED-53 — l'élève corrige son matricule depuis son profil
  Étant donné un élève inscrit avec le matricule 12345678A, connecté
  Quand il ouvre « Corriger mon matricule », saisit son PIN actuel et « 8765 4321-b », et enregistre
  Alors son profil affiche « Matricule 87654321B », sans rechargement de la page
  Et ses autres sessions restent ouvertes
  Et le journal enregistre « student_number.changed » avec les deux matricules masqués

Scénario: ED-54 — seul l'élève corrige son propre matricule
  Étant donné un élève au matricule 12345678A
  Quand un membre de l'équipe, le Proviseur de A et un enseignant appellent chacun le cas d'usage de correction pour cet élève
  Alors chacun reçoit « forbidden »
  Et le matricule est toujours 12345678A
  Et « Débloquer un compte » ne propose ni recherche par matricule ni « Corriger le matricule »

Scénario: ED-65 — correction refusée : PIN, format, matricule pris, débit
  Étant donné un élève au matricule 12345678A et un autre au matricule 87654321B
  Quand le premier saisit un PIN actuel faux
  Alors il lit « PIN incorrect. » et l'échec compte comme un échec de connexion
  Quand il saisit « 1234567 »
  Alors il lit « Le matricule compte 8 chiffres et une lettre, par exemple 12345678A. »
  Quand il saisit 87654321B
  Alors il lit « Ce matricule est déjà utilisé… » sans aucun nom
  Et son matricule est toujours 12345678A
  Quand il fait une 11ᵉ tentative dans l'heure
  Alors il reçoit 429 « Trop de tentatives »

Scénario: ED-55 — l'équipe réinitialise le second facteur d'une direction
  Étant donné un Censeur de A qui a perdu son téléphone
  Quand un membre de l'équipe le trouve par son numéro et réinitialise son second facteur
  Alors le second facteur et les sessions du Censeur sont supprimés
  Et à sa connexion suivante il réactive son second facteur
  Et le cas d'usage de réinitialisation refuse un acteur de la direction
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | Entités : `School::StaffMember`, `School::StaffPosition`, `School::StudentPlacement`, `Identity::StudentNumber` (nouvelles) ; `Identity::Actor#position`, `Identity::User#student_number` et `#school_admin?`, `Classroom::Membership#school_id` et `#school_year`, `Identity::SessionState#privileged?`, `Identity::HomeDestination` (`:school_admin_home`), `Identity::AuditAction` (+5) ; `Classroom::Membership` gagne `school_id`, `school_year`, `classroom_public_id`, `classroom_name` (défauts `nil`). Port **nouveau** `School::StaffRepositoryPort` ; méthodes ajoutées à `UserRepositoryPort`, `RegistrationRepositoryPort`, `MembershipRepositoryPort`, `ClassroomRepositoryPort`, `TeachingRepositoryPort`, `SchoolRepositoryPort` (ADR-0066 §4.5). Policies : `School::StaffPolicy`, `School::RejoinSchoolPolicy`, `Identity::ChangeOwnStudentNumberPolicy` (nouvelles) ; `SecondFactorPolicy`, `ResetSecondFactorPolicy` (étendues). Use cases nouveaux : `School::InviteStaffMember`, `School::DetachStaffMember`, `School::DetachTeacher`, `School::ReinstateTeacher`, `School::RejoinSchoolWithCode`, `School::FindStudentForPlacement`, `School::PlaceStudent`, `Identity::ChangeOwnStudentNumber` ; modifiés : `Identity::AcceptInvitation`, `Identity::ResolveSession`, `Classroom::JoinWithCode`, `Classroom::AddLevelClassroom`, `School::RegenerateSchoolCode` |
| Infrastructure | Migrations : `school_staffs` (ADR-0044), `teacher_school_departures` (avec réintégration) et index partiel de `classroom_students` (ADR-0066), `users.student_number` en deux temps (ADR-0065). `Orm::SchoolStaff`. `Repositories::School::StaffRepository` ; méthodes ajoutées aux repositories existants. Queries nouvelles : `School::DirectionSchoolQuery`, `School::StaffMembersQuery`, `School::SchoolTeachersQuery`, `School::DepartedTeachersQuery`, `School::SchoolStudentsQuery`, `School::SchoolDashboardQuery`, `School::DirectionClassroomsQuery` ; modifiées : `Identity::ShellUserQuery`, `Identity::ProfileQuery`, `Identity::AccountLookupQuery` (fonction et établissement d'un membre de la direction, pour sa carte) |
| Delivery | `config/routes/school_admin.rb` (nouveau) ; ajouts dans `config/routes/teams.rb` et `identity.rb`. `SchoolAdmin::BaseController`, `HomesController`, `ClassroomsController`, `LevelClassroomsController`, `TeachersController`, `DepartedTeachersController`, `TeacherReinstatementsController`, `StudentsController`, `StudentPlacementsController`, `SchoolsController`, `SchoolCodesController`, `StaffMembersController`, `StaffInvitationsController` ; `Teams::SchoolStaffMembersController`, `Teams::SchoolStaffInvitationsController` ; `Identity::SchoolRejoinsController`, `Identity::ProfileStudentNumbersController`. Modifiés : `AuthenticatedController` (garde de la direction sans établissement), `Identity::SecondFactorsController`, `Identity::InvitationsController`, `Identity::PendingAccountsController`, `Classroom::JoinsController`, `Teams::SecondFactorResetsController`, `Authentication` |
| UI | Vues `school_admin/**` ; partiels `shared/staff_invitations/_form` et `_created` ; `teams/school_staff_members/index` ; `school_admin/departed_teachers/index` ; `identity/profile_student_numbers/edit`. Modifiées : `identity/pending_accounts/show`, `identity/invitations/show`, `identity/profiles/_information`, `classroom/joins/_signup_form`, `teams/account_lookups/_result`, `teams/schools/show` ; `NavigationHelper` (5ᵉ destination). Aucun nouveau contrôleur Stimulus : `classroom--join-code-copy`, `modal` et `dropdown` existent |

## 6. Décisions rattachées

- [ADR-0065](../../decisions/adr/0065-matricule-de-l-eleve.md) — Le matricule MENA de l'élève (**Accepté** le 2026-09-28, avec les retours du porteur). Amende ADR-0036.
- [ADR-0066](../../decisions/adr/0066-espace-direction-droits-et-gestes.md) — L'espace direction : une policy à gestes pour deux niveaux de droits (**Accepté** le 2026-09-28, avec les retours du porteur). Amende ADR-0044, ADR-0057, ADR-0030, ADR-0031, ADR-0040.
- [ADR-0067](../../decisions/adr/0067-tableau-de-bord-de-l-etablissement.md) — Le tableau de bord de l'établissement (**Accepté** le 2026-09-28). Complète ADR-0062.
- Amendements datés ajoutés dans ADR-0030, ADR-0031, ADR-0036, ADR-0040, ADR-0044, ADR-0057.
- [UDR-0052](../../decisions/udr/0052-espace-direction.md) — Espace direction (**Accepté** le 2026-09-28, avec les retours du porteur). Ferme **C-31**. Amende UDR-0006, 0019, 0036, 0041, 0050 ; note en tête de l'UDR-0002.
- [UDR-0053](../../decisions/udr/0053-matricule-de-l-eleve.md) — Matricule de l'élève (**Accepté** le 2026-09-28, avec les retours du porteur). Amende UDR-0009, 0020, 0041.

> **Règle du programme** : une décision `Proposé` ne débloque aucun Lot 0 ([`programme.md` §2](../../workflows/programme.md#2-décider--prdmd-cadre--adrudr-de-fondation)). Le porteur a accepté ADR-0065, 0066, 0067 et UDR-0052, 0053 le 2026-09-28, avec ses retours, et confirmé le format du matricule (`12345678A`). Reste avant la migration du Lot F : revérifier qu'aucun élève n'est inscrit en production.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes du tableau de bord de l'établissement | — (page inexistante) | nombre fixe, identique quand le volume triple (≤ 6) | |
| Temps du tableau de bord, 77 classes, 3 000 élèves, 30 000 sessions (base de test locale) | — | < 300 ms | |
| Requêtes d'une page de liste (enseignants, élèves) | — | nombre fixe, indépendant de la taille de la page | |
| Gestes de l'équipe nécessaires à un établissement | tous | l'invitation du premier Proviseur | |

## 8. Exigences transmises à `annuaire-equipe`

Le second chantier de la V2 consomme ces contrats, gelés par le Lot 0 de ce chantier :

- `Identity::AnonymizeUser` met `users.student_number` à `NULL` et termine le rattachement `school_staffs` actif (amendement de l'ADR-0036).
- La recherche de comptes de l'annuaire retrouve un élève par son **matricule entier** (égalité stricte, jamais de recherche partielle) : c'est ainsi que l'équipe trouve le compte qui a usurpé un matricule, pour l'anonymiser. L'annuaire ne **modifie** pas un matricule : seul l'élève le corrige (ADR-0065).
- Les listes et fiches de comptes affichent le matricule d'un élève et la fonction d'un membre de la direction.
- Il doit être en production **avant l'ouverture aux élèves** : un matricule usurpé ne se libère que par l'anonymisation (ADR-0065, coûts consentis).
- Il démarre **après la fusion du Lot 0a** de ce chantier (contrats de `users` gelés) ; ses routes et locales de l'équipe attendent notre Lot 0b (plan).
