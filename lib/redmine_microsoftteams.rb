# frozen_string_literal: true

# Classes in lib/ are autoloaded by Redmine's plugin loader.
module RedmineMicrosoftteams
  def self.setup
    Issue.include(IssuePatch) unless Issue.include?(IssuePatch)
    # Hook listeners register themselves once they are loaded.
    Listener
  end
end
