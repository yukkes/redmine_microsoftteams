# frozen_string_literal: true

module RedmineMicrosoftteams
  # Absolute URLs of Redmine objects based on the host name setting.
  module Urls
    module_function

    def object_url(obj)
      Rails.application.routes.url_for(obj.event_url(url_options))
    end

    def revision_url(changeset)
      repository = changeset.repository
      Rails.application.routes.url_for(
        controller: 'repositories', action: 'revision', id: repository.project,
        repository_id: repository.identifier_param, rev: changeset.revision, **url_options
      )
    end

    def url_options
      if Setting.host_name.to_s =~ %r{\A(https?://)?(.+?)(:(\d+))?(/.+)?\z}i
        { host: Regexp.last_match(2), protocol: Setting.protocol, port: Regexp.last_match(4),
          script_name: Regexp.last_match(5) }
      else
        { host: Setting.host_name, protocol: Setting.protocol }
      end
    end
  end
end
