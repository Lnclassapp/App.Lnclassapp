# UDR-0003 : Moteur d'Évaluation & Gamification (Assessment UI)
<!-- index
titre: Moteur d'évaluation & gamification (Assessment UI)
statut: Accepté · Tokens remplacés par 0005
adr-lie: [0008](../adr/0008-moteur-evaluation-et-gamification.md)
problematique: Offrir une expérience d'exercice immersive sans rechargement (Turbo Frames), centrée sur la progression visible et la récompense (badges Argent, Or, Diamant).
-->

> ⚠️ **Remplacée partiellement par [UDR-0005](./0005-design-system-fondateur.md)** (2026-09-25) : la section « Tokens » ne s'applique plus. Utilisez les tokens `@theme` et la table de correspondance de l'UDR-0005 §3. Les autres sections restent valables.

| | |
|---|---|
| **Statut** | Remplacé partiellement — *voir l'avertissement ci-dessous* |
| **Date** | — |
| **Chantier** | — |
| **ADR lié** | [ADR-0008 — Moteur d'évaluation et gamification](../adr/0008-moteur-evaluation-et-gamification.md) |
| **Remplacé par** | [UDR-0005](./0005-design-system-fondateur.md) *(section « Tokens »)*, [UDR-0007](./0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) *(vocabulaire)*, [ADR-0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md) *(badges)* |

---

> ⚠️ **Vocabulaire remplacé — plus de « Quiz », quatre badges.**
> Le 2026-09-25, « Quiz interactif » est remplacé par « Exercice » ([UDR-0007](./0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md)). Les badges sont Bronze (≥ 50 %), Argent (≥ 70 %), Or (≥ 80 %) et Diamant (100 %, sans faute) : le « Diamant » cité ici est défini par l'[ADR-0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md). Le reste de cette UDR reste en vigueur.

## 1. Contexte

Les élèves ont besoin d'une interface immersive, sans rechargement, pour réaliser leurs exercices. Les enseignants doivent pouvoir assigner des exercices facilement et voir les performances. Le système d'évaluation intègre un volet "Gamification" (Badges : Argent, Or, Diamant) pour engager les étudiants.

## 2. Décision

Nous adoptons une expérience utilisateur asynchrone (Hotwire / Turbo Frames) de type "Quiz interactif" ou "Flashcard".
La navigation entre les questions se fait de manière fluide avec des micro-animations de transition.
L'accent visuel est mis sur la progression (barre de progression visible) et la récompense (badges stylisés).

## 3. Règles d'implémentation

> Contrat d'exécution — reprise intégrale de la section « Règles d'implémentation pour l'Agent IA » du document d'origine.

**Tokens**
- **Couleurs & Thème :** Continuité avec le thème (Fond ivoire `bg-slate-50`, texte marine `text-secondary`, accent `text-primary-600`).
- **Gamification :**
  - Argent (`bg-slate-100 text-slate-500 border-slate-200`)
  - Or (`bg-yellow-50 text-yellow-600 border-yellow-200`)
  - Diamant (`bg-cyan-50 text-cyan-600 border-cyan-200`)

**Comportement**
- **Animations / Interactions :**
  - La barre de progression doit avoir un `transition-all duration-500 ease-out`.
  - Les cartes de questions (`_question_card`) doivent paraître flottantes (`shadow-sm`, `rounded-2xl`).
  - Lors de la sélection d'une réponse, utiliser des transitions douces sur le conteneur `label` (`hover:bg-gray-50 transition-colors`).
- **Architecture de la vue :**
  - Le changement de question s'effectue dans un `<turbo-frame id="question_frame">`.
  - Les erreurs ou feedbacks s'affichent dynamiquement au-dessus de la question.

**États obligatoires**
- Erreur : feedback affiché dynamiquement au-dessus de la question.
- Vide · Chargement · Succès : — *(non documenté)*

**Accessibilité**
- — *(non documenté)*

## 4. Conséquences

- L'expérience élève est drastiquement améliorée et semble native (aucune page blanche).
- Complexité gérée côté serveur via Hotwire plutôt que d'alourdir le frontend avec une application React/Vue.
