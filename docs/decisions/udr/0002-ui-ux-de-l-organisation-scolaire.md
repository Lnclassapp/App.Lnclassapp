# UDR-0002 : UI/UX de l'Organisation Scolaire

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | — |
| **Chantier** | — |
| **ADR lié** | [ADR-0023 — Modélisation de l'organisation scolaire](../adr/0023-modelisation-de-l-organisation-scolaire.md) |
| **Remplacé par** | — |

---

## 1. Contexte

L'espace permettant d'afficher et de gérer les écoles, les DRENAs et les classes doit être repensé. Actuellement (ou dans la vision cible), cet espace est potentiellement lourd et administratif. L'objectif est de le rendre clair, hiérarchique et aligné avec la philosophie *Premium* définie dans `system.md`.

## 2. Décision

### Hiérarchie Visuelle Forte
- **L'École comme Pilier** : Les écoles sont affichées sous forme de cartes d'identité claires (Logo ou initiales, Sigle, Nom complet, Statut).
- **Indicateurs de Statut** : Utilisation de badges (Pills) pour le type (`Public`, `Privé`) et le statut de validation (`Actif`, `En attente`) en s'appuyant sur les couleurs Tailwind (`bg-green-100 text-green-800` pour actif).

### Espaces d'Action Dédiés (Focus)
- Les actions d'édition ou de création ne se feront pas dans des popups (modales) surchargées, mais via la navigation dans des pages dédiées ou des `Turbo Frames` de tiroir latéral (Slide-over) pour ne pas perdre le contexte.

### Micro-interactions
- Comme pour le catalogue, les cartes d'écoles (composant `_school_card.html.erb`) bénéficieront du soulèvement au survol (`hover:-translate-y-1 shadow-lg`) pour encourager le clic.
- La navigation interne de l'école (vers ses "Classes") se fera via des onglets (Tabs) discrets sous le nom de l'école.

## 3. Règles d'implémentation

> Contrat d'exécution — reprise intégrale des règles de structure et du composant de référence décrits dans le document d'origine.

**Structure de la vue principale (ex : `/schools`)**
- **Header** : Titre massif "Établissements" + Bouton Primaire (Bleu 600) "Nouvelle École".
- **Filtres** : Barre de recherche simple + Sélecteur DRENA (Menu déroulant propre).
- **Grille (Grid)** : `grid-cols-1 md:grid-cols-2 lg:grid-cols-3` pour afficher les cartes d'établissements de manière aérée.
- **Empty State** : Un composant d'état vide amical (Icône de bâtiment gris clair + "Aucune école trouvée").

**Composant clé : School Card**
- Composant de référence : `_school_card.html.erb`

```html
<div class="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm hover:shadow-md transition-all">
  [Sigle/Avatar] [Nom]
  [Type: Privé/Public] [DRENA]
  [Actions (Ouvrir / Classes)]
</div>
```

**Tokens**
- Carte : `bg-white rounded-2xl border border-slate-200 p-5 shadow-sm`.
- Badge de statut actif : `bg-green-100 text-green-800`.
- Bouton primaire : Bleu 600.

**Comportement**
- Survol de carte : `hover:-translate-y-1 shadow-lg` (et `hover:shadow-md transition-all` sur le composant).
- Création / édition : page dédiée ou `Turbo Frame` de type slide-over. **Jamais de modale.**
- Navigation école → classes : onglets (Tabs) discrets sous le nom de l'école.

**États obligatoires**
- Vide : composant d'état vide (icône de bâtiment gris clair + "Aucune école trouvée").
- Chargement · Erreur · Succès : — *(non documenté)*

**Accessibilité**
- — *(non documenté)*

## 4. Conséquences

*Section absente du document d'origine. Les points ci-dessous sont déduits littéralement des règles énoncées en sections 2 et 3, sans ajout de décision nouvelle.*

- Toute vue de création ou d'édition d'école ou de classe doit être une page dédiée ou un slide-over en Turbo Frame : l'usage des modales est exclu sur cette surface.
- `_school_card.html.erb` devient le composant de référence pour représenter un établissement ; toute nouvelle liste d'écoles doit le réutiliser plutôt que de redéfinir sa propre carte.
- Toute liste d'établissements doit prévoir un état vide, la grille responsive `1 / 2 / 3` colonnes et le couple recherche + filtre DRENA.
