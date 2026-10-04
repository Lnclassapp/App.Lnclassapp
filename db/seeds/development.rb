# ADR-0034: fictitious accounts and content for local development, PIN 2468 everywhere — a team member with a
# second factor, an onboarded SVT teacher of « Tle D 1 », a student of that classroom, and a published course
# with one essential and one exercise of 2 questions. Idempotent by contact and by name.
raise "db/seeds/development.rb est réservé au développement" unless Rails.env.development?

pin = "2468"
account = lambda do |contact, **attributes|
  Orm::User.find_by(contact:) || Orm::User.create!(contact:, pin:, gender: "female", **attributes)
end

member = account.call("0700000000", role: "team", team_role: "admin", last_name: "Kouassi", first_name: "Aya")
unless Orm::TotpCredential.exists?(user: member)
  Orm::TotpCredential.create!(user: member, secret: ROTP::Base32.random, confirmed_at: Time.current)
end
secret = Orm::TotpCredential.find_by!(user: member).secret
puts "Équipe : 0700000000, PIN #{pin}, secret TOTP de développement #{secret} (code actuel : #{ROTP::TOTP.new(secret).now})"

svt = Orm::Material.find_by!(slug: "svt")
tle = Orm::Level.find_by!(slug: "tle")
series_d = Orm::Series.find_by!(slug: "d")
classroom = Orm::Classroom.joins(:school).find_by!(name: "Tle D 1", schools: { name: "Lycée Moderne de Treichville" })

teacher = account.call("0500000001", role: "teacher", last_name: "Yao", first_name: "Koffi")
Orm::TeacherProfile.create!(user: teacher, material: svt, onboarding_completed_at: Time.current) unless teacher.teacher_profile
unless Orm::TeacherSchool.exists?(teacher_id: teacher.id)
  Orm::TeacherSchool.create!(teacher_id: teacher.id, school_id: classroom.school_id, primary: true)
end
unless Orm::TeacherClassroom.exists?(teacher_id: teacher.id, classroom:)
  Orm::TeacherClassroom.create!(teacher_id: teacher.id, classroom:)
end

student = account.call("0100000001", role: "student", last_name: "Traoré", first_name: "Awa")
unless Orm::ClassroomStudent.exists?(student_id: student.id)
  Orm::ClassroomStudent.create!(student_id: student.id, classroom:, primary: true, joined_at: Time.current)
end

now = Time.current
published = { status: "published", published_at: now }
course = Orm::Course.find_by(name: "La cellule", level: tle, series: series_d, material: svt) ||
         Orm::Course.create!(name: "La cellule", subtitle: "Unité du vivant", level: tle, series: series_d, material: svt,
                             author: member, content: "<p>La cellule est l'unité de base du vivant : $1\\,\\mu m$ à $100\\,\\mu m$.</p>",
                             **published)
essential = Orm::Essential.find_by(course:, name: "La membrane plasmique") ||
            Orm::Essential.create!(course:, name: "La membrane plasmique", position: 1, author: member,
                                   content: "<p>La membrane plasmique délimite la cellule et contrôle les échanges.</p>", **published)
unless Orm::Exercise.exists?(essential:)
  exercise = Orm::Exercise.create!(essential:, title: "Reconnaître la membrane", position: 1, author: member, **published)
  [ [ "La membrane plasmique délimite la cellule.", [ [ "Vrai", true ], [ "Faux", false ] ], "true_false" ],
    [ "Quel est son rôle principal ?", [ [ "Contrôler les échanges", true ], [ "Produire l'énergie", false ],
                                         [ "Stocker l'ADN", false ], [ "Digérer les déchets", false ] ], "single_choice" ] ]
    .each.with_index(1) do |(content, answers, question_type), position|
      # Un énoncé est du texte brut (UDR-0017) ; seuls le cours et la fiche sont du texte riche.
      question = exercise.questions.create!(position:, content:, question_type:)
      answers.each.with_index(1) { |(text, correct), rank| question.answers.create!(position: rank, content: text, correct:) }
    end
end
