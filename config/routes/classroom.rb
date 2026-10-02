# 🌐 DELIVERY · routes du contexte classroom
# Rôle : adhésion par code, accueils élève et enseignant, page de classe, assignations
# ADR  : 0030, 0040, 0041, 0048
get "join", to: "classroom/join_codes#new", as: :new_join_code
post "join", to: "classroom/join_codes#create", as: :join_codes
get "c/:code", to: "classroom/joins#new", as: :join_classroom
post "c/:code", to: "classroom/joins#create"

get "students", to: "classroom/student_homes#show", as: :student_home                       # gelé
get "students/classroom", to: "classroom/student_classrooms#show", as: :student_classroom   # gelé
get "teachers", to: "classroom/teacher_homes#show", as: :teacher_home                       # gelé
get "teachers/classrooms", to: "classroom/teaching_selections#index", as: :teacher_classrooms # gelé
post "teachers/classrooms/:classroom_public_id/teaching", to: "classroom/teachings#create", as: :classroom_teaching
delete "teachers/classrooms/:classroom_public_id/teaching", to: "classroom/teachings#destroy"
post "teachers/onboarding", to: "classroom/teacher_onboardings#create", as: :teacher_onboarding

get "classrooms/:public_id", to: "classroom/classrooms#show", as: :classroom
get "classrooms/:classroom_public_id/courses/:course_slug", to: "classroom/classroom_courses#show", as: :classroom_course
get "classrooms/:classroom_public_id/courses/:course_slug/essentials/:essential_slug",
    to: "classroom/classroom_essentials#show", as: :classroom_essential
post "classrooms/:classroom_public_id/assignments", to: "classroom/assignments#create", as: :classroom_assignments
patch "assignments/:public_id/archive", to: "classroom/assignments#archive", as: :archive_assignment
get "courses/:course_slug/assignments", to: "classroom/course_assignments#index", as: :course_assignments
