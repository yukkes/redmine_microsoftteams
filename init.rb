# frozen_string_literal: true

Redmine::Plugin.register :redmine_microsoftteams do
  name 'Redmine Microsoft Teams'
  author 'wellbia'
  url 'https://github.com/wellbia/redmine_microsoftteams'
  author_url 'https://github.com/wellbia'
  description 'Microsoft Teams chat integration'
  version '0.6.0'

  requires_redmine version_or_higher: '5.0'

  project_module :microsoftteams do
    permission :receive_microsoftteams_notifications, {}, public: true
  end

  settings default: {
    'display_watchers' => 'no',
    'webhook_role' => ''
  }, partial: 'settings/microsoftteams_settings'
end

RedmineMicrosoftteams.setup
