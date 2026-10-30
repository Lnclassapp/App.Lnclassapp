# UDR-0143 : Carrousel des classes de l'enseignant — « précédentes » et « suivantes » sur ordinateur
<!-- index
titre: Carrousel des classes de l'enseignant : boutons précédent et suivant dès lg
statut: Accepté
adr-lie: —
problematique: À la souris, la bande des classes de l'accueil enseignant ne défile pas (molette verticale, barre masquée) et ne revient pas au début ; deux boutons ronds encadrent les points dès lg, annoncés grisés à leur bout. Complète l'UDR enseignant §3.3
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-30 |
| **Chantier** | `docs/chantiers/carrousel-classes-enseignant` |
| **ADR lié** | — |
| **Remplacé par** | — |

---

## 1. Contexte

Dès 1280 px, l'accueil enseignant montre ses classes en bande de cartes de 16,5 rem, la quatrième coupée au bord (UDR enseignant §3.3). Sa barre de défilement est masquée et la molette d'une souris est verticale : l'enseignant avance en tabulant, mais ne peut plus revenir au début.

## 2. Décision

Deux boutons ronds, « Classes précédentes » et « Classes suivantes », encadrent les points, dès `lg` seulement. Au téléphone, le doigt suffit : rien ne change. Un bouton à son bout reste en place, grisé et annoncé (`aria-disabled`), plutôt que masqué : la ligne ne bouge pas et le focus clavier n'est pas perdu.

## 3. Règles d'implémentation

**Structure**
- Ligne des points (`data-communication--carousel-target="pager"`, `hidden items-center justify-center gap-3 pt-3`, rendue `flex` par le contrôleur quand la bande déborde) : bouton « précédentes », points (`span.flex.gap-1.5[aria-hidden]`), bouton « suivantes ».
- Bouton : `button[type=button]`, `aria-controls="teacher_home_classrooms_track"` (id de la bande), icône mini `chevron-left` / `chevron-right`, libellé en `sr-only` (`classroom.teacher_homes.show.previous_classrooms` / `next_classrooms`).

**Tokens**
- `size-tap rounded-full border border-line bg-white text-brand-strong hover:bg-mist` ; focus `outline-2 outline-brand` ; au bout `aria-disabled:opacity-50`, sans survol.
- Visible dès `lg` seulement (`hidden lg:grid`).

**Comportement**
- Contrôleur `communication--carousel`, cibles facultatives `previous` / `next`, actions `#previous` / `#next` : la bande défile d'une largeur (`scrollBy`, lisse sous `motion-safe`, aimantée par `snap-start`).
- `aria-disabled="true"` au début pour « précédentes », à la fin pour « suivantes », recalculé à chaque défilement ; un clic sur un bouton au bout ne fait rien.
- Sans JavaScript : la ligne reste cachée, la bande défile comme avant.

**Accessibilité**
- Cibles de 48 px (`size-tap`), boutons natifs : Entrée et Espace. Le bouton garde le focus quand il atteint son bout.

## 4. Conséquences

- Les autres bandes du contrôleur (annonces, cours de « Ma classe ») n'ont pas ces cibles et ne changent pas ; elles peuvent les adopter avec le même balisage.
- Les points restent décoratifs : ce sont les boutons qui naviguent.
