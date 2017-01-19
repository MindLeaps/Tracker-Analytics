require_dependency "mindleaps_analytics/application_controller"

module MindleapsAnalytics
  class MainController < ApplicationController
    def first
      now = Date.today
      students = Student.all

      @seriesA = []
      # @seriesB = []

      students.each do |student|

        id = student.id
        # nr_of_lessons = Lesson.where(student_id: id).count  // Lesson doesn't have the student, you need to go to Grade
        # nr_of_grades = Grade.where(student_id: id).distinct.count(:lesson_id)
        nr_of_lessons = Grade.where(student_id: id).distinct.count(:lesson_id)
        dob = student.dob
        age = now.year - dob.year - ((now.month > dob.month || (now.month == dob.month && now.day >= dob.day)) ? 0 : 1)
        # time = ((Date.today - student.created_at.to_date).to_i)

        point = []

        performance = 3.31
        performance += 1.72*(10**-2) * nr_of_lessons
        performance += -8.14*(10**-5) * nr_of_lessons**2
        performance += 1.63*(10**-7) * nr_of_lessons**3
        performance += -1.12*(10**-10) * nr_of_lessons**4
        performance += 0.039 * age
        # performance += 0.508 if student.group_a
        # performance += 0.325 if student.group_b
        # performance += 0.619 if student.group_c
        # performance += 0.585 if student.group_d
        # performance += 0.233 if student.group_e
        # performance += -0.589 if student.data_collector_2
        # performance += -0.762 if student.data_collector_3
        # performance += -0.169 if student.data_collector_6
        # performance += -0.06 if student.class_type_2

        point << nr_of_lessons
        point << performance
        @seriesA << point
        # @seriesB << point if student.group_b

      end

    end

    def second
    end

    def third
    end
  end
end
