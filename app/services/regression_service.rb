# frozen_string_literal: true

class RegressionService
  @@skill_parameters = {
    'Memorization' => {
      t1: 0.059758,
      t2: -0.00076705,
      t3: 4.3031e-06,
      t4: -8.3512e-09,
      age: 0.050686
    },
    'Grit' => {
      t1: 0.026253,
      t2: -0.00033544,
      t3: 1.9132e-06,
      t4: -3.6252e-09,
      age: 0.038559
    },
    'Teamwork' => {
      t1: 0.055124,
      t2: -0.00069727,
      t3: 3.6287e-06,
      t4: -6.3662e-09,
      age: 0.05823
    },
    'Discipline' => {
      t1: 0.026199,
      t2: -0.00035038,
      t3: 2.0376e-06,
      t4: -4.0821e-09,
      age: 0.062841
    },
    'Self-Esteem' => {
      t1: 0.054099,
      t2: -0.00068634,
      t3: 3.6989e-06,
      t4: -6.8504e-09,
      age: 0.039392
    },
    'Creativity & Self-Expression' => {
      t1: 0.051559,
      t2: -0.0006465,
      t3: 3.5453e-06,
      t4: -6.7835e-09,
      age: 0.041264
    },
    'Language' => {
      t1: 0.079468,
      t2: -0.0010474,
      t3: 5.6985e-06,
      t4: -1.0727e-08,
      age: 0.050222
    }
  }

  def skill_regression(skill_name, length)
    Array.new(length) do |i|
      [i, skill_regression_point(@@skill_parameters[skill_name], i)]
    end
  end

  private

  def skill_regression_point(params, index)
    3.5 + params[:t1] * index + params[:t2] * index**2 + params[:t3] * index**3 + params[:t4] * index**4 + params[:age] * 13
  end


end
