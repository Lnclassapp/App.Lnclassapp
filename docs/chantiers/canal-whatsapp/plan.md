# Plan d'exécution — Canal WhatsApp pour joindre les utilisateurs hors de l'application

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
>
> **Aucun lot ne démarre** avant : les réponses du porteur à Q1-Q5 (memo), l'ADR-0102 et les UDR-0122/0123 passées à « Accepté », le tarif Meta inscrit dans l'ADR (§4.5). Le passage en production (`whatsapp.enabled: true`) attend en plus : entreprise vérifiée par Meta, numéro dédié, modèle `announcement_notice` approuvé, politique de confidentialité validée par les juristes.

## Graphe

```
Prérequis hors code (porteur, Meta, juristes)
  ↓
Lot 0 — SOCLE (séquentiel) : tables, entités, ports, adaptateurs, config, routes
  ↓
  ├─► Lot A  Accord sur le profil (UDR-0122)        ┐
  ├─► Lot B  Avis d'annonce (UDR-0123)               ├─ en parallèle
  └─► Lot C  Webhook entrant : statuts et STOP       ┘
                                                     
  Lot D  Code du PIN par WhatsApp (UDR-0124) — GELÉ, attend `verification-whatsapp`
```

**4 lots actifs** (0, A, B, C) **+ 1 lot gelé** (D). Après le Lot 0 : 3 agents en parallèle.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + fichiers partagés
- **Fichiers**     : `db/migrate/…_create_whatsapp_consents.rb`
                     `db/migrate/…_create_whatsapp_deliveries.rb`
                     `db/migrate/…_add_whatsapp_notice_to_messages.rb`
                     `db/schema.rb`
                     `app/domain/entities/communication/whatsapp_consent.rb`
                     `app/domain/entities/communication/whatsapp_delivery.rb`
                     `app/domain/entities/communication/message.rb` *(attribut `whatsapp_notice`)*
                     `app/domain/ports/communication/whatsapp_gateway_port.rb`
                     `app/domain/ports/communication/whatsapp_consent_repository_port.rb`
                     `app/domain/ports/communication/whatsapp_delivery_repository_port.rb`
                     `app/domain/ports/communication/whatsapp_recipients_port.rb`
                     `app/infrastructure/orm/whatsapp_consent.rb` · `app/infrastructure/orm/whatsapp_delivery.rb`
                     `app/infrastructure/orm/message.rb` *(attribut)*
                     `app/infrastructure/repositories/communication/whatsapp_consent_repository.rb`
                     `app/infrastructure/repositories/communication/whatsapp_delivery_repository.rb`
                     `app/infrastructure/repositories/communication/whatsapp_cloud_gateway.rb`
                     `app/infrastructure/repositories/communication/log_whatsapp_gateway.rb`
                     `app/infrastructure/repositories/communication/message_repository.rb` *(lecture et écriture de `whatsapp_notice`)*
                     `config/whatsapp.yml` · `config/initializers/whatsapp.rb` *(choix de l'adaptateur, `config.x.whatsapp`)*
                     `config/credentials.yml.enc` *(clés `whatsapp.access_token`, `phone_number_id`, `app_secret`, `verify_token`, vides en développement)*
                     `config/routes/communication.rb` · `config/routes/identity.rb` *(fichiers partagés : toutes les routes du chantier)*
                     `test/architecture/layout_test.rb` *(pureté : `Net::HTTP` interdit dans `app/domain/`)*
- **Dépend de**    : prérequis (Q1-Q5 répondues, ADR-0102 accepté)
- **Test associé** : `test/domain/entities/communication/whatsapp_consent_test.rb` (accord valide seulement si non révoqué et empreinte égale) ·
                     `test/infrastructure/repositories/communication/whatsapp_cloud_gateway_test.rb` (transport HTTP **injecté** : le dépôt n'a ni WebMock ni VCR ; traduction des codes Meta en symboles, délai, aucune exception vers le domaine) ·
                     `test/infrastructure/repositories/communication/whatsapp_delivery_repository_test.rb` (`RecordNotUnique` sur `(message_id, user_id)`) ·
                     `test/architecture/port_contracts_test.rb` (les deux adaptateurs implémentent le port)
- **Done quand**   : `bin/rails runner "puts Ports::Communication::WhatsappGatewayPort.name"` répond ; les migrations passent dans les deux sens ; en développement, un appel au port écrit une ligne de journal et n'appelle personne ; les routes existent et répondent 404 tant que leurs contrôleurs n'existent pas

---

## Lot A — Accorder et retirer l'avis WhatsApp depuis son profil

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/communication/grant_whatsapp_consent.rb`
                     `app/domain/use_cases/communication/revoke_whatsapp_consent.rb`
                     `app/domain/use_cases/identity/anonymize_user.rb` *(supprime l'accord)*
                     `app/infrastructure/queries/communication/whatsapp_consent_query.rb`
                     `app/controllers/communication/whatsapp_consents_controller.rb`
                     `app/views/communication/whatsapp_consents/_row.html.erb`
                     `app/views/communication/whatsapp_consents/new.html.erb`
                     `app/views/communication/whatsapp_consents/create.turbo_stream.erb`
                     `app/views/communication/whatsapp_consents/destroy.turbo_stream.erb`
                     `app/views/identity/profiles/_information.html.erb`
                     `app/views/identity/profiles/_student_information.html.erb`
                     `config/locales/communication/whatsapp_consents.fr.yml`
                     `config/locales/identity/profiles.fr.yml`
                     `config/locales/communication/pages/privacy.fr.yml` *(§3 accord, §4 finalité, §6 Meta sous-traitant et transfert ; textes des juristes)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/communication/grant_whatsapp_consent_test.rb` (WA-01, WA-05 : élève refusé si `students` faux) ·
                     `test/domain/use_cases/communication/revoke_whatsapp_consent_test.rb` (WA-02) ·
                     `test/domain/use_cases/identity/anonymize_user_test.rb` (WA-06) ·
                     `test/system/communication/whatsapp_consent_test.rb` (WA-01 à WA-04 dans le navigateur, 390 px et ordinateur)
- **Done quand**   : un enseignant active les avis depuis son profil, voit l'aperçu du message, puis les désactive ; après un changement de numéro, la ligne dit « à réactiver » ; un élève ne voit pas la ligne

---

## Lot B — Avertir sur WhatsApp à la publication d'une annonce

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/policies/communication/whatsapp_notice_policy.rb`
                     `app/domain/use_cases/communication/plan_whatsapp_notice.rb` *(destinataires, plafond, silence de nuit, lignes `pending`)*
                     `app/domain/use_cases/communication/deliver_whatsapp_notice.rb` *(relit l'annonce, envoie par lots de 100, essais)*
                     `app/domain/use_cases/communication/create_message.rb`
                     `app/domain/use_cases/communication/update_message.rb`
                     `app/domain/use_cases/communication/publish_scheduled_messages.rb`
                     `app/infrastructure/queries/communication/whatsapp_recipients_query.rb`
                     `app/infrastructure/queries/communication/whatsapp_delivery_stats_query.rb`
                     `app/jobs/communication/whatsapp_notice_job.rb`
                     `app/controllers/communication/authored_messages_controller.rb`
                     `app/controllers/communication/whatsapp_recipients_controller.rb`
                     `app/views/communication/authored_messages/_form.html.erb`
                     `app/views/communication/authored_messages/_row.html.erb`
                     `app/views/communication/whatsapp_recipients/show.html.erb`
                     `app/javascript/controllers/communication/whatsapp_recipients_controller.js`
                     `config/locales/communication/authored_messages.fr.yml`
                     `config/locales/communication/whatsapp_recipients.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/communication/plan_whatsapp_notice_test.rb` (WA-10, WA-12, WA-13, WA-R1, WA-R2, WA-R3, WA-R7) ·
                     `test/domain/use_cases/communication/deliver_whatsapp_notice_test.rb` (WA-14, WA-R4, WA-R5) ·
                     `test/domain/policies/communication/whatsapp_notice_policy_test.rb` (WA-R6) ·
                     `test/infrastructure/queries/communication/whatsapp_recipients_query_test.rb` (une requête, règle de lecture de l'ADR-0078 §4.3) ·
                     `test/system/communication/whatsapp_notice_test.rb` (WA-11 : le décompte suit l'audience)
- **Done quand**   : la direction coche l'avis, lit le nombre de destinataires, publie ; le journal de l'adaptateur montre un envoi par destinataire consentant et aucun autre ; « Mes annonces » affiche le bilan

---

## Lot C — Recevoir les statuts de Meta et le « STOP »

- **Couche**       : domaine + infrastructure + delivery
- **Fichiers**     : `app/domain/use_cases/communication/record_whatsapp_status.rb`
                     `app/domain/use_cases/communication/handle_whatsapp_reply.rb`
                     `app/controllers/communication/whatsapp_webhooks_controller.rb` *(vérification `hub.verify_token`, signature `X-Hub-Signature-256` sur le corps brut avant toute analyse, 64 Kio, `rate_limit`, sans session ni CSRF)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/communication/whatsapp_webhooks_controller_test.rb` (WA-R8 : sans signature, mauvaise signature, corps trop gros → 401/413 sans écriture ; vérification d'abonnement) ·
                     `test/domain/use_cases/communication/record_whatsapp_status_test.rb` (WA-15 ; identifiant inconnu ignoré) ·
                     `test/domain/use_cases/communication/handle_whatsapp_reply_test.rb` (WA-16 ; « Stop », « ARRET », «  stop  » ; tout autre texte n'écrit rien)
- **Done quand**   : un appel signé rejoué depuis la console de test de Meta (ou un `curl` signé en recette) passe un avis à « delivered » et un « STOP » désactive l'accord ; un appel non signé reçoit 401
- **Menace écrite d'abord** (CLAUDE.md, entrée externe) : corps forgé, rejeu, inondation, JSON profond, numéro d'un autre compte dans « from ». Parades : signature avant lecture, taille bornée, `JSON.parse(max_nesting: 10)`, seul « from » sert à retrouver le compte, rien du texte n'est stocké.

---

## Lot D — Code de récupération du PIN par WhatsApp *(GELÉ)*

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/identity/send_pin_recovery_code_on_whatsapp.rb`
                     `app/controllers/identity/whatsapp_pin_codes_controller.rb`
                     `app/views/identity/whatsapp_pin_codes/new.html.erb`
                     `app/views/identity/pin_resets/new.html.erb`
                     `config/locales/identity/whatsapp_pin_codes.fr.yml` · `config/locales/identity/pin_resets.fr.yml`
                     `config/whatsapp.yml` *(modèle « authentification » — remonte au socle de ce lot au dégel)*
                     `docs/decisions/adr/NNNN-…` *(amendement de l'ADR-0032)*
- **Dépend de**    : Lot 0 **et** livraison de `verification-whatsapp` (numéro prouvé) **et** réponse Q9 du porteur
- **Test associé** : `test/domain/use_cases/identity/send_pin_recovery_code_on_whatsapp_test.rb` (WA-30 ; numéro non vérifié → rien n'est envoyé ; 3 par heure par numéro)
- **Done quand**   : un élève au numéro vérifié reçoit un code sur WhatsApp et change son PIN seul ; un numéro inconnu reçoit la même réponse et rien n'est envoyé

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/communication.rb`, `config/routes/identity.rb` | Lot 0 |
| `config/whatsapp.yml`, `config/initializers/whatsapp.rb`, credentials | Lot 0 |
| `db/schema.rb` et migrations | Lot 0 |
| Ports, entités, ORM, repositories et adaptateurs WhatsApp | Lot 0 |
| `app/infrastructure/repositories/communication/message_repository.rb`, `app/domain/entities/communication/message.rb` | Lot 0 |
| `app/domain/use_cases/identity/anonymize_user.rb` | Lot A |
| `app/views/identity/profiles/_information.html.erb`, `_student_information.html.erb`, `config/locales/identity/profiles.fr.yml` | Lot A |
| `config/locales/communication/pages/privacy.fr.yml` | Lot A |
| `create_message.rb`, `update_message.rb`, `publish_scheduled_messages.rb` | Lot B |
| `authored_messages_controller.rb`, `authored_messages/_form`, `_row`, `config/locales/communication/authored_messages.fr.yml` | Lot B |
| `whatsapp_webhooks_controller.rb` | Lot C |
| `identity/pin_resets/new.html.erb`, `config/locales/identity/pin_resets.fr.yml` | Lot D (gelé) |

Aucun fichier n'est listé par deux lots parallèles.

## Portes de sortie

- [ ] Lots 0, A, B, C `Done` ; Lot D reste gelé et le journal le dit
- [ ] Un rôle distinct de l'auteur a **exécuté** le résultat : accord, publication avec avis, bilan, webhook signé et non signé, en recette avec l'adaptateur de journal, puis un envoi réel vers un numéro de test Meta
- [ ] Tests de refus WA-R1 à WA-R8 verts
- [ ] Pureté du domaine (`Net::HTTP` compris), rubocop, tests, parcours système, brakeman : `bin/ci` local écrit dans la PR (ADR-0069)
- [ ] Revue `security-reviewer` sur le diff final (route entrante, service tiers, policy)
- [ ] Captures 390 px et ordinateur : profil (3 états de la ligne, fenêtre), formulaire d'annonce (case, décompte, plafond), « Mes annonces » (bilan)
- [ ] ADR-0102 et UDR-0122/0123 « Accepté » ; ADR-0045 annoté de l'amendement ; index régénérés par `script/docs/build_index` au commit de clôture
- [ ] `journal.md` complété
