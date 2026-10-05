# Onboarding de la direction d'un établissement

> **À qui s'adresse ce guide.** À l'équipe Lnclass qui fait entrer la direction d'un établissement (Proviseur, Censeur, Adjoint au chef d'établissement, Directeur des études…), et à la personne de la direction elle-même. Il décrit ce qui est **en production** aujourd'hui. En cas d'écart, [`docs/decisions/`](../decisions/) fait foi.
>
> **Une seule fonction pour l'instant.** Lnclass ne distingue pas encore les fonctions : toute personne invitée est « direction » de son établissement, avec les mêmes droits. Les fonctions (Proviseur, Censeur, Éducateur, Secrétaire) arriveront plus tard.

---

## Les liens à retenir

Les adresses ci-dessous se lisent après l'adresse de Lnclass (par exemple `<adresse de Lnclass>/login`).

| Page | Lien | Qui |
|---|---|---|
| Inviter la direction | Équipe → fiche de l'établissement → ⋮ → « Inviter la direction » (`/teams/schools/<établissement>/staff-invitations/new`) | Équipe |
| Créer son compte (inscription) | `/invitations/<jeton>` : le lien d'invitation reçu, valable **72 h** | Direction |
| Se connecter | `/login` | Direction |
| PIN oublié | `/identity/pin-reset`, lien « PIN oublié ? » de la connexion | Direction |
| Travail des élèves (accueil) | `/school-admin/classrooms` | Direction |
| Enseignants | `/school-admin/teachers` | Direction |
| Enseignants retirés | `/school-admin/teachers/departed` | Direction |
| Établissement (lien d'inscription, classes) | `/school-admin/school` | Direction |
| Mon profil | `/profile` | Direction |

Le lien d'inscription des **enseignants**, que la direction diffuse, a la forme `/e/<code>` (le code d'établissement, par exemple `K7M4QZ`).

---

## 1. L'équipe invite la direction

Prérequis : l'établissement est importé et **actif**. Un établissement en brouillon ou désactivé ne propose pas « Inviter la direction ».

1. Équipe → **Établissements** → ouvrir la fiche de l'établissement.
2. Menu **⋮** de l'en-tête → **« Inviter la direction »**.
3. Saisir le **numéro** de la personne (10 chiffres, par exemple `07 00 00 00 00`). Ce numéro lui servira à se connecter.
4. **« Créer l'invitation »** : le **lien d'invitation** s'affiche, avec « Copier le lien ».
5. Le copier **avant de fermer la fenêtre** : il ne s'affiche qu'une fois. L'envoyer à la personne hors de Lnclass (WhatsApp, SMS).

Le lien expire au bout de **72 heures**. On peut inviter plusieurs personnes de la direction : une invitation par numéro.

| Message | Ce qu'il veut dire | Que faire |
|---|---|---|
| « Ce numéro a déjà un compte Lnclass. » | Le numéro sert déjà, par exemple à un compte enseignant | Inviter un autre numéro de la personne |
| « Une invitation attend déjà ce numéro. » | Une invitation de moins de 72 h est en cours | Retrouver le lien envoyé, ou attendre son expiration puis réinviter |
| « Cet établissement n'est pas actif. » | L'établissement est en brouillon ou désactivé | L'activer d'abord |

---

## 2. La direction crée son compte (inscription)

1. Ouvrir le **lien d'invitation** reçu (`/invitations/<jeton>`).
2. La page « **Créer votre compte de direction** » affiche « Vous rejoignez *<établissement>* comme direction ».
3. Remplir :
   - **Identité** : nom, prénom(s), genre ;
   - **Sécurité** : un **PIN à 4 chiffres** et sa confirmation.

   Le numéro n'est pas demandé : c'est celui qui a reçu l'invitation.
4. **« Créer mon compte »**. Lnclass ouvre la page de connexion, numéro déjà rempli, avec le message « Votre compte est créé. Connectez-vous avec votre numéro et votre PIN. »

> **« Ce lien d'invitation n'est plus valable ».** Le lien a expiré (72 h), a déjà servi ou a été annulé. Demander une nouvelle invitation à l'équipe Lnclass.

---

## 3. Se connecter

1. Aller sur **`/login`** (bouton « Se connecter » de la page d'accueil).
2. Saisir son **numéro** (10 chiffres) et son **PIN**.
3. **« Se connecter »** → « Connexion réussie » : la direction arrive sur **« Travail des élèves »**.

La direction n'a **pas** de second facteur (code d'une application d'authentification) : numéro et PIN suffisent. Seule l'équipe Lnclass en a un.

Au-delà de 5 essais par minute, la connexion est bloquée un moment. Pour se déconnecter : menu du compte → « Se déconnecter ».

### PIN oublié

1. Contacter l'**équipe Lnclass**, qui donne un **code de récupération** (8 chiffres, valable 15 minutes).
2. Sur la connexion, cliquer **« PIN oublié ? »** (`/identity/pin-reset`).
3. Saisir le code, puis un nouveau PIN → « Enregistrer le nouveau PIN » → se reconnecter.

---

## 4. L'espace direction

La navigation compte trois entrées. L'établissement est toujours celui du compte : la direction ne voit jamais un autre établissement.

### 4.1 Travail des élèves (accueil)

`/school-admin/classrooms` : les classes de l'année, avec leur activité. Une classe s'ouvre pour voir ses élèves et leurs résultats. « Anciens élèves » liste les élèves qui ont quitté l'établissement.

### 4.2 Établissement

`/school-admin/school`

- **Inviter vos enseignants** : le **lien d'inscription** (`/e/<code>`) et le code d'établissement. Utiliser « **Copier le lien** » ou « **Partager sur WhatsApp** » (groupe des professeurs, affichage en salle des professeurs). L'enseignant qui ouvre le lien s'inscrit avec l'établissement déjà rempli.
- **Changer le lien** : seulement si le lien a circulé hors de l'établissement. L'ancien lien et l'ancien code cessent aussitôt de marcher, y compris les liens de parrainage des enseignants. Les enseignants déjà inscrits restent.
- **Classes par niveau** :
  - le **« + »** d'un niveau ajoute la classe suivante (« 6ème 5 ») ;
  - le **« − »** retire la dernière, **seulement si elle n'a jamais servi** (aucun élève, aucun enseignant, aucun devoir) ; elle est alors supprimée définitivement.

> Si l'établissement n'est pas actif, la page se consulte mais ne se modifie pas.

### 4.3 Enseignants

`/school-admin/teachers` : les enseignants inscrits.

- **Retirer un enseignant qui a quitté l'établissement** : ⋮ sur sa ligne → « **Retirer de l'établissement** » → confirmer. Il ne voit plus l'établissement ni ses classes, et ses devoirs encore actifs sont archivés. Les classes, les élèves et leurs résultats restent. Il garde son compte et peut rejoindre un **autre** établissement avec le code ou le lien de celui-ci.
- **Réintégrer un enseignant retiré** : « **Enseignants retirés** » (`/school-admin/teachers/departed`) → « **Réintégrer** ». Il revient dans l'établissement et doit redéclarer ses classes. Lui seul ne peut pas revenir : c'est la direction qui le réintègre.

### 4.4 Mon profil

`/profile` : nom, numéro, PIN (le PIN actuel est demandé) et photo.

---

## 5. Ce que la direction ne fait pas (encore)

- Inviter un autre membre de la direction : c'est l'équipe Lnclass qui invite (§1).
- Valider un enseignant inscrit sans code : ce sont ses collègues garants et l'équipe.
- Changer un élève de classe, voir un numéro de téléphone, renommer une classe.
- Donner un code de récupération de PIN : c'est l'équipe.

---

## 6. Check-list

**Équipe**
- [ ] Établissement **actif**, classes de l'année présentes
- [ ] Direction invitée, lien envoyé dans les 72 h

**Direction**
- [ ] Compte créé depuis le lien d'invitation
- [ ] Première connexion sur `/login`
- [ ] Lien d'inscription partagé aux enseignants
- [ ] Classes vérifiées, classe manquante ajoutée par « + »
- [ ] Inscriptions des enseignants suivies dans « Enseignants »

---

## 7. Où trouver les règles exactes

| Sujet | Décision |
|---|---|
| Invitation de la direction, espace en lecture | [ADR-0065](../decisions/adr/0065-espace-direction-simple-en-lecture-seule.md), [UDR-0052](../decisions/udr/0052-espace-direction-simple.md) |
| Gestes de la direction : lien, classes, enseignants | [ADR-0071](../decisions/adr/0071-gestes-de-la-direction-sur-son-etablissement.md), [UDR-0056](../decisions/udr/0056-gestes-de-la-direction.md) |
| PIN oublié, code de récupération | [ADR-0032](../decisions/adr/0032-recuperation-assistee-du-pin.md) |
| Page de connexion, numéro pré-rempli | [UDR-0054](../decisions/udr/0054-finitions-d-interface.md) |
