# ADR-0009 : Stack Frontend Moderne — Vanilla CSS, Tailwind CSS v4, Hotwire (Turbo/Stimulus) & KaTeX

| | |
|---|---|
| **Statut** | Remplacé partiellement — *voir l'avertissement ci-dessous* |
| **Date** | 2026-07-22 |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | ADR-0013 *(partie Redux uniquement)* |

---

> ⚠️ **Décision partiellement remplacée — Redux a été retiré du projet.**
> La partie « **Redux Toolkit / `store.js`** » de cet ADR (§ 3, point 3) **n'est plus en vigueur** : l'[ADR-0013](./0013-suppression-redux-et-introduction-dto.md) a banni Redux du projet le 2026-08-12. L'état local du client est désormais géré **exclusivement par des contrôleurs Stimulus**.
> Toutes les autres décisions de cet ADR — **Tailwind CSS v4**, **Hotwire (Turbo Drive / Frames / Streams)**, **Stimulus** et **KaTeX** — restent pleinement en vigueur.
> Complété le 2026-09-25 par le porteur : tous les CRUD passent par Hotwire (§3, point 6).

## 1. Contexte et problématique
Lors du choix d'une architecture pour une application éducative riche (LMS), l'industrie pousse fréquemment vers la création d'une **Single Page Application (SPA)** lourde avec React, Vue ou Angular, communiquant avec un backend par une API REST ou GraphQL.

Dans notre contexte d'utilisation et de développement :
* Une SPA découplée double la charge de travail (maintenance de deux dépôts, gestion complexe de l'état asynchrone, routage dupliqué, problèmes de SEO sur les pages de catalogue de cours).
* Sur les smartphones de milieu et d'entrée de gamme en Côte d'Ivoire (souvent en réseau 3G/4G instable), télécharger un bundle JavaScript de plusieurs mégaoctets ralentit dramatiquement le temps d'affichage initial (Time to Interactive).
* De plus, les cours et exercices d'examen (BAC et BEPC en Mathématiques, Physique et Chimie) nécessitent un rendu irréprochable et instantané des **formules scientifiques en LaTeX** sans casser les transitions de page.

---

## 2. Moteurs de décision
* **Performance sur Réseaux Africains :** Minimiser la quantité de JavaScript transmise au client en privilégiant le rendu côté serveur (SSR) hyper-rapide de Rails.
* **Réactivité Moderne (SPA-like UX) :** Offrir des transitions de page instantanées, des modals sans rechargement et des mises à jour dynamiques du DOM.
* **Productivité et Cohérence Visuelle :** Utiliser un Design System unifié basé sur des classes utilitaires pré-compilées (**Tailwind CSS v4**).
* **Rendu Mathématique Scientifique :** Intégrer un moteur LaTeX rapide (KaTeX) qui s'exécute de manière fiable à chaque changement de vue.

---

## 3. Décision
Nous avons pris la décision de rejeter le modèle SPA lourd au profit de la **Stack HTML-over-the-Wire (Hotwire)** native de Rails 8 :
1. **Turbo Drive & Turbo Frames :** Pour des navigations instantanées et l'isolation des formulaires (ex: ajouter une classe ou un exercice sans recharger la page principale).
2. **Turbo Streams :** Pour insérer, modifier ou supprimer des éléments HTML du DOM en réponse à des actions HTTP (ex: `create.turbo_stream.erb`).
3. **Stimulus & Redux Toolkit (`store.js`) :** Pour les interactions UI locales (ouverture de menus déroulants, animations, gestion du thème sombre/clair via un mini-store Redux synchronisé au DOM).
4. **Tailwind CSS v4 :** Compilé nativement pour générer des feuilles de style ultra-légères en utilisant nos composants normés (`card-ln`, `badge-success`).
5. **KaTeX via Hook Turbo :** Dans `application.js`, un écouteur sur l'événement `turbo:load` invoque `renderMathInElement` sur l'ensemble du body pour convertir instantanément les balises `$$...$$` et `$...$` en équations mathématiques stylisées.
6. **Tous les CRUD en Hotwire** *(ajout du porteur, 2026-09-25)* : chaque écran de création, modification ou suppression (DRENA, établissements, classes, taxonomie, contenu, comptes) s'édite dans un Turbo Frame et met la liste à jour par un Turbo Stream, sans rechargement complet de la page. Une réponse HTML classique reste le repli sans JavaScript.

---

## 4. Conséquences

### 🟢 Positives
* **Vitesse de Chargement Exceptionnelle :** Le HTML initial arrive en quelques millisecondes. L'application est fluide et réactive, même sur un mobile Android en 3G.
* **Productivité de l'Équipe :** Pas besoin d'écrire de sérialiseurs JSON complexes ou d'entretenir un routeur frontend : Rails gère tout.
* **Rendu Scientifique Impeccable :** Les élèves consultent des sujets de BAC en physique et maths avec des intégrales et fractions parfaitement formatées.

### 🔴 Coûts consentis
* **Discipline Hotwire :** Les développeurs doivent bien comprendre la différence entre un `turbo_frame` (qui s'attend à recevoir un fragment HTML correspondant) et un `turbo_stream` (qui ordonne au navigateur des actions sur le DOM).

---

## 5. Notes d'implémentation

Extrait de `app/javascript/application.js` montrant le couplage harmonieux entre Turbo et KaTeX :
```javascript
// app/javascript/application.js
import "@hotwired/turbo-rails"
import "./controllers"

// Rendu automatique et instantané des équations KaTeX après chaque transition Turbo
document.addEventListener("turbo:load", () => {
  document.documentElement.classList.remove("turbo-loading")
  if (typeof renderMathInElement === "function") {
    renderMathInElement(document.body, {
      delimiters: [
        {left: '$$', right: '$$', display: true},
        {left: '$', right: '$', display: false}
      ],
      throwOnError: false
    })
  }
})
```

Exemple d'une réponse **Turbo Stream** (`create.turbo_stream.erb`) qui injecte en direct la nouvelle classe créée par un enseignant dans l'arborescence :
```erb
<%# app/views/classrooms/create.turbo_stream.erb %>
<%# 1. Ajoute instantanément la nouvelle classe en tête de liste sans recharger la page %>
<%= turbo_stream.prepend nested_dom_id(@school, "classrooms"), partial: "classrooms/classroom", locals: { classroom: @classroom } %>

<%# 2. Réinitialise le formulaire de création %>
<%= turbo_stream.update nested_dom_id(@school, Orm::Classroom.new), "" %>

<%# 3. Affiche la notification de confirmation %>
<%= render_flash_stream %>
```
