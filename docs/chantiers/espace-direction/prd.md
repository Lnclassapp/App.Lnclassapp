# PRD — Espace direction, ce qui reste de la V2

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
> **État** : accepté. Amendé au Lot 0 (2026-10-16) sur les réponses du porteur ([memo](memo.md#réponses-du-porteur-2026-10-16)) : **Q5 retirée** (la direction ne change pas un élève de classe : §4.5 et ses scénarios sortent) ; **DIR-4** (aucune direction n'est inscrite : la fonction est obligatoire, « Préciser ma fonction » et le cas « sans fonction » sortent).

## 1. Contexte

L'espace direction est en production avec ses lectures et ses gestes, mais tous les comptes de direction ont les mêmes droits et aucune fonction. La direction ne peut ni changer un élève de classe, ni trouver un élève sans connaître sa classe. Ce chantier ajoute quatre fonctions et deux rangs de droits, la recherche d'un élève dans l'établissement, et la recette du profil côté direction. Le changement de classe d'un élève n'est pas un geste de la direction (Q5) : l'élève le fait lui-même (`changement-etablissement-eleve`).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Direction, rang **gestion** (chef d'établissement, adjoint ou directeur des études) | Tout ce qu'elle fait aujourd'hui ; chercher un élève | Changer une fonction, la sienne comprise ; changer un élève de classe ; agir hors de son établissement |
| Direction, rang **vie scolaire** (éducateur, secrétaire) | Tout lire ; partager le lien d'invitation et le lien d'une classe ; retirer un élève ; chercher un élève | « + » et « − » d'un niveau ; archiver ou restaurer une classe ou un niveau ; retirer ou réintégrer un enseignant ; retirer une direction ; changer une fonction |
| Équipe (admin, field) | Choisir la fonction en invitant ; changer la fonction de toute direction | Agir dans l'espace direction (403, inchangé) |
| Enseignant, élève | Rien de nouveau | Lire une fonction ailleurs que dans le bloc « Direction » |

Règles d'autorisation :

- `Entities::School::StaffPosition` donne le rang d'une fonction (`management` ou `school_life`) ; une fonction absente ou inconnue n'est pas `management` (la règle se ferme par défaut ; la base n'en a pas, DIR-4).
- `ManageSchoolStructurePolicy`, `ManageSchoolTeachersPolicy` et `RemoveSchoolStaffPolicy` exigent, pour une direction, le rang `management` (ADR-0092 §4.3).
- `Policies::School::SetStaffPositionPolicy` (nouvelle) : l'équipe admin ou field ; jamais une direction.
- `ReadOwnSchoolPolicy` (inchangée) garde tout l'espace direction ; l'établissement vient toujours du compte, jamais de l'adresse (ADR-0065).

## 3. Parcours utilisateur

### Chemin nominal

1. Mme Koné s'inscrit comme direction avec le code de son lycée et choisit « Secrétaire ». Le bloc « Direction » affiche « Secrétaire » sous son nom.
2. Sur la page d'un niveau, elle ne voit pas le menu d'archivage ; sur « Enseignants », pas de « Retirer ».
3. Elle tape « kouassi » dans « Chercher un élève » de l'accueil, voit « Kouassi Aya · 6ème 3 », ouvre la classe filtrée sur ce nom.
4. Sur la page de la classe, elle peut retirer un élève ; elle ne change pas un élève de classe (Q5).
5. L'équipe corrige, sur la fiche de l'établissement, la fonction d'une direction qui s'est trompée.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Inscription qui choisit « Chef d'établissement » alors qu'un chef est actif | 422, message sous le champ : « Votre établissement a déjà un chef d'établissement sur Lnclass. Choisissez votre fonction ou contactez l'équipe Lnclass. » |
| Inscription sans fonction | 422, « Choisissez votre fonction. » |
| Direction de rang vie scolaire qui forge un geste de gestion | 403, toast « Vous ne pouvez pas faire ce geste. », rien n'est écrit |
| Direction qui envoie un changement de fonction | 403 (route de l'équipe) |
| Invitation de chef acceptée après l'arrivée d'un autre chef | 422, « Demandez à l'équipe Lnclass une nouvelle invitation. » |
| Recherche de moins de 3 lettres | Aucune liste, indice « 3 lettres au moins. » |
| Recherche sans résultat | État vide « Aucun élève ne porte ce nom dans vos classes. » |

## 4. Critères d'acceptation

Chaque scénario devient au moins un test ; le fichier de test est nommé dans le [plan](plan.md).

### 4.1 Fonctions — socle (Lot 0)

```gherkin
Scénario: ED-01 — une seule fonction parmi quatre, en base
  Étant donné un compte direction actif du Lycée A
  Quand on enregistre la fonction « principal » dans school_staffs.position
  Alors la base refuse la valeur
  Et elle accepte « head », « deputy », « educator », « secretary », jamais NULL (DIR-4)

Scénario: ED-02 — un seul chef d'établissement actif
  Étant donné une direction active du Lycée A de fonction « head »
  Quand une seconde direction active du Lycée A reçoit la fonction « head »
  Alors la base refuse l'écriture
  Et une direction archivée de fonction « head » n'empêche pas l'écriture

Scénario: ED-03 — le libellé du rang 2 suit le type d'établissement
  Étant donné une direction de fonction « deputy »
  Quand son établissement est public
  Alors sa fonction se lit « Adjoint au chef d'établissement »
  Et dans un établissement privé ou mixte, elle se lit « Directeur des études »

Scénario: ED-04 — le bloc « Direction » affiche la fonction
  Étant donné les directions du Lycée A : Mme Koné « secretary », M. Yao « head »
  Quand une direction du Lycée A ouvre « Établissement »
  Alors la ligne de Mme Koné porte « Secrétaire »
  Et la ligne de M. Yao porte « Chef d'établissement »
  Et l'équipe lit les mêmes libellés sur la fiche du Lycée A

Scénario: ED-05 — la session porte la fonction
  Étant donné une direction de fonction « educator » connectée
  Quand l'espace direction construit son acteur
  Alors l'acteur a staff_position « educator »
  Et un enseignant, un élève et un membre de l'équipe ont staff_position nil
```

### 4.2 Choisir sa fonction en arrivant (Lot A)

```gherkin
Scénario: ED-10 — la fonction est obligatoire à l'inscription
  Étant donné le formulaire d'inscription de la direction
  Quand une personne l'envoie sans fonction, avec un code valide
  Alors la réponse est 422 avec « Choisissez votre fonction. »
  Et aucun compte n'est créé

Scénario: ED-11 — l'inscription retient la fonction choisie
  Étant donné le code du Lycée A, public, sans chef actif
  Quand une personne s'inscrit avec la fonction « Adjoint au chef d'établissement »
  Alors son rattachement au Lycée A a la position « deputy »
  Et le journal « school_staff.registered » porte la position

Scénario: ED-12 — un second chef est refusé à l'inscription
  Étant donné le Lycée A, dont le chef d'établissement est actif
  Quand une personne s'inscrit avec la fonction « Chef d'établissement »
  Alors la réponse est 422, le message sous le champ dit de choisir une fonction ou de contacter l'équipe
  Et le nom du chef actif n'apparaît pas dans la réponse

Scénario: ED-13 — deux inscriptions simultanées comme chef
  Étant donné le Lycée A sans chef actif
  Quand deux personnes s'inscrivent en même temps avec la fonction « Chef d'établissement »
  Alors une seule inscription aboutit
  Et l'autre reçoit le refus d'ED-12, sans erreur 500

Scénario: ED-14 — l'équipe choisit la fonction en invitant
  Étant donné un membre de l'équipe sur la fiche du Lycée A
  Quand il invite une direction avec la fonction « Éducateur »
  Alors l'invitation porte la position « educator »
  Et la direction qui accepte l'invitation est rattachée avec « educator »

Scénario: ED-15 — l'invitation d'un second chef est refusée
  Étant donné le Lycée A, dont le chef d'établissement est actif
  Quand l'équipe invite une direction avec la fonction « Chef d'établissement »
  Alors la réponse est 422 « Cet établissement a déjà un chef d'établissement actif. »
  Et aucune invitation n'est créée
```

### 4.3 Changer une fonction (Lot B)

> ED-20 (« Préciser ma fonction ») est retiré par DIR-4 : aucune direction n'est sans fonction.

```gherkin
Scénario: ED-21 — une direction ne change pas sa fonction
  Étant donné Mme Koné, direction de fonction « secretary »
  Quand elle envoie une requête qui fixe sa position à « head »
  Alors la réponse est 403
  Et sa position reste « secretary »

Scénario: ED-22 — une direction ne fixe jamais la fonction d'une autre
  Étant donné M. Yao, chef du Lycée A, et Mme Koné « secretary »
  Quand M. Yao envoie une requête qui fixe la position de Mme Koné
  Alors la réponse est 403

Scénario: ED-23 — l'équipe change la fonction d'une direction
  Étant donné un membre de l'équipe sur la fiche du Lycée A
  Quand il change la fonction de Mme Koné de « Secrétaire » à « Éducateur »
  Alors la ligne de Mme Koné porte « Éducateur » sans rechargement de la page
  Et le journal enregistre « school_staff.position_set » avec l'ancienne et la nouvelle position

Scénario: ED-24 — préciser ou changer vers un chef déjà pris
  Étant donné le Lycée A, dont M. Yao est le chef actif
  Quand l'équipe choisit « Chef d'établissement » pour un autre compte
  Alors la réponse est 422 « Cet établissement a déjà un chef d'établissement actif. »

Scénario: ED-25 — la restauration d'un ancien chef ne crée pas deux chefs
  Étant donné l'ancien chef du Lycée A, archivé, et un nouveau chef actif
  Quand l'équipe restaure l'ancien chef
  Alors la restauration est refusée avec « Cet établissement a déjà un chef d'établissement actif. Changez d'abord une fonction. »
```

### 4.4 Droits par fonction (Lot C)

```gherkin
Scénario: ED-30 — le rang vie scolaire ne touche pas à la structure
  Étant donné Mme Koné, secrétaire du Lycée A actif
  Quand elle envoie « + » sur la ligne « 6ème », « − », l'archivage d'une classe, sa restauration ou l'archivage d'un niveau
  Alors chaque réponse est 403
  Et aucune classe n'est créée, retirée, archivée ni restaurée

Scénario: ED-31 — le rang vie scolaire ne retire ni ne réintègre un enseignant
  Étant donné un éducateur du Lycée A
  Quand il envoie le retrait d'un enseignant du Lycée A, puis la réintégration d'un enseignant retiré
  Alors chaque réponse est 403
  Et le rattachement de l'enseignant n'a pas changé

Scénario: ED-32 — le rang vie scolaire ne retire pas une direction
  Étant donné une secrétaire du Lycée A arrivée depuis 30 jours
  Quand elle envoie le retrait du chef d'établissement
  Alors la réponse est 403
  Et le chef reste actif

Scénario: ED-33 — le rang vie scolaire ne voit pas les gestes qu'il n'a pas
  Étant donné une secrétaire du Lycée A
  Quand elle ouvre « Établissement », la page d'un niveau, « Enseignants » et « Enseignants retirés »
  Alors elle ne voit ni « + », ni « − », ni le menu d'archivage, ni « Retirer de l'établissement », ni « Réintégrer », ni « Retirer de la direction »
  Et elle voit le lien d'invitation, « Copier le lien » et « Partager sur WhatsApp »

Scénario: ED-34 — le rang vie scolaire garde les gestes sur les élèves
  Étant donné un éducateur du Lycée A
  Quand il ouvre la page de la classe 6ème 3
  Alors il voit « Changer le lien » et « Retirer de la classe »
  Et le retrait d'un élève aboutit

Scénario: ED-35 — le rang gestion garde tout
  Étant donné un chef et un adjoint du Lycée A
  Quand chacun ajoute une classe, archive une classe et retire un enseignant
  Alors chaque geste aboutit comme avant ce chantier

Scénario: ED-36 — l'équipe garde ses gestes
  Étant donné un membre de l'équipe
  Quand il ajoute une classe au Lycée A et retire une direction du Lycée A
  Alors chaque geste aboutit comme avant ce chantier
```

### 4.5 Changer un élève de classe (Lot D) — retiré

> Retiré par le porteur (Q5, 2026-10-16) : la direction ne change pas un élève de classe ; l'élève le fait lui-même (`changement-etablissement-eleve`). ED-40 à ED-51 sortent du chantier ; UDR-0093 passe « Abandonnée ».

### 4.6 Trouver un élève dans l'établissement (Lot E)

```gherkin
Scénario: ED-60 — la direction trouve un élève par son nom
  Étant donné Kouassi Aya en 6ème 3 et Kouassi Brou en Tle D1, au Lycée A
  Quand une direction du Lycée A cherche « kouas » depuis l'accueil
  Alors elle voit deux résultats : « Aya Kouassi · 6ème 3 » et « Brou Kouassi · Tle D1 »
  Et chaque résultat mène à la page de sa classe filtrée sur son nom

Scénario: ED-61 — sans accent ni casse, prénom ou nom d'abord
  Quand la direction cherche « AYA KOUASSI » puis « kouassi aya » puis « Aÿa »
  Alors Kouassi Aya est trouvée chaque fois

Scénario: ED-62 — seulement les élèves présents de l'établissement
  Étant donné un élève du Lycée B, un élève retiré de sa classe du Lycée A, un élève d'une classe archivée et un compte anonymisé, tous nommés « Kouassi »
  Quand une direction du Lycée A cherche « kouassi »
  Alors aucun d'eux n'apparaît

Scénario: ED-63 — trois lettres au moins
  Quand la direction envoie la recherche « ko »
  Alors aucune requête de recherche n'est faite sur les élèves
  Et la page affiche « 3 lettres au moins. »

Scénario: ED-64 — vingt résultats au plus
  Étant donné 25 élèves nommés « Koné » au Lycée A
  Quand la direction cherche « kone »
  Alors elle voit 20 résultats et « Affinez votre recherche : 20 premiers résultats. »

Scénario: ED-65 — aucun numéro de téléphone
  Quand la direction cherche « 0701020304 », le numéro d'un élève du Lycée A
  Alors l'élève n'est pas trouvé
  Et aucune réponse de recherche ne contient de numéro de téléphone

Scénario: ED-66 — réservé à la direction
  Étant donné un enseignant, un élève et un membre de l'équipe connectés
  Quand chacun ouvre la recherche d'élèves de l'espace direction
  Alors chaque réponse est 403
```

### 4.7 Recette du profil côté direction (Lot F)

```gherkin
Scénario: ED-70 — la direction change son PIN sous son PIN actuel
  Étant donné une direction connectée, de PIN « 2468 »
  Quand elle change son PIN pour « 1357 » en saisissant « 2468 »
  Alors elle se connecte ensuite avec « 1357 »
  Et le journal enregistre « pin.changed » sans aucun PIN

Scénario: ED-71 — un PIN actuel faux est refusé à la direction
  Quand la direction saisit « 0000 » comme PIN actuel
  Alors la réponse est 422 et son PIN reste « 2468 »

Scénario: ED-72 — la direction met sa photo
  Étant donné une direction connectée
  Quand elle envoie une photo valide depuis « Mon profil »
  Alors l'avatar de son en-tête affiche la photo
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::School::StaffPosition` (nouvelle : codes, rang, clé de libellé) ; `Entities::School::Staff` (+ `position`, `head?`) ; `Entities::Identity::Actor` (+ `staff_position`, `school_management?`) ; `Entities::Identity::AuditAction` (+ `school_staff.position_set`) ; use case `School::SetStaffPosition` ; policy `SetStaffPositionPolicy` (nouvelle) et trois policies amendées ; `StaffRepositoryPort` (+ `set_position`, `head_taken?`, `position:` à l'arrivée) |
| Infrastructure | Migration : `school_staffs.position` (`NOT NULL`, CHECK, index unique partiel du chef) et `invitations.position` (nouvelles valeurs, obligatoire pour une direction) ; `StaffRepository`, `UserRepository` (acteur), `SchoolStaffQuery` (position) ; query `School::StudentSearchQuery` (nouvelle) |
| Delivery | `Teams::SchoolStaffPositionsController`, `SchoolAdmin::StudentSearchesController` (nouveaux) ; inscription et invitation de la direction amendées ; routes dans `config/routes/school_admin.rb` et `config/routes/teams.rb` |
| UI | Champ « Fonction » à l'inscription et à l'invitation ; libellé et « Changer la fonction » (équipe) dans le bloc « Direction » ; gestes masqués au rang vie scolaire, avec une note ; recherche d'élève sur la carte « Établissement » et page de résultats |

## 6. Décisions rattachées

- [ADR-0092](../../decisions/adr/0092-fonctions-de-direction-droits-par-rang-et-changement-de-classe.md) — fonctions de direction, droits par rang *(Accepté ; changement de classe retiré, Q5)*. Amende ADR-0044, 0065, 0071, 0077.
- [UDR-0092](../../decisions/udr/0092-fonction-de-direction-et-gestes-par-rang.md) — fonction à l'inscription, à l'invitation et dans le bloc « Direction » ; gestes masqués au rang vie scolaire *(Accepté)*. Amende UDR-0056, 0070, 0083.
- [UDR-0093](../../decisions/udr/0093-changer-un-eleve-de-classe.md) — « Changer de classe » sur la page d'une classe de la direction *(Abandonnée, Q5)*.
- [UDR-0094](../../decisions/udr/0094-chercher-un-eleve-dans-l-etablissement.md) — recherche d'un élève depuis l'accueil de la direction *(Accepté)*. Amende UDR-0074 §3.3.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Page d'une classe de la direction, p95 (budget ADR-0067) | à mesurer au Lot 0 | < 100 ms, inchangée à ± 10 % | |
| Recherche d'un élève, établissement de 2 000 élèves, p95 | — | < 100 ms (index trigramme `index_users_on_searchable_full_name`) | |
| Accueil de la direction, HTML | à mesurer au Lot 0 | < 150 Ko (ADR-0067) | |
