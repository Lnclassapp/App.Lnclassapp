# Memo — Refonte des contenus de mathématiques

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-10-29 |
| **Branche** | `feature/refonte-contenus-maths` |
| **Programme** | — |

---

## Le problème

Les 213 leçons livrées (39 en mathématiques) sont dans l'ancien format : l'import les accepte mais **jette tous leurs exercices**. Leurs exercices sont des QCM et Vrai/Faux sans énoncé, sans méthode : l'élève coche, il n'apprend pas à raisonner. La révision est éclatée entre deux supports (fiche des notions essentielles et fiche de cours illustrée), et seules 3 leçons ont une fiche illustrée.

## Pour qui

**Élève** qui révise une leçon de mathématiques avant une interrogation, un devoir ou le BEPC : il doit comprendre une méthode et savoir la réappliquer seul. **Équipe** Lnclass qui produit et importe les contenus.

## Pourquoi maintenant

Les exercices des leçons en ligne sont perdus à l'import : les leçons de mathématiques n'ont aujourd'hui rien de juste à faire travailler.

## Hors périmètre

Ce qu'on ne fera **pas** dans ce chantier. Cette section est la plus utile du memo : c'est elle qui empêche le chantier de gonfler.

- Les autres matières (après les mathématiques, chantiers suivants).
- Les niveaux de mathématiques autres que la 3e (chantiers suivants, même pipeline).
- Toute fusion mécanique de l'ancien contenu : tout est réécrit.
- Archivage ou suppression ciblée des anciennes leçons : le porteur remet la base à zéro lui-même.
- Tout outil de suppression de leçon.
- Tout nouvel écran pour les enseignants et les parents : ils gardent leur parcours actuel.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Décisions héritées (porteur, 2026-10-29) | Tout réécrire ; ≥ 5 questions par exercice ; correction avec méthode de raisonnement détaillée ; mathématiques d'abord ; anciennes leçons supprimées sans archive | Contenu neuf de bout en bout ; suppression irréversible (copies et notes des élèves sur ces leçons perdues), confirmée explicitement avant Staging et main |
| Fiche des notions essentielles ou fiche de cours illustrée : laquelle garder ? | On **supprime la fiche des notions essentielles**. On garde la fiche illustrée, renommée **fiche de révision**. Elle **garde ses figures interactives**. | Un seul support de révision par leçon. Le format d'échange perd ses fiches essentielles (et l'exercice rattaché à chacune). Chaque leçon de mathématiques doit avoir sa fiche de révision et ses figures : coût de production nettement plus élevé (une figure interactive aujourd'hui = du code propre à la leçon). La proposition « gabarit 4 blocs, figure fixe » est écartée pour la figure ; le reste du gabarit reste à trancher. |
| Figures interactives : codées par leçon ou génériques ? | **Génériques** : quelques sortes de figures réutilisables, décrites dans le contenu de la leçon et remplies par l'IA. | Aucun code propre à une leçon. Il faut un catalogue de sortes de figures (à recenser sur les 39 leçons) et leur description dans le format d'échange → ADR. Les figures existantes propres à une leçon (Thalès, lentilles) sont à remplacer ou à garder : à trancher. |
| Tous les niveaux d'un coup ou un pilote ? | **Pilote 3e** (BEPC, Thalès sert de modèle), puis les autres niveaux avec le même pipeline. | Ce chantier livre le format, les figures génériques, le pipeline et les leçons de 3e. Les autres niveaux de maths sortent du périmètre de ce chantier (chantiers suivants, sans nouveau cadrage du format). |
| Comment supprimer les anciennes leçons ? (aucun outil n'existe) | D'abord « remplacement à l'import », puis **révisé par le porteur** : une **commande à lancer par environnement**, qui montre un aperçu (leçons, copies, notes perdues) et ne supprime qu'après confirmation écrite du porteur. | Suppression séparée de l'import : l'import reste un ajout. Aucune interface, aucun bouton. L'aperçu porte la confirmation exigée par la décision n°4. Le périmètre de la suppression (quelles leçons) reste à fixer. |
| Quelles anciennes leçons supprimer, et quand ? | **Toutes les mathématiques, tout de suite** (les 39), sans attendre la réécriture des autres niveaux. | Entre la suppression et les chantiers suivants, seuls les élèves de 3e ont des leçons de maths ; les autres niveaux n'en ont aucune. L'écran d'une matière sans leçon doit afficher un état vide clair. |
| Devoirs ouverts sur une ancienne leçon au moment de la suppression ? | **Aucun utilisateur actif aujourd'hui.** Le porteur remet la base à zéro lui-même (tous les contenus supprimés) et on repart de là. | Plus de commande de suppression à créer, plus d'aperçu des pertes, plus de cas « devoir ouvert » : la décision précédente (commande) devient sans objet. La remise à zéro vide aussi les autres matières : elles restent vides jusqu'à leur réécriture. Aucune reprise de l'ancien contenu à prévoir. La confirmation explicite avant Staging et main reste due, mais c'est le porteur qui agit. |
| Retirer l'ancien format et la fiche des notions essentielles du code ? | **Oui.** | Un seul format accepté à l'import ; l'ancien est refusé avec un message clair. La fiche des notions essentielles disparaît de l'application (écran, images, données). Chantier plus gros mais un seul format à maintenir → ADR (changement de contrat d'import). |
| Contenu de la fiche de révision ? | **Gabarit fixe** par notion : À retenir · La méthode (étapes numérotées) · Un exemple corrigé (qui applique les étapes) · Le piège à éviter, + figure interactive générique si utile. Ni glossaire ni exercices dans la fiche. | Les 8 sortes de blocs, les 3 pages et le glossaire disparaissent → refonte de l'écran de la fiche (UDR). Le contrôle automatique peut vérifier le gabarit bloc par bloc. Les corrections d'exercices reprennent les étapes et les mots de « La méthode ». |
| Organisation des exercices sans fiches essentielles ? | **1 exercice d'application par notion** de la fiche de révision + **4 problèmes de synthèse** par leçon ; chacun ≥ 5 questions, correction avec méthode détaillée. | L'exercice se rattache désormais à une notion de la fiche de révision (et non plus à une fiche essentielle) : changement du format d'échange et du lien en base → ADR. Le contrôle vérifie : une notion = un exercice, exactement 4 problèmes, ≥ 5 questions partout. |
| Qui garantit la justesse des corrections ? | Contrôle automatique + **relecture IA indépendante qui refait les calculs** ; pour le pilote 3e, **un enseignant de maths relit aussi** avant import. Ensuite IA seule si le pilote est propre. | Une étape humaine dans le pipeline du pilote : l'import de la 3e attend la relecture de l'enseignant (délai hors de notre main). Il faut un support de relecture lisible sans l'application (export lisible des leçons). Critère de sortie du pilote à définir (ex. : aucune erreur de fond trouvée par l'enseignant). |
| Enseignants et parents : qu'est-ce qui change ? | Les enseignants donnent exercices et devoirs à leur classe **comme aujourd'hui**. Rien de nouveau pour les parents. | Aucun écran nouveau pour eux. À vérifier : le devoir s'appuie sur les nouveaux exercices (rattachés à une notion ou problèmes de leçon) sans changer le parcours de l'enseignant. |
| Quelles sortes de figures génériques ? | Pas de catalogue fixé à l'avance : **chaque figure présente dans une leçon est générée avec son paramétrage**, pour être réutilisable dans la fiche de révision et dans les exercices. | La figure devient un contenu paramétré (sorte + paramètres), décrit dans le fichier de la leçon et citable depuis la fiche comme depuis un exercice. Les sortes de figures naissent des leçons de 3e au fil de la rédaction ; chaque nouvelle sorte demande son rendu → le catalogue des sortes est un livrable du chantier (ADR). |
| Les 3 fiches illustrées existantes (Thalès, Lentilles, Texte argumentatif) ? | **Supprimées** ; leurs figures sont reprises en figures génériques réutilisables (fiches de révision et exercices) si besoin. | Les fiches illustrées, leurs données de démarrage et les figures propres à une leçon sortent de l'application. Thalès et les lentilles deviennent des sortes de figures paramétrées. |
| Qui relit le pilote, et quand ? | **Juste après la génération**, dans l'application : la leçon importée attend une **validation avant publication**. | On s'appuie sur le circuit existant brouillon → publication par l'équipe : l'import crée des leçons en brouillon, rien n'est visible des élèves avant validation. La relecture se fait dans l'application (pas d'export à part). L'aperçu en brouillon doit montrer fiche, figures, exercices **et corrections** pour être relu. |
| Réimport d'une leçon déjà importée ? | **On refuse.** Précisé en phase 2 : refus si la leçon a déjà été publiée ; une leçon **encore en brouillon** est remplacée par le réimport. | Message clair qui nomme la leçon publiée ; rien n'est modifié. Une erreur trouvée à la relecture se corrige dans le fichier, qu'on réimporte tant que la leçon est en brouillon (les écrans d'édition des exercices n'existent plus). |
| Mise en forme de la fiche de révision : cahier ou styles de l'application ? | **Garder l'habillage cahier** (papier Seyès, titres manuscrits, police à empattements, 3 thèmes, encadrés). | Seul le contenu passe au gabarit en 4 blocs. La feuille de style à part et ses polices restent ; seules les parties sans données (lexique, explication simple, exercices dans la page) sont retirées. Le corrigé de l'équipe, outil interne, garde les styles de l'application. |

## Cas limites identifiés

- Matière sans aucune leçon (toutes les matières hors maths 3e après la remise à zéro) : état vide clair pour l'élève et l'enseignant.
- Notion sans figure utile : la fiche s'affiche sans figure, sans emplacement vide.
- Leçon d'une seule notion : 1 exercice + 4 problèmes ; leçon de nombreuses notions : autant d'exercices que de notions.
- Fichier de l'ancien format présenté à l'import : refus avec message clair, rien d'importé.
- Fichier partiellement valide (une notion sans exercice, un problème de moins de 5 questions) : refus total, aucune leçon à moitié importée.
- Figure générique mal décrite (sorte inconnue, données incohérentes) : refusée au contrôle, jamais une figure cassée à l'écran.
- Réimport d'une leçon déjà publiée (ou archivée) : refusé, message nommant la leçon, rien de modifié. Leçon en brouillon : remplacée entière.
- Figure citée par un exercice mais absente de la leçon : refusée au contrôle.

## Questions encore ouvertes

- ~~Critère de sortie du pilote 3e~~ → **tranché par le porteur** : les 10 leçons de 3e s'importent sans erreur, et leur contenu respecte les spécifications du plan (gabarit des 4 blocs, 1 exercice par notion + 4 problèmes, ≥ 5 questions, correction rédigée qui suit la méthode, figures paramétrées).
- **Thème teal (porteur)** : « À retenir » et « La méthode » ne partagent plus le même vert ; chaque bloc a sa couleur (UDR §3.2).
