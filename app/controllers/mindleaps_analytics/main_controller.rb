require_dependency "mindleaps_analytics/application_controller"

module MindleapsAnalytics
  class MainController < ApplicationController
    skip_after_action :verify_authorized

    before_action do
      @selected_organization_id = params[:organization_select]
      @selected_chapter_id = params[:chapter_select]
      @selected_group_id = params[:group_select]
      @selected_student_id = params[:student_select]

      @selected_organizations = find_resource_by_id_param @selected_organization_id, Organization
      @selected_chapters = find_resource_by_id_param(@selected_chapter_id, Chapter) { |c| c.where(organization: @selected_organizations) }
      @selected_groups = find_resource_by_id_param(@selected_group_id, Group) { |g| g.where(chapter: @selected_chapters) }
      @selected_students = find_resource_by_id_param(@selected_student_id, Student) { |s| s.where(group: @selected_groups) }
    end

    def first
      @organizations = policy_scope Organization
      if not @selected_organization_id.nil? and not @selected_organization_id == '' and not @selected_organization_id == 'All'
        @chapters = Chapter.where(organization_id: @selected_organization_id)
      else
        @chapters = policy_scope Chapter
      end

      if not @selected_chapter_id.nil? and not @selected_chapter_id == '' and not @selected_chapter_id == 'All'
        @groups = Group.where(chapter_id: @selected_chapter_id)
      elsif not @selected_organization_id.nil? and not @selected_organization_id == '' and not @selected_organization_id == 'All'
        @groups = Group.includes(:chapter).where(chapters: {organization_id: @selected_organization_id})
      else
        @groups = policy_scope Group
      end

      if not @selected_group_id.nil? and not @selected_group_id == '' and not @selected_group_id == 'All'
        @students = Student.where(group_id: @selected_group_id).order(:last_name, :first_name).all
      elsif not @selected_chapter_id.nil? and not @selected_chapter_id == '' and not @selected_chapter_id == 'All'
        @students = Student.includes(:group).where(groups: {chapter_id: @selected_chapter_id}).order(:last_name, :first_name).all
      elsif not @selected_organization_id.nil? and not @selected_organization_id == '' and not @selected_organization_id == 'All'
        @students = Student.includes(group: :chapter).where(chapters: {organization_id: @selected_organization_id}).order(:last_name, :first_name).all
      else
        @students = policy_scope Student.order(:last_name, :first_name)
      end

      res2 = assesments_per_month
      @categories2 = res2[:categories].to_json
      @series2 = res2[:series].to_json


      @series4 = histogram_of_student_performance.to_json

      @series5 = histogram_of_student_performance_change.to_json

      @series6 = histogram_of_student_performance_change_by_gender.to_json

      @series10 = average_performance_per_group_by_lesson.to_json

      @series9 = performance_data_for_each_student_versus_time_in_program.to_json
    end

    def second

      @subject = params[:subject_select]

      @organizations = policy_scope Organization
      if not @selected_organization_id.nil? and not @selected_organization_id == '' and not @selected_organization_id == 'All'
        @chapters = Chapter.where(organization_id: @selected_organization_id)
      else
        @chapters = policy_scope Chapter
      end

      if not @selected_group_id.nil? and not @selected_group_id == '' and not @selected_group_id == 'All'
        @groups = Group.where(chapter_id: @selected_chapter_id)
      elsif not @selected_organization_id.nil? and not @selected_organization_id == '' and not @selected_organization_id == 'All'
        @groups = Group.includes(:chapter).where(chapters: {organization_id: @selected_organization_id})
      else
        @groups = policy_scope Group
      end

      if not @selected_group_id.nil? and not @selected_group_id == '' and not @selected_group_id == 'All'
        @students = Student.where(group_id: @selected_group_id).order(:last_name, :first_name).all
      elsif not @selected_chapter_id.nil? and not @selected_chapter_id == '' and not @selected_chapter_id == 'All'
        @students = Student.includes(:group).where(groups: {chapter_id: @selected_chapter_id}).order(:last_name, :first_name).all
      elsif not @selected_organization_id.nil? and not @selected_organization_id == '' and not @selected_organization_id == 'All'
        @students = Student.includes(group: :chapter).where(chapters: {organization_id: @selected_organization_id}).order(:last_name, :first_name).all
      else
        @students = Student.order(:last_name, :first_name).all
      end

      if not @selected_organization_id.nil? and not @selected_organization_id == '' and not @selected_organization_id == 'All'
        @subjects = Subject.where(organization: @selected_organization_id)
      else
        @subjects = policy_scope Subject
      end

      unless params[:organization_select]
        @selected_organization_id = @organizations.first.id
      end
      unless params[:subject_select]
        @subject = @subjects.first.id
      end

      # figure 3: Histograms (Trellis) for the seven skills that are evaluated
      # multiple series (1 per group) per histogram;
      # x-axis: nr. of lessons
      # y-axis: average score
      # series = [{skill : skill_name, series : [{name : group_name, data : [[x, y], ..]}]}]
      series3 = performance_per_skill
      @count = series3.count
      @series3 = series3.to_json

    end

    def third
      @subject = params[:subject_select]

      @organizations = policy_scope Organization
      if not @selected_organization_id.nil? and not @selected_organization_id == '' and not @selected_organization_id == 'All'
        @chapters = Chapter.where(organization_id: @selected_organization_id)
      else
        @chapters = Chapter.where(organization: @organizations)
      end

      unless params[:organization_select]
        @selected_organization_id = @organizations.first.id
      end

      # figure 8: Average performance per group by days in program
      # Rebecca requested a Trellis per Group
      series8 = []
      get_series_chart8(series8)
      @count = series8.count
      @series8 = series8.to_json

    end


    def average_performance_per_group_by_lesson
      groups = Array(get_groups_for_average_performance)

      conn = ActiveRecord::Base.connection.raw_connection
      series = groups.map do |group|
        result = conn.exec("select row_number() over (ORDER BY date) - 1, round(avg(mark), 2)::FLOAT
                   from lessons as l
                     join grades as g on l.id = g.lesson_id
                     join grade_descriptors as gd on gd.id = g.grade_descriptor_id
                   WHERE group_id = #{group.id}
                   GROUP BY l.id;").values
        { name: "#{t(:group)} #{group.group_chapter_name}", data: result }
      end

      p_t1 = 0.05565
      p_t2 = -0.00075043
      p_t3 = 4.2898e-06
      p_t4 = -8.4405e-09
      p_age = 0.048271
      # No intercept value given bij Patrick, so we use the average over all the group values here
      # = Average(3,928; 3,7858; 4,012; 3,9965; 4,3559; 3,3744)
      p_intercept = 3.909

      age = 13

      regression_values = series.pluck(:data).map(&:length).max

      regression = Array.new(regression_values) do |index|
        p_intercept + p_t1 * index + p_t2 * index**2 + p_t3 * index**3 + p_t4 * index**4 + p_age * age
      end

      series << {name: t(:regression_curve), data: regression, color: '#FF0000', lineWidth: 1, marker: {enabled: false}}
      series
    end

    def performance_data_for_each_student_versus_time_in_program
      series = []
      # regression parameters
      p_intercept = 3.31 # RegressionParameter.where(name: 'intercept').first.value
      p_t1 = 0.0556501190994651 # RegressionParameter.where(name: 't1').first.value
      p_t2 = -0.000750429285049042 # RegressionParameter.where(name: 't2').first.value
      p_t3 = 4.28977790402216E-06 # RegressionParameter.where(name: 't3').first.value
      p_t4 = -8.44049073102675E-09 # RegressionParameter.where(name: 't4').first.value
      p_age = 0.0482714171873393 # RegressionParameter.where(name: 'age').first.value

      if not @selected_student_id.nil? and not @selected_student_id == '' and not @selected_student_id == 'All'
        lessons = Lesson.includes(:grades).where(grades: {student_id: @selected_student_id})
        student = Student.find(@selected_student_id)
        @groupname = '(' + t(:student) + ' ' + student.proper_name + ')'
      elsif not @selected_group_id.nil? and not @selected_group_id == '' and not @selected_group_id == 'All'
        group = Group.find(@selected_group_id)
        chapter = group.chapter
        organization = chapter.organization
        orgname = organization.organization_name
        chapname = chapter.chapter_name
        groupname = group.group_name
        @groupname = '(' + t(:group) + ' ' + orgname + ' - ' + chapname + ' - ' + groupname + ')'
        lessons = Lesson.where(group_id: @selected_group_id)
      elsif not @selected_chapter_id.nil? and not @selected_chapter_id == '' and not @selected_chapter_id == 'All'
        chapter = Chapter.find(@selected_chapter_id)
        organization = chapter.organization
        group = chapter.groups.first
        orgname = organization.organization_name
        chapname = chapter.chapter_name
        groupname = group.group_name
        @groupname = '(' + t(:group) + ' ' + orgname + ' - ' + chapname + ' - ' + groupname + ')'
        lessons = Lesson.includes(:group).where(group_id: group.id)
        # lessons = Lesson.includes(:group).where(groups: {chapter_id: @selected_chapter_id})
      elsif not @selected_organization_id.nil? and not @selected_organization_id == '' and not @selected_organization_id == 'All'
        organization = Organization.find(@selected_organization_id)
        chapter = organization.chapters.first
        group = chapter.groups.first
        orgname = organization.organization_name
        chapname = chapter.chapter_name
        groupname = group.group_name
        @groupname = '(' + t(:group) + ' ' + orgname + ' - ' + chapname + ' - ' + groupname + ')'
        lessons = Lesson.includes(:group).where(group_id: group.id)
        # lessons = Lesson.includes(group: :chapter).where(chapters: {organization_id: @selected_organization_id})
      else
        organization = @organizations.first
        chapter = organization.chapters.first
        group = chapter.groups.first
        orgname = organization.organization_name
        chapname = chapter.chapter_name
        groupname = group.group_name
        @groupname = '(' + t(:group) + ' ' + orgname + ' - ' + chapname + ' - ' + groupname + ')'
        lessons = Lesson.includes(:group).where(group_id: group.id)
        # lessons = Lesson.all
      end

      performance_hash = {}
      performance_hash[:above] = []
      performance_hash[:below] = []

      lessons.each do |lesson|
        # Find the students who attended this lesson
        if not @selected_student_id.nil? and not @selected_student_id == '' and not @selected_student_id == 'All'
          students = Student.includes(:grades).where(grades: {lesson_id: lesson.id}, id: @selected_student_id)
        else
          students = Student.includes(:grades).select('distinct students.*').where(grades: {lesson_id: lesson.id})
        end

        students.each do |student|
          avg = Grade.where(lesson_id: lesson.id, student_id: student.id).joins(:grade_descriptor).average(:mark)
          # The number of lessons where this student participated in
          # nr_of_lessons = Lesson.includes(:grades).where('date < :date_to',
          #                                                {date_to: lesson.date}, grade: {student_id: student.id}).distinct.count(:id)
          nr_of_lessons = Lesson.includes(:grades).where('date < :date_to',
                                                         {date_to: lesson.date}).where(grades: {student_id: student.id}).distinct.count(:id)
          # nr_of_lessons = Lesson.where('date < :date_to', {date_to: lesson.date}, group_id: student.group.id).distinct.count(:id)

          dob = student.dob
          now = lesson.date
          age = now.year - dob.year - ((now.month > dob.month || (now.month == dob.month && now.day >= dob.day)) ? 0 : 1)

          # Non-linear multivariate regression formula
          performance = p_intercept
          performance += p_t1 * nr_of_lessons
          performance += p_t2 * nr_of_lessons**2
          performance += p_t3 * nr_of_lessons**3
          performance += p_t4 * nr_of_lessons**4
          performance += p_age * age

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
      series
    end

    def get_series_chart8(series)

      # top query
      if not @selected_student_id.nil? and not @selected_student_id == '' and not @selected_student_id == 'All'
        lessons = Lesson.includes(:grades).where(grades: {student_id: @selected_student_id})
      elsif not @selected_group_id.nil? and not @selected_group_id == '' and not @selected_group_id == 'All'
        lessons = Lesson.where(group_id: @selected_group_id)
      elsif not @selected_chapter_id.nil? and not @selected_chapter_id == '' and not @selected_chapter_id == 'All'
        lessons = Lesson.includes(:group).where(groups: {chapter_id: @selected_chapter_id})
      elsif not @selected_organization_id.nil? and not @selected_organization_id == '' and not @selected_organization_id == 'All'
        lessons = Lesson.includes(group: :chapter).where(chapters: {organization_id: @selected_organization_id})
      else
        lessons = policy_scope Lesson
      end

      # Hash to contain the groups series, so one entry per group
      series_hash = Hash.new
      regression_hash = Hash.new

      # Calculate the average performance for this lesson and group
      lessons.each do |lesson|
        # Count the number of previous lessons for this group
        nr_of_lessons = Lesson.where('group_id = :group_id AND date < :date_to',
                                     {group_id: lesson.group_id, date_to: lesson.date}).distinct.count(:id)
        # Determine the average group performance for this lesson
        avg = Grade.where(lesson_id: lesson.id).joins(:grade_descriptor).average(:mark)

        age = 13

        point = []
        point << nr_of_lessons
        point << avg.to_f

        # Prediction based on the regression model
        fitted = []
        fitted << nr_of_lessons
        p_t1 = 0.05565
        p_t2 = -0.00075043
        p_t3 = 4.2898e-06
        p_t4 = -8.4405e-09
        p_age = 0.048271
        # No intercept value given bij Patrick, so we use the average over all the group values here
        # = Average(3,928; 3,7858; 4,012; 3,9965; 4,3559; 3,3744)
        p_intercept = 3.909

        # No intercept value given bij Patrick, so we use the average over all the group values here (=3.5)
        fitted << p_intercept + p_t1 * nr_of_lessons + p_t2 * nr_of_lessons**2 + p_t3 * nr_of_lessons**3 + p_t4 * nr_of_lessons**4 + p_age * age

        # Bug Tracker: TRACK-111 - Conflicts groups with same name from different chapters
        hash_key = lesson.group.chapter.chapter_name + ' ' + lesson.group.group_name
        if series_hash[hash_key] == nil
          series_hash[hash_key] = []
        end
        if regression_hash[hash_key] == nil
          regression_hash[hash_key] = []
        end

        # add this point to the correct (meaning: this Group's) data series
        series_hash[hash_key] << point
        regression_hash[hash_key] << fitted
      end

      # Calculation is done, now convert the series_hash to something HighCharts understands
      # series_hash.each do |group, array|
      #   series << {name: t(:group) + ' ' + group, data: array}
      # end

      series_hash.each do |group, array|
        group_series = []
        regression = regression_hash[group]

        regression.sort_by! {|a| a[0]}
        group_series << {name: t(:group) + ' ' + group, data: array}
        group_series << {name: t(:regression_curve), data: regression, color: '#FF0000', lineWidth: 1, marker: {enabled: false}}
        series << {group: t(:group) + ' ' + group, series: group_series}
      end

    end

    def histogram_of_student_performance_change_by_gender
      conn = ActiveRecord::Base.connection.raw_connection
      male_students = @selected_students.where(gender: 'M')
      female_students = @selected_students.where(gender: 'F')

      result= []

      if male_students.length.positive?
        result << { name: "#{t(:gender)} M", data: conn.exec(performance_change_query(male_students)).values }
      end

      if female_students.length.positive?
        result << { name: "#{t(:gender)} F", data: conn.exec(performance_change_query(female_students)).values }
      end

      result
    end

    def histogram_of_student_performance_change
      conn = ActiveRecord::Base.connection.raw_connection

      if @selected_students.blank?
        res = []
      else
        res = conn.exec(performance_change_query(@selected_students)).values
      end
      [{name: t(:frequency_perc), data: res}]
    end

    def performance_per_skill
      series = []
      skills = Subject.includes(:skills).find(@subject).skills
      series_double_hash = Hash.new
      skill_hash = Hash.new

      # top query
      if not @selected_student_id.nil? and not @selected_student_id == '' and not @selected_student_id == 'All'
        lessons = Lesson.includes(:grades).where(grades: {student_id: @selected_student_id})
      elsif not @selected_group_id.nil? and not @selected_group_id == '' and not @selected_group_id == 'All'
        lessons = Lesson.where(group_id: @selected_group_id)
      elsif not @selected_chapter_id.nil? and not @selected_chapter_id == '' and not @selected_chapter_id == 'All'
        lessons = Lesson.includes(:group).where(groups: {chapter_id: @selected_chapter_id})
      elsif not @selected_organization_id.nil? and not @selected_organization_id == '' and not @selected_organization_id == 'All'
        lessons = Lesson.includes(group: :chapter).where(chapters: {organization_id: @selected_organization_id})
      else
        lessons = Lesson.where(group: @groups)
      end

      # Calculate the average performance for this lesson and group
      age = 0
      lessons.each do |lesson|
        if not @selected_student_id.nil? and not @selected_student_id == '' and not @selected_student_id == 'All'
          nr_of_lessons = Lesson.includes(:grades).where('date < :date_to',
                                                         {date_to: lesson.date}).where(grades: {student_id: @selected_student_id}).distinct.count(:id)

          # This student's age (for regression calculation)
          dob = Student.find(@selected_student_id).dob
          now = lesson.date
          age = now.year - dob.year - ((now.month > dob.month || (now.month == dob.month && now.day >= dob.day)) ? 0 : 1)
          # age = 13
        else
          # Count the number of previous lessons for this group
          nr_of_lessons = Lesson.where('group_id = :group_id AND date < :date_to',
                                       {group_id: lesson.group_id, date_to: lesson.date}).distinct.count(:id)

          # Calculate the average age for the group (for regression calculation)
          #
          # Below code is correct but a performance killer
          # Also, the regression parameters for age are quite small, making its impact on overall fitted performance small
          # It's questionable if the costs outweigh the benefits, so for now let's make age a constant
          # </
          # now = lesson.date
          # grades = lesson.grades.all
          # grades.each do |grade|
          #   dob = grade.student.dob
          #   age += now.year - dob.year - ((now.month > dob.month || (now.month == dob.month && now.day >= dob.day)) ? 0 : 1)
          # end
          # age /= lesson.grades.size
          age = 13
          # />

        end

        skills.each do |skill|
          if not @selected_student_id.nil? and not @selected_student_id == '' and not @selected_student_id == 'All'
            avg = Grade.includes(:grade_descriptor).where(lesson_id: lesson.id, student_id: @selected_student_id, grade_descriptors: {skill_id: skill.id}).joins(:grade_descriptor).average(:mark)
          else
            # Determine the average group performance for this lesson
            avg = Grade.includes(:grade_descriptor).where(lesson_id: lesson.id, grade_descriptors: {skill_id: skill.id}).joins(:grade_descriptor).average(:mark)
          end

          # Actual performance
          point = []
          point << nr_of_lessons
          point << avg.to_f

          # Prediction based on the regression model
          if skill_hash[skill.skill_name] == nil
            skill_hash[skill.skill_name] = []
          end
          skill_hash[skill.skill_name] << nr_of_lessons

          if series_double_hash[skill.skill_name] == nil
            series_double_hash[skill.skill_name] = Hash.new
          end

          # add this point to the correct (meaning: this Group's) data series
          # Bug Tracker: TRACK-111 - Conflicts groups with same name from different chapters
          hash_key = lesson.group.chapter.chapter_name + ' ' + lesson.group.group_name
          if series_double_hash[skill.skill_name][hash_key] == nil
            series_double_hash[skill.skill_name][hash_key] = []
          end

          # series_hash[lesson.group.group_name] << point
          series_double_hash[skill.skill_name][hash_key] << point

        end
      end

      # Calculation is done, now convert the series_hash to something HighCharts understands
      series_double_hash.each do |skill_name, hash|

        regression = []
        skill_hash[skill_name].each do |nr_of_lessons|

          point = []
          point << nr_of_lessons
          case skill_name
            when 'Memorization'
              p_t1 = 0.059758
              p_t2 = -0.00076705
              p_t3 = 4.3031e-06
              p_t4 = -8.3512e-09
              p_age = 0.050686
            when 'Grit'
              p_t1 = 0.026253
              p_t2 = -0.00033544
              p_t3 = 1.9132e-06
              p_t4 = -3.6252e-09
              p_age = 0.038559
            when 'Teamwork'
              p_t1 = 0.055124
              p_t2 = -0.00069727
              p_t3 = 3.6287e-06
              p_t4 = -6.3662e-09
              p_age = 0.05823
            when 'Discipline'
              p_t1 = 0.026199
              p_t2 = -0.00035038
              p_t3 = 2.0376e-06
              p_t4 = -4.0821e-09
              p_age = 0.062841
            when 'Self-Esteem'
              p_t1 = 0.054099
              p_t2 = -0.00068634
              p_t3 = 3.6989e-06
              p_t4 = -6.8504e-09
              p_age = 0.039392
            when 'Creativity & Self-Expression'
              p_t1 = 0.051559
              p_t2 = -0.0006465
              p_t3 = 3.5453e-06
              p_t4 = -6.7835e-09
              p_age = 0.041264
            when 'Language'
              p_t1 = 0.079468
              p_t2 = -0.0010474
              p_t3 = 5.6985e-06
              p_t4 = -1.0727e-08
              p_age = 0.050222
          end
          # No intercept value given bij Patrick, so we use the average over all the group values here (=3.5)
          point << 3.5 + p_t1 * nr_of_lessons + p_t2 * nr_of_lessons**2 + p_t3 * nr_of_lessons**3 + p_t4 * nr_of_lessons**4 + p_age * age
          regression << point
        end

        skill_series = []
        hash.each do |group, array|
          skill_series << {name: t(:group) + ' ' + group, data: array}
        end

        regression.sort_by! {|a| a[0]}
        skill_series << {name: t(:regression_curve), data: regression, color: '#FF0000', lineWidth: 1, marker: {enabled: false}}
        series << {skill: skill_name, series: skill_series}
      end
      series
    end

    def histogram_of_student_performance
      conn = ActiveRecord::Base.connection.raw_connection
      if @selected_students.blank?
        res = []
      else
        res = conn.exec("select COALESCE(rounded, 0)::INT as mark, count(*) * 100 / (sum(count(*)) over ())::FLOAT as percentage
                            from (select s.id, round(avg(mark)) as rounded
                                  from students as s
                                    left join grades as g
                                      on s.id = g.student_id
                                    left join grade_descriptors as gd
                                      on gd.id = g.grade_descriptor_id
                                  WHERE s.id IN (#{@selected_students.pluck(:id).join(', ')})
                                  GROUP BY s.id
                            ) as student_round_mark
                          GROUP BY mark
                          ORDER BY mark;").values
      end

      [{name: t(:frequency_perc), data: res}]
    end

    def assesments_per_month
      conn = ActiveRecord::Base.connection.raw_connection
      lesson_ids = Lesson.where(group_id: @selected_students.map(&:group_id).uniq).pluck(:id)

      if lesson_ids.blank?
        res = []
      else
        res = conn.exec("select to_char(date_trunc('month', l.date), 'YYYY-MM') as month, count(distinct(l.id, g.student_id)) as assessments
                                      from lessons as l
                                        inner join grades as g
                                          on l.id = g.lesson_id
                                        inner join groups as gr
                                          on gr.id = l.group_id
                                      where l.id IN (#{lesson_ids.join(', ')})
                                      group by month
                                      order by month;").values
      end

      {
        categories: res.map { |e| e[0] },
        series: [{ name: t(:nr_of_assessments), data: res.map { |e| e[1] } }]
      }
    end

    private

    def get_groups_for_average_performance
      if @selected_student_id.present? && @selected_student_id != 'All'
        Student.find(@selected_organization_id).group.includes(:chapter)
      elsif @selected_group_id.present? && @selected_group_id != 'All'
        Group.includes(:chapter).find(@selected_group_id)
      elsif @selected_chapter_id.present? && @selected_chapter_id != 'All'
        Group.includes(:chapter).where(chapter_id: @selected_chapter_id)
      elsif @selected_organization_id.present? && @selected_organization_id != 'All'
        Group.includes(:chapter).where(chapter: {organization_id: @selected_organization_id})
      else
        @groups.includes(:chapter)
      end
    end

    def find_resource_by_id_param(id, resource_class)
      return resource_class.where(id: id) unless all_selected?(id)
      return policy_scope(yield resource_class) if block_given?

      policy_scope resource_class
    end

    def all_selected?(id_selected)
      id_selected.nil? || id_selected == '' || id_selected == 'All'
    end

    def performance_change_query(students)
      "with w1 AS (
          SELECT
            s.id as student_id,
            l.id as lesson_id,
            date,
            avg(mark)
          FROM students AS s
            JOIN grades AS g
              ON s.id = g.student_id
            JOIN lessons AS l
              ON l.id = g.lesson_id
            JOIN grade_descriptors AS gd
              ON gd.id = g.grade_descriptor_id
          WHERE s.id IN (#{students.pluck(:id).join(', ')})
          GROUP BY s.id, l.id
      ),
      min_table AS (
          SELECT * from w1 s1 WHERE (student_id, date) IN (
            SELECT student_id, MIN(date) FROM w1
            GROUP BY student_id
          ) OR date is null
      ),
      max_table AS (
        SELECT * from w1 s1 WHERE (student_id, date) IN (
          SELECT student_id, MAX(date) FROM w1
          GROUP BY student_id
        ) OR date is null
      )
      SELECT COALESCE(floor(((max_table.avg - min_table.avg) * 2) + 0.5) / 2, 0)::FLOAT as diff, count(*) * 100 / (SUM(count(*)) over ())::FLOAT FROM max_table
        JOIN min_table
        ON max_table.student_id = min_table.student_id
      GROUP BY diff
      ORDER BY diff;"
    end
  end
end

