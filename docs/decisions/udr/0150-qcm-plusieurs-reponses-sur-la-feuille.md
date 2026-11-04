# UDR-0150 : La feuille annonce le nombre de réponses d'un QCM et nomme la question refusée
<!-- index
titre: QCM à plusieurs réponses sur la feuille
statut: Accepté
adr-lie: —
problematique: Sur la feuille de cahier, un QCM à plusieurs bonnes réponses ne dit pas combien en cocher, et un refus de vérification ne dit pas quelle question est en cause.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-04 |
| **Chantier** | `docs/chantiers/qcm-plusieurs-reponses` |
| **ADR lié** | — (ADR-0054 : nombre exact de propositions) |
| **Remplacé par** | — |

Amende l'UDR-0149 §3 (exercices de la feuille ; États : erreur).

---

## 1. Contexte

Un élève coche une seule proposition à un QCM qui en attend deux. La feuille ne le prévenait pas, et le refus disait « un nombre est attendu pour un calcul ».

## 2. Décision

Prévenir et bloquer (choix du pilote, 2026-11-04) : la feuille annonce le nombre de propositions à cocher, comme le lecteur d'exercice ; une sélection du mauvais nombre ne corrige rien et le message nomme la question. Compter la question fausse a été écarté.

## 3. Règles d'implémentation

**Annonce** (`app/views/catalog/courses/sheets/_question.html.erb`)
- Sous l'énoncé d'un QCM à 2 ou 3 bonnes réponses, avant ses propositions : `p.ps-instruction` « Coche 2 réponses. » / « Coche 3 réponses. » (`catalog.courses.sheets.choose_count`, `count:`). Rien pour un QCM à une réponse ni pour un vrai ou faux.
- L'annonce s'affiche dans tous les modes (élève, visiteur, enseignant, équipe, lecture). Le groupe de propositions la cite : `aria-describedby` vers son `id` (`question-<id>-instruction`).

**Refus** (`assessment/sheet_checks/_error`)
- Une copie refusée pour des réponses mal formées : une ligne par question fautive, dans l'ordre, « Question <lettre> : <consigne> », dans le même `p.ps-error` (`role="alert"`), lignes séparées par `<br>` :
  - mauvaise sélection : « coche 2 réponses. » (le nombre de la question) ;
  - nombre illisible : « écris un nombre, par exemple -3,5. » ;
  - case à compléter vide ou illisible, autre type : « vérifie ta réponse. ».
- Une copie illisible dans sa forme (aucune question désignée) : le message général d'aujourd'hui, sans « un nombre est attendu ».
- Les réponses de l'élève restent cochées (inchangé).

**Tokens**
- `.ps-instruction` dans `prepare_sheet.css` : italique, `#000`, taille du texte des questions, marge basse 8 px. Aucun style en ligne.

**États**
- Succès : la page de résultat (inchangé). Erreur : ci-dessus. Vide et chargement : inchangés.

**Accessibilité**
- L'annonce est du texte, lue avec la question grâce à `aria-describedby`. Le refus garde `role="alert"`.

## 4. Conséquences

- Un QCM multiple se reconnaît sur la feuille sans le tenter.
- Interdit : un refus de vérification qui ne nomme pas la question quand le domaine la désigne.
