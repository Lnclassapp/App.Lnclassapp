# Memo — Canal WhatsApp pour joindre les utilisateurs hors de l'application

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `feature/canal-whatsapp` |
| **Programme** | — *(touche les vagues V6 « annonces » et V1 « récupération du PIN » du programme `refonte-application`, sans en être une)* |

---

## Le problème

Lnclass ne peut joindre personne en dehors de l'application :

- **Annonces** : une annonce n'est vue qu'à la prochaine visite. Les notifications poussées et le SMS sont explicitement hors du périmètre des annonces.
- **Récupération du PIN** : un élève qui a oublié son PIN dépend d'un enseignant ou de l'équipe, qui lui dicte un code de vive voix. Le SMS était prévu puis reporté, faute de fournisseur choisi.

Or chaque compte a déjà un numéro de mobile ivoirien unique et vérifié dans son format, et WhatsApp est le canal que ce public lit réellement.

## Pour qui

- **Élèves** : recevoir une annonce qui les concerne, et peut-être leur code de récupération.
- **Enseignants** : recevoir les annonces de l'équipe ou de leur direction.
- **Direction** (`school_admin`) et **équipe** (`team`) : ceux qui publient, et qui voudraient savoir que l'annonce a été reçue.

## Pourquoi maintenant

*À établir pendant le grill* : les annonces (vague V6) ne sont pas encore construites, et la récupération assistée du PIN vient d'être livrée.

## Hors périmètre

*Première version, à durcir pendant le grill.*

- Une messagerie bidirectionnelle (répondre à une annonce, discuter avec un enseignant) ou une boîte de réception partagée.
- Le SMS, les notifications poussées du navigateur, l'e-mail.
- Les campagnes marketing ou tout message non lié à la scolarité.

## Ce que le grill a révélé

> Rempli au fil du grill, une question à la fois.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| | | |

## Cas limites identifiés

- …

## Questions encore ouvertes

- …
