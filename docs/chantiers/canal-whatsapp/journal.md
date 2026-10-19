# Journal — Canal WhatsApp pour joindre les utilisateurs hors de l'application

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-16 | Cadrage repris : grill écrit (Q1 à Q12) avec recommandations, PRD, plan, ADR-0102, UDR-0122 à 0124, tous **Proposé** | Le porteur a demandé de lancer les vagues V2 à V6 ; le dossier était resté au gabarit depuis la PR #70 | ADR-0102 (Proposé) |
| 2026-10-16 | Ce chantier pose le port d'envoi commun, pas `verification-whatsapp` | `verification-whatsapp` est au backlog ; la feuille de route prévoit ce cas (fiche V6) | ADR-0102 §4.1 |
| 2026-10-16 | Recommandé : API Cloud de Meta en direct, n8n possible derrière le même port | n8n n'est pas un fournisseur ; il ajoute un serveur, un secret et un lieu de transit des numéros | ADR-0102 §3, en attente de Q1 |
| 2026-10-16 | Recommandé : récupération du PIN par WhatsApp **gelée** (Lot D) jusqu'à la vérification du numéro | Un code envoyé à un numéro jamais prouvé donne le compte à qui reçoit ce numéro | ADR-0102 §4.7, en attente de Q9 |
| 2026-10-16 | L'accord garde l'empreinte du numéro accepté au lieu d'être révoqué par `ChangeOwnContact` | Pas d'écriture croisée `identity` → `communication` ; un changement de numéro invalide l'accord de lui-même | ADR-0102 §4.2 |

## Ce qui a dérapé

- **La PR #70 est fusionnée depuis le 2026-09-28** (`3b3aad37`), mais la feuille de route (§1, fiche V6, table des chantiers) la dit encore « non fusionnée ». Elle ne contenait que les 4 fichiers au gabarit et un memo en brouillon. À corriger dans la feuille de route au prochain passage (ce cadrage n'y touche pas).
- Le cadrage précédent avait noté le grill comme « non commencé » pendant 18 jours : les questions Q11 à Q14 de la feuille de route n'avaient jamais été posées au porteur.

## Ce qu'on a appris sur la codebase

- WhatsApp n'existe dans le code que comme **liens sortants** `wa.me` : `ShareHelper#whatsapp_share_url` (partage de classe, d'établissement, parrainage, « Inviter mon enseignant ») et `SupportHelper#whatsapp_contact` (carte d'aide, numéro de `config/support.yml`). `ShareChannel` compte les partages par canal.
- **Aucun client HTTP sortant** dans `app/` ni `lib/`, aucune gemme HTTP, ni WebMock ni VCR : le Lot 0 injecte le transport dans l'adaptateur pour le tester.
- **Aucun n8n, aucun webhook** dans le code ; n8n n'apparaît que dans l'ADR-0063 et le journal de `croissance-parrainage`.
- `users` n'a **ni date de naissance ni consentement** : l'âge d'un élève est inconnu (la politique de confidentialité le dit, §3).
- Les routes sont découpées par contexte (`config/routes/*.rb`) : le Lot 0 détient `communication.rb` et `identity.rb`.
- Les annonces passent par trois chemins de publication (`CreateMessage`, `UpdateMessage`, `PublishScheduledMessages`) : l'avis doit partir des trois.
- Le numéro du support (`0584258085`) est utilisé dans l'application WhatsApp : il ne peut pas devenir le numéro d'envoi de l'API sans perdre l'application.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Récupération du PIN par WhatsApp (Lot D, UDR-0124, amendement de l'ADR-0032) | Numéro non prouvé | `verification-whatsapp`, puis dégel du Lot D |
| Avis déclenchés par l'enseignant | Coût, mineurs (Q5) | Drapeau `whatsapp.authors`, sans code |
| Avis aux élèves | Avis des juristes (Q4) | Drapeau `whatsapp.students`, sans code |
| Envoi des codes d'établissement (ADR-0057) | Hors périmètre | À ouvrir après ce chantier, sur le même port |
| Feuille de route : « PR #70 non fusionnée » | Ce cadrage ne touche pas aux index ni à la feuille de route | Prochaine mise à jour de la feuille de route |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | ADR-0102 *(Proposé)* |
| **UDR produits** | UDR-0122, UDR-0123, UDR-0124 *(Proposé ; 0124 gelée)* |
