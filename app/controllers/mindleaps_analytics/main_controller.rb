require_dependency "mindleaps_analytics/application_controller"

module MindleapsAnalytics
  class MainController < ApplicationController
    def first

      # Patrick's formula
      @series = []
      regression(@series)

      # figure 2: # Assessments per month
      # This chart has a categorical x-axis: the months
      @x_axis2 = []
      @y_axis2 = []
      count_assessments(@x_axis2, @y_axis2)

      # figure 4: Histogram of student performance values
      # count average performance per student
      @series4 = []
      count_student_avg_performance(@series4)

      # figure 5: Histogram of student performance change
      @series5 = []
      count_student_avg_performance_change(@series5)

      # figure 6: Histogram of student performance change by boys and girls
      @series6 = []
      count_student_avg_performance_change_by_gender(@series6)

      # figure 8: Average performance per group by days in program
      @series8 = []
      avg_performance_per_student_by_days_in_program(@series8)

    end

    def avg_performance_per_student_by_days_in_program(series)

      # The top query
      students = Student.all

      students.each do |student|

      end

    end

    def count_student_avg_performance_change_by_gender(series)

      # The top query
      students = Student.all

      # Hash to contain the genders series, so one entry per gender
      seriesDoubleHash = Hash.new
      # Hash to contain the total number of entries per gender
      seriesTotalsHash = Hash.new(0)

      # Calculate the performance difference per student
      students.each do |student|
        minDate = Grade.where(student_id: student.id).joins(:lesson).minimum(:date)
        maxDate = Grade.where(student_id: student.id).joins(:lesson).maximum(:date)
        minAverage = Grade.includes(:lesson).where(grades: {student_id: student.id}, lessons: {date: minDate}).joins(:grade_descriptor).average(:mark)
        maxAverage = Grade.includes(:lesson).where(grades: {student_id: student.id}, lessons: {date: maxDate}).joins(:grade_descriptor).average(:mark)


        minAverage = 0 if minAverage.nil?
        maxAverage = 0 if maxAverage.nil?

        # Bin the x-axis on 0.5's
        difference = (((maxAverage - minAverage) * 2) + 0.5).floor.to_f / 2

        # add this point to the correct (meaning: for this student's Gender) data series
        # so we're creating a new hash per gender, and add that to the seriesDoubleHash
        # all in all the data structure looks like this: seriesDoubleHash[:Gender] => Hash[:x-axis bin] => Count
        if seriesDoubleHash[student.gender] == nil
          seriesDoubleHash[student.gender] = Hash.new(0)
        end
        seriesDoubleHash[student.gender][difference.object_id] += 1
        # Calculate the totals so we can calculate the distribution per series
        seriesTotalsHash[student.gender] += 1
      end

      # Calculation is done, now convert the seriesDoubleHash to something HighCharts understands
      # Loop over the Genders: max 2
      seriesDoubleHash.each do |key, hash|
        # Array to contain the x and y values
        # x-axis = difference bin, y value = frequency
        data = []
        # Loop over the Difference bins: Expected 10 - 20 entries
        # Map the hash keys back to x-axis bins and transform the y-axis counts to frequencies
        hash.each do |difference, count|
          data << [ObjectSpace._id2ref(difference), (count * 100) / seriesTotalsHash[key]]
        end
        series << {name: key, data: data}
      end

    end

    def count_student_avg_performance_change(series)

      # The top query
      students = Student.all

      # Hash to contain the difference bins with their counts
      seriesHash = Hash.new(0)

      # Calculate the performance difference per student
      students.each do |student|
        minDate = Grade.where(student_id: student.id).joins(:lesson).minimum(:date)
        maxDate = Grade.where(student_id: student.id).joins(:lesson).maximum(:date)
        minAverage = Grade.includes(:lesson).where(grades: {student_id: student.id}, lessons: {date: minDate}).joins(:grade_descriptor).average(:mark)
        maxAverage = Grade.includes(:lesson).where(grades: {student_id: student.id}, lessons: {date: maxDate}).joins(:grade_descriptor).average(:mark)


        minAverage = 0 if minAverage.nil?
        maxAverage = 0 if maxAverage.nil?

        # Bin the x-axis on 0.5's
        difference = (((maxAverage - minAverage) * 2) + 0.5).floor.to_f / 2
        seriesHash[difference.object_id] += 1
      end

      # Array to contain the x and y values
      # x-axis = difference bin, y value = frequency
      data = []

      # Loop over the Difference bins: Expected 10 - 20 entries
      # Map the hash keys back to x-axis bins and transform the y-axis counts to frequencies
      seriesHash.each do |difference, count|
        data << [ObjectSpace._id2ref(difference), (count * 100) / students.count]
      end
      series << {name: 'Frequency %', data: data}

    end

    def count_student_avg_performance(series)

      # The top query
      students = Student.all

      # Hash to contain the average performance bins with their counts
      seriesHash = Hash.new(0)
      students.each do |student|
        avg = Grade.where(student_id: student.id).joins(:grade_descriptor).average(:mark)

        if avg.nil?
          avg = 0
        else
          avg = avg.round
        end
        seriesHash[avg.object_id] += 1
      end

      # Array to contain the x and y values
      # x-axis = difference bin, y value = frequency
      data = []

      # Loop over the average performance bins
      # Map the hash keys back to x-axis bins and transform the y-axis counts to frequencies
      seriesHash.each do |difference, count|
        data << [ObjectSpace._id2ref(difference), (count * 100) / students.count]
      end
      series << {name: 'Frequency %', data: data}

    end

    def count_assessments(x_axis, y_axis)
      @dates = Lesson.group(:date).count.keys

      months_raw = {}

      # Create a sortable key here, so we can sort the hash later
      @dates.each do |date|
        month = date.year.to_s + date.month.to_s
        months_raw[month.to_sym] = [date.year, date.month]
      end

      # Sort and turn into an array
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
        if groups[student.group_id.object_id] == nil
          groups[student.group_id.object_id] = []
        end
        groups[student.group_id.object_id] << point

      end

      # now get the group name for each group, and store group name and data together in an array
      groups.each do |key, data|
        group = Group.find(ObjectSpace._id2ref(key))
        series << {name: t(:group) + ' ' + group.group_name, data: data}
      end
    end

    def second
    end

    def third
    end
  end
end
