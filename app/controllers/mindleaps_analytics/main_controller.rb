require_dependency "mindleaps_analytics/application_controller"

module MindleapsAnalytics
  class MainController < ApplicationController
    def first

      # Patrick's formula
      @series = []
      regression(@series)

      # figure 2: # Assessments per month
      @x_axis2 = []
      @y_axis2 = []
      count_assessments(@x_axis2, @y_axis2)

      # figure 4: Histogram of student performance values
      # count average performance per student
      @x_axis4 = []
      @y_axis4 = []
      count_student_avg_performance(@x_axis4, @y_axis4)

      # figure 5: Histogram of student performance change
      @x_axis5 = []
      @y_axis5 = []
      count_student_avg_performance_change(@x_axis5, @y_axis5)

    end

    def count_student_avg_performance_change(x_axis, y_axis)
      students = Student.all

      marks_raw = Hash.new(0)
      @debug = []
      students.each do |student|
        minDate = Grade.where(student_id: student.id).joins(:lesson).minimum(:date)
        maxDate = Grade.where(student_id: student.id).joins(:lesson).maximum(:date)
        @debug << [minDate, maxDate]
        # minGrades = Grade.includes(:lesson).where(grades: {student_id: student.id}, lessons: {date: minDate})
        # minGrades.count
        minAverage = Grade.includes(:lesson).where(grades: {student_id: student.id}, lessons: {date: minDate}).joins(:grade_descriptor).average(:mark)
        maxAverage = Grade.includes(:lesson).where(grades: {student_id: student.id}, lessons: {date: maxDate}).joins(:grade_descriptor).average(:mark)


        minAverage = 0 if minAverage.nil?
        maxAverage = 0 if maxAverage.nil?

        difference = (((maxAverage - minAverage) * 2) + 0.5).floor
        marks_raw[difference.object_id] += 1
      end

      marks_sorted = marks_raw.sort

      marks_sorted.each do |key, values|
        x_axis << (ObjectSpace._id2ref(key)).to_f / 2
        y_axis << (values * 100) / students.count
      end
    end

    def count_student_avg_performance(x_axis, y_axis)

      students = Student.all

      marks_raw = Hash.new(0)
      students.each do |student|
        avg = Grade.where(student_id: student.id).joins(:grade_descriptor).average(:mark)

        if avg.nil?
          avg = 0
        else
          avg = avg.round
        end
        marks_raw[avg.to_s.to_sym] += 1
      end

      marks_sorted = marks_raw.sort

      marks_sorted.each do |key, values|
        x_axis << key.to_s
        y_axis << (values * 100) / students.count
      end
    end

    def count_assessments(x_axis, y_axis)
      @dates = Lesson.group(:date).count.keys
      months_raw = {}
      @dates.each do |date|
        month = date.year.to_s + date.month.to_s
        months_raw[month.to_sym] = [date.year, date.month]
      end

      months_sorted = months_raw.sort

      months_sorted.each do |key, values|
        from = Date.new(values[0], values[1], 1)
        to = Date.new(values[0], values[1], 1).at_end_of_month
        lessons = Lesson.where("date >= :date_from AND date <= :date_to", {date_from: from, date_to: to})
        nr_of_assessments = 0
        lessons.each do |lesson|
          nr_of_assessments += Grade.where(lesson_id: lesson.id).distinct.count(:student_id)
        end
        x_axis << key.to_s
        y_axis << nr_of_assessments
      end
    end

    def regression(series)
      now = Date.today
      students = Student.all

      # let's create a hash with key group_id and data an empty array which will contain the points (x,y)
      # we do this so we can create a data series per group in the scatter chart
      groups = Hash.new

      # now calculate the performance for each student
      students.each do |student|

        id = student.id
        # The number of lessons the student has attended
        # nr_of_lessons = student.grades.distinct.count(:lesson_id)
        nr_of_lessons = Grade.where(student_id: id).distinct.count(:lesson_id)
        dob = student.dob
        age = now.year - dob.year - ((now.month > dob.month || (now.month == dob.month && now.day >= dob.day)) ? 0 : 1)

        # Non-linear multivariate regression formula
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

        point = []
        point << nr_of_lessons
        point << performance

        # add this point to the correct (meaning: for this student's Group) data series
        if groups[student.group_id.to_s.to_sym] == nil
          groups[student.group_id.to_s.to_sym] = []
        end
        groups[student.group_id.to_s.to_sym] << point

      end

      # now get the group name for each group, and store group name and data together in an array
      groups.each do |key, data|
        group = Group.find(key.to_s.to_i)
        series << {name: group.group_name, data: data}
      end
    end

    def second
    end

    def third
    end
  end
end
