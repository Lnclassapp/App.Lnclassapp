# PRD — Message prêt dans le lien WhatsApp de la carte d'aide

## 1. Contexte

La ligne WhatsApp de la carte d'aide ouvre une conversation vide ([memo](memo.md)). Elle ouvrira désormais WhatsApp avec un message déjà écrit, modifiable, qui présente la personne connectée. Seuls changent le lien et l'en-tête de la direction, qui gagne « Besoin d'aide ? » ([UDR-0128](../../decisions/udr/0128-message-pret-dans-le-lien-whatsapp-de-la-carte-d-aide.md)).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Élève | Ouvrir WhatsApp avec nom, classe, établissement | Voir les données d'un autre compte |
| Enseignant(e) | Idem avec sa matière et son établissement principal | — |
| Visiteur | Ouvrir WhatsApp avec le message simple | — |
| Direction | Ouvrir la carte depuis son en-tête, WhatsApp avec nom, « membre de la direction », établissement | — |
| Équipe | — (pas de carte d'aide : c'est le support) | — |

Aucune règle d'autorisation nouvelle : le message ne lit que la personne connectée, déjà lue par le shell.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève touche « Besoin d'aide ? », puis « Chatter avec le support ».
2. WhatsApp s'ouvre sur la conversation du support, le champ rempli : « Bonjour Lnclass, je suis Awa Koné, élève de Tle D 1, Lycée moderne de Cocody. Ma question : ».
3. Elle écrit sa question à la suite et envoie.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Visiteur (connexion, inscription élève) | « Bonjour Lnclass, ma question : » |
| Élève sans classe active | « …, élève. Ma question : » |
| Numéro WhatsApp absent de la configuration | Pas de ligne WhatsApp (inchangé) |
| Numéro configuré avec un 0 de tête | Le test de la configuration échoue avant la mise en ligne |

## 4. Critères d'acceptation

```gherkin
Scénario: CA-1 — élève connecté
  Étant donné l'élève Awa Koné, en Tle D 1 au Lycée moderne de Cocody
  Quand elle ouvre la carte d'aide
  Alors le lien WhatsApp est wa.me/<numéro configuré>?text=<message encodé>
  Et le message décodé est « Bonjour Lnclass, je suis Awa Koné, élève de Tle D 1, Lycée moderne de Cocody. Ma question : »
  Et il ne contient ni son numéro, ni son code secret, ni aucun identifiant

Scénario: CA-2 — enseignant connecté
  Étant donné l'enseignant Yao N'Guessan, de Physique-Chimie au Lycée d'Abidjan
  Quand il ouvre la carte d'aide
  Alors le message décodé est « Bonjour Lnclass, je suis Yao N'Guessan, enseignant de Physique-Chimie, Lycée d'Abidjan. Ma question : »

Scénario: CA-3 — visiteur
  Étant donné une personne non connectée sur la connexion ou l'inscription élève
  Quand elle ouvre la carte d'aide
  Alors le message décodé est « Bonjour Lnclass, ma question : »

Scénario: CA-4 — direction et équipe
  Étant donné Koffi Yao, de la direction du Collège Notre-Dame
  Quand il ouvre « Besoin d'aide ? » depuis son en-tête, y compris à 390 px sans défilement horizontal
  Alors le message décodé est « Bonjour Lnclass, je suis Koffi Yao, membre de la direction, Collège Notre-Dame. Ma question : »
  Et un membre de l'équipe n'a aucun lien WhatsApp du support dans son en-tête

Scénario: CA-5 — encodage et données
  Étant donné un nom avec apostrophe et un établissement avec accent et « & »
  Alors le lien n'a que des caractères sûrs (%20, %27, %C3%A8, %26) et se décode en le message d'origine
  Et le message réutilise la lecture du shell, sans requête de plus
  Et un numéro de support qui commence par 0 est refusé par le test de la configuration
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | — |
| Infrastructure | La lecture du shell rend aussi les éléments du détail, séparés, et le genre |
| Delivery | Le shell transmet ces éléments à la vue |
| UI | La carte d'aide reçoit la personne de l'en-tête ; l'en-tête de la direction la rend ; textes dans la locale de la carte |

## 6. Décisions rattachées

- UDR-0128 — message prêt du lien WhatsApp (amende UDR-0061 §3.4)
- UDR-0006 (en-tête de la direction), ADR-0049 (aucun service tiers)

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes de la lecture du shell (élève / enseignant / direction) | 2 / 3 / 2 | inchangé | 2 / 3 / 2 |
