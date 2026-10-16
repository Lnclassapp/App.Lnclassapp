# UDR-0101 : Profil de l'élève — la ligne « Classe » ouvre « Changer de classe »
<!-- index
titre: Profil élève : la ligne Classe ouvre « Changer de classe »
statut: Proposé
adr-lie: [0095](../adr/0095-l-eleve-change-lui-meme-de-classe-et-d-etablissement.md)
problematique: Élève à classe active : la ligne « Classe » du profil devient une ligne à toucher, action « Changer », qui ouvre la page « Changer de classe » en pleine page (pas en fenêtre) ; « Établissement » reste en lecture seule. Amende UDR-0089 §3.2
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/changement-etablissement-eleve`](../../chantiers/changement-etablissement-eleve/memo.md) |
| **ADR lié** | [ADR-0095](../adr/0095-l-eleve-change-lui-meme-de-classe-et-d-etablissement.md) |
| **Amende** | [UDR-0089](0089-profil-eleve-carte-bleue-lignes-a-toucher-et-se-deconnecter.md) §3.2 (Classe en lecture seule), §3.7 |
| **Remplacé par** | — |

---

## 1. Contexte

Aujourd'hui, un élève qui a une classe active n'a aucun moyen d'en changer : la ligne « Classe » de son profil est en lecture seule (UDR-0089 §3.2), et « Choisis ta classe » le renvoie à l'accueil. L'élève qui déménage, ou qui s'est trompé de classe à l'inscription, cherche naturellement le geste là où sa classe est écrite : son profil.

## 2. Décision

> **La ligne « Classe » du profil devient une ligne à toucher, avec l'action « Changer ». Elle ouvre la page « Changer de classe » (UDR-0102) en pleine page. La ligne « Établissement » reste en lecture seule : changer d'établissement, c'est changer de classe.**

Pourquoi une seule entrée, sur « Classe » : un élève ne change jamais d'établissement sans changer de classe ; deux lignes cliquables pour le même parcours feraient croire à deux gestes.

Pourquoi en pleine page et pas dans une fenêtre (contrairement aux autres lignes, UDR-0089 §3.4) : la cascade en trois étapes et la confirmation ne tiennent pas dans une feuille de 480 px, et l'élève doit pouvoir revenir en arrière avec le bouton du navigateur.

## 3. Règles d'implémentation

### 3.1 Ligne « Classe »

- Partial : `identity/profiles/_student_row` (UDR-0089), avec `href: new_student_classroom_change_path`, `action: t(".change")` (« Changer »).
- **Cible** : la ligne ne vise **pas** le cadre `modal`. Le partial reçoit un local `frame: "_top"` (défaut : `"modal"`, inchangé pour Photo, Nom, Numéro) et le pose dans `data-turbo-frame`.
- Icône, libellé, valeur : inchangés (« Classe », nom de la classe).
- Ordre des lignes : inchangé (Photo, Nom, Numéro, Classe, Établissement, Inscrit le).

### 3.2 Ligne « Établissement »

- Inchangée : lecture seule, sans chevron.

### 3.3 Élève sans classe active

- Les lignes Classe et Établissement restent absentes (UDR-0089 §3.6). L'élève choisit sa classe depuis l'accueil (« Choisis ta classe », UDR-0081 §3.5) : aucune ligne nouvelle.

### 3.4 Tokens

- Ceux de la ligne existante : `text-mute` pour le libellé, `text-ink` pour la valeur, `text-brand-strong` pour « Changer », chevron `text-mute`, survol `bg-mist`. Aucune valeur en dur.

### 3.5 États obligatoires

- Avec classe : ligne « Classe » à toucher.
- Sans classe : lignes absentes.
- Thème sombre.
- 390 px et 1 280 px (deux colonnes, UDR-0089 §3.5).

### 3.6 Accessibilité

- Nom accessible : « Changer classe, %{classe} » selon la règle d'UDR-0089 §3.7 (`identity.profiles.student_information.row_label`).
- Hauteur ≥ `spacing-tap` (48 px), focus visible `outline-brand`.
- Aucune fenêtre : le focus suit la navigation Turbo vers la nouvelle page.

## 4. Conséquences

- Le profil devient l'unique entrée du changement de classe pour un élève à classe active ; « Ma classe » et l'accueil ne reçoivent pas de bouton.
- `_student_row` gagne un local `frame:` ; les trois lignes à fenêtre ne changent pas.
- Tests à relire : `test/system/identity/profile_test.rb` et `test/controllers/identity/profiles_controller_test.rb`.
