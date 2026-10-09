# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class IssuesControllerTest < Redmine::ControllerTest
  tests IssuesController

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :issues, :issue_statuses, :issue_categories, :trackers, :projects_trackers, :enumerations,
           :enabled_modules, :workflows, :custom_fields, :custom_fields_projects, :custom_fields_trackers

  def setup
    @posts = []
    HTTPClient.any_instance.stubs(:post_async).with do |url, body, _headers|
      @posts << { url: url, body: JSON.parse(body) }
    end
    Project.find(1).enable_module!(:microsoftteams)
    @request.session[:user_id] = 2
  end

  def test_post_new_issue_with_watchers
    with_settings plugin_redmine_microsoftteams: { 'teams_url' => 'https://example.com/teams',
                                                   'display_watchers' => 'yes' } do
      post :create, params: { project_id: 1,
                              issue: { tracker_id: 3, subject: 'With watchers', watcher_user_ids: ['3'] } }
    end

    assert_response :redirect
    assert_equal 1, @posts.size
    facts = @posts.first[:body]['attachments'].first['content']['body'].last['facts']
    assert_includes facts, { 'title' => 'Watcher', 'value' => 'Dave Lopper' }
  end
end
