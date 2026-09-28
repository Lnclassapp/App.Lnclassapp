# Memo — Cycles en boutons radio

| | |
|---|---|
| **Type de cycle** | feature (léger : une vue par formulaire, aucun changement de domaine) |
| **Statut** | livré |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `feature/cycles-en-radio` |
| **Programme** | — |

---

## Le problème

Le cycle d'un niveau et celui d'un établissement se saisissent dans une liste déroulante, alors qu'il n'y a que deux valeurs possibles. Il faut ouvrir la liste pour voir les choix ; à la création d'un niveau, la liste part sur « Choisir un cycle » et un oubli revient en 422.

Le porteur, le 2026-09-28 : « remplace la liste déroulante des cycles par des boutons radio avec 1er cycle par défaut ».

## Pour qui

L'équipe (Team), qui crée et modifie les niveaux et modifie les établissements, au bureau comme au téléphone.

## Pourquoi maintenant

Demande du porteur du 2026-09-28, avant la mise en production de la V1.

## Périmètre

Les formulaires qui **saisissent** un cycle, recensés par `grep -rn "cycle" app/views` (seuls deux `ui_field … :cycle, as: :select`) :

| Formulaire | Valeurs (domaine) | Libellés | Valeur cochée |
|---|---|---|---|
| Niveau — `teams/levels/_form` (création et modification) | `first`, `second` | Premier cycle, Second cycle | création : `first` ; modification : la valeur enregistrée |
| Établissement — `teams/schools/_form` (modification seule, UDR-0036) | `first`, `both` | Premier cycle, Premier et second cycles | la valeur enregistrée |

## Hors périmètre

- Le filtre « Tous les cycles » de la liste des établissements : c'est un filtre avec une option « tous », il reste une liste déroulante.
- Le domaine : mêmes valeurs soumises (`level[cycle]`, `school[cycle]`), mêmes validations, mêmes messages.
- Les autres listes déroulantes (type, statut, DRENA, niveau d'un cours…).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| « 1er cycle par défaut » pour un établissement ? | Aucun écran ne crée d'établissement (import seul, UDR-0036) : le formulaire ne sert qu'à modifier, et un établissement a toujours un cycle (colonne `NOT NULL`, défaut `both`). | La valeur équivalente du domaine est `first` (« Premier cycle ») ; elle ne s'applique qu'à la création, donc seulement au niveau. L'établissement coche sa valeur enregistrée. |
| Où poser le défaut du niveau ? | Dans `new` du contrôleur, comme la position suivante déjà proposée ; la vue coche ce que porte le formulaire. | Aucune règle dans la vue ni dans le domaine ; une modale re-rendue en 422 garde la saisie. |
| Un composant radio existe-t-il ? | Non : Genre (inscriptions), Catégorie de matière et Rôle d'invitation écrivent chacun leurs radios à la main. | Nouveau composant `ui_radio_group` dans le design system (UDR-0005), visible sur `/design`. Les radios existantes ne sont pas migrées ici. |
| L'invite « Choisir un cycle » garde-t-elle un sens ? | Non : un bouton est toujours coché. | Clé `teams.levels.form.cycle_prompt` retirée. |
| Trois selects de front (type, cycle, statut) dans la modale d'établissement ? | Deux libellés longs ne tiennent pas dans un tiers de colonne. | Type et statut passent sur deux colonnes ; le cycle prend une ligne entière, ses deux options côte à côte dès `sm`. |

## Cas limites identifiés

- Saisie forcée sans cycle (requête écrite à la main) : 422, erreur sous le groupe, aucun bouton coché.
- Téléphone (390 px) : les options s'empilent, chacune sur toute la largeur, cible de 48 px, la page ne défile pas en largeur.
- Clavier : Tab entre dans le groupe sur l'option cochée, les flèches changent le choix.

## Questions encore ouvertes

- Aucune.
