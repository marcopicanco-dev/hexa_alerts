class MatchExternalReference < ApplicationRecord
  belongs_to :match

  validates :source, :external_id, presence: true
  validates :external_id, uniqueness: true
end
