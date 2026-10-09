# frozen_string_literal: true

module RedmineMicrosoftteams
  module IssuePatch
    def self.included(base)
      base.after_create :create_from_issue
      base.after_save :save_from_issue
    end

    def create_from_issue
      @create_already_fired = true
      return unless user_has_role?

      Redmine::Hook.call_hook(:redmine_microsoftteams_issues_new_after_save, issue: self)
    end

    def save_from_issue
      return if @create_already_fired || current_journal.nil? || !user_has_role?

      Redmine::Hook.call_hook(:redmine_microsoftteams_issues_edit_after_save, issue: self, journal: current_journal)
    end

    private

    def user_has_role?
      role_name = Setting.plugin_redmine_microsoftteams['webhook_role']
      return true if role_name.blank?

      user = User.current
      return false unless user&.logged?

      user.roles_for_project(project).any? { |role| role.name == role_name }
    end
  end
end
