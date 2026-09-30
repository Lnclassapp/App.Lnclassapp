# Memo — App Android pour élèves et enseignants

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-09-30 |
| **Branche** | `ccr-9b7287af-3kx7cj` *(branche imposée par la session ; `feature/app-android` selon la convention)* |
| **Programme** | — *(hors plan de `refonte-application` ; la PWA reste en V4, `installation-pwa`)* |

---

## Le problème

Lnclass n'existe que dans le navigateur. Un élève ou un enseignant qui cherche « Lnclass » sur le Play Store ne trouve rien, n'a pas d'icône sur son téléphone, et ne bénéficie d'aucune fonction du téléphone : ni vibration, ni partage natif, ni notification.

L'installation depuis le navigateur (PWA) qui donnerait au moins l'icône n'est pas branchée et reste au backlog (V4). Plusieurs plans antérieurs prévoyaient des applications en magasin (juin 2026, Turbo Native), sans qu'aucune ligne de code natif ne soit écrite.

## Pour qui

- **Élève**, sur un téléphone Android, souvent d'entrée de gamme et en 3G/4G : de l'installation depuis le Play Store jusqu'à la session d'exercice.
- **Enseignant**, sur un téléphone Android : suivi de ses classes et assignation du contenu.
- **Direction d'établissement** : reste sur la web app responsive, sans application.
- **Équipe** : reste sur le web *(hypothèse à confirmer au grill)*.

## Pourquoi maintenant

Pas d'urgence de livraison : le chantier est **cadré puis mis en attente** (décision du porteur, 2026-09-30). Le cadrer maintenant sert à fixer la stratégie mobile par écrit (Android d'abord, Hotwire Native, établissements sur le web, PWA et iOS plus tard) et à trancher tôt les décisions longues : compte Play Store, public mineur, paiement, version d'Android minimale.

## Hors périmètre

*Première version, à durcir pendant le grill.*

- Une application iOS.
- L'installation depuis le navigateur (PWA), qui reste au chantier `installation-pwa` de la V4.
- Une application pour la direction d'établissement ou pour l'équipe.
- Le rôle Parent, écarté du plan le 2026-09-22.
- Réécrire des écrans en natif : les écrans restent ceux du site.
- Le paiement dans l'application.

## Ce que le grill a révélé

> Rempli au fil du grill, une question à la fois.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| | | |

## Cas limites identifiés

- …

## Questions encore ouvertes

- …
