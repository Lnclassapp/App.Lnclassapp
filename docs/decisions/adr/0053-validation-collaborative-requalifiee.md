# ADR-0053 : La validation collaborative n'entre pas dans le projet cible avant une décision produit, et aucun label de conformité n'est affiché

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-33**, vague V8 (hors plan) |
| **Remplace** | [ADR-0011](./0011-validation-collaborative-crowdsourcing.md) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0011 se déclare `Accepté` et rédigé au passé. Il décrit :

- une `CommunityValidation` polymorphe, réservée aux enseignants **certifiés** ;
- des entités à la racine.

Rien de cela n'existe (**C-16**). Le glossaire ne connaît aucune certification, et les conventions exigent un namespace par contexte (**C-34**). Seule trace dans le code : un bandeau « Conforme au programme », affiché à tous sur chaque contenu, sans aucune validation derrière (CA-29). Ce bandeau affirme une garantie pédagogique qui n'existe pas.

## 2. Moteurs de décision

1. L'interface n'affirme rien que le système ne vérifie.
2. Un ADR `Accepté` décrit ce qui est, ou ce qui sera fait.
3. La feature attend ses questions produit, pas une modélisation anticipée.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Implémenter l'ADR-0011 | Écrit | Personne n'a défini « certifié » ; modélisation hors conventions |
| B — **Requalifier : retirer, puis décider plus tard** | Aucun mensonge à l'écran | La feature attend |
| C — Abandon définitif | Clair | Ferme une piste produit sans l'avoir instruite |

## 4. Décision

> **Nous remplaçons l'ADR-0011, nous ne livrons aucune validation collaborative ni aucun label de conformité dans les vagues V0 à V6, et nous subordonnons la feature à une décision produit préalable.**

- **Aucun bandeau** « Conforme au programme », « Validé » ou équivalent n'apparaît dans le projet cible. Le vocabulaire de l'UDR-0007 l'interdit.
- **Aucune** table, route, entité ni policy de validation n'est créée avant la V8.
- La **décision produit** doit répondre à trois questions avant tout nouvel ADR :
  1. qui peut valider : tout enseignant, un enseignant certifié (par qui, sur quel critère), l'équipe ;
  2. ce que la validation change pour l'élève (affichage, ordre, rien) ;
  3. ce qui se passe quand un contenu validé est modifié.
- **Contraintes déjà connues** pour le futur ADR : contexte `catalog`, namespace `Catalog::` (ADR-0027) ; une policy par use case (ADR-0028) ; auteur par `users.id` ; archivage plutôt que suppression (ADR-0036).
- Le signalement d'une erreur de contenu par un enseignant, s'il est voulu avant la V8, est une feature distincte, à inscrire à la feuille de route sans passer par cet ADR.

## 5. Conséquences

### 🟢 Positives

- L'interface cesse d'affirmer une conformité non vérifiée.
- C-16 (part ADR-0011) et C-34 sont fermées : plus aucun ADR `Accepté` ne décrit une feature fantôme.

### 🔴 Coûts consentis

- Les enseignants n'ont aucun moyen intégré de signaler une erreur de contenu avant qu'une décision soit prise.
- Le travail de modélisation de l'ADR-0011 est mis de côté.

## 6. Notes d'implémentation

Aucun code à écrire : la décision est une absence. La seule action concrète est de ne pas reprendre le bandeau de l'ancien (`app/views/**/_conformity_badge*` ou équivalent, CA-29).

## 7. Comment vérifier que la décision est respectée

- `test/i18n/vocabulary_test.rb` (UDR-0007) échoue si « Conforme au programme » ou « Validé par la communauté » apparaît dans une locale ou une vue.
- `test/architecture/layout_test.rb` échoue si un fichier nommé `*validation*` apparaît sous `app/domain/entities/catalog/` sans ADR de référence dans son en-tête HITL.

## 8. Remplace, complète, amende

- **Remplace** l'ADR-0011 en entier (C-16, C-34).

## 9. Points à confirmer par le porteur

- Retrait du bandeau dès la V1, sans remplacement.
- La feature est rangée en V8.
