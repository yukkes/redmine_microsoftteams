# frozen_string_literal: true

module RedmineMicrosoftteams
  # Facts (title/value pairs) shown on the cards.
  module Facts
    extend Redmine::I18n

    # Issue attributes whose values are record ids, and the models to look them up.
    DETAIL_MODELS = {
      'tracker' => 'Tracker',
      'project' => 'Project',
      'status' => 'IssueStatus',
      'priority' => 'IssuePriority',
      'category' => 'IssueCategory',
      'assigned_to' => 'Principal',
      'fixed_version' => 'Version'
    }.freeze

    module_function

    def for_issue(issue, display_watchers: false)
      facts = {
        l(:field_status) => escape(issue.status),
        l(:field_priority) => escape(issue.priority),
        l(:field_assigned_to) => escape(issue.assigned_to)
      }
      facts[l(:field_watcher)] = escape(issue.watcher_users.join(', ')) if display_watchers
      facts
    end

    def for_journal(journal)
      journal.details.map { |detail| detail_to_field(detail) }.reduce({}, :merge)
    end

    def detail_to_field(detail)
      title, value =
        case detail.property
        when 'cf'
          custom_field_detail(detail)
        when 'attachment'
          [l(:label_attachment), attachment_detail_value(detail)]
        else
          attribute_detail(detail)
        end
      return {} unless title

      { title => value.presence || '-' }
    end

    def custom_field_detail(detail)
      custom_field = detail.custom_field
      return unless custom_field

      value = detail.value ? IssuesController.helpers.format_value(detail.value, custom_field) : ''
      [custom_field.name, value]
    end

    def attachment_detail_value(detail)
      attachment = Attachment.find_by(id: detail.prop_key)
      attachment ? link(attachment.filename, attachment) : escape(detail.value)
    end

    def attribute_detail(detail)
      key = detail.prop_key.to_s.sub('_id', '')
      return [l(:field_parent_issue), parent_detail_value(detail)] if key == 'parent'

      value =
        if DETAIL_MODELS.key?(key)
          DETAIL_MODELS[key].constantize.find_by(id: detail.value)
        else
          detail.value
        end
      [l("field_#{key}"), escape(value)]
    end

    def parent_detail_value(detail)
      issue = Issue.find_by(id: detail.value)
      issue ? link(issue, issue) : escape(detail.value)
    end

    def link(text, obj)
      "[#{escape text}](#{Urls.object_url obj})"
    end

    def escape(msg)
      Card.escape(msg)
    end
  end
end
