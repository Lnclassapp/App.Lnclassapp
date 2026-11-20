# Journal — Partage de la classe et mesure du k-factor élève

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-20 | Attribution dans une table à part, écrite une fois ; `joined_via` inchangé | `joined_via` est réécrit au retour dans une classe et lu par l'entonnoir | ADR-XXXX-attribution-des-inscriptions-eleves |
| 2026-11-20 | Invitant désigné par un code opaque de 8 caractères, créé au premier envoi (POST) | Ne pas faire circuler l'identifiant public d'un élève dans WhatsApp | ADR-XXXX-attribution-des-inscriptions-eleves |
| 2026-11-20 | Le cadrage enchaîne sur l'exécution sans demander « Je lance les lots ? » (étape 6 de la skill `feature`) | Le porteur a demandé la livraison (PR prête) et le contrat de session interdit de finir sur une question | non |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-20 · partage-classe-k-factor · Quel k afficher : invitations seules, ou QR + invitations comme le playbook ? — appliqué : (QR + invitation) ÷ inscrits, colonnes séparées ; autres : invitation ÷ inscrits ; recommandé : appliqué (le playbook fixe le seuil 0,5 sur cette définition)
- [ ] 2026-11-20 · partage-classe-k-factor · L'invitation de l'enseignant reste-t-elle sur l'accueil quand la classe a déjà un enseignant ? — appliqué : non, seulement si la classe n'a aucun enseignant (règle Wave « une porte par écran ») ; autres : les deux bannières ; recommandé : appliqué
- [ ] 2026-11-20 · partage-classe-k-factor · L'enseignant et la direction voient-ils le k de leurs classes ? — appliqué : non (équipe seulement, V1) ; autres : un chiffre par classe sur la page de la classe ; recommandé : appliqué, à rouvrir après le premier lancement
- [ ] 2026-11-20 · partage-classe-k-factor lot E · « Mesuré depuis le » : première attribution de toute la base, ou de la période affichée ? — appliqué : de toute la base (date de début de la mesure, stable d'une période à l'autre) ; autres : première attribution de la période ; recommandé : appliqué

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Lot 0 : `db/schema.rb` régénéré par un PostgreSQL local d'une autre version réécrit toutes les contraintes CHECK (`::character varying::text`) ; le lot n'ajoute à la main que ses deux tables, ses clés étrangères et la version.
- Lot 0 : `Shared::Result` s'écrit `::Shared::Result` dans `Repositories::Classroom` (sinon `Repositories::Shared`).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
