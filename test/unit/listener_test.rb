# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class ListenerTest < ActiveSupport::TestCase
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :issues, :issue_statuses, :issue_categories, :versions, :trackers, :projects_trackers, :enumerations,
           :enabled_modules, :journals, :journal_details, :watchers,
           :custom_fields, :custom_fields_projects, :custom_fields_trackers, :custom_values,
           :repositories, :changesets, :workflows

  TEAMS_URL = 'https://example.com/workflows/teams'
  LEGACY_URL = 'https://example.webhook.office.com/webhookb2/teams'

  def setup
    @posts = []
    HTTPClient.any_instance.stubs(:post_async).with do |url, body, headers|
      @posts << { url: url, body: JSON.parse(body), headers: headers }
    end
    @project = Project.find(1)
    @project.enable_module!(:microsoftteams)
    User.current = User.find(2)
  end

  def teardown
    User.current = nil
  end

  def test_post_new_issue_as_adaptive_card
    with_teams_settings do
      Issue.generate!(project: @project, subject: 'New <issue>', description: 'Some description')
    end

    assert_equal 1, @posts.size
    post = @posts.first
    assert_equal TEAMS_URL, post[:url]
    assert_equal 'message', post[:body]['type']

    attachment = post[:body]['attachments'].first
    assert_equal 'application/vnd.microsoft.card.adaptive', attachment['contentType']

    texts = attachment['content']['body'].pluck('text').compact
    assert_includes texts, 'eCookbook'
    assert(texts.any? { |text| text.include?('created') && text.include?('New &lt;issue&gt;') })
    assert_includes texts, 'Some description'

    fact_set = attachment['content']['body'].find { |block| block['type'] == 'FactSet' }
    assert_includes fact_set['facts'].pluck('title'), 'Status'
  end

  def test_post_new_issue_as_message_card_for_legacy_webhook_url
    with_teams_settings('teams_url' => LEGACY_URL) do
      Issue.generate!(project: @project, subject: 'Legacy', description: "a\r\n<pre>code</pre>\r\nb")
    end

    assert_equal 1, @posts.size
    body = @posts.first[:body]
    assert_equal 'eCookbook', body['title']
    assert_includes body['text'], 'Legacy'
    assert_equal ["```\r\ncode"], body['sections'].pluck('text').compact.grep(/code/)
    assert_includes body['sections'].last['facts'].pluck('name'), 'Status'
  end

  def test_post_code_block_as_monospace_text
    with_teams_settings do
      Issue.generate!(project: @project, description: "before\n<pre>code</pre>\nafter")
    end

    blocks = @posts.first[:body]['attachments'].first['content']['body']
    code = blocks.find { |block| block['text'] == 'code' }
    assert_equal 'monospace', code['fontType']
  end

  def test_skip_private_issue
    with_teams_settings do
      Issue.generate!(project: @project, is_private: true)
    end

    assert_empty @posts
  end

  def test_skip_project_without_module
    @project.disable_module!(:microsoftteams)
    with_teams_settings do
      Issue.generate!(project: @project.reload)
    end

    assert_empty @posts
  end

  def test_skip_without_url
    with_teams_settings('teams_url' => '') do
      Issue.generate!(project: @project)
    end

    assert_empty @posts
  end

  def test_use_url_of_project_custom_field
    field = ProjectCustomField.generate!(name: 'Teams URL', field_format: 'string')
    @project.custom_field_values = { field.id.to_s => 'https://example.com/project' }
    @project.save!
    Project.find(3).enable_module!(:microsoftteams)

    with_teams_settings do
      Issue.generate!(project: Project.find(3))
    end

    assert_equal 'https://example.com/project', @posts.first[:url]
  end

  def test_skip_user_without_webhook_role
    with_teams_settings('webhook_role' => 'Developer') do
      Issue.generate!(project: @project)
    end

    assert_empty @posts
  end

  def test_post_for_user_with_webhook_role
    with_teams_settings('webhook_role' => 'Manager') do
      Issue.generate!(project: @project)
    end

    assert_equal 1, @posts.size
  end

  def test_post_issue_update
    issue = Issue.find(1)
    with_teams_settings('post_updates' => '1') do
      issue.init_journal(User.current, 'Some notes')
      issue.status_id = 2
      issue.save!
    end

    assert_equal 1, @posts.size
    blocks = @posts.first[:body]['attachments'].first['content']['body']
    assert(blocks.any? { |block| block['text'].to_s.include?('updated') })
    assert(blocks.any? { |block| block['text'] == 'Some notes' })
    facts = blocks.find { |block| block['type'] == 'FactSet' }['facts']
    assert_includes facts, { 'title' => 'Status', 'value' => 'Assigned' }
  end

  def test_post_issue_update_with_custom_field_and_parent
    issue = Issue.find(1)
    with_teams_settings('post_updates' => '1') do
      issue.init_journal(User.current)
      issue.custom_field_values = { '2' => 'changed' }
      issue.parent_issue_id = 2
      issue.save!
    end

    # Redmine 5.0 also posts the update of the new parent issue.
    post = @posts.find { |p| p[:body]['attachments'].first['content']['body'][1]['text'].include?('#1') }
    facts = post[:body]['attachments'].first['content']['body'].last['facts']
    assert_includes facts, { 'title' => 'Searchable field', 'value' => 'changed' }
    parent = facts.find { |fact| fact['title'] == 'Parent task' }
    assert_match %r{\A\[.*\]\(http://.*/issues/2\)\z}, parent['value']
  end

  def test_skip_issue_update_without_post_updates
    issue = Issue.find(1)
    with_teams_settings do
      issue.init_journal(User.current, 'Some notes')
      issue.save!
    end

    assert_empty @posts
  end

  def test_skip_private_notes
    issue = Issue.find(1)
    with_teams_settings('post_updates' => '1') do
      issue.init_journal(User.current, 'Private')
      issue.private_notes = true
      issue.save!
    end

    assert_empty @posts
  end

  def test_post_issue_update_by_changeset
    changeset = Changeset.find(100)
    with_teams_settings('post_updates' => '1') do
      with_settings commit_ref_keywords: '*', commit_update_keywords: [{ 'keywords' => 'fixes', 'status_id' => '3' }] do
        changeset.update!(comments: 'Fixes #1')
        changeset.scan_comment_for_issue_ids
      end
    end

    texts = @posts.last[:body]['attachments'].first['content']['body'].pluck('text').compact
    assert_includes texts, 'Applied in changeset [Fixes #1](http://localhost:3000/projects/ecookbook/repository/10/revisions/1).'
  end

  def test_post_with_object_url_with_prefix
    with_teams_settings do
      with_settings host_name: 'redmine.example.com:8080/redmine', protocol: 'https' do
        Issue.generate!(project: @project)
      end
    end

    texts = @posts.first[:body]['attachments'].first['content']['body'].pluck('text').compact
    assert(texts.any? { |text| text.include?('(https://redmine.example.com:8080/redmine/issues/') })
  end

  def test_connection_errors_are_logged
    HTTPClient.any_instance.stubs(:post_async).raises(SocketError)
    with_teams_settings do
      assert_nothing_raised { Issue.generate!(project: @project) }
    end
  end

  private

  def with_teams_settings(settings = {}, &block)
    with_settings(plugin_redmine_microsoftteams: {
      'teams_url' => TEAMS_URL,
      'display_watchers' => 'no',
      'webhook_role' => ''
    }.merge(settings), &block)
  end
end
