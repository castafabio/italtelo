class AddFileNameToAggregatedJobs < ActiveRecord::Migration[6.1]
  def change
    add_column :aggregated_jobs, :file_name, :string, default: nil
  end
end
