# Memo — Canal WhatsApp pour joindre les utilisateurs hors de l'application

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `feature/canal-whatsapp` |
| **Programme** | `refonte-application` — **V6**, après le chantier `annonces` (rattachement du 2026-09-28, feuille de route §2 et fiche V6) |

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

**Ce n'est pas urgent** : la feuille de route place ce chantier en V6, **après** le chantier `annonces`, qui n'existe pas encore. Le cadrer maintenant sert à trancher tôt les décisions longues à obtenir (fournisseur, approbation des modèles de message par Meta, consentement des mineurs), pas à livrer vite.

## Déjà décidé ailleurs

> Ces points viennent de la feuille de route du programme et d'un chantier voisin. Le grill ne les rouvre pas, il en tire les conséquences.

- **Rattachement** : V6, après `annonces`. Ce chantier dépend donc des annonces livrées, et de la V2 pour l'audience « direction ».
- **Port d'envoi commun** avec le chantier `verification-whatsapp` (vérification du numéro à l'inscription, au backlog) : celui des deux qui démarre en premier pose le port d'envoi du contexte `communication` et l'adaptateur n8n ; l'autre les réutilise.
- **Une seule décision** pour les deux chantiers sur le fournisseur derrière n8n, le coût par message et qui le paie, et la sécurité du hook (signature dans les deux sens).
- **Il faudra un ADR** pour le canal et un **amendement de l'ADR-0045** (qui exclut aujourd'hui les notifications hors de l'application) ; un amendement de l'ADR-0032 si le code de récupération du PIN passe par WhatsApp.
- **Questions déjà posées au porteur** dans la feuille de route : le message porte-t-il l'annonce entière ou un avis avec un lien (Q11) ; fournisseur, coût et payeur (Q13) ; le code du PIN dans ce chantier ou plus tard (Q14).

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
