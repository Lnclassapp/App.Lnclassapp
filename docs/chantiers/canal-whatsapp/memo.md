# Memo — Canal WhatsApp pour joindre les utilisateurs hors de l'application

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage — **grill écrit, réponses du porteur attendues** (Q1 à Q12 ci-dessous) |
| **Ouvert le** | 2026-09-28 · cadrage repris le 2026-10-16 |
| **Branche** | `feature/canal-whatsapp` *(code)* · `docs/cadrage-canal-whatsapp` *(ce cadrage)* |
| **Programme** | `refonte-application` — **V6**, après `annonces` (V6a, PR #162) et `annonces-v2` (PR #182), tous deux en production |
| **Décisions** | [ADR-0102](../../decisions/adr/0102-canal-whatsapp-sortant-port-d-envoi-consentement-et-avis-d-annonce.md) · [UDR-0122](../../decisions/udr/0122-consentement-whatsapp-sur-le-profil.md) · [UDR-0123](../../decisions/udr/0123-avis-whatsapp-d-une-annonce.md) · [UDR-0124](../../decisions/udr/0124-code-de-recuperation-du-pin-par-whatsapp.md) — toutes **Proposé** |

---

## Le problème

Lnclass ne peut joindre personne en dehors de l'application :

- **Annonces** : une annonce n'est vue qu'à la prochaine visite (ADR-0045, « Conséquences »). Elle dure 30 jours et un auteur n'en a que 3 en ligne (ADR-0081) : un élève qui ouvre l'application une fois par mois en manque.
- **Récupération du PIN** : un élève qui a oublié son PIN dépend d'un enseignant ou de l'équipe, qui lui dicte un code de 8 chiffres de vive voix (ADR-0032). Le SMS a été reporté faute de fournisseur.
- **Codes d'établissement** : 3 900 codes à transmettre à la main faute de canal (ADR-0057, « Conséquences »).

Or chaque compte a un numéro de mobile ivoirien unique (`users.contact`, format `0[157]XXXXXXXX`), et WhatsApp est le canal que ce public lit réellement. Aujourd'hui l'application n'utilise WhatsApp **que par des liens sortants** (`wa.me`) : rien n'est envoyé par Lnclass.

## Pour qui

- **Élèves** : savoir qu'une annonce les attend, sans ouvrir l'application pour le découvrir.
- **Enseignants** : idem pour les annonces de l'équipe et de leur direction.
- **Direction** (`school_admin`) et **équipe** (`team`) : ceux qui publient, et qui veulent savoir combien de personnes ont été averties.
- **Le porteur**, qui paie chaque message.

## Pourquoi maintenant

Ce n'est pas urgent : les annonces sont livrées, le canal est leur suite. Le cadrer maintenant sert à lancer **les démarches longues hors du code** : vérification de l'entreprise par Meta (qui exige le RCCM, encore « à compléter » dans la politique de confidentialité), un numéro dédié, l'approbation des modèles de message, l'avis des juristes sur le consentement des mineurs et le transfert de données hors de Côte d'Ivoire. Aucune ligne de code ne doit partir avant les réponses Q1 à Q5.

## Inventaire au 2026-10-16

### Documentation

| Source | État |
|---|---|
| Ce dossier (PR #70, fusionnée le 2026-09-28) | Memo en brouillon, PRD, plan et journal restés au gabarit. La PR ne contenait que ces 4 fichiers. La feuille de route la dit encore « non fusionnée » : c'est faux depuis le 2026-09-28 |
| [`verification-whatsapp`](../verification-whatsapp/memo.md) | Backlog, grill arrêté à la question 2. Q1 tranchée : **chantier séparé, port d'envoi commun** dans `communication` |
| Feuille de route, fiche V6 et Q11 à Q14 | Q11 à Q14 jamais répondues. La porte de la V6 est déjà écrite : aucun message hors de l'audience, avant la publication, ou sans consentement |
| ADR-0045 | Exclut « notifications temps réel et envoi SMS » du périmètre des annonces : à amender |
| ADR-0032 | Reporte le SMS « quand un fournisseur sera choisi par ADR » : à amender seulement si la récupération par WhatsApp entre (Q9) |
| ADR-0063, journal `croissance-parrainage` | Le porteur y a demandé un **hook n8n** pour la vérification du numéro (2026-09-28) |

### Code

| Élément | Où | Ce qu'il fait |
|---|---|---|
| `whatsapp_share_url` | `app/helpers/share_helper.rb` | Lien `https://wa.me/?text=…` : partage du lien de classe, de l'établissement, parrainage, « Inviter mon enseignant ». Sortant, ouvert par l'appareil de l'utilisateur |
| `whatsapp_contact` | `app/helpers/support_helper.rb`, `config/support.yml` | Lien `wa.me/2250584258085` de la carte d'aide (support humain, 8 h-20 h) |
| `ShareChannel` | `app/domain/entities/identity/share_channel.rb` | Compte les partages par canal (`whatsapp`, `sms`, `copy`, `native`) |
| Annonces | `app/domain/use_cases/communication/*_message.rb`, `PublishScheduledMessagesJob` (Solid Queue) | Publication immédiate ou programmée ; c'est là que l'avis devra partir |
| Récupération du PIN | `IssuePinRecoveryCode`, `ResetPinWithCode`, `identity/pin_resets/new` | Code de 8 chiffres, 15 min, 5 essais, dicté de vive voix |
| **n8n, webhook, client HTTP sortant** | — | **Aucun.** Aucun `Net::HTTP`, aucune gemme HTTP, aucune route entrante signée. Ce chantier pose le **premier appel à un service tiers** de l'application |
| Consentement, date de naissance | — | **Aucun.** `users` n'a ni consentement ni âge : on ne sait pas qui est mineur |

## Déjà décidé ailleurs

> Le grill ne rouvre pas ces points, il en tire les conséquences.

- **Rattachement** : V6, après `annonces`. L'audience `school_admins` existe (V2 livrée).
- **Port d'envoi commun** avec `verification-whatsapp` : celui des deux qui démarre en premier le pose ; l'autre le réutilise. `verification-whatsapp` étant au backlog, **c'est ce chantier qui le pose** (ADR-0102).
- **Une seule décision** pour les deux chantiers sur le fournisseur, le coût et la sécurité du hook : c'est l'ADR-0102.
- **La porte de la V6** (feuille de route) : aucun message WhatsApp hors de l'audience, avant la publication, ou à qui n'y a pas consenti — prouvé par des tests de refus.

## Hors périmètre

- Une messagerie bidirectionnelle : répondre à une annonce, discuter avec un enseignant, une boîte de réception partagée. Un message reçu par Lnclass n'est lu que pour « STOP » (Lot C).
- Le contenu de l'annonce dans le message : le message est un **avis avec un lien** (recommandation Q2), le contenu reste derrière la connexion.
- Le SMS, l'e-mail, les notifications poussées du navigateur ou de l'application Android.
- Les campagnes marketing, les relances d'inactivité, tout message non lié à une annonce ou à un compte.
- L'envoi des codes d'établissement (ADR-0057) et la vérification du numéro à l'inscription : chantier `verification-whatsapp`, qui réutilisera le port.
- Les accusés de lecture affichés à l'auteur : on compte les messages remis, pas qui a lu.
- Un renvoi de l'avis quand une annonce est modifiée.

## Ce que le grill a révélé

> Grill écrit le 2026-10-16 par l'agent de cadrage, à partir des docs et du code. **Les réponses sont attendues du porteur.** Chaque ligne porte la recommandation de l'agent ; l'ADR-0102 et le PRD sont écrits sur ces recommandations et changent si le porteur répond autrement.

| # | Question au porteur | Recommandation | Conséquence sur le chantier |
|---|---|---|---|
| Q1 *(FdR Q13)* | **Fournisseur** : l'API WhatsApp Business de Meta en direct, ou un hook **n8n** devant elle ? | **API WhatsApp Cloud de Meta, appelée directement par l'application**, derrière un port. n8n n'est pas un fournisseur : il faudrait de toute façon Meta (ou une passerelle non officielle, qui fait bannir le numéro) derrière lui. Il ajoute un serveur à héberger et à protéger, un secret partagé signé dans les deux sens, et un lieu de plus où transitent numéros et codes. Le port garde n8n possible plus tard sans toucher au domaine | ADR-0102 §4.1. Si le porteur garde n8n : même port, autre adaptateur, signature HMAC-SHA256 dans les deux sens, n8n déclaré comme sous-traitant |
| Q2 *(FdR Q11)* | Le message porte-t-il **l'annonce entière** ou **un avis avec un lien** ? | **Un avis avec un lien**, sans le texte de l'annonce : « Nouvelle annonce de *{établissement ou Lnclass}* sur Lnclass : *{lien}* ». Le contenu reste derrière la connexion (la porte de la V6 tient même si le numéro est partagé), une annonce retirée ne survit pas dans WhatsApp, un seul modèle à faire approuver par Meta, aucune donnée de l'annonce chez Meta | Un seul modèle « utilitaire ». Le titre n'est pas envoyé non plus |
| Q3 *(FdR Q13)* | **Coût** : qui paie, et quel plafond ? | Meta facture chaque message **à l'envoi**, par catégorie (utilitaire, authentification, marketing) et par pays du destinataire : relever le tarif du jour pour la Côte d'Ivoire avant d'accepter l'ADR. Une annonce nationale `all` peut viser **tous les comptes consentants** d'un coup. Recommandation : Lnclass paie ; **plafond mensuel** de messages en configuration, envoi refusé et signalé au-delà ; l'auteur voit le **nombre de destinataires** avant de publier | `config/whatsapp.yml` (plafond), compteur mensuel, refus `:quota_exceeded` visible dans « Mes annonces » |
| Q4 *(FdR Q12)* | **Consentement**, surtout des **mineurs** : qui reçoit, après quel accord ? | **Accord explicite, désactivé par défaut, pour tous les rôles**, donné par le titulaire du compte sur son profil, retirable à tout moment (profil ou réponse « STOP »). Nous ne connaissons pas l'âge (aucune date de naissance) : faire confirmer par les juristes si l'accord d'un élève mineur suffit au regard de la loi n° 2013-450 et du transfert vers Meta (hors de Côte d'Ivoire, ARTCI). En attendant leur avis : **les élèves sont exclus de la première livraison** | Table `whatsapp_consents` avec preuve (date, version du texte, source). Politique de confidentialité amendée (Meta sous-traitant, transfert). Si les juristes valident : un drapeau de configuration ouvre les élèves, sans code |
| Q5 | **Qui peut déclencher** un avis WhatsApp ? | **L'équipe et la direction** seulement, case « Avertir sur WhatsApp » cochée annonce par annonce. **Pas l'enseignant** en première livraison : il ne paie pas, il écrit à des mineurs, et 3 annonces en ligne par enseignant multiplient le coût | Policy dans `CreateMessage` / `UpdateMessage` ; colonne `messages.whatsapp_notice` |
| Q6 | **Quand** l'avis part-il ? | À la **publication** effective (immédiate ou par le job des annonces programmées), **jamais entre 20 h et 7 h** (heure d'Abidjan) : décalé à 7 h. Pas de renvoi si l'annonce est modifiée ; rien n'est envoyé si elle est archivée ou retirée avant l'envoi | Le job d'envoi relit le statut de l'annonce juste avant chaque lot |
| Q7 | **Numéro d'envoi** : lequel ? | **Un numéro dédié**, jamais utilisé dans l'application WhatsApp. Le numéro du support (`0584258085`) ne peut pas servir aux deux : Meta retire un numéro de l'application WhatsApp quand il passe sur l'API. Démarche Meta : compte Business vérifié au nom de Lnclass Côte d'Ivoire SARL, donc **RCCM** à fournir | Prérequis hors code, bloquant pour le Lot 0 |
| Q8 | Que fait-on des **réponses** envoyées au numéro ? | Les ignorer, sauf « **STOP** » (et « ARRET »), qui retire le consentement. Le message d'avis le dit. Meta renvoie aussi les statuts (remis, échec) par un webhook signé : on les garde pour compter | Lot C : route entrante signée `X-Hub-Signature-256`, sans session |
| Q9 *(FdR Q14)* | **Code de récupération du PIN** par WhatsApp : dans ce chantier, ou plus tard ? | **Plus tard, après `verification-whatsapp`.** Le numéro d'un compte n'a jamais été prouvé : quiconque a saisi un numéro qui n'est pas le sien à l'inscription recevrait, en face, le moyen de prendre le compte. Une fois le numéro vérifié, le volet devient sûr. Le Lot D est donc écrit, mais **gelé** | Lot D (UDR-0124) et l'amendement de l'ADR-0032 attendent `verification-whatsapp` |
| Q10 | **Rapport avec `verification-whatsapp`** : qui pose le port ? | **Ce chantier**, puisque l'autre est au backlog. L'ADR-0102 tranche une fois pour les deux le fournisseur, le coût, la signature et les données transmises. Recommandation de séquence : livrer le canal (lots 0 à C), puis rouvrir `verification-whatsapp` (le code de vérification réutilise le port avec un modèle « authentification »), puis dégeler le Lot D | ADR-0102 §4.1 nomme le port générique, pas « annonces » |
| Q11 | Un **changement de numéro** garde-t-il le consentement ? | **Non** : le nouveau numéro n'a rien accepté. Le consentement garde l'empreinte (HMAC) du numéro accepté ; à l'envoi, une empreinte qui ne correspond plus au numéro du compte vaut refus, et le profil redemande l'accord. Aucune écriture croisée dans `ChangeOwnContact` | `whatsapp_consents.contact_digest` ; test de refus après changement de numéro |
| Q12 | Faut-il dire à l'auteur **qui** a reçu l'avis ? | **Non, un compte** : « Averties sur WhatsApp : 214 · échecs : 3 ». Aucune liste nominative (moins de données, pas de pression sur les élèves) | `whatsapp_deliveries` agrégées par annonce dans « Mes annonces » |

## Cas limites identifiés

- **Téléphone partagé** : le numéro d'un élève est souvent celui d'un parent. L'avis sans contenu (Q2) ne révèle que l'existence d'une annonce et le nom de l'établissement.
- **Compte anonymisé** (ADR-0036, `contact` `NULL`) : consentement effacé, jamais destinataire.
- **Numéro sans WhatsApp** : Meta renvoie un échec ; il est compté, jamais retenté, et ne bloque pas les autres.
- **Annonce retirée entre la publication et l'envoi** : le job relit le statut, rien ne part ; ce qui est déjà parti reste parti (d'où l'avis sans contenu).
- **Annonce programmée publiée à 22 h** : publiée à 22 h dans l'application, avis décalé à 7 h.
- **Plafond mensuel atteint au milieu d'une annonce** : l'annonce est publiée, la partie non envoyée est marquée `skipped_quota`, l'auteur le voit.
- **Double exécution du job** (Solid Queue rejoue) : un seul envoi par couple annonce-destinataire (index unique), clé d'idempotence côté Meta.
- **Auteur destinataire de sa propre annonce** : exclu.
- **Changement de rôle ou départ d'une classe** entre la publication et l'envoi : l'audience est calculée au moment de l'envoi, par la même règle de lecture que l'application (ADR-0078 §4.3).
- **Panne de Meta** : nouvel essai avec délai croissant, 3 fois au plus, puis `failed`. Jamais d'exception visible par l'auteur.
- **Jeton Meta expiré ou révoqué** : tous les envois échouent avec la même erreur → alerte journalisée une fois, pas une par message.

## Questions encore ouvertes

Toutes celles de la table ci-dessus, Q1 à Q12, jusqu'à la réponse du porteur. Deux relèvent aussi d'un tiers :

- **Juristes** : base légale du traitement, consentement d'un mineur, transfert vers Meta (Q4).
- **Démarches Meta** : RCCM, vérification de l'entreprise, numéro dédié, approbation du modèle d'avis (Q7).
