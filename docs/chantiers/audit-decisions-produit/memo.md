# Memo — Décisions produit de l'audit du 8 novembre 2026

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-08 |
| **Branche** | `fix/audit-decisions-produit` |
| **Programme** | — |

---

## Le problème

L'audit du 8/11 (`docs/audits/2026-11-08-bugs-code-mort.md`, `…-optimisations-ux-wording.md`) a laissé onze points « à confirmer ». Le porteur a tranché ; ce chantier applique ses réponses.

## Pour qui

Direction d'école, enseignant, équipe, élève (annonces, catalogue, classes).

## Décisions du porteur et ce qui change

| Réf. | Décision | Application |
|---|---|---|
| B-011 | La direction lit, en lecture seule, la fiche d'un élève d'une classe de SON école | `ReadClassroomPolicy` : branche direction (même `school_id`) ; lien du nom depuis sa page de classe ; sur la fiche : retour vers sa page, ni « Gérer », ni liens vers les pages de l'enseignant |
| B-012 | Une liste vide de jours de séance est refusée | `SessionDaysInput` : `:blank` ; message « Cochez au moins un jour. » |
| B-013 | Un enseignant se retire d'une classe archivée | `WithdrawTeachingPolicy` (se déclarer garde `DeclareTeachingPolicy`) |
| B-015 | Valider une demande d'adhésion exige école active et départ fermé | `ReviewJoinRequest` (valider seulement ; refuser reste permis) : conflit `school_inactive` / `departure_open`, messages dédiés |
| B-023 | **Aucun changement** : bascule stricte au 1er septembre (ADR-0041) | Noté ici ; rien dans le code |
| B-029 | Retirer une annonce exige programmée ou publiée | `WithdrawPolicy` : un brouillon répond `:conflict` (404 côté écran) |
| B-032 | Les fichiers d'une annonce suivent les droits de l'annonce | `ReadFilePolicy` : l'équipe passe par `moderatable_by?` et ne lit que programmée/publiée d'un autre auteur |
| B-035 | Un élève sans classe active voit les annonces de son école d'inscription | `ReadableMessages#reader_for` : repli sur l'école de sa dernière inscription (annonces par rôle, pas celles d'une classe) |
| B-046 | La leçon par son adresse se limite aux matières de l'enseignant | `ReadOwnMaterialPolicy` sur la leçon, son ancienne fiche, la feuille et l'ancienne adresse d'une notion ; direction, équipe, élève inchangés. Amende UDR-0077 §4 (UDR « audit-decisions-produit ») |
| O-X04 | **Pas de cache** 7/30 jours du Pilotage (ADR-0062 : données fraîches) | Rien à retirer : le code ne mettait déjà en cache que `year` (5 min). Pas d'optimisation de requête sans mesure : voir le journal |
| O-C02 | « Voir plus » des longues listes du catalogue | Leçons de la vue matière (ordinateur, élève) : page suivante au défilement ou lien « Afficher plus de fiches de cours » ; le catalogue et la vue téléphone paginaient déjà |

## Hors périmètre

- Index d'`exercise_sessions` / requêtes du Pilotage (O-X04 sans cache), à ouvrir en `/optimize` avec une mesure.
- Les exercices et sessions lus par un enseignant hors de ses matières (`assessment/*`) : seules les leçons (cours, fiche, feuille, notion) sont limitées.

## Cas limites identifiés

- Un enseignant sans matière dans l'établissement courant : 404 sur toute leçon (comme le catalogue vide).
- Direction d'une autre école ou sans école : 403 sur la fiche élève.
- Un brouillon d'annonce : plus retirable ; son auteur le supprime ou le publie comme avant.

## Questions encore ouvertes

Aucune ; voir `journal.md` (`## À trancher`).
