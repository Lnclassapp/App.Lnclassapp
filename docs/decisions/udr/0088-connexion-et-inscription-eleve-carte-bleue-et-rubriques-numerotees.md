# UDR-0088 : Connexion et inscription élève — carte bleue d'accueil, panneau bleu dès 1 024 px, rubriques numérotées, « Besoin d'aide ? » en haut
<!-- index
titre: Connexion et inscription élève : carte bleue, rubriques numérotées
statut: Accepté
adr-lie: —
problematique: Connexion (tous rôles, au « vous ») et inscription élève : carte bleue au téléphone, panneau bleu à gauche dès 1 024 px, « Besoin d'aide ? » en haut à droite, lien « Créer mon compte élève » sur la connexion, inscription en trois rubriques numérotées en cartes, genre en pastilles. Amende UDR-0054, 0060, 0081
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-15 |
| **Chantier** | [`docs/chantiers/connexion-inscription-eleve`](../../chantiers/connexion-inscription-eleve/memo.md) |
| **ADR lié** | — (règles d'identité inchangées : ADR-0050, ADR-0084 à ADR-0086) |
| **Amende** | [UDR-0054](0054-finitions-d-interface.md) §3.2 (logo dans l'accueil bleu) · [UDR-0060](0060-connexion-et-recuperation-du-pin.md) (mise en page de la connexion) · [UDR-0081](0081-inscription-eleve-sans-code-de-classe.md) §3.1–3.2 (mise en page de l'inscription) |
| **Remplacé par** | — |

---

## 1. Contexte

Les deux pages ont été redessinées sur la toile https://claude.ai/artifact/Mk5fa5Wvh9jBgG9LDBH1eV, sur téléphone, tablette et ordinateur. Le porteur a tranché le 2026-10-15 (memo du chantier) :

- la carte bleue d'accueil au téléphone, le panneau bleu à gauche dès 1 024 px ;
- des rubriques numérotées en cartes ;
- la cascade de « Choisis ta classe » reprise telle quelle ;
- le genre en pastilles ;
- « Besoin d'aide ? » en haut ;
- un lien vers l'inscription élève sur la connexion.

La connexion sert à tous les rôles : son texte reste au « vous ».

## 2. Décision

> **Connexion et inscription partagent un même accueil bleu (carte au téléphone et sur tablette, panneau à gauche dès 1 024 px) et « Besoin d'aide ? » en haut à droite. Le formulaire est dans une carte blanche, en rubriques numérotées pour l'inscription.**

## 3. Règles d'implémentation

### 3.1 Accueil bleu (`shared/_auth_welcome`, nouveau)

| Largeur | Rendu |
|---|---|
| < 1 024 px | Carte en haut du formulaire, de la même largeur : dégradé `brand-strong` → `brand`, texte blanc, logo 48 px (lien vers `/`), titre, phrase |
| ≥ 1 024 px | Panneau à gauche, sur la moitié de l'écran, même dégradé, logo 64 px, titre, phrase ; le formulaire à droite |

- **Connexion** : « Heureux de vous revoir », avec la phrase actuelle.
- **Inscription** : « Bienvenue sur Lnclass », avec la phrase actuelle.
- **Point de bascule** : les deux pages passent en deux colonnes à 1 024 px. Aujourd'hui, la connexion bascule à `lg` et l'inscription à `md`.

### 3.2 « Besoin d'aide ? » (`shared/_auth_help`, nouveau)

- **Place** : en haut à droite des deux pages, en gras `text-brand-strong`, avec l'icône du casque (UDR-0084 §3.1).
- **Action** : il ouvre `shared/_help_sheet`.
- **Dans l'app Android** : il n'est pas rendu si la barre native porte déjà l'aide (UDR-0080).

### 3.3 Connexion (`identity/sessions/new`)

- **Carte** : la carte « Connexion » est blanche, `rounded-card`, et fait 440 px au plus.
- **Champs et actions** : le numéro, le code secret avec l'œil et l'info, « Se connecter » (`brand`), puis « Code secret oublié ? ».
- **Lien vers l'inscription** : un filet, puis « Pas encore de compte ? » suivi du lien « Créer mon compte élève », vers l'inscription élève.
- **Ordinateur** : la carte est centrée en hauteur.
- **Inchangés** : les erreurs, le focus, le numéro pré-rempli et le refus dans la mauvaise app (UDR-0054 §3.3, §3.8 ; UDR-0060).

### 3.4 Inscription (`classroom/student_registrations/new`, `_form`)

- **Formulaire** : 560 px au plus. Le titre est « Créer ton compte élève », avec « Trois rubriques, une minute. » en dessous.
- **Rubriques** : chacune est une carte blanche avec un numéro dans une pastille `bg-brand-soft text-brand-strong`.
  1. **Ta classe** : la cascade `_class_picker`. Par le lien d'une classe, c'est le bandeau de la classe avec « Ce n'est pas ta classe ? ».
  2. **Toi** : nom, prénoms, genre et numéro. Le genre se choisit par deux grandes pastilles radio de 44 px de haut, avec les libellés actuels ; la pastille choisie est en `bg-brand-strong text-white` (amendé à la livraison : `bg-brand` sous du blanc ne passe pas AA, §3.7).
  3. **Code secret** : le code, la confirmation et « Les codes concordent. ».
- **Bas du formulaire** : « Créer mon compte » (`brand`, pleine largeur au téléphone), puis « Déjà un compte ? Se connecter ».

### 3.5 Cascade de classe

`_class_picker` est partagé avec « Choisis ta classe ». Sa nouvelle forme (niveaux en pastilles, classes en cases, 4 par ligne dès 700 px, DRENA et établissement derrière « Changer ») est décidée et livrée par le chantier `choix-classe-eleve`. Ce chantier ne la modifie pas : il l'enveloppe dans la rubrique 1.

### 3.6 États obligatoires

- **Connexion** : vierge, erreur, numéro pré-rempli, mauvaise app.
- **Inscription** : vierge, lien de la classe, erreurs, codes qui concordent.
- **Communs** : feuille d'aide ouverte ; thème sombre ; téléphone, tablette (820 px) et ordinateur (1 280 px).

### 3.7 Accessibilité

- **Rubriques** : chacune est un `fieldset` avec une `legend` (« 1. Ta classe »). Le numéro est décoratif.
- **Pastilles du genre** : de vrais `input type="radio"`, dans un `fieldset` « Genre ».
- **Logo** : son nom accessible est le nom accessible actuel (`logo_home`).
- **Contraste** : AA sur le dégradé, dans les deux thèmes.

## 4. Conséquences

- **Accueil partagé** : un même partial `_auth_welcome` sert aux deux pages. Il pourra servir à « Code secret oublié ? » plus tard.
- **Tests à relire** : `test/system/identity/sign_in_test.rb`, `test/system/classroom/join_test.rb`, `test/system/finitions/{public_pages,narrow_screens}_test.rb` et `test/controllers/identity/sessions_controller_test.rb`. Leur comportement est identique ; seuls les sélecteurs de mise en page bougent.
