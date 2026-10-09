# frozen_string_literal: true

class EnableMicrosoftteamsProjectModule < ActiveRecord::Migration[4.2]
  MODULE_NAME = 'microsoftteams'

  def up
    Project.find_each do |project|
      EnabledModule.find_or_create_by!(project_id: project.id, name: MODULE_NAME)
    end

    Setting.default_projects_modules = Array(Setting.default_projects_modules) | [MODULE_NAME]
  end

  def down
    EnabledModule.where(name: MODULE_NAME).delete_all
    Setting.default_projects_modules = Array(Setting.default_projects_modules) - [MODULE_NAME]
  end
end
