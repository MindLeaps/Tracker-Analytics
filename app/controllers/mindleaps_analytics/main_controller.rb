require_dependency "mindleaps_analytics/application_controller"

module MindleapsAnalytics
  class MainController < ApplicationController

    def first

      @organization = params[:organization_select]
      @chapter = params[:chapter_select]
      @group = params[:group_select]
      @student = params[:student_select]

      # figure 2: # Assessments per month
      # This chart has a categorical x-axis: the months
      categories2 = []
      series2 = []
      get_series_chart2(categories2, series2)
      @categories2 = categories2.to_json
      @series2 = series2.to_json

      # figure 4: Histogram of student performance values
      # count average performance per student
      series4 = []
      get_series_chart4(series4)
      @series4 = series4.to_json

      # figure 5: Histogram of student performance change
      series5 = []
      get_series_chart5(series5)
      @series5 = series5.to_json

      # figure 6: Histogram of student performance change by boys and girls
      series6 = []
      get_series_chart6(series6)
      @series6 = series6.to_json

      # figure 8: Average performance per group by days in program
      # Rebecca requested a Trellis per Group
      series8 = []
      get_series_chart8(series8)
      @series8 = series8.to_json

      # Figure 9: Performance data for each student versus time in program
      # Different series for above/below regression formula (Patrick's formula)
      series9 = []
      get_series_chart9(series9)
      @series9 = series9.to_json

    end

    def second

      @organization = params[:organization_select]
      @chapter = params[:chapter_select]
      @group = params[:group_select]
      @subject = params[:subject_select]
      @student = params[:student_select]

      unless params[:organization_select]
        @organization = Organization.first.id
      end
      unless params[:subject_select]
        @subject = Subject.first.id
      end

      # figure 3: Histograms (Trellis) for the seven skills that are evaluated
      # multiple series (1 per group) per histogram;
      # x-axis: nr. of lessons
      # y-axis: average score
      # series = [{skill : skill_name, series : [{name : group_name, data : [[x, y], ..]}]}]
      series3 = []
      get_series_chart3(series3)
      @count = series3.count
      @series3 = series3.to_json

    end

    def third

      @organization = params[:organization_select]
      @chapter = params[:chapter_select]
      @group = params[:group_select]
      @subject = params[:subject_select]
      @student = params[:student_select]

      unless params[:organization_select]
        @organization = Organization.first.id
      end
      unless params[:subject_select]
        @subject = Subject.first.id
      end

      # figure 8: Average performance per group by days in program
      # Rebecca requested a Trellis per Group
      series8 = []
      get_series_chart8(series8)
      @count = series8.count
      @series8 = series8.to_json

    end

    def get_series_chart9(series)

      # top query
      if not @student.nil? and not @student == '' and not @student == 'All'
        lessons = Lesson.includes(:grades).where(grades: {student_id: @student})
      elsif not @group.nil? and not @group == '' and not @group == 'All'
        lessons = Lesson.where(group_id: @group)
      elsif not @chapter.nil? and not @chapter == '' and not @chapter == 'All'
        lessons = Lesson.includes(:group).where(groups: {chapter_id: @chapter})
      elsif not @organization.nil? and not @organization == '' and not @organization == 'All'
        lessons = Lesson.includes(group: :chapter).where(chapters: {organization_id: @organization})
      else
        lessons = Lesson.all
      end

      performance_hash = {}
      performance_hash[:above] = []
      performance_hash[:below] = []

      lessons.each do |lesson|
        # Find the students who attended this lesson
        if not @student.nil? and not @student == '' and not @student == 'All'
          students = Student.includes(:grades).where(grades: {lesson_id: lesson.id}, id: @student)
        else
          students = Student.includes(:grades).where(grades: {lesson_id: lesson.id})
        end

        students.each do |student|
          avg = Grade.where(lesson_id: lesson.id, student_id: student.id).joins(:grade_descriptor).average(:mark)
          # The number of lessons where this student participated in
          nr_of_lessons = Lesson.includes(:grades).where('date < :date_to', {date_to: lesson.date}, grade: {student_id: student.id}).count

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
          point[:name] = student.last_name + ', ' + student.first_name
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

      # top query
      if not @student.nil? and not @student == '' and not @student == 'All'
        lessons = Lesson.includes(:grades).where(grades: {student_id: @student})
      elsif not @group.nil? and not @group == '' and not @group == 'All'
        lessons = Lesson.where(group_id: @group)
      elsif not @chapter.nil? and not @chapter == '' and not @chapter == 'All'
        lessons = Lesson.includes(:group).where(groups: {chapter_id: @chapter})
      elsif not @organization.nil? and not @organization == '' and not @organization == 'All'
        lessons = Lesson.includes(group: :chapter).where(chapters: {organization_id: @organization})
      else
        lessons = Lesson.all
      end

      # Hash to contain the groups series, so one entry per group
      series_hash = Hash.new

      # Calculate the average performance for this lesson and group
      lessons.each do |lesson|
        # Count the number of previous lessons for this group
        nr_of_lessons = Lesson.where('group_id = :group_id AND date < :date_to',
                                     {group_id: lesson.group_id, date_to: lesson.date}).distinct.count(:id)
        # Determine the average group performance for this lesson
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

      # top query
      if not @student.nil? and not @student == '' and not @student == 'All'
        students = Student.where(id: @student)
      elsif not @group.nil? and not @group == '' and not @group == 'All'
        students = Student.where(group_id: @group)
      elsif not @chapter.nil? and not @chapter == '' and not @chapter == 'All'
        students = Student.includes(:group).where(groups: {chapter_id: @chapter})
      elsif not @organization.nil? and not @organization == '' and not @organization == 'All'
        students = Student.includes(group: :chapter).where(chapters: {organization_id: @organization})
      else
        students = Student.all
      end

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
          data << [ObjectSpace._id2ref(difference), (count * 100).to_f / series_totals_hash[key]]
        end
        series << {name: t(:gender) + ' ' + key, data: data}
      end

    end

    def get_series_chart5(series)

      # top query
      if not @student.nil? and not @student == '' and not @student == 'All'
        students = Student.where(id: @student)
      elsif not @group.nil? and not @group == '' and not @group == 'All'
        students = Student.where(group_id: @group)
      elsif not @chapter.nil? and not @chapter == '' and not @chapter == 'All'
        students = Student.includes(:group).where(groups: {chapter_id: @chapter})
      elsif not @organization.nil? and not @organization == '' and not @organization == 'All'
        students = Student.includes(group: :chapter).where(chapters: {organization_id: @organization})
      else
        students = Student.all
      end

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
        data << [ObjectSpace._id2ref(difference), (count * 100).to_f / students.count]
      end
      series << {name: t(:frequency_perc), data: data}

    end

    def get_series_chart3(series)

      skills = Skill.includes(:assignments).where(organization_id: @organization, assignments: {subject_id: @subject})

      series_double_hash = Hash.new

      # top query
      if not @student.nil? and not @student == '' and not @student == 'All'
        lessons = Lesson.includes(:grades).where(grades: {student_id: @student})
      elsif not @group.nil? and not @group == '' and not @group == 'All'
        lessons = Lesson.where(group_id: @group)
      elsif not @chapter.nil? and not @chapter == '' and not @chapter == 'All'
        lessons = Lesson.includes(:group).where(groups: {chapter_id: @chapter})
      elsif not @organization.nil? and not @organization == '' and not @organization == 'All'
        lessons = Lesson.includes(group: :chapter).where(chapters: {organization_id: @organization})
      else
        lessons = Lesson.all
      end

      # Hash to contain the groups series, so one entry per group
      # series_hash = Hash.new

      # Calculate the average performance for this lesson and group
      lessons.each do |lesson|
        if not @student.nil? and not @student == '' and not @student == 'All'
          nr_of_lessons = Lesson.includes(:grades).where('date < :date_to', {date_to: lesson.date}).where(grades: {student_id: @student}).distinct.count(:id)
        else
          # Count the number of previous lessons for this group
          nr_of_lessons = Lesson.where('group_id = :group_id AND date < :date_to',
                                       {group_id: lesson.group_id, date_to: lesson.date}).distinct.count(:id)
        end

        skills.each do |skill|
          if not @student.nil? and not @student == '' and not @student == 'All'
            avg = Grade.includes(:grade_descriptor).where(lesson_id: lesson.id, student_id: @student, grade_descriptors: {skill_id: skill.id}).joins(:grade_descriptor).average(:mark)
          else
            # Determine the average group performance for this lesson
            avg = Grade.includes(:grade_descriptor).where(lesson_id: lesson.id, grade_descriptors: {skill_id: skill.id}).joins(:grade_descriptor).average(:mark)
          end

          point = []
          point << nr_of_lessons
          point << avg.to_f

          if series_double_hash[skill.skill_name] == nil
            series_double_hash[skill.skill_name] = Hash.new
          end

          # add this point to the correct (meaning: this Group's) data series
          if series_double_hash[skill.skill_name][lesson.group.group_name] == nil
            series_double_hash[skill.skill_name][lesson.group.group_name] = []
          end
          # series_hash[lesson.group.group_name] << point
          series_double_hash[skill.skill_name][lesson.group.group_name] << point
        end
      end

      # Calculation is done, now convert the series_hash to something HighCharts understands
      # series_double_hash.each do |skill, hash|
      #   series[skill] = []
      #   hash.each do |group, array|
      #     series[skill] << {name: t(:group) + ' ' + group, data: array}
      #   end
      # end
      series_double_hash.each do |skill, hash|
        skill_series = []
        hash.each do |group, array|
          skill_series << {name: t(:group) + ' ' + group, data: array}
        end
        series << {skill: skill, series: skill_series}
      end

    end

    def get_series_chart4(series)

      # top query
      if not @student.nil? and not @student == '' and not @student == 'All'
        students = Student.where(id: @student)
      elsif not @group.nil? and not @group == '' and not @group == 'All'
        students = Student.where(group_id: @group)
      elsif not @chapter.nil? and not @chapter == '' and not @chapter == 'All'
        students = Student.includes(:group).where(groups: {chapter_id: @chapter})
      elsif not @organization.nil? and not @organization == '' and not @organization == 'All'
        students = Student.includes(group: :chapter).where(chapters: {organization_id: @organization})
      else
        students = Student.all
      end

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
        data << [ObjectSpace._id2ref(difference), (count * 100).to_f / students.count]
      end
      series << {name: t(:frequency_perc), data: data}

    end

    def get_series_chart2(categories, series)

      # top query
      if not @student.nil? and not @student == '' and not @student == 'All'
        #dates = Grade.joins(:lesson).where(student_id: @student).group(:date).count.keys
        dates = Lesson.includes(:grades).where(grades: {student_id: @student}).group(:date).count.keys
      elsif not @group.nil? and not @group == '' and not @group == 'All'
        dates = Lesson.where(group_id: @group).group(:date).count.keys
      elsif not @chapter.nil? and not @chapter == '' and not @chapter == 'All'
        dates = Lesson.includes(:group).where(groups: {chapter_id: @chapter}).group(:date).count.keys
      elsif not @organization.nil? and not @organization == '' and not @organization == 'All'
        dates = Lesson.includes(group: :chapter).where(chapters: {organization_id: @organization}).group(:date).count.keys
      else
        dates = Lesson.group(:date).count.keys
      end

      months_raw = {}

      # Create a sortable key here, so we can sort the hash later
      dates.each do |date|
        month = date.year.to_s + date.month.to_s
        months_raw[month.to_sym] = [date.year, date.month]
      end

      # Sort and turn into an array
      months_sorted = months_raw.sort

      data = []
      months_sorted.each do |key, values|
        from = Date.new(values[0], values[1], 1)
        to = Date.new(values[0], values[1], 1).at_end_of_month
        lessons = Lesson.where('date >= :date_from AND date <= :date_to', {date_from: from, date_to: to})
        nr_of_assessments = 0
        lessons.each do |lesson|
          if not @student.nil? and not @student == '' and not @student == 'All'
            nr_of_assessments += Grade.where(lesson_id: lesson.id, student: @student).distinct.count(:student_id)
          else
            nr_of_assessments += Grade.where(lesson_id: lesson.id).distinct.count(:student_id)
          end
        end
        categories << key.to_s
        data << nr_of_assessments
      end
      series << {name: t(:nr_of_assessments), data: data}
    end

  end

end

