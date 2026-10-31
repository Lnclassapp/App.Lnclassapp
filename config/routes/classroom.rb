# 🌐 DELIVERY · routes du contexte classroom
# Rôle : inscription de l'élève, adhésion par lien, lien d'une classe, fiche et retrait d'un élève, accueils élève et enseignant, historique de l'élève, page de classe, assignations, envois de plusieurs exercices, jours de séance et suivi
# ADR  : 0030, 0036, 0040, 0041, 0048, 0072, sujets-de-devoir (ajout du 2026-10-30), 0084, 0085, 0086, 0095, 0097, 0109
# IL-02 (ADR-0085, Lot F) : l'ancienne entrée « join » mène à l'inscription élève (le code revient, voir classroom-codes plus bas).
get "join", to: redirect("/student-signup")
get "c/:code", to: "classroom/joins#new", as: :join_classroom
post "c/:code", to: "classroom/joins#create"
# ADR-0109 (§4.4) : le code de six caractères revient à côté du lien ; sa vérification est une page
# (Turbo Frame), jamais du JSON, au débit `classroom/joins`. Nom et chemin gelés par le Lot 0 ; le contrôleur est celui du Lot A.
get "classroom-codes/:code", to: "classroom/classroom_codes#show", as: :classroom_code
# ADR-0085 §4 : l'élève s'inscrit en choisissant sa classe (DRENA → établissement → niveau → classe), sans code.
get "student-signup", to: "classroom/student_registrations#new", as: :new_student_registration
post "student-signup", to: "classroom/student_registrations#create", as: :student_registrations
# ADR-0085 §4.3 : l'élève sans classe active (classe archivée, ou retiré) en choisit une par la même cascade.
get "students/classroom/new", to: "classroom/student_classroom_choices#new", as: :new_student_classroom_choice
post "students/classroom", to: "classroom/student_classroom_choices#create", as: :student_classroom_choices
# ADR-0095 : l'élève à classe active change de classe ; seule la confirmation (POST) écrit.
get "students/classroom/change", to: "classroom/student_classroom_changes#new", as: :new_student_classroom_change
get "students/classroom/change/confirm", to: "classroom/student_classroom_changes#confirm", as: :confirm_student_classroom_change
post "students/classroom/change", to: "classroom/student_classroom_changes#create", as: :student_classroom_change

get "students", to: "classroom/student_homes#show", as: :student_home                       # gelé
get "students/classroom", to: "classroom/student_classrooms#show", as: :student_classroom   # gelé
# Lot R (ADR-0036, memo Q19) : l'archive de l'élève, consultable même sans classe active.
get "students/archive", to: "classroom/student_archives#show", as: :student_archive
# UDR-0080 §3.2 : le panneau du compte de l'élève comme page ; la coque Android l'ouvre en modale (ADR-0084 §4.3).
get "students/menu", to: "classroom/student_menus#show", as: :student_menu
# UDR-0082 §3.2 : le panneau du compte de l'enseignant, ouvert en modale par la coque « Lnclass Teacher » (ADR-0086 §4.4).
get "teachers/menu", to: "classroom/teacher_menus#show", as: :teacher_menu
get "teachers", to: "classroom/teacher_homes#show", as: :teacher_home                       # gelé
get "teachers/classrooms", to: "classroom/teaching_selections#index", as: :teacher_classrooms # gelé
post "teachers/classrooms/:classroom_public_id/teaching", to: "classroom/teachings#create", as: :classroom_teaching
delete "teachers/classrooms/:classroom_public_id/teaching", to: "classroom/teachings#destroy"
post "teachers/onboarding", to: "classroom/teacher_onboardings#create", as: :teacher_onboarding

get "classrooms/:public_id", to: "classroom/classrooms#show", as: :classroom
# ADR-0085 §4.1, §4.5 : changer le lien de la classe, retirer un élève (ManageClassroomMembersPolicy).
# ADR-0097 §4.1 : la fiche d'un élève dans sa classe, au même chemin que son retrait.
patch "classrooms/:public_id/link", to: "classroom/classroom_links#update", as: :classroom_link
get "classrooms/:classroom_public_id/students/:student_public_id", to: "classroom/classroom_students#show", as: :classroom_student
delete "classrooms/:classroom_public_id/students/:student_public_id", to: "classroom/classroom_students#destroy"
get "classrooms/:classroom_public_id/courses/:course_slug", to: "classroom/classroom_courses#show", as: :classroom_course
get "classrooms/:classroom_public_id/courses/:course_slug/essentials/:essential_slug",
    to: "classroom/classroom_essentials#show", as: :classroom_essential
# ADR-0072, UDR-0062 §3.4, §3.5 : `new` avant le suivi, que son :public_id capturerait.
get "classrooms/:classroom_public_id/assignments/new", to: "classroom/assignments#new", as: :new_classroom_assignment
post "classrooms/:classroom_public_id/assignments", to: "classroom/assignments#create", as: :classroom_assignments
get "classrooms/:classroom_public_id/assignments/:public_id", to: "classroom/assignment_follow_ups#show", as: :classroom_assignment
# ADR sujets-de-devoir (ajout du 2026-10-30) : un envoi de 1 à 10 exercices à la classe. Nom et chemin gelés par le Lot 0b ;
# le contrôleur est celui du Lot E.
post "classrooms/:classroom_public_id/assignment_batches", to: "classroom/assignment_batches#create", as: :classroom_assignment_batches
get "classrooms/:classroom_public_id/session_days/edit", to: "classroom/session_days#edit", as: :edit_classroom_session_days
patch "classrooms/:classroom_public_id/session_days", to: "classroom/session_days#update", as: :classroom_session_days
patch "assignments/:public_id/archive", to: "classroom/assignments#archive", as: :archive_assignment
