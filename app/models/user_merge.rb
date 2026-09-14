class UserMerge < ApplicationRecord
  belongs_to :source_user, class_name: "User"
  belongs_to :target_user, class_name: "User"

  validates :status, inclusion: { in: %w[completed undone] }

  def undoable?
    status == "completed"
  end
end
