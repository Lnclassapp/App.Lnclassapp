# ADR-0129 : La médaille d'un exercice se lit dans la médaille enregistrée à la clôture
<!-- index
titre: Médaille d'exercice lue à la clôture, Bronze dès une réponse
statut: Accepté
adr-lie: [0033](0033-bareme-des-badges-et-seuils-pedagogiques.md), [0106](0106-les-seuils-pedagogiques-se-lisent-sur-la-note-affichee.md)
problematique: Plusieurs écrans recalculent la médaille depuis le score, qui ne dit pas si l'élève a répondu ; « Bronze dès une réponse » exige un fait que le score ne porte pas.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-11-08) |
| **Date** | 2026-11-08 |
| **Chantier** | `docs/chantiers/medailles-grading-bronze` |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le porteur décide : tout exercice traité donne au moins Bronze, une copie vide ne donne rien. Le score (0 à 100) ne distingue pas 0 % avec réponses fausses et 0 % copie vide. Six lectures recalculent la médaille depuis le score (`Grading.badge_for`) : résultat de session, rapport de compréhension (détail et résumé), accueil enseignant, fiche élève, liste de classe. La médaille enregistrée à la clôture (`exercise_badges`) existe déjà, une par élève et par exercice.

## 2. Moteurs de décision

- Une seule vérité par médaille ; pas de recalcul qui diverge du stocké.
- Aucune migration, aucun rattrapage (décision du porteur).
- Requêtes de lecture légères.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Lire la médaille enregistrée | Une vérité ; la clôture connaît les réponses | Les écrans changent de source |
| B — Recalculer depuis le score + nombre de réponses | Rien d'enregistré à changer | Chaque requête compte les réponses ; six requêtes touchées ; deux sources qui peuvent diverger |

## 4. Décision

> **Nous écrivons la médaille à la clôture : le palier du score, ou Bronze si le score est sous 48 % et qu'au moins une réponse a été donnée (une tentative non `unanswered`). Les écrans lisent la médaille enregistrée, jamais le score.**

Le palier du meilleur résultat reste la règle « ne monte que vers un palier supérieur » (ADR-0033). `Grading.badge_for(score)` reste le palier du score seul ; `Grading.session_medal(score, treated:)` est la médaille d'une session (rien pour une copie vide), la même règle à la clôture et à l'écran (`Queries::Assessment::Medals::TREATED_SQL`).

- **Copie traitée** : au moins une tentative non `unanswered`. Une question du cahier (aucun champ) rend la copie traitée (journal, À trancher). Une question « remettre dans l'ordre » laissée telle quelle envoie un ordre : elle compte comme une réponse (UDR-0138), donc Bronze.
- **Médaille de classe** (`class_badge_for`) : « Pas encore » sans médaille lisible dans la classe, même avec des notes (copies vides seulement, PRD §3) ; avec une médaille, Bronze au minimum, sinon la règle de la moyenne.
- **Lecture par classe** (ADR-0097 §4.5) : une médaille ne se lit dans une classe que si la session qui l'a enregistrée appartient à une de ses assignations (`Queries::Assessment::Medals.by_assignment`). Une médaille gagnée ailleurs n'existe pas ici (journal, À trancher).
- **Écrans élève** : la médaille d'un exercice est la médaille enregistrée ; celle d'une session (résultat, historique, archive, progrès) est `session_medal`.

## 5. Conséquences

### 🟢 Positives

- Une seule source ; plus d'écart entre ce que la clôture a dit et ce que l'écran recalcule.
- Aucune migration.

### 🔴 Coûts consentis

- Les sessions clôturées avant ce chantier sous 48 % restent sans médaille : les écrans les lisent « Pas encore ».
- Six requêtes à modifier et leurs tests.
- Un exercice d'une session sans médaille enregistrée (anciens cas) ne se recalcule pas.

## 6. Hors périmètre

Aucune table, aucun port nouveau : l'ADR change la source de lecture d'un contrat existant.

## 7. Comment vérifier

Tests de clôture (copie à 20 % avec réponses, copie vide, copie partiellement vide, session sans tentative, cahier seul) ; un test par requête de lecture avec une copie vide (« Pas encore ») et une médaille gagnée dans une autre classe (jamais lue) ; trajet complet copie vide → résultat « Pas encore », aucune ligne `exercise_badges`.
