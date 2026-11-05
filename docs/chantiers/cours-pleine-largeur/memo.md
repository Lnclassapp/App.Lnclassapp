# Memo — La fiche de cours remplit l'écran du téléphone

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré ([#471](https://github.com/Lnclassapp/App.Lnclassapp/pull/471) vers `Develop`, 2026-11-04), clos |
| **Ouvert le** | 2026-11-04 |
| **Branche** | `feature/cours-pleine-largeur` |
| **Programme** | — |

---

## Le problème

Sur téléphone, la fiche de révision affichée dans la page d'une fiche de cours laisse trop d'espace sur les côtés. Quatre marges s'empilent : celle de la page, le cadre gris du cahier, la marge de la page du cahier et celle de l'encadré. Le texte d'un encadré « À retenir » commence à 66 px du bord, et une étape de « La méthode » à 88 px. Les lignes sont courtes et la fiche est longue à faire défiler.

## Pour qui

L'élève qui révise une leçon sur téléphone. L'enseignant qui l'ouvre sur téléphone voit la même fiche.

## Pourquoi maintenant

Le chantier `feuille-pleine-largeur` vient de mettre les feuilles bord à bord sur téléphone. Le pilote demande « la même chose » pour la fiche de cours.

## Hors périmètre

- L'ordinateur et la tablette (640 px et plus) : inchangés.
- La fiche de cours ouverte seule (écran plein, sans `data-embedded`), qui va déjà bord à bord sous 1 000 px : inchangée.
- Les cases « Prépare interros » et « Prépare devoirs » sous la fiche, l'en-tête de la page : inchangés.
- Le contenu de la fiche, la marge rouge, les lignes Seyès et les couleurs des encadrés : inchangés.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quel réglage, vu sur un essai à 390 px (avant / après) ? | « Oui lance, mais c'est la 3e capture qui me plaît beaucoup » : la 3e capture est l'essai « après » (bas de la fiche, « Voir plus », cases Prépare interros) | Les valeurs de l'essai sont reprises telles quelles dans l'UDR. |
| Quelles pages ? | Toutes celles qui affichent le cahier dans la colonne de l'application (`data-embedded`) : la fiche de cours et la page « Je m'entraîne ». Proposé, accepté (« Oui lance ») | Une règle CSS commune à `.sheet-screen[data-embedded]`, aucune vue touchée. |
| Le cadre gris et ses coins arrondis ? | Ils disparaissent sous 640 px dans l'essai validé | `border-radius: 0` et marge de page annulée. |

## Cas limites identifiés

- Une formule plus large que l'écran : défile dans sa ligne (`div.sheet-text`), jamais la page.
- La marge rouge reste à 8 px du bord : le texte de la page commence à 16 px, pas plus près.
- Le dégradé de la fiche repliée et « Voir plus » : inchangés.

## Questions encore ouvertes

- Aucune.
