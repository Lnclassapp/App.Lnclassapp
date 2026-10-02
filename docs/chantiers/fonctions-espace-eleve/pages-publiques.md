# Brouillons des pages publiques — à relire par le porteur

> **Statut : brouillon, 2026-10-02.** Contrat d'interface : [UDR-0063](../../decisions/udr/0063-pages-publiques-mission-confidentialite-cgu-cgv.md). Aucun de ces textes n'est en ligne.
>
> **Règle de rédaction** : chaque fait vient du code, du schéma (`db/schema.rb`) ou d'un ADR, cité en note `[source]`. Les notes disparaissent du texte publié. Ce qui n'est pas établi est marqué **« À FOURNIR »** (le porteur) ou **« À VALIDER PAR UN JURISTE »**. Aucune page n'est mise en ligne tant qu'il reste un de ces marqueurs (UDR-0063 §2.4).
>
> Ton : vouvoiement (UDR-0063 §3.3).

## Sommaire

1. [Notre mission](#1-notre-mission--mission)
2. [Politique de protection des données](#2-politique-de-protection-des-données--confidentialite)
3. [Conditions générales d'utilisation (CGU)](#3-conditions-générales-dutilisation--conditions-utilisation)
4. [Conditions générales de vente (CGV) — squelette](#4-conditions-générales-de-vente--conditions-vente--squelette)
5. [Données à fournir, récapitulatif](#5-données-à-fournir-récapitulatif)

---

## 1. Notre mission — `/mission`

> **À VALIDER PAR LE PORTEUR** : la page reprend ce que la landing et la doc disent déjà. Aucune phrase n'ajoute un chiffre, un partenaire ou une promesse.

**`h1` — Notre mission**

**Faire comprendre, chap chap.**
Lnclass aide les élèves de Côte d'Ivoire, de la 6e à la Terminale, à comprendre leurs cours et à s'entraîner, avec leurs enseignants. `[source : config/locales/homepage/index.fr.yml, hero ; UDR-0059, slogan « Forcément, tu comprends chap chap »]`

**Pour qui**
- **Les élèves** apprennent à leur rythme : ils rejoignent leur classe avec son code, révisent les fiches essentielles et s'entraînent avec des exercices corrigés. `[source : homepage, audience.roles.students]`
- **Les enseignants** guident leur classe : ils déclarent leurs classes, leur assignent des exercices et suivent les résultats de leurs élèves. `[source : homepage, audience.roles.teachers — « cours et exercices » devient « exercices », ADR-0072]`
- **Les établissements** suivent le travail de leurs élèves et gèrent leurs enseignants. `[source : ADR-0065, ADR-0071]`

**Ce que nous faisons**
- **Le programme officiel**, de la 6e à la Terminale : des cours, des fiches essentielles et des exercices, pour préparer le BEPC et le BAC. `[source : homepage, features.items.curriculum ; docs/contenus/ (progressions DPFC 2026-2027)]`
- **Un peu chaque jour** : des exercices courts, avec la correction détaillée de chaque question. `[source : homepage, features.items.exercises]`
- **La progression rendue visible** : des badges (Bronze, Argent, Or, Diamant) et la maîtrise de chaque exercice. `[source : homepage ; ADR-0033]`

**Comment nous le faisons**
- **Une application légère**, conçue pour les téléphones d'entrée de gamme et les connexions modestes. `[source : homepage, features.lead ; ADR-0051 (budget de poids)]`
- **Sans publicité ni traceur** : aucun script, aucune police, aucun outil de mesure venant d'un tiers. `[source : ADR-0049]` — *« sans publicité » : À VALIDER PAR LE PORTEUR (aucune publicité dans le code au 2026-10-02, mais c'est un engagement pour l'avenir).*

**À FOURNIR** (facultatif) : l'histoire de Lnclass, l'équipe, une phrase du fondateur.

---

## 2. Politique de protection des données — `/confidentialite`

> **Inventaire factuel au 2026-10-02.** Il décrit ce que l'application enregistre réellement. Il ne dit pas ce qui est conforme : seul un juriste, avec les données à fournir, peut l'écrire.

**`h1` — Protection de vos données personnelles** · « Mis à jour le **À FOURNIR** »

### 2.1 Qui est responsable

Le responsable du traitement est **Lnclass Côte d'Ivoire** (décision du porteur, 2026-10-02).
- Forme juridique, adresse du siège, numéro RCCM : **À FOURNIR**.
- Contact pour toute question sur vos données (adresse électronique ou postale, téléphone) : **À FOURNIR**.

### 2.2 Cadre applicable

Ce traitement relève de la **loi n° 2013-450 du 19 juin 2013 relative à la protection des données à caractère personnel** de Côte d'Ivoire, dont l'autorité de contrôle est l'**ARTCI** (Autorité de Régulation des Télécommunications/TIC de Côte d'Ivoire).
- Déclaration ou autorisation du traitement auprès de l'ARTCI, et sa référence : **À FOURNIR** (aucune démarche n'est documentée dans le dépôt).
- Formulation exacte du cadre et des droits : **À VALIDER PAR UN JURISTE**.

### 2.3 Les données que nous enregistrons

| Catégorie | Données | Qui est concerné | Source |
|---|---|---|---|
| Identité | Nom, prénom(s), genre (masculin, féminin) | Tous les comptes | `users` ; ADR-0037 |
| Contact | Numéro de téléphone ivoirien à 10 chiffres, qui sert d'identifiant de connexion | Tous les comptes | `users.contact` ; ADR-0050 |
| Secret de connexion | PIN à 4 chiffres, **jamais stocké en clair** (empreinte bcrypt) | Tous les comptes | `users.pin_digest` ; ADR-0050 |
| Rôle et rattachement | Rôle (élève, enseignant, direction, équipe) ; classe et date d'arrivée ou de départ ; établissement ; matière enseignée ; classes déclarées | Selon le rôle | `classroom_students`, `teacher_schools`, `teacher_classrooms`, `teacher_profiles`, `school_staffs` |
| Photo de profil (facultative) | Image carrée, recadrée par le téléphone, **dont les métadonnées (lieu, appareil…) sont retirées** avant d'être gardée | Comptes qui en ajoutent une | ADR-0060 |
| Travail scolaire | Sessions d'exercice (début, fin, avancement, score), réponses données, badges obtenus, fiches à revoir | Élèves | `exercise_sessions`, `question_attempts`, `exercise_badges`, `knowledge_gaps` ; ADR-0033, 0043, 0054 |
| Travail de l'enseignant | Exercices assignés et leurs dates ; jours de séance (après ce chantier) | Enseignants | `classroom_assignments` ; ADR-0048, ADR-0072 |
| Connexion et sécurité | Sessions de connexion (adresse IP, navigateur, dates) ; tentatives de connexion (numéro saisi, adresse IP, réussite) ; codes de récupération du PIN (empreinte seulement) ; second facteur de l'équipe (secret chiffré, codes de secours en empreinte) | Tous les comptes ; second facteur : équipe | `sessions`, `login_attempts`, `pin_recovery_codes`, `totp_credentials`, `backup_codes` ; ADR-0050, 0032, 0031 |
| Journal des actions sensibles | Qui a fait quoi et quand (verrouillage, PIN réinitialisé, changement de nom, de numéro ou de photo, publication de contenu, retrait d'un enseignant…), avec l'adresse IP ; jamais un secret | Comptes qui font ces actions, et comptes concernés | `audit_events` ; `Entities::Identity::AuditAction` ; ADR-0050 |
| Invitations et parrainage | Numéro de téléphone d'une personne invitée (direction, équipe) ; qui a invité qui ; canal de partage d'un lien (WhatsApp, SMS, copie) | Enseignants, direction, équipe | `invitations`, `referrals`, `referral_shares`, `school_join_requests` ; ADR-0063, 0065 |

**Ce que nous n'enregistrons pas** :
- aucun traceur publicitaire ni outil de mesure d'audience d'un tiers ; **aucun cookie autre que celui de la connexion** ; les statistiques d'usage sont calculées à partir des données ci-dessus, de façon agrégée `[ADR-0049]` ;
- aucune adresse électronique, aucune date de naissance, aucune adresse postale (absentes du schéma) ;
- aucune donnée de paiement à ce jour (le paiement n'existe pas encore ; la page sera mise à jour avec lui).

### 2.4 Pourquoi nous les utilisons

| Finalité | Données |
|---|---|
| Créer votre compte et vous connecter | identité, contact, PIN, sessions |
| Protéger votre compte (verrouillage après des échecs, récupération du PIN, journal) | tentatives, codes, journal, adresse IP `[ADR-0050 : 5 échecs → 15 min ; 10 → 1 h ; 20 → récupération assistée]` |
| Faire fonctionner la classe : l'élève voit ses exercices, l'enseignant suit ses élèves | rattachements, travail scolaire, assignations |
| Permettre à l'établissement de suivre le travail de ses élèves | noms des élèves de ses classes et chiffres de leur travail `[ADR-0065]` |
| Mesurer l'usage du service, de façon agrégée | comptes, sessions d'exercice, assignations `[ADR-0049, ADR-0062]` |
| Faire connaître Lnclass entre collègues | parrainage `[ADR-0063]` |

Base légale de chaque finalité (consentement, contrat, intérêt légitime…) : **À VALIDER PAR UN JURISTE**.

### 2.5 Qui voit vos données

| Qui | Ce qu'il voit | Source |
|---|---|---|
| **Vous** | Votre profil, votre numéro, votre travail | `ReadUserPolicy` |
| **Un camarade de classe** | Le nombre d'élèves de la classe ; **jamais** la liste des élèves ni leurs résultats | UDR-0011 |
| **Une personne qui a le code de la classe** | Le nom de la classe, de l'établissement et le niveau, pour reconnaître la bonne classe avant de la rejoindre ; **jamais** un élève, un enseignant ni l'effectif | UDR-0009 |
| **L'enseignant de la classe** | Nom, prénom, photo et résultats de ses élèves ; **pas leur numéro** ; il peut leur donner un code de récupération du PIN | `ReadUserPolicy` (`show_contact: false`) ; ADR-0032 |
| **La direction de l'établissement** | Ses enseignants ; les élèves de ses classes et les chiffres de leur travail | ADR-0065, ADR-0071 |
| **L'équipe Lnclass** | Tous les comptes, pour les débloquer et assurer le support ; le numéro est masqué dans les tableaux de suivi (deux premiers et deux derniers chiffres) | ADR-0038, ADR-0062 |

Aucune donnée n'est vendue ni cédée. `[aucun export ni API tierce dans le code au 2026-10-02]` — *engagement : À VALIDER PAR LE PORTEUR.*

### 2.6 Où sont vos données

- L'application, sa base de données (PostgreSQL) et les fichiers (photos de profil) sont hébergés chez **Railway**, prestataire d'hébergement ; les fichiers sont dans un stockage objet compatible S3 chez le même prestataire. `[ADR-0010, ADR-0047]`
- Région et pays d'hébergement : **À FOURNIR** (la doc n'en atteste aucun ; la configuration du stockage vaut `auto`). Transfert hors de Côte d'Ivoire et ses garanties : **À VALIDER PAR UN JURISTE**.
- Les photos ne sont servies que par l'application, à une personne connectée et autorisée ; aucune adresse publique de fichier. `[ADR-0060]`
- Si vous écrivez au support par **WhatsApp** ou l'appelez (carte d'aide, UDR-0061), l'échange passe par ce service ou par votre opérateur, hors de Lnclass.

### 2.7 Comment nous les protégeons

- Connexion chiffrée (HTTPS) ; cookie de connexion protégé (`httponly`, `secure`) ; session fermée après **30 jours** sans activité, **12 heures** au plus pour l'équipe et la direction. `[ADR-0050 ; Entities::Identity::SessionLifetime]`
- PIN et codes jamais stockés en clair ; verrouillage progressif après des échecs. `[ADR-0050, ADR-0032]`
- Second facteur obligatoire pour l'équipe. `[ADR-0031]`
- Aucun script d'un tiers dans les pages (politique de sécurité du contenu stricte). `[ADR-0049]`
- Les métadonnées des photos (position GPS comprise) sont retirées avant stockage. `[ADR-0060]`

### 2.8 Combien de temps nous les gardons

**À FOURNIR**, catégorie par catégorie. Faits établis au 2026-10-02 :
- les fichiers envoyés mais jamais rattachés sont effacés après 48 heures `[config/recurring.yml, ADR-0047]` ;
- l'ADR-0036 prévoit d'effacer les tentatives de connexion après 90 jours et les codes et invitations périmés après 30 jours, **mais ces purges ne sont pas programmées dans l'application** (`config/recurring.yml`) : à faire avant de les écrire dans la page ;
- une classe est archivée en fin d'année scolaire, pas supprimée `[ADR-0041, ADR-0036]` ;
- un compte n'est jamais supprimé mais **anonymisé** (nom remplacé, numéro effacé, sessions fermées), ses résultats restant sous forme anonyme `[ADR-0036]` — **cette anonymisation n'est pas encore construite** (aucun use case `AnonymizeUser` au 2026-10-02).

### 2.9 Vos droits

Droits d'accès, de rectification, d'opposition et de suppression prévus par la loi n° 2013-450 : formulation **À VALIDER PAR UN JURISTE** ; contact pour les exercer : **À FOURNIR**.
Ce que l'application permet déjà, seul : modifier son nom, son numéro, son PIN et sa photo `[ADR-0055, ADR-0060]`. La suppression d'un compte se demande au support (aucune fonction dans l'application).

### 2.10 Les élèves mineurs

La plupart des élèves ont **moins de 18 ans** (6e à Terminale). Âge à partir duquel un élève peut s'inscrire seul, et place de l'accord des parents : **À FOURNIR / À VALIDER PAR UN JURISTE**. Au 2026-10-02, l'inscription d'un élève ne demande ni âge ni accord parental (`Classroom::JoinAsStudent`).

---

## 3. Conditions générales d'utilisation — `/conditions-utilisation`

> **Brouillon factuel.** Les articles 3.1 à 3.6 décrivent le fonctionnement réel ; les engagements et les sanctions sont des propositions **À VALIDER PAR UN JURISTE**.

**`h1` — Conditions générales d'utilisation** · « Mis à jour le **À FOURNIR** »

### 3.0 Objet et éditeur

Les présentes conditions régissent l'usage de Lnclass (lnclass.com), édité par **Lnclass Côte d'Ivoire** — adresse, RCCM, contact : **À FOURNIR**. Utiliser le service vaut acceptation des conditions : **À VALIDER PAR UN JURISTE** (au 2026-10-02, aucune case d'acceptation n'existe à l'inscription ; question ouverte).

### 3.1 Les comptes et les rôles

| Rôle | Comment on obtient un compte | Source |
|---|---|---|
| **Élève** | En rejoignant sa classe avec le code donné par son enseignant (lien `/c/<code>` ou saisie du code), puis en indiquant son nom, son genre, son numéro et un PIN | UDR-0009, ADR-0040, 0041 |
| **Enseignant** | En s'inscrivant avec le code de son établissement ; sans code, son compte attend la validation de l'équipe ou d'un collègue | ADR-0057, ADR-0063 |
| **Direction** | Sur invitation de l'équipe Lnclass, pour un seul établissement | ADR-0065 |
| **Équipe Lnclass** | Sur invitation seulement, avec un second facteur obligatoire | ADR-0038, ADR-0031 |

- Un élève n'a qu'**une classe active** à la fois. `[ADR-0040]`
- Une classe appartient à une année scolaire ; elle est archivée en fin d'année et a un effectif maximal. Son code peut être révoqué et remplacé. `[ADR-0041]`

### 3.2 Le PIN et sa récupération

- Le compte se protège par un **PIN de 4 chiffres**, choisi à l'inscription, personnel et secret. Ne le communiquez à personne. `[ADR-0025, ADR-0050]`
- Après plusieurs PIN faux, le compte se verrouille : 15 minutes après 5 échecs, 1 heure après 10, jusqu'à une récupération assistée après 20. `[ADR-0050]`
- PIN oublié : l'enseignant de votre classe, ou l'équipe, vous donne de vive voix un **code de récupération de 8 chiffres, valable 15 minutes et utilisable une fois** ; vous choisissez alors un nouveau PIN, et toutes vos connexions ouvertes sont fermées. `[ADR-0032]`

### 3.3 Le contenu fourni par Lnclass

- Les cours, fiches essentielles et exercices sont **publiés par Lnclass** et restent sa propriété ; leur auteur n'en est qu'une trace. `[ADR-0035]`
- Un contenu peut être retiré (archivé) à tout moment ; vos résultats sont conservés. `[ADR-0035, ADR-0036]`
- Licence d'usage accordée à l'utilisateur (usage personnel et scolaire, interdiction de reproduction…) : **À VALIDER PAR UN JURISTE**.
- Exactitude du contenu et signalement d'une erreur : **À FOURNIR** (aucun parcours de signalement n'existe ; ADR-0053).

### 3.4 Usage acceptable — *proposition, À VALIDER PAR UN JURISTE*

Vous vous engagez à :
- utiliser votre propre compte, et ne pas vous connecter avec celui d'un autre ;
- ne pas partager votre PIN ni un code de récupération ;
- ne pas partager le code d'une classe hors de cette classe ;
- ne pas tenter de contourner les protections du service (accès aux données d'autres comptes, essais répétés de PIN) ;
- ne pas copier ni diffuser le contenu hors du cadre scolaire.

### 3.5 Suspension et fin d'un compte

Ce que l'application fait aujourd'hui :
- elle **verrouille** un compte après des échecs de connexion (§3.2) ;
- la direction peut **retirer un enseignant** de son établissement ; il perd ses classes, et ses exercices assignés sont archivés `[ADR-0071]` ;

Ce qui n'existe pas encore et doit être décidé : la **suspension** d'un compte par Lnclass pour usage abusif (motifs, préavis, recours) et la **suppression** à la demande (anonymisation, ADR-0036, non construite) : **À FOURNIR / À VALIDER PAR UN JURISTE**.

### 3.6 Données personnelles

Renvoi à la [politique de protection des données](#2-politique-de-protection-des-données--confidentialite).

### 3.7 Responsabilité — **À VALIDER PAR UN JURISTE**

Disponibilité du service, limites de responsabilité, force majeure : aucun engagement n'est établi.

### 3.8 Âge minimum et accord des parents — **À FOURNIR / À VALIDER PAR UN JURISTE**

### 3.9 Droit applicable et litiges — **À VALIDER PAR UN JURISTE**

Droit ivoirien et tribunaux de Côte d'Ivoire (à confirmer), tentative de règlement amiable préalable.

### 3.10 Modification des conditions — **À VALIDER PAR UN JURISTE**

Comment les utilisateurs sont prévenus d'un changement.

---

## 4. Conditions générales de vente — `/conditions-vente` — squelette

> **Squelette seulement : aucun chiffre, aucun engagement.** L'abonnement n'est pas décidé (chantier [`abonnement-mobile-money`](../abonnement-mobile-money/memo.md), grill non fait). **Le lot CGV dépend de ce chantier** ; ces rubriques se remplissent avec son grill et son ADR.

**`h1` — Conditions générales de vente** · « Mis à jour le **À FOURNIR** »

1. **Vendeur** — Lnclass Côte d'Ivoire ; adresse, RCCM, contact : **À FOURNIR**.
2. **L'offre et le prix** — ce que l'abonnement donne, ce qui reste gratuit, qui paie (élève, parent, établissement), prix en francs CFA (XOF), taxes : **À FOURNIR** (questions ouvertes d'`abonnement-mobile-money`).
3. **Le paiement par Wave** — paiement depuis l'application Wave ; l'abonnement n'est activé qu'à la confirmation du paiement par Wave, pas au retour sur Lnclass ; le numéro de transaction Wave sert de preuve. `[memo abonnement-mobile-money, « Ce que l'API Wave permet »]` — formulation finale : **À FOURNIR**.
4. **Durée et renouvellement** — durée : **À FOURNIR**. **Aucun prélèvement automatique** : Wave n'en propose pas, chaque renouvellement est un nouveau paiement fait par l'utilisateur. `[même source]`
5. **Fin de l'abonnement** — ce que perd l'utilisateur à l'échéance, délai de grâce : **À FOURNIR**.
6. **Rétractation et remboursement** — délai, conditions, mode (remboursement Wave possible techniquement) : **À FOURNIR / À VALIDER PAR UN JURISTE**.
7. **Réclamation** — contact, délai de réponse, médiation : **À FOURNIR**.
8. **Droit applicable** — renvoi aux CGU, §3.9.

---

## 5. Données à fournir, récapitulatif

| Donnée | Pages | Par |
|---|---|---|
| Adresse du siège, RCCM, forme juridique de Lnclass Côte d'Ivoire | Confidentialité, CGU, CGV | porteur |
| Contact « données personnelles » et contact général | Confidentialité, CGU, CGV | porteur |
| Déclaration ou autorisation ARTCI et sa référence | Confidentialité | porteur |
| Durées de conservation, par catégorie | Confidentialité | porteur, avec un juriste |
| Région d'hébergement (Railway, stockage objet) | Confidentialité | porteur (console Railway) |
| Âge minimum, accord des parents | Confidentialité, CGU | porteur, avec un juriste |
| Bases légales, droits, responsabilité, droit applicable, tribunaux | Confidentialité, CGU | juriste |
| Acceptation des CGU à l'inscription (case à cocher ou non) | CGU | porteur |
| Offre, prix, durée, remboursement, réclamation | CGV | chantier `abonnement-mobile-money` |
| Validation des phrases de mission | Mission | porteur |
