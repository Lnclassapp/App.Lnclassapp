# UDR-NNNN : [Titre — quelle surface d'interface]
<!-- index
titre: [titre court de l'index]
statut: Accepté
adr-lie: [NNNN](../adr/NNNN-slug.md)
problematique: [une phrase : le problème d'interface que la décision tranche]
-->
<!--
  Nom du fichier : NNNN-titre-en-kebab-case.md
  Une UDR n'est pas un compte-rendu de design : c'est une CONSIGNE EXÉCUTABLE.
  Un agent doit pouvoir écrire la vue à partir de la seule section 3, sans poser de question.
  Après création : ajouter la ligne correspondante dans docs/decisions/udr/README.md
-->

| | |
|---|---|
| **Statut** | Proposé · Accepté · Déprécié · Remplacé |
| **Date** | AAAA-MM-JJ |
| **Chantier** | `docs/chantiers/<slug>` |
| **ADR lié** | ADR-NNNN *(le cas échéant)* |
| **Remplacé par** | — |

---

## 1. Contexte

Quelle friction utilisateur ? Qui la subit, à quel moment de son parcours, et qu'est-ce que ça lui coûte ?

## 2. Décision

Ce qui a été retenu côté expérience, et **pourquoi ce choix plutôt qu'un autre** (slide-over plutôt que modale, Turbo Frame plutôt que rechargement, etc.).

## 3. Règles d'implémentation

> Cette section est un **contrat d'exécution**. Un agent l'applique littéralement.

**Structure**
- Composant de référence : `app/views/components/_xxx.html.erb`
- Hiérarchie des blocs, du conteneur à l'élément

**Tokens**
- Couleurs : variables du design system uniquement, jamais de valeur en dur
- Typographie : …
- Espacements et rayons : …

**Comportement**
- Turbo Frame / Turbo Stream : quel `id`, quelle cible, quel fallback sans JS
- Contrôleur Stimulus : lequel, quelles `data-*`

**États obligatoires**
- Vide · Chargement · Erreur · Succès

**Accessibilité**
- Cibles tactiles ≥ 48×48 px
- Contraste, focus visible, `aria-*` requis, ordre de tabulation

## 4. Conséquences

Ce que cette décision impose au reste de l'interface, et ce qu'elle interdit désormais.
