class CreateMindleapsAnalyticsRegressionParameters < ActiveRecord::Migration[5.0]
  def change
    create_table :mindleaps_analytics_regression_parameters do |t|
      t.string :name
      t.float :value

      t.timestamps
    end
  end
end
