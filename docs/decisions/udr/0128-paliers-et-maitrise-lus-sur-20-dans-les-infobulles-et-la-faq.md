# UDR-0128 : Paliers et maîtrise lus sur 20 — les infobulles « Badge » et « Maîtrise » et la FAQ disent des notes, jamais des pourcentages
<!-- index
titre: Paliers et maîtrise lus sur 20 dans les infobulles et la FAQ
statut: Accepté
adr-lie: [0105](../adr/0105-les-seuils-pedagogiques-se-lisent-sur-la-note-affichee.md), [0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md)
problematique: Les infobulles « Badge » et « Maîtrise » (page d'un exercice, résultat de session) et les réponses « badges » et « maîtrise » de la FAQ citent des seuils en % alors que l'élève lit une note sur 20 et que les paliers s'obtiennent désormais dès 10, 14 et 16/20. Les textes se lisent sur 20, calculés depuis Grading.
-->

| | |
|---|---|
| **Statut** | Accepté (2026-10-19, porteur : « Oui, partout ») |
| **Date** | 2026-10-19 |
| **Chantier** | [`docs/chantiers/note-sur-20-partout`](../../chantiers/note-sur-20-partout/memo.md) |
| **ADR lié** | [ADR-0105](../adr/0105-les-seuils-pedagogiques-se-lisent-sur-la-note-affichee.md) §4.5 · [ADR-0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md) |
| **Amende** | [UDR-0054](0054-finitions-d-interface.md) §3.4 (textes d'infobulle communs : « Badge » et « Maîtrise ») · [UDR-0061](0061-carte-d-aide-et-faq.md) (réponses « badges » et « maîtrise ») · [UDR-0119](0119-fiche-a-revoir-exercice-propose-et-regle-sur-20.md) §2.3 (même principe, étendu) |
| **Remplacé par** | — |

---

## 1. Contexte

Les infobulles « Badge » et « Maîtrise » disaient « Bronze à partir de 50 %, Argent à partir de 70 %… » et « Acquis : 70 % et plus ». Or l'élève lit toutes ses notes sur 20 (UDR-0023) et, depuis l'ADR-0105, un palier s'obtient dès la **note** du seuil : Bronze dès 10/20 (48 %), Argent dès 14/20 (68 %), Or dès 16/20 (78 %). Un texte en pourcentage serait faux de deux points, et il parlerait une autre langue que l'écran.

## 2. Décision

1. **Les seuils se lisent sur 20**, avec « dès » pour un palier et « et plus » pour une maîtrise. Aucun pourcentage de seuil n'apparaît.
2. **Les notes sont calculées, jamais écrites en dur** : `Assessment::BadgesHelper#badges_tip` et `#mastery_tip` interpolent `Grading.grade_on_20(<seuil>)` dans `shared.info_tips.badges` et `shared.info_tips.mastery`. La FAQ (`communication.help.show.questions.badges` et `.mastery`) reçoit `pass_grade`, `mastery_grade` et `gold_grade` de `communication/help/show.html.erb`.
3. **Le Diamant se dit par sa condition**, pas par un chiffre : « toutes les réponses justes » (ADR-0105 §4.3).
4. **Rien d'autre ne change** : emplacement des infobulles, taille, ton, ordre des questions de la FAQ.

## 3. Consigne d'exécution

| Surface | Texte (valeurs actuelles : seuils 50, 70, 80) | Source |
|---|---|---|
| Infobulle « Badge » (`#student_progress`, `#session_badge`) | « Bronze dès 10/20, Argent dès 14/20, Or dès 16/20, Diamant : toutes les réponses justes. » | `badges_tip` |
| Infobulle « Maîtrise » (`#student_progress`, résultat de session) | « Acquis : 14/20 et plus. Fragile : de 10 à 13/20. En difficulté : moins de 10/20. » | `mastery_tip` |
| FAQ « Comment gagner un badge ? » (`#help_question_badges`) | « … Bronze dès 10/20, Argent dès 14/20, Or dès 16/20, Diamant quand toutes les réponses sont justes. Tu as un seul badge par exercice, et il ne peut que monter. » | `thresholds` de la vue |
| FAQ « Que veut dire « Maîtrise » ? » (`#help_question_mastery`) | « Acquis dès 14/20, Fragile dès 10/20, En difficulté sous 10/20. » | `thresholds` de la vue |

- Les clés `%{bronze}`, `%{silver}`, `%{gold}`, `%{acquired}`, `%{fragile}`, `%{below_acquired}` (infobulles) et `%{pass_grade}`, `%{mastery_grade}`, `%{gold_grade}` (FAQ) sont obligatoires : un test échoue si une valeur manque.
- Si un seuil change dans `Grading`, les textes suivent sans toucher la locale.
- Accessibilité et Turbo : inchangés (infobulles `ui_info_tip` et `stat_info_tip`, FAQ en `<details>`).

## 4. Conséquences

- Les tests d'écran citent les notes calculées (`Grading.grade_on_20`), pas des chaînes.
- Les écrans qui montraient déjà une note sur 20 (résultat, historique, accueil, « Ma classe ») ne changent pas, hormis ce qui est décidé par la note : couleur, maîtrise et palier restent cohérents avec elle.
