# ADR-NNNN : [Titre de la décision, à l'affirmative]

<!--
  Nom du fichier : NNNN-titre-en-kebab-case.md — 4 chiffres, séquentiel, jamais réutilisé.
  Vérifier le dernier numéro : ls docs/decisions/adr/ | tail -3
  Après création : ajouter la ligne correspondante dans docs/decisions/adr/README.md
-->

| | |
|---|---|
| **Statut** | Proposé · Accepté · Déprécié · Remplacé |
| **Date** | AAAA-MM-JJ |
| **Chantier** | `docs/chantiers/<slug>` |
| **Remplace** | — *(ou ADR-NNNN)* |
| **Remplacé par** | — *(ou ADR-NNNN)* |

---

## 1. Contexte et problématique

Quelle situation a rendu cette décision nécessaire ? Quel problème concret se posait, et qu'est-ce qui rendait le statu quo intenable ?

Écrire pour quelqu'un qui découvre le projet dans deux ans. Le contexte est la partie la plus précieuse d'un ADR : la décision se devine souvent, le contexte jamais.

## 2. Moteurs de décision

Les critères qui ont pesé, par ordre d'importance.

- …
- …

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — … | | |
| B — … | | |

*Si une seule option a été sérieusement envisagée, le dire — c'est une information.*

## 4. Décision

Ce qui a été retenu, formulé à l'affirmative et sans ambiguïté.

> **Nous …**

## 5. Conséquences

### 🟢 Positives

- …

### 🔴 Coûts consentis

- …

*Un ADR sans coût consenti est un ADR qui n'a pas été écrit honnêtement.*

## 6. Notes d'implémentation

Du **code réel du projet**, pas du pseudo-code, avec le chemin du fichier. C'est ce qui permet à un agent de reproduire la décision plutôt que de la réinterpréter.

```ruby
# app/domain/…
```

## 7. Comment vérifier que la décision est respectée

Le test, le cop rubocop ou la commande qui échoue si quelqu'un contrevient à cette décision. Si rien ne peut le vérifier automatiquement, le dire explicitement — et considérer que la décision tiendra mal.
