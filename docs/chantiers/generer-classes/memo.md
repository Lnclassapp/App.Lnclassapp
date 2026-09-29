# Memo — Générer les classes manquantes des établissements

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `feature/generer-classes` |
| **Programme** | — |

---

## Le problème

En production, le 2026-09-28, l'équipe a importé 3 851 établissements **avant** d'avoir créé les niveaux, les séries et les matières. Les classes d'un établissement ne naissent qu'à son import (ADR-0030) : faute de référentiel, le barème n'a rien trouvé à générer, et ces établissements n'ont aucune classe. Un enseignant qui s'y inscrit ne trouve rien à déclarer, un élève n'a aucun code pour rejoindre une classe.

Réimporter le même fichier ne répare rien : un établissement déjà en base est un doublon, ignoré et jamais mis à jour (ADR-0039). Ajouter les classes une à une, à la main, représente environ 79 000 classes.

## Pour qui

L'équipe (Team), sur l'écran Établissements, une fois le référentiel (niveaux, séries, liaisons niveau/série) en place.

## Pourquoi maintenant

La production est ouverte depuis le 2026-09-27 et la rentrée est en cours : sans classes, aucun enseignant ni élève des 3 851 établissements ne peut commencer. Aucun contournement raisonnable n'existe.

## Hors périmètre

- Compléter un établissement qui a **déjà** au moins une classe de l'année (par exemple un niveau sauté à l'import) : il n'est jamais modifié. Une classe manquante isolée s'ajoute par « Ajouter une classe ».
- Régénérer les classes d'un établissement dont le type ou le cycle a changé : modifier un établissement ne touche toujours aucune classe (UDR-0036).
- Générer les classes d'une **autre** année scolaire que l'année en cours (passage d'année, ADR-0041).
- Générer pour un seul établissement depuis sa fiche.
- Les établissements désactivés.
- Supprimer ou renommer des classes existantes.
- Toute notification temps réel (WebSocket) : le suivi reprend celui des imports, rechargé toutes les 3 s.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| « Sans classe », c'est sans classe du tout, ou sans classe de l'année en cours ? | De l'année en cours (ADR-0041 : une classe appartient à une année). Une classe archivée de l'année compte : l'établissement en a une. | Un établissement est candidat s'il n'a **aucune** classe de l'année, quel que soit leur statut. |
| Un établissement désactivé reçoit-il ses classes ? | Non : il n'est plus proposé à la création de classe ni à l'inscription (UDR-0036, décision du 2026-09-27). Un brouillon, oui : l'import lui aurait donné ses classes. | Candidats : statut `active` ou `draft`. La modale le dit. |
| Relancer, ou cliquer deux fois, crée-t-il des doublons ? | Non : un établissement doté a des classes, il n'est plus candidat. Deux lancements simultanés sont refusés. | Idempotence par construction ; un seul rapport en cours (index unique partiel des imports), second clic → « déjà en cours ». |
| Que fait un établissement pour lequel le barème ne donne rien (référentiel encore vide) ? | Il reste sans classe, compté à part, et sera repris au prochain lancement. | Compteur « Sans classe à générer » ; les niveaux et séries sautés sont comptés comme à l'import. |
| 3 900 établissements et 79 000 classes dans une seule transaction ? | Non : verrous longs, et un refus annulerait tout. | Lots de 200 établissements par transaction ; un lot refusé est rejoué établissement par établissement, comme l'import. |
| Où l'équipe voit-elle le résultat, et faut-il un nouvel écran ? | Le moteur d'import ne convient pas (il lit un fichier JSON), mais son **rapport** convient : statut, progression, compteurs, détails, suivi rechargé, un seul en cours par type, reprise des rapports bloqués. | Le rapport est un `import_report` d'un nouveau `kind` `classrooms`, sans fichier ; aucun nouvel écran (ADR-0056). |
| Une classe ajoutée à la main pendant la génération, dans un établissement candidat ? | Rare ; si le nom entre en collision, le lot est rejoué et cet établissement passe en erreur ; sinon il reçoit ses classes en plus. | Les candidats sont relus lot par lot, juste avant l'écriture ; le cas est accepté. |
| Un import d'établissements qui tourne en même temps ? | Ses établissements naissent avec leurs classes dans la même transaction : jamais candidats. | Pas de verrou entre les deux types. |
| Qui peut lancer ? | La même règle que l'import d'établissements : l'équipe. | `School::ManageSchoolPolicy`, revérifiée au démarrage du job. |
| Les codes d'adhésion restent-ils uniques sur 79 000 classes ? | Oui si on tire comme l'import : codes déjà pris chargés une fois, complétés lot après lot. | `JoinCode.generate_unique` sur `taken_join_codes` (ADR-0041). |

## Cas limites identifiés

- Aucun établissement candidat : le rapport se termine à zéro, rien n'est écrit.
- Référentiel vide : tous les candidats sont « sans classe à générer », rien n'est écrit, niveaux sautés comptés.
- Job tué (déploiement) : le rapport reste en cours ; il passe `failed` au lancement suivant après 10 minutes (ADR-0039), et relancer reprend là où il en était, puisque les établissements dotés ne sont plus candidats.
- Droit retiré entre le clic et l'exécution : le rapport passe `failed`, rien n'est écrit.
- Collège public (`first`) : seulement les niveaux du premier cycle ; établissement mixte : barème du privé.

## Questions encore ouvertes

- Aucune.
