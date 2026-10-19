# UDR-0112 : Chiffres de la classe sur la page de l'enseignant et de l'équipe — les trois tuiles de la direction
<!-- index
titre: Chiffres de la classe sur la page de l'enseignant et de l'équipe
statut: Proposé
adr-lie: —
problematique: CL-14. L'enseignant ne voit pas devoirs donnés, taux de rendu et moyenne de sa classe, que la direction lit déjà ; les mêmes tuiles, mêmes définitions, sous l'en-tête de la page d'une classe.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/vie-de-la-classe`](../../chantiers/vie-de-la-classe/memo.md) |
| **ADR lié** | — (aucune règle ne change : définitions de l'UDR-0074 et seuil de `StudentWorkQuery::MIN_STUDENTS_FOR_AVERAGE`) · amende [UDR-0027](0027-page-classe.md) |
| **Remplacé par** | — |

---

## 1. Contexte

La page d'une classe de l'enseignant et de l'équipe (`classroom/classrooms#show`) montre chaque exercice assigné et son compte de « faits », puis chaque élève et son dernier score. Elle ne dit pas, en un regard, si la classe rend ses devoirs. La direction le lit sur sa page de la même classe : trois tuiles « Devoirs donnés », « Taux de rendu », « Moyenne » (UDR-0074, `school_admin/classrooms/show`). Deux chiffres différents pour la même classe selon le rôle seraient pires qu'aucun : les tuiles reprennent la même requête.

## 2. Décision

- Les **trois tuiles de la direction**, au même balisage, entre l'en-tête et les jours de séance.
- Mêmes valeurs, lues par `Queries::School::StudentWorkQuery` (méthode `figures(public_id:)`), pas par un nouveau calcul.
- Montrées à l'enseignant de la classe et à l'équipe (`ReadClassroomPolicy`, accès `show_roster`) ; l'élève n'a pas accès à cette page (403, inchangé).
- Pas de pastille de couleur (signal de la direction, UDR-0074) : l'enseignant a déjà le détail par exercice juste en dessous.

## 3. Règles d'implémentation

> Cette section est un **contrat d'exécution**. Un agent l'applique littéralement.

**Structure**
- Nouveau partiel `app/views/classroom/classrooms/_figures.html.erb`, `locals: (figures:)`, rendu dans `show.html.erb` en tête du conteneur `space-y-10`, avant `_session_days`.
- `<section id="classroom_figures" aria-labelledby="classroom_figures_title">` ; titre `h2` `sr-only` « Chiffres de la classe ».
- `<ul class="grid grid-cols-3 gap-3">`, trois `<li class="rounded-ln bg-mist px-3 py-4">` : valeur `font-display text-2xl font-extrabold tabular-nums`, libellé `text-sm text-mute`, suivi de `ui_info_tip` pour « Taux de rendu » et « Moyenne » avec les textes `school_admin.classrooms.tips.submission_rate` et `.average` (mêmes clés, mêmes mots que la direction).
- Valeur absente (`nil`) : `<span aria-hidden="true">—</span><span class="sr-only">non calculé</span>`, clé `school_admin.classrooms.not_computed`.

**Tokens**
- `bg-mist`, `rounded-ln`, `text-mute`, `font-display` : ceux de `school_admin/classrooms/show`, sans valeur en dur.

**Comportement**
- Rendu serveur, sans frame ni Stimulus ; la page est déjà rafraîchie par morphing après un retrait d'élève (UDR-0081) : les tuiles se recalculent avec elle.
- `StudentWorkQuery#figures(public_id:)` : une requête pour les devoirs donnés et rendus, une pour la moyenne — nombre de requêtes fixe, indépendant du nombre d'élèves.

**États obligatoires**
- Vide : aucun devoir donné → « 0 », « — », « — ».
- Chargement : sans objet (rendu serveur).
- Erreur : celle de la page.
- Succès : les trois valeurs.

**Accessibilité**
- Chaque tuile est un `li` lu « 3, Devoirs donnés » ; la bulle d'aide est un bouton ≥ 48 × 48 px (composant `ui_info_tip`).
- À 390 px, trois colonnes égales, valeurs sur une ligne (`text-2xl` tient « 100 % » dans un tiers de 358 px).

## 4. Conséquences

- La page d'une classe de l'enseignant et celle de la direction affichent les mêmes chiffres pour la même classe ; une évolution de définition se fait dans `StudentWorkQuery`, une fois.
- L'UDR-0027 est amendée : un bloc de plus en tête de page.
