# frozen_string_literal: true

require 'httpclient'
require 'json'

module RedmineMicrosoftteams
  class Listener < Redmine::Hook::Listener
    def redmine_microsoftteams_issues_new_after_save(context = {})
      issue = context[:issue]
      return if issue.is_private?

      url = teams_url(issue.project)
      return unless url

      text = "#{escape issue.author} #{l(:issue_created)} [#{escape issue}](#{Urls.object_url issue})"
      facts = Facts.for_issue(issue, display_watchers: settings['display_watchers'] == 'yes')
      speak escape(issue.project), text, issue.description, facts, url
    end

    def redmine_microsoftteams_issues_edit_after_save(context = {})
      return unless settings['post_updates'] == '1'

      issue = context[:issue]
      journal = context[:journal]
      return if issue.is_private? || journal.private_notes?

      url = teams_url(issue.project)
      return unless url

      text = "#{escape journal.user} #{l(:issue_updated)} [#{escape issue}](#{Urls.object_url issue})"
      speak escape(issue.project), text, journal.notes, Facts.for_journal(journal), url
    end

    def model_changeset_scan_commit_for_issue_ids_pre_issue_update(context = {})
      issue = context[:issue]
      changeset = context[:changeset]

      url = teams_url(issue.project)
      return unless url && issue.save
      return if issue.is_private?

      journal = issue.current_journal
      text = "#{escape journal.user} #{l(:issue_updated)} [#{escape issue}](#{Urls.object_url issue})"
      changeset_link = "[#{escape changeset.comments}](#{Urls.revision_url changeset})"
      sections = ll(Setting.default_language, :text_status_changed_by_changeset, changeset_link)

      speak escape(issue.project), text, sections, Facts.for_journal(journal), url
    end

    def controller_wiki_edit_after_save(context = {})
      return unless settings['post_wiki_updates'] == '1'

      project = context[:project]
      page = context[:page]
      url = teams_url(project)
      return unless url

      content = page.content
      text = "[#{page.title}](#{Urls.object_url page}) #{l(:wiki_updated_by)} *#{content.author}*"
      text = "#{text}\n\n#{escape content.comments}" if content.comments.present?

      speak escape(project), text, nil, nil, url
    end

    def speak(title, text, sections = nil, facts = nil, url = nil)
      url ||= settings['teams_url']
      return if url.blank?

      post(url, Card.build(url, title, text, sections, facts))
    end

    private

    def settings
      Setting.plugin_redmine_microsoftteams
    end

    def post(url, msg)
      client = HTTPClient.new
      client.ssl_config.cert_store.set_default_paths
      client.ssl_config.ssl_version = :auto
      client.post_async url, msg.to_json, { 'Content-Type': 'application/json' }
    rescue StandardError => e
      Rails.logger.warn("cannot connect to #{url}")
      Rails.logger.warn(e)
    end

    def escape(msg)
      Card.escape(msg)
    end

    def teams_url(project)
      url_for_project(project) if microsoftteams_enabled_for_project?(project)
    end

    def url_for_project(project)
      return if project.blank?

      field = ProjectCustomField.find_by(name: 'Teams URL')
      [
        field && project.custom_value_for(field)&.value,
        url_for_project(project.parent),
        settings['teams_url']
      ].find(&:present?)
    end

    def microsoftteams_enabled_for_project?(project)
      project.present? && project.module_enabled?(:microsoftteams)
    end
  end
end
