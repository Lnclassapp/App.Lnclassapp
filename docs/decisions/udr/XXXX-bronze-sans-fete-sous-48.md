# UDR-XXXX : Résultat — Bronze sans fête sous 48 %, « Pas encore » quand rien n'est médaillé
<!-- index
titre: Bronze sans fête sous 48 % sur le résultat
statut: Accepté
adr-lie: [0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md)
problematique: Une première médaille Bronze obtenue sous 48 % ne doit pas être célébrée comme une réussite ; une copie vide n'a pas de médaille.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-11-08) |
| **Date** | 2026-11-08 |
| **Chantier** | `docs/chantiers/medailles-grading-bronze` |
| **ADR lié** | ADR-XXXX-medailles-lues-a-la-cloture |
| **Amende** | UDR-XXXX-medailles-remplacent-notes-et-moyennes §2.5 |
| **Remplacé par** | — |

---

## 1. Contexte

Bronze s'obtient dès qu'une réponse est donnée. Célébrer une copie à 20 % comme une réussite serait faux et décourageant à la fois.

## 2. Décision

Sous 48 %, la médaille Bronze s'affiche sans « Nouvelle médaille ! » ni confettis ; elle est présentée comme un début. Sans médaille, « Pas encore ».

## 3. Règles d'implémentation

**Structure** : `app/views/assessment/session_results/_badge.html.erb` ; `show.html.erb` (confettis).

**Comportement**
- `earned_now` ne vaut vrai que si la médaille vient d'être décernée **et** que le score est de 48 % ou plus (note affichée 10/20 ou plus, `Grading.reaches?`). Sous 48 %, la pastille « Nouvelle médaille ! » n'est pas rendue.
- Les confettis restent soumis à leur règle actuelle (ton « succès ») : aucun changement.
- Sans médaille : libellé `assessment.badges.levels.none` (« Pas encore »), phrase d'encouragement existante, bouton « Refaire l'exercice » inchangé.

**États obligatoires**
- Vide : « Pas encore ». Chargement et erreur : inchangés. Succès : médaille nommée en toutes lettres.

**Accessibilité** : `aria-label` « Médaille Bronze » ; le palier ne se lit jamais par la couleur seule (UDR-0007).

## 4. Conséquences

Aucun autre écran ne change ici ; les écrans de médaille viendront avec `medailles-eleve`.
