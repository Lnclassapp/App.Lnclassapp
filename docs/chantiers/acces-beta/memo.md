# Memo — Accès complet gratuit pendant la bêta

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-11-12 |
| **Branche** | `feature/acces-beta` |
| **Programme** | — |

---

## Le problème

Lnclass cherche des bêta-testeurs. Or l'élève voit dès l'accueil un bandeau qui compte ses jours gratuits et l'invite à s'abonner, et dès le 16 novembre 2026 (7 jours après la mise en ligne) il ne peut plus démarrer un exercice ni vérifier un entraînement sans carte d'abonnement. On demande à des testeurs d'essayer l'application tout en leur fermant la porte au bout d'une semaine.

## Pour qui

L'élève, du premier jour au dernier jour de la bêta. Décision du porteur (non rouverte) : pendant la bêta, l'élève a l'accès complet gratuit.

## Pourquoi maintenant

Le blocage tombe le 16 novembre 2026, dans 4 jours ; le recrutement des bêta-testeurs est en cours.

## Hors périmètre

- Supprimer l'offre, les cartes, les points relais ou la page Mon abonnement : tout reste en place, prêt à être réactivé.
- Les écrans de l'équipe (caisse, lots de cartes) : l'équipe continue de préparer la vente.
- Parent, SchoolStaff, enseignant : ils n'étaient jamais bloqués ni invités à s'abonner ; rien ne change pour eux.
- Fixer la date de fin de la bêta : décision commerciale à venir (une ligne à poser).
- Les conditions générales de vente (page publique) : elles décrivent l'offre, pas l'état de la bêta.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Supprimer le bandeau de la vue suffit-il ? | Non : le blocage est calculé à part et refuse le démarrage d'exercice et l'entraînement de notion. | Un seul réglage doit couper les deux ; le bandeau se masque en lisant le même état. |
| Un élève qui a déjà activé une carte, que voit-il pendant la bêta ? | Il reste abonné, avec sa date. | L'état « abonné » passe avant la bêta : rien n'est perdu, la page affiche toujours sa date. |
| Quand la bêta ferme, un élève ancien est-il bloqué d'un coup ? | Oui, avec la règle d'origine. Porteur : non, la mise en ligne de l'offre est reportée à la fin de la bêta. | Le réglage est une date de fin ; les 7 jours gratuits partent d'elle. |
| Un autre écran élève pousse-t-il vers l'abonnement ? | Le menu élève n'a pas de lien ; l'écran de blocage n'apparaît que sur refus, qui n'arrive plus ; Mon abonnement reste joignable à la main et affichait « Il te reste N jours ». | Mon abonnement affiche un état « bêta » sans compte à rebours ; la saisie de code reste possible. |
| Enseignant, direction, équipe : changent-ils ? | Non, ils restent « sans restriction ». | Aucun travail ; écrit dans Hors périmètre. |
| Un réglage par environnement (variable) ou dans le code ? | Le blocage est une règle du domaine, en Ruby pur ; une variable obligerait le domaine à lire l'environnement ou à câbler cinq contrôleurs. | Une constante de l'offre, `BETA_ENDS_ON`, à côté des 7 jours gratuits (ADR). |

## Cas limites identifiés

- Élève abonné dont la carte expire pendant la bêta : il repasse en « bêta », pas en « bloqué ».
- Élève créé avant la mise en ligne : « bêta », sans jours comptés.
- Compte inconnu ou non-élève : inchangé (« sans restriction »).

## Questions encore ouvertes

- Voir `journal.md` § À trancher.
