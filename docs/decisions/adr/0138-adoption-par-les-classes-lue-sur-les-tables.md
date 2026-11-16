# ADR-0138 : L'adoption par les classes se lit en direct sur les tables existantes
<!-- index
titre: Adoption par les classes, lue sur les tables
statut: Accepté
problematique: comment savoir où la chaîne enseignant → classe → élèves casse, sans table ni traceur
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-16 |
| **Chantier** | `docs/chantiers/acquisition-classes` |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

En novembre 2026, Lnclass compte 7 élèves. La croissance passe par la classe : un enseignant qui l'adopte amène 30 à 80 élèves. La page Croissance (ADR-0063, UDR-0050, UDR-0175) mesure le parrainage entre enseignants et l'entonnoir des élèves. En revanche, **rien ne relie un enseignant à une classe qui travaille**.

Les faits du produit rendent cette lecture moins évidente qu'il n'y paraît :
- l'enseignant ne crée pas de classe, il en coche une que l'équipe ou la direction a ouverte ;
- le code existe avant lui et appartient à la classe ;
- un élève peut entrer sans code, par la cascade (ADR-0085) ;
- le partage d'un code n'est pas enregistré (ADR-0049).

Sans définitions fixes, chaque chantier recompterait « enseignant actif » ou « classe qui s'en sert » à sa façon. La page Croissance le fait déjà : son « enseignant actif » désigne tout enseignant rattaché à un établissement.

## 2. Moteurs de décision

1. Désigner le goulot d'acquisition avec les données déjà en base, cette semaine.
2. Pas de nouvelle table, pas de traceur, pas de bandeau de cookies (ADR-0049, ADR-0062).
3. Des définitions réutilisables telles quelles par une future section de la page Croissance et par les lots d'action.
4. Exécutable en production sans risque : lecture seule, charge bornée, comptes seulement.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A. Requête de lecture sur les tables actuelles, tâche `READ ONLY` | Rien à migrer. Donne un verdict dès la première exécution, sur tout l'historique. Précédent : `entonnoir:brut`. | Ne voit ni le partage d'un code ni une déclaration retirée. 2b et 3 ne se séparent que par un indice. |
| B. Table d'événements (partage du code, affichage du code, écran « Aucune classe ouverte ») | Distingue 2b de 3 directement | Nouvelle table et traceur, contraires à ADR-0049. Aucun historique : il faut attendre des semaines avec 7 élèves. |
| C. Colonne « enseignant qui a donné le code » sur l'adhésion | Attribue l'élève à l'enseignant | Change le contrat de l'inscription de l'élève, tout juste retravaillée. Le code est partagé entre enseignants. |

## 4. Décision

**Option A.** La « classe adoptée » et l'entonnoir enseignant E1 à E6 sont des définitions métier fixes (PRD du chantier, §3.1). Ils sont lus en direct par une requête bornée du contexte `classroom`, qui consulte `identity`, `school` et `crm` en lecture seule. La règle qui désigne le goulot est une entité pure du domaine, avec ses seuils en constantes.

Une classe est **adoptée** quand au moins un enseignant l'a cochée et qu'au moins **5 de ses élèves** ont commencé un exercice.

## 5. Conséquences

### 🟢 Positives

- Un verdict en une commande, sur tout l'historique, sans attendre.
- Toute future section de la page Croissance ou tout tableau du CRM réutilise les mêmes définitions.
- Aucun risque pour la base de production : lecture seule et `statement_timeout`.

### 🔴 Coûts consentis

- 2b (code jamais donné) et 3 (code ignoré) ne se distinguent que par l'indice « devoir donné à une classe vide ». Si l'indice ne tranche pas, l'option B revient, avec son propre ADR.
- Une déclaration de classe retirée et la première voie d'une ré-adhésion sont invisibles.
- Une sixième lecture de la base pour l'équipe, à maintenir quand le schéma de `classroom_students`, `teacher_classrooms` ou `crm_accounts` change.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/classroom/adoption_verdict.rb : Ruby pur, seuils en constantes, une méthode par branche
# app/infrastructure/queries/classroom/class_adoption_query.rb : 4 lectures, sous-requêtes scalaires sur index
# lib/tasks/entonnoir_classes.rake : SET TRANSACTION READ ONLY ; SET LOCAL statement_timeout = '60s'
```

## 7. Comment vérifier que la décision est respectée

- `test/tasks/entonnoir_classes_task_test.rb` : une écriture tentée dans la transaction lève `read-only transaction`, et la sortie ne contient ni nom, ni numéro, ni identifiant public.
- `git diff --stat db/` reste vide pour le chantier.
- Toute nouvelle mesure de l'adoption par les classes appelle `ClassAdoptionQuery` ou en réutilise les définitions. Une redéfinition se voit en revue.
