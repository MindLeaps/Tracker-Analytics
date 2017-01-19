require_dependency "mindleaps_analytics/application_controller"

module MindleapsAnalytics
  class MainController < ApplicationController
    def first
      now = Date.today
      # Student.group(:group_id)
      students = Student.all
      @x = Group.all

      # let's create a hash with key group_id and data an empty array which will contain the points (x,y)
      # we do this so we can create a data series per group in the scatter chart
      @groups = {}
      group_ids = students.group(:group_id).count.keys
      group_ids.each do |group_id|
        @groups[group_id.to_s.to_sym] = []
      end

      # now calculate the performance for each student
      students.each do |student|

        id = student.id
        nr_of_lessons = Grade.where(student_id: id).distinct.count(:lesson_id)
        dob = student.dob
        age = now.year - dob.year - ((now.month > dob.month || (now.month == dob.month && now.day >= dob.day)) ? 0 : 1)

        point = []

        # Patrick's formula
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

        # add this point to the correct (meaning: for this student's Group) data series
        @groups[student.group_id.to_s.to_sym] << point

      end

      # now get the groupname for each group, and store groupname and data together in an array
      @series = []
      @groups.each do |key, data|
        group = Group.find(key.to_s.to_i)
        @series << {name: group.group_name, data: data}
      end

    end

    def second
    end

    def third
    end
  end
end
