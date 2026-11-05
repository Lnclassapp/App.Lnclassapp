# Memo — Les leçons de 3ème préparées comme Thalès

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-05 |
| **Branche** | `feature/lecons-3eme-comme-thales` |
| **Ticket** | [#484](https://github.com/Lnclassapp/App.Lnclassapp/issues/484), étape 1 |

---

## Le problème

Deux leçons de 3ème seulement sont complètes pour les feuilles « Prépare interros » et « Prépare devoirs » : Thalès et Calcul littéral.
Les 58 autres leçons v3 de 3ème n'ont qu'un exercice par notion et aucun sujet : leur section « Prépare devoirs » ne se montre pas.

## Pour qui

L'élève de 3ème qui prépare une interro, un devoir ou le BEPC, dans toutes les matières ; l'enseignant qui envoie un sujet à sa classe.

## Pourquoi maintenant

Le pilote a validé les deux modèles et fixé l'ordre (#484) : la 3ème d'abord, puis la Terminale, la 1ère sur demande.

## Hors périmètre

- La Terminale (étape 2) et la 1ère (étape 3) : chantiers suivants.
- Le cours, les fiches des notions, le 1er exercice de chaque notion et les 4 exercices « Toute la leçon » : inchangés, octet pour octet.
- L'écran et le code : rien ne change, donc ni ADR ni UDR.
- Staging et production : aucun import à la main.

## Ce que le grill a révélé

Les décisions ont été prises par le pilote dans #484 (2026-11-05), à appliquer telles quelles.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quel modèle ? | Thalès et Calcul littéral | 2 exercices par notion (le 2e de 6 questions), 4 sujets de 4 exercices de 5 ou 6 questions. |
| Matières sans calcul ? | Même structure, à la manière d'une épreuve | Texte ou document puis questions, seulement des types corrigés automatiquement, aucune question rédigée. |
| Comment prouver le fond ? | Script hors dépôt | sympy en mathématiques et physique-chimie ; extrait de la fiche pour chaque bonne réponse ailleurs. |
| Découpage ? | Un chantier, une PR, un commit par matière | Mathématiques d'abord, puis EDHC, français, histoire-géographie, physique-chimie, SVT. |

## Cas limites identifiés

- Une réponse à saisir n'est qu'un mot ou un nombre court, avec ses écritures raisonnables ; une phrase se choisit dans un QCM.
- Une figure n'est ajoutée qu'avec une sorte existante de `figure_kinds.rb` ; sans sorte adaptée, pas de figure.

## Questions encore ouvertes

- Aucune.
