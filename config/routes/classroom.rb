# 🌐 DELIVERY · routes du contexte classroom
# Rôle : inscription de l'élève, adhésion par code ou par lien, lien d'une classe, retrait d'un élève, accueils élève et enseignant, historique de l'élève, page de classe, assignations, jours de séance et suivi
# ADR  : 0030, 0036, 0040, 0041, 0048, 0072, 0085
get "join", to: "classroom/join_codes#new", as: :new_join_code
post "join", to: "classroom/join_codes#create", as: :join_codes
get "c/:code", to: "classroom/joins#new", as: :join_classroom
post "c/:code", to: "classroom/joins#create"
# ADR-0085 §4 : l'élève s'inscrit en choisissant sa classe (DRENA → établissement → niveau → classe), sans code.
get "student-signup", to: "classroom/student_registrations#new", as: :new_student_registration
post "student-signup", to: "classroom/student_registrations#create", as: :student_registrations
# ADR-0085 §4.3 : l'élève sans classe active (classe archivée, ou retiré) en choisit une par la même cascade.
get "students/classroom/new", to: "classroom/student_classroom_choices#new", as: :new_student_classroom_choice
post "students/classroom", to: "classroom/student_classroom_choices#create", as: :student_classroom_choices

get "students", to: "classroom/student_homes#show", as: :student_home                       # gelé
get "students/classroom", to: "classroom/student_classrooms#show", as: :student_classroom   # gelé
# Lot R (ADR-0036, memo Q19) : l'archive de l'élève, consultable même sans classe active.
get "students/archive", to: "classroom/student_archives#show", as: :student_archive
get "teachers", to: "classroom/teacher_homes#show", as: :teacher_home                       # gelé
get "teachers/classrooms", to: "classroom/teaching_selections#index", as: :teacher_classrooms # gelé
post "teachers/classrooms/:classroom_public_id/teaching", to: "classroom/teachings#create", as: :classroom_teaching
delete "teachers/classrooms/:classroom_public_id/teaching", to: "classroom/teachings#destroy"
post "teachers/onboarding", to: "classroom/teacher_onboardings#create", as: :teacher_onboarding

get "classrooms/:public_id", to: "classroom/classrooms#show", as: :classroom
# ADR-0085 §4.1, §4.5 : changer le lien de la classe, retirer un élève (ManageClassroomMembersPolicy).
patch "classrooms/:public_id/link", to: "classroom/classroom_links#update", as: :classroom_link
delete "classrooms/:classroom_public_id/students/:student_public_id", to: "classroom/classroom_students#destroy",
                                                                      as: :classroom_student
get "classrooms/:classroom_public_id/courses/:course_slug", to: "classroom/classroom_courses#show", as: :classroom_course
get "classrooms/:classroom_public_id/courses/:course_slug/essentials/:essential_slug",
    to: "classroom/classroom_essentials#show", as: :classroom_essential
# ADR-0072, UDR-0062 §3.4, §3.5 : `new` avant le suivi, que son :public_id capturerait.
get "classrooms/:classroom_public_id/assignments/new", to: "classroom/assignments#new", as: :new_classroom_assignment
post "classrooms/:classroom_public_id/assignments", to: "classroom/assignments#create", as: :classroom_assignments
get "classrooms/:classroom_public_id/assignments/:public_id", to: "classroom/assignment_follow_ups#show", as: :classroom_assignment
get "classrooms/:classroom_public_id/session_days/edit", to: "classroom/session_days#edit", as: :edit_classroom_session_days
patch "classrooms/:classroom_public_id/session_days", to: "classroom/session_days#update", as: :classroom_session_days
patch "assignments/:public_id/archive", to: "classroom/assignments#archive", as: :archive_assignment
