# UDR-0003 : Moteur d'Évaluation & Gamification (Assessment UI)

> ⚠️ **Remplacée partiellement par [UDR-0005](./0005-design-system-fondateur.md)** (2026-09-25) : la section « Tokens » ne s'applique plus. Utilisez les tokens `@theme` et la table de correspondance de l'UDR-0005 §3. Les autres sections restent valables.

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | — |
| **Chantier** | — |
| **ADR lié** | [ADR-0008 — Moteur d'évaluation et gamification](../adr/0008-moteur-evaluation-et-gamification.md) |
| **Remplacé par** | [UDR-0005](./0005-design-system-fondateur.md), section « Tokens » seulement |

---

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
