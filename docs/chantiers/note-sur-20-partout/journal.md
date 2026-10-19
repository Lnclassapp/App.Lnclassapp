# Journal — La note sur 20 décide partout

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-19 | Nouvel ADR-0106 plutôt qu'un amendement du seul §4.5 de l'ADR-0101 | La décision touche aussi l'ADR-0033 (les seuils des badges) et les textes d'écran ; un ADR autonome se retrouve mieux que cinq lignes dans un §4.5 consacré aux lacunes. L'ADR-0101 §4.5 renvoie vers lui. | Oui, ADR-0106 |
| 2026-10-19 | Le Diamant reste le sans-faute (`Grading.perfect?`), hors de la règle | `score_percent` est arrondi vers le bas et vaut 100 seulement si tout est juste (ADR-0033). Lu sur 20, 98 % donnerait un faux « sans-faute ». | Oui, ADR-0106 §4.3 |
| 2026-10-19 | Les moyennes (accueil enseignant, « Réussite moyenne » de l'équipe, travail des élèves) ne changent pas | Des statistiques, pas des décisions ; arrondir avant de moyenner changerait le chiffre sans rien décider. | Oui, ADR-0106 §4.4 |
| 2026-10-19 | Infobulles et FAQ lues sur 20, calculées depuis `Grading` | Un texte « Bronze à partir de 50 % » devenait faux (Bronze dès 48 %). | UDR-0131 |
| 2026-10-19 | Les badges déjà décernés ne sont pas recalculés | Un badge s'écrit à la clôture et ne descend jamais ; aucune migration demandée. | Oui, ADR-0106 §5 |

## Ce qui a dérapé

- Les cinq vues qui recopiaient `grade_on_20(x) >= grade_on_20(MASTERY_THRESHOLD)` (et un `>= 14` en dur dans `_treated_exercise`) étaient déjà « alignées » mais dupliquaient l'arrondi : elles passent par `reaches?`.
- Cinq tests de domaine et de requête codaient les anciennes bornes (49/50, 69/70) : réécrits aux nouvelles (47/48, 67/68).
- Les numéros ADR-0105 et UDR-0128 étaient déjà pris (PR 238 et aide WhatsApp sur `Develop`) ; UDR-0129 et 0130 sont réservés par les PR 238 et 237. Renumérotés ADR-0106 et UDR-0131 à la reprise, lignes de la PR seulement : les UDR-0128 de l'aide WhatsApp restent.
- Revues de la reprise : rien en sécurité ; ajoutés un garde-fou d'architecture (aucune comparaison brute à un `*_THRESHOLD` dans `app/`, hors `perfect?`) et le test de la page de résultat à 98 % (20/20, Or, « Recommencer »).

## Ce qu'on a appris sur la codebase

- Les FAQ et les infobulles citent les seuils par interpolation depuis `Grading` ; un changement de lecture des seuils touche donc aussi les locales, pas seulement le domaine.
- `mastery_for` alimente à la fois la maîtrise de l'élève, les catégories de compréhension de la classe et le point de couleur de chaque question : une seule modification les aligne toutes.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Rattrapage des badges déjà décernés (élèves à 48 %, 68 %, 78 %) : d'ici là, la page de l'exercice (badge enregistré) peut dire un palier sous la page de résultat (recalculé), ADR-0106 §5 | Pas demandé ; chantier de données | à ouvrir si le porteur le veut |
