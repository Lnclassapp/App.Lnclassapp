# Memo — « Choisis ta classe » aux couleurs Wave et Djamo

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-15 |
| **Branche** | `Develop` (cadrage, docs seules) ; le code passera par une PR |
| **Programme** | — |

---

## Le problème

« Choisis ta classe » (`classroom/student_classroom_choices#new`) fonctionne, mais ses quatre listes déroulantes ne ressemblent pas aux écrans élève redessinés (`accueil-eleve`, `cours-eleve`, `ma-classe-eleve`, `exercice-eleve`, `profil-eleve`, `historique-eleve`).

## Pour qui

L'élève sans classe active (classe archivée, ou retiré), le plus souvent sur un téléphone Android d'entrée de gamme.

## Hors périmètre

- Les règles d'adhésion (ADR-0085) : classe complète, élève retiré, déjà inscrit, lien plus valable.
- Les listes servies par le serveur (DRENA, établissements, niveaux qui ont une classe active, classes) et le repli sans JavaScript.

## Point de départ : la page actuelle

Relevée dans le code le 2026-10-15 (ADR-0040, ADR-0085, UDR-0081 §3.3 à §3.5) : « Choisis ta classe » avec « Accueil » ; une carte avec la cascade partagée `_class_picker` (DRENA → établissement → niveau en listes déroulantes, puis une ligne radio par classe, « Complète » désactivée), la DRENA et l'établissement de la dernière classe déjà choisis ; alertes « Ce lien n'est plus valable. Choisis ta classe. » et refus en tête ; « Ta classe n'est pas encore sur Lnclass. » ; bouton « Rejoindre cette classe », inactif tant qu'aucune classe n'est cochée.

## Maquettes

Toile : https://claude.ai/artifact/QhGVuZiGSxEdCBqa4CKwaM (téléphone d'abord).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quelle page après l'historique ? | Le choix de classe (porteur, 2026-10-15). | Trois étapes numérotées ; l'établissement en une ligne avec « Changer » ; niveaux en pastilles, classes en grandes cases ; même en-tête et même menu (avec « Mon historique »). |

## Questions ouvertes

1. Les niveaux en pastilles et les classes en cases conviennent-ils ?
2. La même cascade sert à l'inscription (`_class_picker` partagé) : la garde-t-on identique ?
