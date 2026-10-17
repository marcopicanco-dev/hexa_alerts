class CompetitionSync < ApplicationRecord
  STATUSES = %w[queued running completed failed].freeze

  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :active, -> { where(status: %w[queued running]) }

  def active? = status.in?(%w[queued running])
  def completed? = status == "completed"
  def fallback? = details.dig("espn", "source") == "snapshot"
end
