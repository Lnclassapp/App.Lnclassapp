---
name: casl
description: Déclenche le Continuous Autonomous Security Loop (CASL) avec Strix pour auditer l'application, corriger les failles et configurer la CI.
---

# Continuous Autonomous Security Loop (CASL)

Lorsqu'un utilisateur demande à lancer "CASL" ou tape une commande similaire comme "/CASL", tu agis comme un ingénieur DevSecOps Senior et tu DOIS exécuter automatiquement la boucle de sécurité suivante en utilisant les compétences Strix installées :

## Étape 1 : Audit et Exploitation (Red Team)
- Utilise la compétence `penetration-testing-with-strix` pour lancer un pentest complet de l'application de manière autonome.
- Attend la fin du scan et lis les résultats (vulnérabilités confirmées avec PoC).

## Étape 2 : Remédiation Automatique (Blue Team)
- Utilise la compétence `fix-security-vulnerabilities-with-strix` pour analyser chaque faille trouvée.
- Applique directement les correctifs nécessaires dans le code source pour corriger la racine du problème.

## Étape 3 : Validation (Zero-Regression)
- Relance l'audit (ou demande à la compétence de remédiation de vérifier) pour t'assurer que le PoC original ne fonctionne plus.
- Valide que le code est sécurisé.

## Étape 4 : CI/CD (Shift-Left)
- Invoque la compétence `ci-security-scanning-with-strix`.
- Configure un pipeline CI (ex: GitHub Actions) pour que Strix scanne automatiquement les futures Pull Requests.

## Étape 5 : Rapport et Traçabilité (Audit Trail)
- Crée un artefact formel sous forme de fichier Markdown dans le dossier `docs/security_and_pentesting/` (par exemple `CASL_Report_YYYY-MM-DD.md`).
- Le rapport DOIT inclure : les vecteurs d'attaque essayés, les preuves de concept (PoC) ayant réussi, le détail des correctifs appliqués, et le statut final de validation.

**Instructions pour l'agent :** Exécute ces étapes l'une après l'autre de manière systématique et ininterrompue. Ne termine pas le workflow sans avoir généré et sauvegardé le rapport d'audit détaillé, puis notifie l'utilisateur.
