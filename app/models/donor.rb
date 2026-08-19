class Donor < ApplicationRecord
  has_many :gifts, dependent: :restrict_with_exception
  validates :name, presence: true
end
