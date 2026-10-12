# 📰 Template PR/FAQ (Working Backwards - Amazon Standard)

> **Document de 4 à 6 pages maximum (Six-Pager)**
> Utilisé pour aligner l'équipe sur la valeur client, lever les incertitudes techniques et opérationnelles avant d'écrire la moindre ligne de code.

---

## PARTIE 1 : Le Communiqué de Presse (Press Release - 1 Page)
*Le PR décrit la fonctionnalité comme si elle était déjà lancée aujourd'hui. Il doit être rédigé avec un langage simple, sans jargon technique.*

### Titre (Headline)
> *Exemple : Lnclass lance le nouveau module d'exercice "Objectif BAC 2026" ultra-rapide sur mobile.*

### Sous-titre (Sub-headline)
> *Une phrase expliquant qui est la cible et quel est le bénéfice principal.*

### Résumé (Summary)
> *Résumé du lancement et de la valeur apportée.*

### Le Problème (The Problem)
> *Décrire la frustration actuelle de l'utilisateur (Ex: lenteurs sur mobile, manque d'interactivité).*

### La Solution (The Solution)
> *Expliquer comment ce nouveau produit résout élégamment le problème.*

### Citation de l'Équipe (Leader Quote)
> *Une citation du Product Owner ou Lead Architect expliquant la vision derrière le produit.*

### Citation Client (Customer Quote)
> *Une citation fictive mais réaliste d'un élève décrivant sa joie d'utiliser le module d'exercice.*

### Comment Démarrer (How to Get Started)
> *Le parcours ultra-simple pour commencer à utiliser le service.*

### Appel à l'Action (Call to Action / Pricing)
> *Exemple : "Disponible dès aujourd'hui gratuitement sur l'application mobile Lnclass".*

---

## PARTIE 2 : Les Questions Fréquentes Externes (Customer FAQs - 2 Pages)
*Questions qu'un Élève, Enseignant ou Parent pourrait poser lors du lancement.*

*   **Q1 : Est-ce que cette fonctionnalité consomme beaucoup de données internet ?**
    *   *R : Non, nous avons optimisé...*
*   **Q2 : L'application fonctionne-t-elle hors ligne ?**
    *   *R : ...*
*   **Q3 : Est-ce compatible avec tous les smartphones Android, même anciens ?**
    *   *R : ...*

---

## PARTIE 3 : Les Questions Fréquentes Internes (Internal & Technical FAQs - 3 Pages)
*Questions difficiles posées par l'équipe d'ingénierie, de design, ou de direction.*

### Stratégie & Produit
*   **Q1 : Quelles sont les métriques clés (KPIs) qui mesureront le succès de cette feature ?**
    *   *R : ...*
*   **Q2 : Quel est le coût de serveur estimé si 10 000 élèves se connectent simultanément pendant le BAC ?**
    *   *R : ...*

### Architecture & Technique (Hexagonal & Strada)
*   **Q3 : Pourquoi avoir choisi Strada au lieu de React Native ou Flutter pour la partie mobile ?**
    *   *R : Strada permet de réutiliser 95% de notre code HTML/Tailwind en encapsulant l'application web dans un conteneur natif léger, réduisant les coûts de développement par 3.*
*   **Q4 : Comment garantit-on que la logique d'attribution des badges dans le Domaine n'est pas contournée en modifiant les requêtes HTTP ?**
    *   *R : La vérification et la sauvegarde du score et du badge se font uniquement côté serveur dans le Use Case `CompleteExerciseSession`. Le client n'envoie que les réponses saisies, jamais son score.*
*   **Q5 : Comment gère-t-on le cas où le réseau coupe en plein milieu de la soumission d'une réponse ?**
    *   *R : Le repository utilise une approche idempotente...*
