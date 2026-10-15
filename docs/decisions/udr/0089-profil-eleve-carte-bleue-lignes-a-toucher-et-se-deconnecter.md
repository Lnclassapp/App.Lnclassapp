# UDR-0089 : Profil de l'élève — carte bleue, lignes entières à toucher, fenêtres par le bas, établissement, « Se déconnecter » en bas
<!-- index
titre: Profil de l'élève : carte bleue, lignes à toucher, Se déconnecter
statut: Proposé
adr-lie: —
problematique: Élève : profil dans le cadre de l'accueil, carte bleue (photo, nom, « Élève en 3e B »), lignes entières à toucher, ligne Établissement en lecture seule, fenêtres en feuille sous 700 px et au centre au-delà, « Se déconnecter » en bas, deux colonnes dès 1 024 px. Amende UDR-0041, 0047, 0051
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-15 |
| **Chantier** | [`docs/chantiers/profil-eleve`](../../chantiers/profil-eleve/memo.md) |
| **ADR lié** | — |
| **Amende** | [UDR-0041](0041-page-profil.md) (branche élève) · [UDR-0047](0047-photo-de-profil.md) (fenêtre de la photo) · [UDR-0051](0051-afficher-le-code-pin.md) (fenêtre du code secret) |
| **Dépend de** | [UDR-0084](0084-accueil-eleve-en-tete-au-logo-menu-de-l-avatar-et-exercice-du-jour.md) (en-tête, menu, avatar aux initiales) |
| **Remplacé par** | — |

---

## 1. Contexte

Le profil a été redessiné sur la toile https://claude.ai/artifact/BCpNowiWxjrCx53kCTTr9g. Le porteur a tranché le 2026-10-15 (memo du chantier) :

- même cadre et même menu que l'accueil ;
- une carte bleue avec la photo, le nom et la classe ;
- des lignes entières à toucher ;
- des fenêtres par le bas au téléphone ;
- l'établissement affiché ;
- « Se déconnecter » en bas du profil.

## 2. Décision

> **Le profil de l'élève est une carte bleue d'identité suivie de listes de lignes à toucher, chaque ligne ouvrant sa fenêtre ; « Se déconnecter » ferme la page.**

## 3. Règles d'implémentation

### 3.1 Carte bleue

- **Fond** : dégradé `brand-strong` → `brand`, texte blanc.
- **Contenu** :
  - l'avatar `xl`, avec la photo, ou les initiales et le « + » (UDR-0084 §3.4) ;
  - le nom (`h2`) ;
  - « Élève en %{classe} ». Sans classe, la ligne est absente.
- **Pas de bouton** dans la carte : la photo se change depuis la ligne « Photo ».

### 3.2 « Mes informations »

- **Lignes** : une `ui_card` blanche avec une ligne par information, dans l'ordre : Photo, Nom, Numéro, Classe, Établissement, Inscrit le.
- **Lignes modifiables** (Photo, Nom, Numéro) : la ligne entière est un lien (`data-turbo-frame="modal"`). Elle porte le libellé en `text-mute`, la valeur en `text-ink` et un chevron à droite. Sa hauteur est au moins `spacing-tap`.
- **Lignes en lecture seule** (Classe, Établissement, Inscrit le) : sans chevron ni lien.
- **Établissement** : celui de la classe principale active (`ProfileQuery#school_name`, rempli désormais pour l'élève).

### 3.3 « Mon code secret », « Apparence », « Se déconnecter »

- **« Mon code secret »** : une carte avec une ligne « Changer mon code secret », qui ouvre la fenêtre.
- **« Apparence »** (`shared/_theme_switch`, carte) : sous 1 024 px seulement, comme aujourd'hui. Au-delà, la lune de l'en-tête suffit.
- **« Se déconnecter »** : un bouton pleine largeur, `secondary`, avec l'icône `arrow-right-start-on-rectangle`, en bas de la page.
  - Il fait `button_to session_path, method: :delete`, la même action que le menu du compte.
  - Pas de confirmation, comme dans le menu.

### 3.4 Fenêtres (nom, photo, code secret, numéro)

- **Rendu** : `ui_modal`, dans le cadre `modal` existant.
  - Sous 700 px, en feuille depuis le bas (`rounded-sheet` en haut, poignée).
  - Dès 700 px, au centre, 480 px au plus.
- **Contenu, validations et erreurs** : inchangés. L'aperçu recadré de la photo, l'œil du code secret et « Code secret incorrect. » restent comme aujourd'hui.
- **Bouton principal** : pleine largeur dans la feuille.

### 3.5 Mise en page

| Largeur | Disposition |
|---|---|
| < 700 px | une colonne pleine largeur |
| 700–1 023 px | une colonne de 720 px, centrée |
| ≥ 1 024 px | menu de gauche ; deux colonnes dans 960 px : « Mes informations » à gauche ; « Mon code secret » et « Se déconnecter » à droite |

La carte bleue est au-dessus, sur toute la largeur.

### 3.6 États obligatoires

- Avec photo, sans photo, sans classe.
- Chacune des quatre fenêtres ouverte, avec son erreur.
- Thème sombre.

### 3.7 Accessibilité

- **Lignes modifiables** : leur nom accessible est « Modifier %{libellé}, %{valeur} ».
- **Feuille** : `role="dialog"` et `aria-modal`. Le focus y est piégé et revient à la ligne d'origine.
- **« Se déconnecter »** : un vrai bouton de formulaire.

## 4. Conséquences

- **Autres rôles** : le profil de l'enseignant, de la direction et de l'équipe garde UDR-0041.
- **Tests à relire** : `test/system/identity/profile*_test.rb` et `test/controllers/identity/profiles_controller_test.rb`.
