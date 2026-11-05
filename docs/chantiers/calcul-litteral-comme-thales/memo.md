# Memo — Calcul littéral préparé comme Thalès

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-11-05 |
| **Branche** | `feature/calcul-litteral-comme-thales` |
| **Programme** | — |

---

## Le problème

« Propriétés de Thalès dans un triangle » est la seule leçon complète pour les feuilles :
- 2 exercices par notion, donc 2 feuilles « Prépare interros » par notion ;
- 4 sujets de devoir de 4 exercices, avec figures.

« Calcul littéral » (3ème, mathématiques) n'a qu'un exercice par notion et aucun sujet : sa section « Prépare devoirs » ne se montre pas.

## Pour qui

L'élève de 3ème qui prépare une interro ou un devoir de calcul littéral, et l'enseignant qui envoie un sujet à sa classe.

## Pourquoi maintenant

Toutes les leçons sont maintenant chargées entières sur Develop ([Lnclassapp/App.Lnclassapp#477](https://github.com/Lnclassapp/App.Lnclassapp/pull/477)). Le pilote demande de faire pour Calcul littéral « la même chose que pour Thalès » ; il a choisi cette seule leçon d'abord, pour voir le résultat.

## Hors périmètre

- Les autres leçons : ce chantier sert de deuxième modèle avant d'aller plus loin.
- Le cours, les fiches des 4 notions (« À retenir », méthode, exemple, piège, « Je m'entraîne ») et les 4 exercices « Toute la leçon » : inchangés.
- L'écran : aucune vue ne change, donc pas d'UDR.
- Staging et production : le fichier n'y est pas importé à la main.
  - Staging recharge seul les exercices et sujets d'une leçon à sujets (ADR-0122).
  - Si la leçon de Staging n'a pas les 4 notions du fichier, le journal de Staging le dira (`notion_not_found`), sans rien casser.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quel modèle pour les autres leçons ? | « Tel que tu as fait pour Thalès, c'est même chose » | Même structure que Thalès : 2 exercices par notion, 4 sujets de 4 exercices. |
| Quelles leçons ? | « Calcul littéral seulement » | Un seul fichier. |
| Qui le fait ? | « Moi, ici » (Claude, dans la session du pilote) | Chantier ici, PR assignée au pilote. |

## Cas limites identifiés

- Une expression attendue au clavier (« complète ») a plusieurs écritures (`2x+6`, `6+2x`).
  - Une question « complète » ne demande qu'un nombre, un signe ou un terme simple.
  - Les expressions se choisissent dans un QCM.
- Les calculs sont tous revérifiés par une machine : chaque bonne réponse est juste, et chaque mauvaise réponse est fausse.

## Questions encore ouvertes

- Aucune.
