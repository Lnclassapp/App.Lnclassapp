# Pages publiques — textes à faire valider par les juristes

> **Statut : textes complets, 2026-10-02**, à faire valider par les juristes **avant la sortie de l'application**. Contrat d'interface : [UDR-0063](../../decisions/udr/0063-pages-publiques-mission-confidentialite-cgu-cgv.md). Aucun de ces textes n'est en ligne : une page n'entre dans `ONLINE` qu'après la validation des juristes (lot Z du [plan](plan.md)).
>
> **Règle de rédaction.** Chaque fait décrit le fonctionnement réel de l'application (code, schéma, ADR) ; ses sources sont au §6, hors du texte publié. Les informations légales viennent du porteur (2026-10-02). Ce que seuls les juristes peuvent écrire est signalé dans le texte par **‹ … : à compléter par les juristes ›** ; ces marques disparaissent à la validation. Le test de garde de l'UDR-0063 §3.3 refuse une page en ligne qui en contient encore.
>
> Ton : vouvoiement (UDR-0063 §3.3).

> ### ⚖️ Relecture juridique — ce que les juristes doivent compléter ou valider
>
> **À compléter** (le porteur ne les fournira pas) :
> 1. Le **numéro RCCM** de Lnclass Côte d'Ivoire SARL (Protection des données §1, CGU §1, CGV §1).
> 2. La **déclaration ou l'autorisation auprès de l'ARTCI** et sa référence (Protection des données §2).
> 3. Le **droit applicable et les tribunaux compétents** (CGU §11, CGV §10) ; la rédaction proposée retient le droit ivoirien.
> 4. La **responsabilité** de Lnclass : disponibilité, limites, force majeure (CGU §9, CGV §9).
> 5. L'**âge minimum** et l'**accord des parents** pour un élève mineur (Protection des données §10, CGU §10).
> 6. Les **bases légales** de chaque finalité (Protection des données §4).
> 7. Les **transferts** de données hors de Côte d'Ivoire, selon la région d'hébergement (Protection des données §6).
> 8. La **TVA** : le prix de 16 000 F CFA est-il toutes taxes comprises ou hors TVA (CGV §2).
> 9. Le **droit de rétractation légal** applicable en Côte d'Ivoire, son délai, et son articulation avec le remboursement sous 7 jours (CGV §7).
> 10. Les **réclamations** : délai de réponse, procédure et **médiation** (CGV §8).
>
> **À valider** :
> 11. Le cadre cité (**loi n° 2013-450 du 19 juin 2013**, ARTCI) et la liste des droits (Protection des données §2, §9).
> 12. La règle de conservation donnée par le porteur (révisée le 2026-10-02) — **pas d'anonymisation** ; données gardées comme **archive**, consultables par l'élève et par l'établissement quitté ; **suppression sur demande, sous 30 jours** — et sa formulation (lot R).
> 13. L'acceptation des CGU (aujourd'hui, aucune case à cocher à l'inscription) et la procédure de modification des conditions (CGU §1, §12).
> 14. La licence d'usage du contenu et l'usage acceptable (CGU §4, §5) ; la suspension d'un compte (CGU §7).
> 15. Les CGV entières, avec l'offre fixée par le porteur (2026-10-02, grill du chantier `abonnement-mobile-money`) : prix sans prorata, 30 premiers jours gratuits (14 jours d'accès complet, puis du 15e au 30e jour des rappels pour s'abonner), exercices visibles mais aucun à commencer sans abonnement, remboursement sous 7 jours, numéro de transaction Wave comme reçu.
>
> **Avant la sortie, côté produit** (pas les juristes) : le lot R livré (archive consultable par l'élève parti, suppression sur demande sous 30 jours). Numéros et horaires du support : fournis le 2026-10-02.

## Sommaire

1. [Notre mission](#1-notre-mission--mission)
2. [Politique de protection des données](#2-politique-de-protection-des-données--confidentialite)
3. [Conditions générales d'utilisation](#3-conditions-générales-dutilisation--conditions-utilisation)
4. [Conditions générales de vente](#4-conditions-générales-de-vente--conditions-vente)
5. [Informations légales, récapitulatif](#5-informations-légales-récapitulatif)
6. [Sources des faits](#6-sources-des-faits)

---

## 1. Notre mission — `/mission`

> À valider par le porteur : la page reprend ce que la landing et la documentation disent déjà, sans chiffre, partenaire ni promesse nouvelle.

**`h1` — Notre mission**

**Faire comprendre, chap chap.**
Lnclass aide les élèves de Côte d'Ivoire, de la 6e à la Terminale, à comprendre leurs cours et à s'entraîner, avec leurs enseignants.

**Pour qui**
- **Les élèves** apprennent à leur rythme : ils rejoignent leur classe avec son code, révisent les fiches essentielles et s'entraînent avec des exercices corrigés.
- **Les enseignants** guident leur classe : ils déclarent leurs classes, leur donnent des exercices pour la séance suivante et suivent les résultats de leurs élèves.
- **Les établissements** suivent le travail de leurs élèves et gèrent leurs enseignants.

**Ce que nous faisons**
- **Le programme officiel**, de la 6e à la Terminale : des cours, des fiches essentielles et des exercices, pour préparer le BEPC et le BAC.
- **Un peu chaque jour** : des exercices courts, avec la correction détaillée de chaque question.
- **La progression rendue visible** : des badges (Bronze, Argent, Or, Diamant) et la maîtrise de chaque exercice.

**Comment nous le faisons**
- **Une application légère**, conçue pour les téléphones d'entrée de gamme et les connexions modestes.
- **Sans traceur** : aucun script, aucune police, aucun outil de mesure venant d'un tiers.

Lnclass est édité par **Lnclass Côte d'Ivoire SARL**, à Tiassalé.

---

## 2. Politique de protection des données — `/confidentialite`

**`h1` — Protection de vos données personnelles**
« Mis à jour le ‹ date de validation : à compléter par les juristes › »

Lnclass est utilisé par des élèves, souvent mineurs, par leurs enseignants et par leurs établissements. Cette politique dit quelles données nous enregistrons, pourquoi, qui les voit, combien de temps nous les gardons et comment exercer vos droits.

### 1. Qui est responsable de vos données

Le responsable du traitement est **Lnclass Côte d'Ivoire SARL**, Tiassalé, au feu du marché, vers la Pharmacie Saint-Joseph, Côte d'Ivoire — RCCM ‹ numéro : à compléter par les juristes ›.

Pour toute question sur vos données : **+225 05 44 32 00 20** ou **+225 05 84 25 80 85**.

### 2. Le cadre applicable

Ce traitement relève de la loi ivoirienne **n° 2013-450 du 19 juin 2013 relative à la protection des données à caractère personnel**. L'autorité de contrôle est l'**ARTCI** (Autorité de Régulation des Télécommunications/TIC de Côte d'Ivoire). ‹ Déclaration ou autorisation auprès de l'ARTCI et sa référence : à compléter par les juristes ›

### 3. Les données que nous enregistrons

| Catégorie | Données | Qui est concerné |
|---|---|---|
| Identité | Nom, prénom(s), genre | Tous les comptes |
| Contact | Numéro de téléphone ivoirien, qui sert aussi à se connecter | Tous les comptes |
| Code secret | PIN à 4 chiffres, **jamais enregistré en clair** | Tous les comptes |
| Rattachement | Rôle (élève, enseignant, direction, équipe), classe et dates d'arrivée et de départ, établissement, matière enseignée, classes déclarées, jours de séance de l'enseignant | Selon le rôle |
| Photo de profil, facultative | Image carrée, dont nous retirons les informations cachées (lieu, appareil) avant de la garder | Comptes qui en ajoutent une |
| Travail scolaire | Exercices commencés et terminés, réponses, notes, badges, fiches à revoir | Élèves |
| Travail de l'enseignant | Exercices donnés à ses classes et leurs dates limites | Enseignants |
| Sécurité | Connexions ouvertes (adresse IP, navigateur, dates), tentatives de connexion (numéro saisi, adresse IP, réussite ou échec), codes de récupération du PIN (sous forme non lisible) ; pour l'équipe, le second facteur | Tous les comptes |
| Journal des actions sensibles | Qui a fait quoi et quand (verrouillage, PIN réinitialisé, changement de nom, de numéro ou de photo, publication d'un contenu, retrait d'un enseignant), avec l'adresse IP ; jamais un code secret | Comptes qui font ces actions, et comptes concernés |
| Invitations et parrainage | Numéro d'une personne invitée (direction, équipe), qui a invité qui, canal de partage d'un lien (WhatsApp, SMS, copie) | Enseignants, direction, équipe |

**Ce que nous n'enregistrons pas** : aucune adresse électronique, aucune date de naissance, aucune adresse postale ; aucun traceur publicitaire ni outil de mesure d'un tiers ; **aucun cookie autre que celui qui vous garde connecté**. Nos statistiques d'usage sont calculées, de façon agrégée, à partir des données ci-dessus.

### 4. Pourquoi nous les utilisons

| Finalité | Données utilisées | Base légale |
|---|---|---|
| Créer votre compte et vous connecter | identité, contact, PIN, connexions | ‹ à compléter par les juristes › |
| Protéger votre compte : verrouillage après plusieurs PIN faux, récupération du PIN, journal | tentatives, codes, journal, adresse IP | ‹ à compléter par les juristes › |
| Faire fonctionner la classe : l'élève voit ses exercices, l'enseignant suit ses élèves | rattachement, travail scolaire, exercices donnés | ‹ à compléter par les juristes › |
| Permettre à l'établissement de suivre le travail de ses élèves | noms des élèves de ses classes et chiffres de leur travail | ‹ à compléter par les juristes › |
| Mesurer l'usage du service, de façon agrégée | comptes, exercices faits, exercices donnés | ‹ à compléter par les juristes › |
| Faire connaître Lnclass entre collègues | parrainage | ‹ à compléter par les juristes › |

### 5. Qui voit vos données

- **Vous** voyez votre profil, votre numéro et votre travail.
- **Vos camarades de classe** voient le nombre d'élèves de la classe, **jamais** la liste des élèves ni leurs résultats.
- **Une personne qui a le code de votre classe** voit le nom de la classe, de l'établissement et le niveau, pour reconnaître la bonne classe avant de la rejoindre ; **jamais** un élève, un enseignant ni l'effectif.
- **L'enseignant de votre classe** voit votre nom, votre photo et vos résultats, et qui a rendu un exercice en retard ; **pas votre numéro**. Il peut vous donner un code pour retrouver l'accès à votre compte.
- **La direction de votre établissement** voit ses enseignants, les élèves de ses classes et les chiffres de leur travail.
- **L'équipe Lnclass** voit tous les comptes, pour les débloquer et vous aider ; dans ses tableaux de suivi, le numéro est masqué.

Nous ne vendons ni ne cédons vos données.

### 6. Où sont vos données

L'application, sa base de données et les photos sont hébergées chez **Railway**, prestataire d'hébergement ; les photos sont dans un espace de stockage du même prestataire. ‹ Région d'hébergement et transferts hors de Côte d'Ivoire, avec leurs garanties : à compléter par les juristes ›

Les photos ne sont montrées que par l'application, à une personne connectée et autorisée ; elles n'ont pas d'adresse publique.

Si vous écrivez au support par **WhatsApp** ou si vous l'appelez, l'échange passe par WhatsApp ou par votre opérateur téléphonique, hors de Lnclass.

### 7. Comment nous les protégeons

- Les échanges avec l'application sont chiffrés (HTTPS).
- Votre connexion se ferme après **30 jours** sans activité ; pour l'équipe et la direction, après **12 heures** au plus.
- Votre PIN et vos codes ne sont jamais enregistrés en clair. Après plusieurs PIN faux, le compte se verrouille.
- Les comptes de l'équipe exigent un second facteur.
- Aucun script d'un tiers n'est chargé dans les pages.
- Les informations cachées des photos (position GPS comprise) sont retirées avant l'enregistrement.

### 8. Combien de temps nous les gardons

- **Vos données sont conservées comme archive**, sans limite de durée, tant que vous ne demandez pas leur suppression. Après votre départ d'une classe ou d'un établissement, l'archive reste consultable par vous, depuis votre compte, et par l'établissement que vous avez quitté, pour les résultats obtenus chez lui.
- **Vous pouvez demander la suppression de votre compte** au support : elle est faite dans les 30 jours qui suivent votre demande. ‹ Ce que deviennent les résultats déjà consultés par l'établissement après une suppression : à valider par les juristes ›
- **Les informations d'usage de l'application sont conservées**, sans votre nom : exercices faits, réponses, notes, badges et fiches à revoir. Elles servent à la progression et au suivi par les enseignants et l'établissement ; les statistiques d'une classe restent justes après le départ d'un élève.
- Les classes sont archivées en fin d'année scolaire, pas supprimées.
- Les fichiers envoyés mais jamais utilisés sont effacés après 48 heures.

### 9. Vos droits

Vous pouvez demander l'accès à vos données, leur rectification, vous opposer à leur traitement ou demander leur suppression, dans les conditions de la loi n° 2013-450. ‹ Formulation exacte des droits et recours auprès de l'ARTCI : à compléter par les juristes ›

Pour exercer vos droits : **+225 05 44 32 00 20** ou **+225 05 84 25 80 85**.

Sans attendre, vous pouvez vous-même modifier votre nom, votre numéro, votre PIN et votre photo depuis votre profil. La suppression d'un compte se demande au support : elle est faite dans les 30 jours.

### 10. Les élèves mineurs

La plupart des élèves qui utilisent Lnclass ont moins de 18 ans. Un élève s'inscrit avec le code que lui donne son enseignant, dans le cadre de sa classe. ‹ Âge minimum pour s'inscrire seul et accord des parents : à compléter par les juristes ›

### 11. Modification de cette politique

Nous mettons cette page à jour quand l'application change ce qu'elle enregistre. La date de mise à jour est en tête de page.

---

## 3. Conditions générales d'utilisation — `/conditions-utilisation`

**`h1` — Conditions générales d'utilisation**
« Mis à jour le ‹ date de validation : à compléter par les juristes › »

### 1. Objet et éditeur

Les présentes conditions encadrent l'usage de **Lnclass** (lnclass.com), édité par **Lnclass Côte d'Ivoire SARL**, Tiassalé, au feu du marché, vers la Pharmacie Saint-Joseph, Côte d'Ivoire — RCCM ‹ numéro : à compléter par les juristes › — contact : **+225 05 44 32 00 20** et **+225 05 84 25 80 85**.

En utilisant Lnclass, vous acceptez ces conditions. ‹ Mode d'acceptation (aujourd'hui, aucune case à cocher à l'inscription) : à valider par les juristes ›

### 2. Les comptes

- **Élève** : il rejoint sa classe avec le code donné par son enseignant, puis indique son nom, son genre, son numéro et choisit un PIN. Un élève a une seule classe active à la fois.
- **Enseignant** : il s'inscrit avec le code de son établissement ; sans ce code, son compte attend d'être validé par l'équipe Lnclass ou par un collègue.
- **Direction** : un membre de la direction est invité par l'équipe Lnclass, pour un seul établissement.
- **Équipe Lnclass** : ses membres sont invités et protègent leur compte par un second facteur.

Une classe appartient à une année scolaire et est archivée à la fin de celle-ci. Son code peut être remplacé à tout moment.

### 3. Votre PIN

- Votre compte est protégé par un **PIN de 4 chiffres**, personnel et secret. Ne le communiquez à personne.
- Après plusieurs PIN faux, le compte se verrouille : 15 minutes après 5 échecs, 1 heure après 10 ; après 20, il faut une récupération assistée.
- **PIN oublié** : l'enseignant de votre classe, ou l'équipe Lnclass, vous donne de vive voix un code de récupération de 8 chiffres, valable 15 minutes et utilisable une seule fois. Vous choisissez alors un nouveau PIN, et toutes vos connexions ouvertes sont fermées.

### 4. Le contenu

Les cours, fiches essentielles et exercices sont publiés par Lnclass et lui appartiennent. Lnclass peut les modifier ou les retirer à tout moment ; vos résultats sont conservés.

Vous pouvez utiliser ce contenu pour votre usage personnel et scolaire. Vous ne pouvez pas le copier, le revendre ni le diffuser en dehors de ce cadre. ‹ Étendue exacte de la licence d'usage : à valider par les juristes ›

### 5. Ce que vous vous engagez à faire

- utiliser votre propre compte, et ne pas vous connecter avec celui d'un autre ;
- garder secrets votre PIN et tout code de récupération ;
- ne partager le code d'une classe qu'avec les élèves de cette classe ;
- ne pas chercher à accéder aux données d'un autre compte, ni à contourner les protections du service ;
- respecter les autres utilisateurs.

### 6. Les exercices et leurs dates limites

Un enseignant donne à sa classe des exercices pour la séance suivante. Un exercice reste faisable après sa date limite : il est alors signalé « en retard », et l'enseignant voit qu'il a été rendu après la date.

### 7. Suspension et fin d'un compte

- Un compte se verrouille après plusieurs PIN faux (article 3).
- La direction d'un établissement peut retirer un enseignant de son établissement ; il perd alors ses classes, et les exercices qu'il avait donnés sont retirés.
- Lnclass peut suspendre un compte qui ne respecte pas l'article 5. ‹ Motifs, préavis et recours : à compléter par les juristes ›
- Vous pouvez demander la fermeture de votre compte au support. Il est anonymisé selon la [politique de protection des données](#2-politique-de-protection-des-données--confidentialite) (article 8).

### 8. Vos données

La [politique de protection des données](#2-politique-de-protection-des-données--confidentialite) dit quelles données nous enregistrons et comment exercer vos droits.

### 9. Responsabilité

‹ Disponibilité du service, limites de responsabilité, force majeure : à compléter par les juristes ›

### 10. Élèves mineurs

‹ Âge minimum et accord des parents : à compléter par les juristes ›

### 11. Droit applicable et litiges

Les présentes conditions sont soumises au **droit ivoirien**. En cas de litige, les parties recherchent d'abord une solution amiable. ‹ Tribunaux compétents et confirmation du droit applicable : à compléter par les juristes ›

### 12. Modification des conditions

Lnclass peut modifier ces conditions. La date de mise à jour figure en tête de page. ‹ Façon de prévenir les utilisateurs d'un changement : à compléter par les juristes ›

---

## 4. Conditions générales de vente — `/conditions-vente`

> **Offre fixée le 2026-10-02** par le grill du chantier [`abonnement-mobile-money`](../abonnement-mobile-money/memo.md) (Q1 à Q8, porteur). Le texte ci-dessous est complet ; il reste à faire valider par les juristes, qui complètent les marques ‹ › (lot P4 ; mise en ligne au lot Z).
>
> **Vocabulaire** (porteur, 2026-10-02) : la locale n'admet pas le mot « essai » (UDR-0007, test `test/i18n/locale_files_test.rb`) ; l'essai gratuit du grill (Q4, Q7) s'écrit **« période gratuite »**, partout (CGV, bandeaux de rappel, écrans). Le blocage commence **après le 30e jour**.

**`h1` — Conditions générales de vente**
« Mis à jour le ‹ date de validation : à compléter par les juristes › »

### 1. Vendeur

L'abonnement à Lnclass est vendu par **Lnclass Côte d'Ivoire SARL**, Tiassalé, au feu du marché, vers la Pharmacie Saint-Joseph, Côte d'Ivoire — RCCM ‹ numéro : à compléter par les juristes › — contact : **+225 05 44 32 00 20** et **+225 05 84 25 80 85**.

### 2. L'offre et le prix

L'abonnement est attaché à un compte élève. Il est payé **par l'élève ou par son parent**.

Il coûte **16 000 F CFA pour l'année scolaire**. ‹ Prix toutes taxes comprises ou hors TVA : à compléter par les juristes ›

Le prix est le même à tout moment de l'année : un abonnement pris en cours d'année est payé **au plein tarif, sans prorata**, et vaut jusqu'à la fin de l'année scolaire en cours.

### 3. La période gratuite

La **période gratuite dure 30 jours**, sans abonnement. Elle compte à partir de la création de votre compte élève, et n'est accordée qu'une fois par compte :

- pendant **14 jours**, vous avez accès à tout Lnclass ;
- du **15e au 30e jour**, vous gardez l'accès à tout Lnclass, et des messages vous invitent à prendre un abonnement ;
- **après le 30e jour**, il vous faut un abonnement pour commencer un exercice (article 6).

### 4. Le paiement

Le paiement se fait avec **Wave**, depuis l'application Wave de l'élève ou de son parent.

L'abonnement est activé quand Wave confirme le paiement à Lnclass, pas au retour sur l'application. **Le numéro de transaction Wave sert de reçu** : gardez-le.

### 5. Durée et renouvellement

L'abonnement vaut pour **une année scolaire, de septembre à juillet**. Il prend fin avec l'année scolaire en cours, quelle que soit la date du paiement.

**Il n'y a aucun prélèvement automatique** : Wave ne le permet pas. L'abonnement n'est donc pas renouvelé tout seul ; pour l'année suivante, vous le renouvelez vous-même par un nouveau paiement.

### 6. Sans abonnement

Après le 30e jour sans abonnement, ou quand votre abonnement prend fin avec l'année scolaire, vous **gardez votre compte et l'historique de votre travail** : vous pouvez toujours vous connecter et le consulter.

Vous **voyez tous les exercices**, y compris ceux que votre enseignant vous donne, mais vous **ne pouvez pas en commencer** : Lnclass vous invite alors à prendre un abonnement.

### 7. Rétractation et remboursement

Vous pouvez demander le remboursement de votre abonnement **dans les 7 jours qui suivent le paiement**, au **+225 05 44 32 00 20** ou au **+225 05 84 25 80 85**, en donnant le numéro de transaction Wave. Le remboursement est fait par Wave.

Après ces 7 jours, l'abonnement n'est pas remboursé.

‹ Droit de rétractation prévu par la loi ivoirienne, son délai et son articulation avec ce remboursement : à compléter par les juristes ›

### 8. Réclamation

Pour toute réclamation : **+225 05 44 32 00 20** ou **+225 05 84 25 80 85**. Pour un paiement, donnez le numéro de transaction Wave. ‹ Délai de réponse, procédure de réclamation et médiation : à compléter par les juristes ›

### 9. Responsabilité

‹ Responsabilité de Lnclass envers l'acheteur, indisponibilité du service, force majeure : à compléter par les juristes ›

### 10. Droit applicable et litiges

Les présentes conditions sont soumises au **droit ivoirien**. En cas de litige, les parties recherchent d'abord une solution amiable. ‹ Tribunaux compétents et confirmation du droit applicable : à compléter par les juristes ›

---

## 5. Informations légales, récapitulatif

| Information | Valeur | Source |
|---|---|---|
| Entité, responsable du traitement | **Lnclass Côte d'Ivoire SARL** | porteur, 2026-10-02 |
| Adresse | Tiassalé, au feu du marché, vers la Pharmacie Saint-Joseph | porteur, 2026-10-02 |
| Contact | +225 05 44 32 00 20 · +225 05 84 25 80 85 | porteur, 2026-10-02 |
| Conservation | Pas d'anonymisation ; archive consultable par l'élève et l'établissement quitté ; suppression sur demande sous 30 jours | porteur, 2026-10-02 (révisé le même jour) ; construite par le lot R |
| RCCM | à compléter | juristes |
| Déclaration ou autorisation ARTCI | à compléter | juristes |
| Droit applicable, tribunaux, responsabilité, âge minimum et accord des parents, bases légales, transferts | à compléter | juristes |
| Définition du « départ », données « sensibles » | à arrêter | porteur, avant le lot R |
| Offre | Abonnement par compte élève, payé par l'élève ou son parent, par Wave ; **16 000 F CFA** l'année scolaire (septembre à juillet), plein tarif sans prorata ; sans renouvellement automatique ; 30 premiers jours gratuits, comptés depuis la création du compte (14 jours d'accès complet, puis du 15e au 30e jour accès complet avec des rappels) ; sans abonnement, compte, historique et exercices visibles, aucun exercice à commencer, invitation à s'abonner ; remboursement par Wave sur demande sous 7 jours ; numéro de transaction Wave comme reçu | porteur, 2026-10-02 (grill `abonnement-mobile-money`, Q1 à Q8) |
| TVA, droit de rétractation légal, réclamation et médiation | à compléter | juristes |
| Numéros et horaires du **support** (carte d'aide) | à fournir | porteur |

## 6. Sources des faits

| Affirmation | Source |
|---|---|
| Programme de la 6e à la Terminale, BEPC et BAC ; exercices quotidiens corrigés ; badges ; application légère | `config/locales/homepage/index.fr.yml` ; `docs/contenus/` ; ADR-0033 ; ADR-0051 |
| Aucun traceur, aucun script tiers, un seul cookie | ADR-0049 |
| Données enregistrées | `db/schema.rb` : `users`, `classroom_students`, `teacher_classrooms`, `teacher_profiles`, `school_staffs`, `exercise_sessions`, `question_attempts`, `exercise_badges`, `knowledge_gaps`, `classroom_assignments`, `classroom_session_days` (ADR-0072), `sessions`, `login_attempts`, `pin_recovery_codes`, `totp_credentials`, `backup_codes`, `audit_events`, `invitations`, `referrals`, `referral_shares`, `school_join_requests` |
| PIN en empreinte bcrypt, verrouillage 5 / 10 / 20, sessions de 30 jours et 12 heures | ADR-0050 ; `Entities::Identity::SessionLifetime` |
| Code de récupération de 8 chiffres, 15 minutes, usage unique | ADR-0032 |
| Second facteur de l'équipe ; secret chiffré | ADR-0031 ; `Orm::TotpCredential` |
| Photo recadrée, métadonnées retirées, servie sous session | ADR-0060 |
| Hébergement Railway, stockage objet ; aucune région attestée | ADR-0010, ADR-0047 (`BUCKET_REGION` vaut `auto`) |
| Ce que voient l'enseignant (sans numéro), la direction, l'équipe (numéro masqué) | `ReadUserPolicy` ; ADR-0062, ADR-0065, ADR-0071 ; UDR-0009, UDR-0011 |
| Inscription élève par code, enseignant par code d'établissement, direction et équipe sur invitation | UDR-0009 ; ADR-0040, 0041, 0057, 0063, 0065, 0038 |
| Contenu propriété de la plateforme, archivé, résultats conservés | ADR-0035, ADR-0036 |
| Retrait d'un enseignant, exercices archivés | ADR-0071 |
| Exercice faisable après l'échéance, « en retard » | ADR-0072 ; UDR-0062 |
| Fichiers non rattachés effacés après 48 h | `config/recurring.yml` ; ADR-0047 |
| Anonymisation : nom remplacé, numéro effacé, connexions fermées, résultats gardés | ADR-0036 §4 et son amendement proposé (lot R) — **non construite au 2026-10-02** |
| Paiement Wave, sans prélèvement automatique ; abonnement activé par la confirmation de Wave ; numéro de transaction comme reçu ; remboursement par Wave | memo `abonnement-mobile-money`, « Ce que l'API Wave permet » |
| Payeur, durée, prix, plein tarif sans prorata, 30 premiers jours gratuits (14 jours d'accès complet, rappels du 15e au 30e jour) une fois par compte, exercices visibles mais aucun à commencer sans abonnement, remboursement sous 7 jours | porteur, 2026-10-02 ; memo `abonnement-mobile-money`, « Ce que le grill a révélé », Q1 à Q8 (Q7 et Q8 révisés le même jour) ; année scolaire de septembre à juillet : ADR-0041 |
