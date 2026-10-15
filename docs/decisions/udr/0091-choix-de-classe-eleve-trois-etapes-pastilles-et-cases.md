# UDR-0091 : « Choisis ta classe » — trois étapes numérotées, établissement replié avec « Changer », niveaux en pastilles, classes en cases
<!-- index
titre: Choix de classe : trois étapes, pastilles des niveaux, cases des classes
statut: Accepté
adr-lie: —
problematique: Élève sans classe et inscription : la cascade partagée `_class_picker` devient trois étapes numérotées ; établissement en une ligne avec « Changer » (DRENA et établissement en listes derrière) ; niveaux en pastilles ; classes en grandes cases, 4 par ligne dès 700 px, « Complète » désactivée ; repli sans JS conservé. Amende UDR-0081 §3.3–3.5
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-15 |
| **Chantier** | [`docs/chantiers/choix-classe-eleve`](../../chantiers/choix-classe-eleve/memo.md) |
| **ADR lié** | — (règles d'adhésion inchangées : ADR-0040, ADR-0085) |
| **Amende** | [UDR-0081](0081-inscription-eleve-sans-code-de-classe.md) §3.3–3.5 (forme de la cascade) |
| **Dépend de** | [UDR-0084](0084-accueil-eleve-en-tete-au-logo-menu-de-l-avatar-et-exercice-du-jour.md) (en-tête, menu) |
| **Remplacé par** | — |

---

## 1. Contexte

La page a été redessinée sur la toile https://claude.ai/artifact/QhGVuZiGSxEdCBqa4CKwaM. Le porteur a tranché le 2026-10-15 (memo du chantier) :

- trois étapes numérotées ;
- l'établissement en une ligne avec « Changer » ;
- les niveaux en pastilles et les classes en cases ;
- le même cadre que l'accueil ;
- une cascade identique pour l'inscription.

## 2. Décision

> **La cascade de classe est faite de trois étapes numérotées. La DRENA et l'établissement se replient en une ligne dès qu'ils sont connus, et les niveaux et les classes se choisissent par des pastilles et des cases, sans liste déroulante.**

## 3. Règles d'implémentation

### 3.1 Étapes

Chaque étape est un `fieldset` avec une `legend` numérotée (pastille `bg-brand-soft text-brand-strong`) :

1. **Ton établissement** :
   - si l'établissement est connu (dernière classe, ou choix fait), une ligne avec l'icône `building-library`, le nom de l'établissement, la DRENA en `text-mute`, et le bouton `ghost` « Changer » ;
   - sinon, ou après « Changer », les deux listes actuelles : DRENA (`select`), puis établissement (cadre `picker_schools`).
2. **Ton niveau** (cadre `picker_levels`) : les niveaux qui ont une classe active, en pastilles. Ce sont des `input type="radio"` stylés : 40 px de haut, `rounded-full` ; la pastille choisie est en `bg-brand text-white`. Elles passent à la ligne si besoin.
3. **Ta classe** (cadre `picker_classrooms`) : les classes en grandes cases radio de 64 px de haut, avec le nom de la classe en `font-display`.
   - Grille de 2 colonnes au téléphone, de 4 dès 700 px.
   - Classe complète : `disabled`, `opacity-60`, badge « Complète ».
   - Case choisie : bordure `brand`, fond `brand-soft`, coche.

### 3.2 Comportement

- **Contrôleur** : `classroom--class-picker` gagne l'action `change`. Elle remplace la ligne repliée par les listes et vide les étapes 2 et 3 (`clear` actuel).
- **Chargements** : ils passent par les cadres Turbo actuels (`frame.src`), sans nouvelle route ; l'état d'erreur et « Réessayer » sont inchangés.
- **Sans JS** : « Changer » est un lien vers `new` sans `school_public_id`, et le bouton « Continuer » de chaque étape reste.
- **Bouton final** : « Rejoindre cette classe » (`brand`, pleine largeur au téléphone), désactivé par JS tant qu'aucune case n'est cochée.

### 3.3 Page « Choisis ta classe » (`classroom/student_classroom_choices/new`)

- **Cadre et largeur** : en-tête et menus d'UDR-0084 ; il n'y a plus de lien « Accueil » au-dessus du titre. Le formulaire fait 640 px au plus.
- **En tête** : le titre « Choisis ta classe », puis les alertes actuelles (lien plus valable, refus).
- **Sous l'étape 3** : « Ta classe n'est pas encore sur Lnclass. » (actuel).

### 3.4 Inscription

La même cascade remplit la rubrique 1 de l'inscription (UDR-0088 §3.5), avec les mêmes partials.

### 3.5 États obligatoires

- Établissement connu ; établissement inconnu ; après « Changer ».
- Niveau choisi ; classe complète ; erreur de chargement.
- Alerte de refus.
- Sans JS.
- Thème sombre.

### 3.6 Accessibilité

- **Pastilles et cases** : de vrais `radio` dans leur `fieldset`, au clavier par les flèches.
- **« Changer »** : son nom accessible est « Changer d'établissement ».
- **Étape rechargée** : une annonce `aria-live="polite"` dit le nombre de niveaux ou de classes trouvés.

## 4. Conséquences

- **Partage** : l'inscription élève et « Choisis ta classe » changent ensemble, puisque le partial est partagé.
- **Tests à relire** : `test/controllers/classroom/student_classroom_choices_controller_test.rb`, `test/controllers/school/{drena_schools,school_levels,level_classrooms}_controller_test.rb` et `test/system/classroom/join_test.rb`.
