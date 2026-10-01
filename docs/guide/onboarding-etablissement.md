# Onboarding d'un établissement : l'équipe, la direction, les enseignants

> **À qui s'adresse ce guide.** À l'équipe Lnclass (terrain, administration) qui fait entrer un établissement, et aux personnes qu'elle accompagne : la direction (Proviseur, Censeur, Directeur des études, Éducateur, Secrétaire) et les enseignants. Ce guide décrit les parcours tels qu'ils sont décidés et codés. Il ne remplace pas les décisions : en cas d'écart, [`docs/decisions/`](../decisions/) fait foi.
>
> **Ce qui marche aujourd'hui et ce qui arrive.**
>
> | Parcours | État |
> |---|---|
> | Intégrer un établissement (équipe) | ✅ En production (V1) |
> | Inscription et premiers pas de l'enseignant | ✅ En production (V1) |
> | Inscription de l'élève par le code de sa classe | ✅ En production (V1). Le **matricule** obligatoire arrive avec la V2 |
> | Espace direction (Proviseur, Censeur, Directeur des études…) | 🚧 En construction : chantier [`espace-direction`](../chantiers/espace-direction/prd.md), vague V2. Décisions acceptées le 2026-09-28, socle (Lot 0a) livré, écrans à venir |
>
> Tant que l'espace direction n'est pas livré, **l'équipe fait à la place de la direction** les gestes décrits en §3 (classes, code d'établissement).

---

## 1. Les mots à connaître

| Mot | Ce que c'est |
|---|---|
| **DRENA** | Direction régionale de l'Éducation nationale. Chaque établissement appartient à une DRENA. |
| **Établissement** | Un lycée ou un collège, public, privé ou mixte. Statut : **brouillon**, **actif** ou **désactivé**. Seul un établissement **actif** accepte des inscriptions. |
| **Code d'établissement** | 6 caractères, affichés `K7M-4QZ`. Il sert aux **enseignants** pour s'inscrire. Son lien de partage est `/e/<code>`. |
| **Code national** | Les 6 chiffres de l'établissement dans les résultats du BEPC (`012345`). Il sert quand l'établissement n'a pas encore de code Lnclass. |
| **Classe** | Une classe d'une année scolaire (« 6ème 1 », « Tle D 2 »), avec un plafond d'effectif (80 par défaut). |
| **Code d'adhésion** | Le code d'**une classe** : 5 caractères, affichés `KFM-37`. Il sert aux **élèves** pour rejoindre leur classe. Son lien est `/c/<code>`. **Ne pas confondre avec le code d'établissement.** |
| **Barème** | Le nombre de classes par niveau et par type d'établissement, d'après lequel Lnclass génère les classes. |
| **Garant** | Un enseignant déjà inscrit dans l'établissement qui confirme un collègue inscrit sans code. |
| **Matricule** | Le matricule MENA de l'élève : 8 chiffres et une lettre (`12345678A`). Obligatoire à l'inscription à partir de la V2. |
| **Second facteur** | Un code à 6 chiffres donné par une application d'authentification (Google Authenticator, Microsoft Authenticator…), exigé en plus du PIN pour l'équipe, puis pour la direction en V2. |

Tout le monde se connecte avec son **numéro de téléphone** ivoirien (10 chiffres) et un **PIN à 4 chiffres**, sur `/login`.

---

## 2. Intégrer un établissement (équipe) ✅

L'établissement n'est jamais créé à la main : il entre par **import**.

### 2.1 Préparer

1. Vérifier que la **DRENA** de l'établissement existe (Équipe → DRENA). Sinon, la créer.
2. Vérifier le **barème** des classes pour le type de l'établissement (public, privé, mixte) : c'est lui qui dit combien de « 6ème », de « 2nde C »… seront générées. Une ligne absente vaut 0 classe ([ADR-0058](../decisions/adr/0058-bareme-des-classes-en-base.md)).

### 2.2 Importer

1. Équipe → **Imports** → nouvel import de type « Établissements », avec le fichier JSON.
2. Suivre le **rapport d'import** : lignes importées, lignes refusées et motif de chaque refus.
3. À l'import, Lnclass donne à chaque établissement :
   - son **code d'établissement**, unique ([ADR-0057](../decisions/adr/0057-code-d-etablissement.md)) ;
   - ses **classes de l'année**, générées d'après le barème, chacune avec son code d'adhésion ([ADR-0030](../decisions/adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md)).
4. Si des établissements n'ont aucune classe de l'année (barème modifié après coup, nouvelle année), lancer « **Générer les classes manquantes** » depuis la liste des établissements. Le travail tourne en arrière-plan et produit son propre rapport ([ADR-0056](../decisions/adr/0056-generation-des-classes-manquantes.md)). Seuls les établissements actifs ou en brouillon **sans aucune classe de l'année** reçoivent des classes.

### 2.3 Ouvrir l'établissement

1. Ouvrir la **fiche** de l'établissement et vérifier le nom, la DRENA, le type et les classes par niveau.
2. Ajuster les classes si besoin : le **« + »** d'un niveau ajoute la classe suivante (« 6ème 5 ») ; le **« − »** retire la dernière, seulement si elle n'a jamais servi ([ADR-0059](../decisions/adr/0059-ajuster-les-classes-d-un-niveau.md)).
3. Passer le statut à **actif**. Un établissement en brouillon ou désactivé refuse les inscriptions d'enseignants.
4. Relever le **code d'établissement** sur la fiche (bouton « Copier le code » ou « Copier le lien ») et le transmettre à l'établissement, hors de Lnclass (appel, WhatsApp, visite).

> **Régénérer le code** (menu de la fiche) le remplace aussitôt : l'ancien code et tous les liens déjà partagés cessent de marcher. Les enseignants déjà inscrits restent rattachés. À faire seulement si le code a fuité hors de l'établissement.

> **Désactiver** un établissement le retire des inscriptions et de la création de classes ; ses classes, ses élèves et ses enseignants sont conservés. **Supprimer** n'est possible que si aucune classe n'a jamais servi.

### 2.4 Check-list de l'équipe

- [ ] DRENA présente, barème vérifié
- [ ] Import passé, rapport sans refus inexpliqué
- [ ] Classes de l'année présentes sur la fiche
- [ ] Statut **actif**
- [ ] Code d'établissement transmis à l'établissement
- [ ] (V2) Proviseur invité, voir §3.1

---

## 3. La direction : Proviseur, Censeur, Directeur des études, Éducateur, Secrétaire 🚧

> **En construction (V2).** Ce qui suit décrit l'espace direction tel que décidé ([ADR-0066](../decisions/adr/0066-espace-direction-droits-et-gestes.md), [UDR-0052](../decisions/udr/0052-espace-direction.md)). Il n'est pas encore ouvert : d'ici là, l'équipe fait ces gestes depuis la fiche de l'établissement.

### 3.1 Les quatre fonctions

Lnclass connaît quatre fonctions de direction, et pas plus ([ADR-0044](../decisions/adr/0044-rattachement-de-la-direction-par-invitation.md)). Une fonction qui n'est pas dans la liste prend la plus proche :

| Dans l'établissement | Fonction dans Lnclass | Niveau de droits |
|---|---|---|
| Proviseur, Directeur (privé) | **Proviseur** | Gère |
| Censeur, **Directeur des études** | **Censeur** | Gère |
| Éducateur, surveillant général | **Éducateur** | Voit et organise |
| Secrétaire | **Secrétaire** | Voit et organise |

> Le **Directeur des études** d'un établissement privé est rattaché comme **Censeur** : c'est la fonction la plus proche (pilotage pédagogique, mêmes droits). Lnclass ne crée pas de fonction de plus.

| Geste | Proviseur | Censeur | Éducateur | Secrétaire |
|---|:-:|:-:|:-:|:-:|
| Voir le tableau de bord, les classes, les enseignants, les élèves, le personnel, le code | ✅ | ✅ | ✅ | ✅ |
| Ajouter la classe suivante d'un niveau (« + ») | ✅ | ✅ | ✅ | ✅ |
| Changer un élève de l'établissement de classe | ✅ | ✅ | ✅ | ✅ |
| Inviter un Censeur, un Éducateur, une Secrétaire | ✅ | ✅ | | |
| Régénérer le code d'établissement | ✅ | ✅ | | |
| Retirer un enseignant, le réintégrer | ✅ | ✅ | | |
| Retirer un membre du personnel (jamais soi-même, jamais le Proviseur) | ✅ | ✅ | | |

**Personne dans la direction ne peut** : inviter un Proviseur (c'est l'équipe qui le fait) ; valider un enseignant en attente (ce sont les collègues garants et l'équipe, §4.2) ; voir la note d'un élève nommé ou un numéro de téléphone ; modifier un matricule ; créer une classe au nom libre, retirer ou renommer une classe ; agir sur un autre établissement.

### 3.2 Entrée de la direction, pas à pas

**Côté équipe**
1. Ouvrir la fiche de l'établissement **actif**, section « Direction » → « Inviter la direction ».
2. Saisir le numéro du Proviseur (un numéro **qui n'a pas encore de compte Lnclass**) et choisir « Proviseur ».
3. Un **lien d'invitation** s'affiche **une seule fois**. Le copier et l'envoyer au Proviseur hors de Lnclass. Il expire au bout de **72 heures**.

**Côté Proviseur**
1. Ouvrir le lien : « Rejoindre la direction de <établissement> · Fonction : Proviseur ».
2. Saisir son nom, ses prénoms, son genre et choisir un PIN à 4 chiffres.
3. Se connecter avec son numéro et son PIN.
4. **Activer le second facteur** : installer une application d'authentification sur son téléphone, scanner le QR code, saisir le code à 6 chiffres.
5. **Noter et garder les codes de secours** affichés une seule fois : ils remplacent l'application si le téléphone est perdu.
6. Arriver sur le **tableau de bord** de l'établissement.

À chaque connexion suivante : numéro, PIN, puis code du second facteur.

**Le Proviseur constitue son équipe** : Établissement → « Inviter un membre » → numéro, fonction (Censeur, Éducateur ou Secrétaire) → lien à transmettre. Le **Directeur des études** est invité comme **Censeur**. Au plus 30 invitations par heure.

### 3.3 Le premier jour de la direction

1. **Établissement** : lire le code d'établissement, le **copier** et le diffuser aux enseignants (groupe WhatsApp des professeurs, affichage en salle des professeurs).
2. **Classes** : vérifier les classes de l'année ; ajouter une classe manquante par le « + » de son niveau. Chaque classe a son **code d'adhésion**, à donner aux élèves de la classe.
3. **Enseignants** : suivre les inscriptions au fil des jours (liste paginée, filtrable par classe).
4. **Élèves** : suivre les inscriptions ; corriger une erreur de classe par « Changer de classe » sur la ligne de l'élève, ou par « Chercher par matricule » (le matricule **entier** d'un élève de l'établissement).
5. **Accueil** : le tableau de bord montre le nombre de classes, d'enseignants et d'élèves, puis, pour chaque classe, l'effectif, les devoirs donnés, le taux de rendu et la moyenne. Une classe de moins de 5 élèves affiche « — » pour la moyenne : aucune note d'élève n'est reconnaissable.

### 3.4 Situations courantes

| Situation | Que faire |
|---|---|
| Le lien d'invitation a expiré ou s'est perdu | Attendre son expiration (72 h), puis réinviter le même numéro |
| « Ce numéro a déjà un compte Lnclass. » | Une invitation vise un numéro sans compte : utiliser un autre numéro, ou contacter l'équipe |
| Téléphone perdu, plus de second facteur | Utiliser un code de secours ; sinon, l'équipe **réinitialise** le second facteur depuis « Débloquer un compte », et le membre le réactive à sa connexion suivante |
| PIN oublié | « PIN oublié » sur la page de connexion, avec un code de récupération donné par l'équipe |
| Un enseignant quitte l'établissement | Proviseur ou Censeur : Enseignants → ⋮ → « Retirer de l'établissement ». Ses classes, devoirs et résultats restent ; il garde son compte et peut rejoindre un **autre** établissement avec son code. Il ne peut **pas** revenir seul dans celui-ci |
| Enseignant retiré par erreur | Proviseur ou Censeur : « Enseignants retirés » → « Réintégrer ». Il retrouve l'établissement et se redéclare dans ses classes |
| Le code d'établissement a fuité | Proviseur ou Censeur : Établissement → « Régénérer le code ». L'ancien code et ses liens cessent de marcher |
| Changement de Proviseur | L'équipe retire l'ancien et invite le nouveau. En attendant, le Censeur gère l'établissement |
| Un membre du personnel part | Proviseur ou Censeur : Établissement → ⋮ → « Retirer ». Il est déconnecté partout et ne voit plus que son profil |
| L'établissement est désactivé | Toute la direction ne voit plus que l'écran d'attente et son profil |

---

## 4. Les enseignants ✅

### 4.1 S'inscrire avec le code d'établissement (cas normal)

1. Ouvrir le **lien** `/e/<code>` reçu de la direction ou d'un collègue (l'établissement est déjà rempli), ou aller sur « Inscription enseignant » et saisir le **code d'établissement** (6 caractères, `K7M-4QZ`).
2. Vérifier le bandeau « Votre établissement » (nom et DRENA).
3. Remplir : nom, prénom(s), genre, numéro de téléphone (10 chiffres, il sert à se connecter), **matière enseignée**, PIN à 4 chiffres et sa confirmation.
4. « Créer mon compte ».
5. **« Quelles classes enseignez-vous ? »** : cocher ses classes dans l'établissement, puis « Terminer la configuration ».
6. Arriver sur l'**accueil** : « Mes classes ».

> **Erreurs fréquentes.** « Ce code est un code de classe » : c'est le code d'adhésion d'une classe (élèves), pas le code d'établissement. « Code d'établissement invalide » : le code a été régénéré, l'établissement n'est pas actif, ou il y a une faute de frappe ; le redemander à la direction. Au-delà de 10 essais par minute, Lnclass bloque un moment.

### 4.2 S'inscrire sans code (l'établissement n'a pas encore son code)

1. Sur l'inscription, choisir « **Mon établissement n'a pas encore de code Lnclass** ».
2. Désigner l'établissement par son **code national** (6 chiffres du BEPC) ou en choisissant la **DRENA** puis l'établissement.
3. Remplir le reste du formulaire comme en §4.1.
4. Le compte est **en attente** : « Votre demande est en cours de validation ».
5. Il est validé par :
   - **un collègue déjà inscrit** dans l'établissement (le garant), depuis son accueil, bloc « Collègues en attente » → « **Je confirme** », seulement s'il connaît la personne ;
   - ou **l'équipe Lnclass**, depuis la fiche de l'établissement (demandes en attente).
6. Une fois validé, l'enseignant se connecte et choisit ses classes (§4.1, étape 5).

> **La direction ne valide pas les comptes en attente** (décision du porteur, Q1) : ce sont les collègues garants et l'équipe.

### 4.3 Faire entrer ses élèves

1. Ouvrir une de ses classes (accueil → « Ouvrir la classe »).
2. Copier le **code d'adhésion** de la classe (`KFM-37`) ou « **Partager sur WhatsApp** » : le message contient le lien `/c/<code>` et le code.
3. L'élève ouvre le lien (ou « Rejoindre une classe », puis saisit le code) et crée son compte : nom, prénom(s), genre, numéro, PIN. À partir de la V2, il saisit aussi son **matricule** (8 chiffres et une lettre, sur sa carte scolaire ou son bulletin).
4. La classe affiche son effectif (« 34 / 80 »). Une classe pleine refuse les nouveaux élèves.

> Un élève a **une seule classe principale active**. Il ne peut pas en rejoindre une autre tant que la sienne est active ; une erreur de classe se corrige par la direction (V2) ou par l'équipe.

### 4.4 Inviter ses collègues

Accueil → « **Inviter un collègue** » : un lien personnel, à partager par WhatsApp, SMS ou copier-coller. Le collègue s'inscrit avec l'établissement déjà rempli, et l'inscription est comptée comme un parrainage (badge « Ambassadeur »). Seul un enseignant d'un établissement **actif** peut inviter.

### 4.5 Ensuite

- **Assigner un cours** : Cours → ouvrir un cours du catalogue → l'assigner à une ou plusieurs de ses classes.
- **Modifier ses classes** : accueil → « Modifier mes classes ».
- **Un élève a oublié son PIN** : l'enseignant de sa classe lui donne un code de récupération depuis la liste des élèves de la classe ; l'élève le saisit sur « PIN oublié ».
- **Mon profil** : nom, numéro, PIN (sous le PIN actuel), photo.

---

## 5. Le calendrier type d'un établissement

| Quand | Qui | Quoi |
|---|---|---|
| J − 7 | Équipe | DRENA, barème, import, classes, statut actif (§2) |
| J − 5 | Équipe | Code d'établissement transmis ; (V2) invitation du Proviseur (§3.2) |
| J − 3 | Direction (V2) ou équipe | Classes vérifiées et complétées ; code diffusé aux enseignants |
| J − 3 à J | Enseignants | Inscription par code, choix des classes, invitation des collègues (§4.1, §4.4) |
| J | Enseignants | Codes d'adhésion donnés aux élèves en classe (§4.3) |
| J + 7 | Direction (V2) ou équipe | Tableau de bord : classes sans enseignant, classes sans élève, erreurs de classe corrigées |

---

## 6. Où trouver les règles exactes

| Sujet | Décision |
|---|---|
| Classes générées, une école par enseignant | [ADR-0030](../decisions/adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md), [ADR-0056](../decisions/adr/0056-generation-des-classes-manquantes.md), [ADR-0058](../decisions/adr/0058-bareme-des-classes-en-base.md), [ADR-0059](../decisions/adr/0059-ajuster-les-classes-d-un-niveau.md) |
| Code d'établissement | [ADR-0057](../decisions/adr/0057-code-d-etablissement.md), [UDR-0044](../decisions/udr/0044-inscription-enseignant-par-code-d-etablissement.md) |
| Vie d'une classe, code d'adhésion, plafond | [ADR-0041](../decisions/adr/0041-vie-d-une-classe-annee-scolaire-et-code.md), [UDR-0009](../decisions/udr/0009-rejoindre-une-classe.md) |
| Inscription sans code, garants, parrainage | [ADR-0063](../decisions/adr/0063-parrainage-demarrage-a-froid-et-mesure-du-k-factor.md), [UDR-0050](../decisions/udr/0050-inviter-un-collegue-et-croissance.md) |
| Direction : invitation, fonctions, droits | [ADR-0044](../decisions/adr/0044-rattachement-de-la-direction-par-invitation.md), [ADR-0066](../decisions/adr/0066-espace-direction-droits-et-gestes.md), [UDR-0052](../decisions/udr/0052-espace-direction.md) |
| Tableau de bord de l'établissement | [ADR-0067](../decisions/adr/0067-tableau-de-bord-de-l-etablissement.md) |
| Matricule de l'élève | [ADR-0065](../decisions/adr/0065-matricule-de-l-eleve.md), [UDR-0053](../decisions/udr/0053-matricule-de-l-eleve.md) |
| Second facteur | [ADR-0031](../decisions/adr/0031-second-facteur-totp-pour-l-equipe.md) |
