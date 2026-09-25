# UDR-0001 : Design Visuel du Catalogue Pédagogique

> ⚠️ **Remplacée partiellement par [UDR-0005](./0005-design-system-fondateur.md)** (2026-09-25) : la section « Tokens » ne s'applique plus. Utilisez les tokens `@theme` et la table de correspondance de l'UDR-0005 §3. Les autres sections restent valables.

| | |
|---|---|
| **Statut** | Remplacé partiellement — *voir l'avertissement ci-dessous* |
| **Date** | — |
| **Chantier** | — |
| **ADR lié** | [ADR-0022 — Modélisation hexagonale du catalogue pédagogique](../adr/0022-modelisation-hexagonale-du-catalogue-pedagogique.md) |
| **Remplacé par** | [UDR-0005](./0005-design-system-fondateur.md) *(section « Tokens »)*, [UDR-0007](./0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) *(vocabulaire)* |

---

> ⚠️ **Vocabulaire remplacé — « Fiche essentielle ».**
> Le terme « essentiels (habiletés) » est remplacé par l'[UDR-0007](./0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) le 2026-09-25 : l'interface écrit « Fiche essentielle », jamais « Habileté ». Le reste de cette UDR reste en vigueur.

## 1. Contexte

Le catalogue pédagogique est la porte d'entrée principale pour les élèves et les professeurs. Le design précédent manquait de clarté hiérarchique et affichait trop d'informations d'un coup (comme les listes complètes d'essentiels sur la carte du cours), créant une surcharge cognitive. Il fallait définir une direction visuelle forte, professionnelle et engageante.

## 2. Décision

### 1. L'Intention "Étude Premium"
L'interface doit évoquer le sérieux de l'apprentissage tout en restant moderne et dynamique. 
- **Couleurs de fond** : Utilisation d'un ivoire très clair (`bg-slate-50`) pour le fond général, rappelant le papier et reposant les yeux.
- **Typographie** : Contraste fort. Les titres de cours utilisent un bleu très profond (`text-slate-900`) avec une graisse élevée (`font-extrabold`) pour ancrer le regard.

### 2. La Signature Visuelle : Le Badge de Matière
Au lieu d'utiliser de grandes images de couverture génériques, la carte s'appuie sur une icône de matière lumineuse générée dynamiquement via le helper `subject_palette_for`.
- Le badge flotte dans un carré aux coins arrondis, coloré spécifiquement pour la matière (ex: Vert pour SVT, Bleu pour Physique).
- Il possède un léger effet `scale` au survol pour donner vie à la carte.

### 3. Épuration Extrême (Retrait des Essentiels)
Après itération, il a été décidé de **ne pas afficher la liste des essentiels (habiletés) sur la carte du cours**.
- **Pourquoi ?** L'affichage de sous-listes rendait les cartes trop hautes et brisait la grille visuelle du catalogue. La carte du catalogue doit rester une simple "vitrine" invitant au clic. Les détails du cours seront consultés sur la page `show` du cours.

### 4. Composants et Ombres (Layered Depth)
- Les cartes de cours n'ont pas de bordures dures ou épaisses.
- Elles utilisent un fond blanc pur (`bg-white`), une bordure quasi-invisible (`border-slate-100`) et une ombre très douce (`shadow-[0_2px_12px_rgba(...)`).
- Au survol, la carte se soulève (`-translate-y-1.5`) et l'ombre s'intensifie, signalant clairement la nature cliquable de l'ensemble de la carte.

## 3. Règles d'implémentation

> Contrat d'exécution — reformulation des règles déjà énoncées en section 2. Aucune règle nouvelle n'a été ajoutée lors de la normalisation.

**Structure**
- Composant de référence : `app/views/components/courses/_course_card.html.erb` — source de vérité du design, à réutiliser partout où un cours est listé.
- La carte est une vitrine : titre + badge de matière. **Ne jamais y afficher la liste des essentiels / habiletés.**

**Tokens**
- Fond général de page : `bg-slate-50` (ivoire très clair).
- Fond de carte : `bg-white` ; bordure `border-slate-100` ; ombre `shadow-[0_2px_12px_rgba(...)]`.
- Titre de cours : `text-slate-900` + `font-extrabold`.
- Couleur du badge de matière : jamais en dur — obtenue via le helper `subject_palette_for`.

**Comportement**
- Survol de la carte : `-translate-y-1.5` + intensification de l'ombre ; l'intégralité de la carte est cliquable.
- Survol du badge de matière : léger effet `scale`.
- Turbo Frame / Stimulus : — *(non documenté)*

**États obligatoires**
- — *(non documenté)*

**Accessibilité**
- — *(non documenté)*

## 4. Conséquences

- **Développement** : Le composant `app/views/components/courses/_course_card.html.erb` est désormais la source de vérité pour ce design et doit être réutilisé partout où un cours est listé.
- **Backend** : Le contrôleur n'a plus besoin de pré-charger les `.essentials` lors du rendu de la liste `index` (gain de performance SQL), puisque ces informations ne sont plus affichées sur la carte.
