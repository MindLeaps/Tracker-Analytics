module SQL
  def performance_per_skill_in_lessons_query(lessons)
    <<~SQL
      select rank() over(PARTITION BY gr.id, s.id order by date) - 1 as rank, round(avg(mark), 2)::FLOAT, l.id, date, s.skill_name, gr.id::INT from
          lessons as l
          join groups as gr on gr.id = l.group_id
          join grades as g on l.id = g.lesson_id
          join grade_descriptors as gd on gd.id = g.grade_descriptor_id
          join skills as s on s.id = gd.skill_id
        WHERE l.id IN (#{lessons.pluck(:id).join(', ')})
        GROUP BY gr.id, l.id, s.id
        ORDER BY gr.id, date, s.id;
    SQL
  end

  def performance_change_query(students)
    <<~SQL
      with w1 AS (
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
      ORDER BY diff;
    SQL
  end
end
