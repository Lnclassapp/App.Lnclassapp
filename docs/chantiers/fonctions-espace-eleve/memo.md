# Memo — Fonctions de l'espace élève

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage — grill en cours (2026-10-02) |
| **Ouvert le** | 2026-10-02 |
| **Branche** | `ccr-93a43a40-3h3ty4` *(repartie de `Develop` le 2026-10-02, après la fusion d'`interface-epuree` phase 1)* |
| **Programme** | — *(né du grill d'`interface-epuree`, Q8 ; probablement à découper en plusieurs chantiers au grill)* |

---

## Le problème

La maquette V2 de l'accueil élève, validée par le porteur le 2026-10-02, montre six fonctions qui n'existent pas encore dans l'application :

1. **Échéances et retards** : un exercice assigné a une date limite (« À rendre demain »), la liste « À faire ensuite » est triée par échéance, et un point ambre signale une matière où un exercice est en retard.
2. **Durée d'un exercice** : la carte du haut annonce le temps estimé (« 15 min »).
3. **Paiement et abonnement** : une case « Paiement » dans la grille, et une annonce « Ton abonnement se termine dans 7 jours, renouvelle-le par Mobile Money ».
4. **Annonces signées** : un carrousel de messages signés (la direction, un enseignant, l'équipe Lnclass). Un message officiel ne se ferme pas, les autres se masquent avec « Annuler » pendant 5 secondes.
5. **Lecture audio** : chaque annonce peut être écoutée, et le bouton s'atténue une fois le message écouté.
6. **Aide** : un bouton « Besoin d'aide ? » dans l'en-tête de l'accueil, vers un support. Aucune page d'aide n'existe ; ajoutée le 2026-10-02 à la demande du porteur, après l'UDR-0058 d'`interface-epuree`.

Le chantier `interface-epuree` a décidé (grill, Q8) de n'épurer que l'existant : ces six éléments en sont retirés et regroupés ici.

## Pour qui

- **Élève** : il voit ses échéances, la durée d'un exercice, son abonnement, les annonces, et peut les écouter.
- **Enseignant** : il fixe les échéances en assignant, et signe ses annonces.
- **Direction** : elle signe les annonces officielles de son établissement.
- **Équipe** : elle gère les abonnements et signe les annonces « Lnclass ».

*Première version : qui fait quoi exactement se tranche au grill.*

## Pourquoi maintenant

L'accueil élève épuré sera livré sans ces fonctions. Tant qu'elles manquent, la carte du haut ne peut pas dire « à rendre demain », la grille n'a pas de case Paiement et il n'y a pas d'annonces. Ce chantier rend la V2 complète.

*À confirmer au grill : l'ordre entre les cinq fonctions, et si l'une d'elles est urgente.*

## Hors périmètre

*Première version, à durcir pendant le grill.*

- L'épuration des écrans élève : chantier `interface-epuree`.
- La messagerie de classe et le temps réel, retirés du plan le 2026-09-22.
- Tout autre moyen de paiement que Mobile Money, tant que le grill n'en décide pas autrement.

## Points de vigilance avant le grill

- **Paiement** : un paywall « Prépa BAC » a été **écarté et retiré du plan le 2026-09-22** (feuille de route de `refonte-application`). Réintroduire un paiement revient sur une décision du porteur : le grill doit le confirmer explicitement, et le paiement demandera un nouveau contexte métier, donc une décision d'architecture.
- **Annonces** : elles sont déjà prévues comme vague V6 du programme `refonte-application`, avec une décision acceptée sur la publication programmée et l'audience. Ce chantier doit s'y raccrocher plutôt que la doubler.
- **Six fonctions, quatre parties de l'application ou plus** (les classes pour les échéances, le contenu pour la durée, la communication pour les annonces et l'audio, un domaine nouveau pour le paiement). Un seul chantier risque d'être trop gros : le grill dira s'il faut un programme.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Q1 — Le paiement, retiré du plan le 2026-09-22, revient-il ? | **Oui**, un vrai abonnement payé par Mobile Money | Revient sur la décision du 2026-09-22 (à tracer). Nouveau contexte métier (abonnement, opérateur, reçus) : un ADR est obligatoire, et le chantier dépasse un seul cycle |
| Q2 — Le paiement dans ce chantier ou à part ? | **À part** : un chantier `abonnement-mobile-money`, avec son ADR | Ce chantier traite cinq fonctions (échéances, durée, annonces, audio, aide). La case « Paiement » et l'annonce d'abonnement restent masquées ici et passent au nouveau chantier |
| Q3 — Les annonces (et l'audio) ici, ou à part ? Rien n'est construit ; l'ADR-0045 ne prévoit que l'équipe comme autrice | **À part** : un chantier `annonces`, qui étend l'ADR-0045 à la direction et aux enseignants, avec la lecture audio | Ce chantier se réduit à **trois fonctions** : échéances, durée, aide. Le carrousel d'annonces et le bouton d'écoute restent masqués ici |
| Q4 — Où mène « Besoin d'aide ? » ? | Une **fenêtre** sur ordinateur, une **carte qui monte du bas** (25 % de la hauteur) sur téléphone, avec trois options : **FAQ**, **WhatsApp**, **contact direct**. Le porteur fournira un exemple de la carte | Trois cibles à construire ou à fournir : une page FAQ (contenu à écrire), un numéro WhatsApp du support, un contact direct (à préciser à la réception de l'exemple). Une UDR pour la carte d'aide ; motif « bottom sheet » nouveau sur téléphone |
| Q5 — Après la date limite, l'exercice ? | **Toujours faisable, marqué « En retard »** (point ambre sur la matière) ; l'enseignant voit qu'il a été rendu après la date | Aucune fermeture automatique, aucun job de clôture lié à l'échéance. L'échéance est une donnée d'affichage et de tri ; « rendu en retard » se calcule en comparant la date de la session terminée à l'échéance |
| Q6 — Sur quoi fixer une échéance ? Obligatoire ? | **L'enseignant n'assigne qu'un exercice**, « pour la séance prochaine », pas pour une date choisie. **Cours et fiches ne sont plus assignables** : retirer leurs boutons d'assignation. L'échéance se **déduit de l'emploi du temps** de l'enseignant pour la classe, demandé lors des premières assignations. Échéance facultative | Change le domaine : `Entities::Classroom::Assignable::TYPES` passe à `Exercise` seul (ADR à écrire, UDR des écrans cours et fiche à amender). Nouveau : un emploi du temps enseignant × classe (jours et heures de séance), une échéance calculée = la prochaine séance après l'assignation. À trancher : le sort des assignations de cours et de fiches déjà en base |
| Q7 — Que deviennent les assignations de cours et de fiches déjà faites ? | **Il n'y en a pas pour le moment** (porteur) | Pas de conversion de données. La migration qui restreint `assignable_type` à `Exercise` vérifie quand même la base au déploiement et échoue s'il en trouve, plutôt que de les perdre |
| Q8 — Quel emploi du temps demande-t-on ? | **Les jours de la semaine** où l'enseignant voit la classe (ex. lundi et jeudi), cochés lors des premières assignations, modifiables ensuite | Nouvelle donnée : jours de séance par enseignant × classe (pas d'heures). Échéance = le prochain de ces jours strictement après l'assignation ; sans jours renseignés, pas d'échéance. À trancher : vacances et jours fériés |

## Cas limites identifiés

- …

## Questions encore ouvertes

- Ordre de priorité entre les six fonctions.
- Aide : une page d'aide, un lien WhatsApp (chantier `canal-whatsapp`), ou un contact ?
- Le paiement revient-il dans le plan, alors qu'il en a été retiré le 2026-09-22 ?
- Les annonces : ce chantier, ou la vague V6 déjà prévue ?
