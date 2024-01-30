class CleanUp < ApplicationJob
  queue_as :italtelo
  sidekiq_options retry: 1, backtrace: 10

  def perform
    # Cancello tutti i files caricati più vecchi di due mesi
    ActiveStorage::Attachment.where(record: LineItem.where(status: 'completed')).where("created_at <= ?", Date.today.end_of_day - 2.months).delete_all
    ActiveStorage::Attachment.where(record: AggregatedJob.completed).where("created_at <= ?", Date.today.end_of_day - 2.months).delete_all
  end
end
