# Memo — Refonte de la page d'accueil publique

| | |
|---|---|
| **Type de cycle** | feature (interface : une vue, sa locale, deux options d'un composant ; aucun changement de domaine, de route ni de contrôleur) |
| **Statut** | en cours — livré en PR [#145](https://github.com/Lnclassapp/App.Lnclassapp/pull/145), en attente du porteur |
| **Ouvert le** | 2026-10-02 |
| **Branche** | `feature/refonte-homepage` |
| **Programme** | — |

---

## Le problème

La page d'accueil publique est la seule page qu'un visiteur non connecté voit. Elle a été écrite en V1 pour « dire le contenu de la V1 » ([UDR-0012](../../decisions/udr/0012-landing-et-modales-de-role.md)) et elle le fait, mais comme une page de présentation générique, pas comme la porte d'entrée d'un élève sur un téléphone d'entrée de gamme :

- **Elle pèse lourd pour le public visé.** La photo du héros est un PNG de 1,3 Mo, plus de dix fois les deux polices et la feuille de style réunies, téléchargé par chaque visiteur, le plus souvent en 3G avec des données payées par la famille (ADR-0009, ADR-0051). Le budget de poids ne surveille que le JavaScript et le CSS ; l'image lui a échappé.
- **Elle dit plusieurs fois la même chose.** Sept blocs se suivent (héros, matières, « Pour qui ? », fonctionnalités, trois étapes, appel final, pied) et l'espace enseignant y est présenté trois fois : carte « Pour qui ? », fonctionnalité n° 4, entrée de rôle. Le visiteur a pourtant une seule décision à prendre : élève ou enseignant.
- **Son en-tête propose trois ancres et deux boutons**, dont « Commencer », qui défile jusqu'à un appel final qui répète les deux entrées du héros.
- **Elle tutoie l'enseignant** (« Déclare tes classes ») alors que toute l'application le vouvoie (« Déclarez les classes où vous enseignez »).
- **Elle promet « et plus encore »** après six matières, range l'Histoire-Géographie hors des Lettres alors que le référentiel l'y range, et oublie l'Anglais, qui est au référentiel.
- **Deux identités visuelles se disputent la page** : le filet orange de la carte enseignant et le bloc noir des fonctionnalités, alors que la marque n'a qu'une couleur, le bleu, et que le fond de l'application est le papier.

Demande du porteur, le 2026-10-02 : « tu vas refaire la Homepage de Lnclass ».

## Pour qui

- **L'élève** (11 à 18 ans) qui arrive par un lien reçu sur WhatsApp ou par l'adresse donnée en classe, souvent sur un Android d'entrée de gamme : il doit comprendre en un écran ce qu'est Lnclass et entrer par « Je suis élève ».
- **L'enseignant** qui a entendu parler de Lnclass par un collègue (parrainage, ADR-0063) ou par son établissement (code d'établissement, ADR-0057) : il doit lire ce que Lnclass lui apporte et créer son compte.
- **La personne déconnectée**, quel que soit son rôle : « Se connecter » en un tap.
- **Le parent ou la direction** qui reçoit une capture de la page : la marque et la promesse doivent se lire sans contexte.

## Pourquoi maintenant

La V1 est en production depuis le 2026-09-27. La page d'accueil est la porte d'entrée de la croissance par parrainage et par code d'établissement, et chaque visiteur paie aujourd'hui 1,3 Mo avant de voir le premier bouton. Le porteur demande la refonte.

## Hors périmètre

- **Les routes, le contrôleur et le domaine ne changent pas** : `/` sert la même page statique, un visiteur connecté est toujours renvoyé vers son accueil.
- **Aucune nouvelle entrée de rôle** : ni parent, ni établissement (UDR-0012, TR-03 : V2). Les deux modales de rôle gardent leur contenu et leurs identifiants.
- **Aucune donnée dynamique** (nombre d'élèves, d'établissements, de cours) : la page reste sans requête.
- **Aucun tarif, abonnement ni paiement** : la page n'en parle pas (le test de la landing refuse « FCFA »).
- **Pas de mode sombre** : exclu de la V1 par l'UDR-0005, même si la grille de design synchronisée dans Claude Code le prévoit. Cette contradiction se tranche par le porteur, hors de ce chantier (voir les questions ouvertes).
- **Les pages publiques voisines** (connexion, `/join`, inscription enseignant, PIN oublié) ne changent pas.
- **Aucune nouvelle photo ni illustration** : la photo existante est réencodée, les logos sont réutilisés.
- **Le texte du slogan** : « Avec Lnclass, tu comprends chap chap ! » et « Plante la graine aujourd'hui. » sont repris tels quels.

## Ce que le grill a révélé

> Grill mené en session autonome, sans le porteur : chaque réponse est une hypothèse de travail, marquée comme telle quand elle engage un choix de produit. Le porteur peut la renverser en revue de PR ; la colonne de droite dit ce qu'il faudrait changer.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Que voient le parent, la direction et l'équipe sur cette page ? | Rien qui leur soit propre : aucun des trois n'entre seul en V1 (la direction et l'équipe sont invitées, ADR-0038 et ADR-0044 ; le parent n'existe pas). Une capture de la page doit cependant leur dire ce qu'est Lnclass. | Deux entrées, et seulement deux (UDR-0012 inchangée). Le héros se suffit sur une capture : logo, promesse, les deux entrées. |
| Un élève de plusieurs classes, un enseignant de deux établissements : la page change-t-elle ? | Non. La page est publique, elle ne connaît personne, et un visiteur connecté n'y arrive jamais. | Aucune donnée, aucune requête. Le test de redirection existant reste la preuve. |
| Quelles matières annoncer, et que promet « et plus encore » ? | Le référentiel de développement et de test compte sept matières (ADR-0034) : Mathématiques, Physique-Chimie, SVT en Sciences ; Français, Anglais, Histoire-Géographie, Philosophie en Lettres. En production, l'équipe crée le sien à l'écran, et la page ne peut pas le lire sans requête. | Les sept matières du référentiel, sans « et plus encore », chacune dans la teinte de sa catégorie. Si le référentiel de production diffère, c'est une ligne de locale à changer. **Hypothèse à confirmer par le porteur.** |
| Que peut-on promettre à l'enseignant sans mentir ? | Ce que la V1 livre : déclarer ses classes et partager leur code, assigner cours, fiches essentielles et exercices, lire les scores (TR-05, UDR-0026, UDR-0027). Rien sur la remédiation (V5) ni les annonces (V6). | Une section « Enseignants » en vouvoiement, trois promesses, un seul bouton « Créer mon compte enseignant » vers l'inscription existante. |
| Garde-t-on la photo, à 1,3 Mo ? | Oui pour ce qu'elle dit (deux élèves ivoiriens, un téléphone, une table : « c'est pour nous »), non à ce poids. Le même cadrage en 960 × 640, encodé en WebP, tient en 22 Ko ; Chrome 111 et Safari 16.4, le plancher de l'ADR-0051, lisent le WebP. | La photo est réencodée, ses dimensions sont déclarées (aucun saut de mise en page), et un test refuse un fichier de plus de 100 Ko. Le PNG disparaît du dépôt. |
| À quoi sert « Commencer » dans l'en-tête, en plus des deux entrées du héros ? | À défiler vers l'appel final, qui répète les deux entrées : trois chemins vers la même décision. | L'en-tête ne garde que « Se connecter », pour la personne déconnectée. Le héros porte la décision ; l'appel final la répète une fois, en bas, pour qui a tout lu. |
| Les deux entrées tiennent-elles sans défiler sur un petit Android (360 × 640) ? | Avec la navigation retirée et le héros resserré : en-tête 64 px, pastille, titre sur deux lignes, chapeau, deux boutons de 56 px empilés, environ 420 px en tout. Oui. | Critère RH-03 et test système à 360 × 640 : le bas du second bouton est au-dessus du bord de la fenêtre. |
| Faut-il un nouveau composant pour des boutons d'entrée de 56 px pleine largeur ? | Non : `ui_modal` rend déjà son déclencheur par `ui_button` ; il ne lui manque que la taille et la largeur. | Deux options de `ui_modal`, `trigger_size:` et `trigger_full:`, amendement de l'UDR-0005, exemple sur `/design`, test du helper. |
| Quel contexte borné porte la règle ? | Aucun : la page ne porte aucune règle métier. Elle est delivery et UI. | Pas d'ADR. Le scope des commits est `ui`. |
| Les modales de rôle nomment-elles l'onglet, comme l'exige l'UDR-0054 pour toute modale ? | Non : elles sont les seules modales à ne pas passer `document_title:`. | Chaque modale de rôle nomme l'onglet par son titre (« Tu es élève ? · Lnclass ») tant qu'elle est ouverte. |

## Cas limites identifiés

- **Sans JavaScript** : les boutons « Je suis élève » et « Je suis enseignant » ne peuvent pas ouvrir leur `<dialog>` ; « Se connecter » dans l'en-tête et « Créer mon compte enseignant » restent des liens ordinaires. Inchangé par rapport à aujourd'hui.
- **Visiteur connecté** : renvoyé vers son accueil, inchangé.
- **390 px et 360 px** : aucun défilement horizontal ; la carte posée sur la photo et le logo décoratif de l'appel final restent dans leurs gouttières.
- **Photo non chargée** (réseau coupé) : le texte alternatif décrit la scène ; la mise en page tient grâce aux dimensions déclarées.
- **Ancres** : chaque lien du pied vise une section qui existe ; le test des liens le vérifie.

## Questions encore ouvertes

- Le slogan et la ligne de l'appel final sont repris tels quels : le porteur voulait-il aussi changer le texte ?
- Les sept matières annoncées sont celles du référentiel de développement : sont-elles celles de la production ?
- Mode sombre : la grille de design synchronisée le prévoit, l'UDR-0005 l'exclut en V1. À trancher par le porteur, hors de ce chantier.
