# PRD — Canal WhatsApp pour joindre les utilisateurs hors de l'application

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
>
> **Écrit sur les recommandations du grill (memo, Q1 à Q12), pas encore sur les réponses du porteur.** Une réponse différente modifie ce fichier avant le Lot 0.

## 1. Contexte

Une annonce n'est vue qu'à la prochaine visite, et le PIN oublié se récupère de vive voix ([memo](memo.md)). Ce chantier pose le premier envoi sortant de Lnclass : un **avis WhatsApp** (un lien, jamais le contenu) envoyé, à la publication d'une annonce de l'équipe ou de la direction, aux comptes de son audience qui l'ont accepté pour leur numéro actuel. Il pose aussi le port d'envoi que `verification-whatsapp` réutilisera ; la récupération du PIN par WhatsApp est décrite mais **gelée** jusqu'à la vérification du numéro.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| `team` | Cocher « Avertir aussi sur WhatsApp » sur ses annonces ; voir le nombre de destinataires et le bilan ; accepter ou refuser pour lui-même | Voir qui a reçu l'avis ; avertir après publication ; dépasser le plafond mensuel |
| `school_admin` | Idem, pour les annonces de son établissement | Idem |
| `teacher` | Accepter ou refuser pour lui-même ; recevoir les avis | Cocher l'avis (tant que `whatsapp.authors` ne le contient pas) |
| `student` | **Rien** tant que `whatsapp.students` est faux. Ensuite : accepter ou refuser pour lui-même, recevoir les avis | Cocher l'avis |
| Meta (webhook) | Signaler un statut de remise, transmettre un « STOP » | Toute autre écriture ; tout appel non signé |

Règles d'autorisation :
- Rédaction : la policy existante `Policies::Communication::PublishPolicy` (ADR-0078 §4.2), étendue par `Policies::Communication::WhatsappNoticePolicy` (rôle dans `whatsapp.authors`).
- Destinataires : la règle de lecture de l'ADR-0078 §4.3, appliquée au moment de l'envoi, restreinte aux accords valides (ADR-0102 §4.2, §4.3).
- Accord : chacun ne gère que le sien (aucune policy croisée, l'acteur est le compte connecté).

## 3. Parcours utilisateur

### Chemin nominal

1. Un enseignant ouvre son profil, touche « Activer » sur la ligne « Annonces sur WhatsApp », lit le message type, touche « Activer ». La ligne indique « Activées pour ce numéro ».
2. La direction de son établissement rédige une annonce pour `teachers`, coche « Avertir aussi sur WhatsApp » et lit « 12 personnes l'ont accepté dans cette audience ». Elle publie à 10 h.
3. Le job d'envoi part après la transaction. Chacun des 12 reçoit : « Nouvelle annonce de Lycée Moderne de Tiassalé sur Lnclass. Ouvre-la ici : https://lnclass.com/announcements. Pour ne plus recevoir ces messages, réponds STOP. »
4. L'enseignant touche le lien, se connecte si besoin, lit l'annonce dans la page Annonces.
5. Dans « Mes annonces », la direction lit « WhatsApp : 12 avertis ».

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Publication à 21 h | L'annonce est en ligne à 21 h ; l'avis part à 7 h ; « Mes annonces » : « WhatsApp : envoi à 7 h » |
| Annonce programmée pour 8 h | L'avis part après sa publication par le job, à 8 h |
| Annonce retirée ou archivée avant ou pendant l'envoi | Le job relit le statut et s'arrête ; « envoi arrêté, N avertis » |
| Annonce modifiée après publication | Aucun nouvel avis |
| Plafond mensuel atteint | L'annonce est publiée ; les destinataires restants passent en `skipped_quota` ; « N non envoyés (plafond du mois) » |
| Numéro sans WhatsApp, refusé par Meta | `failed`, compté en « non joints », jamais retenté |
| Meta indisponible ou limite de débit | Nouvel essai avec délai croissant, 3 essais au plus, puis `failed` |
| Jeton Meta invalide | Tous `failed` (`unauthorized`) ; une seule alerte journalisée |
| Le compte change de numéro | L'accord ne vaut plus ; le profil affiche « à réactiver » ; aucun avis |
| Le compte répond « STOP » | Accord retiré (`stop_reply`) ; le profil affiche « Désactivées depuis WhatsApp » |
| Le compte répond autre chose | Ignoré, non stocké |
| Webhook non signé ou mal signé | `401`, aucune lecture du corps |
| Un enseignant forge `whatsapp_notice=1` | Ignoré ; l'annonce est publiée sans avis |
| Compte anonymisé | Accord supprimé ; jamais destinataire |
| Job rejoué | Un seul avis par annonce et par destinataire |
| `whatsapp.enabled` faux | Aucune case, aucune ligne de profil ; l'adaptateur de journal est utilisé |

## 4. Critères d'acceptation

Chacun devient un test. Les critères **WA-R** sont les tests de refus exigés par la porte de la V6.

```gherkin
# Accord — Lot A

Scénario: WA-01 Un enseignant accepte les avis pour son numéro
  Étant donné un enseignant connecté dont le numéro est 0701020304
  Et qu'il n'a jamais accepté les avis WhatsApp
  Quand il active « Annonces sur WhatsApp » depuis son profil
  Alors un accord est enregistré avec l'empreinte de 0701020304 et la version du texte affiché
  Et la ligne indique « Activées pour ce numéro »
  Et le journal contient « whatsapp.consent_granted » pour ce compte

Scénario: WA-02 Désactiver ne demande pas de confirmation
  Étant donné un enseignant dont l'accord est actif
  Quand il touche « Désactiver »
  Alors l'accord est révoqué avec « revoked_via: profile »
  Et la ligne indique « Désactivées »

Scénario: WA-03 La fenêtre montre le message tel qu'il sera reçu
  Étant donné un enseignant de l'établissement « Lycée Moderne de Tiassalé »
  Quand il ouvre la fenêtre d'activation
  Alors il lit son numéro groupé
  Et un aperçu qui contient « Nouvelle annonce de Lycée Moderne de Tiassalé sur Lnclass »

Scénario: WA-04 Un nouveau numéro doit être réactivé
  Étant donné un enseignant dont l'accord est actif pour 0701020304
  Quand il change son numéro pour 0505060708
  Alors la ligne indique « Ton numéro a changé : à réactiver »
  Et il ne fait plus partie des destinataires d'aucun avis

Scénario: WA-05 L'élève ne voit pas la ligne tant que les élèves ne sont pas ouverts
  Étant donné que « whatsapp.students » est faux
  Quand un élève ouvre son profil
  Alors il ne voit aucune ligne « Annonces sur WhatsApp »
  Et une requête POST vers /profile/whatsapp_consent est refusée

Scénario: WA-06 L'anonymisation supprime l'accord
  Étant donné un enseignant dont l'accord est actif
  Quand son compte est anonymisé
  Alors aucune ligne whatsapp_consents ne le concerne

# Avis d'annonce — Lot B

Scénario: WA-10 La direction avertit les enseignants de son établissement
  Étant donné 3 enseignants de l'établissement A qui ont accepté
  Et 1 enseignant de l'établissement A qui n'a pas accepté
  Quand la direction de A publie à 10 h une annonce « teachers » avec « Avertir aussi sur WhatsApp »
  Alors le port d'envoi est appelé 3 fois avec le modèle « announcement_notice »
  Et les variables sont le nom de l'établissement A et le lien de la page Annonces
  Et « Mes annonces » affiche « WhatsApp : 3 avertis »

Scénario: WA-11 Le nombre de destinataires suit l'audience
  Étant donné l'équipe sur le formulaire d'une nouvelle annonce
  Quand elle passe l'audience de « teachers » à « school_admins »
  Alors le nombre affiché est celui des directions qui ont accepté

Scénario: WA-12 Silence de nuit
  Étant donné qu'il est 21 h à Abidjan
  Quand la direction publie une annonce avec avis
  Alors aucun appel au port n'a lieu avant 7 h
  Et « Mes annonces » affiche « WhatsApp : envoi à 7 h »

Scénario: WA-13 Plafond mensuel
  Étant donné un plafond mensuel de 100 avis dont 90 déjà envoyés
  Quand l'équipe publie une annonce avec avis pour 30 destinataires
  Alors 10 avis partent et 20 sont « skipped_quota »
  Et l'annonce est publiée

Scénario: WA-14 Idempotence
  Étant donné une annonce avec avis pour 5 destinataires
  Quand le job d'envoi s'exécute deux fois
  Alors le port d'envoi est appelé 5 fois en tout

Scénario: WA-15 Statut de remise
  Étant donné un avis envoyé avec l'identifiant Meta « wamid.X »
  Quand Meta signale « delivered » pour « wamid.X » par un appel signé
  Alors l'avis passe à « delivered »

Scénario: WA-16 STOP retire l'accord
  Étant donné un enseignant dont l'accord est actif pour 0701020304
  Quand Meta transmet, par un appel signé, le texte « stop » venant de 2250701020304
  Alors l'accord est révoqué avec « revoked_via: stop_reply »

# Refus — porte de la V6

Scénario: WA-R1 Aucun avis hors de l'audience
  Étant donné un élève de la classe 3e B qui a accepté (élèves ouverts)
  Quand un avis part pour une annonce ciblant la seule classe 3e A
  Alors le port d'envoi n'est jamais appelé pour cet élève

Scénario: WA-R2 Aucun avis avant la publication
  Étant donné une annonce programmée pour demain avec avis
  Quand le job d'envoi est exécuté aujourd'hui
  Alors le port d'envoi n'est pas appelé

Scénario: WA-R3 Aucun avis sans accord valide
  Étant donné un compte sans accord, un compte à l'accord révoqué et un compte dont le numéro a changé
  Quand un avis part pour une audience qui les contient tous
  Alors le port d'envoi n'est appelé pour aucun d'eux

Scénario: WA-R4 Aucun avis pour une annonce retirée
  Étant donné une annonce avec avis retirée par l'équipe avant 7 h
  Quand le job d'envoi s'exécute à 7 h
  Alors le port d'envoi n'est pas appelé

Scénario: WA-R5 Aucun contenu d'annonce dans le message
  Quand un avis part pour l'annonce « Réunion des parents » au texte « Samedi 9 h, salle 4 »
  Alors aucune variable envoyée ne contient « Réunion » ni « salle 4 »

Scénario: WA-R6 L'enseignant ne déclenche pas d'avis
  Étant donné que « whatsapp.authors » ne contient pas « teacher »
  Quand un enseignant publie une annonce en envoyant « whatsapp_notice=1 »
  Alors l'annonce est enregistrée avec « whatsapp_notice » faux
  Et le port d'envoi n'est pas appelé

Scénario: WA-R7 Aucun élève tant que les élèves ne sont pas ouverts
  Étant donné que « whatsapp.students » est faux
  Et un élève disposant d'une ligne d'accord (créée en base)
  Quand un avis part pour une annonce « students »
  Alors le port d'envoi n'est pas appelé pour cet élève

Scénario: WA-R8 Webhook non signé
  Quand un appel POST /webhooks/whatsapp arrive sans signature valide
  Alors la réponse est 401
  Et aucune ligne n'est modifiée

# Récupération du PIN — Lot D, GELÉ (ne s'exécute qu'après verification-whatsapp)

Scénario: WA-30 Réponse identique quel que soit le numéro
  Étant donné un numéro sans compte et un numéro de compte vérifié
  Quand on demande un code WhatsApp pour chacun
  Alors les deux réponses sont identiques
  Et le port n'est appelé que pour le compte vérifié
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | Entités `Communication::WhatsappConsent`, `Communication::WhatsappDelivery` ; ports `WhatsappGatewayPort`, `WhatsappConsentRepositoryPort`, `WhatsappDeliveryRepositoryPort`, `WhatsappRecipientsPort` ; use cases `GrantWhatsappConsent`, `RevokeWhatsappConsent`, `PlanWhatsappNotice`, `DeliverWhatsappNotice`, `RecordWhatsappStatus`, `HandleWhatsappReply` ; policy `WhatsappNoticePolicy` |
| Infrastructure | Migrations `whatsapp_consents`, `whatsapp_deliveries`, `messages.whatsapp_notice` ; `Orm::WhatsappConsent`, `Orm::WhatsappDelivery` ; repositories ; adaptateurs `WhatsappCloudGateway`, `LogWhatsappGateway` ; queries `WhatsappRecipientsQuery`, `WhatsappConsentQuery`, `WhatsappDeliveryStatsQuery` ; job `Communication::WhatsappNoticeJob` ; `config/whatsapp.yml`, credentials `whatsapp.*` |
| Delivery | `Communication::WhatsappConsentsController` (`/profile/whatsapp_consent`), `Communication::WhatsappRecipientsController` (`/announcements/whatsapp_recipients`), `Communication::WhatsappWebhooksController` (`/webhooks/whatsapp`) ; `AuthoredMessagesController` étendu |
| UI | Ligne et fenêtre d'accord (UDR-0122) ; case, décompte et bilan d'annonce (UDR-0123) ; écran PIN gelé (UDR-0124) ; politique de confidentialité amendée |

## 6. Décisions rattachées

- [ADR-0102](../../decisions/adr/0102-canal-whatsapp-sortant-port-d-envoi-consentement-et-avis-d-annonce.md) — canal WhatsApp sortant (Proposé) ; amende l'ADR-0045
- [UDR-0122](../../decisions/udr/0122-consentement-whatsapp-sur-le-profil.md) — consentement sur le profil (Proposé)
- [UDR-0123](../../decisions/udr/0123-avis-whatsapp-d-une-annonce.md) — avis WhatsApp d'une annonce (Proposé)
- [UDR-0124](../../decisions/udr/0124-code-de-recuperation-du-pin-par-whatsapp.md) — code du PIN par WhatsApp (Proposé, gelé)

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Comptes ayant accepté les avis (enseignants, directions) | 0 | Mesuré à 30 jours, pas de cible avant les premiers chiffres | |
| Avis remis / avis envoyés | — | ≥ 90 % | |
| Coût mensuel des avis | 0 | ≤ plafond fixé par le porteur (Q3) | |
| Appels au port hors audience, hors accord ou avant publication | — | **0** (tests WA-R) | |
