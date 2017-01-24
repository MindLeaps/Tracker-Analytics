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
      get_series_chart2(@x_axis2, @y_axis2)

      # figure 4: Histogram of student performance values
      # count average performance per student
      @series4 = []
      get_series_chart4(@series4)

      # figure 5: Histogram of student performance change
      @series5 = []
      get_series_chart5(@series5)

      # figure 6: Histogram of student performance change by boys and girls
      @series6 = []
      get_series_chart6(@series6)

      # figure 8: Average performance per group by days in program
      @series8 = []
      get_series_chart8(@series8)

      @series9 = []
      get_series_chart9(@series9)

    end

    def get_series_chart9(series)

      # The top query
      lessons = Lesson.all

      performance_hash = {}
      performance_hash[:above] = []
      performance_hash[:below] = []

      lessons.each do |lesson|
        # Find the students who attended this lesson
        students = Student.includes(:grades).where(grades: {lesson_id: lesson.id})

        students.each do |student|
          avg = Grade.where(lesson_id: lesson.id, student_id: student.id).joins(:grade_descriptor).average(:mark)
          # The number of lessons where this student participated in
          nr_of_lessons = Lesson.includes(:grades).where("date < :date_to", {date_to: lesson.date}, grade: {student_id: student.id}).count

          dob = student.dob
          now = lesson.date
          age = now.year - dob.year - ((now.month > dob.month || (now.month == dob.month && now.day >= dob.day)) ? 0 : 1)

          # Non-linear multivariate regression formula
          performance = 3.31
          performance += 1.72*(10**-2) * nr_of_lessons
          performance += -8.14*(10**-5) * nr_of_lessons**2
          performance += 1.63*(10**-7) * nr_of_lessons**3
          performance += -1.12*(10**-10) * nr_of_lessons**4
          performance += 0.039 * age

          point = {}
          point[:name] = student.last_name + ", " + student.first_name
          point[:x] = nr_of_lessons
          point[:y] = avg.to_f

          if (avg >= performance)
            performance_hash[:above] << point
          else
            performance_hash[:below] << point
          end
        end

      end

      performance_hash.each do |group, array|
        if (group == :above)
          series << {name: t(:above_regression), data: array}
        else
          series << {name: t(:below_regression), data: array}
        end
      end

    end

    def get_series_chart8(series)

      # The top query
      lessons = Lesson.all

      # Hash to contain the groups series, so one entry per group
      series_hash = Hash.new

      # Calculate the average performance for this lesson and group
      lessons.each do |lesson|
        # Count the number of previous lessons for this group
        nr_of_lessons = Lesson.where("group_id = :group_id AND date < :date_to",
                                     {group_id: lesson.group_id, date_to: lesson.date}).distinct.count(:id)
        # Determine the average group performance for this lesson
        # avg = Grade.includes(:lesson).where(lessons: {id: lesson.id}).joins(:grade_descriptor).average(:mark)
        avg = Grade.where(lesson_id: lesson.id).joins(:grade_descriptor).average(:mark)

        point = []
        point << nr_of_lessons
        point << avg.to_f

        # add this point to the correct (meaning: this Group's) data series
        if series_hash[lesson.group.group_name] == nil
          series_hash[lesson.group.group_name] = []
        end
        series_hash[lesson.group.group_name] << point
      end

      # Calculation is done, now convert the series_hash to something HighCharts understands
      series_hash.each do |group, array|
        series << {name: t(:group) + ' ' + group, data: array}
      end

    end

    def get_series_chart6(series)

      # The top query
      students = Student.all

      # Hash to contain the genders series, so one entry per gender
      series_double_hash = Hash.new
      # Hash to contain the total number of entries per gender
      series_totals_hash = Hash.new(0)

      # Calculate the performance difference per student
      students.each do |student|
        min_date = Grade.where(student_id: student.id).joins(:lesson).minimum(:date)
        max_date = Grade.where(student_id: student.id).joins(:lesson).maximum(:date)
        min_avg = Grade.includes(:lesson).where(grades: {student_id: student.id}, lessons: {date: min_date}).joins(:grade_descriptor).average(:mark)
        max_avg = Grade.includes(:lesson).where(grades: {student_id: student.id}, lessons: {date: max_date}).joins(:grade_descriptor).average(:mark)

        min_avg = 0 if min_avg.nil?
        max_avg = 0 if max_avg.nil?

        # Bin the x-axis on 0.5's
        difference = (((max_avg - min_avg) * 2) + 0.5).floor.to_f / 2

        # add this point to the correct (meaning: for this student's Gender) data series
        # so we're creating a new hash per gender, and add that to the seriesDoubleHash
        # all in all the data structure looks like this: seriesDoubleHash[:Gender] => Hash[:x-axis bin] => Count
        if series_double_hash[student.gender] == nil
          series_double_hash[student.gender] = Hash.new(0)
        end
        series_double_hash[student.gender][difference.object_id] += 1
        # Calculate the totals so we can calculate the distribution per series
        series_totals_hash[student.gender] += 1
      end

      # Calculation is done, now convert the seriesDoubleHash to something HighCharts understands
      # Loop over the Genders: max 2
      series_double_hash.each do |key, hash|
        # Array to contain the x and y values
        # x-axis = difference bin, y value = frequency
        data = []
        # Loop over the Difference bins: Expected 10 - 20 entries
        # Map the hash keys back to x-axis bins and transform the y-axis counts to frequencies
        hash.each do |difference, count|
          data << [ObjectSpace._id2ref(difference), (count * 100) / series_totals_hash[key]]
        end
        series << {name: t(:gender) + ' ' + key, data: data}
      end

    end

    def get_series_chart5(series)

      # The top query
      students = Student.all

      # Hash to contain the difference bins with their counts
      series_hash = Hash.new(0)

      # Calculate the performance difference per student
      students.each do |student|
        min_date = Grade.where(student_id: student.id).joins(:lesson).minimum(:date)
        max_date = Grade.where(student_id: student.id).joins(:lesson).maximum(:date)
        min_avg = Grade.includes(:lesson).where(grades: {student_id: student.id}, lessons: {date: min_date}).joins(:grade_descriptor).average(:mark)
        max_avg = Grade.includes(:lesson).where(grades: {student_id: student.id}, lessons: {date: max_date}).joins(:grade_descriptor).average(:mark)


        min_avg = 0 if min_avg.nil?
        max_avg = 0 if max_avg.nil?

        # Bin the x-axis on 0.5's
        difference = (((max_avg - min_avg) * 2) + 0.5).floor.to_f / 2
        series_hash[difference.object_id] += 1
      end

      # Array to contain the x and y values
      # x-axis = difference bin, y value = frequency
      data = []

      # Loop over the Difference bins: Expected 10 - 20 entries
      # Map the hash keys back to x-axis bins and transform the y-axis counts to frequencies
      series_hash.each do |difference, count|
        data << [ObjectSpace._id2ref(difference), (count * 100) / students.count]
      end
      series << {name: t(:frequency_perc), data: data}

    end

    def get_series_chart4(series)

      # The top query
      students = Student.all

      # Hash to contain the average performance bins with their counts
      series_hash = Hash.new(0)
      students.each do |student|
        avg = Grade.where(student_id: student.id).joins(:grade_descriptor).average(:mark)

        if avg.nil?
          avg = 0
        else
          avg = avg.round
        end
        series_hash[avg.object_id] += 1
      end

      # Array to contain the x and y values
      # x-axis = difference bin, y value = frequency
      data = []

      # Loop over the average performance bins
      # Map the hash keys back to x-axis bins and transform the y-axis counts to frequencies
      series_hash.each do |difference, count|
        data << [ObjectSpace._id2ref(difference), (count * 100) / students.count]
      end
      series << {name: t(:frequency_perc), data: data}

    end

    def get_series_chart2(x_axis, y_axis)
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
