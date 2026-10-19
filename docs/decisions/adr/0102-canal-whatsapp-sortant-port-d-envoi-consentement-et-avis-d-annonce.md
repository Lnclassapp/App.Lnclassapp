# ADR-0102 : Canal WhatsApp sortant — un port d'envoi commun, l'API Cloud de Meta en direct, un accord explicite par compte et un avis d'annonce sans contenu
<!-- index
titre: Canal WhatsApp sortant — port d'envoi commun, API Cloud de Meta en direct, accord explicite, avis d'annonce sans contenu
statut: Proposé *(2026-10-16, en attente des réponses Q1 à Q12 du porteur)* — *amende 0045 (§4 « Hors périmètre »)*
problematique: Premier service tiers appelé par l'application. Port `WhatsappGatewayPort` (contexte `communication`) partagé avec `verification-whatsapp` ; adaptateur API Cloud de Meta (n8n possible derrière le même port) ; `whatsapp_consents` (empreinte du numéro), `whatsapp_deliveries`, `messages.whatsapp_notice` ; avis avec lien, jamais le contenu ; équipe et direction seulement ; plafond mensuel, silence 20 h-7 h ; webhook entrant signé pour statuts et STOP. PIN gelé jusqu'à la vérification du numéro.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/canal-whatsapp`](../../chantiers/canal-whatsapp/memo.md) · programme `refonte-application`, vague V6 |
| **Amende** | [ADR-0045](./0045-annonces-publication-programmee-et-audience.md) §4, « Hors périmètre » : l'avis WhatsApp d'une annonce y entre. [ADR-0032](./0032-recuperation-assistee-du-pin.md) **non amendé** : voir §4.7 |
| **Partagé avec** | [`verification-whatsapp`](../../chantiers/verification-whatsapp/memo.md) (backlog) : même port, même fournisseur, même sécurité |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Lnclass ne joint personne hors de l'application. Une annonce n'est vue qu'à la prochaine visite (ADR-0045) et ne dure que 30 jours (ADR-0081). Le PIN oublié se récupère par un code dicté de vive voix (ADR-0032), faute de canal. Le public lit WhatsApp ; chaque compte a un numéro ivoirien unique (`users.contact`).

Aujourd'hui, WhatsApp n'existe dans le code que sous forme de **liens sortants** `wa.me` (`ShareHelper`, `SupportHelper`) : c'est l'appareil de l'utilisateur qui envoie, jamais Lnclass. L'application n'a **aucun client HTTP sortant**, aucune route entrante signée, aucun consentement stocké, et ne connaît **l'âge de personne** (pas de date de naissance, politique de confidentialité §3). Ce canal est donc le **premier service tiers** que l'application appelle, et il touche des **mineurs**.

Le porteur a évoqué un « hook n8n » le 2026-09-28 pour la vérification du numéro (ADR-0063, journal `croissance-parrainage`). Le chantier `verification-whatsapp` a tranché, avant d'être mis au backlog, qu'il partagerait le port d'envoi de ce chantier. La feuille de route demande **une seule décision** sur le fournisseur, le coût et la sécurité pour les deux : c'est celle-ci.

## 2. Moteurs de décision

1. **Aucun message hors de l'audience, avant la publication, ou sans accord** (porte de la V6). Une annonce lisible par WhatsApp échapperait à la règle de lecture de l'ADR-0078 §4.3.
2. **Le moins de données possible chez un tiers**, et aucune qui ne soit nécessaire : un numéro et un lien, pas un nom, pas un contenu.
3. **Un coût borné** : chaque message est facturé par Meta à l'envoi ; une annonce nationale toucherait tous les consentants d'un coup.
4. **Le domaine ignore le fournisseur** : changer d'intermédiaire (n8n, autre prestataire) ne touche que l'adaptateur.
5. **Un seul envoi par destinataire**, même si le job est rejoué.
6. **Rien à héberger de plus** si on peut l'éviter.

## 3. Options envisagées

### Fournisseur (Q1)

| Option | Pour | Contre |
|---|---|---|
| A — **API WhatsApp Cloud de Meta, appelée par l'application** | Officielle ; hébergée par Meta ; un seul secret côté Lnclass ; les envois et l'idempotence vivent dans Solid Queue, déjà en place | Démarches Meta (entreprise vérifiée, numéro dédié, modèles approuvés) ; premier client HTTP de l'application |
| B — Hook **n8n** devant l'API Cloud | Le porteur peut modifier un flux sans déploiement | n8n **n'est pas un fournisseur** : Meta reste derrière. Un serveur de plus à héberger et à mettre à jour ; un secret partagé signé dans les deux sens ; numéros (et plus tard codes) qui transitent par un système de plus, à déclarer comme sous-traitant ; deux endroits où rejouer un envoi |
| C — Prestataire agréé (BSP) devant Meta | Tableau de bord, support | Coût par message ajouté au tarif Meta ; même démarches ; un sous-traitant de plus |
| D — Passerelle non officielle (WhatsApp Web automatisé) | Aucune démarche | Contraire aux conditions de WhatsApp : numéro banni sans préavis. **Exclue** |
| E — Statu quo : liens `wa.me` seulement | Gratuit, déjà là | L'utilisateur doit agir : ne résout ni l'avis d'annonce ni l'envoi d'un code |

**Retenue : A**, derrière un port qui garde B et C possibles sans toucher au domaine.

### Contenu du message (Q2)

| Option | Pour | Contre |
|---|---|---|
| A — L'annonce entière (titre, texte, image) | Lisible sans ouvrir l'application | Contourne la règle de lecture ; une annonce retirée reste dans WhatsApp ; un modèle par forme d'annonce ; le contenu part chez Meta |
| B — **Un avis avec un lien** | Le contenu reste derrière la connexion ; un seul modèle ; rien de l'annonce chez Meta | Il faut ouvrir l'application. **Retenue** |

### Accord (Q4)

| Option | Pour | Contre |
|---|---|---|
| A — Tous les comptes, désinscription possible | Portée maximale | Envoi non sollicité à des mineurs ; contraire à l'esprit de la loi n° 2013-450 ; Meta exige un accord préalable |
| B — **Accord explicite par compte, désactivé par défaut** | Preuve de l'accord ; conforme à la règle de Meta | Portée faible au départ. **Retenue** |
| C — Accord par l'établissement pour ses élèves | Une démarche pour des centaines d'élèves | L'établissement n'est pas titulaire du numéro ; aucune preuve individuelle |

## 4. Décision

> **Nous envoyons des messages WhatsApp par l'API Cloud de Meta, derrière un port d'envoi générique du contexte `communication` ; nous n'écrivons qu'à un compte qui l'a accepté pour son numéro actuel ; et, pour une annonce, nous n'envoyons qu'un avis avec un lien, à la demande de l'équipe ou de la direction, sous un plafond mensuel, jamais la nuit.**

### 4.1 Le port d'envoi (commun avec `verification-whatsapp`)

`Ports::Communication::WhatsappGatewayPort` — gelé au Lot 0 :

| Méthode | Contrat |
|---|---|
| `send_template(to:, template:, variables:, idempotency_key:)` | `to` : numéro E.164 sans `+` (`225` + les 10 chiffres de `users.contact`). `template` : clé d'un modèle déclaré dans `config/whatsapp.yml`. `variables` : tableau de chaînes. → `Shared::Result.success(provider_message_id)` ou `failure(:invalid_recipient \| :rate_limited \| :unavailable \| :unauthorized \| :rejected)` |

Le port ne connaît ni les annonces, ni les comptes, ni les codes : `verification-whatsapp` l'appellera avec son propre modèle (catégorie « authentification »).

Adaptateurs :

- `Repositories::Communication::WhatsappCloudGateway` : `POST https://graph.facebook.com/<version>/<phone_number_id>/messages`, jeton dans les credentials, délai de 5 s, aucune gemme ajoutée (`Net::HTTP`). Il traduit les codes d'erreur de Meta en symboles du port ; il ne lève jamais vers le domaine.
- `Repositories::Communication::LogWhatsappGateway` : développement et recette. Écrit dans le journal, n'appelle personne. **Choisi par défaut** tant que `whatsapp.enabled` est faux.

Si le porteur garde n8n (Q1), un troisième adaptateur `N8nWhatsappGateway` implémente le même port : corps signé HMAC-SHA256 (`X-Lnclass-Signature`, horodatage inclus, fenêtre de 5 minutes), réponse signée par n8n et vérifiée, n8n déclaré sous-traitant. Rien d'autre ne change.

### 4.2 Tables

**`whatsapp_consents`** (contexte `communication`) :

| Colonne | Contrainte |
|---|---|
| `user_id` | `NOT NULL`, FK `users` `ON DELETE CASCADE`, **index unique** : une ligne par compte |
| `contact_digest` | `string NOT NULL` : HMAC-SHA256 du numéro accepté, clé tirée de `secret_key_base` (comme `pin_recovery_codes.code_digest`) |
| `granted_at` | `datetime NOT NULL` |
| `revoked_at` | `datetime NULL` |
| `revoked_via` | `string NULL`, `CHECK IN ('profile','stop_reply')`, et `CHECK ((revoked_at IS NULL) = (revoked_via IS NULL))` |
| `text_version` | `string NOT NULL` : version du texte d'accord affiché (preuve) |

Un compte **consent** quand sa ligne existe, `revoked_at IS NULL` **et** `contact_digest` correspond à son `users.contact` actuel. Changer de numéro (`ChangeOwnContact`) n'écrit donc rien ici : l'ancien accord cesse de valoir de lui-même, et le profil le redemande (Q11). L'anonymisation (`AnonymizeUser`, ADR-0036) supprime la ligne.

**`whatsapp_deliveries`** :

| Colonne | Contrainte |
|---|---|
| `message_id` | `NOT NULL`, FK `messages` `ON DELETE CASCADE` |
| `user_id` | `NOT NULL`, FK `users` `ON DELETE CASCADE` |
| `status` | `CHECK IN ('pending','sent','delivered','failed','skipped_quota')` |
| `provider_message_id` | `string NULL`, index unique partiel `WHERE provider_message_id IS NOT NULL` |
| `error_code` | `string NULL` (symbole du port, jamais le corps de la réponse de Meta) |
| `attempts` | `integer NOT NULL DEFAULT 0`, `CHECK (attempts <= 3)` |
| `sent_at`, `delivered_at` | `datetime NULL` |

Index unique `(message_id, user_id)` : **un seul avis par annonce et par destinataire**, même si le job rejoue. Index `(created_at)` pour le décompte mensuel. **Aucun numéro n'est copié** : il est lu dans `users` au moment de l'envoi.

**`messages.whatsapp_notice`** : `boolean NOT NULL DEFAULT false`. Figé une fois l'annonce publiée.

### 4.3 Qui déclenche, qui reçoit

| Rôle | Coche « Avertir sur WhatsApp » | Peut recevoir un avis |
|---|---|---|
| `team` | Oui | Oui, s'il a accepté |
| `school_admin` | Oui, pour ses annonces | Oui, s'il a accepté |
| `teacher` | **Non** en première livraison (`whatsapp.authors` en configuration) | Oui, s'il a accepté |
| `student` | — | **Non** tant que `whatsapp.students` est faux, c'est-à-dire jusqu'à l'avis des juristes (Q4). Le profil élève ne montre alors pas la ligne |

**Destinataires** : la règle de lecture de l'ADR-0078 §4.3, appliquée **au moment de l'envoi**, restreinte aux comptes qui consentent (§4.2), dont `contact` n'est pas `NULL`, sauf l'auteur. Une seule requête (`Queries::Communication::WhatsappRecipientsQuery`), jamais une boucle sur les comptes.

### 4.4 Quand et quoi

- L'avis part à la **publication effective** de l'annonce : `CreateMessage` (publication immédiate), `UpdateMessage` (passage de brouillon à publiée) et `PublishScheduledMessages` mettent en file `Communication::WhatsappNoticeJob` **après** la transaction.
- **Silence de 20 h à 7 h**, heure d'Abidjan (UTC) : le job est programmé à 7 h.
- Le job **relit l'annonce** avant chaque lot de 100 destinataires : archivée, retirée ou terminée, il s'arrête sans rien envoyer de plus.
- Une annonce **modifiée** n'est jamais renvoyée.
- **Modèle unique** `announcement_notice`, catégorie « utilitaire », en français : « Nouvelle annonce de {{1}} sur Lnclass. Ouvre-la ici : {{2}}. Pour ne plus recevoir ces messages, réponds STOP. » `{{1}}` = nom de l'établissement, ou « l'équipe Lnclass » pour une annonce nationale ; `{{2}}` = `https://lnclass.com/announcements`. **Ni titre, ni texte, ni nom d'auteur, ni nom d'élève.**

### 4.5 Coût

- Lnclass paie (recommandation Q3, à confirmer). Le tarif Meta du jour pour la Côte d'Ivoire, par catégorie, est relevé par le porteur **avant** que cet ADR passe à « Accepté », et inscrit ici.
- `whatsapp.monthly_cap` (configuration) : au-delà, les destinataires restants passent en `skipped_quota` ; l'annonce reste publiée ; l'auteur le voit dans « Mes annonces ».
- Le formulaire montre le **nombre de destinataires** avant publication (UDR-0123).

### 4.6 Webhook entrant (statuts et STOP)

- `GET /webhooks/whatsapp` : vérification d'abonnement Meta (`hub.verify_token` comparé en temps constant).
- `POST /webhooks/whatsapp` : **signature `X-Hub-Signature-256` vérifiée** (HMAC-SHA256 du corps brut avec le secret de l'application Meta, `ActiveSupport::SecurityUtils.secure_compare`) **avant** tout analyse JSON ; corps limité à 64 Kio ; sans session, sans CSRF ; `rate_limit` par IP. Signature absente ou fausse : `401`, rien n'est lu.
- Statuts `delivered` / `failed` : mis à jour par `provider_message_id`. Un identifiant inconnu est ignoré.
- Message texte reçu : seul « STOP » ou « ARRET » (casse et espaces ignorés) est lu ; il retire l'accord du compte dont le numéro correspond (`revoked_via: 'stop_reply'`). Tout autre texte est ignoré et **n'est pas stocké**.

### 4.7 Code de récupération du PIN : gelé

Le numéro d'un compte n'a jamais été prouvé (le chantier `verification-whatsapp` est au backlog). Envoyer un code de récupération à ce numéro donnerait le compte à quiconque reçoit les messages d'un numéro mal saisi. **L'ADR-0032 n'est pas amendé ici** ; il le sera par un ADR ultérieur, quand le numéro sera vérifié. L'UDR-0124 décrit déjà l'écran, pour que ce volet ne soit pas re-cadré.

### 4.8 Amendement de l'ADR-0045

Dans l'ADR-0045 §4, « Hors périmètre : messagerie de classe, notifications temps réel et envoi SMS » se lit désormais : « … et envoi SMS. **L'avis WhatsApp d'une annonce relève de l'ADR-0102.** »

## 5. Conséquences

### 🟢 Positives

- Une annonce de l'équipe ou de la direction atteint, le jour même, ceux qui l'ont accepté.
- La porte de la V6 tient même si un numéro est partagé : le message ne contient rien qui ne soit public.
- `verification-whatsapp` démarre avec le port, le fournisseur et la sécurité déjà décidés.
- Changer d'intermédiaire (n8n, prestataire) ne touche qu'un adaptateur.

### 🔴 Coûts consentis

- **Démarches longues hors du code** : vérification de l'entreprise par Meta (RCCM, encore « à compléter » dans la politique de confidentialité), numéro dédié — qui **ne peut pas** être celui du support, utilisé dans l'application WhatsApp —, approbation du modèle.
- **Un tiers de plus** : Meta reçoit des numéros de comptes, dont ceux de mineurs si les élèves sont ouverts. La politique de confidentialité (§3, §4, §6) doit le dire, et le transfert hors de Côte d'Ivoire doit être validé par les juristes (ARTCI).
- **Portée faible au départ** : un accord explicite, désactivé par défaut, ne sera donné que par une partie des comptes ; les élèves sont exclus jusqu'à l'avis des juristes.
- **Coût variable** à chaque annonce, borné par le plafond, mais réel.
- **Le premier client HTTP sortant** de l'application : délais, pannes et jeton expiré à gérer, et un secret de plus à faire tourner.
- L'avis oblige à ouvrir l'application : il informe, il ne remplace pas la lecture.

## 6. Notes d'implémentation

```ruby
# 🧠 DOMAINE · Ports::Communication::WhatsappGatewayPort
# Rôle : contrat d'envoi d'un modèle WhatsApp, commun aux avis d'annonce et à la vérification du numéro
# ADR  : 0102
module Ports
  module Communication
    module WhatsappGatewayPort
      # to : "225" + 10 chiffres ; template : clé de config/whatsapp.yml ; variables : [String]
      # → Shared::Result.success(provider_message_id) | failure(:invalid_recipient | :rate_limited | :unavailable | :unauthorized | :rejected)
      def send_template(to:, template:, variables:, idempotency_key:)
        raise NotImplementedError, "#{self.class} doit implémenter #send_template"
      end
    end
  end
end
```

```yaml
# config/whatsapp.yml (aucun secret : jeton, secret d'application et verify_token sont dans les credentials)
production:
  enabled: false            # vrai seulement après l'acceptation de cet ADR et l'approbation du modèle
  authors: [team, school_admin]
  students: false           # Q4 : avis des juristes
  monthly_cap: 0            # Q3 : fixé par le porteur
  quiet_hours: { from: 20, to: 7 }
  consent_text_version: "2026-10"
  templates:
    announcement_notice: { name: announcement_notice, language: fr }
```

## 7. Comment vérifier que la décision est respectée

- **Tests de refus du use case d'envoi** (porte de la V6) : aucun appel au port pour un compte hors audience, une annonce non publiée, archivée ou retirée, un compte sans accord, un accord révoqué, un accord dont l'empreinte ne correspond plus au numéro, un élève quand `students` est faux, l'auteur.
- **Test d'idempotence** : deux exécutions du job pour la même annonce n'appellent le port qu'une fois par destinataire (`RecordNotUnique` sur `(message_id, user_id)`).
- **Test du modèle** : les variables envoyées ne contiennent ni le titre ni le texte de l'annonce (assertion sur le double du port).
- **Test du webhook** : signature absente ou fausse → `401` et aucune écriture ; « STOP » révoque ; tout autre texte n'écrit rien.
- **Test de policy** : un enseignant qui envoie `whatsapp_notice=1` voit le champ ignoré (la valeur reste fausse).
- Le test de pureté du domaine refuse toute référence à `Net::HTTP` dans `app/domain/` (déjà couvert par la règle d'or n° 1 pour `ActiveRecord` ; à étendre au Lot 0).

## 8. Remplace, complète, amende

- **Amende** l'ADR-0045 §4 (« Hors périmètre »), voir §4.8.
- **Ne touche pas** l'ADR-0032 : le volet PIN est gelé (§4.7).
- **Sert** le chantier `verification-whatsapp`, qui ajoutera son modèle « authentification » sans redéfinir le port.

## 9. Points à confirmer par le porteur

Questions Q1 à Q12 du [memo](../../chantiers/canal-whatsapp/memo.md#ce-que-le-grill-a-révélé). Cet ADR reste **Proposé** tant que Q1 (fournisseur), Q3 (payeur, tarif, plafond), Q4 (accord, juristes) et Q5 (qui déclenche) ne sont pas répondues.
