# UDR-0081 : En-tête de l'enseignant comme celui de l'élève, panneau du compte de l'enseignant, barres de « Lnclass Teacher », messages de refus croisés

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-08 |
| **Chantier** | [`docs/chantiers/app-android`](../../chantiers/app-android/memo.md) (reprise « Lnclass Teacher ») |
| **ADR lié** | [ADR-0085](../adr/0085-coque-android-enseignants-lnclass-teacher.md) · [ADR-0084](../adr/0084-coque-android-eleves-hotwire-native.md) |
| **Amende** | [UDR-0080](0080-en-tete-eleve-panneau-du-compte-et-barres-de-l-app-android.md) §3.1 et §3.2 (étendus à l'enseignant), §3.4 (le message nomme la bonne app) · [UDR-0006](0006-shell-applicatif-par-role.md) (seules la direction et l'équipe gardent l'en-tête d'origine) |
| **Remplacé par** | — |

---

## 1. Contexte

Le porteur a fixé le 2026-10-08 :
- l'enseignant reçoit, sur le site, l'en-tête de l'élève (UDR-0080) ;
- son panneau du compte garde « Inviter un collègue » ;
- sa barre basse ne change pas ;
- dans « Lnclass Teacher », les barres natives sont celles de l'élève, avec quatre onglets ;
- un compte entré dans la mauvaise app est envoyé vers la bonne.

## 2. Décision

1. **Deux rôles, un en-tête.** La branche de l'en-tête de l'UDR-0080 §3.1 vaut pour `student` **et** `teacher`. La direction et l'équipe gardent l'en-tête d'origine.
2. **Un panneau par rôle, un seul partial.** `_account_panel` rend les entrées du rôle. La page `/teachers/menu` rend celui de l'enseignant, comme `/students/menu` rend celui de l'élève.
3. **Le refus nomme la bonne app**, jamais un rôle que la personne ne connaît pas déjà : il ne survient qu'après un PIN correct.

## 3. Règles d'implémentation

### 3.1 En-tête de l'enseignant

Identique à UDR-0080 §3.1 : avatar à gauche (déclencheur-lien du panneau, vers `/teachers/menu` sans JavaScript), sans logo ni badge de rôle ; à droite, « Besoin d'aide ? » et l'interrupteur clair/sombre, à toutes les largeurs. Le filet du haut garde la couleur de l'enseignant (`bg-teacher`). À 390 px, la rangée tient sur une ligne, sans défilement horizontal.

### 3.2 Panneau du compte de l'enseignant

Même structure que UDR-0080 §3.2 (identité, liens, thème, déconnexion). Identité : nom, et la ligne de détail de `ShellUser` (l'établissement). Liens, dans cet ordre :

| Entrée | Icône | Adresse |
|---|---|---|
| Mon profil | `user-circle` | `profile_path` |
| Inviter un collègue | `user-plus` | `teacher_invite_path` |

Le lien courant porte `aria-current="page"`. La barre latérale de l'enseignant (ordinateur) garde sa carte « Inviter un collègue » : le panneau ne la remplace pas.

### 3.3 Barres de « Lnclass Teacher »

- **Barre du haut** : identique à l'app élèves (UDR-0080 §3.3). Le menu de l'avatar ouvre `/teachers/menu` en modale.
- **Onglets** : Accueil (`home`), Classes (`user-group`), Cours (`book-open`), Annonces (`megaphone`), avec les libellés de `shared.navigation`.
- **Couleur active** : `#C2410C`, l'orange foncé du design system, lisible sur fond blanc. L'orange `#FF8A00` reste celui de l'écran de démarrage et de l'icône.
- **Onglets cachés** sur les pages ouvertes en modale : « Assigner un exercice », « Jours de séance », le panneau du compte et l'aide (ADR-0085 §4.3).

### 3.4 Messages de refus (page de connexion, 422, ton `:warning`)

| Coque | Compte (PIN correct) | Titre | Texte | Lien |
|---|---|---|---|---|
| élèves | enseignant | « Utilisez Lnclass Teacher » | « Cette app est réservée aux élèves. Les enseignants ont leur app, Lnclass Teacher. » | « Ouvrir Lnclass Teacher » : fiche Play Store si connue, sinon le site |
| élèves | direction, équipe | « Cette app est réservée aux élèves » | « Direction et équipe : continuez sur le site. » | « Ouvrir lnclass.com » |
| enseignants | élève | « Utilisez l'app Lnclass » | « Cette app est réservée aux enseignants. Les élèves ont leur app, Lnclass. » | « Ouvrir Lnclass » : fiche Play Store si connue, sinon le site |
| enseignants | direction, équipe | « Cette app est réservée aux enseignants » | « Direction et équipe : continuez sur le site. » | « Ouvrir lnclass.com » |

Le lien s'ouvre hors de l'app (`target="_blank"`). Le numéro et le PIN ne sont pas réaffichés.

## 4. Conséquences

- Les tests et captures qui décrivaient l'en-tête de l'enseignant (logo, menu déroulant du compte) changent avec lui.
- Une nouvelle entrée du compte de l'enseignant se fait dans `_account_panel` et vaut pour le site comme pour l'app.
