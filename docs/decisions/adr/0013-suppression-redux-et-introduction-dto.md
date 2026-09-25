# ADR-0013 : Suppression de Redux, Maintien de Yarn et Introduction des DTO

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-08-12 |
| **Chantier** | — |
| **Remplace** | ADR-0009 *(partie Redux)* |
| **Remplacé par** | — |

---

> ℹ️ **Cet ADR remplace la partie « Redux » de l'[ADR-0009](./0009-stack-frontend-vanilla-css-tailwind-hotwire.md).** Les autres décisions frontend de l'ADR-0009 (Tailwind v4, Hotwire, KaTeX) restent en vigueur.

## 1. Contexte et problématique
Migration Lnclassapp vers Rails 8.

L'ancienne application souffrait de trois problèmes majeurs :
1. **Frontend sur-engagé** : La présence de `@reduxjs/toolkit` dans un écosystème dominé par Hotwire/Turbo allait à l'encontre de la philosophie "HTML over the wire", alourdissant le client inutilement.
2. **Couplage Métier/Web** : Les contrôleurs passaient des hachages de paramètres (`ActionController::Parameters.to_h`) directement aux Use Cases de la couche Domaine. Cela fragilisait le métier face aux changements d'interface.

## 2. Décision

### 2.1 Suppression totale de Redux
* Redux est officiellement banni du nouveau projet.
* L'état local du client (thème sombre, ouverture/fermeture de la barre latérale, etc.) sera exclusivement géré par des contrôleurs **Stimulus** (`@hotwired/stimulus`) stockant éventuellement leur état dans le `localStorage` ou les attributs de données du DOM.

### 2.2 Introduction du pattern DTO (Data Transfer Object)
* Pour garantir l'isolation totale de la couche Domaine (`app/domain`), aucun paramètre brut issu des contrôleurs Rails ne doit traverser la frontière hexagonale.
* Les requêtes web doivent être encapsulées, validées, et transformées en objets Ruby purs (`Dtos::NomInput`) avant d'être envoyées aux `UseCases`.

### 2.3 Utilisation de Yarn et Propshaft
* Le projet maintient **Yarn** comme gestionnaire de dépendances pour l'écosystème Node.js/JavaScript, et utilise **Propshaft** pour la gestion native des assets.

## 3. Conséquences
* **Avantages** : Un frontend beaucoup plus léger, une architecture métier infaillible (anti-corruption), et des builds JS/CSS stables.
* **Inconvénients** : Légère verbosité supplémentaire côté serveur (création obligatoire de classes DTO pour chaque action complexe). L'équipe devra apprendre à concevoir en mode "Data Contracts".
