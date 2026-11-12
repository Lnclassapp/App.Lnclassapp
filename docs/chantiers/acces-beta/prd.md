# PRD — Accès complet gratuit pendant la bêta

## 1. Contexte

Pendant la bêta, l'élève a l'accès complet gratuit (décision du porteur). Le bandeau d'abonnement de l'accueil et le blocage après 7 jours disparaissent, sans supprimer le code de l'offre : un seul réglage les rallume après la bêta ([memo](memo.md)).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | démarrer un exercice et vérifier un entraînement, quelle que soit l'ancienneté du compte ; activer une carte | — |
| Teacher, SchoolStaff, Team | inchangé (jamais bloqués) | — |

Règle : `Entities::Billing::Access` (statut calculé) lue par les use cases qui démarrent une séance ou jugent un entraînement.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève ouvre l'accueil : aucun bandeau d'abonnement, aucun lien « M'abonner ».
2. Il démarre un exercice ou vérifie un entraînement : c'est accepté, même des semaines après la création du compte.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| L'élève ouvre Mon abonnement à la main | Carte « Accès complet gratuit pendant la bêta », sans compte à rebours ; la saisie d'un code reste possible |
| L'élève a une carte activée | Il reste abonné, avec sa date |
| La date de fin de bêta est posée et atteinte | Chaque élève non abonné a 7 jours gratuits à partir de cette date (bandeau compris), puis il est bloqué ; un compte créé après la fin compte depuis sa création |

## 4. Critères d'acceptation

```gherkin
Étant donné la bêta ouverte et un élève dont le compte a plus de 7 jours
Quand il ouvre l'accueil
Alors il ne voit ni bandeau d'abonnement ni lien vers Mon abonnement

Étant donné la bêta ouverte et un élève dont le compte a plus de 7 jours
Quand il démarre un exercice
Alors la séance est créée, sans redirection vers Mon abonnement

Étant donné la bêta ouverte et un élève dont le compte a plus de 7 jours
Quand il vérifie un entraînement de notion
Alors l'entraînement est jugé, jamais refusé

Étant donné la bêta ouverte et un élève abonné
Alors son accès reste « abonné » avec sa date

Étant donné la bêta ouverte
Quand l'élève ouvre Mon abonnement
Alors il lit « Accès complet gratuit pendant la bêta » et aucun compte à rebours

Étant donné une fin de bêta posée au 10 janvier et un élève inscrit en novembre
Quand il ouvre l'accueil le 9 janvier
Alors il ne voit aucun bandeau
Quand il démarre un exercice le 16 janvier
Alors la séance est créée et l'accueil dit « Il te reste 1 jour gratuit »
Quand il démarre un exercice le 17 janvier
Alors rien n'est créé et il est redirigé vers Mon abonnement
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | réglage de l'offre ; statut `beta` de l'accès ; prédicat « invité à s'abonner » |
| Infrastructure | aucun changement |
| Delivery | aucun changement |
| UI | bandeau de l'accueil masqué en bêta ; carte d'état « bêta » sur Mon abonnement ; une clé I18n |

## 6. Décisions rattachées

- ADR-XXXX-acces-beta-reglage-unique — le réglage unique de la bêta
- UDR-XXXX-acces-beta-sans-abonnement — l'élève ne voit aucune invitation à s'abonner pendant la bêta
