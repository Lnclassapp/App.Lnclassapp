# Memo — « Fiche de cours » et « Fiche de révision » à l'écran

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-10-12 |
| **Branche** | `feature/renommage-fiche-revision` |
| **Programme** | — |

---

## Le problème

Deux objets du catalogue portent à l'écran des noms que les nouveaux contenus n'emploient plus :

- le résumé des notions clés d'un cours s'appelle « Fiche essentielle » ;
- le cours lui-même s'appelle « Cours ».

Le porteur rebaptise le premier **« Fiche de révision »** et le second **« Fiche de cours »**. Ce sont les noms des fiches dessinées par l'équipe, que la plateforme va intégrer : fiches de cours, fiches de révision, exercices. Tant que l'écran garde les anciens noms, la plateforme parle une autre langue que ses contenus à venir.

## Pour qui

- **Élève** : catalogue, page d'une fiche de cours, page d'une fiche de révision, accueil (fiches à revoir), page d'une classe, page d'un exercice, aide.
- **Enseignant** : accueil, page d'une classe, fiches vues depuis une classe.
- **Équipe** :
  - accueil ;
  - formulaires de fiche de cours, de fiche de révision et d'exercice ;
  - imports, publication en cascade, invitations ;
  - référentiel : niveaux, séries, matières.
- **Visiteur** : page d'accueil, mission, conditions d'utilisation.

## Pourquoi maintenant

Le porteur a validé le 2026-10-12 l'intégration des nouvelles fiches : style cahier, mobile d'abord, entraînement noté, saisie par import JSON. Les chantiers suivants (contenu en blocs, questions enrichies) écriront de nouveaux textes d'interface. Ils doivent naître avec les bons mots, pas avec les anciens.

## Hors périmètre

- **Les noms dans le code** restent `Course` et `Essential`, de même que les tables, les clés d'import JSON et les routes. Le glossaire interdit `Fiche` et `Sheet` dans le code.
- **Les adresses** restent `…/courses/<cours>/essentials/<fiche>`. Aucune redirection : les liens déjà partagés restent valides.
- **L'onglet de navigation « Cours »** et le titre de sa rubrique ne changent pas : c'est une rubrique, pas le nom d'un objet.
- **« Cours » au sens scolaire courant** ne change pas, par exemple « comprendre leurs cours » ou « révisent leurs cours » sur les pages publiques.
- **Le contenu et la forme des fiches** (style cahier, blocs, lexique, « En clair ») relèvent du chantier `contenu-en-blocs`.
- **Les nouveaux types de questions** relèvent du chantier `questions-enrichies`.
- **Les données saisies par l'équipe** ne sont pas réécrites, par exemple un nom de fiche qui contiendrait « essentielle ».
- **Les décisions et chantiers déjà livrés** restent l'historique de leur date.
- **Les commentaires du code** changent au fil des chantiers qui touchent ces fichiers.
- **Les CGU** ne prennent pas de nouvelle version : la date de mise à jour reste inchangée.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| « Fiche de révision à revoir » est redondant : que lit l'élève quand une fiche passe à revoir ? | « Fiches à revoir » sur l'accueil, « Fiche à revoir » dans le bandeau de la fiche | L'UDR-0007 interdit « Fiche » seul dans un titre. La nouvelle décision d'interface crée cette exception, limitée aux titres « à revoir » |
| Que devient le titre « Essentielles de la leçon » de la liste des fiches d'un cours ? | « Révisions de la leçon », dans le catalogue et dans la page d'un cours d'une classe | L'exception de l'amendement du 2026-09-30 de l'UDR-0007 change de mot, elle ne disparaît pas. La garde du test de vocabulaire suit la nouvelle valeur |
| Les pages publiques, CGU comprises, changent-elles ? | Oui, toutes. Le changement est terminologique, sans effet sur les droits : pas de nouvelle version des CGU | Accueil, mission et CGU entrent dans le périmètre. La date « mise à jour le 2 octobre 2026 » des CGU reste inchangée |
| L'adresse d'une fiche contient « essentials », visible et partagée par WhatsApp : la change-t-on ? | Non, l'adresse fait partie du code | Aucune route ne bouge et il n'y a aucune redirection. Écrit dans `Hors périmètre` |
| Jusqu'où va le renommage hors écran (doc interne, commentaires du code) ? | Doc vivante seulement : glossaire, décisions de vocabulaire, guides, prompt de rédaction des contenus | Le diff se limite à ce qu'on voit à l'écran et à la doc qui fait foi |
| Les maquettes appellent la page d'un cours « Fiche de cours » : ce chantier renomme-t-il aussi « Cours » ? | Oui, dans ce chantier | Le périmètre double : « Cours » est dans environ 35 fichiers de traduction. Il faut trier les faux amis (« en cours », « Import en cours ») et le sens scolaire courant. Le genre change : « le cours créé » devient « la fiche de cours créée », donc chaque accord se relit |
| « Fiches de cours » tient-il dans l'onglet de navigation mobile à 390 px ? | L'onglet et le titre de la rubrique gardent « Cours ». Partout où l'on nomme l'objet, on écrit « fiche de cours » | Règle d'écriture en deux cas (rubrique / objet), à écrire noir sur blanc dans la décision d'interface. Pas de risque de débordement de la barre |

## Cas limites identifiés

- **Faux amis** : « en cours », « Import en cours », « Génération en cours », « Chargement en cours », « parcours ». Ils ne changent pas.
- **Sens scolaire courant** (« comprendre leurs cours », « Révise l'essentiel du cours ») : il ne change pas. Ce n'est pas le nom de l'objet Lnclass.
- **Accords** : chaque message passe du masculin au féminin.
  - « Cours « X » créé » devient « Fiche de cours « X » créée ».
  - « Aucun cours » devient « Aucune fiche de cours ».
  - « Ce cours est assigné » devient « Cette fiche de cours est assignée ».
- **Comptes** : « 1 cours » / « 12 cours », invariables, deviennent « 1 fiche de cours » / « 12 fiches de cours ». Le pluriel s'accorde.
- **En-têtes de colonnes** des tableaux du référentiel (niveaux, séries, matières) : « Cours » devient « Fiches de cours ». La largeur est à vérifier à 390 px.
- **Messages qui nomment les deux objets** : « Publiez d'abord la fiche essentielle et son cours » devient « Publiez d'abord la fiche de révision et sa fiche de cours ».
- **Libellés de type d'import** : « Cours complets » devient « Fiches de cours complètes ».
- **Tests qui comparent un texte exact** : ils sont mis à jour dans le même lot que la traduction.

## Questions encore ouvertes

- Aucune bloquante. Le titre de l'accueil public, « Révise l'essentiel du cours », reste tel quel (sens courant). À revoir si le porteur veut citer les fiches de révision dans l'accroche.
