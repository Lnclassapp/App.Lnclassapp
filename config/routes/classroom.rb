# 🌐 DELIVERY · routes du contexte classroom
# Rôle : adhésion par code, accueils élève et enseignant, historique de l'élève, page de classe, assignations, jours de séance et suivi
# ADR  : 0030, 0036, 0040, 0041, 0048, 0072
get "join", to: "classroom/join_codes#new", as: :new_join_code
post "join", to: "classroom/join_codes#create", as: :join_codes
get "c/:code", to: "classroom/joins#new", as: :join_classroom
post "c/:code", to: "classroom/joins#create"

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
