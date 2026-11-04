# UDR-0148 : La fiche de révision coupée à 50 mots
<!-- index
titre: Fiche de révision coupée à 50 mots
statut: Accepté
adr-lie: —
problematique: 150 mots avant « Voir plus » montraient presque toute une notion ; l'aperçu de la fiche doit être court
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-31 |
| **Chantier** | `docs/chantiers/fiche-revision-coupe-50-mots` |
| **ADR lié** | — |
| **Remplacé par** | — |

---

## 1. Contexte

UDR-0139 §3.2 coupe la fiche de révision de la page d'une leçon après 150 mots. Une notion type en compte une cinquantaine : la partie visible montrait presque une notion entière, et l'élève, sur téléphone, défilait longtemps avant la suite de la page.

## 2. Décision

Le seuil passe de **150 à 50 mots**. Tout le reste d'UDR-0139 §3.2–§3.3 et d'UDR-0141 tient : même comptage, coupe en fin du bloc qui atteint le seuil, fiche ouverte d'emblée, « Voir plus » qui déplie sur place sans requête. La fiche en plein écran n'est pas réintroduite.

## 3. Règles d'implémentation

Amende UDR-0139 §3.2 et UDR-0141 : partout où elles disent « 150 mots », lire « 50 mots ».

- Le seuil est la constante `Entities::Catalog::RevisionPreview::LIMIT = 50`, seule source ; ni la vue, ni le contrôleur `catalog--revision-more`, ni la query ne le répètent.
- La coupe tombe **après le premier bloc qui porte le total à 50 ou plus** ; total ≤ 50 : pas de coupe, pas de bouton.
- En pratique : la partie visible est le plus souvent l'« À retenir » de la première notion, parfois avec la méthode ; dès deux notions, la seconde est derrière « Voir plus ».

**États** : inchangés (UDR-0139 §3.2) — fiche vide, fiche courte entière, fiche coupée avec « Voir plus », fiche dépliée avec « Voir moins ».

**Accessibilité** : inchangée — bouton de 48 px, `aria-expanded`, annonce `aria-live`, focus au premier élément déplié puis rendu au bouton.

## 4. Conséquences

Presque toutes les leçons à plusieurs notions affichent désormais « Voir plus ». Changer le seuil ne demande que la constante et les tests qui la figent.
