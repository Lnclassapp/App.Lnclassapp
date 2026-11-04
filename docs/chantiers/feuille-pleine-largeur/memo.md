# Memo — La feuille remplit l'écran du téléphone

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-11-04 |
| **Branche** | `feature/feuille-pleine-largeur` |
| **Programme** | — |

---

## Le problème

Sur téléphone, la feuille d'une leçon (épreuve à lire, feuille à remplir) laisse trop d'espace sur les côtés : trois marges s'empilent (page, feuille blanche, cadre de l'exercice). Le texte commence à 36 px du bord sur l'épreuve et à 51 px sur la feuille à remplir ; les énoncés et les champs sont serrés.

## Pour qui

L'élève sur téléphone, qui lit et remplit les feuilles « Prépare interros » / « Prépare devoirs » et les devoirs de « Ma classe » ; l'enseignant qui lit une feuille sur téléphone.

## Pourquoi maintenant

Le pilote a vu les captures des chantiers `sujet-comme-une-epreuve` et `refaire-ou-continuer` à 390 px et demande que la feuille remplisse l'écran.

## Hors périmètre

- L'ordinateur et la tablette (640 px et plus) : inchangés.
- Les autres écrans de l'application (accueil, leçon, cases des feuilles, correction) : inchangés.
- Le contenu et l'ordre de la feuille : inchangés.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quel réglage, vu sur un essai à 390 px (feuille à remplir et épreuve, avant / après) ? | « La capture 4 me plaît beaucoup, c'est ça que je veux » (l'épreuve après : texte à 12 px du bord) | Valeurs de l'essai reprises telles quelles dans l'UDR. |
| Le bouton sous l'épreuve ? | Il faut changer « Continuer Prépare interros / devoirs » (page où on voit le sujet sans pouvoir le traiter) ; texte choisi : « Commencer l'exercice » | Le bouton dit toujours « Commencer l'exercice » (UDR §3, amende UDR-0151 §3). Un premier essai avec « Continuer … » toujours était un malentendu, corrigé avant la PR. |
| Quelles pages ? | Toutes les feuilles (leçon, devoir de « Ma classe », enseignant) : proposé, accepté (« Oui lance ») | Une règle CSS commune à `.ps-page`, aucune vue touchée. |

## Cas limites identifiés

- Une formule ou un tableau plus large que l'écran : défile dans sa case (UDR-0152), jamais la page.
- Le bouton « Commencer » sous l'épreuve : garde une marge de 12 px, aligné sur le texte.

## Questions encore ouvertes

- Aucune.
