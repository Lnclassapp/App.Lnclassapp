# Memo — Code d'établissement pour l'inscription des enseignants

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `feature/code-etablissement` |
| **Programme** | — |

---

## Le problème

Aujourd'hui, un enseignant s'inscrit seul en choisissant sa DRENA, puis son établissement dans une liste, puis sa matière. Rien ne vérifie qu'il y enseigne : **n'importe qui peut se déclarer de n'importe quel établissement actif**, et accéder ainsi à la liste nominative de ses classes (le coût consenti de l'ADR-0030). Les élèves, eux, ne rejoignent une classe qu'avec le code que leur donne leur professeur : sans code, pas de classe.

Demande du porteur (2026-09-28) : « développe le code d'établissement pour les profs, comme pour les élèves ».

## Pour qui

- **L'enseignant (Teacher)** qui s'inscrit : il saisit le code que lui a transmis son établissement, ou ouvre le lien qu'on lui a envoyé, et son établissement est trouvé sans chercher dans une liste de 3 900.
- **L'équipe (Team)**, qui transmet ce code à chaque établissement et le change quand il a fuité.

## Pourquoi maintenant

La production est ouverte depuis le 2026-09-27 et la rentrée est en cours : les inscriptions d'enseignants arrivent maintenant. Chaque jour sans code laisse entrer des inscriptions non vérifiables, qu'il faudra trier à la main.

## Hors périmètre

- **Les enseignants déjà inscrits** : leur rattachement ne change pas, aucun ne doit ressaisir de code.
- **La direction (`school_admin`) qui lit ou régénère le code** de son établissement : V2 ; en V1, seule l'équipe le voit.
- Afficher le code dans la **liste** des établissements, l'exporter en masse ou l'envoyer par SMS : la fiche suffit en V1.
- **Fermer** un code sans le remplacer (comme `CloseJoinCode` pour une classe) : désactiver l'établissement produit déjà cet effet.
- Retirer un enseignant inscrit avec un code qui avait fui : geste existant de l'équipe, inchangé.
- Supprimer l'adresse `/drenas/:drena_public_id/schools` (frame et JSON, SC-26) : elle n'est plus utilisée par l'inscription, mais reste une API publique documentée (UDR-0024 §4).
- Un code par enseignant ou à usage unique (invitation nominative) : c'est le rôle des invitations de l'équipe.
- Une expiration automatique du code.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Le code est-il obligatoire, ou une alternative à la liste DRENA → établissement ? | **Défaut retenu, à confirmer** : obligatoire. Garder la liste en parallèle laisserait la porte ouverte que le code doit fermer. | La sélection DRENA → établissement disparaît du formulaire. |
| Qui transmet le code, et où le lit-on ? | **Défaut retenu, à confirmer** : l'équipe, sur la fiche de l'établissement, avec « Copier » et un lien à partager. | Bloc « Code d'établissement » dans l'en-tête de la fiche. |
| Un code qui a fui ? | Il se remplace en un geste ; l'ancien cesse aussitôt de fonctionner. **Défaut retenu, à confirmer** : « Régénérer le code » dans le menu ⋮ de l'en-tête (UDR-0042), confirmé. | Use case de régénération, autorisé comme la gestion des établissements, tracé au journal d'audit. |
| Un enseignant peut-il confondre le code de sa classe et celui de son établissement ? | Oui : l'élève tape un code à 5 caractères, l'enseignant en recevra un autre. **Défaut retenu, à confirmer** : 6 caractères, affichés en deux groupes de trois séparés d'un tiret (`K7M-4QZ`). | Format distinct ; un code au format « classe » saisi par erreur reçoit un message dédié, qui ne révèle rien puisqu'aucune recherche n'a lieu. |
| Le code est-il devinable ? | 32 symboles (lettres sans I ni O, chiffres 2 à 9), 6 positions : ~1,07 milliard de codes pour ~3 900 établissements, soit 1 chance sur 275 000 par essai. Le code de classe, lui, a 884 736 valeurs. | Limite de débit de `/c/` reprise pour `/e/` (10 par minute et par adresse) ; l'envoi du formulaire garde ses 5 par minute. |
| Code inconnu, établissement désactivé, en brouillon, code remplacé : que voit-on ? | **Le même message neutre**, comme pour un code de classe : on ne dit jamais qu'un code existe mais qu'il est fermé. | Une seule erreur « Code d'établissement invalide » ; `/e/<code>` répond 404 dans tous ces cas. |
| Un établissement en brouillon accepte-t-il les inscriptions ? | Non, comme aujourd'hui : seul un établissement actif en accepte. Son code existe déjà et fonctionnera dès qu'il sera actif. | La fiche prévient : « tant que l'établissement n'est pas actif, ce code ne permet pas de s'inscrire ». |
| Les ~3 900 établissements de production ont-ils un code dès la mise en production ? | Oui : la migration leur en donne un à chacun, par lots, puis rend la colonne obligatoire. | Migration sans transaction globale : colonne nulle, remplissage par lots de 500, index unique construit sans bloquer les écritures, contrainte validée à part. |
| Et les établissements importés ensuite ? | Chacun reçoit son code dans la même écriture que son insertion, unique en base et dans le lot. | L'import tire les codes comme il tire les codes de classe (ADR-0041). |
| Une création manuelle d'établissement doit-elle générer un code ? | La demande le prévoit, mais aucun écran ne crée d'établissement en V1 (amendement de l'ADR-0030) ; le seul chemin est l'import. | Le contrat d'écriture unitaire du dépôt exige le code ; les seeds et les fabriques de test en tirent un. Écart consigné. |
| Deux régénérations tombent-elles sur le même code ? | Improbable, mais l'index unique refuse ; on retire au sort, cinq fois au plus. | Pas de verrou applicatif ; au-delà de cinq refus, « écriture refusée ». |
| Un enseignant arrive par le lien : doit-il retaper le code ? | Non : la page montre l'établissement trouvé (nom et DRENA, rien d'autre) et garde le code en champ caché, avec « Ce n'est pas votre établissement ? ». | L'aperçu ne révèle que deux noms, comme celui d'une classe (UDR-0009). |
| Une personne connectée ouvre `/e/<code>` ? | Même règle que `/teacher-signup` : renvoyée vers son accueil. | — |
| Un enseignant peut-il être rattaché à un établissement actif puis désactivé ? | Oui, inchangé : la désactivation ne détache personne. | — |

## Cas limites identifiés

- Code saisi avec des espaces, des tirets ou en minuscules (`k7m 4qz`, `K7M-4QZ`) : accepté, normalisé.
- Code d'un établissement désactivé, puis réactivé : il refonctionne (le code n'est pas effacé à la désactivation).
- Ancien code après régénération : invalide immédiatement, même message que l'inconnu.
- 11ᵉ ouverture de `/e/<code>` dans la minute depuis la même adresse : 429 sans aperçu.
- Migration interrompue (déploiement tué) : elle se relance et reprend là où elle s'est arrêtée (colonne, index et remplissage idempotents).
- Import d'établissements pendant la migration : à éviter (l'ancienne version du code insère sans code) ; si cela arrive, la migration échoue proprement et se relance.

## Questions encore ouvertes

Les quatre défauts ci-dessous ont été appliqués sans arbitrage du porteur ; ils sont **à confirmer** :

1. Code obligatoire, sélection DRENA → établissement supprimée.
2. L'équipe transmet le code (fiche, copier, lien, régénération dans le menu ⋮).
3. Format : 6 caractères sur 32 symboles, affiché `XXX-XXX`, lien `/e/<code>`.
4. Enseignants déjà inscrits inchangés ; `/e/` limité à 10 requêtes par minute et par adresse.
