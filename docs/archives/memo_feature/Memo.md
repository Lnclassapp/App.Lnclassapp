# 📝 [Feature Name] - Memo Produit & UX

> **Focus :** Vision Produit, Spécifications Fonctionnelles, Expérience Utilisateur (UI/UX) et Critères d'Acceptation.
> **Date de création :** YYYY-MM-DD
> **Statut :** [Brouillon / En Cours / Validé]

---

## 1. Description du Problème & Valeur Métier
* **Quoi ?** (Résumé succinct de la fonctionnalité)
* **Pourquoi ?** (Quel problème utilisateur ou opportunité business cela résout-il ?)
* **Qui ?** (Cibles principales : Élève, Enseignant, École, Admin)
* **Valeur attendue :** (Performance, conversion, engagement, etc.)

---

## 2. Parcours Utilisateur (User Flows)
Décrire le cheminement de l'utilisateur étape par étape.

### 2.1. Parcours Principal (Happy Path)
1. **Étape 1 :** L'utilisateur arrive sur ...
2. **Étape 2 :** L'utilisateur clique sur ...
3. **Étape 3 :** L'utilisateur voit ...

### 2.2. Parcours Alternatifs & Edge Cases
* **Cas Limite A (Ex: Réseau instable/hors-ligne) :** Comment l'application doit-elle se comporter ?
* **Cas Limite B (Ex: Donnée manquante) :** Que se passe-t-il si ... ?
* **Cas Limite C (Ex: Interruption de session) :** ...

---

## 3. Spécifications UI/UX (Mobile-First & Hotwire Native)
*Lnclass étant une application hybride, l'expérience sur mobile via Hotwire Native est critique.*

### 3.1. Design Mobile-First & Animations
* **Comportement Responsif :** 
  * Éléments masqués sur mobile : `turbo-native:hidden` ou `hidden md:block`.
  * Zones de clic tactiles d'au moins **48x48px** pour éviter les erreurs de ciblage.
* **Micro-interactions & États :**
  * **Hover/Active :** États actifs avec retour tactile immédiat (ex: opacité réduite ou changement léger de couleur au touch).
  * **Chargement (Loading states) :** Boutons désactivés avec spinner pendant la soumission, utilisation d'écrans squelettes (Skeleton Screens) pour le contenu.
  * **États vides (Empty states) :** Message clair, illustration et bouton d'appel à l'action pour les listes vides.

### 3.2. Intégrations Hybrides (Strada & Composants Natifs)
* **Pont Strada :** Quels composants doivent être délégués au natif pour une expérience irréprochable ?
  * *Exemple : Barre de progression native, boîte de dialogue de confirmation native, ou menu contextuel natif.*
* **Comportement de la Navigation :**
  * Push de nouvel écran (présentation classique).
  * Modal native (présentation de formulaire ou de filtre).

---

## 4. Critères d'Acceptation & Scénarios de Test (Gherkin)
Ces critères servent de contrat de validation pour le développement et la QA.

### Scénario 1 : [Titre du scénario principal]
* **Étant donné que** [contexte initial]
* **Quand** [l'action utilisateur]
* **Alors** [le résultat attendu dans l'UI]

### Scénario 2 : [Titre du scénario alternatif / erreur]
* **Étant donné que** [contexte d'erreur]
* **Quand** [l'action utilisateur]
* **Alors** [affichage d'un Toast d'erreur / blocage de l'action]
