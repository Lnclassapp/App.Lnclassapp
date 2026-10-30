# PRD — Fiche de révision en plein écran

## 1. Contexte

Sur la page d'une leçon, la fiche de révision s'affichait ouverte, coupée à 150 mots avec « Voir plus ». Le porteur demande
(2026-10-30) : à l'arrivée sur la leçon, l'élève ne voit qu'un bouton « Fiche de révision » ; le bouton ouvre la fiche, qui prend
toute la page.

## 2. Comportement

| Situation | Comportement attendu |
|---|---|
| Arrivée sur la page de la leçon | un bouton « Fiche de révision » à la place de la fiche ; « Prépare interros » inchangé |
| Clic sur le bouton | une `<dialog>` plein écran (`ui_modal placement: :full`) montre la fiche entière, sans « Voir plus » ; titre et croix restent en haut au défilement |
| Croix, Échap | la fiche se ferme, le focus revient au bouton |
| Adresse `#fiche-de-revision` (redirection de `/fiche`) ou `#notion-…` (cartes des leçons) | la fiche s'ouvre à l'arrivée, sur la notion visée (`catalog--revision-dialog`) |
| Leçon sans fiche | « La fiche de révision arrive bientôt. », sans bouton |
| Leçon vue depuis une classe (enseignant) | inchangée : fiche ouverte, coupe des 150 mots et « Voir plus » |

## 3. Hors périmètre

Sans JavaScript, le bouton n'ouvre rien (la `<dialog>` est dans le HTML, fermée).
