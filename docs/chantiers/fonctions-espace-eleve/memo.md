# Memo — Fonctions de l'espace élève

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage — grill non commencé |
| **Ouvert le** | 2026-10-02 |
| **Branche** | `ccr-93a43a40-3h3ty4` *(branche de session ; à renommer `feature/fonctions-espace-eleve` si le porteur le souhaite)* |
| **Programme** | — *(né du grill d'`interface-epuree`, Q8 ; probablement à découper en plusieurs chantiers au grill)* |

---

## Le problème

La maquette V2 de l'accueil élève, validée par le porteur le 2026-10-02, montre cinq fonctions qui n'existent pas encore dans l'application :

1. **Échéances et retards** : un exercice assigné a une date limite (« À rendre demain »), la liste « À faire ensuite » est triée par échéance, et un point ambre signale une matière où un exercice est en retard.
2. **Durée d'un exercice** : la carte du haut annonce le temps estimé (« 15 min »).
3. **Paiement et abonnement** : une case « Paiement » dans la grille, et une annonce « Ton abonnement se termine dans 7 jours, renouvelle-le par Mobile Money ».
4. **Annonces signées** : un carrousel de messages signés (la direction, un enseignant, l'équipe Lnclass). Un message officiel ne se ferme pas, les autres se masquent avec « Annuler » pendant 5 secondes.
5. **Lecture audio** : chaque annonce peut être écoutée, et le bouton s'atténue une fois le message écouté.

Le chantier `interface-epuree` a décidé (grill, Q8) de n'épurer que l'existant : ces cinq éléments en sont retirés et regroupés ici.

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
- **Cinq fonctions, quatre parties de l'application** (les classes pour les échéances, le contenu pour la durée, la communication pour les annonces et l'audio, un domaine nouveau pour le paiement). Un seul chantier risque d'être trop gros : le grill dira s'il faut un programme.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| | | |

## Cas limites identifiés

- …

## Questions encore ouvertes

- Ordre de priorité entre les cinq fonctions.
- Le paiement revient-il dans le plan, alors qu'il en a été retiré le 2026-09-22 ?
- Les annonces : ce chantier, ou la vague V6 déjà prévue ?
