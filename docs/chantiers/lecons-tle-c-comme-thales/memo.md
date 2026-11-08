# Memo — Les leçons de Terminale C préparées comme Thalès

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours (2026-11-05) |
| **Ouvert le** | 2026-11-05 |
| **Branche** | `feature/lecons-tle-c-comme-thales` |
| **Ticket** | [#484](https://github.com/Lnclassapp/App.Lnclassapp/issues/484), étape 2, dossier `tle-c` |

---

## Le problème

Les 45 leçons v3 de `tle-c` (Français 6, Mathématiques 10, Philosophie 9, Physique-Chimie 10, SVT 10) n'ont qu'un exercice par notion et aucun sujet : leur section « Prépare devoirs » ne se montre pas.

## Pour qui

L'élève de Terminale C qui prépare une interro, un devoir ou le baccalauréat ; l'enseignant qui envoie un sujet à sa classe.

## Pourquoi maintenant

La 3ème est fusionnée (#494, chantier `lecons-3eme-comme-thales`). Le pilote a fixé l'ordre de la Terminale dans #484 : `tle-c`, `tle-d`, `tle-a1`, `tle-a2`, `tle`. Le porteur a validé le lancement.

## Hors périmètre

- Les autres dossiers de Terminale, y compris les copies des leçons de `tle-c` dans `tle-d`, `tle-a1` et `tle-a2` : chantiers suivants (liste dans le journal).
- Le cours, les fiches des notions, le 1er exercice de chaque notion et les 4 exercices « Toute la leçon » : inchangés, octet pour octet.
- L'écran et le code (`app/`) : rien ne change, donc ni ADR ni UDR.
- Staging et production : aucun import à la main.

## Ce que le grill a révélé

Les décisions ont été prises par le pilote dans #484 (2026-11-05) et appliquées comme en 3ème.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quel modèle ? | Thalès, Calcul littéral et les 60 leçons de 3ème | 2 exercices par notion (le 2e de 6 questions), 4 sujets de 4 exercices de 5 ou 6 questions. |
| Matières sans calcul ? | Même structure, à la manière d'une épreuve | Philosophie, Français, SVT : texte ou document puis questions corrigées automatiquement, aucune `written` ; phrases complètes en QCM. |
| Comment prouver le fond ? | Script hors dépôt, même méthode qu'en 3ème | sympy et réponses faussées exprès en Mathématiques et Physique-Chimie ; extrait mot pour mot de la leçon ailleurs. |
| Découpage ? | Un chantier, une PR, un commit par matière | Mathématiques d'abord, puis Français, Philosophie, Physique-Chimie, SVT. |

## Cas limites identifiés

- Une leçon de `tle-c` qui a la même fiche dans `tle-d`, `tle-a1` ou `tle-a2` n'est changée qu'ici ; le chantier du dossier suivant reprend les mêmes ajouts.
- Une figure n'est ajoutée qu'avec une sorte existante de `figure_kinds.rb` ; sans sorte adaptée, pas de figure.

## Questions encore ouvertes

- Aucune.
