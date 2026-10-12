# Memo — Fiches en blocs

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | décision |
| **Ouvert le** | 2026-10-12 |
| **Branche** | `feature/contenu-en-blocs` |
| **Programme** | — |

---

## Le problème

Une fiche de cours et une fiche de révision ne sont aujourd'hui qu'un long texte mis en forme : titres, listes, gras, formules. L'élève lit un mur de texte sur son téléphone. Rien ne distingue une propriété à retenir d'un piège à éviter, rien ne se replie, aucun mot difficile n'est expliqué sur place.

L'équipe a reçu un modèle de fiche (9 fiches maquettées : Thalès, Lentilles, Texte argumentatif, Digestion, Colonisation, Devoirs des parents, Dissertation philosophique, Cinématique, plus une version mobile à onglets de Colonisation). Toutes suivent la même grammaire : en-tête, encadrés « Propriété », « À retenir », « Attention », « Rédaction type » en étapes, explication « En clair » à afficher ou masquer, lexique en bulles, exemple rédigé, tableau, sources, correction à révéler. Lnclass ne sait afficher aucun de ces éléments, et le filtre de sécurité du texte enrichi refuse tableaux et images.

213 leçons déjà rédigées existent sous forme de texte mis en forme.

## Pour qui

- **L'élève**, qui lit une fiche sur un téléphone d'entrée de gamme, souvent sur une connexion lente, en classe ou le soir pour réviser.
- **L'équipe**, qui écrit ou fait écrire les fiches et les importe.
- **L'enseignant**, qui ouvre la même fiche pour la projeter ou la conseiller à sa classe.

## Pourquoi maintenant

Le modèle de fiche est validé par le porteur (style cahier, mobile d'abord, import avant tout éditeur). Les chantiers suivants (questions enrichies, médias interactifs, entraînement illimité) s'appuient sur ce format : tant qu'il n'existe pas, chaque nouvelle leçon est écrite dans l'ancien format et devra être reprise.

## Hors périmètre

Ce qu'on ne fera **pas** dans ce chantier. Cette section est la plus utile du memo : c'est elle qui empêche le chantier de gonfler.

- Les nouveaux types de questions notées (numérique, remise en ordre, association, texte à trous, indice) : chantier `questions-enrichies`.
- Les médias interactifs (frise, schéma cliquable, carte, figures Thalès, lentilles, cinématique) : chantier `medias-interactifs`.
- L'entraînement illimité et l'atelier « Je rédige » : chantier `entrainement-illimite-redaction`.
- Un éditeur par blocs dans l'interface de l'équipe : l'import vient d'abord.
- La mise en page A4 pour l'impression.
- Les images fixes (schéma, photo, carte en image) : avec `medias-interactifs`.
- Les onglets de la maquette mobile.
- Un aperçu du nouveau format en production : la relecture se fait sur la recette.
- Parent (n'existe pas) et direction d'établissement : rien ne change pour eux.
- La conversion des 213 leçons elle-même : chantier de contenu à part, qui conditionne la bascule.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Que deviennent les 213 leçons déjà rédigées en texte mis en forme ? | Toutes réécrites en blocs avant la livraison. | Un seul format à la livraison : le texte mis en forme disparaît des fiches de cours et de révision. La réécriture des 213 leçons devient une condition de mise en production, à cadrer (qui, avec quel outil, quel contrôle). |
| Qui réécrit, et la mise en ligne attend-elle la dernière leçon ? | Un modèle de langue convertit, l'équipe relit ; bascule unique quand les 213 leçons sont converties et relues. | Le chantier livre le format, l'import et le guide de rédaction en blocs ; la conversion des 213 leçons est un chantier de contenu à part, qui conditionne la bascule. Les élèves ne voient le nouveau format qu'au jour de la bascule : jusque-là, la production garde l'ancien affichage. |
| À quoi le lexique est-il rattaché ? | À rien : la définition s'écrit dans la fiche, au mot souligné. | Pas de liste de mots à gérer, pas d'écran de lexique pour l'équipe. Un même mot peut avoir deux définitions dans deux fiches. Si la fiche montre un lexique complet, il se déduit des mots définis dans cette fiche, il ne se saisit pas. |
| Sur téléphone, onglets, page qui défile ou sections repliables ? | Une page qui défile, un sommaire en tête, le lexique de la fiche en bas. | Pas d'onglets dans ce chantier : la maquette mobile à onglets est écartée. La lecture marche sans JavaScript ; seuls la bulle du lexique, « En clair » et « Voir la correction » en demandent, avec un repli lisible sans. |
| Qui décide quand la correction d'un exercice d'application s'affiche ? | L'enseignant la débloque, par classe. | Le chantier traverse `classroom` : un réglage par classe et par fiche. Une correction verrouillée n'est jamais envoyée au navigateur de l'élève (même règle que les réponses notées). L'enseignant a un geste nouveau sur la fiche de sa classe. Restent à trancher : l'état par défaut, l'élève sans classe, deux enseignants d'une même classe. |
| État par défaut, et l'élève sans classe ? | Verrouillée en classe tant que l'enseignant ne débloque pas ; l'élève sans classe la voit toujours. | La règle d'affichage dépend de l'appartenance de l'élève à une classe, donc de la classe qui fait foi : à préciser pour un élève passé d'une classe à une autre. L'équipe et l'enseignant voient toujours la correction. |
| L'enseignant débloque une correction, une fiche ou une leçon ? | Toute la fiche d'un coup, pour sa classe. | Un seul interrupteur par fiche et par classe ; il survit au réimport de la fiche. Les exercices d'application n'ont pas besoin d'identifiant propre. |
| Le chantier ouvre-t-il les images fixes ? | Non : elles viennent avec `medias-interactifs`. | Aucun fichier téléversé dans ce chantier, donc pas de menace « fichier envoyé » à écrire. La réécriture des 213 leçons se fait sans image ; une leçon qui en a besoin le signale pour plus tard. |
| Où s'applique l'écriture manuscrite (Kalam) ? | Titres, « En clair » et notes en marge ; le corps reste dans la police Lnclass, sur fond Seyès. | Une police de plus, hébergée par Lnclass et chargée seulement sur les fiches : elle entre dans le budget de poids des pages. |
| Un bloc mal formé dans un import ? | Le bloc est ignoré, la fiche passe, avec un avertissement. | Risque de perte silencieuse : chaque bloc ignoré est nommé dans le rapport d'import (fiche, position, raison), et le rapport le compte en tête. Un import avec avertissements ne se confond pas avec un import propre. |
| Où l'équipe relit-elle les 213 leçons avant la bascule ? | Sans préférence du porteur : sur la recette (option la plus simple). | Le nouveau format se déploie sur la recette ; les leçons converties y sont importées et relues. La production reçoit code et contenu le jour de la bascule. Rien à construire pour un aperçu en production. |
| *(lu dans le code)* Parent, direction d'établissement ? | Le Parent n'existe pas dans Lnclass ; la direction ne lit pas les fiches. | Rien pour eux : écrit dans `Hors périmètre`. |
| *(lu dans le code)* Élève dans plusieurs classes, enseignant dans deux établissements ? | Un élève n'a qu'une classe active ; le multi-établissement enseignant est reporté (porteur, 2026-09-28). | La classe active de l'élève fait foi pour le verrou des corrections. Un enseignant débloque pour chacune de ses classes, quel que soit l'établissement. |

## Cas limites identifiés

- Une fiche sans aucun exercice d'application : pas de bouton de déverrouillage pour l'enseignant.
- Une fiche dont tous les blocs sont ignorés à l'import : elle n'est pas créée vide, elle est refusée.
- Un élève qui change de classe : il suit le verrou de sa nouvelle classe.
- L'élève quitte sa classe (classe archivée, retrait) : il devient « sans classe » et voit les corrections.
- Une fiche réimportée après déverrouillage : le déverrouillage tient.
- Un mot du lexique défini deux fois dans la même fiche : la première définition fait foi, l'import avertit.
- Une formule KaTeX invalide dans un bloc : le bloc est ignoré avec avertissement, comme tout bloc mal formé.
- Une fiche très longue (20 encadrés et plus) sur un téléphone d'entrée de gamme : le sommaire doit rester utile.
- JavaScript coupé ou en échec : « En clair », lexique et correction restent lisibles (repli sans script), la correction verrouillée reste absente.

## Questions encore ouvertes

- La liste exacte des types de blocs du premier jet (à figer dans le PRD à partir des 9 maquettes).
- L'enseignant reverrouille-t-il une correction après l'avoir débloquée ? (proposé : oui, même interrupteur)
- Le chantier de conversion des 213 leçons : qui l'ouvre, avec quel prompt et quel contrôle de relecture.
